import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/reports/domain/report_models.dart';

/// Contract for operational metrics, tabular reports, and CSV export streams.
///
/// Implementations must respect tenant isolation (`businessId`) and caller
/// authorization (Head vs assigned Employee). Reporting reads are read-only and
/// never mutate ledger, subscription, or billing records.
abstract interface class ReportingRepository {
  /// Fetches real-time summary cards and activity feeds. Heads receive
  /// business-wide metrics, while employees receive only their assigned scope.
  Future<OperationalDashboard> fetchDashboard({
    required AppUser actor,
    required DateTime now,
  });

  /// Fetches one cursor-paginated page of report rows and aggregate totals
  /// matching the specified [filter].
  Future<ReportPage> fetchReport({
    required AppUser actor,
    required ReportFilter filter,
    ReportCursor? cursor,
    int pageSize = 25,
  });

  /// Fetches complete unpaginated rows (up to [maximumRows]) for CSV export.
  Future<List<ReportRow>> fetchExportRows({
    required AppUser actor,
    required ReportFilter filter,
    int maximumRows = 5000,
  });
}
