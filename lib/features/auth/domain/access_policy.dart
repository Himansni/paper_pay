import 'package:paper_route/features/auth/domain/app_user.dart';

abstract final class PermissionKey {
  static const addCustomers = 'addCustomers';
  static const editAssignedCustomers = 'editAssignedCustomers';
  static const recordPayments = 'recordPayments';
  static const recordDeliveryExceptions = 'recordDeliveryExceptions';
}

/// Mirrors important client-side visibility checks. Firestore Rules remain the
/// authority; this policy only prevents presenting actions that will be denied.
class AccessPolicy {
  const AccessPolicy();

  bool canReadCustomer({
    required AppUser member,
    required String customerBusinessId,
    required String assignedEmployeeId,
  }) {
    if (!member.hasActiveAccess || member.businessId != customerBusinessId) {
      return false;
    }
    return member.isHead || member.uid == assignedEmployeeId;
  }

  bool canCreateCustomer(AppUser member) =>
      member.hasActiveAccess &&
      (member.isHead ||
          member.permissions.contains(PermissionKey.addCustomers));

  bool canEditCustomer({
    required AppUser member,
    required String customerBusinessId,
    required String assignedEmployeeId,
    required bool isArchived,
  }) =>
      !isArchived &&
      canReadCustomer(
        member: member,
        customerBusinessId: customerBusinessId,
        assignedEmployeeId: assignedEmployeeId,
      ) &&
      (member.isHead ||
          member.permissions.contains(PermissionKey.editAssignedCustomers));

  bool canManageCustomerLifecycle(AppUser member) =>
      member.hasActiveAccess && member.isHead;

  bool canSetOpeningBalance(AppUser member) =>
      member.hasActiveAccess && member.isHead;

  bool canUseArea(AppUser member, String areaId) =>
      member.hasActiveAccess &&
      areaId.isNotEmpty &&
      (member.isHead || member.areaIds.contains(areaId));

  bool canRecordPayment({
    required AppUser member,
    required String customerBusinessId,
    required String assignedEmployeeId,
  }) =>
      canReadCustomer(
        member: member,
        customerBusinessId: customerBusinessId,
        assignedEmployeeId: assignedEmployeeId,
      ) &&
      (member.isHead ||
          member.permissions.contains(PermissionKey.recordPayments));
}
