import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paper_route/app/paper_route_app.dart';
import 'package:paper_route/core/config/firebase_bootstrap.dart';
import 'package:paper_route/features/auth/data/firebase_auth_repository.dart';
import 'package:paper_route/features/auth/presentation/auth_providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Head and employee complete the connected customer lifecycle', (
    tester,
  ) async {
    final startup = await FirebaseBootstrap.initialize();
    expect(startup.isReady, isTrue);
    await FirebaseAuth.instance.signOut();

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
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'phase3-head@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'Phase3-Smoke-2026!',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await _settleRemote(tester);
    expect(find.text('Head Distributor workspace'), findsOneWidget);

    await tester.tap(find.text('Customers'));
    await _settleRemote(tester);
    expect(find.text('Customer directory'), findsOneWidget);

    await tester.tap(find.text('New customer'));
    await tester.pumpAndSettle();
    expect(find.text('Customer profile'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Customer name'),
      'Smoke Household',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Primary phone'),
      '9876543210',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'House / flat number (optional)'),
      '42-B',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Building / floor details (optional)'),
      'First floor',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full address'),
      '42 Central Market Road',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Recognizable landmark'),
      'Old Clock Tower',
    );
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Location-identification notes (optional)',
      ),
      'Blue gate beside pharmacy',
    );

    final areaDropdown = find.byKey(const ValueKey('customer-area-dropdown'));
    await tester.scrollUntilVisible(
      areaDropdown,
      450,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(areaDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Central Route').last);
    await tester.pumpAndSettle();

    final openingBalance = find.widgetWithText(
      TextFormField,
      'Opening balance (₹)',
    );
    await tester.scrollUntilVisible(
      openingBalance,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(openingBalance, '25.50');
    final create = find.text('Create customer');
    await tester.scrollUntilVisible(
      create,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(create);
    await _settleRemote(tester);

    await _expectEventually(tester, find.text('Smoke Household'));
    await tester.tap(find.text('Smoke Household'));
    await _settleRemote(tester);
    expect(find.text('Find the house'), findsOneWidget);
    expect(find.text('LANDMARK: Old Clock Tower'), findsOneWidget);
    expect(find.text('Blue gate beside pharmacy'), findsOneWidget);

    final changeAssignment = find.text('Change assignment');
    await tester.scrollUntilVisible(
      changeAssignment,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(changeAssignment);
    await tester.pumpAndSettle();
    final dialogDropdowns = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    expect(dialogDropdowns, findsNWidgets(2));
    await tester.tap(dialogDropdowns.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smoke Employee').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save assignment'));
    await _settleRemote(tester);
    expect(find.text('Smoke Employee'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit customer'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Recognizable landmark'),
      'Updated Clock Tower',
    );
    final save = find.text('Save customer changes');
    await tester.scrollUntilVisible(
      save,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await _settleRemote(tester);
    final updatedLandmark = find.text('LANDMARK: Updated Clock Tower');
    await tester.scrollUntilVisible(
      updatedLandmark,
      -500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(updatedLandmark, findsOneWidget);

    final archive = find.text('Archive customer');
    await tester.scrollUntilVisible(
      archive,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(archive);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await _settleRemote(tester);
    final reactivate = find.text('Reactivate customer');
    await tester.scrollUntilVisible(
      reactivate,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(reactivate, findsOneWidget);

    await tester.tap(reactivate);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reactivate'));
    await _settleRemote(tester);
    final archiveAgain = find.text('Archive customer');
    await tester.scrollUntilVisible(
      archiveAgain,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(archiveAgain, findsOneWidget);
    expect(find.text('Customer created'), findsOneWidget);
    expect(find.text('Assignment transferred'), findsOneWidget);
    expect(find.text('Customer details updated'), findsOneWidget);
    expect(find.text('Customer archived'), findsOneWidget);
    expect(find.text('Customer reactivated'), findsOneWidget);

    await FirebaseAuth.instance.signOut();
    await _settleRemote(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'phase3-employee@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'Phase3-Employee-2026!',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await _settleRemote(tester);
    expect(find.text('Find the house'), findsOneWidget);
    expect(find.text('Financial opening'), findsNothing);

    await tester.tap(find.byType(BackButton));
    await _settleRemote(tester);
    expect(find.text('Your assigned route'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Employee distribution workspace'), findsOneWidget);

    await tester.tap(find.text('My customers'));
    await _settleRemote(tester);
    expect(find.text('Your assigned route'), findsOneWidget);
    expect(find.text('Smoke Household'), findsOneWidget);
    await tester.tap(find.text('Smoke Household'));
    await _settleRemote(tester);
    await tester.tap(find.byTooltip('Edit customer'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Location-identification notes (optional)',
      ),
      'Employee confirmed the blue gate',
    );
    final employeeSave = find.text('Save customer changes');
    await tester.scrollUntilVisible(
      employeeSave,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(employeeSave);
    await _settleRemote(tester);
    final employeeLocationNote = find.text('Employee confirmed the blue gate');
    await tester.scrollUntilVisible(
      employeeLocationNote,
      -500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(employeeLocationNote, findsOneWidget);
  });
}

Future<void> _settleRemote(WidgetTester tester) async {
  // Firestore listeners can keep scheduling frames while the route changes.
  // Bound remote settling so a genuine loading or permission failure reaches
  // the following assertion instead of hanging for pumpAndSettle's timeout.
  for (var index = 0; index < 16; index++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _expectEventually(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  final observedText = <String>{};
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    observedText.addAll(
      tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty),
    );
    await tester.pump(const Duration(milliseconds: 250));
  }
  if (finder.evaluate().isEmpty) {
    fail('Expected $finder. Observed text: ${observedText.join(' | ')}');
  }
}
