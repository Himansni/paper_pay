class CustomerAssignment {
  const CustomerAssignment({
    required this.id,
    required this.customerCode,
    required this.name,
    required this.phone,
    required this.areaId,
    required this.assignedEmployeeId,
    required this.status,
  });

  factory CustomerAssignment.fromMap(String id, Map<String, Object?> data) {
    return CustomerAssignment(
      id: id,
      customerCode: data['customerCode'] as String? ?? id,
      name: data['name'] as String? ?? 'Unnamed customer',
      phone: data['phone'] as String? ?? '',
      areaId: data['areaId'] as String? ?? '',
      assignedEmployeeId: data['assignedEmployeeId'] as String? ?? '',
      status: data['status'] as String? ?? 'active',
    );
  }

  final String id;
  final String customerCode;
  final String name;
  final String phone;
  final String areaId;
  final String assignedEmployeeId;
  final String status;
}
