import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/domain/customer_removal_request.dart';

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

  Future<String> requestCustomerRemoval({
    required AppUser actor,
    required String customerId,
    required String reason,
  });

  Stream<List<CustomerRemovalRequest>> watchPendingRemovalRequests({
    required String businessId,
    required String requesterId,
    required bool isHead,
  });

  Future<void> reviewRemovalRequest({
    required AppUser actor,
    required String requestId,
    required bool approved,
    String? reviewNotes,
  });
}
