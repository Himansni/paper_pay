import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/delivery/domain/delivery_models.dart';
import 'package:paper_route/features/delivery/domain/delivery_repository.dart';
import 'package:paper_route/features/delivery/domain/route_order.dart';

class FirebaseDeliveryRepository implements DeliveryRepository {
  FirebaseDeliveryRepository(this._firestore);

  factory FirebaseDeliveryRepository.fromDefaultApp() =>
      FirebaseDeliveryRepository(FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;

  String _routeId(LocalDate date, String areaId) => '${date.toString()}_$areaId';

  DocumentReference<Map<String, dynamic>> _dropRef({
    required String businessId,
    required String routeId,
    required String customerId,
  }) =>
      _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('dailyRoutes')
          .doc(routeId)
          .collection('drops')
          .doc(customerId);

  CollectionReference<Map<String, dynamic>> _dropsCollection({
    required String businessId,
    required String routeId,
  }) =>
      _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('dailyRoutes')
          .doc(routeId)
          .collection('drops');

  DocumentReference<Map<String, dynamic>> _routeOrderRef({
    required String businessId,
    required String areaId,
  }) =>
      _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('routeOrders')
          .doc(areaId);

  @override
  Future<void> recordDropStatus({
    required String businessId,
    required String areaId,
    required LocalDate date,
    required String customerId,
    required DeliveryStopStatus status,
    String? exceptionReason,
    required String actorUid,
  }) async {
    final routeId = _routeId(date, areaId);
    final ref = _dropRef(
      businessId: businessId,
      routeId: routeId,
      customerId: customerId,
    );

    final auditRef = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('auditRecords')
        .doc();

    final batch = _firestore.batch();

    // 1. Append-only audit record preserving complete transition history
    batch.set(auditRef, {
      'businessId': businessId,
      'actorId': actorUid,
      'action': 'deliveryDropStatusUpdated',
      'entityType': 'deliveryDrop',
      'entityId': customerId,
      'routeId': routeId,
      'areaId': areaId,
      'date': date.toString(),
      'status': status.value,
      if (status == DeliveryStopStatus.exception && exceptionReason != null)
        'exceptionReason': exceptionReason,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Mutable drop document paired with matching lastAuditId
    final payload = <String, dynamic>{
      'businessId': businessId,
      'routeId': routeId,
      'date': date.toString(),
      'areaId': areaId,
      'customerId': customerId,
      'status': status.value,
      'exceptionReason':
          status == DeliveryStopStatus.exception ? exceptionReason : null,
      'actorUid': actorUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastAuditId': auditRef.id,
    };

    batch.set(ref, payload, SetOptions(merge: true));

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      throw AppException(
        'Could not update delivery status: ${e.message ?? e.code}',
      );
    }
  }

  @override
  Future<Map<String, DeliveryDropRecord>> fetchRouteDrops({
    required String businessId,
    required String areaId,
    required LocalDate date,
  }) async {
    final routeId = _routeId(date, areaId);
    try {
      final snap = await _dropsCollection(
        businessId: businessId,
        routeId: routeId,
      ).get();

      final Map<String, DeliveryDropRecord> drops = {};
      for (final doc in snap.docs) {
        drops[doc.id] = DeliveryDropRecord.fromMap(doc.data());
      }
      return drops;
    } on FirebaseException catch (e) {
      throw AppException(
        'Could not load delivery records: ${e.message ?? e.code}',
      );
    }
  }

  @override
  Stream<Map<String, DeliveryDropRecord>> watchRouteDrops({
    required String businessId,
    required String areaId,
    required LocalDate date,
  }) {
    final routeId = _routeId(date, areaId);
    return _dropsCollection(
      businessId: businessId,
      routeId: routeId,
    ).snapshots().map((snap) {
      final Map<String, DeliveryDropRecord> drops = {};
      for (final doc in snap.docs) {
        drops[doc.id] = DeliveryDropRecord.fromMap(doc.data());
      }
      return drops;
    });
  }

  @override
  Future<List<DeliveryDropRecord>> fetchTodayExceptions({
    required String businessId,
    required LocalDate date,
  }) async {
    try {
      final areasSnap = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('areas')
          .where('businessId', isEqualTo: businessId)
          .where('status', isEqualTo: 'active')
          .get();

      final List<DeliveryDropRecord> exceptions = [];
      for (final areaDoc in areasSnap.docs) {
        final areaId = areaDoc.id;
        final routeId = _routeId(date, areaId);
        final dropSnap = await _dropsCollection(
          businessId: businessId,
          routeId: routeId,
        ).where('status', isEqualTo: 'exception').get();

        for (final doc in dropSnap.docs) {
          exceptions.add(DeliveryDropRecord.fromMap(doc.data()));
        }
      }
      return exceptions;
    } on FirebaseException catch (e) {
      throw AppException('Could not load exceptions: ${e.message ?? e.code}');
    }
  }

  @override
  Future<RouteOrder?> getRouteOrder({
    required String businessId,
    required String areaId,
  }) async {
    try {
      final snap = await _routeOrderRef(businessId: businessId, areaId: areaId).get();
      if (!snap.exists || snap.data() == null) {
        return null;
      }
      return RouteOrder.fromMap(snap.data()!);
    } on FirebaseException catch (e) {
      throw AppException('Could not fetch route order: ${e.message ?? e.code}');
    }
  }

  @override
  Stream<RouteOrder?> watchRouteOrder({
    required String businessId,
    required String areaId,
  }) {
    return _routeOrderRef(businessId: businessId, areaId: areaId)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) {
        return null;
      }
      return RouteOrder.fromMap(snap.data()!);
    });
  }

  @override
  Future<void> saveRouteOrder({
    required String businessId,
    required String areaId,
    required List<String> customerIds,
    required String actorUid,
  }) async {
    try {
      await _routeOrderRef(businessId: businessId, areaId: areaId).set({
        'businessId': businessId,
        'areaId': areaId,
        'customerIds': customerIds,
        'updatedBy': actorUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AppException('Could not save route order: ${e.message ?? e.code}');
    }
  }

  @override
  Future<void> insertCustomerInRoute({
    required String businessId,
    required String areaId,
    required String customerId,
    required RoutePlacement placement,
    String? afterCustomerId,
    required String actorUid,
  }) async {
    final currentOrder = await getRouteOrder(
      businessId: businessId,
      areaId: areaId,
    );
    final List<String> list = currentOrder != null
        ? List<String>.from(currentOrder.customerIds)
        : <String>[];

    // Remove if already present
    list.remove(customerId);

    switch (placement) {
      case RoutePlacement.first:
        list.insert(0, customerId);
        break;
      case RoutePlacement.afterCustomer:
        if (afterCustomerId != null) {
          final index = list.indexOf(afterCustomerId);
          if (index != -1) {
            list.insert(index + 1, customerId);
            break;
          }
        }
        list.add(customerId);
        break;
      case RoutePlacement.last:
        list.add(customerId);
        break;
    }

    await saveRouteOrder(
      businessId: businessId,
      areaId: areaId,
      customerIds: list,
      actorUid: actorUid,
    );
  }
}

class InMemoryDeliveryRepository implements DeliveryRepository {
  final Map<String, Map<String, DeliveryDropRecord>> _store = {};
  final Map<String, RouteOrder> _routeOrders = {};
  final List<Map<String, dynamic>> _auditRecords = [];

  List<Map<String, dynamic>> get auditRecords =>
      List.unmodifiable(_auditRecords);

  String _key(String businessId, String areaId, LocalDate date) =>
      '$businessId/${date.toString()}_$areaId';

  String _orderKey(String businessId, String areaId) => '$businessId/$areaId';

  @override
  Future<void> recordDropStatus({
    required String businessId,
    required String areaId,
    required LocalDate date,
    required String customerId,
    required DeliveryStopStatus status,
    String? exceptionReason,
    required String actorUid,
  }) async {
    final key = _key(businessId, areaId, date);
    final map = _store.putIfAbsent(key, () => {});

    final auditId = 'audit_${DateTime.now().microsecondsSinceEpoch}';
    _auditRecords.add({
      'auditId': auditId,
      'businessId': businessId,
      'actorId': actorUid,
      'action': 'deliveryDropStatusUpdated',
      'entityType': 'deliveryDrop',
      'entityId': customerId,
      'routeId': '${date.toString()}_$areaId',
      'areaId': areaId,
      'date': date.toString(),
      'status': status.value,
      'exceptionReason': exceptionReason,
      'createdAt': DateTime.now(),
    });

    map[customerId] = DeliveryDropRecord(
      businessId: businessId,
      routeId: '${date.toString()}_$areaId',
      date: date.toString(),
      areaId: areaId,
      customerId: customerId,
      status: status,
      exceptionReason: exceptionReason,
      actorUid: actorUid,
      updatedAt: DateTime.now(),
      lastAuditId: auditId,
    );
  }

  @override
  Future<Map<String, DeliveryDropRecord>> fetchRouteDrops({
    required String businessId,
    required String areaId,
    required LocalDate date,
  }) async {
    return Map<String, DeliveryDropRecord>.from(
      _store[_key(businessId, areaId, date)] ?? const {},
    );
  }

  @override
  Stream<Map<String, DeliveryDropRecord>> watchRouteDrops({
    required String businessId,
    required String areaId,
    required LocalDate date,
  }) {
    return Stream.value(
      Map<String, DeliveryDropRecord>.from(
        _store[_key(businessId, areaId, date)] ?? const {},
      ),
    );
  }

  @override
  Future<List<DeliveryDropRecord>> fetchTodayExceptions({
    required String businessId,
    required LocalDate date,
  }) async {
    final List<DeliveryDropRecord> list = [];
    for (final map in _store.values) {
      for (final drop in map.values) {
        if (drop.businessId == businessId &&
            drop.date == date.toString() &&
            drop.status == DeliveryStopStatus.exception) {
          list.add(drop);
        }
      }
    }
    return list;
  }

  @override
  Future<RouteOrder?> getRouteOrder({
    required String businessId,
    required String areaId,
  }) async {
    return _routeOrders[_orderKey(businessId, areaId)];
  }

  @override
  Stream<RouteOrder?> watchRouteOrder({
    required String businessId,
    required String areaId,
  }) {
    return Stream.value(_routeOrders[_orderKey(businessId, areaId)]);
  }

  @override
  Future<void> saveRouteOrder({
    required String businessId,
    required String areaId,
    required List<String> customerIds,
    required String actorUid,
  }) async {
    _routeOrders[_orderKey(businessId, areaId)] = RouteOrder(
      businessId: businessId,
      areaId: areaId,
      customerIds: customerIds,
      updatedBy: actorUid,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> insertCustomerInRoute({
    required String businessId,
    required String areaId,
    required String customerId,
    required RoutePlacement placement,
    String? afterCustomerId,
    required String actorUid,
  }) async {
    final current = await getRouteOrder(
      businessId: businessId,
      areaId: areaId,
    );
    final List<String> list =
        current != null ? List<String>.from(current.customerIds) : [];

    list.remove(customerId);

    switch (placement) {
      case RoutePlacement.first:
        list.insert(0, customerId);
        break;
      case RoutePlacement.afterCustomer:
        if (afterCustomerId != null) {
          final index = list.indexOf(afterCustomerId);
          if (index != -1) {
            list.insert(index + 1, customerId);
            break;
          }
        }
        list.add(customerId);
        break;
      case RoutePlacement.last:
        list.add(customerId);
        break;
    }

    await saveRouteOrder(
      businessId: businessId,
      areaId: areaId,
      customerIds: list,
      actorUid: actorUid,
    );
  }
}
