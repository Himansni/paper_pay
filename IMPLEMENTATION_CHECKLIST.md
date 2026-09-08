# PaperRoute implementation checklist

Updated: 8 September 2026

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

- [ ] Customer CRUD with full address and landmark details
- [ ] Head and permission-aware employee creation
- [ ] Assignment and transfer history
- [ ] Search by ID, name, phone, area, and landmark
- [ ] Customer detail operational view
- [ ] Optional consented map coordinates

## Phase 4 — Newspapers and subscriptions

- [ ] Newspaper catalog CRUD
- [ ] Default and date-specific price management
- [ ] Multiple customer subscriptions
- [ ] Start/end, pause/resume, quantity, and pricing exceptions
- [ ] Preserve subscription history

## Phase 5 — Billing engine

- [x] Pure daily/date-specific monthly calculation
- [x] Start/end, pause, no-delivery, quantity, and price precedence tests
- [x] Duplicate charge protection
- [x] Prior balance and signed adjustment calculations
- [ ] Firestore repositories and deterministic monthly bill IDs
- [ ] Immutable finalized bill snapshots and line items
- [ ] Bill review/finalization UI
- [ ] Firestore transaction integration tests

## Phase 6 — Collections and QR/UPI

- [x] Pure partial-payment and reversal ledger calculations
- [x] Requested/pending payments excluded from confirmed totals
- [x] Duplicate payment ID rejection
- [x] Append-only payment/reversal Security Rules
- [ ] Head UPI settings UI
- [ ] Amount-specific UPI URI and QR display
- [ ] Explicit manual receipt confirmation
- [ ] Server-acknowledgement and retry UX
- [ ] Customer and employee collection history

## Phase 7 — Dashboards and reports

- [ ] Real Head metrics and alerts
- [ ] Real Employee metrics and quick actions
- [ ] Daily/monthly/employee/area collection reports
- [ ] Outstanding and payment-status reports
- [ ] Newspaper counts and billing totals
- [ ] Paginated CSV export
- [ ] Economical summary projection strategy

## Phase 8 — Production readiness

- [ ] Complete emulator integration suite
- [ ] Performance/read-cost profiling with 1,000+ customers
- [ ] Accessibility and outdoor-readability review
- [ ] Android signing and release flavors
- [ ] Separate development and production Firebase projects
- [ ] App Check evaluation and rollout
- [ ] Privacy, retention, backup, and incident procedures
- [ ] Production deployment only after explicit owner approval
