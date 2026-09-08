enum UserRole { head, employee }

enum AccountStatus { active, inactive, pending }

/// Auth identity joined with the trusted membership projection stored in
/// Firestore. A missing role means the email is authenticated but not yet
/// authorized for a business.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.isEmailVerified,
    this.businessId,
    this.role,
    this.status = AccountStatus.pending,
    this.permissions = const {},
  });

  final String uid;
  final String email;
  final String displayName;
  final bool isEmailVerified;
  final String? businessId;
  final UserRole? role;
  final AccountStatus status;
  final Set<String> permissions;

  bool get hasActiveAccess =>
      businessId != null && role != null && status == AccountStatus.active;

  bool get isHead => role == UserRole.head;
}
