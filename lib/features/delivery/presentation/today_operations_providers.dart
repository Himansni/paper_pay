import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/delivery/domain/delivery_models.dart';
import 'package:paper_route/features/delivery/domain/today_operations_models.dart';
import 'package:paper_route/features/delivery/presentation/delivery_providers.dart';
import 'package:paper_route/features/reports/presentation/reporting_providers.dart';

class HeadTodayOperationsDateNotifier extends Notifier<LocalDate> {
  @override
  LocalDate build() => LocalDate.fromDateTime(DateTime.now());

  void setDate(LocalDate date) => state = date;
}

final headTodayOperationsDateProvider =
    NotifierProvider<HeadTodayOperationsDateNotifier, LocalDate>(
  HeadTodayOperationsDateNotifier.new,
);

final headTodayOperationsProvider = FutureProvider.autoDispose
    .family<HeadTodayOperationsSummary, AppUser>((ref, user) async {
  final businessId = user.businessId!;
  final date = ref.watch(headTodayOperationsDateProvider);
  final deliveryRepo = ref.watch(deliveryRepositoryProvider);

  // 1. Fetch active areas
  final areas = await ref.watch(deliveryAreasProvider(businessId).future);
  final activeAreas = areas.where((a) => a.isActive).toList();

  // 2. Compute route progress per area using persisted drop records
  final List<AreaRouteProgress> routeProgresses = [];
  final List<DeliveryDropRecord> allExceptions = [];

  for (final area in activeAreas) {
    final dropsMap = await deliveryRepo.fetchRouteDrops(
      businessId: businessId,
      areaId: area.id,
      date: date,
    );

    int delivered = 0;
    int exceptions = 0;
    int paused = 0;

    for (final drop in dropsMap.values) {
      if (drop.status == DeliveryStopStatus.delivered) {
        delivered++;
      } else if (drop.status == DeliveryStopStatus.exception) {
        exceptions++;
        allExceptions.add(drop);
      } else if (drop.status == DeliveryStopStatus.paused) {
        paused++;
      }
    }

    final totalStops = dropsMap.isNotEmpty
        ? dropsMap.length
        : (delivered + exceptions + paused);

    routeProgresses.add(
      AreaRouteProgress(
        areaId: area.id,
        areaName: area.name,
        totalStops: totalStops > 0 ? totalStops : 1,
        deliveredStops: delivered,
        pausedStops: paused,
        exceptionStops: exceptions,
      ),
    );
  }

  // 3. Fetch publications circulation tally
  // Query active/paused subscriptions via collectionGroup in single indexed query
  final List<PublicationCirculationTally> circulationTallies = [];
  try {
    final firestore = FirebaseFirestore.instance;
    final subsSnap = await firestore
        .collectionGroup('subscriptions')
        .where('businessId', isEqualTo: businessId)
        .where('status', whereIn: ['active', 'paused'])
        .get();

    final Map<String, ({String name, int ordered, int paused})> pubMap = {};

    for (final doc in subsSnap.docs) {
      final data = doc.data();
      final startDateStr = data['startDate'] as String?;
      final endDateStr = data['endDate'] as String?;
      final weekdays =
          (data['deliveryWeekdays'] as List<dynamic>?)?.cast<int>() ?? [];
      final quantity = (data['quantity'] as num?)?.toInt() ?? 1;
      final pubId = data['newspaperId'] as String? ?? '';
      final pubName = data['newspaperName'] as String? ?? 'Newspaper';
      final status = data['status'] as String? ?? 'active';

      if (pubId.isEmpty) continue;
      if (!weekdays.contains(date.isoWeekday)) continue;
      if (startDateStr != null &&
          date.isBefore(LocalDate.parse(startDateStr))) {
        continue;
      }
      if (endDateStr != null && date.isAfter(LocalDate.parse(endDateStr))) {
        continue;
      }

      final existing = pubMap[pubId] ?? (name: pubName, ordered: 0, paused: 0);
      final isPaused = status == 'paused';

      pubMap[pubId] = (
        name: pubName,
        ordered: existing.ordered + quantity,
        paused: existing.paused + (isPaused ? quantity : 0),
      );
    }

    for (final entry in pubMap.entries) {
      circulationTallies.add(
        PublicationCirculationTally(
          newspaperId: entry.key,
          newspaperName: entry.value.name,
          orderedCopies: entry.value.ordered,
          pausedCopies: entry.value.paused,
        ),
      );
    }
  } catch (_) {
    // Tests or offline fallback
  }

  // 4. Financial totals & collections
  int todayCash = 0;
  int todayUpi = 0;
  int paymentCount = 0;
  int currentOutstanding = 0;

  try {
    final dashboard =
        await ref.watch(operationalDashboardProvider(user).future);
    currentOutstanding = dashboard.currentOutstandingPaise;
    todayCash = dashboard.todayCollectionsPaise;
  } catch (_) {}

  return HeadTodayOperationsSummary(
    date: date,
    circulationTallies: circulationTallies,
    routeProgresses: routeProgresses,
    collections: HeadTodayCollectionsTally(
      cashPaise: todayCash,
      upiPaise: todayUpi,
      totalPaise: todayCash + todayUpi,
      paymentCount: paymentCount,
    ),
    currentOutstandingPaise: currentOutstanding,
    todayExceptions: allExceptions,
  );
});
