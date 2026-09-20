import 'package:paper_route/features/auth/domain/app_user.dart';

/// View model for a businesses/{businessId}/members/{uid} document.
/// Role, status, permissions, and area IDs together describe business access.
class EmployeeMember {
  const EmployeeMember({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.phone,
    required this.role,
    required this.status,
    required this.permissions,
    required this.areaIds,
    required this.notes,
  });

  factory EmployeeMember.fromMap(String uid, Map<String, Object?> data) {
    return EmployeeMember(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      role: switch (data['role']) {
        'head' => UserRole.head,
        'employee' => UserRole.employee,
        _ => null,
      },
      status:
          data['status'] == 'active'
              ? AccountStatus.active
              : AccountStatus.inactive,
      permissions: _stringSet(data['permissions']),
      areaIds: _stringSet(data['areaIds']),
      notes: data['notes'] as String? ?? '',
    );
  }

  final String uid;
  final String email;
  final String displayName;
  final String phone;
  final UserRole? role;
  final AccountStatus status;
  final Set<String> permissions;
  final Set<String> areaIds;
  final String notes;

  bool get isHead => role == UserRole.head;
  bool get isEmployee => role == UserRole.employee;

  /// Inactive members remain in history but cannot use protected business data.
  bool get isActive => status == AccountStatus.active;

  static Set<String> _stringSet(Object? value) =>
      value is List ? value.whereType<String>().toSet() : <String>{};
}
