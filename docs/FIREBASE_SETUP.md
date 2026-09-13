# Firebase setup and first-Head bootstrap

Android and Web are connected to the Spark project **PaperRouteDev** (`paperroutedev`). FlutterFire generated the platform configuration on 7 September 2026. The reviewed Phase 6 Firestore Rules and all 15 composite indexes are deployed; both replacement payment-history indexes are `READY`. No paid service or billing account was enabled.

The project creation, Email/Password provider, Firestore database, CLI login, FlutterFire configuration, first-Head bootstrap, and verified login are complete. Keep these steps as a recovery/reference guide.

## 1. Create the Spark project — complete

1. Open the [Firebase Console](https://console.firebase.google.com/).
2. Click **Create a project**.
3. Enter a name such as **PaperRoute Dev**. Firebase will propose a globally unique project ID; copy that ID for later.
4. Google Analytics is optional for this version. You can turn it off to keep setup simple.
5. Click **Create project**.
6. Leave the project on the **Spark (no-cost)** plan. Do not attach a billing account.

Use separate development and production projects before release. Do not use real customer data in the development project.

## 2. Enable email/password Authentication — complete

1. In the left menu open **Build → Authentication**.
2. Click **Get started**.
3. Open **Sign-in method**.
4. Select **Email/Password**.
5. Enable **Email/Password**. Leave passwordless email-link sign-in off for now.
6. Click **Save**.

## 3. Create Cloud Firestore — complete

1. Open **Build → Firestore Database**.
2. Click **Create database**.
3. Select **Standard edition** and **Production mode**.
4. Choose the region closest to the business and expected customers. For an India-only business, select an India region if the console offers it. This location cannot be changed later.
5. Click **Create**.

Production mode is intentional. The repository's tested rules will replace the initial deny rules only after review and explicit deployment approval.

## 4. Connect Flutter to the project — complete

From this repository in Terminal:

```sh
npx firebase login
dart pub global activate flutterfire_cli
"$HOME/.pub-cache/bin/flutterfire" configure
```

The FlutterFire CLI is already installed on this Mac. Its folder is not currently on the shell `PATH`, so the full path above is intentional. Alternatively, add `export PATH="$PATH:$HOME/.pub-cache/bin"` to `~/.zshrc`, reopen Terminal, and use `flutterfire configure`.

The configured command for this repository is:

```sh
PATH="$PWD/node_modules/.bin:$PATH" \
  "$HOME/.pub-cache/bin/flutterfire" configure \
  --project=paperroutedev \
  --account=your-firebase-account@example.com \
  --platforms=android,web \
  --android-package-name=in.paperroute.paper_route
```

Re-run it only when adding a platform or changing Firebase services. During interactive configuration:

1. Select the Firebase project ID `paperroutedev`.
2. Select **android** and **web**.
3. Accept the Android package name `in.paperroute.paper_route`.
4. Let the tool replace `lib/firebase_options.dart` and update platform configuration.

The generated Firebase options contain client identifiers, not Admin SDK secrets. Never download or add a service-account JSON key to the Flutter project.

The local alias is already set to `paperroutedev` in the ignored `.firebaserc`. To recreate it without deploying anything:

```sh
npx firebase use --add
```

Select the development project and name the alias `default`. This creates `.firebaserc`, which is intentionally ignored because it is environment-specific.

## 5. Verify and deploy Firestore access controls — complete

The emulator dependencies are already declared in `package.json`:

```sh
npm install
env JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  PATH="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin:$PATH" \
  npm run test:rules
flutter analyze
flutter test
```

All rules tests must pass. Do not change the rules to `allow read, write: if true`.

After explicit owner approval, the reviewed rules and indexes were deployed only to `paperroutedev` with:

```sh
npx firebase deploy \
  --only firestore:rules,firestore:indexes \
  --project paperroutedev \
  --account your-firebase-account@example.com
```

At the end of Phase 1, the active Firestore rules were read back from the Firebase Rules API and matched the repository exactly. The four index definitions were also read back from the Firestore Admin API, and every index build completed with state `READY`.

After explicit owner approval on 8 September 2026, the Phase 2 rule permitting an inactive user to read only their own membership was deployed with:

```sh
npx firebase deploy --only firestore:rules --project paperroutedev
```

Every other business read still requires active membership. The active rules were read back from the Firebase Rules API and matched the then-current `firestore.rules` exactly at SHA-256 `9856e3fb24d29b1d95328bf3cd2a3dbfbf82cf0ed1675957c4669b8977f2e712`. The post-deployment emulator suite passed all 18 security tests. Indexes and all unrelated Firebase services were unchanged.

### Phase 3 deployment and live smoke verification — complete

Before deployment, a read-only collection-group inventory found zero existing customer documents in the development tenant, so no legacy migration or customer rewrite was required. After explicit owner approval on 9 September 2026, only the reviewed Firestore Rules and indexes were deployed with:

```sh
npx firebase deploy \
  --only firestore:rules,firestore:indexes \
  --project paperroutedev
```

The active Rules API source matches `firestore.rules` at SHA-256 `b1e00abbad701e859b7fa70a7467ec0f327eeb9bd07ca3c2f25ea917f3eb663e`. All 11 composite indexes in `firestore.indexes.json` were matched through the Firestore Admin API and reached `READY`; no required or unexpected index remained. The complete post-deployment emulator suite passed all 26 Security Rules tests. Functions, Hosting, billing, and unrelated Firebase services were not changed.

An explicitly approved live Head smoke test created two development-only areas and one synthetic customer. It verified customer creation, listing, mobile-readable detail, name/phone/code/landmark search, area filtering, a cross-area transfer, an audited profile edit, archive, reactivation, and append-only history. The customer and both areas were left archived/inactive. Readback confirmed `locationConsent: false`, `coordinates: null`, `openingBalancePaise: 0`, ten retained audit records, and zero related subscriptions, bills, or payments.

### Phase 4 deployment and live smoke verification — complete

Before deployment, a read-only project-wide inventory found one compatible Phase 3 customer, one Head membership, and ten existing customer audits in `news-agency-01`. It found zero newspapers, legacy price overrides, price rules, subscriptions, versions, pauses, Phase 4 audits, or employee memberships. The existing customer matched the strict current schema, so no data migration or rewrite was needed.

After explicit owner approval on 9 September 2026, only `firestore:rules` and `firestore:indexes` were deployed to `paperroutedev`. The active Rules API release `cade41dd-63c5-4d40-b7a3-a09ebbe3aede` matches `firestore.rules` exactly at SHA-256 `ca6726d58cd3f1e86d2e3ae02ff3fe5bcd5daeaa8532969fbc167cca18fb17c2`. All 15 deployed index definitions match `firestore.indexes.json`, with all four new Phase 4 indexes and the previous 11 reporting `READY`. The post-deployment emulator suite passed all 34 security tests.

A read-only live check first used the existing verified Head session. The secure `news-agency-01` workspace, customer directory, archived synthetic customer detail, subscription empty/guard states, newspaper catalog, and pricing empty state loaded without Firestore permission errors.

After separate explicit approval, a minimal live-development smoke test created one synthetic customer, one synthetic area, and two synthetic newspapers. It verified normalized catalog search and pagination, profile editing, archive/reactivate behavior, effective-period and exact-date pricing, deterministic precedence, an audited price correction, multiple subscription schedules, quantities, pauses, resume, end, restart, and a Head-authorized customer-specific price. A restart regression fix ensures an ended subscription's historical `endDate` is never prefilled as the new planned end. Final readback found Alpha with three retained term versions, two closed pauses, eight subscription audits, and three retained price-rule revisions; Beta with one closed term version and two subscription audits. The customer and newspapers were archived and the area made inactive. No bill, payment, collection, UPI, or unrelated live record was created. Functions, Hosting, billing, and unrelated Firebase services were not deployed or enabled.

### Phase 5 Rules deployment and compatibility inventory — complete

Monthly billing is implemented locally with deterministic `bills/{YYYY-MM}` IDs, immutable daily line snapshots, per-month adjustment controls, a per-customer service-source revision lock, append-only Head adjustments and audits, assigned-employee bill reads, and deny-by-default financial writes. The real repository workflow passes against the local Auth and Firestore emulators. `firestore.indexes.json` is unchanged because Phase 5 reuses existing customer and pricing indexes and scopes bill queries to one customer.

On 12 September 2026, the owner-approved read-only inventory found zero finalized bills, line items, billing controls, billing sources, adjustments, and delivery exceptions; two ended subscriptions, four closed immutable subscription versions, two closed pauses, two archived newspapers, three retained price-rule revisions, and two archived customers with zero opening balances. Every existing source document matched the strict Phase 4/5 fields, identifiers, types, date semantics, and tenant path. The absence of `billingSources/service` is compatible: the first future authorized subscription or delivery-exception creation initializes it atomically, so no backfill is required.

Only `firestore:rules` was deployed to `paperroutedev`; indexes, Functions, Hosting, billing services, and unrelated resources were unchanged. The active Rules API source is ruleset `2175186a-b3e1-4dd5-a4ec-da3e2d643dc3` and matches local `firestore.rules` exactly at SHA-256 `9f788dab0b5d576cf79918d12149e5b4d57df0d1196a234bef9bc5f845f280f2`. The complete post-deployment emulator suite passed all 43 Rules/transaction tests. The verified Head session loaded the workspace, archived customer and subscription history, archived newspaper catalog, and monthly billing workspace without permission errors.

### Phase 5 synthetic live billing smoke verification — complete

After separate explicit approval, the verified Head created one development-only area, one synthetic customer with `locationConsent: false`, null coordinates and a ₹12.34 opening balance, and two synthetic newspapers. The November 2026 source history retained an every-day Alpha term for 1–15 November at quantity one, a closed 8–9 November pause, a Monday–Saturday Alpha term from 16 November at quantity two, and a Monday-only Beta term at quantity three with a Head-authorized ₹4.50 customer price. Catalog defaults, effective periods, and exact-date prices remained separate append-only records.

The read-only preview produced exactly 26 Alpha lines worth ₹213.00 and five Beta lines worth ₹67.50. Current charges were ₹280.50; the ₹12.34 opening balance and one audited −₹1.00 adjustment produced a ₹291.84 total due and 31 daily snapshots. The Head finalized deterministic bill `2026-11`; its detail retained the same header, per-newspaper counts and totals, adjustment, and immutable daily lines. Re-entering the preview route resolved to that existing bill without another write, while the emulator-backed concurrent-finalization test independently confirmed exactly one bill, line set, and finalization audit under simultaneous repository retries.

Cleanup ended both subscriptions on 30 November 2026, archived the customer and both newspapers, and made the synthetic area inactive. All subscription versions, pause, price rules, finalized financial snapshots, and audit records remain preserved. No payment, collection, UPI, employee, Phase 6, or unrelated live record was created. Final verification passed clean formatting, `flutter analyze`, all 85 Flutter tests, all 43 Firestore Rules/transaction tests, JSON/JavaScript validation, and the emulator-backed Chrome Phase 5 repository/screen integration test.

### Phase 6 implementation and deployment

Collections are implemented locally for cash, UPI, bank transfer, and controlled other methods. Confirmed payments and reversals are immutable append-only financial records; transaction-coupled `collectionState`, `billBalances`, and private `paymentStates` projections provide efficient current balances without reading all history. Payments support partial, repeated, oldest-bill-first, optional selected-bill, and two-bill allocation. Full and partial reversals are Head-only. The original payment and every finalized bill remain unchanged.

The connected UPI workflow stores only business UPI display configuration. Amount-specific and static UPI QR codes are payment requests, not proof: they create no ledger write and do not reduce outstanding. The collector must manually confirm observed receipt, and the UI displays success only after server readback of the complete transaction. Ambiguous retry recovery is bounded to read-only verification of the same immutable idempotency key.

The complete local Phase 6 suite covers domain arithmetic, all payment methods, UPI URI generation, QR non-confirmation, partial/multiple payments, selected and oldest-first allocation, concurrent duplicate confirmation, Head/employee access, pagination, immutable payments, partial/full reversal, overpayment/over-reversal denial, audit pairing, multi-month carry-forward, and opening-balance safety. The connected repository/screen workflow uses only the Auth and Firestore emulators with synthetic data.

The existing finalized bill `C-8744D64529294296A5FC0F8884740506/2026-11` received its separately reviewed trusted `billBalances/2026-11` and `collectionState/current` compatibility projections plus a deterministic migration audit. Its immutable bill, 31 lines, source audit, and ₹291.84 outstanding total were not changed.

The owner-approved deployment replaced only the two payment-history indexes, waited for both to become `READY`, and then released only the reviewed Phase 6 Firestore Rules. The deployed 15-index set matches `firestore.indexes.json`, and the active Rules match the local file byte-for-byte.

The live Head smoke test verified ₹291.84 outstanding, collection history, UPI settings, and an amount-specific ₹5.00 QR marked as a request rather than a receipt. Because no real money was received, the final receipt confirmation was deliberately cancelled. Cleanup restored empty disabled UPI defaults and re-archived the synthetic customer. Live Firestore retains zero payments, zero private payment states, and zero reversals; confirmed and reversed totals remain zero. Exactly four append-only audits record the temporary customer reactivation/archive and UPI enable/disable changes.

Confirmed-payment, duplicate-ID, allocation, and reversal behavior was verified only in `demo-paper-route`. The exact emulator regression starts at ₹291.84, creates immutable ₹10 cash and ₹5 UPI payments, rejects the duplicate cash ID, records ₹4, ₹6, and ₹5 reversals, and finishes at ₹15 confirmed, ₹15 reversed, and ₹291.84 outstanding with two payments, two private payment states, and three reversals. A live confirmed receipt remains intentionally unverified until actual receipt or a separately designed explicit test-only transaction mechanism is available.

## 6. Bootstrap the first Head securely — complete

The app intentionally has no public Head registration.

1. In Firebase Console open **Build → Authentication → Users**.
2. Click **Add user**.
3. Enter the Head's real login email and a temporary strong password.
4. Copy the created user's **User UID**.
5. Open **Firestore Database → Data → Start collection**.
6. Create collection `businesses` with a document ID such as `news-agency-01`.
7. Add these fields to the business document:
   - `businessId` (string): `news-agency-01`
   - `ownerId` (string): the copied UID
   - `name` (string): business name
   - `phone` (string): business phone
   - `createdAt` (timestamp): current time
   - `updatedAt` (timestamp): current time
8. Inside that business document create subcollection `members` and a document whose ID is the Head UID.
9. Add member fields:
   - `businessId` (string): `news-agency-01`
   - `uid` (string): Head UID
   - `email` (string): lowercase Head email
   - `displayName` (string): Head name
   - `phone` (string): Head phone
   - `role` (string): `head`
   - `status` (string): `active`
   - `permissions` (array): empty array
   - `areaIds` (array): empty array
   - `createdAt` and `updatedAt` (timestamp): current time
10. At the database root create collection `userProfiles`, document ID equal to the Head UID, with the same identity fields: `uid`, lowercase `email`, `displayName`, `phone`, `businessId`, `role: head`, `status: active`, `permissions: []`, `createdAt`, and `updatedAt`.

Sign in to the app. If Firebase marks the email unverified, use the app's **Resend email** action, open the email, then tap **I have verified my email**. Change the temporary password through **Forgot password?**.

## 7. Create employee invitations in PaperRoute

The signed-in Head now creates invitations from **Employees → Invite employee**. The Head selects only operational employee permissions and initial active areas. PaperRoute creates the invitation and its append-only audit record atomically, then displays the random invitation code once for secure sharing.

Give the employee the business ID and invitation code through a trusted channel. They use **I have an employee invitation**, create their own password, verify that exact email, and enter both values. The role remains fixed to `employee`; neither the invitation UI nor the accepting client can create a Head or select a role.

## 8. Run the real app

```sh
flutter run
```

Choose an Android device/emulator. The local Android toolchain is ready. iOS requires completing Xcode installation first.
