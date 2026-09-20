import 'package:paper_route/features/employees/domain/employee_invitation.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';

/// Repository contract for Head-managed invitations and member access.
/// Every operation requires an explicit business ID to preserve tenant scope.
abstract interface class EmployeeRepository {
  Stream<List<EmployeeMember>> watchMembers(String businessId);

  Stream<List<EmployeeInvitation>> watchInvitations(String businessId);

  Future<String> createInvitation({
    required String businessId,
    required String actorId,
    required String email,
    required Set<String> permissions,
    required Set<String> areaIds,
    required DateTime expiresAt,
  });

  Future<void> updateMemberAccess({
    required String businessId,
    required String actorId,
    required String memberId,
    required String displayName,
    required String phone,
    required String notes,
    required bool isActive,
    required Set<String> permissions,
  });

  Future<void> revokeInvitation({
    required String businessId,
    required String actorId,
    required String invitationId,
  });
}
