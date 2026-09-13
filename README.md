# PaperRoute

PaperRoute is an Android-first Flutter application for Indian newspaper agents. It is designed to manage multi-tenant businesses, employees, areas, customers, date-sensitive newspaper billing, and manual payment collection without requiring paid backend infrastructure for the first release.

## Current status

Phases 0 through 5 are complete in the development project. Monthly billing is locally tested, protected by the deployed Phase 5 Firestore Rules, and verified through an owner-approved synthetic live billing lifecycle in `paperroutedev`.

- Flutter project for Android, iOS, and web
- Firebase project `paperroutedev` connected for Android and Web
- feature-first clean architecture with Riverpod and GoRouter
- Firebase startup with a safe configuration-required screen
- email/password login, password reset, and email verification
- secure invitation-based employee activation
- Head/Employee routing from trusted Firestore membership data
- tenant-aware Firestore schema, indexes, and deny-by-default Security Rules
- Head business settings for the permitted name, phone, and address fields
- secure employee invitations, employee details, status, and permission management
- delivery-area creation/editing/archiving and authoritative employee-area assignment
- full customer creation, paginated directory, Firestore-native search, detail, editing, archive/reactivate, assignment, and transfer workflows
- permission-aware employee creation and editing of only active customers assigned to that employee in an authorized area
- mobile-readable house, address, landmark, location-note, contact, delivery, and billing-preference details
- optional GPS coordinates only when customer consent is recorded
- Head-authorized opening balances stored as integer paise and immutable after creation
- append-only audit records paired with every customer creation, profile change, lifecycle change, assignment, and transfer
- paginated newspaper catalog with name/code search, profile editing, and archive/reactivate lifecycle
- exact-date and effective-period price history with deterministic precedence and audited corrections
- multiple versioned subscriptions per customer with quantities, weekday schedules, pauses, resume, end, and restart
- assignment-, area-, and permission-scoped employee subscription management without pricing authority
- deterministic version-aware monthly previews, immutable finalization, signed adjustments, bill status, and paginated daily bill detail
- append-only payment/reversal ledger calculations
- Dart unit/widget tests and Firebase Emulator Security Rules tests

Collections/payment UI, dashboard metrics, reports, and exports are not yet implemented. Customer and newspaper records are archived rather than physically deleted, and subscription and bill history is retained. The dashboard exposes only connected workflows and identifies later modules honestly instead of displaying fabricated data.

Progress is tracked in [IMPLEMENTATION_CHECKLIST.md](IMPLEMENTATION_CHECKLIST.md).

## Technology

- Flutter 3.29.2 / Dart 3.7.2
- Firebase Authentication and Cloud Firestore
- Firebase Local Emulator Suite
- Riverpod for dependency injection and testable state
- GoRouter for declarative navigation
- Material 3

## Project structure

```text
lib/
  app/                    application shell and router
  core/                   configuration, dates, errors, and theme
  features/
    auth/                 auth data, domain policy, and UI
    business/             Head business settings
    employees/            invitations and member access management
    areas/                delivery areas and employee coverage
    customers/            paginated customer management and assignment
    newspapers/           paginated catalog and effective-date prices
    subscriptions/        versioned customer subscription lifecycle
    billing/              monthly planning, Firestore finalization, and UI
    collections/domain/   pure payment ledger calculation
    dashboard/            role-aware authenticated landing page
test/
  app/                    widget tests
  features/               Dart business-rule tests
  firestore/              emulator Security Rules tests
docs/                     architecture, schema, and setup guides
integration_test/         emulator-backed customer, catalog, and billing workflows
tool/                     local-demo emulator seed utilities
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/FIRESTORE_SCHEMA.md](docs/FIRESTORE_SCHEMA.md) for the design rationale.

## Local setup

1. Install Flutter stable, Android Studio, and VS Code with the Flutter extension.
2. Run `flutter doctor -v` and resolve Android issues.
3. Run `flutter pub get`.
4. Complete [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md).
5. Start an Android emulator and run `flutter run`.

For local Firebase-only development:

```sh
npm install
npx firebase emulators:start --project demo-paper-route --only auth,firestore
flutter run --dart-define=USE_FIREBASE_EMULATORS=true
```

The Android emulator connects to the host through `10.0.2.2`; web and Apple platforms use `127.0.0.1`. Emulator persistence is disabled deliberately so stale local data does not hide test failures.

## Tests and checks

```sh
dart format --output=none --set-exit-if-changed \
  lib test integration_test test_driver
flutter analyze
flutter test
env JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  PATH="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin:$PATH" \
  npm run test:rules
```

The last local verification completed on 13 September 2026 with clean formatting, no analyzer issues, 109 passing Dart/widget tests, 53 passing Firestore Rules/transaction tests, and a passing emulator-backed Chrome Phase 6 repository/screen integration test. The expanded suite covers immutable payment and reversal history, deterministic allocation projections, duplicate-ID recovery, partial collections, Head and employee authority, tenant isolation, UPI request safety, prior-balance carry-forward, and every earlier billing protection.

The Phase 3 integration test signs in as a synthetic verified Head, creates a complete customer with an opening balance, assigns the customer, edits the profile, archives and reactivates it, and verifies the audit history. It then signs in as the assigned synthetic employee, verifies assignment-scoped visibility and the hidden Head financial view, and saves an authorized location-note edit through the real repository and local Security Rules. All data is recreated in the local `demo-paper-route` emulators; no live Firebase customer records are created.

To reproduce that connected test, start the Auth and Firestore emulators in one terminal, then use another terminal:

```sh
npm run seed:phase3-emulator
flutter run -d chrome \
  --target integration_test/phase3_customer_smoke_test.dart \
  --dart-define=USE_FIREBASE_EMULATORS=true
```

The seed script is hard-coded to `127.0.0.1` and Firebase demo project `demo-paper-route`; it clears only those ephemeral emulator records.

The Phase 4 connected test uses the same local-only safeguards and exercises the real Firebase repositories through Auth and Firestore Rules:

```sh
npm run seed:phase4-emulator
flutter run -d chrome \
  --target integration_test/phase4_catalog_subscription_smoke_test.dart \
  --dart-define=USE_FIREBASE_EMULATORS=true
```

It creates synthetic catalog entries, verifies cursor pagination and search, appends default/period/exact pricing and a correction, manages multiple subscriptions, validates term versions and pause history, archives/reactivates a newspaper, and proves employee assignment, area, permission, and pricing restrictions. It does not connect to or modify `paperroutedev`.

The Phase 5 connected test builds on the same local-only seed and exercises real monthly billing repositories and local Rules:

```sh
npm run seed:phase5-emulator
flutter run -d chrome \
  --target integration_test/phase5_monthly_billing_smoke_test.dart \
  --dart-define=USE_FIREBASE_EMULATORS=true
```

It verifies catalog price precedence, a customer-specific price, a scheduled pause, one no-delivery exception, service-source revision advances, a signed adjustment, read-only preview, simultaneous idempotent finalization, immutable daily snapshots, pagination, prior-bill carry-forward, and employee denial. It never connects to `paperroutedev`.

The Phase 6 connected test uses the same local-only seed and exercises collections through real Auth, Firestore repositories, and Security Rules:

```sh
npm run seed:phase6-emulator
flutter run -d chrome \
  --target integration_test/phase6_collections_smoke_test.dart \
  --dart-define=USE_FIREBASE_EMULATORS=true
```

It verifies concurrent duplicate-ID confirmation, cash and UPI collection, amount-specific QR construction, immutable allocations, partial and full reversals, UPI settings, receipt and history screens, employee collection scope, and future-month carry-forward. All confirmed-payment records are synthetic and remain inside `demo-paper-route`.

## Security model

- All tenant data lives under `businesses/{businessId}`.
- Membership is checked from `businesses/{businessId}/members/{uid}` on every tenant request.
- Member documents are the client session's sole authority for role, status, and permissions; user profiles cannot grant access.
- A client cannot create a Head account or business.
- The first Head is bootstrapped by a trusted Firebase project administrator.
- Employee self-registration is useful only with a pending invite for the exact verified email.
- Invite consumption, membership creation, and user-profile creation happen in one transaction and are validated using `getAfter()`.
- Employees can read only customers assigned to their UID.
- Employee customer creation is limited to the employee's own UID, an area in their authoritative membership, and a zero opening balance.
- Employee profile edits require the explicit permission, an active assigned customer, immutable tenant/assignment/lifecycle/financial fields, and a paired audit record.
- Customer status changes, assignment transfers, and opening balances remain Head-only; customer documents cannot be physically deleted.
- Catalog and shared pricing writes are Head-only; employees can read active-tenant catalog data but cannot configure prices.
- Employee subscription writes require an active assigned customer, an authorized area, and `manageAssignedSubscriptions`; custom customer pricing remains Head-only.
- Newspaper price corrections and subscription term changes append replacement/version documents and paired audits instead of rewriting history.
- Bills, confirmed payments, reversals, delivery exceptions, and audit records are append-only.
- Payment document IDs are idempotency keys; a repeated create cannot duplicate a payment.
- The client-side `AccessPolicy` improves UX, but Firestore Rules are always authoritative.

Never put Firebase Admin SDK credentials or service-account keys in this repository or in the Flutter app.

## Billing rules

Money is represented as integer paise, never binary floating-point values. Billing uses calendar-only dates and snapshots one line per customer/subscription/service date. Price precedence is:

1. customer-specific subscription-version price
2. newspaper exact-date rule
3. newspaper effective-period rule
4. newspaper default price

Exact-date rules take precedence over periods. Active periods for the same newspaper cannot overlap, and ambiguous or missing inputs block finalization instead of using write order or an implicit zero. Catalog corrections supersede the old rule with a new audited revision. The planner honors version effective dates, delivery weekdays, inclusive pauses, no-delivery exceptions, quantity, prior balance, and signed adjustments. Duplicate customer/subscription/date charge keys stop calculation. Finalized bill and line snapshots are immutable, so later catalog or subscription changes cannot rewrite billed history.

## Payment and QR limitation

Generating or showing a UPI QR does not prove that payment succeeded. Only a collection explicitly marked `manuallyConfirmed` contributes to paid totals. Requested, pending, failed, and cancelled records do not reduce the balance. Corrections are new reversal records; historical payment documents are never edited or deleted.

Firestore transactions fail while offline. A future collection screen must keep the action visibly pending until the server acknowledges it and reuse the same payment ID when retrying.

## Spark-plan design

As of 7 September 2026, Standard edition Firestore's free quota includes one free database, 1 GiB stored data, 50,000 document reads/day, 20,000 writes/day, 20,000 deletes/day, and 10 GiB/month outbound transfer. Firebase Authentication on Spark documents a 3,000 daily-active-user limit for most providers, which is more than enough for the initial employee count. See the official [Firestore pricing guide](https://firebase.google.com/docs/firestore/pricing), [Firebase pricing page](https://firebase.google.com/pricing), and [Authentication limits](https://firebase.google.com/docs/auth/limits).

Cloud Functions deployment requires Blaze, even though usage has a free allowance. PaperRoute therefore does not depend on Functions in the Spark release. Secure employee onboarding uses verified email invitations and Firestore Rules. See the official [Functions quotas guidance](https://firebase.google.com/docs/functions/quotas).

Cost controls planned for later phases:

- paginated, tenant-constrained customer queries
- employee queries constrained by `assignedEmployeeId`
- on-demand monthly bill finalization rather than daily fan-out writes
- summary documents for dashboards, treated as caches rather than financial truth
- no broad listeners over all customers or payments
- one source-of-truth ledger with targeted month/date queries

## Deployment

The reviewed Phase 6 deny-by-default Firestore Rules and all 15 composite indexes are deployed to the development project `paperroutedev`. The active Rules API source matches `firestore.rules` exactly at SHA-256 `688fa3ab9ca980e47a3aca5dea14a3972c769a8111914d249283f1a7e83f7127`; both Phase 6 replacement payment-history indexes are `READY`, and the deployed set matches `firestore.indexes.json`. No production project or application binary has been deployed.

For any future production deployment, rerun the emulator tests and obtain explicit owner approval first:

```sh
npx firebase deploy --only firestore:rules,firestore:indexes --project <production-project-id>
flutter build appbundle --release
```

Before release, use separate development and production Firebase projects, review indexes, evaluate App Check, complete Android signing, test email templates, and rerun the full local Security Rules suite.

## Known limitations

- Hard deletion of areas is intentionally not exposed; an area is archived by setting it inactive so historical references remain intact.
- Phase 5 carries the previous finalized total due without subtracting payments; confirmed-payment settlement begins in Phase 6.
- Atomic finalization is intentionally capped at 475 daily lines per customer/month.
- Dashboard totals and report exports are not implemented.
- UPI QR presentation and manual confirmation UI are Phase 6.
- Fully offline financial writes are intentionally unsupported.
- iOS builds require the local Xcode installation to be completed.
- npm reports vulnerabilities in emulator-only development dependencies; these packages are not shipped in the Flutter application and should be refreshed as Firebase tooling updates.

## Roadmap

The remaining phases are listed in [IMPLEMENTATION_CHECKLIST.md](IMPLEMENTATION_CHECKLIST.md): collections/UPI, dashboards/reports, and production hardening.
