import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/delivery/domain/delivery_models.dart';

class PublicationCirculationTally {
  const PublicationCirculationTally({
    required this.newspaperId,
    required this.newspaperName,
    required this.orderedCopies,
    required this.pausedCopies,
  });

  final String newspaperId;
  final String newspaperName;
  final int orderedCopies;
  final int pausedCopies;

  int get toDistributeCopies => orderedCopies - pausedCopies;
}

class AreaRouteProgress {
  const AreaRouteProgress({
    required this.areaId,
    required this.areaName,
    required this.totalStops,
    required this.deliveredStops,
    required this.pausedStops,
    required this.exceptionStops,
  });

  final String areaId;
  final String areaName;
  final int totalStops;
  final int deliveredStops;
  final int pausedStops;
  final int exceptionStops;

  int get activeStops => totalStops - pausedStops;
  int get pendingStops => (activeStops - deliveredStops - exceptionStops).clamp(0, activeStops);
  double get progressRatio => activeStops <= 0 ? 1.0 : (deliveredStops / activeStops).clamp(0.0, 1.0);
  int get percentComplete => (progressRatio * 100).round();
  bool get isCompleted => pendingStops <= 0 && activeStops > 0;
}

class HeadTodayCollectionsTally {
  const HeadTodayCollectionsTally({
    required this.cashPaise,
    required this.upiPaise,
    required this.totalPaise,
    required this.paymentCount,
  });

  final int cashPaise;
  final int upiPaise;
  final int totalPaise;
  final int paymentCount;
}

class HeadTodayOperationsSummary {
  const HeadTodayOperationsSummary({
    required this.date,
    required this.circulationTallies,
    required this.routeProgresses,
    required this.collections,
    required this.currentOutstandingPaise,
    required this.todayExceptions,
  });

  final LocalDate date;
  final List<PublicationCirculationTally> circulationTallies;
  final List<AreaRouteProgress> routeProgresses;
  final HeadTodayCollectionsTally collections;
  final int currentOutstandingPaise;
  final List<DeliveryDropRecord> todayExceptions;

  int get totalOrderedCopies => circulationTallies.fold(0, (sum, t) => sum + t.orderedCopies);
  int get totalPausedCopies => circulationTallies.fold(0, (sum, t) => sum + t.pausedCopies);
  int get totalToDistributeCopies => totalOrderedCopies - totalPausedCopies;
  int get totalRoutes => routeProgresses.length;
  int get completedRoutes => routeProgresses.where((r) => r.isCompleted).length;
}
