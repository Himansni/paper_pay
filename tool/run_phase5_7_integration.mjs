import { spawnSync } from 'node:child_process';

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

function run(command, args, label) {
  process.stdout.write(`\n=== ${label} ===\n`);

  const result = spawnSync(command, args, {
    stdio: 'inherit',
    env: process.env,
  });

  if (result.error) {
    throw result.error;
  }

  if (result.status !== 0) {
    throw new Error(`${label} failed with exit code ${result.status ?? 'unknown'}.`);
  }
}

for (const phase of phases) {
  run('node', [phase.seedScript], `${phase.name}: seed`);
  run(
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
  );
}

process.stdout.write(
  '\nAll Phase 5, 6, and 7 emulator integration smoke tests passed.\n',
);
