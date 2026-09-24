import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/auth/domain/auth_repository.dart';
import 'package:paper_route/features/auth/presentation/access_pending_page.dart';
import 'package:paper_route/features/auth/presentation/auth_providers.dart';

class _FakeAuthRepository implements AuthRepository {
  String? lastBusinessId;
  String? lastInvitationId;
  String? lastDisplayName;
  String? lastPhone;
  AppException? errorToThrow;

  @override
  Future<void> acceptEmployeeInvitation({
    required String businessId,
    required String invitationId,
    required String displayName,
    required String phone,
  }) async {
    lastBusinessId = businessId;
    lastInvitationId = invitationId;
    lastDisplayName = displayName;
    lastPhone = phone;
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Stream<AppUser?> watchCurrentUser() => Stream.value(null);

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<void> resendEmailVerification() async {}

  @override
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> registerInvitedEmployee({
    required String email,
    required String password,
    required String displayName,
  }) async {}

  @override
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> reauthenticate({required String password}) async {}

  @override
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> requestAccountDeletion({
    required String confirmation,
    String? reason,
  }) async {}
}

void main() {
  const user = AppUser(
    uid: 'emp-123',
    email: 'craftares.online@gmail.com',
    displayName: 'Rahul',
    isEmailVerified: true,
    role: UserRole.employee,
    status: AccountStatus.pending,
  );

  testWidgets('displays signed-in email and disables autocorrect/capitalization on codes', (
    tester,
  ) async {
    final fakeRepo = _FakeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: AccessPendingPage(user: user),
        ),
      ),
    );

    // Subtitle shows signed in email clearly
    expect(
      find.textContaining('Signed in as craftares.online@gmail.com'),
      findsOneWidget,
    );

    // Find inner TextFields
    final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    // First is Business ID, second is Invitation code
    expect(textFields[0].textCapitalization, TextCapitalization.none);
    expect(textFields[0].autocorrect, isFalse);

    expect(textFields[1].textCapitalization, TextCapitalization.none);
    expect(textFields[1].autocorrect, isFalse);
  });

  testWidgets('trims input whitespace before submitting activation', (
    tester,
  ) async {
    final fakeRepo = _FakeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: AccessPendingPage(user: user),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Business ID'),
      '  biz_founder_acceptance  ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Invitation code'),
      '  n9QOMgv3bk87wGfGU5Qq  ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      '  Rahul  ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone number'),
      '  9876543210  ',
    );
    await tester.ensureVisible(find.text('Activate access'));
    await tester.tap(find.text('Activate access'));
    await tester.pump();

    expect(fakeRepo.lastBusinessId, 'biz_founder_acceptance');
    expect(fakeRepo.lastInvitationId, 'n9QOMgv3bk87wGfGU5Qq');
    expect(fakeRepo.lastDisplayName, 'Rahul');
    expect(fakeRepo.lastPhone, '9876543210');
  });

  testWidgets('displays actionable error when signed in with wrong email', (
    tester,
  ) async {
    final fakeRepo = _FakeAuthRepository();
    fakeRepo.errorToThrow = const AppException(
      'Sign in with the invited email address. Currently signed in as craftares.online@gmail.com.',
      code: 'invitation-email-mismatch',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: AccessPendingPage(user: user),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Business ID'),
      'biz_founder_acceptance',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Invitation code'),
      'n9QOMgv3bk87wGfGU5Qq',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Rahul',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone number'),
      '9876543210',
    );
    await tester.ensureVisible(find.text('Activate access'));
    await tester.tap(find.text('Activate access'));
    await tester.pump();

    expect(
      find.text(
        'Sign in with the invited email address. Currently signed in as craftares.online@gmail.com.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('displays specific error when invitation is already used or expired', (
    tester,
  ) async {
    final fakeRepo = _FakeAuthRepository();
    fakeRepo.errorToThrow = const AppException(
      'This invitation has already been used.',
      code: 'invitation-already-used',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: AccessPendingPage(user: user),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Business ID'),
      'biz_founder_acceptance',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Invitation code'),
      'n9QOMgv3bk87wGfGU5Qq',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Rahul',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone number'),
      '9876543210',
    );
    await tester.ensureVisible(find.text('Activate access'));
    await tester.tap(find.text('Activate access'));
    await tester.pump();

    expect(
      find.text('This invitation has already been used.'),
      findsOneWidget,
    );
  });
}
