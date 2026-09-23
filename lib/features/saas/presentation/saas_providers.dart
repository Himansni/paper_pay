import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/saas/data/firebase_saas_repository.dart';
import 'package:paper_route/features/saas/domain/saas_models.dart';
import 'package:paper_route/features/saas/domain/saas_repository.dart';

final saasRepositoryProvider = Provider<SaasRepository>(
  (ref) => FirebaseSaasRepository.fromDefaultApp(),
);

final saasSubscriptionProvider =
    StreamProvider.family<SaasSubscription, String>((ref, businessId) {
      final repository = ref.watch(saasRepositoryProvider);
      return repository.watchSubscription(businessId);
    });

class SaasEntitlementState {
  const SaasEntitlementState({
    required this.subscription,
    required this.now,
    required this.effectiveStatus,
    required this.daysRemaining,
    required this.graceDaysRemaining,
    required this.isReadOnly,
    required this.canPerformWrites,
    required this.isInGracePeriod,
    required this.isTrial,
  });

  final SaasSubscription subscription;
  final DateTime now;
  final SaasSubscriptionStatus effectiveStatus;
  final int daysRemaining;
  final int graceDaysRemaining;
  final bool isReadOnly;
  final bool canPerformWrites;
  final bool isInGracePeriod;
  final bool isTrial;
}

final saasEntitlementProvider =
    Provider.family<SaasEntitlementState?, String>((ref, businessId) {
      final subscriptionAsync = ref.watch(saasSubscriptionProvider(businessId));
      final sub = subscriptionAsync.asData?.value;
      if (sub == null) return null;
      final now = DateTime.now();
      return SaasEntitlementState(
        subscription: sub,
        now: now,
        effectiveStatus: sub.effectiveStatus(now),
        daysRemaining: sub.daysRemaining(now),
        graceDaysRemaining: sub.graceDaysRemaining(now),
        isReadOnly: sub.isReadOnly(now),
        canPerformWrites: sub.canPerformWrites(now),
        isInGracePeriod: sub.isInGracePeriod(now),
        isTrial: sub.isTrial(now),
      );
    });
