import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/reports/data/firebase_reporting_repository.dart';
import 'package:paper_route/features/reports/domain/report_models.dart';
import 'package:paper_route/features/reports/domain/reporting_repository.dart';

/// Provides the concrete Firestore reporting repository instance.
final reportingRepositoryProvider = Provider<ReportingRepository>((ref) {
  return FirebaseReportingRepository.fromDefaultApp();
});

/// Fetches the operational dashboard snapshot for the authenticated [user].
///
/// Marked `autoDispose` so leaving the dashboard frees cached memory and returns
/// fresh live metrics upon re-entry.
final operationalDashboardProvider = FutureProvider.autoDispose
    .family<OperationalDashboard, AppUser>((ref, user) {
      return ref
          .watch(reportingRepositoryProvider)
          .fetchDashboard(actor: user, now: DateTime.now());
    });
