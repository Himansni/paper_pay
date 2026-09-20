import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/features/areas/domain/area_repository.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/employees/domain/employee_invitation.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';
import 'package:paper_route/features/employees/domain/employee_repository.dart';
import 'package:paper_route/features/employees/presentation/employee_providers.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/domain/newspaper_repository.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';
import 'package:paper_route/features/reports/domain/report_models.dart';
import 'package:paper_route/features/reports/domain/reporting_repository.dart';
import 'package:paper_route/features/reports/presentation/reporting_providers.dart';
import 'package:paper_route/features/reports/presentation/reports_page.dart';

void main() {
  testWidgets('reports apply filters and use a fresh cursor for each query', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.reset);
    final reports = _FakeReports();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reportingRepositoryProvider.overrideWithValue(reports),
          areaRepositoryProvider.overrideWithValue(_FakeAreas()),
          employeeRepositoryProvider.overrideWithValue(_FakeEmployees()),
          newspaperRepositoryProvider.overrideWithValue(_FakeNewspapers()),
        ],
        child: const MaterialApp(home: ReportsPage(user: _head)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First payment'), findsOneWidget);
    await tester.tap(find.text('Load more results'));
    await tester.pumpAndSettle();
    expect(find.text('Second payment'), findsOneWidget);
    expect(reports.cursors[0], isNull);
    expect(reports.cursors[1]?.documentPath, 'payments/payment-1');

    await tester.enterText(
      find.widgetWithText(TextField, 'Customer ID (optional)'),
      ' C-002 ',
    );
    await tester.tap(find.byKey(const ValueKey('apply-report-filters')));
    await tester.pumpAndSettle();

    expect(find.text('Filtered payment'), findsOneWidget);
    expect(find.text('First payment'), findsNothing);
    expect(reports.cursors.last, isNull);
    expect(reports.filters.last.customerId, 'C-002');
  });

  testWidgets('reports render empty and repository error states', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 2000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reportingRepositoryProvider.overrideWithValue(
            _FakeReports(mode: _ReportMode.empty),
          ),
          areaRepositoryProvider.overrideWithValue(_FakeAreas()),
          employeeRepositoryProvider.overrideWithValue(_FakeEmployees()),
          newspaperRepositoryProvider.overrideWithValue(_FakeNewspapers()),
        ],
        child: const MaterialApp(
          home: ReportsPage(key: ValueKey('empty-report'), user: _head),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No matching report rows'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reportingRepositoryProvider.overrideWithValue(
            _FakeReports(mode: _ReportMode.error),
          ),
          areaRepositoryProvider.overrideWithValue(_FakeAreas()),
          employeeRepositoryProvider.overrideWithValue(_FakeEmployees()),
          newspaperRepositoryProvider.overrideWithValue(_FakeNewspapers()),
        ],
        child: const MaterialApp(home: ReportsPage(user: _head)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('synthetic report error'), findsOneWidget);
  });
}

const _head = AppUser(
  uid: 'head-a',
  email: 'head@example.test',
  displayName: 'Head',
  isEmailVerified: true,
  businessId: 'business-a',
  role: UserRole.head,
  status: AccountStatus.active,
);

enum _ReportMode { pages, empty, error }

class _FakeReports implements ReportingRepository {
  _FakeReports({this.mode = _ReportMode.pages});

  final _ReportMode mode;
  final cursors = <ReportCursor?>[];
  final filters = <ReportFilter>[];

  @override
  Future<ReportPage> fetchReport({
    required AppUser actor,
    required ReportFilter filter,
    ReportCursor? cursor,
    int pageSize = 25,
  }) async {
    cursors.add(cursor);
    filters.add(filter);
    if (mode == _ReportMode.error) throw StateError('synthetic report error');
    if (mode == _ReportMode.empty) return _page(const [], false);
    if (filter.customerId == 'C-002') {
      return _page(const [_filteredRow], false);
    }
    return cursor == null
        ? _page(
          const [_firstRow],
          true,
          const ReportCursor(
            sortValue: '2026-09-13',
            documentPath: 'payments/payment-1',
          ),
        )
        : _page(const [_secondRow], false);
  }

  ReportPage _page(
    List<ReportRow> rows,
    bool hasMore, [
    ReportCursor? cursor,
  ]) => ReportPage(
    rows: rows,
    summary: const ReportSummary(
      totalCount: 2,
      totalPaise: 1500,
      secondaryPaise: 0,
      secondaryCount: 0,
      breakdown: {},
    ),
    nextCursor: cursor,
    hasMore: hasMore,
  );

  @override
  Future<List<ReportRow>> fetchExportRows({
    required AppUser actor,
    required ReportFilter filter,
    int maximumRows = 5000,
  }) async =>
      filter.customerId == 'C-002'
          ? const [_filteredRow]
          : const [_firstRow, _secondRow];

  @override
  Future<OperationalDashboard> fetchDashboard({
    required AppUser actor,
    required DateTime now,
  }) => throw UnimplementedError();
}

const _firstRow = ReportRow(
  id: 'payment-1',
  title: 'First payment',
  subtitle: 'C-001',
  status: 'confirmed',
  fields: {'Method': 'cash'},
  amountPaise: 1000,
);
const _secondRow = ReportRow(
  id: 'payment-2',
  title: 'Second payment',
  subtitle: 'C-002',
  status: 'confirmed',
  fields: {'Method': 'upi'},
  amountPaise: 500,
);
const _filteredRow = ReportRow(
  id: 'payment-2',
  title: 'Filtered payment',
  subtitle: 'C-002',
  status: 'confirmed',
  fields: {'Method': 'upi'},
  amountPaise: 500,
);

class _FakeAreas implements AreaRepository {
  @override
  Stream<List<DeliveryArea>> watchAreas(String businessId) =>
      Stream.value(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEmployees implements EmployeeRepository {
  @override
  Stream<List<EmployeeMember>> watchMembers(String businessId) =>
      Stream.value(const []);

  @override
  Stream<List<EmployeeInvitation>> watchInvitations(String businessId) =>
      Stream.value(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNewspapers implements NewspaperRepository {
  @override
  Future<NewspaperPage> fetchNewspapers(NewspaperListRequest request) async =>
      const NewspaperPage(newspapers: [], nextCursor: null, hasMore: false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
