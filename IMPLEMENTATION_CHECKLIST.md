# PaperRoute implementation checklist

Updated: 16 September 2026

## Phase 0 — Environment and architecture

- [x] Inspect Flutter, Dart, Android SDK, Java, Node, npm, Git, and Firebase CLI
- [x] Initialize Flutter in the existing Git repository
- [x] Add Android, iOS, and web targets
- [x] Establish feature-first presentation/domain/data structure
- [x] Add Riverpod dependency injection and GoRouter navigation
- [x] Add Firebase/Emulator configuration files and Git hygiene
- [x] Document architecture, schema, Firebase setup, costs, and limitations
- [ ] Complete local Xcode installation (owner action; Android is ready)
- [x] Connect Android and Web to Firebase project `paperroutedev`

## Phase 1 — Firebase and authentication

- [x] Safe Firebase startup and configuration-required UI
- [x] Email/password login
- [x] Password-reset email flow
- [x] Email verification gate
- [x] Secure verified-email employee registration
- [x] Atomic invitation consumption and employee membership creation
- [x] Head/Employee routing from Firestore membership
- [x] Disabled-account gate and sign-out
- [x] Deny-by-default Firestore Security Rules
- [x] First-Head trusted bootstrap instructions
- [x] Rules tests for auth, roles, tenant isolation, invitations, and finance
- [x] Create the real Firebase project and enable Authentication/Firestore
- [x] Deploy reviewed strict rules and indexes to development after owner approval
- [x] Bootstrap and verify the first Head record and real dashboard login

## Phase 2 — Business, employees, and areas

- [x] Connected Head business settings form
- [x] Head employee invitation and management UI
- [x] Employee permissions and active/inactive controls
- [x] Area create/read/edit/archive and employee assignment
- [x] Existing-customer assignment and transfer foundation (no customer CRUD)
- [x] Audit entries for business, invitation, permission, area, and customer-assignment changes
- [x] Flutter workflow tests and Firestore Emulator tenant/permission tests
- [x] Emulator-backed Head write workflows and inactive-employee gate smoke test
- [x] Deploy and read back the Phase 2 inactive-member self-read rule after explicit owner approval

## Phase 3 — Customer management

- [x] Customer create/read/update with archive/reactivate semantics and full address details
- [x] Head and permission-aware employee creation
- [x] Area assignment, employee transfer, and append-only change history
- [x] Firestore-native search by ID, name, phone, area, and landmark
- [x] Cursor-based customer pagination without the former 100-record limit
- [x] Mobile-readable customer detail and house-identification view
- [x] Optional coordinates gated by recorded customer consent
- [x] Head-only opening-balance creation with integer paise and immutable follow-up writes
- [x] Flutter domain/widget tests, Firestore Rules tests, and emulator-backed Head/employee lifecycle smoke test
- [x] Deploy the reviewed Phase 3 rules and indexes to `paperroutedev` after explicit owner approval
- [x] Run an approved live-development smoke test after the Phase 3 rules and indexes are active

## Phase 4 — Newspapers and subscriptions

- [x] Newspaper catalog creation, paginated listing/search, editing, archive, and reactivation
- [x] Default, exact-date, and effective-period price management with audited corrections
- [x] Multiple versioned customer subscriptions
- [x] Start/end/restart, pause/resume, weekday schedule, quantity, and Head pricing exceptions
- [x] Preserve immutable subscription terms, pause, pricing, and audit history
- [x] Permission-aware Head/employee UI and repository workflows
- [x] Flutter domain/widget tests, Firestore Rules tests, and emulator-backed lifecycle smoke test
- [x] Deploy and read back the reviewed Phase 4 rules and indexes after explicit owner approval
- [x] Run the approved live-development Head catalog, pricing, subscription-lifecycle, restart, and archival-cleanup smoke test

## Phase 5 — Billing engine

- [x] Pure daily/date-specific monthly calculation
- [x] Start/end, pause, no-delivery, quantity, and price precedence tests
- [x] Duplicate charge protection
- [x] Prior balance and signed adjustment calculations
- [x] Firestore repositories and deterministic monthly bill IDs
- [x] Immutable finalized bill snapshots and paginated line items
- [x] Bill workspace, read-only preview, finalization, adjustment, and detail UI
- [x] Head/employee tenant and financial-mutation Security Rules coverage
- [x] Firestore transaction idempotency, concurrency, source-revision, and collection-membership conflict tests
- [x] Emulator-backed real repository billing lifecycle test
- [x] Read-only live compatibility inventory and owner-approved Rules deployment
- [x] Owner-approved synthetic live billing smoke test

## Phase 6 — Collections and QR/UPI

- [x] Pure partial-payment and reversal ledger calculations
- [x] Requested/pending payments excluded from confirmed totals
- [x] Duplicate payment ID rejection
- [x] Append-only payment/reversal Security Rules
- [x] Integer-paise collection projections integrated with Phase 5 prior balances
- [x] Deterministic oldest-bill-first allocation with optional selected-bill priority
- [x] Cash, UPI, bank-transfer, and controlled-other confirmation workflows
- [x] Head-only partial/full reversals with immutable original payments
- [x] Head UPI settings UI
- [x] Amount-specific UPI URI and QR display
- [x] Explicit manual receipt confirmation
- [x] Server-acknowledgement and bounded idempotency recovery UX
- [x] Customer and employee cursor-paginated collection history
- [x] Receipt, allocation detail, outstanding summary, and Head reversal UI
- [x] Flutter domain/widget tests and Firestore Emulator security/transaction tests
- [x] Emulator-backed Head/employee collection, carry-forward, QR, and reversal workflow
- [x] Trusted projection backfill, live compatibility verification, and owner-approved Rules/index deployment
- [x] Owner-approved live UPI configuration and amount-specific QR/request verification with safe cleanup
- [x] Exact ₹10/₹5 duplicate-ID, allocation, and ₹4/₹6/₹5 reversal smoke sequence in the Firebase Emulator
- [ ] Live confirmed-payment receipt verification (requires actual receipt or an explicit test-only transaction mechanism)

## Phase 7 — Dashboards and reports

- [x] Real Head metrics and alerts
- [x] Real Employee metrics and quick actions
- [x] Daily/monthly/employee/area collection reports
- [x] Outstanding and payment-status reports
- [x] Newspaper counts and billing totals
- [x] Paginated CSV export
- [x] Economical aggregate/projection strategy without a duplicate financial ledger
- [x] Primary Pricing Region and centralized Daily Pricing workflow
- [x] Head-only report routing, employee data scoping, and tenant-isolation Rules tests
- [x] Emulator-backed dashboard, report, filter, pagination, pricing, and immutable-bill workflow
- [x] Read-only live compatibility inventory and owner-approved Phase 7 Rules/index deployment
- [x] Owner-approved live Phase 7 read-only verification without synthetic writes

## Phase 8 — Production readiness

- [x] Complete emulator integration suite
- [x] Emulator-only performance/read-cost profile with 1,200 customers and representative operational records
- [x] Focused accessibility, large-text, tap-target, outdoor-readability, and financial-confirmation review
- [x] Separate Android development/production flavors, R8 release build, signing guard, and secure signing documentation
- [x] Fail-closed development/production Firebase configuration boundary and exact production setup plan
- [x] App Check evaluation and staged non-enforcing rollout plan
- [x] Privacy, retention, export, backup/recovery, credential rotation, and incident procedures
- [x] Focused tenant/role/privacy/immutable-ledger security audit; no Rules weakening required
- [x] Cost-conscious quota/error monitoring and scale-risk guidance
- [x] Reproducible CI gate for formatting, analysis, Flutter/Rules/index tests, hygiene scan, and Android release build
- [x] Production release, staged rollout, and app/Rules/index/data rollback runbook
- [x] Create and configure the separate production Firebase project (`paperroute-production`)
- [x] Create and protect the Android upload key and Play signing configuration
- [ ] Complete production App Check monitoring and later enforcement (requires release traffic and explicit approval)
- [ ] Complete iOS Xcode, Apple signing, and production FlutterFire configuration (deferred)
- [ ] Production deployment only after explicit owner approval

### Phase 8 local verification — 14 September 2026

- [x] 127 Dart files formatted; `flutter analyze` reported no issues
- [x] 128 Flutter unit/widget tests passed
- [x] 58 Firestore Rules/transaction tests passed
- [x] Phase 7 connected Auth/Firestore emulator browser workflow passed (2 test stages)
- [x] 3 production index/regression tests passed; exactly 61 unique indexes retained
- [x] JSON and JavaScript validation, `git diff --check`, and versionable-file secret/generated-artifact scan passed
- [x] Emulator-only scale profile passed with 1,200 customers and 5,525 operational documents
- [x] R8/resource-shrunk development release APK built successfully

### Phase 8 local verification — 16 September 2026 (post commit 8a02209)

- [x] 62 Firestore Rules/transaction tests passed (0 failed, 11 suites)
- [x] 128 Flutter unit/widget tests passed (0 failed)
- [x] 3 production index/regression tests passed
- [x] 231 versionable files scanned; repository hygiene passed
- [x] 127 Dart files formatted (0 changed); `flutter analyze` reported 0 issues
- [x] Branch `production-launch`; working tree clean except intentional untracked `android/app/src/production/google-services.json`
