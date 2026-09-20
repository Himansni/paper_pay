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
  final Set<String> assignedEmployeeIds;
}
