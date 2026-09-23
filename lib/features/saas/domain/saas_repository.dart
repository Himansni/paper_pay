import 'package:paper_route/features/saas/domain/saas_models.dart';

abstract interface class SaasRepository {
  /// Watches the authoritative subscription and trial state for the agency.
  Stream<SaasSubscription> watchSubscription(String businessId);

  /// Fetches the authoritative subscription and trial state for the agency once.
  Future<SaasSubscription> fetchSubscription(String businessId);

  /// Submits an audited plan renewal or upgrade request.
  Future<void> requestPlanRenewal({
    required String businessId,
    required String actorId,
    required String targetPlanId,
  });
}
