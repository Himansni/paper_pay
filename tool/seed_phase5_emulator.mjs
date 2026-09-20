// Phase 5 monthly billing seed — thin wrapper over the shared Phase 4 bootstrap.
//
// The Phase 5 integration test creates all billing-specific data (newspapers,
// subscriptions, pauses, exceptions, adjustments, and bills) programmatically
// via real repositories after signing in. This seed only provisions the Auth
// accounts, business, members, area, and customers that every phase reuses.

await import('./seed_phase4_emulator.mjs');

process.stdout.write(
  '\n  Phase 5 monthly billing seed ready.\n' +
    '  Auth accounts, business, members, area, and customers are provisioned.\n' +
    '  Billing-specific data will be created by the integration test.\n\n',
);
