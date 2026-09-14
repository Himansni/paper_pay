import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/reports/domain/report_csv.dart';
import 'package:paper_route/features/reports/domain/report_models.dart';

void main() {
  test('report math distinguishes payment state and outstanding age', () {
    expect(
      ReportMath.outstandingStatus(
        outstandingPaise: 10000,
        confirmedPaise: 0,
        reversedPaise: 0,
      ),
      OutstandingStatus.unpaid,
    );
    expect(
      ReportMath.outstandingStatus(
        outstandingPaise: 9000,
        confirmedPaise: 2000,
        reversedPaise: 1000,
      ),
      OutstandingStatus.partiallyPaid,
    );
    expect(
      ReportMath.outstandingStatus(
        outstandingPaise: 0,
        confirmedPaise: 10000,
        reversedPaise: 0,
      ),
      OutstandingStatus.fullyPaid,
    );
    expect(
      ReportMath.age(
        oldestOutstandingMonth: '2026-09',
        selectedMonth: '2026-09',
        outstandingPaise: 1,
      ),
      OutstandingAge.current,
    );
    expect(
      ReportMath.age(
        oldestOutstandingMonth: '2026-08',
        selectedMonth: '2026-09',
        outstandingPaise: 1,
      ),
      OutstandingAge.oneMonth,
    );
    expect(
      ReportMath.age(
        oldestOutstandingMonth: '2026-06',
        selectedMonth: '2026-09',
        outstandingPaise: 1,
      ),
      OutstandingAge.older,
    );
  });

  test('report period rejects inverted and unbounded queries', () {
    expect(
      () =>
          ReportingPeriod(
            start: DateTime.utc(2026, 9, 2),
            endExclusive: DateTime.utc(2026, 9, 1),
          ).validate(),
      throwsA(isA<AppException>()),
    );
    expect(
      () =>
          ReportingPeriod(
            start: DateTime.utc(2025),
            endExclusive: DateTime.utc(2027),
          ).validate(),
      throwsA(isA<AppException>()),
    );
  });

  test('day and month periods use local calendar boundaries', () {
    final day = ReportingPeriod.day(DateTime(2026, 9, 13, 18, 45));
    expect(day.start.toLocal(), DateTime(2026, 9, 13));
    expect(day.endExclusive.toLocal(), DateTime(2026, 9, 14));

    final month = ReportingPeriod.month(DateTime(2026, 9, 13, 18, 45));
    expect(month.start.toLocal(), DateTime(2026, 9));
    expect(month.endExclusive.toLocal(), DateTime(2026, 10));
  });

  test('report filters keep one indexed entity scope', () {
    final base = ReportFilter(
      kind: ReportKind.collections,
      period: ReportingPeriod.month(DateTime.utc(2026, 9)),
      billingMonth: '2026-09',
      employeeId: 'employee-a',
      areaId: 'east',
    );
    expect(base.canonicalized().employeeId, 'employee-a');
    expect(base.canonicalized().areaId, isEmpty);

    final customer = base.copyWith(customerId: ' C-001 ').canonicalized();
    expect(customer.customerId, 'C-001');
    expect(customer.employeeId, isEmpty);
    expect(customer.areaId, isEmpty);
  });

  test(
    'CSV export uses filtered rows and neutralizes spreadsheet formulas',
    () {
      final filter = ReportFilter(
        kind: ReportKind.collections,
        period: ReportingPeriod.month(DateTime.utc(2026, 9)),
        billingMonth: '2026-09',
        employeeId: 'employee-a',
      );
      final csv = ReportCsv.build(
        kind: ReportKind.collections,
        filter: filter,
        rows: const [
          ReportRow(
            id: 'payment-1',
            title: '=HYPERLINK("bad")',
            subtitle: 'Synthetic customer',
            status: 'confirmed',
            amountPaise: 1234,
            fields: {'Method': 'cash', 'Notes': '+formula'},
          ),
        ],
      );

      expect(csv, contains("'=HYPERLINK("));
      expect(csv, contains("'+formula"));
      expect(csv, contains('₹12.34'));
      expect(
        ReportCsv.safeFilename(filter, DateTime.utc(2026, 9, 13)),
        'paperroute-collections-2026-09.csv',
      );
    },
  );

  test('dashboard net collection subtracts immutable reversals', () {
    expect(_dashboard.netCollectionsPaise, 12500);
  });
}

const _dashboard = OperationalDashboard(
  monthKey: '2026-09',
  activeCustomers: 10,
  archivedCustomers: 2,
  activeEmployees: 3,
  activeAreas: 4,
  activeNewspapers: 5,
  currentMonthBilledPaise: 20000,
  currentMonthCollectionsPaise: 15000,
  currentOutstandingPaise: 5000,
  todayCollectionsPaise: 1000,
  currentMonthPayments: 4,
  currentMonthReversals: 1,
  currentMonthReversedPaise: 2500,
  unpaidCustomers: 2,
  partiallyPaidCustomers: 1,
  fullyPaidCustomers: 7,
  customersWithoutFinalizedBill: 2,
  recentPayments: [],
  recentBilling: [],
  recentCustomers: [],
  employeeCollections: [],
  areaOutstanding: [],
  routeSummaries: [],
);
