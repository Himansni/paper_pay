import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/reports/domain/report_models.dart';

abstract interface class ReportingRepository {
  Future<OperationalDashboard> fetchDashboard({
    required AppUser actor,
    required DateTime now,
  });

  Future<ReportPage> fetchReport({
    required AppUser actor,
    required ReportFilter filter,
    ReportCursor? cursor,
    int pageSize = 25,
  });

  Future<List<ReportRow>> fetchExportRows({
    required AppUser actor,
    required ReportFilter filter,
    int maximumRows = 5000,
  });
}
