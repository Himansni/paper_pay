import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/business/domain/business_profile.dart';
import 'package:paper_route/features/business/domain/business_repository.dart';

class FirebaseBusinessRepository implements BusinessRepository {
  FirebaseBusinessRepository(this._firestore);

  factory FirebaseBusinessRepository.fromDefaultApp() =>
      FirebaseBusinessRepository(FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _business(String businessId) =>
      _firestore.collection('businesses').doc(businessId);

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
}
