import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:paper_route/firebase_options.dart';

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

/// Initializes the real Firebase project or an explicitly requested local
/// demo project. Production is always the default.
abstract final class FirebaseBootstrap {
  static const bool _useEmulators = bool.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
  );

  static Future<FirebaseStartup> initialize() async {
    try {
      if (_useEmulators) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'demo-api-key',
            appId: '1:1234567890:web:paper-route-demo',
            messagingSenderId: '1234567890',
            projectId: 'demo-paper-route',
          ),
        );
        await _connectToEmulators();
      } else {
        // flutterfire configure replaces the checked-in placeholder with the
        // non-secret identifiers for each selected platform.
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      return const FirebaseStartup.ready();
    } on Object catch (error) {
      return FirebaseStartup.configurationRequired(
        'Firebase is not configured for this build. Complete the steps in '
        'docs/FIREBASE_SETUP.md, then restart the app.\n\nDetails: $error',
      );
    }
  }

  static Future<void> _connectToEmulators() async {
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
}
