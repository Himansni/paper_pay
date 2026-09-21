# PaperRoute production release runbook

This runbook is preparatory. `paperroutedev` remains development. Creating a
production project, deploying Firebase resources, enabling App Check
enforcement, publishing an app, or writing production data requires explicit
owner approval.

Create Agency Account adds a separate release gate. Do not make the entry point
operational against a live project until the two single-field collection-group
indexes are ready, the reviewed Rules are active, Blaze/Functions has explicit
founder approval, both callable Functions are deployed, and a synthetic
non-production smoke test passes. Existing manually bootstrapped Heads and
invited Employees require no migration.

## Environment boundary

| Environment | Firebase | Android application ID | App label |
|---|---|---|---|
| Development | `paperroutedev` | `in.paperroute.paper_route` | PaperRoute Dev |
| Production | separate project, not yet created | `in.paperroute.paper_route.prod` | PaperRoute |

`APP_ENV` defaults to `development`. Android builds additionally require the
matching flavor. Production startup rejects the development and emulator
project IDs and requires explicit production FlutterFire values. The production
Android build also fails if its Firebase file or signing configuration is
missing.

Recommended Firebase display name: **PaperRoute Production**. Recommended
project-ID candidate: **`paperroute-production-in`**. Firebase project IDs are
globally unique and permanent, so confirm availability and the final owner
suffix before creation. Record the approved ID; do not silently substitute one.

## One-time production Firebase setup (manual, after approval)

1. Create the separate project on the Spark plan. Do not enable Google
   Analytics or billing unless separately approved. Choose the Firestore region
   deliberately; it cannot be changed later. Prefer the Indian region nearest
   the users after checking current Firebase availability and pricing.
2. Enable only Email/Password Authentication and create Cloud Firestore in
   locked/production mode.
3. Register Android application `in.paperroute.paper_route.prod` and a separate
   Web application. Do not reuse either development app registration.
4. Run FlutterFire configuration for the approved production project, retaining
   the existing development config. Put the Android public client file at
   `android/app/src/production/google-services.json`. Supply the production Web
   and Android public client identifiers as the documented `PROD_FIREBASE_*`
   dart-defines; keep CI/release values in the protected release environment.
5. Run `node tool/validate_release_config.mjs --production`. It must report a
   distinct project and the exact production Android package.
6. Deploy `firestore:indexes` only, verify the project ID first, and wait until
   every required composite index is `READY`. Then deploy `firestore:rules`
   only. Read back and compare both local/deployed definitions. Never use a broad
   `firebase deploy` command.
7. Enable App Check providers in monitor-only mode following
   [APP_CHECK_ROLLOUT.md](APP_CHECK_ROLLOUT.md). Do not enforce yet.
8. Using trusted administrator access, create the initial Head Auth user and
   exact bootstrap documents from [FIREBASE_SETUP.md](FIREBASE_SETUP.md).
   Verify email and sign in before creating employees. Never add public Head
   registration.
9. As Head, set the Primary Pricing Region in Business Settings. Then configure
   catalog/prices; do not fabricate historic financial data.

## Android signing and versioning

`pubspec.yaml` supplies `versionName+versionCode` (currently `1.0.0+1`). Every
Play upload needs a unique, increasing build number. Update deliberately, for
example `flutter build appbundle --build-name=1.0.0 --build-number=2 ...`.

Create the upload key manually and store it outside the repository:

```sh
keytool -genkeypair -v -keystore /secure/private/path/paper-route-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias paper-route-upload
cp android/key.properties.example android/key.properties
```

Replace placeholders in the ignored `android/key.properties`. Back up the key
and credentials in an owner-controlled encrypted vault. Never send them through
Git, chat logs, or Firebase. Google Play App Signing is recommended; keep the
upload key separate from the Play-managed app-signing key.

Build only after production validation:

```sh
node tool/validate_release_config.mjs --production
flutter build appbundle --release --flavor production \
  --dart-define=APP_ENV=production \
  --dart-define=PROD_FIREBASE_PROJECT_ID=APPROVED_PROJECT_ID \
  --dart-define=PROD_FIREBASE_API_KEY=PUBLIC_WEB_API_KEY \
  --dart-define=PROD_FIREBASE_MESSAGING_SENDER_ID=SENDER_ID \
  --dart-define=PROD_FIREBASE_ANDROID_APP_ID=ANDROID_APP_ID
```

The signed AAB is under `build/app/outputs/bundle/productionRelease/`. R8 and
resource shrinking are enabled. Keep the generated mapping/symbol files with
the private release artifacts for diagnosis. An APK may be built with
`flutter build apk` for internal device testing; Play release uses AAB.

## Release gate and rollout

Run the CI-equivalent suite from a clean checkout. Confirm Firebase target,
rules hash, index readiness, version, signing certificate, app label/package,
and no secrets in the staged diff. Test a new synthetic tenant/customer on the
emulator first. On production, use the Head account for a read-only navigation
check, then obtain explicit approval for any synthetic write smoke test.

Use Play internal testing, then a small staged rollout. Stop rollout for auth or
permission regressions, financial mismatch, duplicate transaction, crash loop,
or unexplained read/write surge.

## Rollback

- App: halt the Play rollout. Android version codes cannot go backwards; build
  the last verified Git commit with a new higher build number and the same
  production configuration/signing key, verify it, and release it.
- Rules: check out the last verified rules file without resetting user work,
  verify the production target and diff, deploy only `firestore:rules`, then
  read back and compare the hash.
- Indexes: first restore application/rules compatibility. Re-add any required
  previous index and wait for `READY` before removing a replacement. Index
  deletion is not an instant rollback.
- Data: never roll back immutable bills, payments, reversals, pricing revisions,
  subscription versions, or audits by overwriting/deleting them. Quarantine the
  affected workflow and use an approved compensating record or trusted,
  documented migration.

iOS release remains blocked until Xcode, Apple signing, bundle registration, and
the iOS FlutterFire configuration are completed and verified on macOS.

# Agency-registration legal approval

Final Terms and Privacy copy requires founder/legal approval before enabling agency registration in any shipped release.
