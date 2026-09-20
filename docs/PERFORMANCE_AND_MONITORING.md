# Performance, read cost, and monitoring

## Query/read-cost review

Customer/catalog/report lists are cursor paginated and never fetch the whole
tenant for a page. Dashboard totals use server aggregates. Recent activity and
ranked employee/area summaries are bounded. Billing plans one selected customer
and month at a time and snapshots its resolved inputs; payment allocation reads
the customer's open balances, not every tenant bill. No connected Phase 8 path
showed an obvious per-row network query loop.

Run the emulator-only scale profile with:

```sh
npm run profile:phase8
```

It hard-fails outside `demo-paper-route`, creates 1,200 customers with areas,
employees, subscriptions, bills, balances, payments, and reversals, then checks
two customer cursor pages and representative dashboard/outstanding/employee
aggregates. Timings are regression signals for query shape, not production
latency guarantees; the emulator has no production network or index build cost.

The main cost risk is dashboard/report fan-out: a Head dashboard intentionally
uses multiple aggregation requests, and detailed breakdown reports perform a
bounded number of aggregates for visible configured dimensions. Avoid automatic
rapid refresh, keep filters deliberate, and inspect usage before raising the
current limits. CSV export is paginated and capped at 5,000 rows.

## Cost-conscious monitoring

No paid monitoring service is enabled. During rollout, a named owner should
review Firebase Usage and billing/quota dashboards daily, then weekly after the
baseline stabilizes:

- Firestore document reads/writes/deletes, storage, denied requests, and quota;
- Authentication sign-in failures and unusual account creation/reset activity;
- App Check metrics in monitor mode;
- user-reported startup, permission, billing, payment, reversal, and export
  errors, recording app version, role, workflow, time, and sanitized error code;
- unexpected changes in bills finalized, confirmed payments, reversals, or
  audit counts compared with normal business volume.

Set conservative free-quota operational thresholds (for example, investigate a
2x day-over-day read/write increase or repeated financial errors) based on the
first normal month. Never log passwords, Firebase tokens, full addresses, phone
numbers, UPI references, or exported rows. Crashlytics/paid alerting is not
configured; adding it needs a privacy/cost review and separate approval.

Poor-network financial UX must continue to treat only server-acknowledged,
read-back state as truth. A spinner, local form completion, QR display, or UPI
request is not a confirmed payment. Finalization/payment/reversal retry paths
retain deterministic identifiers, transactions, read-back recovery, and clear
uncertain-result messaging. Do not add offline optimistic ledger totals.
