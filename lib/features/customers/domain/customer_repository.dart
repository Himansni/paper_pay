import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';

/// Boundary for tenant-scoped customer reads and audited lifecycle writes.
/// Widgets use this contract instead of constructing Firestore paths directly.
abstract interface class CustomerRepository {
  Future<CustomerPage> fetchCustomers(CustomerListRequest request);

  Stream<Customer?> watchCustomer({
    required String businessId,
    required String customerId,
  });

  Stream<List<CustomerAuditEntry>> watchCustomerHistory({
    required String businessId,
    required String customerId,
  });

  Future<String> createCustomer({
    required AppUser actor,
    required CustomerInput input,
  });

  Future<void> updateCustomerProfile({
    required AppUser actor,
    required String customerId,
    required CustomerInput input,
  });

  Future<void> setCustomerArchived({
    required AppUser actor,
    required String customerId,
    required bool archived,
  });

  Future<void> assignCustomer({
    required AppUser actor,
    required String customerId,
    required String employeeId,
    required String areaId,
  });
}
