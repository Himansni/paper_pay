import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/delivery/domain/delivery_models.dart';
import 'package:paper_route/features/delivery/domain/today_operations_models.dart';

void main() {
  group('Head Today Operations Models & Math', () {
    test('PublicationCirculationTally calculates distribution net of pauses', () {
      const tally = PublicationCirculationTally(
        newspaperId: 'dainik-bhaskar',
        newspaperName: 'Dainik Bhaskar',
        orderedCopies: 150,
        pausedCopies: 12,
      );

      expect(tally.toDistributeCopies, equals(138));
    });

    test('AreaRouteProgress handles active, pending, ratio and completion flags', () {
      const routeInProgress = AreaRouteProgress(
        areaId: 'area-1',
        areaName: 'Sector 4',
        totalStops: 50,
        deliveredStops: 30,
        pausedStops: 10,
        exceptionStops: 2,
      );

      // Total 50, paused 10 => active 40
      expect(routeInProgress.activeStops, equals(40));
      // Delivered 30 + exception 2 = 32 handled. 40 - 32 = 8 pending
      expect(routeInProgress.pendingStops, equals(8));
      // 30 / 40 = 0.75
      expect(routeInProgress.progressRatio, equals(0.75));
      expect(routeInProgress.percentComplete, equals(75));
      expect(routeInProgress.isCompleted, isFalse);

      const routeDone = AreaRouteProgress(
        areaId: 'area-2',
        areaName: 'Sector 5',
        totalStops: 30,
        deliveredStops: 28,
        pausedStops: 0,
        exceptionStops: 2,
      );

      expect(routeDone.activeStops, equals(30));
      expect(routeDone.pendingStops, equals(0));
      expect(routeDone.isCompleted, isTrue);
    });

    test('HeadTodayOperationsSummary aggregates multi-line depot operations', () {
      final summary = HeadTodayOperationsSummary(
        date: const LocalDate(2026, 9, 23),
        circulationTallies: const [
          PublicationCirculationTally(
            newspaperId: 'np-1',
            newspaperName: 'Dainik Jagran',
            orderedCopies: 200,
            pausedCopies: 15,
          ),
          PublicationCirculationTally(
            newspaperId: 'np-2',
            newspaperName: 'The Times of India',
            orderedCopies: 100,
            pausedCopies: 5,
          ),
        ],
        routeProgresses: const [
          AreaRouteProgress(
            areaId: 'area-1',
            areaName: 'North Block',
            totalStops: 100,
            deliveredStops: 90,
            pausedStops: 10,
            exceptionStops: 0,
          ),
          AreaRouteProgress(
            areaId: 'area-2',
            areaName: 'South Block',
            totalStops: 50,
            deliveredStops: 20,
            pausedStops: 5,
            exceptionStops: 0,
          ),
        ],
        collections: const HeadTodayCollectionsTally(
          cashPaise: 450000,
          upiPaise: 150000,
          totalPaise: 600000,
          paymentCount: 12,
        ),
        currentOutstandingPaise: 1250000,
        todayExceptions: [
          DeliveryDropRecord(
            businessId: 'biz-1',
            routeId: '2026-09-23_area-2',
            date: '2026-09-23',
            areaId: 'area-2',
            customerId: 'cust-9',
            status: DeliveryStopStatus.exception,
            exceptionReason: 'Door locked / dog barking',
            actorUid: 'emp-1',
            updatedAt: DateTime.now(),
          ),
        ],
      );

      expect(summary.totalOrderedCopies, equals(300));
      expect(summary.totalPausedCopies, equals(20));
      expect(summary.totalToDistributeCopies, equals(280));
      expect(summary.totalRoutes, equals(2));
      // Route 1 active is 90, delivered 90 -> completed. Route 2 active 45, delivered 20 -> incomplete.
      expect(summary.completedRoutes, equals(1));
      expect(summary.collections.totalPaise, equals(600000));
      expect(summary.todayExceptions.length, equals(1));
    });
  });
}
