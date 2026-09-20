import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/app/paper_route_app.dart';
import 'package:paper_route/core/config/firebase_bootstrap.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/auth/domain/auth_repository.dart';
import 'package:paper_route/features/auth/presentation/auth_providers.dart';
import 'package:paper_route/features/reports/domain/report_models.dart';
import 'package:paper_route/features/reports/domain/reporting_repository.dart';
import 'package:paper_route/features/reports/presentation/reporting_providers.dart';

void main() {
  testWidgets('shows actionable Firebase setup state', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PaperRouteApp(
          startup: FirebaseStartup.configurationRequired('Not configured'),
        ),
      ),
    );

    expect(find.text('Firebase setup required'), findsOneWidget);
    expect(find.textContaining('docs/FIREBASE_SETUP.md'), findsOneWidget);
  });

  testWidgets('signed-out session shows login and invite entry points', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const PaperRouteApp(startup: FirebaseStartup.ready()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('I have an employee invitation'), findsOneWidget);
  });

  testWidgets('verified Head sees connected role-gated dashboard actions', (
    tester,
  ) async {
    const head = AppUser(
      uid: 'head-1',
      email: 'head@example.com',
      displayName: 'Head User',
      isEmailVerified: true,
      businessId: 'business-a',
      role: UserRole.head,
      status: AccountStatus.active,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(currentUser: head),
          ),
          reportingRepositoryProvider.overrideWithValue(
            _FakeReportingRepository(),
          ),
        ],
        child: const PaperRouteApp(startup: FirebaseStartup.ready()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Head Distributor workspace'), findsOneWidget);
    expect(find.text('Business settings'), findsOneWidget);
    expect(find.text('Add employee'), findsOneWidget);
    expect(find.text('Add area'), findsOneWidget);
    expect(find.text('Add customer'), findsOneWidget);
    expect(find.text('Daily pricing'), findsOneWidget);
    expect(find.text('View reports'), findsOneWidget);
  });

  testWidgets('employee cannot open a Head management route', (tester) async {
    const employee = AppUser(
      uid: 'employee-1',
      email: 'employee@example.com',
      displayName: 'Employee User',
      isEmailVerified: true,
      businessId: 'business-a',
      role: UserRole.employee,
      status: AccountStatus.active,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(currentUser: employee),
          ),
          reportingRepositoryProvider.overrideWithValue(
            _FakeReportingRepository(),
          ),
        ],
        child: const PaperRouteApp(startup: FirebaseStartup.ready()),
      ),
    );
    await tester.pumpAndSettle();

    GoRouter.of(
      tester.element(find.text('Employee distribution workspace')),
    ).go('/employees');
    await tester.pumpAndSettle();

    expect(find.text('Employee distribution workspace'), findsOneWidget);
    expect(find.text('Team access'), findsNothing);
  });
}

class _FakeReportingRepository implements ReportingRepository {
  @override
  Future<OperationalDashboard> fetchDashboard({
    required AppUser actor,
    required DateTime now,
  }) async => const OperationalDashboard(
    monthKey: '2026-09',
    activeCustomers: 0,
    archivedCustomers: 0,
    activeEmployees: 0,
    activeAreas: 0,
    activeNewspapers: 0,
    currentMonthBilledPaise: 0,
    currentMonthCollectionsPaise: 0,
    currentOutstandingPaise: 0,
    todayCollectionsPaise: 0,
    currentMonthPayments: 0,
    currentMonthReversals: 0,
    currentMonthReversedPaise: 0,
    unpaidCustomers: 0,
    partiallyPaidCustomers: 0,
    fullyPaidCustomers: 0,
    customersWithoutFinalizedBill: 0,
    recentPayments: [],
    recentBilling: [],
    recentCustomers: [],
    employeeCollections: [],
    areaOutstanding: [],
    routeSummaries: [],
  );

  @override
  Future<ReportPage> fetchReport({
    required AppUser actor,
    required ReportFilter filter,
    ReportCursor? cursor,
    int pageSize = 25,
  }) async => const ReportPage(
    rows: [],
    summary: ReportSummary(
      totalCount: 0,
      totalPaise: 0,
      secondaryPaise: 0,
      secondaryCount: 0,
      breakdown: {},
    ),
    nextCursor: null,
    hasMore: false,
  );

  @override
  Future<List<ReportRow>> fetchExportRows({
    required AppUser actor,
    required ReportFilter filter,
    int maximumRows = 5000,
  }) async => const [];
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.currentUser});

  final AppUser? currentUser;

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
  Stream<AppUser?> watchCurrentUser() => Stream.value(currentUser);
}
