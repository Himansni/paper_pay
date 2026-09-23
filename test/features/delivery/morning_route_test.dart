import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/delivery/domain/delivery_models.dart';
import 'package:paper_route/features/delivery/presentation/delivery_providers.dart';
import 'package:paper_route/features/delivery/presentation/morning_route_page.dart';

void main() {
  group('Morning Route Domain Models & Calculation', () {
    test('DailyPaperDrop correctly tracks quantity and paused status', () {
      const activeDrop = DailyPaperDrop(
        newspaperId: 'toi',
        newspaperName: 'Times of India',
        quantity: 2,
        isPaused: false,
      );
      expect(activeDrop.quantity, 2);
      expect(activeDrop.isPaused, isFalse);
      expect(activeDrop.pauseReason, isNull);

      const pausedDrop = DailyPaperDrop(
        newspaperId: 'et',
        newspaperName: 'Economic Times',
        quantity: 1,
        isPaused: true,
        pauseReason: 'Vacation',
      );
      expect(pausedDrop.quantity, 1);
      expect(pausedDrop.isPaused, isTrue);
      expect(pausedDrop.pauseReason, 'Vacation');
    });

    test('DailyRouteStop accurately derives paused and active status', () {
      const activeStop = DailyRouteStop(
        customerId: 'c-1',
        customerCode: 'C001',
        customerName: 'Aarav Sharma',
        houseNumber: '101',
        buildingInfo: 'Tower A',
        address: 'MG Road',
        landmark: 'Near Temple',
        deliveryPlacement: 'Front porch',
        routeSequence: 1,
        areaId: 'area-1',
        areaName: 'Sector 4',
        drops: [
          DailyPaperDrop(
            newspaperId: 'toi',
            newspaperName: 'Times of India',
            quantity: 1,
            isPaused: false,
          ),
        ],
      );

      expect(activeStop.hasActiveDrops, isTrue);
      expect(activeStop.isPausedToday, isFalse);
      expect(activeStop.isDelivered, isFalse);
      expect(activeStop.activeDrops.length, 1);

      const pausedStop = DailyRouteStop(
        customerId: 'c-2',
        customerCode: 'C002',
        customerName: 'Priya Verma',
        houseNumber: '102',
        buildingInfo: 'Tower B',
        address: 'Ring Road',
        landmark: 'Opp Bank',
        deliveryPlacement: 'Door handle',
        routeSequence: 2,
        areaId: 'area-1',
        areaName: 'Sector 4',
        status: DeliveryStopStatus.paused,
        drops: [
          DailyPaperDrop(
            newspaperId: 'ht',
            newspaperName: 'Hindustan Times',
            quantity: 1,
            isPaused: true,
            pauseReason: 'Holiday',
          ),
        ],
      );

      expect(pausedStop.hasActiveDrops, isFalse);
      expect(pausedStop.isPausedToday, isTrue);
      expect(pausedStop.activeDrops.isEmpty, isTrue);
    });

    test('RouteProgressSummary calculates completion accurately', () {
      const summary = RouteProgressSummary(
        totalStops: 10,
        deliveredStops: 7,
        pausedStops: 1,
        exceptionStops: 0,
      );

      expect(summary.totalStops, 10);
      expect(summary.deliveredStops, 7);
      expect(summary.pendingStops, 2);
      expect(summary.pausedStops, 1);
      expect(summary.percentComplete, 70);
      expect(summary.allCompleted, isFalse);

      const allDone = RouteProgressSummary(
        totalStops: 5,
        deliveredStops: 5,
        pausedStops: 0,
        exceptionStops: 0,
      );
      expect(allDone.percentComplete, 100);
      expect(allDone.allCompleted, isTrue);
    });
  });

  group('DeliveryStatusNotifier State Management', () {
    test('markDelivered, markException, and reset work idempotently', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(deliveryStatusStateProvider), isEmpty);

      // Mark delivered
      container.read(deliveryStatusStateProvider.notifier).markDelivered('c-1');
      expect(
        container.read(deliveryStatusStateProvider)['c-1'],
        DeliveryStopStatus.delivered,
      );

      // Mark exception
      container
          .read(deliveryStatusStateProvider.notifier)
          .markException('c-2', 'Gate locked');
      expect(
        container.read(deliveryStatusStateProvider)['c-2'],
        DeliveryStopStatus.exception,
      );

      // Reset
      container.read(deliveryStatusStateProvider.notifier).reset('c-1');
      expect(
        container.read(deliveryStatusStateProvider).containsKey('c-1'),
        isFalse,
      );
      expect(
        container.read(deliveryStatusStateProvider)['c-2'],
        DeliveryStopStatus.exception,
      );
    });

    test('MorningRouteDateNotifier updates calendar date', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const targetDate = LocalDate(2026, 10, 15);
      container.read(morningRouteDateProvider.notifier).setDate(targetDate);
      expect(container.read(morningRouteDateProvider), targetDate);
    });
  });

  group('MorningRoutePage UI & Interaction Tests', () {
    const testUser = AppUser(
      uid: 'emp-1',
      email: 'emp@test.local',
      displayName: 'Ramesh Hawkar',
      isEmailVerified: true,
      businessId: 'biz-1',
      role: UserRole.employee,
      status: AccountStatus.active,
      areaIds: {'area-1'},
    );

    const mockStops = [
      DailyRouteStop(
        customerId: 'c-101',
        customerCode: 'C101',
        customerName: 'Anil Gupta',
        houseNumber: '12-B',
        buildingInfo: 'Sunrise Apts',
        address: 'MG Road',
        landmark: 'Near Water Tank',
        deliveryPlacement: 'Door handle',
        routeSequence: 1,
        areaId: 'area-1',
        areaName: 'Sector 14',
        drops: [
          DailyPaperDrop(
            newspaperId: 'toi',
            newspaperName: 'Times of India',
            quantity: 1,
            isPaused: false,
          ),
          DailyPaperDrop(
            newspaperId: 'et',
            newspaperName: 'Economic Times',
            quantity: 1,
            isPaused: false,
          ),
        ],
      ),
      DailyRouteStop(
        customerId: 'c-102',
        customerCode: 'C102',
        customerName: 'Sunita Mehra',
        houseNumber: '14-C',
        buildingInfo: 'Sunrise Apts',
        address: 'MG Road',
        landmark: 'Near Gate 2',
        deliveryPlacement: 'Porch',
        routeSequence: 2,
        areaId: 'area-1',
        areaName: 'Sector 14',
        status: DeliveryStopStatus.paused,
        drops: [
          DailyPaperDrop(
            newspaperId: 'dj',
            newspaperName: 'Dainik Jagran',
            quantity: 1,
            isPaused: true,
            pauseReason: 'Customer out of station',
          ),
        ],
      ),
    ];

    testWidgets('renders route stops, newspaper badges, and paused warning', (
      tester,
    ) async {
      _largeView(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            morningRouteStopsProvider(testUser).overrideWith(
              (ref) async => mockStops,
            ),
            deliveryAreasProvider('biz-1').overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
          child: const MaterialApp(
            home: MorningRoutePage(user: testUser),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header title & area name
      expect(find.text('Morning Route'), findsOneWidget);
      expect(find.text('Sector 14'), findsOneWidget);

      // Check customer cards
      expect(find.text('Anil Gupta'), findsOneWidget);
      expect(find.text('12-B, Sunrise Apts'), findsOneWidget);
      expect(find.textContaining('Times of India'), findsOneWidget);
      expect(find.textContaining('Economic Times'), findsOneWidget);

      // Check paused customer and warning banner
      expect(find.text('Sunita Mehra'), findsOneWidget);
      expect(find.textContaining('PAUSED TODAY'), findsOneWidget);
      expect(find.textContaining('Dainik Jagran'), findsOneWidget);

      // Check delivery action buttons
      expect(find.text('Mark Delivered'), findsOneWidget);
    });

    testWidgets('marking delivery updates status and progress', (tester) async {
      _largeView(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            morningRouteStopsProvider(testUser).overrideWith((ref) async {
              final statuses = ref.watch(deliveryStatusStateProvider);
              return mockStops.map((s) {
                final status = statuses[s.customerId] ?? s.status;
                return s.copyWith(status: status);
              }).toList();
            }),
            deliveryAreasProvider('biz-1').overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
          child: const MaterialApp(
            home: MorningRoutePage(user: testUser),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial progress: 0 of 1 delivered
      expect(find.text('0 of 1 active delivered'), findsOneWidget);

      // Tap "Mark Delivered" on Anil Gupta's card
      await tester.tap(find.text('Mark Delivered'));
      await tester.pumpAndSettle();

      // Delivered status chip and undo button should appear
      expect(find.text('Delivered'), findsWidgets);
      expect(find.text('Undo Delivered'), findsOneWidget);
    });
  });
}

void _largeView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 2400);
  addTearDown(tester.view.reset);
}

