import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/dashboard/presentation/dashboard_page.dart';
import 'package:paper_route/features/reports/domain/report_models.dart';
import 'package:paper_route/features/reports/domain/reporting_repository.dart';
import 'package:paper_route/features/reports/presentation/reporting_providers.dart';

void main() {
  testWidgets('Head dashboard renders operational metrics and daily actions', (
    tester,
  ) async {
    _largeView(tester);
    await tester.pumpWidget(_app(_ImmediateReports(_dashboard), _head));
    await tester.pumpAndSettle();

    expect(find.text('Current outstanding'), findsOneWidget);
    expect(find.text("Today's collection"), findsOneWidget);
    expect(find.text('Daily pricing'), findsOneWidget);
    expect(find.text('No finalized bill: 2'), findsOneWidget);
    expect(find.text('Employee collections'), findsOneWidget);
    expect(find.text('Area outstanding'), findsOneWidget);
    expect(find.text('Recent billing'), findsOneWidget);
  });

  testWidgets('Employee dashboard exposes only assigned operational actions', (
    tester,
  ) async {
    _largeView(tester);
    await tester.pumpWidget(_app(_ImmediateReports(_dashboard), _employee));
    await tester.pumpAndSettle();

    expect(find.text('Assigned outstanding'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dashboard-customer-search')),
      findsOneWidget,
    );
    expect(find.text('My route groups'), findsOneWidget);
    expect(find.text('View reports'), findsNothing);
    expect(find.text('Daily pricing'), findsNothing);
  });

  testWidgets('dashboard has explicit loading and error states', (
    tester,
  ) async {
    _largeView(tester);
    final pending = _PendingReports();
    await tester.pumpWidget(_app(pending, _head));
    await tester.pump();
    expect(find.text('Loading current operations…'), findsOneWidget);

    pending.completer.completeError(StateError('synthetic failure'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not load operational metrics'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });
}

Widget _app(ReportingRepository repository, AppUser user) => ProviderScope(
  overrides: [reportingRepositoryProvider.overrideWithValue(repository)],
  child: MaterialApp(home: DashboardPage(user: user)),
);

void _largeView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 2200);
  addTearDown(tester.view.reset);
}

const _head = AppUser(
  uid: 'head-a',
  email: 'head@example.test',
  displayName: 'Head User',
  isEmailVerified: true,
  businessId: 'business-a',
  role: UserRole.head,
  status: AccountStatus.active,
);

const _employee = AppUser(
  uid: 'employee-a',
  email: 'employee@example.test',
  displayName: 'Employee User',
  isEmailVerified: true,
  businessId: 'business-a',
  role: UserRole.employee,
  status: AccountStatus.active,
  areaIds: {'east'},
);

const _dashboard = OperationalDashboard(
  monthKey: '2026-09',
  activeCustomers: 10,
  archivedCustomers: 2,
  activeEmployees: 3,
  activeAreas: 4,
  activeNewspapers: 5,
  currentMonthBilledPaise: 200000,
  currentMonthCollectionsPaise: 100000,
  currentOutstandingPaise: 100000,
  todayCollectionsPaise: 25000,
  currentMonthPayments: 8,
  currentMonthReversals: 1,
  currentMonthReversedPaise: 5000,
  unpaidCustomers: 2,
  partiallyPaidCustomers: 1,
  fullyPaidCustomers: 7,
  customersWithoutFinalizedBill: 2,
  recentPayments: [],
  recentBilling: [],
  recentCustomers: [],
  employeeCollections: [
    NamedMetric(id: 'employee-a', label: 'Employee A', amountPaise: 100000),
  ],
  areaOutstanding: [
    NamedMetric(id: 'east', label: 'East', amountPaise: 100000),
  ],
  routeSummaries: [NamedMetric(id: 'east', label: 'East', amountPaise: 100000)],
);

class _ImmediateReports implements ReportingRepository {
  const _ImmediateReports(this.dashboard);

  final OperationalDashboard dashboard;

  @override
  Future<OperationalDashboard> fetchDashboard({
    required AppUser actor,
    required DateTime now,
  }) async => dashboard;

  @override
  Future<ReportPage> fetchReport({
    required AppUser actor,
    required ReportFilter filter,
    ReportCursor? cursor,
    int pageSize = 25,
  }) => throw UnimplementedError();

  @override
  Future<List<ReportRow>> fetchExportRows({
    required AppUser actor,
    required ReportFilter filter,
    int maximumRows = 5000,
  }) => throw UnimplementedError();
}

class _PendingReports extends _ImmediateReports {
  _PendingReports() : super(_dashboard);

  final completer = Completer<OperationalDashboard>();

  @override
  Future<OperationalDashboard> fetchDashboard({
    required AppUser actor,
    required DateTime now,
  }) => completer.future;
}
