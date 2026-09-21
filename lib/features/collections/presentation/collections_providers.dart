import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/collections/data/firebase_collections_repository.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/collections/domain/collection_repository.dart';

typedef CustomerCollectionKey = ({String businessId, String customerId});
typedef PaymentLookupKey =
    ({AppUser actor, String customerId, String paymentId});

// Supplies the concrete Firestore repository to collection screens.
final collectionsRepositoryProvider = Provider<CollectionsRepository>((ref) {
  return FirebaseCollectionsRepository.fromDefaultApp();
});

// Keeps a customer screen synchronized with the authoritative collection
// projection. `autoDispose` stops listening when that screen leaves the tree.
final customerOutstandingProvider = StreamProvider.autoDispose
    .family<CustomerOutstandingSummary, CustomerCollectionKey>((ref, key) {
      return ref
          .watch(collectionsRepositoryProvider)
          .watchCustomerOutstanding(
            businessId: key.businessId,
            customerId: key.customerId,
          );
    });

// Loads one immutable receipt plus its current reversal projection.
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

// Watches tenant UPI request settings; it does not watch or infer payments.
final upiSettingsProvider = StreamProvider.autoDispose
    .family<UpiSettings, String>((ref, businessId) {
      return ref
          .watch(collectionsRepositoryProvider)
          .watchUpiSettings(businessId);
    });
