import 'package:flutter/foundation.dart';

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
    this.areaIds = const {},
  });

  final String uid;
  final String email;
  final String displayName;
  final bool isEmailVerified;
  final String? businessId;
  final UserRole? role;
  final AccountStatus status;
  final Set<String> permissions;
  final Set<String> areaIds;

  bool get hasActiveAccess =>
      businessId != null && role != null && status == AccountStatus.active;

  bool get isHead => role == UserRole.head;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppUser &&
        other.uid == uid &&
        other.email == email &&
        other.displayName == displayName &&
        other.isEmailVerified == isEmailVerified &&
        other.businessId == businessId &&
        other.role == role &&
        other.status == status &&
        setEquals(other.permissions, permissions) &&
        setEquals(other.areaIds, areaIds);
  }

  @override
  int get hashCode {
    int permHash = 0;
    for (final p in permissions) {
      permHash ^= p.hashCode;
    }
    int areaHash = 0;
    for (final a in areaIds) {
      areaHash ^= a.hashCode;
    }
    return Object.hash(
      uid,
      email,
      displayName,
      isEmailVerified,
      businessId,
      role,
      status,
      permHash,
      areaHash,
    );
  }
}

