import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paper_route/app/paper_route_app.dart';
import 'package:paper_route/core/config/firebase_bootstrap.dart';
import 'package:paper_route/features/auth/data/firebase_auth_repository.dart';
import 'package:paper_route/features/auth/presentation/auth_providers.dart';
import 'package:paper_route/features/employees/data/firebase_employee_repository.dart';

const _businessId = 'employee-flow-business';
const _headEmail = 'employee-flow-head@example.test';
const _employeeEmail = 'invited-employee@example.test';
const _password = 'Employee-Smoke-2026!';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('invited employee activates and can sign in again', (
    tester,
  ) async {
    final startup = await FirebaseBootstrap.initialize();
    expect(startup.isReady, isTrue);
    final auth = FirebaseAuth.instance;
    await auth.signOut();
    final head = await auth.signInWithEmailAndPassword(
      email: _headEmail,
      password: _password,
    );
    final invitationId = await FirebaseEmployeeRepository.fromDefaultApp()
        .createInvitation(
          businessId: _businessId,
          actorId: head.user!.uid,
          email: _employeeEmail,
          permissions: const {'addCustomers'},
          areaIds: const {'employee-area'},
          expiresAt: DateTime.now().add(const Duration(days: 1)),
        );
    await auth.signOut();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FirebaseAuthRepository.fromDefaultApp(),
          ),
        ],
        child: PaperRouteApp(startup: startup),
      ),
    );
    await _pumpUntil(tester, find.text('Welcome back'));
    await tester.tap(find.text('I have an employee invitation'));
    await _pumpUntil(tester, find.text('Create employee login'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Invited Employee',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Invited email'),
      _employeeEmail,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Create password'),
      _password,
    );
    await tester.tap(find.text('Create account'));
    await _pumpUntil(tester, find.text('Verify your email'));

    // The Node harness marks this synthetic emulator account verified, just as
    // opening the emulator verification link would do.
    for (var attempt = 0; attempt < 30; attempt += 1) {
      await tester.tap(find.text('I have verified my email'));
      await tester.pump(const Duration(milliseconds: 500));
      if (find.text('Activate your access').evaluate().isNotEmpty) break;
    }
    await _pumpUntil(tester, find.text('Activate your access'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Business ID'),
      _businessId,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Invitation code'),
      invitationId,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone number'),
      '9000000001',
    );
    await tester.tap(find.text('Activate access'));
    await _pumpUntil(tester, find.text('Employee distribution workspace'));

    final employee = auth.currentUser!;
    final member =
        await FirebaseFirestore.instance
            .doc('businesses/$_businessId/members/${employee.uid}')
            .get();
    final profile =
        await FirebaseFirestore.instance
            .doc('userProfiles/${employee.uid}')
            .get();
    expect(member.data()!['role'], 'employee');
    expect(member.data()!['status'], 'active');
    expect(member.data()!['acceptedInviteId'], invitationId);
    expect(profile.data()!['businessId'], _businessId);

    await tester.tap(find.byTooltip('Sign out'));
    await _pumpUntil(tester, find.text('Welcome back'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      _employeeEmail,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      _password,
    );
    await tester.tap(find.text('Sign in'));
    await _pumpUntil(tester, find.text('Employee distribution workspace'));
  });
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
