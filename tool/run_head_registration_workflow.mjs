import {spawn} from 'node:child_process';

for (const host of [
  process.env.FIRESTORE_EMULATOR_HOST,
  process.env.FIREBASE_AUTH_EMULATOR_HOST,
]) {
  if (!host || (!host.startsWith('127.0.0.1:') && !host.startsWith('localhost:'))) {
    throw new Error('Head registration workflow requires local emulators.');
  }
}

function run(command, args, label, flutter = false) {
  process.stdout.write(`\n=== ${label} ===\n`);
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {env: process.env, stdio: ['pipe', 'pipe', 'pipe']});
    let output = '';
    let ending = false;
    const inspect = (chunk, destination) => {
      destination.write(chunk);
      output += chunk.toString();
      if (flutter && !ending && (output.includes('All tests passed!') || output.includes('Some tests failed.'))) {
        ending = true;
        child.stdin.write('q\n');
        child.stdin.end();
      }
    };
    child.stdout.on('data', (chunk) => inspect(chunk, process.stdout));
    child.stderr.on('data', (chunk) => inspect(chunk, process.stderr));
    child.on('error', reject);
    child.on('close', (code) => {
      const clean = output.replace(/\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])/g, '');
      const flutterFailure =
        flutter &&
        (!clean.includes('All tests passed!') ||
          clean.includes('Some tests failed.') ||
          clean.includes('Test failed.') ||
          clean.includes('EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK'));
      if (code !== 0 || flutterFailure) {
        reject(new Error(`${label} failed with exit code ${code}.`));
      } else {
        resolve();
      }
    });
  });
}

await run('node', ['tool/run_head_registration_integration.mjs'], 'Callable backend integration');
await run('node', ['tool/seed_head_registration_emulator.mjs'], 'Flutter workflow seed');
await run(
  'flutter',
  [
    'run',
    '-d',
    'chrome',
    '--target',
    'integration_test/head_self_registration_smoke_test.dart',
    '--dart-define=USE_FIREBASE_EMULATORS=true',
    '--dart-define=PAPERROUTE_ENABLE_AGENCY_REGISTRATION=true',
  ],
  'Flutter Head registration workflow',
  true,
);

process.stdout.write('\nConnected Head self-registration workflow passed locally.\n');
