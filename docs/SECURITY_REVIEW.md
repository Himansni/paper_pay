# Phase 8 focused security review

Reviewed against the final local architecture and Firestore Rules:

- Tenant access requires active membership under the requested business; the
  final wildcard remains deny-by-default. An inactive member may read only the
  minimal self-membership state needed for the disabled-account gate.
- Member documents remain authoritative for role, status, permissions and area
  assignments. Clients cannot create a Head, change their authority, or manage
  passwords for another user.
- Employees are restricted to assigned customers and authoritative permitted
  areas. Head-only fields include opening balances, price authority, business
  settings, employee control, reversals and reporting exports.
- Finalized bills/lines, confirmed payments, allocations, reversals, pricing
  revisions, subscription versions and audit records are append-only or
  immutable. Transaction-coupled projections are validated against their source
  ledger mutation; private payment state is not generally readable.
- UPI display configuration is Head-managed. QR generation is not payment
  confirmation and performs no ledger write.
- GPS coordinates require the customer consent flag. Customer contact, location
  and exports remain tenant-scoped; operational logging must not contain them.
- Billing finalization, confirmation and reversal use transactions,
  deterministic/idempotent identifiers where retry is allowed, and server
  read-back. Offline local state is never accepted as confirmed financial truth.
- No service-account credential, Admin key, signing key, environment secret,
  emulator export or build output is tracked. FlutterFire client configuration
  is public application metadata and development-flavor scoped.

No Phase 8 Rules change was needed. App Check is recommended as defense in depth
using the staged, non-enforcing plan in [APP_CHECK_ROLLOUT.md](APP_CHECK_ROLLOUT.md).
It must not be used to compensate for weaker Rules.
