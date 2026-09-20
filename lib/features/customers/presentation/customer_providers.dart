import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/customers/data/firebase_customer_repository.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/domain/customer_repository.dart';

typedef CustomerDocumentKey = ({String businessId, String customerId});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return FirebaseCustomerRepository.fromDefaultApp();
});

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
