# Architecture

## Recommendation

Use a feature-first clean architecture with three boundaries inside each feature:

- **Presentation:** Flutter widgets and Riverpod providers. It validates input and displays state but contains no financial rules.
- **Domain:** plain Dart models, policies, and deterministic services. It has no Firebase dependency and is fast to unit test.
- **Data:** Firebase implementations of domain repository interfaces. Vendor exceptions are translated to user-safe application errors.

Shared configuration, theme, errors, and calendar primitives live under `lib/core`. This is intentionally lighter than a full enterprise clean-architecture framework, but preserves the boundaries needed for 1,000+ customers and future web/tablet support.

## State and routing

Riverpod was chosen because it supports dependency overrides in tests, stream state, disposal, and small composable providers without tying domain code to widgets. Code generation is not required in this first version.

GoRouter provides declarative routes. `AuthGate` is the role-routing authority in the UI: it observes the repository session and selects login, verification, activation, disabled-account, Head, or Employee state. A route argument is never accepted as proof of role.

Authenticated Phase 2 routes re-enter `AuthGate`; only an active Head membership can reach business settings, employee management, area management, or customer assignment. An employee who enters a Head URL is returned to their own dashboard.

## Authentication boundary

Firebase Authentication proves identity. Firestore membership proves authorization. The joined `AppUser` has:

- Firebase UID and verified email
- business ID
- fixed role (`head` or `employee`)
- active/inactive status
- permission keys

The membership document is authoritative for role, status, and permissions. A user profile helps locate the business and provides fallback display details, but missing membership data always produces pending access rather than inheriting profile privileges.

The mobile app does not create Heads. A trusted Firebase project administrator creates the first Head. Heads later create employee invitations, never employee Firebase passwords. Employees create their own passwords, verify ownership of the exact invited email, then atomically consume the invite.

This Spark-compatible design avoids placing Admin SDK credentials in the client. A future trusted backend can replace invitation provisioning if automatic user administration becomes important.

## Billing boundary

`MonthlyBillingEngine` is a pure function over calendar dates and integer paise. It produces daily charge snapshots with deterministic keys. Persistence will finalize one customer/month bill in a transaction using a deterministic document ID such as `2026-05` under that customer. Repeating finalization must find the existing bill instead of creating a second one.

Finalized bills are append-only. Corrections are separate adjustment documents. Payments and payment reversals are append-only ledger entries. Cached totals never replace the ledger as financial truth.

## Online/offline boundary

Firestore may cache non-financial reads. Financial transactions fail offline and must be shown as unconfirmed until acknowledged by the server. A retry reuses its original payment document ID. A UPI deep link or displayed QR remains a payment request, not proof of receipt.

## Query and cost strategy

- Keep all tenant records below the business path.
- Query customers in pages; employees add `assignedEmployeeId == uid`.
- Store normalized `searchName`, normalized phone fields, customer code, `areaId`, and landmark tokens for targeted search.
- Finalize bills on demand once per customer/month.
- Query payments by business/user/month using collection-group indexes only for authorized Head reports.
- Maintain month/employee/area summary documents later for dashboards. Treat them as rebuildable projections.
- Avoid listeners over entire customer/payment collections.

## Trusted-backend boundary

Spark Phase 1 deliberately has no Cloud Functions dependency. Operations that require secret credentials, bank/payment verification, cross-document server aggregation, or privileged Auth administration must wait for an approved trusted backend. Cloud Functions deployment requires Blaze; it will not be enabled implicitly.
