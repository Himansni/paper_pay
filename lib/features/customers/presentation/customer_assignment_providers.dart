import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/customers/data/firebase_customer_assignment_repository.dart';
import 'package:paper_route/features/customers/domain/customer_assignment.dart';
import 'package:paper_route/features/customers/domain/customer_assignment_repository.dart';

final customerAssignmentRepositoryProvider =
    Provider<CustomerAssignmentRepository>((ref) {
      return FirebaseCustomerAssignmentRepository.fromDefaultApp();
    });

final customerAssignmentsProvider = StreamProvider.autoDispose
    .family<List<CustomerAssignment>, String>((ref, businessId) {
      return ref
          .watch(customerAssignmentRepositoryProvider)
          .watchCustomers(businessId);
    });
