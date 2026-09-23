class DailyPaperDrop {
  const DailyPaperDrop({
    required this.newspaperId,
    required this.newspaperName,
    required this.quantity,
    required this.isPaused,
    this.pauseReason,
  });

  final String newspaperId;
  final String newspaperName;
  final int quantity;
  final bool isPaused;
  final String? pauseReason;
}

enum DeliveryStopStatus {
  pending('pending', 'Pending'),
  delivered('delivered', 'Delivered'),
  paused('paused', 'Paused'),
  exception('exception', 'Issue Reported');

  const DeliveryStopStatus(this.value, this.label);

  final String value;
  final String label;
}

class DailyRouteStop {
  const DailyRouteStop({
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    required this.houseNumber,
    required this.buildingInfo,
    required this.address,
    required this.landmark,
    required this.deliveryPlacement,
    required this.routeSequence,
    required this.areaId,
    required this.areaName,
    required this.drops,
    this.status = DeliveryStopStatus.pending,
    this.exceptionReason,
    this.deliveredAt,
  });

  final String customerId;
  final String customerCode;
  final String customerName;
  final String houseNumber;
  final String buildingInfo;
  final String address;
  final String landmark;
  final String deliveryPlacement;
  final int routeSequence;
  final String areaId;
  final String areaName;
  final List<DailyPaperDrop> drops;
  final DeliveryStopStatus status;
  final String? exceptionReason;
  final DateTime? deliveredAt;

  bool get isPausedToday => drops.isNotEmpty && drops.every((d) => d.isPaused);
  bool get hasActiveDrops => drops.any((d) => !d.isPaused);
  bool get isDelivered => status == DeliveryStopStatus.delivered;

  List<DailyPaperDrop> get activeDrops => drops.where((d) => !d.isPaused).toList();
  List<DailyPaperDrop> get pausedDrops => drops.where((d) => d.isPaused).toList();

  DailyRouteStop copyWith({
    DeliveryStopStatus? status,
    String? exceptionReason,
    DateTime? deliveredAt,
  }) {
    return DailyRouteStop(
      customerId: customerId,
      customerCode: customerCode,
      customerName: customerName,
      houseNumber: houseNumber,
      buildingInfo: buildingInfo,
      address: address,
      landmark: landmark,
      deliveryPlacement: deliveryPlacement,
      routeSequence: routeSequence,
      areaId: areaId,
      areaName: areaName,
      drops: drops,
      status: status ?? this.status,
      exceptionReason: exceptionReason ?? this.exceptionReason,
      deliveredAt: deliveredAt ?? this.deliveredAt,
    );
  }
}

class RouteProgressSummary {
  const RouteProgressSummary({
    required this.totalStops,
    required this.deliveredStops,
    required this.pausedStops,
    required this.exceptionStops,
  });

  final int totalStops;
  final int deliveredStops;
  final int pausedStops;
  final int exceptionStops;

  int get pendingStops => totalStops - deliveredStops - pausedStops - exceptionStops;
  int get percentComplete => totalStops == 0 ? 0 : ((deliveredStops / totalStops) * 100).round();
  bool get allCompleted => pendingStops <= 0;
}

class DeliveryDropRecord {
  const DeliveryDropRecord({
    required this.businessId,
    required this.routeId,
    required this.date,
    required this.areaId,
    required this.customerId,
    required this.status,
    this.exceptionReason,
    required this.actorUid,
    required this.updatedAt,
  });

  final String businessId;
  final String routeId;
  final String date;
  final String areaId;
  final String customerId;
  final DeliveryStopStatus status;
  final String? exceptionReason;
  final String actorUid;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
    'businessId': businessId,
    'routeId': routeId,
    'date': date,
    'areaId': areaId,
    'customerId': customerId,
    'status': status.value,
    if (exceptionReason != null) 'exceptionReason': exceptionReason,
    'actorUid': actorUid,
    'updatedAt': updatedAt,
  };

  factory DeliveryDropRecord.fromMap(Map<String, dynamic> map) {
    final statusStr = map['status'] as String? ?? 'pending';
    final status = DeliveryStopStatus.values.firstWhere(
      (s) => s.value == statusStr,
      orElse: () => DeliveryStopStatus.pending,
    );
    DateTime updated = DateTime.now();
    final rawUpdated = map['updatedAt'];
    if (rawUpdated != null) {
      if (rawUpdated is DateTime) {
        updated = rawUpdated;
      } else {
        try {
          updated = (rawUpdated as dynamic).toDate() as DateTime;
        } catch (_) {}
      }
    }

    return DeliveryDropRecord(
      businessId: map['businessId'] as String? ?? '',
      routeId: map['routeId'] as String? ?? '',
      date: map['date'] as String? ?? '',
      areaId: map['areaId'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      status: status,
      exceptionReason: map['exceptionReason'] as String?,
      actorUid: map['actorUid'] as String? ?? '',
      updatedAt: updated,
    );
  }
}
