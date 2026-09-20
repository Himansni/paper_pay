import 'package:paper_route/features/auth/domain/app_user.dart';

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
