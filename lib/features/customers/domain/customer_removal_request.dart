import 'package:paper_route/core/errors/app_exception.dart';

enum RemovalRequestStatus {
  pending('pending', 'Pending Approval'),
  approved('approved', 'Approved & Archived'),
  rejected('rejected', 'Rejected');

  const RemovalRequestStatus(this.value, this.label);

  final String value;
  final String label;

  static RemovalRequestStatus fromValue(Object? value) =>
      values.firstWhere((e) => e.value == value, orElse: () => pending);
}

class CustomerRemovalRequest {
  const CustomerRemovalRequest({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.customerName,
    required this.customerCode,
    required this.areaId,
    required this.assignedEmployeeId,
    required this.requestedBy,
    required this.requestedByName,
    required this.reason,
    required this.status,
    this.reviewedBy,
    this.reviewNotes,
    this.createdAt,
    this.updatedAt,
  });

  factory CustomerRemovalRequest.fromMap(
    String id,
    Map<String, Object?> data,
  ) {
    final businessId = (data['businessId'] as String?)?.trim() ?? '';
    final customerId = (data['customerId'] as String?)?.trim() ?? '';
    if (businessId.isEmpty || customerId.isEmpty) {
      throw const AppException('Corrupted customer removal request record.');
    }
    return CustomerRemovalRequest(
      id: id,
      businessId: businessId,
      customerId: customerId,
      customerName: (data['customerName'] as String?)?.trim() ?? 'Unknown Customer',
      customerCode: (data['customerCode'] as String?)?.trim() ?? customerId,
      areaId: (data['areaId'] as String?)?.trim() ?? '',
      assignedEmployeeId: (data['assignedEmployeeId'] as String?)?.trim() ?? '',
      requestedBy: (data['requestedBy'] as String?)?.trim() ?? '',
      requestedByName: (data['requestedByName'] as String?)?.trim() ?? 'Staff Member',
      reason: (data['reason'] as String?)?.trim() ?? '',
      status: RemovalRequestStatus.fromValue(data['status']),
      reviewedBy: (data['reviewedBy'] as String?)?.trim(),
      reviewNotes: (data['reviewNotes'] as String?)?.trim(),
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }

  final String id;
  final String businessId;
  final String customerId;
  final String customerName;
  final String customerCode;
  final String areaId;
  final String assignedEmployeeId;
  final String requestedBy;
  final String requestedByName;
  final String reason;
  final RemovalRequestStatus status;
  final String? reviewedBy;
  final String? reviewNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending => status == RemovalRequestStatus.pending;

  Map<String, Object?> toMap() => {
    'businessId': businessId,
    'customerId': customerId,
    'customerName': customerName,
    'customerCode': customerCode,
    'areaId': areaId,
    'assignedEmployeeId': assignedEmployeeId,
    'requestedBy': requestedBy,
    'requestedByName': requestedByName,
    'reason': reason,
    'status': status.value,
    if (reviewedBy != null) 'reviewedBy': reviewedBy,
    if (reviewNotes != null) 'reviewNotes': reviewNotes,
  };

  static DateTime? _parseTimestamp(Object? value) {
    if (value is DateTime) return value;
    return null;
  }
}
