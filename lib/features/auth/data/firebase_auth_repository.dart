import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/auth/domain/auth_repository.dart';

/// Firebase implementation of authentication and invite-based provisioning.
/// The client never chooses a privileged role: Firestore Rules force an invite
/// acceptance to create an active employee membership only.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore;

  factory FirebaseAuthRepository.fromDefaultApp() => FirebaseAuthRepository(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  );

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Stream<AppUser?> watchCurrentUser() {
    // BEGINNER NOTE:
    // The session is assembled in three layers:
    // 1. Firebase Auth supplies identity and email-verification state.
    // 2. userProfiles supplies the business ID used to locate membership.
    // 3. businesses/{businessId}/members/{uid} supplies trusted authorization.
    late StreamController<AppUser?> controller;
    StreamSubscription<User?>? authSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    profileSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    memberSubscription;

    Future<void> cancelAccountSubscriptions() async {
      // A sign-out or account switch must stop the old tenant listeners before
      // any new user documents are observed.
      await profileSubscription?.cancel();
      await memberSubscription?.cancel();
      profileSubscription = null;
      memberSubscription = null;
    }

    void addError(Object error, StackTrace stackTrace) {
      if (!controller.isClosed) controller.addError(error, stackTrace);
    }

    Future<void> watchProfile(User firebaseUser) async {
      await cancelAccountSubscriptions();

      Future<void> handleProfile(
        DocumentSnapshot<Map<String, dynamic>> profile,
      ) async {
        await memberSubscription?.cancel();
        memberSubscription = null;
        final profileData = profile.data();
        final businessId = profileData?['businessId'] as String?;
        if (businessId == null || businessId.isEmpty) {
          // Authentication alone is not business access. Emitting an AppUser
          // without membership keeps the UI in its pending/setup state.
          if (!controller.isClosed) {
            controller.add(_toAppUser(firebaseUser, profileData, null));
          }
          return;
        }

        void handleMember(DocumentSnapshot<Map<String, dynamic>> member) {
          if (!controller.isClosed) {
            controller.add(
              _toAppUser(firebaseUser, profileData, member.data()),
            );
          }
        }

        memberSubscription = _firestore
            // Membership is read from the business named by the profile, then
            // constrained to the authenticated UID.
            .collection('businesses')
            .doc(businessId)
            .collection('members')
            .doc(firebaseUser.uid)
            .snapshots()
            .listen(handleMember, onError: addError);
      }

      profileSubscription = _firestore
          .collection('userProfiles')
          .doc(firebaseUser.uid)
          .snapshots()
          .listen(handleProfile, onError: addError);
    }

    Future<void> handleAuthChange(User? firebaseUser) async {
      if (firebaseUser == null) {
        await cancelAccountSubscriptions();
        if (!controller.isClosed) controller.add(null);
        return;
      }
      await watchProfile(firebaseUser);
    }

    controller = StreamController<AppUser?>(
      onListen: () {
        authSubscription = _auth.userChanges().listen(
          handleAuthChange,
          onError: addError,
        );
      },
      onCancel: () async {
        await authSubscription?.cancel();
        await cancelAccountSubscriptions();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw _friendlyAuthError(error);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (error) {
      throw _friendlyAuthError(error);
    }
  }

  @override
  Future<void> registerInvitedEmployee({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      await credential.user?.updateDisplayName(displayName.trim());
      await credential.user?.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw _friendlyAuthError(error);
    }
  }

  @override
  Future<void> resendEmailVerification() async {
    final user = _requireCurrentUser();
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw _friendlyAuthError(error);
    }
  }

  @override
  Future<void> reloadCurrentUser() async {
    await _requireCurrentUser().reload();
  }

  @override
  Future<void> acceptEmployeeInvitation({
    required String businessId,
    required String invitationId,
    required String displayName,
    required String phone,
  }) async {
    final user = _requireCurrentUser();
    await user.reload();
    final refreshedUser = _requireCurrentUser();
    if (!refreshedUser.emailVerified) {
      throw const AppException(
        'Verify your email before activating this invitation.',
        code: 'email-not-verified',
      );
    }

    final inviteRef = _firestore
        .collection('businesses')
        .doc(businessId.trim())
        .collection('invitations')
        .doc(invitationId.trim());
    final memberRef = _firestore
        .collection('businesses')
        .doc(businessId.trim())
        .collection('members')
        .doc(refreshedUser.uid);
    final profileRef = _firestore
        .collection('userProfiles')
        .doc(refreshedUser.uid);

    try {
      await _firestore.runTransaction((transaction) async {
        final invitation = await transaction.get(inviteRef);
        final data = invitation.data();
        if (!invitation.exists || data == null) {
          throw const AppException('Invitation not found or no longer valid.');
        }
        if (data['status'] != 'pending' || data['role'] != 'employee') {
          throw const AppException('This invitation has already been used.');
        }
        if (data['email'] != refreshedUser.email?.toLowerCase()) {
          throw const AppException(
            'Sign in with the same email address that was invited.',
          );
        }

        final expiresAt = data['expiresAt'];
        if (expiresAt is Timestamp &&
            expiresAt.toDate().isBefore(DateTime.now())) {
          throw const AppException('This invitation has expired.');
        }

        final permissions =
            data['permissions'] is List
                ? List<String>.from(data['permissions'] as List)
                : <String>[];
        final areaIds =
            data['areaIds'] is List
                ? List<String>.from(data['areaIds'] as List)
                : <String>[];
        final now = FieldValue.serverTimestamp();

        transaction.update(inviteRef, {
          'status': 'accepted',
          'acceptedBy': refreshedUser.uid,
          'acceptedAt': now,
        });
        transaction.set(memberRef, {
          'businessId': businessId.trim(),
          'uid': refreshedUser.uid,
          'email': refreshedUser.email?.toLowerCase(),
          'displayName': displayName.trim(),
          'phone': phone.trim(),
          'role': 'employee',
          'status': 'active',
          'permissions': permissions,
          'areaIds': areaIds,
          'acceptedInviteId': invitationId.trim(),
          'createdAt': now,
          'updatedAt': now,
        });
        transaction.set(profileRef, {
          'uid': refreshedUser.uid,
          'email': refreshedUser.email?.toLowerCase(),
          'displayName': displayName.trim(),
          'phone': phone.trim(),
          'businessId': businessId.trim(),
          'role': 'employee',
          'status': 'active',
          'permissions': permissions,
          'acceptedInviteId': invitationId.trim(),
          'createdAt': now,
          'updatedAt': now,
        });
      });
    } on FirebaseException catch (error) {
      throw AppException(
        error.code == 'permission-denied'
            ? 'The invitation could not be verified. Check the business and invitation codes.'
            : 'Could not activate access. Please try again.',
        code: error.code,
      );
    }
  }

  User _requireCurrentUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AppException('Your session has ended. Please sign in again.');
    }
    return user;
  }

  AppUser _toAppUser(
    User user,
    Map<String, Object?>? profile,
    Map<String, Object?>? member,
  ) {
    // BEGINNER NOTE:
    // A profile helps find and display an account, but only the membership can
    // grant a role, active status, permissions, or assigned areas.
    // Memberships are the sole authority for role, status, and permissions.
    // A profile can locate the tenant and supply presentation details, but a
    // missing membership must never inherit privileges from profile data.
    final role = switch (member?['role']) {
      'head' => UserRole.head,
      'employee' => UserRole.employee,
      _ => null,
    };
    final status = switch (member?['status']) {
      'active' => AccountStatus.active,
      'inactive' => AccountStatus.inactive,
      _ => AccountStatus.pending,
    };
    final rawPermissions = member?['permissions'];
    final permissions =
        rawPermissions is List
            ? rawPermissions.whereType<String>().toSet()
            : <String>{};
    final rawAreaIds = member?['areaIds'];
    final areaIds =
        rawAreaIds is List
            ? rawAreaIds.whereType<String>().toSet()
            : <String>{};

    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName:
          (member?['displayName'] as String?) ??
          (profile?['displayName'] as String?) ??
          user.displayName ??
          '',
      isEmailVerified: user.emailVerified,
      businessId:
          (member?['businessId'] as String?) ??
          (profile?['businessId'] as String?),
      role: role,
      status: status,
      permissions: permissions,
      areaIds: areaIds,
    );
  }

  AppException _friendlyAuthError(FirebaseAuthException error) {
    final message = switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'The email or password is incorrect.',
      'invalid-email' => 'Enter a valid email address.',
      'email-already-in-use' => 'An account already exists for this email.',
      'weak-password' => 'Use a password with at least 8 characters.',
      'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
      'network-request-failed' =>
        'Check your internet connection and try again.',
      _ => 'Authentication failed. Please try again.',
    };
    return AppException(message, code: error.code);
  }
}
