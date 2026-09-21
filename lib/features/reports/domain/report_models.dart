import 'dart:math' as math;

import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';

/// The five primary operational report types available in PaperRoute.
enum ReportKind {
  collections('Collections'),
  billing('Billing'),
  outstanding('Outstanding'),
  customers('Customers'),
  subscriptions('Subscriptions');

  const ReportKind(this.label);

  final String label;
}

/// Derived collection payment state for a customer.
enum OutstandingStatus {
  unpaid('unpaid', 'Unpaid'),
  partiallyPaid('partiallyPaid', 'Partially paid'),
  fullyPaid('fullyPaid', 'Fully paid'),
  credit('credit', 'Credit');

  const OutstandingStatus(this.value, this.label);

  final String value;
  final String label;

  static OutstandingStatus fromValue(Object? value) => values.firstWhere(
    (status) => status.value == value,
    orElse: () => unpaid,
  );
}

/// Age classification for customer debt, measured against the oldest unpaid month.
enum OutstandingAge {
  current('current', 'Current month'),
  oneMonth('oneMonth', '1 month old'),
  older('older', '2+ months old'),
  settled('settled', 'No outstanding');

  const OutstandingAge(this.value, this.label);

  final String value;
  final String label;
}

/// Half-open date interval `[start, endExclusive)` in UTC for bounded queries.
class ReportingPeriod {
  const ReportingPeriod({required this.start, required this.endExclusive});

  factory ReportingPeriod.month(DateTime month) {
    final local = month.toLocal();
    final start = DateTime(local.year, local.month).toUtc();
    return ReportingPeriod(
      start: start,
      endExclusive: DateTime(local.year, local.month + 1).toUtc(),
    );
  }

  factory ReportingPeriod.day(DateTime date) {
    final local = date.toLocal();
    final start = DateTime(local.year, local.month, local.day).toUtc();
    return ReportingPeriod(
      start: start,
      endExclusive: DateTime(local.year, local.month, local.day + 1).toUtc(),
    );
  }

  final DateTime start;
  final DateTime endExclusive;

  void validate() {
    if (!endExclusive.isAfter(start)) {
      throw const AppException('The report end date must follow its start.');
    }
    if (endExclusive.difference(start).inDays > 366) {
      throw const AppException('Choose a report range of one year or less.');
    }
  }
}

/// Single labeled financial summary item with amount in integer paise and count.
class NamedMetric {
  const NamedMetric({
    required this.id,
    required this.label,
    required this.amountPaise,
    this.count = 0,
  });

  final String id;
  final String label;
  final int amountPaise;
  final int count;
}

/// Timeline activity item on the dashboard (e.g., recent payment or finalization).
class DashboardActivity {
  const DashboardActivity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.occurredAt,
    required this.route,
    this.amountPaise,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime? occurredAt;
  final String route;
  final int? amountPaise;
}

/// Real-time operational snapshot combining server-side aggregates and recent activity.
///
/// Amounts are stored in integer paise to avoid rounding discrepancies.
class OperationalDashboard {
  const OperationalDashboard({
    required this.monthKey,
    required this.activeCustomers,
    required this.archivedCustomers,
    required this.activeEmployees,
    required this.activeAreas,
    required this.activeNewspapers,
    required this.currentMonthBilledPaise,
    required this.currentMonthCollectionsPaise,
    required this.currentOutstandingPaise,
    required this.todayCollectionsPaise,
    required this.currentMonthPayments,
    required this.currentMonthReversals,
    required this.currentMonthReversedPaise,
    required this.unpaidCustomers,
    required this.partiallyPaidCustomers,
    required this.fullyPaidCustomers,
    required this.customersWithoutFinalizedBill,
    required this.recentPayments,
    required this.recentBilling,
    required this.recentCustomers,
    required this.employeeCollections,
    required this.areaOutstanding,
    required this.routeSummaries,
  });

  final String monthKey;
  final int activeCustomers;
  final int archivedCustomers;
  final int activeEmployees;
  final int activeAreas;
  final int activeNewspapers;
  final int currentMonthBilledPaise;
  final int currentMonthCollectionsPaise;
  final int currentOutstandingPaise;
  final int todayCollectionsPaise;
  final int currentMonthPayments;
  final int currentMonthReversals;
  final int currentMonthReversedPaise;
  final int unpaidCustomers;
  final int partiallyPaidCustomers;
  final int fullyPaidCustomers;
  final int customersWithoutFinalizedBill;
  final List<DashboardActivity> recentPayments;
  final List<DashboardActivity> recentBilling;
  final List<DashboardActivity> recentCustomers;
  final List<NamedMetric> employeeCollections;
  final List<NamedMetric> areaOutstanding;
  final List<NamedMetric> routeSummaries;

  int get netCollectionsPaise =>
      currentMonthCollectionsPaise - currentMonthReversedPaise;
}

/// Filter parameters selecting report category, date range, entity IDs, and statuses.
class ReportFilter {
  const ReportFilter({
    required this.kind,
    required this.period,
    required this.billingMonth,
    this.employeeId = '',
    this.areaId = '',
    this.customerId = '',
    this.newspaperId = '',
    this.paymentMethod,
    this.customerStatus = '',
    this.billStatus = '',
    this.subscriptionStatus = '',
    this.outstandingStatus,
  });

  final ReportKind kind;
  final ReportingPeriod period;
  final String billingMonth;
  final String employeeId;
  final String areaId;
  final String customerId;
  final String newspaperId;
  final PaymentMethod? paymentMethod;
  final String customerStatus;
  final String billStatus;
  final String subscriptionStatus;
  final OutstandingStatus? outstandingStatus;

  /// Keeps report queries on one tenant-scoped entity dimension. This avoids
  /// an exponential composite-index matrix while retaining every useful
  /// individual filter and deterministic customer lookup.
  ReportFilter canonicalized() {
    final normalizedCustomerStatus =
        (kind == ReportKind.customers || kind == ReportKind.outstanding) &&
                customerStatus.isEmpty
            ? 'active'
            : customerStatus;
    final normalizedBillStatus =
        kind == ReportKind.billing && billStatus.isEmpty
            ? 'finalized'
            : billStatus;
    if (customerId.trim().isNotEmpty) {
      return copyWith(
        customerId: customerId.trim(),
        employeeId: '',
        areaId: '',
        newspaperId: '',
        customerStatus: normalizedCustomerStatus,
        billStatus: normalizedBillStatus,
      );
    }
    if (kind == ReportKind.subscriptions) {
      return copyWith(
        employeeId: '',
        areaId: '',
        customerStatus: normalizedCustomerStatus,
        billStatus: normalizedBillStatus,
      );
    }
    if (employeeId.isNotEmpty) {
      return copyWith(
        areaId: '',
        newspaperId: '',
        customerStatus: normalizedCustomerStatus,
        billStatus: normalizedBillStatus,
      );
    }
    return copyWith(
      newspaperId: '',
      customerStatus: normalizedCustomerStatus,
      billStatus: normalizedBillStatus,
    );
  }

  ReportFilter copyWith({
    ReportKind? kind,
    ReportingPeriod? period,
    String? billingMonth,
    String? employeeId,
    String? areaId,
    String? customerId,
    String? newspaperId,
    PaymentMethod? paymentMethod,
    bool clearPaymentMethod = false,
    String? customerStatus,
    String? billStatus,
    String? subscriptionStatus,
    OutstandingStatus? outstandingStatus,
    bool clearOutstandingStatus = false,
  }) => ReportFilter(
    kind: kind ?? this.kind,
    period: period ?? this.period,
    billingMonth: billingMonth ?? this.billingMonth,
    employeeId: employeeId ?? this.employeeId,
    areaId: areaId ?? this.areaId,
    customerId: customerId ?? this.customerId,
    newspaperId: newspaperId ?? this.newspaperId,
    paymentMethod:
        clearPaymentMethod ? null : paymentMethod ?? this.paymentMethod,
    customerStatus: customerStatus ?? this.customerStatus,
    billStatus: billStatus ?? this.billStatus,
    subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
    outstandingStatus:
        clearOutstandingStatus
            ? null
            : outstandingStatus ?? this.outstandingStatus,
  );
}

/// Opaque pagination token holding the last-seen sort value and document key.
///
/// Firestore `startAfter` uses these fields to fetch the subsequent page without
/// relying on slow offset skips or race-condition-prone indices.
class ReportCursor {
  const ReportCursor({required this.sortValue, required this.documentPath});

  final Object sortValue;
  final String documentPath;
}

/// Generic presentation row displayed in report tables and exported to CSV.
class ReportRow {
  const ReportRow({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.fields,
    this.amountPaise,
    this.occurredAt,
    this.route = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final String status;
  final Map<String, String> fields;
  final int? amountPaise;
  final DateTime? occurredAt;
  final String route;
}

/// Aggregate totals across all matching records in the filtered dataset.
class ReportSummary {
  const ReportSummary({
    required this.totalCount,
    required this.totalPaise,
    required this.secondaryPaise,
    required this.secondaryCount,
    required this.breakdown,
  });

  final int totalCount;
  final int totalPaise;
  final int secondaryPaise;
  final int secondaryCount;
  final Map<String, int> breakdown;

  int get netPaise => totalPaise - secondaryPaise;
}

/// Result of a single paginated report query containing rows, totals, and the next cursor.
class ReportPage {
  const ReportPage({
    required this.rows,
    required this.summary,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<ReportRow> rows;
  final ReportSummary summary;
  final ReportCursor? nextCursor;
  final bool hasMore;
}

/// Pure helper functions for categorizing customer payment and aging status.
abstract final class ReportMath {
  static OutstandingStatus outstandingStatus({
    required int outstandingPaise,
    required int confirmedPaise,
    required int reversedPaise,
  }) {
    if (outstandingPaise < 0) return OutstandingStatus.credit;
    if (outstandingPaise == 0) return OutstandingStatus.fullyPaid;
    return confirmedPaise > reversedPaise
        ? OutstandingStatus.partiallyPaid
        : OutstandingStatus.unpaid;
  }

  static OutstandingAge age({
    required String oldestOutstandingMonth,
    required String selectedMonth,
    required int outstandingPaise,
  }) {
    if (outstandingPaise <= 0 || oldestOutstandingMonth.isEmpty) {
      return OutstandingAge.settled;
    }
    final oldest = _monthIndex(oldestOutstandingMonth);
    final selected = _monthIndex(selectedMonth);
    final difference = math.max(0, selected - oldest);
    if (difference == 0) return OutstandingAge.current;
    if (difference == 1) return OutstandingAge.oneMonth;
    return OutstandingAge.older;
  }

  static int _monthIndex(String month) {
    if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(month)) return 0;
    final parts = month.split('-');
    return int.parse(parts[0]) * 12 + int.parse(parts[1]);
  }
}
