# Firebase setup and first-Head bootstrap

Android and Web are connected to the Spark project **PaperRouteDev** (`paperroutedev`). FlutterFire generated the platform configuration on 7 September 2026. After explicit owner approval, the repository's tested Firestore rules and four composite indexes were deployed to that development project. No paid service or billing account was enabled.

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
