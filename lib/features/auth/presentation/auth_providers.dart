import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/auth/domain/auth_repository.dart';

/// Dependency-injection point replaced with FirebaseAuthRepository in main().
/// Throwing here makes a missing startup override fail immediately and clearly.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw StateError('AuthRepository must be configured at app startup.');
});

// BEGINNER NOTE:
// StreamProvider keeps the UI subscribed to sign-in, email-verification,
// profile, and membership changes. AuthGate rebuilds whenever this value moves
// between loading, error, signed-out, pending-access, and active-access states.
final authSessionProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).watchCurrentUser();
});
