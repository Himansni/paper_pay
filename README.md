# PaperRoute

PaperRoute is an Android-first Flutter application for Indian newspaper agents. It is designed to manage multi-tenant businesses, employees, areas, customers, date-sensitive newspaper billing, and manual payment collection without requiring paid backend infrastructure for the first release.

## Current status

Phases 0 and 1 are complete. Phase 2 connected Head operations are implemented and locally verified:

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
- assignment and transfer of real existing customers, with no placeholder customer creation
- append-only audit records for every Phase 2 write workflow
- deterministic monthly billing domain engine
- append-only payment/reversal ledger calculations
- Dart unit/widget tests and Firebase Emulator Security Rules tests

Full customer CRUD, catalog, billing finalization, collections, dashboard metrics, reports, and exports are not yet implemented. The dashboard exposes only connected workflows and identifies later modules honestly instead of displaying fabricated data.

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
    customers/            existing-customer assignment foundation
    billing/domain/       pure monthly billing calculation
    collections/domain/   pure payment ledger calculation
    dashboard/            role-aware authenticated landing page
test/
  app/                    widget tests
  features/               Dart business-rule tests
  firestore/              emulator Security Rules tests
docs/                     architecture, schema, and setup guides
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
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
env JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  PATH="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin:$PATH" \
  npm run test:rules
```

The last local verification completed on 8 September 2026 with no analyzer issues, 29 passing Dart/widget tests, and 18 passing Firestore Rules tests. The Rules suite covers unauthenticated denial, tenant isolation, assigned-customer access, role escalation denial, pricing denial, append-only payments and audits, verified invitation acceptance, permitted Head business/member/area writes, employee restrictions, customer transfer visibility, and inactive-account isolation.

An emulator-backed app smoke test also signed in as a synthetic Head and exercised the real repositories for business updates, area creation, employee-area assignment, employee permission/status changes, invitation creation/revocation, existing-customer assignment, and audit creation. A synthetic disabled employee then reached only the inactive-account gate. The live development project was inspected read-only and no live test records were created.

## Security model

- All tenant data lives under `businesses/{businessId}`.
- Membership is checked from `businesses/{businessId}/members/{uid}` on every tenant request.
- Member documents are the client session's sole authority for role, status, and permissions; user profiles cannot grant access.
- A client cannot create a Head account or business.
- The first Head is bootstrapped by a trusted Firebase project administrator.
- Employee self-registration is useful only with a pending invite for the exact verified email.
- Invite consumption, membership creation, and user-profile creation happen in one transaction and are validated using `getAfter()`.
- Employees can read only customers assigned to their UID.
- Bills, confirmed payments, reversals, delivery exceptions, and audit records are append-only.
- Payment document IDs are idempotency keys; a repeated create cannot duplicate a payment.
- The client-side `AccessPolicy` improves UX, but Firestore Rules are always authoritative.

Never put Firebase Admin SDK credentials or service-account keys in this repository or in the Flutter app.

## Billing rules

Money is represented as integer paise, never binary floating-point values. Billing uses calendar-only dates and snapshots one line per customer/subscription/service date. Price precedence is:

1. customer date-specific exception
2. subscription fixed price
3. newspaper date override
4. newspaper default price

The engine honors subscription start/end dates, inclusive pauses, no-delivery exceptions, quantity, prior balance, and signed adjustments. Duplicate customer/subscription/date charge keys stop calculation. Finalized bill line snapshots must be stored so future catalog changes cannot rewrite history.

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

The deny-by-default Firestore rules and four composite indexes are deployed to the development project `paperroutedev`. After explicit owner approval on 8 September 2026, the Phase 2 inactive-member self-read rule was deployed with `--only firestore:rules`; indexes and all other Firebase services were unchanged. The active Rules API source matches `firestore.rules` exactly at SHA-256 `9856e3fb24d29b1d95328bf3cd2a3dbfbf82cf0ed1675957c4669b8977f2e712`. No production project or application binary has been deployed.

For any future production deployment, rerun the emulator tests and obtain explicit owner approval first:

```sh
npx firebase deploy --only firestore:rules,firestore:indexes --project <production-project-id>
flutter build appbundle --release
```

Before release, use separate development and production Firebase projects, review indexes, evaluate App Check, complete Android signing, test email templates, and rerun the full local Security Rules suite.

## Known limitations

- Full customer creation/editing remains Phase 3; the Phase 2 assignment screen intentionally operates only on existing records.
- The assignment screen currently reads at most 100 customers and needs pagination before the 1,000-customer performance milestone.
- Hard deletion of areas is intentionally not exposed; an area is archived by setting it inactive so historical references remain intact.
- Billing and ledger engines are tested but are not yet connected to Firestore screens.
- Dashboard totals and report exports are not implemented.
- UPI QR presentation and manual confirmation UI are Phase 6.
- Fully offline financial writes are intentionally unsupported.
- iOS builds require the local Xcode installation to be completed.
- npm reports vulnerabilities in emulator-only development dependencies; these packages are not shipped in the Flutter application and should be refreshed as Firebase tooling updates.

## Roadmap

The remaining phases are listed in [IMPLEMENTATION_CHECKLIST.md](IMPLEMENTATION_CHECKLIST.md): full customer operations, newspapers/subscriptions, persisted billing, collections/UPI, dashboards/reports, then production hardening.
