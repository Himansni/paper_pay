import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:paper_route/firebase_options.dart';

enum AppEnvironment { development, production }

/// Compile-time environment boundary for Firebase and release flavors.
///
/// Development remains the safe default. Production must be requested
/// explicitly and supply its own public FlutterFire client identifiers.
abstract final class AppEnvironmentConfig {
  static const developmentProjectId = 'paperroutedev';
  static const emulatorProjectId = 'demo-paper-route';

  static const _environmentName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const _productionProjectId = String.fromEnvironment(
    'PROD_FIREBASE_PROJECT_ID',
  );
  static const _productionApiKey = String.fromEnvironment(
    'PROD_FIREBASE_API_KEY',
  );
  static const _productionMessagingSenderId = String.fromEnvironment(
    'PROD_FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _productionAndroidAppId = String.fromEnvironment(
    'PROD_FIREBASE_ANDROID_APP_ID',
  );
  static const _productionWebAppId = String.fromEnvironment(
    'PROD_FIREBASE_WEB_APP_ID',
  );
  static const _productionAuthDomain = String.fromEnvironment(
    'PROD_FIREBASE_AUTH_DOMAIN',
  );
  static const _productionStorageBucket = String.fromEnvironment(
    'PROD_FIREBASE_STORAGE_BUCKET',
  );
  static const _productionMeasurementId = String.fromEnvironment(
    'PROD_FIREBASE_MEASUREMENT_ID',
  );

  static AppEnvironment get current => parseEnvironment(_environmentName);

  static AppEnvironment parseEnvironment(String value) => switch (value) {
    'development' => AppEnvironment.development,
    'production' => AppEnvironment.production,
    _ =>
      throw StateError(
        'APP_ENV must be either development or production; received "$value".',
      ),
  };

  static FirebaseOptions currentOptions() {
    final environment = current;
    validateSelection(
      environment: environment,
      flavor: appFlavor,
      projectId:
          environment == AppEnvironment.development
              ? developmentProjectId
              : _productionProjectId,
      requireFlavorMatch:
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    );
    if (environment == AppEnvironment.development) {
      final options = DefaultFirebaseOptions.currentPlatform;
      validateSelection(
        environment: environment,
        flavor: appFlavor,
        projectId: options.projectId,
        requireFlavorMatch: false,
      );
      return options;
    }
    return _productionOptions();
  }

  static void validateSelection({
    required AppEnvironment environment,
    required String? flavor,
    required String projectId,
    bool requireFlavorMatch = true,
  }) {
    final expectedFlavor = environment.name;
    if (requireFlavorMatch && flavor != expectedFlavor) {
      throw StateError(
        'Build flavor "$flavor" cannot use APP_ENV=$expectedFlavor. '
        'Build Android with --flavor $expectedFlavor.',
      );
    }
    if (environment == AppEnvironment.development &&
        projectId != developmentProjectId) {
      throw StateError(
        'Development builds must use Firebase project $developmentProjectId.',
      );
    }
    if (environment == AppEnvironment.production &&
        (projectId.isEmpty ||
            projectId == developmentProjectId ||
            projectId == emulatorProjectId)) {
      throw StateError(
        'Production builds require a separate non-development Firebase project.',
      );
    }
  }

  /// Determines whether Firebase App Check should be activated.
  ///
  /// Per security rollout policy, App Check token acquisition is enabled only
  /// for live production Android builds using Play Integrity. Emulator runs,
  /// development builds, Web, and iOS do not activate production App Check.
  static bool shouldActivateAppCheck({
    required AppEnvironment environment,
    required TargetPlatform platform,
    required bool isWeb,
    required bool useEmulators,
  }) {
    if (useEmulators) {
      return false;
    }
    return environment == AppEnvironment.production &&
        !isWeb &&
        platform == TargetPlatform.android;
  }

  static FirebaseOptions _productionOptions() {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'Production Firebase is configured only for Android and Web. '
        'Complete the platform-specific FlutterFire setup before building this target.',
      );
    }
    final appId = kIsWeb ? _productionWebAppId : _productionAndroidAppId;
    final missing = <String>[
      if (_productionProjectId.isEmpty) 'PROD_FIREBASE_PROJECT_ID',
      if (_productionApiKey.isEmpty) 'PROD_FIREBASE_API_KEY',
      if (_productionMessagingSenderId.isEmpty)
        'PROD_FIREBASE_MESSAGING_SENDER_ID',
      if (appId.isEmpty)
        kIsWeb ? 'PROD_FIREBASE_WEB_APP_ID' : 'PROD_FIREBASE_ANDROID_APP_ID',
      if (kIsWeb && _productionAuthDomain.isEmpty) 'PROD_FIREBASE_AUTH_DOMAIN',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Production Firebase configuration is incomplete: ${missing.join(', ')}.',
      );
    }
    return FirebaseOptions(
      apiKey: _productionApiKey,
      appId: appId,
      messagingSenderId: _productionMessagingSenderId,
      projectId: _productionProjectId,
      authDomain: kIsWeb ? _productionAuthDomain : null,
      storageBucket:
          _productionStorageBucket.isEmpty ? null : _productionStorageBucket,
      measurementId:
          kIsWeb && _productionMeasurementId.isNotEmpty
              ? _productionMeasurementId
              : null,
    );
  }
}
