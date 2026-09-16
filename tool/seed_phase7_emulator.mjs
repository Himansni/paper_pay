// Phase 7 dashboards and reports seed — thin wrapper over the shared Phase 4
// bootstrap.
//
// The Phase 7 integration test creates all reporting-specific data (pricing
// region, newspapers, subscriptions, finalized bills, payments, reversals, and
// daily pricing rules) programmatically via real repositories after signing in.
// This seed only provisions the shared Auth/business/member/area/customer
// baseline.

await import('./seed_phase4_emulator.mjs');

process.stdout.write(
  '\n  Phase 7 dashboards and reports seed ready.\n' +
    '  Auth accounts, business, members, area, and customers are provisioned.\n' +
    '  Reporting-specific data will be created by the integration test.\n\n',
);
