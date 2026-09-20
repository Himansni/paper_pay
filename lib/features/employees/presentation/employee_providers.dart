import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/employees/data/firebase_employee_repository.dart';
import 'package:paper_route/features/employees/domain/employee_invitation.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';
import 'package:paper_route/features/employees/domain/employee_repository.dart';

/// Supplies the Firebase repository to employee-management widgets.
final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return FirebaseEmployeeRepository.fromDefaultApp();
});

// Each family argument is a business ID, so two tenants never share a member
// or invitation stream in Riverpod's provider cache.
final employeeMembersProvider = StreamProvider.autoDispose
    .family<List<EmployeeMember>, String>((ref, businessId) {
      return ref.watch(employeeRepositoryProvider).watchMembers(businessId);
    });

final employeeInvitationsProvider = StreamProvider.autoDispose
    .family<List<EmployeeInvitation>, String>((ref, businessId) {
      return ref.watch(employeeRepositoryProvider).watchInvitations(businessId);
    });
