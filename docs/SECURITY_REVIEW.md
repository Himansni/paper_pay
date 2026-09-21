# Phase 8 focused security review

## Owner registration boundary

Create Agency Account cannot write privileged records through client Rules.
The client supplies only owner/agency presentation fields, legal versions,
locale/platform, and a UUID request ID. A trusted callable derives verified UID
and email from Admin Auth and creates the business, authoritative Head member,
profile, private registry, immutable consent, and audit atomically. Client
member creation remains limited to the exact verified invite-backed employee;
even an existing Head cannot create another Head membership. Pending employee
invitations are choices rather than authority, while accepted employee state or
legacy identity conflicts fail closed. This source is emulator-only until
Blaze/Functions, indexes, and Rules receive separate approval.

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
