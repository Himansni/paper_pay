import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/areas/domain/area_repository.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';

class FirebaseAreaRepository implements AreaRepository {
  FirebaseAreaRepository(this._firestore);

  factory FirebaseAreaRepository.fromDefaultApp() =>
      FirebaseAreaRepository(FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(
    String businessId,
    String name,
  ) => _firestore.collection('businesses').doc(businessId).collection(name);

  @override
  Stream<List<DeliveryArea>> watchAreas(String businessId) {
    return _collection(businessId, 'areas').snapshots().map((event) {
      final areas =
          event.docs
              .map((doc) => DeliveryArea.fromMap(doc.id, doc.data()))
              .toList();
      areas.sort(
        (left, right) =>
            left.name.toLowerCase().compareTo(right.name.toLowerCase()),
      );
      return areas;
    });
  }

  @override
  Future<void> createArea({
    required String businessId,
    required String actorId,
    required String name,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const AppException('Enter an area name.');
    }
    final areaRef = _collection(businessId, 'areas').doc();
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    batch.set(areaRef, {
      'businessId': businessId,
      'name': normalizedName,
      'status': 'active',
      'assignedEmployeeIds': <String>[],
      'createdBy': actorId,
      'createdAt': now,
      'updatedAt': now,
    });
    batch.set(_collection(businessId, 'auditRecords').doc(), {
      'businessId': businessId,
      'actorId': actorId,
      'action': 'areaCreated',
      'entityType': 'area',
      'entityId': areaRef.id,
      'createdAt': now,
    });
    await _commit(batch, 'Could not create the area.');
  }

  @override
  Future<void> updateArea({
    required String businessId,
    required String actorId,
    required String areaId,
    required String name,
    required bool isActive,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const AppException('Enter an area name.');
    }
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    batch.update(_collection(businessId, 'areas').doc(areaId), {
      'businessId': businessId,
      'name': normalizedName,
      'status': isActive ? 'active' : 'inactive',
      'updatedAt': now,
    });
    batch.set(_collection(businessId, 'auditRecords').doc(), {
      'businessId': businessId,
      'actorId': actorId,
      'action': 'areaUpdated',
      'entityType': 'area',
      'entityId': areaId,
      'status': isActive ? 'active' : 'inactive',
      'createdAt': now,
    });
    await _commit(batch, 'Could not update the area.');
  }

  @override
  Future<void> setEmployeeAssignments({
    required String businessId,
    required String actorId,
    required String areaId,
    required Set<String> previousEmployeeIds,
    required Set<String> employeeIds,
  }) async {
    final added = employeeIds.difference(previousEmployeeIds);
    final removed = previousEmployeeIds.difference(employeeIds);
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    batch.update(_collection(businessId, 'areas').doc(areaId), {
      'businessId': businessId,
      'assignedEmployeeIds': employeeIds.toList()..sort(),
      'updatedAt': now,
    });
    for (final uid in added) {
      batch.update(_collection(businessId, 'members').doc(uid), {
        'areaIds': FieldValue.arrayUnion([areaId]),
        'updatedAt': now,
      });
    }
    for (final uid in removed) {
      batch.update(_collection(businessId, 'members').doc(uid), {
        'areaIds': FieldValue.arrayRemove([areaId]),
        'updatedAt': now,
      });
    }
    batch.set(_collection(businessId, 'auditRecords').doc(), {
      'businessId': businessId,
      'actorId': actorId,
      'action': 'areaEmployeeAssignmentsUpdated',
      'entityType': 'area',
      'entityId': areaId,
      'previousEmployeeIds': previousEmployeeIds.toList()..sort(),
      'employeeIds': employeeIds.toList()..sort(),
      'createdAt': now,
    });
    await _commit(batch, 'Could not update area assignments.');
  }

  Future<void> _commit(WriteBatch batch, String fallback) async {
    try {
      await batch.commit();
    } on FirebaseException catch (error) {
      throw AppException(
        error.code == 'permission-denied'
            ? 'Your Head access no longer permits this action.'
            : fallback,
        code: error.code,
      );
    }
  }
}
