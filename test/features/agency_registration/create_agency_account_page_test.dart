import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/features/agency_registration/domain/agency_registration.dart';
import 'package:paper_route/features/agency_registration/domain/agency_registration_repository.dart';
import 'package:paper_route/features/agency_registration/presentation/agency_registration_providers.dart';
import 'package:paper_route/features/agency_registration/presentation/create_agency_account_page.dart';

void main() {
  testWidgets('validates required owner, agency, auth, and consent fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agencyRegistrationRepositoryProvider.overrideWithValue(
            _FakeAgencyRegistrationRepository(),
          ),
        ],
        child: const MaterialApp(home: CreateAgencyAccountPage()),
      ),
    );
    final submit = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Owner full name is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
  });

  testWidgets('creates only an Auth identity and preserves draft in memory', (
    tester,
  ) async {
    final repository = _FakeAgencyRegistrationRepository();
    final container = ProviderContainer(
      overrides: [
        agencyRegistrationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/create-agency',
      routes: [
        GoRoute(
          path: '/create-agency',
          builder: (context, state) => const CreateAgencyAccountPage(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Auth gate')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    final values = <String, String>{
      'Owner full name': 'Synthetic Owner',
      'Owner phone': '9999999999',
      'Agency name': 'Synthetic Agency',
      'Agency phone': '8888888888',
      'Agency address': '10 Test Road',
      'Owner email': 'owner@example.com',
      'Create password': 'password-123',
    };
    for (final entry in values.entries) {
      await tester.enterText(
        find.widgetWithText(TextFormField, entry.key),
        entry.value,
      );
    }
    final terms = find.text('I accept the Terms of Service');
    await tester.ensureVisible(terms);
    await tester.tap(terms);
    final privacy = find.text('I accept the Privacy Notice');
    await tester.ensureVisible(privacy);
    await tester.tap(privacy);
    final submit = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(repository.createdEmail, 'owner@example.com');
    expect(repository.provisionCalls, 0);
    expect(
      container.read(agencyRegistrationDraftProvider)?.agencyName,
      'Synthetic Agency',
    );
    expect(
      container.read(agencyRegistrationIntentProvider),
      AgencyRegistrationIntent.createAgency,
    );
  });
}

class _FakeAgencyRegistrationRepository
    implements AgencyRegistrationRepository {
  String? createdEmail;
  int provisionCalls = 0;

  @override
  Future<void> createOwnerIdentity({
    required String email,
    required String password,
    required String displayName,
  }) async {
    createdEmail = email;
  }

  @override
  Future<AgencyRegistrationOptions> getRegistrationOptions() async =>
      const AgencyRegistrationOptions(
        eligibility: AgencyRegistrationEligibility.eligible,
        pendingInvitationCount: 0,
      );

  @override
  Future<AgencyProvisioningResult> provisionAgencyOwner({
    required AgencyRegistrationDraft draft,
  }) async {
    provisionCalls += 1;
    return const AgencyProvisioningResult(
      businessId: 'business-a',
      alreadyProvisioned: false,
    );
  }
}
