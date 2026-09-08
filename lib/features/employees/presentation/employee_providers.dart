import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/employees/data/firebase_employee_repository.dart';
import 'package:paper_route/features/employees/domain/employee_invitation.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';
import 'package:paper_route/features/employees/domain/employee_repository.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return FirebaseEmployeeRepository.fromDefaultApp();
});

final employeeMembersProvider = StreamProvider.autoDispose
    .family<List<EmployeeMember>, String>((ref, businessId) {
      return ref.watch(employeeRepositoryProvider).watchMembers(businessId);
    });

final employeeInvitationsProvider = StreamProvider.autoDispose
    .family<List<EmployeeInvitation>, String>((ref, businessId) {
      return ref.watch(employeeRepositoryProvider).watchInvitations(businessId);
    });
