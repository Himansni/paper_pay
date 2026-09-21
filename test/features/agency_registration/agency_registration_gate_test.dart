import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/features/agency_registration/domain/agency_registration.dart';
import 'package:paper_route/features/agency_registration/domain/agency_registration_repository.dart';
import 'package:paper_route/features/agency_registration/presentation/agency_registration_gate.dart';
import 'package:paper_route/features/agency_registration/presentation/agency_registration_providers.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/auth/domain/auth_repository.dart';
import 'package:paper_route/features/auth/presentation/auth_providers.dart';

void main() {
  const user = AppUser(
    uid: 'owner-1',
    email: 'owner@example.com',
    displayName: 'Owner',
    isEmailVerified: true,
  );

  testWidgets('pending invitation offers employee or independent owner path', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          agencyRegistrationRepositoryProvider.overrideWithValue(
            _FakeRegistrationRepository(pendingInvitations: 1),
          ),
        ],
        child: const MaterialApp(home: AgencyRegistrationGate(user: user)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Accept employee invitation'), findsOneWidget);
    expect(find.text('Create my own agency'), findsOneWidget);

    await tester.tap(find.text('Create my own agency'));
    await tester.pumpAndSettle();
    expect(find.text('Set up your agency'), findsOneWidget);
  });

  testWidgets('trusted conflict fails closed without showing setup form', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          agencyRegistrationRepositoryProvider.overrideWithValue(
            _FakeRegistrationRepository(blocked: true),
          ),
        ],
        child: const MaterialApp(home: AgencyRegistrationGate(user: user)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Account requires review'), findsOneWidget);
    expect(find.text('Create my agency'), findsNothing);
  });
}

class _FakeRegistrationRepository implements AgencyRegistrationRepository {
  _FakeRegistrationRepository({
    this.pendingInvitations = 0,
    this.blocked = false,
  });

  final int pendingInvitations;
  final bool blocked;

  @override
  Future<void> createOwnerIdentity({
    required String email,
    required String password,
    required String displayName,
  }) async {}

  @override
  Future<AgencyRegistrationOptions> getRegistrationOptions() async =>
      AgencyRegistrationOptions(
        eligibility:
            blocked
                ? AgencyRegistrationEligibility.blocked
                : AgencyRegistrationEligibility.eligible,
        pendingInvitationCount: pendingInvitations,
        conflictReason: blocked ? 'existing-membership' : null,
      );

  @override
  Future<AgencyProvisioningResult> provisionAgencyOwner({
    required AgencyRegistrationDraft draft,
  }) async => const AgencyProvisioningResult(
    businessId: 'business-a',
    alreadyProvisioned: false,
  );
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> acceptEmployeeInvitation({
    required String businessId,
    required String invitationId,
    required String displayName,
    required String phone,
  }) async {}

  @override
  Future<void> registerInvitedEmployee({
    required String email,
    required String password,
    required String displayName,
  }) async {}

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<void> resendEmailVerification() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Stream<AppUser?> watchCurrentUser() => const Stream.empty();
}
