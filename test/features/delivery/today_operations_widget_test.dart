import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/delivery/domain/delivery_models.dart';
import 'package:paper_route/features/delivery/domain/today_operations_models.dart';
import 'package:paper_route/features/delivery/presentation/today_operations_page.dart';
import 'package:paper_route/features/delivery/presentation/today_operations_providers.dart';
import 'package:paper_route/l10n/app_localizations.dart';

void main() {
  const testHeadUser = AppUser(
    uid: 'head-1',
    email: 'head@paperroute.test',
    displayName: 'Head Distributor',
    businessId: 'biz-1',
    role: UserRole.head,
    status: AccountStatus.active,
    isEmailVerified: true,
  );

  final mockSummary = HeadTodayOperationsSummary(
    date: const LocalDate(2026, 9, 23),
    circulationTallies: const [
      PublicationCirculationTally(
        newspaperId: 'toi',
        newspaperName: 'Times of India',
        orderedCopies: 120,
        pausedCopies: 15,
      ),
      PublicationCirculationTally(
        newspaperId: 'ht',
        newspaperName: 'Hindustan Times',
        orderedCopies: 80,
        pausedCopies: 5,
      ),
    ],
    routeProgresses: const [
      AreaRouteProgress(
        areaId: 'area-1',
        areaName: 'Sector 14',
        totalStops: 45,
        deliveredStops: 45,
        pausedStops: 5,
        exceptionStops: 0,
      ),
      AreaRouteProgress(
        areaId: 'area-2',
        areaName: 'Sector 22',
        totalStops: 60,
        deliveredStops: 30,
        pausedStops: 10,
        exceptionStops: 1,
      ),
    ],
    collections: const HeadTodayCollectionsTally(
      cashPaise: 350000,
      upiPaise: 250000,
      totalPaise: 600000,
      paymentCount: 8,
    ),
    currentOutstandingPaise: 950000,
    todayExceptions: [
      DeliveryDropRecord(
        businessId: 'biz-1',
        routeId: '2026-09-23_area-2',
        date: '2026-09-23',
        areaId: 'area-2',
        customerId: 'cust-101',
        status: DeliveryStopStatus.exception,
        exceptionReason: 'House locked, gate chained',
        actorUid: 'emp-2',
        updatedAt: DateTime.now(),
      ),
    ],
  );

  testWidgets('TodayOperationsPage renders circulation breakdown, route progress and collections', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          headTodayOperationsProvider(testHeadUser).overrideWith(
            (ref) async => mockSummary,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TodayOperationsPage(user: testHeadUser),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text("Today's Operations"), findsOneWidget);

    // Verify Depot Circulation Section
    expect(find.text('Depot Pickup Circulation'), findsOneWidget);
    expect(find.text('Times of India'), findsOneWidget);
    expect(find.text('Hindustan Times'), findsOneWidget);
    expect(find.text('105 copies'), findsOneWidget); // 120 - 15 = 105
    expect(find.text('75 copies'), findsOneWidget);  // 80 - 5 = 75

    // Verify Routes Progress Section
    expect(find.text('Sector 14'), findsOneWidget);
    expect(find.text('Sector 22'), findsOneWidget);
    expect(find.textContaining('1 / 2 Lines Done'), findsOneWidget);

    // Verify Collections
    expect(find.text('Cash in Hand'), findsOneWidget);
    expect(find.text('Direct UPI'), findsOneWidget);

    // Verify Exceptions Alert
    expect(find.text('House locked, gate chained'), findsOneWidget);
  });
}
