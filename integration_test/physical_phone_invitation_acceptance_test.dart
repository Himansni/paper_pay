import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paper_route/core/config/firebase_bootstrap.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/data/firebase_auth_repository.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';

const _businessId = 'biz_founder_acceptance';
const _invitationId = 'n9QOMgv3bk87wGfGU5Qq';
const _employeeEmail = 'craftares.online@gmail.com';
const _employeePassword = String.fromEnvironment('FOUNDER_EMP_PASSWORD');

void main() {
  if (_employeePassword.isEmpty) {
    throw Exception('FOUNDER_EMP_PASSWORD is required. Pass using --dart-define');
  }
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Real employee invitation activation flow against paperroutedev',
    (tester) async {
      print('=== STARTING PHYSICAL PHONE ACCEPTANCE #2 INTEGRATION TEST ===');

      final startup = await FirebaseBootstrap.initialize();
      expect(startup.isReady, isTrue);
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      final authRepo = FirebaseAuthRepository.fromDefaultApp();

      // 1. Sign in as invited employee
      await auth.signOut();
      final cred = await auth.signInWithEmailAndPassword(
        email: _employeeEmail,
        password: _employeePassword,
      );
      final employeeUid = cred.user!.uid;
      print('✔ Authenticated as $_employeeEmail (UID: $employeeUid)');
      expect(cred.user!.emailVerified, isTrue);

      // 2. Run real invitation activation
      print('✔ Running acceptEmployeeInvitation...');
      await authRepo.acceptEmployeeInvitation(
        businessId: _businessId,
        invitationId: _invitationId,
        displayName: 'Rahul',
        phone: '9876543210',
      );
      print('✔ acceptEmployeeInvitation completed.');

      // 3. Verify Invitation Document
      final inviteDoc = await firestore
          .doc('businesses/$_businessId/invitations/$_invitationId')
          .get();
      expect(inviteDoc.exists, isTrue);
      final inviteData = inviteDoc.data()!;
      expect(inviteData['status'], 'accepted');
      expect(inviteData['acceptedBy'], employeeUid);
      expect(inviteData['role'], 'employee');
      print('✔ Invitation document verified as accepted by $employeeUid');

      // 4. Verify Member Document
      final memberDoc = await firestore
          .doc('businesses/$_businessId/members/$employeeUid')
          .get();
      expect(memberDoc.exists, isTrue);
      final memberData = memberDoc.data()!;
      expect(memberData['role'], 'employee');
      expect(memberData['status'], 'active');
      expect(memberData['businessId'], _businessId);
      expect(memberData['acceptedInviteId'], _invitationId);
      expect(memberData['email'], _employeeEmail);
      print('✔ Member document verified: role=employee, status=active');

      // 5. Verify User Profile Document
      final profileDoc = await firestore
          .doc('userProfiles/$employeeUid')
          .get();
      expect(profileDoc.exists, isTrue);
      final profileData = profileDoc.data()!;
      expect(profileData['role'], 'employee');
      expect(profileData['status'], 'active');
      expect(profileData['businessId'], _businessId);
      expect(profileData['acceptedInviteId'], _invitationId);
      print('✔ UserProfile verified: role=employee, businessId=$_businessId');

      // 6. Verify User Session navigates to Employee Access
      final appUser = await authRepo.watchCurrentUser().firstWhere(
        (u) => u != null && u.hasActiveAccess,
      );
      expect(appUser, isNotNull);
      expect(appUser!.role, UserRole.employee);
      expect(appUser.status, AccountStatus.active);
      expect(appUser.businessId, _businessId);
      print('✔ AppUser session resolved to active employee dashboard access.');

      // 7. Verify Regression: Re-activation now clearly throws 'already used'
      expect(
        () => authRepo.acceptEmployeeInvitation(
          businessId: _businessId,
          invitationId: _invitationId,
          displayName: 'Rahul',
          phone: '9876543210',
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            'This invitation has already been used.',
          ),
        ),
      );
      print('✔ Regression verified: re-activation produces clear "already used" error.');
    },
  );
}
