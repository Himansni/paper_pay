import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/dashboard/presentation/dashboard_page.dart';
import 'package:paper_route/features/delivery/domain/today_operations_models.dart';
import 'package:paper_route/features/delivery/presentation/today_operations_page.dart';
import 'package:paper_route/features/delivery/presentation/today_operations_providers.dart';
import 'package:paper_route/features/reports/domain/report_models.dart';
import 'package:paper_route/features/reports/presentation/reporting_providers.dart';

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

  const todaySummary = HeadTodayOperationsSummary(
    date: LocalDate(2026, 9, 30),
    circulationTallies: [
      PublicationCirculationTally(
        newspaperId: 'news-1',
        newspaperName:
            'Dainik Bhaskar - Extended Greater Indore Special District Morning Edition',
        orderedCopies: 120,
        pausedCopies: 15,
      ),
      PublicationCirculationTally(
        newspaperId: 'news-2',
        newspaperName:
            'The Times of India - National Edition With Financial Times Supplement',
        orderedCopies: 200,
        pausedCopies: 20,
      ),
    ],
    routeProgresses: [
      AreaRouteProgress(
        areaId: 'area-1',
        areaName: 'Sector 14 Extended Residential Complex Layout B',
        totalStops: 50,
        deliveredStops: 45,
        pausedStops: 0,
        exceptionStops: 0,
      ),
    ],
    collections: HeadTodayCollectionsTally(
      cashPaise: 20000,
      upiPaise: 15000,
      totalPaise: 35000,
      paymentCount: 15,
    ),
    currentOutstandingPaise: 450000,
    todayExceptions: [],
  );

  const dashboardMetrics = OperationalDashboard(
    monthKey: '2026-09',
    currentOutstandingPaise: 12500000,
    todayCollectionsPaise: 450000,
    currentMonthBilledPaise: 8900000,
    currentMonthCollectionsPaise: 7800000,
    currentMonthReversedPaise: 0,
    activeCustomers: 450,
    archivedCustomers: 20,
    activeEmployees: 12,
    activeAreas: 15,
    activeNewspapers: 65,
    currentMonthPayments: 420,
    currentMonthReversals: 2,
    customersWithoutFinalizedBill: 5,
    unpaidCustomers: 120,
    partiallyPaidCustomers: 45,
    fullyPaidCustomers: 280,
    employeeCollections: [
      NamedMetric(
        id: 'emp-1',
        label: 'Rameshwar Dayal Sharma (Hawker Route A)',
        amountPaise: 250000,
      ),
    ],
    areaOutstanding: [
      NamedMetric(
        id: 'area-1',
        label: 'Sector 14 Extended Residential Complex Layout B',
        amountPaise: 450000,
      ),
    ],
    recentPayments: [],
    recentBilling: [],
    recentCustomers: [],
    routeSummaries: [],
  );

  const testViewports = [
    Size(320, 640),
    Size(360, 740),
    Size(390, 844),
    Size(412, 915),
  ];

  group('V1 Responsive Layout & Text Overflow Audit', () {
    for (final viewport in testViewports) {
      testWidgets(
        'Today\'s Operations renders without RenderFlex overflow at ${viewport.width.toInt()}px width',
        (tester) async {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          FlutterError.onError = (details) {
            debugPrint('OVERFLOW DETAILS:\n${details.toString()}');
          };

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                headTodayOperationsProvider(headUser).overrideWith(
                  (ref) => Future.value(todaySummary),
                ),
              ],
              child: const MaterialApp(
                home: TodayOperationsPage(user: headUser),
              ),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          expect(find.byType(TodayOperationsPage), findsOneWidget);
          // Verify no Flutter error / RenderFlex overflow exception was recorded
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Dashboard renders without RenderFlex overflow at ${viewport.width.toInt()}px width',
        (tester) async {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                operationalDashboardProvider(headUser).overrideWith(
                  (ref) => Future.value(dashboardMetrics),
                ),
              ],
              child: const MaterialApp(
                home: DashboardPage(user: headUser),
              ),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          expect(find.byType(DashboardPage), findsOneWidget);
          // Verify no Flutter error / RenderFlex overflow exception was recorded
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
