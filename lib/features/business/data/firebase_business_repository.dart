import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/business/domain/business_profile.dart';
import 'package:paper_route/features/business/domain/business_repository.dart';

// BEGINNER NOTE:
// [FirebaseBusinessRepository] manages the root tenant document in Firestore:
// `businesses/{businessId}`.
// It also records an append-only audit trail in `businesses/{businessId}/auditRecords`
// for every critical business profile change.
class FirebaseBusinessRepository implements BusinessRepository {
  FirebaseBusinessRepository(this._firestore);

  factory FirebaseBusinessRepository.fromDefaultApp() =>
      FirebaseBusinessRepository(FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _business(String businessId) =>
      _firestore.collection('businesses').doc(businessId);

  // BEGINNER NOTE:
  // Listens to real-time snapshot changes on the tenant document, emitting updated
  // [BusinessProfile] objects whenever business details change.
  @override
  Stream<BusinessProfile> watchBusiness(String businessId) {
    return _business(businessId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw const AppException('Business record no longer exists.');
      }
      return BusinessProfile.fromMap(snapshot.id, data);
    });
  }

  // BEGINNER NOTE:
  // Performs an atomic batch update:
  // 1. Updates the `businesses/{businessId}` profile document.
  // 2. Writes an append-only event into `businesses/{businessId}/auditRecords`.
  // If either operation fails, neither is committed to Firestore.
  @override
  Future<void> updateBusiness({
    required String businessId,
    required String actorId,
    required String name,
    required String phone,
    required String address,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const AppException('Enter the business name.');
    }

    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    batch.update(_business(businessId), {
      'name': normalizedName,
      'phone': phone.trim(),
      'address': address.trim(),
      'updatedAt': now,
    });
    batch.set(_business(businessId).collection('auditRecords').doc(), {
      'businessId': businessId,
      'actorId': actorId,
      'action': 'businessSettingsUpdated',
      'entityType': 'business',
      'entityId': businessId,
      'createdAt': now,
    });

    try {
      await batch.commit();
    } on FirebaseException catch (error) {
      throw AppException(
        error.code == 'permission-denied'
            ? 'Your Head access no longer permits business changes.'
            : 'Could not update business settings.',
        code: error.code,
      );
    }
  }

  // BEGINNER NOTE:
  // Validates the geographic region, updates the tenant root document, and appends
  // an audit record containing the new territory values for administrative accountability.
  @override
  Future<void> updatePrimaryPricingRegion({
    required String businessId,
    required String actorId,
    required PricingRegion region,
  }) async {
    final value = region.normalized();
    try {
      value.validate();
    } on FormatException catch (error) {
      throw AppException(error.message);
    }
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    batch.update(_business(businessId), {
      'primaryPricingRegion': value.toMap(),
      'updatedAt': now,
    });
    batch.set(_business(businessId).collection('auditRecords').doc(), {
      'businessId': businessId,
      'actorId': actorId,
      'action': 'primaryPricingRegionUpdated',
      'entityType': 'business',
      'entityId': businessId,
      'state': value.state,
      'districtCity': value.districtCity,
      'editionServiceRegion': value.editionServiceRegion,
      'createdAt': now,
    });
    try {
      await batch.commit();
    } on FirebaseException catch (error) {
      throw AppException(
        error.code == 'permission-denied'
            ? 'Your Head access no longer permits region changes.'
            : 'Could not update the primary pricing region.',
        code: error.code,
      );
    }
  }
}
