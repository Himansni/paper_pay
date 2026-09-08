import 'package:paper_route/features/customers/domain/customer_assignment.dart';

abstract interface class CustomerAssignmentRepository {
  Stream<List<CustomerAssignment>> watchCustomers(String businessId);

  Future<void> assignCustomer({
    required String businessId,
    required String actorId,
    required String customerId,
    required String employeeId,
    required String areaId,
  });
}
