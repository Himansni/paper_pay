enum RoutePlacement {
  first,
  afterCustomer,
  last,
}

class RouteOrder {
  const RouteOrder({
    required this.businessId,
    required this.areaId,
    required this.customerIds,
    this.updatedBy,
    this.updatedAt,
  });

  factory RouteOrder.fromMap(Map<String, dynamic> data) {
    DateTime? dt;
    final rawDate = data['updatedAt'];
    if (rawDate is DateTime) {
      dt = rawDate;
    }

    return RouteOrder(
      businessId: data['businessId'] as String? ?? '',
      areaId: data['areaId'] as String? ?? '',
      customerIds: (data['customerIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      updatedBy: data['updatedBy'] as String?,
      updatedAt: dt,
    );
  }

  final String businessId;
  final String areaId;
  final List<String> customerIds;
  final String? updatedBy;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() => {
        'businessId': businessId,
        'areaId': areaId,
        'customerIds': customerIds,
        if (updatedBy != null) 'updatedBy': updatedBy,
      };

  RouteOrder copyWith({
    String? businessId,
    String? areaId,
    List<String>? customerIds,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return RouteOrder(
      businessId: businessId ?? this.businessId,
      areaId: areaId ?? this.areaId,
      customerIds: customerIds ?? this.customerIds,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
