import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/reports/domain/report_models.dart';

/// Utility for generating RFC 4180-compliant CSV files from structured report rows.
///
/// Exports represent point-in-time read-only snapshots and never modify Firestore data.
abstract final class ReportCsv {
  /// Converts [rows] into comma-separated lines with safe escaping.
  static String build({
    required ReportKind kind,
    required ReportFilter filter,
    required List<ReportRow> rows,
  }) {
    final dynamicFields =
        <String>{for (final row in rows) ...row.fields.keys}.toList()..sort();
    final output = <List<String>>[
      [
        'Report',
        'ID',
        'Title',
        'Details',
        'Status',
        'Amount',
        'Date',
        ...dynamicFields,
      ],
      for (final row in rows)
        [
          kind.label,
          row.id,
          row.title,
          row.subtitle,
          row.status,
          row.amountPaise == null
              ? ''
              : BillingMoney.formatPaise(row.amountPaise!),
          row.occurredAt?.toUtc().toIso8601String() ?? '',
          for (final field in dynamicFields) row.fields[field] ?? '',
        ],
    ];
    return output.map((row) => row.map(_escape).join(',')).join('\r\n');
  }

  static String safeFilename(ReportFilter filter, DateTime generatedAt) {
    final date = generatedAt.toUtc().toIso8601String().substring(0, 10);
    final month = filter.billingMonth.replaceAll(RegExp(r'[^0-9-]'), '');
    return 'paperroute-${filter.kind.name}-${month.isEmpty ? date : month}.csv';
  }

  static String _escape(String value) {
    // Prefix formula-like values so spreadsheet programs cannot execute
    // untrusted customer text when the CSV is opened.
    final safe = RegExp(r'^[=+\-@]').hasMatch(value) ? "'$value" : value;
    return '"${safe.replaceAll('"', '""')}"';
  }
}
