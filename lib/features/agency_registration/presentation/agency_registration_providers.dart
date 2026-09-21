import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/core/config/app_environment.dart';
import 'package:paper_route/features/agency_registration/domain/agency_registration.dart';
import 'package:paper_route/features/agency_registration/domain/agency_registration_repository.dart';

/// One centralized release gate, backed by a disabled-by-default dart-define.
/// Tests may override this provider without weakening backend authorization.
final agencyRegistrationEnabledProvider = Provider<bool>(
  (ref) => AppEnvironmentConfig.agencyRegistrationEnabled,
);

final agencyRegistrationRepositoryProvider =
    Provider<AgencyRegistrationRepository>((ref) {
      throw StateError(
        'AgencyRegistrationRepository must be configured at app startup.',
      );
    });

class AgencyRegistrationDraftNotifier
    extends Notifier<AgencyRegistrationDraft?> {
  @override
  AgencyRegistrationDraft? build() => null;

  void save(AgencyRegistrationDraft draft) => state = draft;

  void clear() => state = null;
}

final agencyRegistrationDraftProvider =
    NotifierProvider<AgencyRegistrationDraftNotifier, AgencyRegistrationDraft?>(
      AgencyRegistrationDraftNotifier.new,
    );

class AgencyRegistrationIntentNotifier
    extends Notifier<AgencyRegistrationIntent?> {
  @override
  AgencyRegistrationIntent? build() => null;

  void choose(AgencyRegistrationIntent intent) => state = intent;

  void clear() => state = null;
}

final agencyRegistrationIntentProvider = NotifierProvider<
  AgencyRegistrationIntentNotifier,
  AgencyRegistrationIntent?
>(AgencyRegistrationIntentNotifier.new);

final agencyRegistrationOptionsProvider =
    FutureProvider.autoDispose<AgencyRegistrationOptions>((ref) {
      return ref
          .watch(agencyRegistrationRepositoryProvider)
          .getRegistrationOptions();
    });
