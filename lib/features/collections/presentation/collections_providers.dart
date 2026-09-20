import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/collections/data/firebase_collections_repository.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/collections/domain/collection_repository.dart';

typedef CustomerCollectionKey = ({String businessId, String customerId});
typedef PaymentLookupKey =
    ({AppUser actor, String customerId, String paymentId});

final collectionsRepositoryProvider = Provider<CollectionsRepository>((ref) {
  return FirebaseCollectionsRepository.fromDefaultApp();
});

final customerOutstandingProvider = StreamProvider.autoDispose
    .family<CustomerOutstandingSummary, CustomerCollectionKey>((ref, key) {
      return ref
          .watch(collectionsRepositoryProvider)
          .watchCustomerOutstanding(
            businessId: key.businessId,
            customerId: key.customerId,
          );
    });

final paymentProvider = FutureProvider.autoDispose
    .family<ConfirmedPayment, PaymentLookupKey>((ref, key) {
      return ref
          .watch(collectionsRepositoryProvider)
          .getPayment(
            actor: key.actor,
            customerId: key.customerId,
            paymentId: key.paymentId,
          );
    });

final upiSettingsProvider = StreamProvider.autoDispose
    .family<UpiSettings, String>((ref, businessId) {
      return ref
          .watch(collectionsRepositoryProvider)
          .watchUpiSettings(businessId);
    });
