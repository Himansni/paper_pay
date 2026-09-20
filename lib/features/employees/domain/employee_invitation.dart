/// Pending onboarding offer created by a Head for one business and email.
/// Its permissions and areas become the employee's initial access on acceptance.
class EmployeeInvitation {
  const EmployeeInvitation({
    required this.id,
    required this.email,
    required this.status,
    required this.permissions,
    required this.areaIds,
    required this.expiresAt,
  });

  factory EmployeeInvitation.fromMap(
    String id,
    Map<String, Object?> data, {
    required DateTime expiresAt,
  }) {
    return EmployeeInvitation(
      id: id,
      email: data['email'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      permissions: _stringSet(data['permissions']),
      areaIds: _stringSet(data['areaIds']),
      expiresAt: expiresAt,
    );
  }

  final String id;
  final String email;
  final String status;
  final Set<String> permissions;
  final Set<String> areaIds;
  final DateTime expiresAt;

  bool get isPending => status == 'pending';
  bool get isExpired => expiresAt.isBefore(DateTime.now());

  static Set<String> _stringSet(Object? value) =>
      value is List ? value.whereType<String>().toSet() : <String>{};
}
