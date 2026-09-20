// Phase 6 collections seed — thin wrapper over the shared Phase 4 bootstrap.
//
// The Phase 6 integration test creates all collection-specific data (newspapers,
// subscriptions, finalized bills, payments, reversals, UPI settings, and
// collection projections) programmatically via real repositories after signing
// in. This seed only provisions the shared Auth/business/member/area/customer
// baseline.

await import('./seed_phase4_emulator.mjs');

process.stdout.write(
  '\n  Phase 6 collections and payments seed ready.\n' +
    '  Auth accounts, business, members, area, and customers are provisioned.\n' +
    '  Collection-specific data will be created by the integration test.\n\n',
);
