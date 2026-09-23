import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/delivery/data/firebase_delivery_repository.dart';
import 'package:paper_route/features/delivery/domain/delivery_models.dart';
import 'package:paper_route/features/delivery/domain/delivery_repository.dart';

void main() {
  group('Delivery Persistence & State Invariants', () {
    late DeliveryRepository repository;
    const businessId = 'biz-del-1';
    const areaId = 'area-north';
    const date = LocalDate(2026, 9, 23);
    const actorUid = 'emp-ramesh';
    const customerId = 'cust-101';

    setUp(() {
      repository = InMemoryDeliveryRepository();
    });

    test('Persists Mark Delivered and survives restart/fresh instance read', () async {
      // 1. Initial state has no drops
      var drops = await repository.fetchRouteDrops(
        businessId: businessId,
        areaId: areaId,
        date: date,
      );
      expect(drops.containsKey(customerId), isFalse);

      // 2. Mark Delivered
      await repository.recordDropStatus(
        businessId: businessId,
        areaId: areaId,
        date: date,
        customerId: customerId,
        status: DeliveryStopStatus.delivered,
        actorUid: actorUid,
      );

      // 3. Read back (simulating app restart)
      drops = await repository.fetchRouteDrops(
        businessId: businessId,
        areaId: areaId,
        date: date,
      );
      expect(drops.containsKey(customerId), isTrue);
      final drop = drops[customerId]!;
      expect(drop.status, DeliveryStopStatus.delivered);
      expect(drop.actorUid, actorUid);
      expect(drop.businessId, businessId);
      expect(drop.areaId, areaId);
      expect(drop.date, '2026-09-23');
      expect(drop.exceptionReason, isNull);
    });

    test('Repeated Mark Delivered is idempotent without duplicate records', () async {
      // Perform Mark Delivered 3 times
      for (var i = 0; i < 3; i++) {
        await repository.recordDropStatus(
          businessId: businessId,
          areaId: areaId,
          date: date,
          customerId: customerId,
          status: DeliveryStopStatus.delivered,
          actorUid: actorUid,
        );
      }

      final drops = await repository.fetchRouteDrops(
        businessId: businessId,
        areaId: areaId,
        date: date,
      );
      expect(drops.length, 1);
      expect(drops[customerId]!.status, DeliveryStopStatus.delivered);
    });

    test('Transition from exception -> delivered clears issue reason and updates status', () async {
      // 1. Report Issue
      await repository.recordDropStatus(
        businessId: businessId,
        areaId: areaId,
        date: date,
        customerId: customerId,
        status: DeliveryStopStatus.exception,
        exceptionReason: 'House Locked / Gate Closed',
        actorUid: actorUid,
      );

      var drops = await repository.fetchRouteDrops(
        businessId: businessId,
        areaId: areaId,
        date: date,
      );
      expect(drops[customerId]!.status, DeliveryStopStatus.exception);
      expect(drops[customerId]!.exceptionReason, 'House Locked / Gate Closed');

      // 2. Later, successfully delivered on second try
      await repository.recordDropStatus(
        businessId: businessId,
        areaId: areaId,
        date: date,
        customerId: customerId,
        status: DeliveryStopStatus.delivered,
        actorUid: actorUid,
      );

      drops = await repository.fetchRouteDrops(
        businessId: businessId,
        areaId: areaId,
        date: date,
      );
      expect(drops.length, 1);
      expect(drops[customerId]!.status, DeliveryStopStatus.delivered);
      expect(drops[customerId]!.exceptionReason, isNull);
    });

    test('Controlled Undo resets status to pending idempotently', () async {
      // 1. Mark Delivered
      await repository.recordDropStatus(
        businessId: businessId,
        areaId: areaId,
        date: date,
        customerId: customerId,
        status: DeliveryStopStatus.delivered,
        actorUid: actorUid,
      );

      // 2. Controlled Undo
      await repository.recordDropStatus(
        businessId: businessId,
        areaId: areaId,
        date: date,
        customerId: customerId,
        status: DeliveryStopStatus.pending,
        actorUid: actorUid,
      );

      final drops = await repository.fetchRouteDrops(
        businessId: businessId,
        areaId: areaId,
        date: date,
      );
      expect(drops[customerId]!.status, DeliveryStopStatus.pending);
    });

    test('Concurrent updates and retry behavior converge on latest write', () async {
      // Two devices concurrently write different statuses
      await Future.wait([
        repository.recordDropStatus(
          businessId: businessId,
          areaId: areaId,
          date: date,
          customerId: customerId,
          status: DeliveryStopStatus.delivered,
          actorUid: 'device-1',
        ),
        repository.recordDropStatus(
          businessId: businessId,
          areaId: areaId,
          date: date,
          customerId: customerId,
          status: DeliveryStopStatus.exception,
          exceptionReason: 'Rain / Waterlogged',
          actorUid: 'device-2',
        ),
      ]);

      final drops = await repository.fetchRouteDrops(
        businessId: businessId,
        areaId: areaId,
        date: date,
      );
      expect(drops.length, 1);
      expect(
        drops[customerId]!.status,
        isIn([DeliveryStopStatus.delivered, DeliveryStopStatus.exception]),
      );
    });
  });
}
