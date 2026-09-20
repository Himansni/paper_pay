/// Business-owned delivery zone used to scope employee operational access.
/// The document ID remains stable even when the area becomes inactive.
class DeliveryArea {
  const DeliveryArea({
    required this.id,
    required this.name,
    required this.isActive,
    required this.assignedEmployeeIds,
  });

  factory DeliveryArea.fromMap(String id, Map<String, Object?> data) {
    final rawEmployeeIds = data['assignedEmployeeIds'];
    return DeliveryArea(
      id: id,
      name: data['name'] as String? ?? '',
      isActive: data['status'] != 'inactive',
      assignedEmployeeIds:
          rawEmployeeIds is List
              ? rawEmployeeIds.whereType<String>().toSet()
              : <String>{},
    );
  }

  final String id;
  final String name;
  final bool isActive;

  /// Denormalized employee UIDs used for Head-facing coverage management.
  /// Member documents also carry their area IDs for authorization queries.
  final Set<String> assignedEmployeeIds;
}
