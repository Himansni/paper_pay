import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:paper_route/features/delivery/data/firebase_delivery_repository.dart';
import 'package:paper_route/features/delivery/domain/delivery_models.dart';
import 'package:paper_route/features/delivery/domain/delivery_repository.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';
import 'package:paper_route/features/subscriptions/presentation/subscription_providers.dart';

final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) {
  try {
    return FirebaseDeliveryRepository.fromDefaultApp();
  } catch (_) {
    return InMemoryDeliveryRepository();
  }
});

class MorningRouteDateNotifier extends Notifier<LocalDate> {
  @override
  LocalDate build() => LocalDate.fromDateTime(DateTime.now());

  void setDate(LocalDate date) => state = date;
}

final morningRouteDateProvider =
    NotifierProvider<MorningRouteDateNotifier, LocalDate>(
  MorningRouteDateNotifier.new,
);

class SelectedRouteAreaNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setArea(String areaId) => state = areaId;
}

final selectedRouteAreaProvider =
    NotifierProvider<SelectedRouteAreaNotifier, String>(
  SelectedRouteAreaNotifier.new,
);

typedef RouteDropsKey = ({String businessId, String areaId, LocalDate date});

final routeDropsStreamProvider = StreamProvider.autoDispose
    .family<Map<String, DeliveryDropRecord>, RouteDropsKey>((ref, key) {
  if (key.areaId.isEmpty) {
    return Stream.value(const <String, DeliveryDropRecord>{});
  }
  return ref.watch(deliveryRepositoryProvider).watchRouteDrops(
        businessId: key.businessId,
        areaId: key.areaId,
        date: key.date,
      );
});

/// Tracks delivery stop statuses with optimistic local updates and Firestore persistence
class DeliveryStatusNotifier
    extends Notifier<Map<String, DeliveryStopStatus>> {
  @override
  Map<String, DeliveryStopStatus> build() =>
      const <String, DeliveryStopStatus>{};

  Future<void> markDelivered(
    String customerId, {
    String? businessId,
    String? areaId,
    LocalDate? date,
    String? actorUid,
  }) async {
    state = {...state, customerId: DeliveryStopStatus.delivered};
    if (businessId != null && areaId != null && date != null && actorUid != null) {
      await ref.read(deliveryRepositoryProvider).recordDropStatus(
            businessId: businessId,
            areaId: areaId,
            date: date,
            customerId: customerId,
            status: DeliveryStopStatus.delivered,
            actorUid: actorUid,
          );
    }
  }

  Future<void> markException(
    String customerId,
    String reason, {
    String? businessId,
    String? areaId,
    LocalDate? date,
    String? actorUid,
  }) async {
    state = {...state, customerId: DeliveryStopStatus.exception};
    if (businessId != null && areaId != null && date != null && actorUid != null) {
      await ref.read(deliveryRepositoryProvider).recordDropStatus(
            businessId: businessId,
            areaId: areaId,
            date: date,
            customerId: customerId,
            status: DeliveryStopStatus.exception,
            exceptionReason: reason,
            actorUid: actorUid,
          );
    }
  }

  Future<void> reset(
    String customerId, {
    String? businessId,
    String? areaId,
    LocalDate? date,
    String? actorUid,
  }) async {
    final next = Map<String, DeliveryStopStatus>.from(state);
    next.remove(customerId);
    state = next;
    if (businessId != null && areaId != null && date != null && actorUid != null) {
      await ref.read(deliveryRepositoryProvider).recordDropStatus(
            businessId: businessId,
            areaId: areaId,
            date: date,
            customerId: customerId,
            status: DeliveryStopStatus.pending,
            actorUid: actorUid,
          );
    }
  }
}

final deliveryStatusStateProvider =
    NotifierProvider<DeliveryStatusNotifier, Map<String, DeliveryStopStatus>>(
  DeliveryStatusNotifier.new,
);

final morningRouteStopsProvider =
    FutureProvider.family<List<DailyRouteStop>, AppUser>((ref, user) async {
  final businessId = user.businessId!;
  final selectedDate = ref.watch(morningRouteDateProvider);
  final selectedAreaId = ref.watch(selectedRouteAreaProvider);
  final markedStatuses = ref.watch(deliveryStatusStateProvider);

  // 1. Fetch areas
  final areasAsync = ref.watch(deliveryAreasProvider(businessId));
  final areas = (areasAsync.asData?.value ?? const <DeliveryArea>[])
      .where((a) => a.isActive)
      .toList();

  String activeAreaId = selectedAreaId;
  if (activeAreaId.isEmpty) {
    if (user.areaIds.isNotEmpty) {
      activeAreaId = user.areaIds.first;
    } else if (areas.isNotEmpty) {
      activeAreaId = areas.first.id;
    }
  }

  final areaName = areas
          .where((a) => a.id == activeAreaId)
          .map((a) => a.name)
          .firstOrNull ??
      'Route';

  // Watch persisted drops for this route
  final persistedDropsAsync = ref.watch(
    routeDropsStreamProvider((
      businessId: businessId,
      areaId: activeAreaId,
      date: selectedDate,
    ),),
  );
  final persistedDrops = persistedDropsAsync.asData?.value ??
      const <String, DeliveryDropRecord>{};

  // 2. Fetch active customers for this area
  final customerPage =
      await ref.read(customerRepositoryProvider).fetchCustomers(
            CustomerListRequest(
              businessId: businessId,
              requesterId: user.uid,
              isHead: user.isHead,
              status: CustomerStatus.active,
              areaId: activeAreaId,
              pageSize: 200,
            ),
          );

  List<Customer> customers = customerPage.customers;
  final routeOrder = await ref.read(deliveryRepositoryProvider).getRouteOrder(
        businessId: businessId,
        areaId: activeAreaId,
      );
  if (routeOrder != null && routeOrder.customerIds.isNotEmpty) {
    final Map<String, Customer> customerMap = {
      for (final c in customers) c.id: c,
    };
    final List<Customer> sorted = [];
    for (final id in routeOrder.customerIds) {
      final c = customerMap.remove(id);
      if (c != null) {
        sorted.add(c);
      }
    }
    sorted.addAll(customerMap.values);
    customers = sorted;
  }

  final List<DailyRouteStop> stops = [];

  for (var i = 0; i < customers.length; i++) {
    final customer = customers[i];
    final List<CustomerSubscription> subs = await ref
        .read(subscriptionRepositoryProvider)
        .watchCustomerSubscriptions(
          businessId: businessId,
          customerId: customer.id,
        )
        .first;

    final List<DailyPaperDrop> drops = [];
    for (final sub in subs) {
      if (sub.isEnded) continue;
      // Check delivery day
      if (!sub.deliveryWeekdays.contains(selectedDate.isoWeekday)) continue;
      if (selectedDate.isBefore(sub.startDate)) continue;
      if (sub.endDate != null && selectedDate.isAfter(sub.endDate!)) continue;

      // Check pause: status-level (open pause) AND dated pauses from subcollection
      bool isPaused = sub.isPaused;
      String? pauseReason;
      if (isPaused) {
        pauseReason = 'Paused';
      } else {
        // Check dated pauses covering selectedDate
        final pauses = await ref
            .read(subscriptionRepositoryProvider)
            .watchPauses(
              businessId: businessId,
              customerId: customer.id,
              subscriptionId: sub.id,
            )
            .first;
        final matchingPause = pauses
            .where((p) => p.contains(selectedDate))
            .firstOrNull;
        if (matchingPause != null) {
          isPaused = true;
          pauseReason = matchingPause.reason.isNotEmpty
              ? matchingPause.reason
              : 'Scheduled Pause';
        }
      }
      drops.add(
        DailyPaperDrop(
          newspaperId: sub.newspaperId,
          newspaperName: sub.newspaperName,
          quantity: sub.quantity,
          isPaused: isPaused,
          pauseReason: pauseReason,
        ),
      );
    }

    if (drops.isEmpty) continue; // No papers scheduled for this customer on this day

    final isAllPaused = drops.every((d) => d.isPaused);
    final persistedDrop = persistedDrops[customer.id];
    final localStatus = markedStatuses[customer.id];

    // Priority:
    // 1. If all papers are paused today -> always paused
    // 2. Local optimistic action if any
    // 3. Persisted drop from Firestore if present and not 'pending'
    // 4. Default: pending
    DeliveryStopStatus stopStatus = DeliveryStopStatus.pending;
    String? exceptionReason;
    DateTime? deliveredAt;

    if (isAllPaused) {
      stopStatus = DeliveryStopStatus.paused;
    } else if (localStatus != null) {
      stopStatus = localStatus;
      if (persistedDrop != null) {
        exceptionReason = persistedDrop.exceptionReason;
        deliveredAt = persistedDrop.updatedAt;
      }
    } else if (persistedDrop != null &&
        persistedDrop.status != DeliveryStopStatus.pending) {
      stopStatus = persistedDrop.status;
      exceptionReason = persistedDrop.exceptionReason;
      deliveredAt = persistedDrop.updatedAt;
    }

    stops.add(
      DailyRouteStop(
        customerId: customer.id,
        customerCode: customer.customerCode,
        customerName: customer.name,
        houseNumber: customer.houseNumber,
        buildingInfo: customer.buildingInfo,
        address: customer.address,
        landmark: customer.landmark,
        deliveryPlacement: customer.deliveryPlacement.label,
        routeSequence: i + 1,
        areaId: activeAreaId,
        areaName: areaName,
        drops: drops,
        status: stopStatus,
        exceptionReason: exceptionReason,
        deliveredAt: deliveredAt,
      ),
    );
  }

  return stops;
});
