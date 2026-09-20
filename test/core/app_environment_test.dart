import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/config/app_environment.dart';

void main() {
  group('AppEnvironmentConfig', () {
    test('accepts only explicit known environment names', () {
      expect(
        AppEnvironmentConfig.parseEnvironment('development'),
        AppEnvironment.development,
      );
      expect(
        AppEnvironmentConfig.parseEnvironment('production'),
        AppEnvironment.production,
      );
      expect(
        () => AppEnvironmentConfig.parseEnvironment('prod'),
        throwsStateError,
      );
    });

    test('development cannot point away from PaperRouteDev', () {
      expect(
        () => AppEnvironmentConfig.validateSelection(
          environment: AppEnvironment.development,
          flavor: 'development',
          projectId: 'some-other-project',
        ),
        throwsStateError,
      );
    });

    test('production cannot point to development or emulator projects', () {
      for (final projectId in const ['paperroutedev', 'demo-paper-route', '']) {
        expect(
          () => AppEnvironmentConfig.validateSelection(
            environment: AppEnvironment.production,
            flavor: 'production',
            projectId: projectId,
          ),
          throwsStateError,
        );
      }
    });

    test('Android flavor and environment must agree', () {
      expect(
        () => AppEnvironmentConfig.validateSelection(
          environment: AppEnvironment.production,
          flavor: 'development',
          projectId: 'paperroute-production-in',
        ),
        throwsStateError,
      );
      expect(
        () => AppEnvironmentConfig.validateSelection(
          environment: AppEnvironment.production,
          flavor: 'production',
          projectId: 'paperroute-production-in',
        ),
        returnsNormally,
      );
    });

    test('activates App Check only for live production Android', () {
      expect(
        AppEnvironmentConfig.shouldActivateAppCheck(
          environment: AppEnvironment.production,
          platform: TargetPlatform.android,
          isWeb: false,
          useEmulators: false,
        ),
        isTrue,
      );

      expect(
        AppEnvironmentConfig.shouldActivateAppCheck(
          environment: AppEnvironment.development,
          platform: TargetPlatform.android,
          isWeb: false,
          useEmulators: false,
        ),
        isFalse,
      );

      expect(
        AppEnvironmentConfig.shouldActivateAppCheck(
          environment: AppEnvironment.production,
          platform: TargetPlatform.android,
          isWeb: false,
          useEmulators: true,
        ),
        isFalse,
      );

      expect(
        AppEnvironmentConfig.shouldActivateAppCheck(
          environment: AppEnvironment.production,
          platform: TargetPlatform.android,
          isWeb: true,
          useEmulators: false,
        ),
        isFalse,
      );

      expect(
        AppEnvironmentConfig.shouldActivateAppCheck(
          environment: AppEnvironment.production,
          platform: TargetPlatform.iOS,
          isWeb: false,
          useEmulators: false,
        ),
        isFalse,
      );
    });
  });
}
