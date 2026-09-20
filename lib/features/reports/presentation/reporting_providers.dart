import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/reports/data/firebase_reporting_repository.dart';
import 'package:paper_route/features/reports/domain/report_models.dart';
import 'package:paper_route/features/reports/domain/reporting_repository.dart';

final reportingRepositoryProvider = Provider<ReportingRepository>((ref) {
  return FirebaseReportingRepository.fromDefaultApp();
});

final operationalDashboardProvider = FutureProvider.autoDispose
    .family<OperationalDashboard, AppUser>((ref, user) {
      return ref
          .watch(reportingRepositoryProvider)
          .fetchDashboard(actor: user, now: DateTime.now());
    });
