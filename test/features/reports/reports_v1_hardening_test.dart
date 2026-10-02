import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';
import 'package:paper_route/features/employees/presentation/employee_providers.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';
import 'package:paper_route/features/reports/data/firebase_reporting_repository.dart';
import 'package:paper_route/features/reports/domain/report_models.dart';
import 'package:paper_route/features/reports/domain/reporting_repository.dart';
import 'package:paper_route/features/reports/presentation/reporting_providers.dart';
import 'package:paper_route/features/reports/presentation/reports_page.dart';

class _FakeFirestore extends Fake implements FirebaseFirestore {}

class _FakeReportingRepository implements ReportingRepository {
  _FakeReportingRepository({
    this.reportError,
  });

  Object? reportError;
  ReportPage? reportPage;

  @override
  Future<OperationalDashboard> fetchDashboard({
    required AppUser actor,
    required DateTime now,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ReportPage> fetchReport({
    required AppUser actor,
    required ReportFilter filter,
    ReportCursor? cursor,
    int pageSize = 25,
  }) async {
    await Future<void>.delayed(Duration.zero);
    if (reportError != null) {
      throw reportError!;
    }
    return reportPage ??
        const ReportPage(
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
  }

  @override
  Future<List<ReportRow>> fetchExportRows({
    required AppUser actor,
    required ReportFilter filter,
    int maximumRows = 5000,
  }) async {
    return const [];
  }
}

void main() {
  const headUser = AppUser(
    uid: 'head-001',
    email: 'head@test.local',
    displayName: 'Head Operator',
    isEmailVerified: true,
    businessId: 'biz-test',
    role: UserRole.head,
    status: AccountStatus.active,
    permissions: {
      PermissionKey.recordPayments,
    },
  );

  group('Reports V1 Hardening & Firestore Index Recovery', () {
    test('FirebaseReportingRepository maps index error to friendly message', () {
      final repo = FirebaseReportingRepository(_FakeFirestore());

      final indexPlatformException = PlatformException(
        code: 'failed-precondition',
        message:
            'The query requires an index. You can create it here: https://console.firebase.google.com/v1/r/project/paperroutedev/firestore/indexes?create_composite=...',
        details: {
          'error': 'FAILED_PRECONDITION',
        },
      );

      final translated = repo.translateError(indexPlatformException);
      expect(translated, isA<AppException>());
      expect(
        translated.message,
        equals('Reports are temporarily unavailable. Please try again.'),
      );
      // Raw Firebase console URL must never be included in the user-facing message
      expect(translated.message.contains('console.firebase.google.com'), isFalse);
      expect(translated.message.contains('FAILED_PRECONDITION'), isFalse);
    });

    testWidgets(
      'Reports screen shows friendly error message and Retry button when index exception occurs',
      (tester) async {
        final fakeRepo = _FakeReportingRepository(
          reportError: PlatformException(
            code: 'failed-precondition',
            message:
                'The query requires an index. You can create it here: https://console.firebase.google.com/...',
          ),
        );

        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              reportingRepositoryProvider.overrideWithValue(fakeRepo),
              deliveryAreasProvider('biz-test').overrideWith(
                (ref) => Stream.value(<DeliveryArea>[]),
              ),
              employeeMembersProvider('biz-test').overrideWith(
                (ref) => Stream.value(<EmployeeMember>[]),
              ),
              activeNewspapersListProvider(
                (businessId: 'biz-test', requesterId: 'head-001'),
              ).overrideWith(
                (ref) async => <Newspaper>[],
              ),
            ],
            child: const MaterialApp(
              home: ReportsPage(user: headUser),
            ),
          ),
        );

        // Post-frame callback fires _load, then microtask/future completes and schedules setState
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();

        expect(
          find.text('Reports are temporarily unavailable. Please try again.'),
          findsOneWidget,
        );
        // Raw platform exception / URL is absent
        expect(find.textContaining('FAILED_PRECONDITION'), findsNothing);
        expect(find.textContaining('console.firebase.google.com'), findsNothing);

        // Retry button exists and is functional
        final retryFinder = find.text('Try again');
        expect(retryFinder, findsOneWidget);

        // Clear error and retry
        fakeRepo.reportError = null;
        await tester.tap(retryFinder);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Reports are temporarily unavailable. Please try again.'), findsNothing);
      },
    );

    testWidgets(
      'Reports tabs render scrollably without overflow at 320px width',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final fakeRepo = _FakeReportingRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              reportingRepositoryProvider.overrideWithValue(fakeRepo),
              deliveryAreasProvider('biz-test').overrideWith(
                (ref) => Stream.value(<DeliveryArea>[]),
              ),
              employeeMembersProvider('biz-test').overrideWith(
                (ref) => Stream.value(<EmployeeMember>[]),
              ),
              activeNewspapersListProvider(
                (businessId: 'biz-test', requesterId: 'head-001'),
              ).overrideWith(
                (ref) async => <Newspaper>[],
              ),
            ],
            child: const MaterialApp(
              home: ReportsPage(user: headUser),
            ),
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(ReportsPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
