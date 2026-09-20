import 'package:paper_route/features/auth/domain/app_user.dart';

/// Boundary used by Riverpod and the UI instead of depending directly on the
/// Firebase SDK. Production supplies FirebaseAuthRepository; tests can supply a
/// controlled implementation without contacting a real project.
abstract interface class AuthRepository {
  Stream<AppUser?> watchCurrentUser();

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  Future<void> sendPasswordReset(String email);

  Future<void> registerInvitedEmployee({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> resendEmailVerification();

  Future<void> reloadCurrentUser();

  Future<void> acceptEmployeeInvitation({
    required String businessId,
    required String invitationId,
    required String displayName,
    required String phone,
  });
}
