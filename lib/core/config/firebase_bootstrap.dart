import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:paper_route/core/config/app_environment.dart';

/// Result of starting Firebase. Configuration errors are shown as a safe,
/// actionable setup screen instead of crashing before the first frame.
class FirebaseStartup {
  const FirebaseStartup._({required this.isReady, this.message});

  const FirebaseStartup.ready() : this._(isReady: true);

  const FirebaseStartup.configurationRequired(String message)
    : this._(isReady: false, message: message);

  final bool isReady;
  final String? message;
}

/// Initializes the selected live Firebase project or an explicitly requested
/// local demo project. Development is the safe default; production fails
/// closed unless its distinct build flavor and public client options agree.
abstract final class FirebaseBootstrap {
  // This is a compile-time flag, so emulator use must be chosen deliberately
  // when launching the app rather than toggled by an end user at runtime.
  static const bool _useEmulators = bool.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
  );

  static Future<FirebaseStartup> initialize({
    @visibleForTesting
    Future<void> Function({required AndroidProvider androidProvider})?
    activateAppCheck,
    @visibleForTesting
    Future<void> Function({required FirebaseOptions options})?
    initializeFirebase,
    @visibleForTesting bool? shouldActivateAppCheckOverride,
  }) async {
    try {
      // BEGINNER NOTE:
      // Emulator mode and live-project mode share the same repositories. The
      // only difference is which Firebase endpoints are selected here.
      if (_useEmulators) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            // Auth Web validates the API-key shape before routing requests to
            // the local emulator. This syntactically valid key is disposable
            // and is never used against a live Firebase project.
            apiKey: 'AIzaSy000000000000000000000000000000000',
            appId: '1:1234567890:web:paper-route-demo',
            messagingSenderId: '1234567890',
            projectId: 'demo-paper-route',
          ),
        );
        await _connectToEmulators();
      } else {
        // AppEnvironmentConfig validates the flavor/project pairing before a
        // live Firebase connection is allowed.
        final options = AppEnvironmentConfig.currentOptions();
        if (initializeFirebase != null) {
          await initializeFirebase(options: options);
        } else {
          await Firebase.initializeApp(options: options);
        }
        await _initializeProductionAppCheck(
          activateAppCheck: activateAppCheck,
          shouldActivateOverride: shouldActivateAppCheckOverride,
        );
      }
      return const FirebaseStartup.ready();
    } on Object catch (error) {
      // Configuration failures become an explicit startup state. This avoids
      // continuing with partially initialized security-sensitive services.
      return FirebaseStartup.configurationRequired(
        'Firebase is not configured for this build. Complete the steps in '
        'docs/FIREBASE_SETUP.md, then restart the app.\n\nDetails: $error',
      );
    }
  }

  static Future<void> _connectToEmulators() async {
    // Android emulators reach the host computer through 10.0.2.2; desktop and
    // browser tests can use the ordinary loopback address.
    final host =
        defaultTargetPlatform == TargetPlatform.android
            ? '10.0.2.2'
            : '127.0.0.1';
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  }

  static Future<void> _initializeProductionAppCheck({
    Future<void> Function({required AndroidProvider androidProvider})?
    activateAppCheck,
    bool? shouldActivateOverride,
  }) async {
    final shouldActivate =
        shouldActivateOverride ??
        AppEnvironmentConfig.shouldActivateAppCheck(
          environment: AppEnvironmentConfig.current,
          platform: defaultTargetPlatform,
          isWeb: kIsWeb,
          useEmulators: _useEmulators,
        );
    if (!shouldActivate) {
      return;
    }

    // BEGINNER NOTE:
    // Firebase Auth identifies the signed-in user. App Check is separate: it
    // helps Firebase recognize requests coming from a genuine app installation.
    try {
      if (activateAppCheck != null) {
        await activateAppCheck(androidProvider: AndroidProvider.playIntegrity);
      } else {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
        );
      }
    } on Object catch (error) {
      // While App Check enforcement is OFF (monitoring only), token acquisition
      // failure must not block application startup or Firebase services.
      debugPrint(
        'Warning: Firebase App Check activation failed in monitoring mode: $error',
      );
    }
  }
}
