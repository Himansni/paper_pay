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

Every authenticated route re-enters `AuthGate`. Only an active Head membership can reach business settings, employee management, or area management. Customer directory, create, detail, and edit routes admit active employees, but the presentation policy and Firestore Rules independently enforce permissions, assigned areas, and assigned-customer access. An employee who enters a Head-only URL is returned to their own dashboard.

## Authentication boundary

Firebase Authentication proves identity. Firestore membership proves authorization. The joined `AppUser` has:

- Firebase UID and verified email
- business ID
- fixed role (`head` or `employee`)
- active/inactive status
- permission keys
- authoritative assigned area IDs

The membership document is authoritative for role, status, and permissions. A user profile helps locate the business and provides fallback display details, but missing membership data always produces pending access rather than inheriting profile privileges.

The mobile app does not create Heads. A trusted Firebase project administrator creates the first Head. Heads later create employee invitations, never employee Firebase passwords. Employees create their own passwords, verify ownership of the exact invited email, then atomically consume the invite.

This Spark-compatible design avoids placing Admin SDK credentials in the client. A future trusted backend can replace invitation provisioning if automatic user administration becomes important.

## Customer-management boundary

The customer feature owns a plain-Dart model and repository contract, a Firebase repository, Riverpod providers, and route pages for directory, form, detail, assignment, lifecycle, and audit history. Repository transactions validate active areas and employee coverage before paired customer/audit writes. The document ID is the permanent customer code; UUID collision attempts become unauthorized updates and therefore cannot overwrite an existing record.

Opening balances are parsed to integer paise and may be set only by a Head during customer creation. They cannot be changed by profile, assignment, or lifecycle operations. The legacy customer-level `subscriptionStatus: notConfigured` field remains an immutable compatibility marker so deployed Phase 3 customer documents require no migration; real Phase 4 state is derived from the customer's subscription subcollection.

Employees can create only self-assigned customers in member-authorized areas when they hold `addCustomers`. They can edit only profile fields of active customers currently assigned to them when they hold `editAssignedCustomers`. The client policy makes unavailable actions clear, while the deployed Phase 3 Rules remain the authority.

## Catalog, pricing, and subscription boundary

The newspaper feature owns tenant-scoped catalog records with stable generated codes, normalized name search, status-based cursor pagination, and append-only audits. A newspaper's initial default price is immutable. Later exact-date and effective-period prices are separate records, and a correction creates a replacement revision while marking the prior record superseded in the same transaction. Exact-date rules outrank periods, and periods cannot overlap. A newspaper-level audit lock makes the conflict check safe against concurrent writers.

Each customer can hold one stable subscription series per newspaper. The series points to an immutable current terms version; quantity, delivery weekdays, effective dates, and optional Head-authorized custom price changes create a new version and close the old one. Pause records are separate, an open pause can be resumed, and ended series can be restarted with a new version. No workflow physically deletes catalog, pricing, subscription, version, pause, or audit history.

Heads control catalog, shared prices, and every customer subscription in their tenant. Employees can read the active catalog, but subscription writes require `manageAssignedSubscriptions`, the employee's current customer assignment, and membership coverage of the customer's current area. Employees cannot set or change custom prices. Firestore Rules enforce the same boundaries independently of route guards and widget visibility.

## Billing boundary

`MonthlyBillingEngine` preserves the original pure calculation API. The Phase 5 `MonthlyBillPlanner` adds immutable subscription-version and pricing-source references while remaining a pure function over calendar-only dates and integer paise. It produces one daily snapshot per customer/subscription/service date with a deterministic key such as `C-1:paper-1:2026-05-03`. Missing newspapers/prices, ambiguous active prices, overlapping term versions, and more than 475 lines block finalization explicitly.

`FirebaseBillingRepository` reads only one customer and month on demand. It resolves immutable term versions, pauses, no-delivery exceptions, exact/period/default prices, customer-specific version prices, prior bills, and signed adjustments. Preview performs no writes. Finalization rechecks customer, subscription, newspaper, per-customer service-source revision, and adjustment-control locks inside a transaction, then creates the deterministic `bills/{YYYY-MM}` header, immutable `lineItems`, a finalized month control, and one append-only audit. Subscription creation and no-delivery exception creation advance `billingSources/service` atomically, so a new collection member appearing after preview is detected even though Firestore transactions cannot query-lock a collection. A repeated or simultaneous request returns the existing deterministic bill and cannot append a duplicate audit.

The bill header stores compact customer and newspaper subtotal snapshots; individual daily lines live in a paginated subcollection to avoid unbounded header growth. Bills and lines cannot be updated or deleted. Head-only signed adjustments are append-only and advance the month control transactionally. A correction to a finalized month is recorded against a later open month with an optional reference to the earlier bill rather than rewriting history.

The first bill uses the customer's immutable `openingBalancePaise` as its prior-balance source. A later bill uses the most recent earlier finalized bill's `totalDuePaise`; it does not add the opening balance again. Until Phase 6, no payment subtraction is performed. Phase 6 must replace that carried outstanding input with the earlier bill total less only server-acknowledged confirmed payments plus append-only reversals/corrections; a pending QR or UPI request must never reduce it.

## Online/offline boundary

Firestore may cache non-financial reads. Financial transactions fail offline and must be shown as unconfirmed until acknowledged by the server. A retry reuses its original payment document ID. A UPI deep link or displayed QR remains a payment request, not proof of receipt.

## Query and cost strategy

- Keep all tenant records below the business path.
- Query customers in cursor pages ordered by normalized name and document ID; employees always add `assignedEmployeeId == uid`.
- Query newspapers in cursor pages ordered by normalized name and document ID; code search uses tenant/status-constrained equality.
- Query only one customer's subscription subcollection and one newspaper's bounded price history at a time; never load all customers to render either workflow.
- Store normalized name/phone/landmark fields and bounded prefix tokens. Search uses exact customer-code equality, `array-contains` for name/phone/landmark prefixes, and an `areaId` equality filter without downloading the whole tenant.
- Finalize bills on demand once per customer/month.
- Query payments by business/user/month using collection-group indexes only for authorized Head reports.
- Maintain month/employee/area summary documents later for dashboards. Treat them as rebuildable projections.
- Avoid listeners over entire customer/payment collections.

## Trusted-backend boundary

Spark Phase 1 deliberately has no Cloud Functions dependency. Operations that require secret credentials, bank/payment verification, cross-document server aggregation, or privileged Auth administration must wait for an approved trusted backend. Cloud Functions deployment requires Blaze; it will not be enabled implicitly.
