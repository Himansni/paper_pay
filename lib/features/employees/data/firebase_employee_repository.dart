import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/employees/domain/employee_invitation.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';
import 'package:paper_route/features/employees/domain/employee_repository.dart';

class FirebaseEmployeeRepository implements EmployeeRepository {
  FirebaseEmployeeRepository(this._firestore);

  factory FirebaseEmployeeRepository.fromDefaultApp() =>
      FirebaseEmployeeRepository(FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _businessCollection(
    String businessId,
    String collection,
  ) => _firestore
      .collection('businesses')
      .doc(businessId)
      .collection(collection);

  @override
  Stream<List<EmployeeMember>> watchMembers(String businessId) {
    return _businessCollection(businessId, 'members').snapshots().map((event) {
      final members =
          event.docs
              .map((doc) => EmployeeMember.fromMap(doc.id, doc.data()))
              .toList();
      members.sort((left, right) {
        if (left.isHead != right.isHead) return left.isHead ? -1 : 1;
        return left.displayName.toLowerCase().compareTo(
          right.displayName.toLowerCase(),
        );
      });
      return members;
    });
  }

  @override
  Stream<List<EmployeeInvitation>> watchInvitations(String businessId) {
    return _businessCollection(businessId, 'invitations').snapshots().map((
      event,
    ) {
      final invitations =
          event.docs.map((doc) {
            final data = doc.data();
            final expiresAt = data['expiresAt'];
            return EmployeeInvitation.fromMap(
              doc.id,
              data,
              expiresAt:
                  expiresAt is Timestamp
                      ? expiresAt.toDate()
                      : DateTime.fromMillisecondsSinceEpoch(0),
            );
          }).toList();
      invitations.sort(
        (left, right) => right.expiresAt.compareTo(left.expiresAt),
      );
      return invitations;
    });
  }

  @override
  Future<String> createInvitation({
    required String businessId,
    required String actorId,
    required String email,
    required Set<String> permissions,
    required Set<String> areaIds,
    required DateTime expiresAt,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw const AppException('Enter a valid employee email address.');
    }
    if (!expiresAt.isAfter(DateTime.now())) {
      throw const AppException('Invitation expiry must be in the future.');
    }

    final inviteRef = _businessCollection(businessId, 'invitations').doc();
    final auditRef = _businessCollection(businessId, 'auditRecords').doc();
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    batch.set(inviteRef, {
      'businessId': businessId,
      'email': normalizedEmail,
      'role': 'employee',
      'status': 'pending',
      'permissions': permissions.toList()..sort(),
      'areaIds': areaIds.toList()..sort(),
      'createdBy': actorId,
      'createdAt': now,
      'expiresAt': Timestamp.fromDate(expiresAt.toUtc()),
    });
    batch.set(auditRef, {
      'businessId': businessId,
      'actorId': actorId,
      'action': 'employeeInvitationCreated',
      'entityType': 'invitation',
      'entityId': inviteRef.id,
      'createdAt': now,
    });

    try {
      await batch.commit();
      return inviteRef.id;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not create the employee invitation.');
    }
  }

  @override
  Future<void> updateMemberAccess({
    required String businessId,
    required String actorId,
    required String memberId,
    required String displayName,
    required String phone,
    required String notes,
    required bool isActive,
    required Set<String> permissions,
  }) async {
    if (memberId == actorId) {
      throw const AppException(
        'The signed-in Head account cannot edit itself.',
      );
    }
    if (displayName.trim().isEmpty) {
      throw const AppException('Enter the employee name.');
    }
    final memberRef = _businessCollection(businessId, 'members').doc(memberId);
    final auditRef = _businessCollection(businessId, 'auditRecords').doc();
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    batch.update(memberRef, {
      'displayName': displayName.trim(),
      'phone': phone.trim(),
      'notes': notes.trim(),
      'status': isActive ? 'active' : 'inactive',
      'permissions': permissions.toList()..sort(),
      'updatedAt': now,
    });
    batch.set(auditRef, {
      'businessId': businessId,
      'actorId': actorId,
      'action': 'employeeAccessUpdated',
      'entityType': 'member',
      'entityId': memberId,
      'status': isActive ? 'active' : 'inactive',
      'permissions': permissions.toList()..sort(),
      'createdAt': now,
    });

    try {
      await batch.commit();
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not update employee access.');
    }
  }

  @override
  Future<void> revokeInvitation({
    required String businessId,
    required String actorId,
    required String invitationId,
  }) async {
    final inviteRef = _businessCollection(
      businessId,
      'invitations',
    ).doc(invitationId);
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();
    batch.update(inviteRef, {
      'status': 'revoked',
      'revokedAt': now,
      'updatedAt': now,
    });
    batch.set(_businessCollection(businessId, 'auditRecords').doc(), {
      'businessId': businessId,
      'actorId': actorId,
      'action': 'employeeInvitationRevoked',
      'entityType': 'invitation',
      'entityId': invitationId,
      'createdAt': now,
    });

    try {
      await batch.commit();
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not revoke the invitation.');
    }
  }

  AppException _translate(FirebaseException error, String fallback) {
    return AppException(
      error.code == 'permission-denied'
          ? 'Your Head access no longer permits this action.'
          : fallback,
      code: error.code,
    );
  }
}
