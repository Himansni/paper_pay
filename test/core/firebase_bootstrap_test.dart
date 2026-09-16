import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/config/firebase_bootstrap.dart';

void main() {
  group('FirebaseBootstrap', () {
    test(
      'App Check activation failure is non-blocking and does not fail startup',
      () async {
        var appCheckAttempted = false;

        final startup = await FirebaseBootstrap.initialize(
          initializeFirebase: ({required options}) async {
            // Simulated successful Firebase core initialization
          },
          shouldActivateAppCheckOverride: true,
          activateAppCheck: ({required androidProvider}) async {
            appCheckAttempted = true;
            expect(androidProvider, AndroidProvider.playIntegrity);
            throw Exception('Play Integrity unavailable on device');
          },
        );

        expect(appCheckAttempted, isTrue);
        expect(startup.isReady, isTrue);
        expect(startup.message, isNull);
      },
    );

    test(
      'successful App Check activation keeps startup ready with Play Integrity',
      () async {
        AndroidProvider? capturedProvider;

        final startup = await FirebaseBootstrap.initialize(
          initializeFirebase: ({required options}) async {
            // Simulated successful Firebase core initialization
          },
          shouldActivateAppCheckOverride: true,
          activateAppCheck: ({required androidProvider}) async {
            capturedProvider = androidProvider;
          },
        );

        expect(capturedProvider, AndroidProvider.playIntegrity);
        expect(startup.isReady, isTrue);
        expect(startup.message, isNull);
      },
    );

    test('core Firebase initialization failure remains fail-closed', () async {
      var appCheckAttempted = false;

      final startup = await FirebaseBootstrap.initialize(
        initializeFirebase: ({required options}) async {
          throw Exception('Firebase configuration invalid');
        },
        shouldActivateAppCheckOverride: true,
        activateAppCheck: ({required androidProvider}) async {
          appCheckAttempted = true;
        },
      );

      expect(appCheckAttempted, isFalse);
      expect(startup.isReady, isFalse);
      expect(
        startup.message,
        contains('Firebase is not configured for this build'),
      );
    });
  });
}
