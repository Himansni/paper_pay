// BEGINNER NOTE:
// [Emulator Integration Test Runner]
// This automation script executes end-to-end integration tests using local Firebase Emulators:
// 1. Verifies that local Firebase Auth and Firestore emulators are running (e.g. 127.0.0.1).
// 2. Seeds deterministic synthetic data into the emulator using phase seed scripts.
// 3. Runs Flutter integration tests (billing, collections, reporting) against the local backend.
// This enables complete verification of data flows and rules without risking remote cloud data.
import { spawn } from 'node:child_process';

const expectedLocalHosts = [
  process.env.FIRESTORE_EMULATOR_HOST,
  process.env.FIREBASE_AUTH_EMULATOR_HOST,
];

for (const host of expectedLocalHosts) {
  if (!host || (!host.startsWith('127.0.0.1:') && !host.startsWith('localhost:'))) {
    throw new Error(
      'Integration runner requires local Firebase Auth and Firestore emulators. ' +
        'Run it through `npm run test:integration`.',
    );
  }
}

const phases = [
  {
    name: 'Phase 5 monthly billing',
    seedScript: 'tool/seed_phase5_emulator.mjs',
    testTarget: 'integration_test/phase5_monthly_billing_smoke_test.dart',
  },
  {
    name: 'Phase 6 collections and payments',
    seedScript: 'tool/seed_phase6_emulator.mjs',
    testTarget: 'integration_test/phase6_collections_smoke_test.dart',
  },
  {
    name: 'Phase 7 dashboards and reporting',
    seedScript: 'tool/seed_phase7_emulator.mjs',
    testTarget: 'integration_test/phase7_reporting_smoke_test.dart',
  },
];

const requestedPhase = process.argv[2]?.toLowerCase();
const phasesToRun = requestedPhase
  ? phases.filter(
      (phase) =>
        phase.name.toLowerCase().includes(requestedPhase) ||
        phase.seedScript.toLowerCase().includes(requestedPhase),
    )
  : phases;

if (requestedPhase && phasesToRun.length === 0) {
  throw new Error(
    `No matching phase found for "${process.argv[2]}". Available phases: Phase 5, Phase 6, Phase 7.`,
  );
}

function runCommand(command, args, label, { isFlutterTest = false } = {}) {
  process.stdout.write(`\n=== ${label} ===\n`);

  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      stdio: ['pipe', 'pipe', 'pipe'],
      env: process.env,
    });

    let combinedOutput = '';
    let terminated = false;

    function terminateFlutter() {
      if (terminated) return;
      terminated = true;
      try {
        child.stdin.write('q\n');
        child.stdin.end();
      } catch {}
      setTimeout(() => {
        try {
          child.kill('SIGINT');
        } catch {}
      }, 3000);
    }

    child.stdout.on('data', (chunk) => {
      process.stdout.write(chunk);
      combinedOutput += chunk.toString();
      if (
        isFlutterTest &&
        (combinedOutput.includes('All tests passed!') ||
          combinedOutput.includes('Some tests failed.') ||
          combinedOutput.includes('Application finished.'))
      ) {
        terminateFlutter();
      }
    });

    child.stderr.on('data', (chunk) => {
      process.stderr.write(chunk);
      combinedOutput += chunk.toString();
      if (
        isFlutterTest &&
        (combinedOutput.includes('All tests passed!') ||
          combinedOutput.includes('Some tests failed.') ||
          combinedOutput.includes('Application finished.'))
      ) {
        terminateFlutter();
      }
    });

    child.on('error', (err) => {
      reject(new Error(`${label} failed to spawn: ${err.message}`));
    });

    child.on('close', (status) => {
      if (status !== 0 && status !== null) {
        return reject(
          new Error(`${label} failed with exit code ${status}.`),
        );
      }

      if (isFlutterTest) {
        const plainOutput = combinedOutput.replace(
          /\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])/g,
          '',
        );
        const hasPassedConfirmation = plainOutput.includes('All tests passed!');
        const hasTestFailureMarker =
          plainOutput.includes('Some tests failed.') ||
          plainOutput.includes('Test failed.') ||
          plainOutput.includes('EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK') ||
          /\b\d+:\d+\s+\+\d+\s+-\d+:/.test(plainOutput) ||
          /\b\d+:\d+\s+\+\d+.*\[E\]/.test(plainOutput);

        if (hasTestFailureMarker || !hasPassedConfirmation) {
          return reject(
            new Error(
              `${label} failed: test failure detected in Flutter output ` +
                `(passed confirmation: ${hasPassedConfirmation}, failure marker: ${hasTestFailureMarker}).`,
            ),
          );
        }
      }

      resolve();
    });
  });
}

for (const phase of phasesToRun) {
  await runCommand('node', [phase.seedScript], `${phase.name}: seed`);
  await runCommand(
    'flutter',
    [
      'run',
      '-d',
      'chrome',
      '--target',
      phase.testTarget,
      '--dart-define=USE_FIREBASE_EMULATORS=true',
    ],
    `${phase.name}: integration smoke test`,
    { isFlutterTest: true },
  );
}

process.stdout.write(
  `\nAll ${phasesToRun.map((p) => p.name.split(' ')[0] + ' ' + p.name.split(' ')[1]).join(', ')} emulator integration smoke tests passed.\n`,
);
