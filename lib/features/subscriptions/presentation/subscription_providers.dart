import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/subscriptions/data/firebase_subscription_repository.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';
import 'package:paper_route/features/subscriptions/domain/subscription_repository.dart';

typedef CustomerSubscriptionsKey = ({String businessId, String customerId});
typedef SubscriptionDocumentKey =
    ({String businessId, String customerId, String subscriptionId});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return FirebaseSubscriptionRepository.fromDefaultApp();
});

final customerSubscriptionsProvider = StreamProvider.autoDispose
    .family<List<CustomerSubscription>, CustomerSubscriptionsKey>((ref, key) {
      return ref
          .watch(subscriptionRepositoryProvider)
          .watchCustomerSubscriptions(
            businessId: key.businessId,
            customerId: key.customerId,
          );
    });

final customerSubscriptionProvider = StreamProvider.autoDispose
    .family<CustomerSubscription?, SubscriptionDocumentKey>((ref, key) {
      return ref
          .watch(subscriptionRepositoryProvider)
          .watchSubscription(
            businessId: key.businessId,
            customerId: key.customerId,
            subscriptionId: key.subscriptionId,
          );
    });

final subscriptionVersionsProvider = StreamProvider.autoDispose
    .family<List<SubscriptionVersion>, SubscriptionDocumentKey>((ref, key) {
      return ref
          .watch(subscriptionRepositoryProvider)
          .watchVersions(
            businessId: key.businessId,
            customerId: key.customerId,
            subscriptionId: key.subscriptionId,
          );
    });

final subscriptionPausesProvider = StreamProvider.autoDispose
    .family<List<SubscriptionPause>, SubscriptionDocumentKey>((ref, key) {
      return ref
          .watch(subscriptionRepositoryProvider)
          .watchPauses(
            businessId: key.businessId,
            customerId: key.customerId,
            subscriptionId: key.subscriptionId,
          );
    });

final subscriptionAuditProvider = StreamProvider.autoDispose
    .family<List<SubscriptionAuditEntry>, SubscriptionDocumentKey>((ref, key) {
      return ref
          .watch(subscriptionRepositoryProvider)
          .watchHistory(
            businessId: key.businessId,
            customerId: key.customerId,
            subscriptionId: key.subscriptionId,
          );
    });
