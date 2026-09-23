import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/saas/domain/saas_models.dart';
import 'package:paper_route/features/saas/domain/saas_repository.dart';

class FirebaseSaasRepository implements SaasRepository {
  FirebaseSaasRepository(this._firestore);

  factory FirebaseSaasRepository.fromDefaultApp() =>
      FirebaseSaasRepository(FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _business(String businessId) =>
      _firestore.collection('businesses').doc(businessId);

  DocumentReference<Map<String, dynamic>> _saasDoc(String businessId) =>
      _business(businessId).collection('subscription').doc('saas');

  @override
  Stream<SaasSubscription> watchSubscription(String businessId) {
    return _saasDoc(businessId).snapshots().asyncMap((snapshot) async {
      DateTime? fallbackActivationTime;
      if (!snapshot.exists) {
        final bizSnap = await _business(businessId).get();
        if (bizSnap.exists) {
          final created = bizSnap.data()?['createdAt'];
          if (created is Timestamp) {
            fallbackActivationTime = created.toDate();
          }
        }
      }
      return SaasSubscription.fromMap(
        businessId,
        snapshot.data(),
        fallbackActivationTime: fallbackActivationTime,
      );
    });
  }

  @override
  Future<SaasSubscription> fetchSubscription(String businessId) async {
    try {
      final snapshot = await _saasDoc(businessId).get();
      DateTime? fallbackActivationTime;
      if (!snapshot.exists) {
        final bizSnap = await _business(businessId).get();
        if (bizSnap.exists) {
          final created = bizSnap.data()?['createdAt'];
          if (created is Timestamp) {
            fallbackActivationTime = created.toDate();
          }
        }
      }
      return SaasSubscription.fromMap(
        businessId,
        snapshot.data(),
        fallbackActivationTime: fallbackActivationTime,
      );
    } on FirebaseException catch (error) {
      throw AppException(
        error.message ?? 'Could not load SaaS subscription.',
        code: error.code,
      );
    }
  }

  @override
  Future<void> requestPlanRenewal({
    required String businessId,
    required String actorId,
    required String targetPlanId,
  }) async {
    // Audit renewal intent. Actual plan activation requires authoritative server verification.
    final now = FieldValue.serverTimestamp();
    try {
      await _business(businessId).collection('auditRecords').doc().set({
        'businessId': businessId,
        'actorId': actorId,
        'action': 'saasPlanRenewalRequested',
        'entityType': 'saasSubscription',
        'entityId': 'saas',
        'targetPlanId': targetPlanId,
        'createdAt': now,
      });
    } on FirebaseException catch (error) {
      throw AppException(
        error.message ?? 'Could not request plan renewal.',
        code: error.code,
      );
    }
  }
}
