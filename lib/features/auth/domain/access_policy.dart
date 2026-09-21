import 'package:paper_route/features/auth/domain/app_user.dart';

// BEGINNER NOTE:
// Granular permission tokens assigned to employee members by the Head distributor.
// These flags allow selective delegation of daily operations without granting full admin rights.
abstract final class PermissionKey {
  static const addCustomers = 'addCustomers';
  static const editAssignedCustomers = 'editAssignedCustomers';
  static const manageAssignedSubscriptions = 'manageAssignedSubscriptions';
  static const recordPayments = 'recordPayments';
  static const recordDeliveryExceptions = 'recordDeliveryExceptions';
}

// BEGINNER NOTE:
// [AccessPolicy] provides client-side UI authorization checks.
// IMPORTANT ARCHITECTURAL PRINCIPLE:
// Client code is NEVER the security authority! An attacker can modify client code
// or call Firebase APIs directly.
// The purpose of [AccessPolicy] is purely for user experience (e.g. hiding disabled buttons,
// showing read-only views, preventing dead-end form submissions).
// The TRUE security boundary is enforced on the server by `firestore.rules`.
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

  bool canReadNewspaperCatalog(AppUser member) => member.hasActiveAccess;

  bool canManageNewspaperCatalog(AppUser member) =>
      member.hasActiveAccess && member.isHead;

  bool canManageSubscription({
    required AppUser member,
    required String customerBusinessId,
    required String assignedEmployeeId,
    required String customerAreaId,
    required bool isCustomerArchived,
  }) =>
      !isCustomerArchived &&
      canReadCustomer(
        member: member,
        customerBusinessId: customerBusinessId,
        assignedEmployeeId: assignedEmployeeId,
      ) &&
      (member.isHead ||
          (member.areaIds.contains(customerAreaId) &&
              member.permissions.contains(
                PermissionKey.manageAssignedSubscriptions,
              )));

  bool canSetSubscriptionPrice(AppUser member) =>
      member.hasActiveAccess && member.isHead;

  bool canEndSubscription({
    required AppUser member,
    required String customerBusinessId,
    required String assignedEmployeeId,
    required String customerAreaId,
    required bool isCustomerArchived,
  }) =>
      (member.hasActiveAccess &&
          member.isHead &&
          member.businessId == customerBusinessId) ||
      canManageSubscription(
        member: member,
        customerBusinessId: customerBusinessId,
        assignedEmployeeId: assignedEmployeeId,
        customerAreaId: customerAreaId,
        isCustomerArchived: isCustomerArchived,
      );

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
    required String customerAreaId,
    required bool isCustomerArchived,
  }) =>
      !isCustomerArchived &&
      canReadCustomer(
        member: member,
        customerBusinessId: customerBusinessId,
        assignedEmployeeId: assignedEmployeeId,
      ) &&
      (member.isHead ||
          (member.areaIds.contains(customerAreaId) &&
              member.permissions.contains(PermissionKey.recordPayments)));
}
