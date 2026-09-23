import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/delivery/domain/delivery_models.dart';
import 'package:paper_route/features/delivery/domain/delivery_repository.dart';

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

    final payload = <String, dynamic>{
      'businessId': businessId,
      'routeId': routeId,
      'date': date.toString(),
      'areaId': areaId,
      'customerId': customerId,
      'status': status.value,
      'exceptionReason': status == DeliveryStopStatus.exception ? exceptionReason : null,
      'actorUid': actorUid,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await ref.set(payload, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw AppException('Could not update delivery status: ${e.message ?? e.code}');
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
      throw AppException('Could not load delivery records: ${e.message ?? e.code}');
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
      // In Firestore, collection group or querying dailyRoutes subcollections
      // Query areas first to check routes
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
}

class InMemoryDeliveryRepository implements DeliveryRepository {
  final Map<String, Map<String, DeliveryDropRecord>> _store = {};

  String _key(String businessId, String areaId, LocalDate date) =>
      '$businessId/${date.toString()}_$areaId';

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
}
