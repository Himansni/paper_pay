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

typedef AreaCustomersKey = ({String businessId, String areaId});

final areaCustomersProvider = FutureProvider.autoDispose
    .family<List<Customer>, AreaCustomersKey>((ref, key) async {
  if (key.areaId.isEmpty) return const [];
  final repo = ref.watch(customerRepositoryProvider);
  final result = await repo.fetchCustomers(
    CustomerListRequest(
      businessId: key.businessId,
      requesterId: '',
      isHead: true,
      status: CustomerStatus.active,
      areaId: key.areaId,
      pageSize: 250,
    ),
  );
  return result.customers;
});
