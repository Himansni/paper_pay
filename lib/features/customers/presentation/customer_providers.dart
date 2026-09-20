import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/customers/data/firebase_customer_repository.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/domain/customer_repository.dart';

/// Both IDs are part of the provider key so similarly named customer documents
/// from different businesses never share Riverpod state.
typedef CustomerDocumentKey = ({String businessId, String customerId});

/// Supplies the Firebase implementation to Customer screens.
final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return FirebaseCustomerRepository.fromDefaultApp();
});

// The detail and history streams are separate because the customer document is
// mutable current state while audit records are append-only historical events.
final customerProvider = StreamProvider.autoDispose
    .family<Customer?, CustomerDocumentKey>((ref, key) {
      return ref
          .watch(customerRepositoryProvider)
          .watchCustomer(
            businessId: key.businessId,
            customerId: key.customerId,
          );
    });

final customerAuditProvider = StreamProvider.autoDispose
    .family<List<CustomerAuditEntry>, CustomerDocumentKey>((ref, key) {
      return ref
          .watch(customerRepositoryProvider)
          .watchCustomerHistory(
            businessId: key.businessId,
            customerId: key.customerId,
          );
    });
