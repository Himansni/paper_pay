import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paper_route/core/config/firebase_bootstrap.dart';
import 'package:paper_route/features/agency_registration/data/firebase_agency_registration_repository.dart';
import 'package:paper_route/features/agency_registration/presentation/agency_registration_gate.dart';
import 'package:paper_route/features/agency_registration/presentation/agency_registration_providers.dart';
import 'package:paper_route/features/auth/data/firebase_auth_repository.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/auth/presentation/auth_gate.dart';
import 'package:paper_route/features/auth/presentation/auth_providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('verified owner provisions one agency through the connected UI', (
    tester,
  ) async {
    final startup = await FirebaseBootstrap.initialize();
    expect(startup.isReady, isTrue);
    final auth = FirebaseAuth.instance;
    await auth.signOut();
    final credential = await auth.signInWithEmailAndPassword(
      email: 'flutter-owner@example.test',
      password: 'Owner-Smoke-2026!',
    );
    expect(credential.user!.emailVerified, isTrue);
    final pendingOwner = AppUser(
      uid: credential.user!.uid,
      email: credential.user!.email!,
      displayName: credential.user!.displayName ?? 'Flutter Owner',
      isEmailVerified: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FirebaseAuthRepository.fromDefaultApp(),
          ),
          agencyRegistrationRepositoryProvider.overrideWithValue(
            FirebaseAgencyRegistrationRepository.fromDefaultApp(),
          ),
        ],
        child: MaterialApp(home: AgencyRegistrationGate(user: pendingOwner)),
      ),
    );
    await _pumpUntil(tester, find.text('Set up your agency'));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Owner phone'),
      '9999999999',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Agency name'),
      'Flutter Emulator Agency',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Agency phone'),
      '8888888888',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Agency address'),
      '20 Emulator Road, Test City',
    );
    final terms = find.text('I accept the Terms of Service');
    await tester.ensureVisible(terms);
    await tester.tap(terms);
    final privacy = find.text('I accept the Privacy Notice');
    await tester.ensureVisible(privacy);
    await tester.tap(privacy);
    final submit = find.text('Create my agency');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    final profileReference = FirebaseFirestore.instance.doc(
      'userProfiles/${credential.user!.uid}',
    );
    final profile = await _waitForDocument(tester, profileReference);
    expect(profile.exists, isTrue);
    final businessId = profile.data()!['businessId'] as String;
    final membership =
        await FirebaseFirestore.instance
            .doc('businesses/$businessId/members/${credential.user!.uid}')
            .get();
    expect(membership.data()!['role'], 'head');
    expect(membership.data()!['status'], 'active');
    expect(membership.data()!['permissions'], isEmpty);
    expect(membership.data()!['areaIds'], isEmpty);
    final consent =
        await FirebaseFirestore.instance
            .doc(
              'userConsents/${credential.user!.uid}/acceptances/terms-v1__privacy-v1',
            )
            .get();
    expect(consent.data()!['termsVersion'], 'terms-v1');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FirebaseAuthRepository.fromDefaultApp(),
          ),
          agencyRegistrationRepositoryProvider.overrideWithValue(
            FirebaseAgencyRegistrationRepository.fromDefaultApp(),
          ),
        ],
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await _pumpUntil(tester, find.text('Head Distributor workspace'));
  });
}

Future<DocumentSnapshot<Map<String, dynamic>>> _waitForDocument(
  WidgetTester tester,
  DocumentReference<Map<String, dynamic>> reference,
) async {
  for (var attempt = 0; attempt < 60; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 500));
    final snapshot = await reference.get();
    if (snapshot.exists) return snapshot;
  }
  final snapshot = await reference.get();
  expect(snapshot.exists, isTrue);
  return snapshot;
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int attempts = 60,
}) async {
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 500));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}
