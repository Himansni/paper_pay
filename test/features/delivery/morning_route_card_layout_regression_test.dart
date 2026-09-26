import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/delivery/domain/delivery_models.dart';
import 'package:paper_route/features/delivery/presentation/delivery_providers.dart';
import 'package:paper_route/features/delivery/presentation/morning_route_page.dart';

void main() {
  const testUser = AppUser(
    uid: 'emp-101',
    email: 'emp@paperroute.test',
    displayName: 'Test Employee',
    isEmailVerified: true,
    businessId: 'biz-test',
    role: UserRole.employee,
    status: AccountStatus.active,
    areaIds: {'area-1', 'area-2'},
  );

  const testAreas = [
    DeliveryArea(
      id: 'area-1',
      name: 'Kabir Nagar Raipur',
      isActive: true,
      assignedEmployeeIds: {'emp-101'},
    ),
    DeliveryArea(
      id: 'area-2',
      name: 'Founder Route Area 1790192875866 Extended Regional Zone',
      isActive: true,
      assignedEmployeeIds: {'emp-101'},
    ),
  ];

  final mockStopNormal = DailyRouteStop(
    customerId: 'c-1',
    customerCode: 'C-1001',
    customerName: 'Kabir Nagar Raipur',
    houseNumber: 'MIG - 21',
    buildingInfo: 'Block B',
    address: 'House / Flat MIG - 21, Kabir Nagar Raipur',
    landmark: 'Near Water Overhead Tank',
    deliveryPlacement: 'Front porch gate',
    routeSequence: 1,
    areaId: 'area-1',
    areaName: 'Kabir Nagar Raipur',
    drops: const [
      DailyPaperDrop(
        newspaperId: 'np-1',
        newspaperName: 'Dainik Jagran',
        quantity: 1,
        isPaused: false,
      ),
    ],
  );

  final mockStopLong = DailyRouteStop(
    customerId: 'c-2',
    customerCode: 'C-VERY-LONG-CUSTOMER-CODE-998877665544332211',
    customerName:
        'Dr. Vikramaditya Harshavardhan Singhania-Deshmukh Bahadur the Third',
    houseNumber: 'Apartment Suite 402-A',
    buildingInfo:
        'The Grand Royal Presidential Imperial Residency and Towers Phase 4',
    address:
        'Plot 12-14, Major Somnath Sharma Marg, Behind Central Business District Metro Station, Raipur, Chhattisgarh 492099',
    landmark:
        'Opposite State Bank of India Zonal Administrative Headquarters',
    deliveryPlacement:
        'Security guard cabin desk on the ground floor left entrance',
    routeSequence: 2,
    areaId: 'area-1',
    areaName: 'Kabir Nagar Raipur',
    drops: const [
      DailyPaperDrop(
        newspaperId: 'np-long-1',
        newspaperName:
            'The International Financial And Commercial Daily Chronicle of Global Markets and Regional Business Analytics Special Collector Edition',
        quantity: 2,
        isPaused: false,
      ),
      DailyPaperDrop(
        newspaperId: 'np-long-2',
        newspaperName:
            'Rashtriya Samachar Darpan Sahitya Evam Vyaparik Jagat',
        quantity: 1,
        isPaused: true,
        pauseReason: 'Customer out of town until next Monday',
      ),
    ],
  );

  group('Morning Route Card Layout & Width Distribution Tests', () {
    testWidgets(
      'A, D, E, F, G, H: Top Route Card gives meaningful width to area and date metadata without vertical character stacking',
      (tester) async {
        // Test on narrow 360x640 mobile screen
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 640);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              morningRouteStopsProvider(testUser).overrideWith(
                (ref) async => [mockStopNormal],
              ),
              deliveryAreasProvider('biz-test').overrideWith(
                (ref) => Stream.value(testAreas),
              ),
              morningRouteDateProvider.overrideWith(
                () => _FixedMorningRouteDateNotifier(const LocalDate(2026, 9, 26)),
              ),
            ],
            child: const MaterialApp(
              home: MorningRoutePage(user: testUser),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // E. No layout overflow exceptions
        expect(tester.takeException(), isNull);

        // A & F. Top Route Area Name "Kabir Nagar Raipur" receives meaningful horizontal width
        final areaNameFinder = find.text('Kabir Nagar Raipur');
        expect(areaNameFinder, findsWidgets);
        final titleSize = tester.getSize(areaNameFinder.first);
        expect(
          titleSize.width,
          greaterThanOrEqualTo(100.0),
          reason: 'Area name title should receive generous width, not 0-15px',
        );

        // G. Height should be standard 1 or 2 lines (around 20-60px), NOT 400px+ vertical stacking
        expect(
          titleSize.height,
          lessThan(80.0),
          reason: 'Text should not wrap one character per line',
        );

        // D & F. Date metadata "2026-09-26 • Saturday" receives meaningful horizontal width
        final dateFinder = find.textContaining('2026-09-26');
        expect(dateFinder, findsOneWidget);
        final dateSize = tester.getSize(dateFinder);
        expect(dateSize.width, greaterThanOrEqualTo(100.0));
        expect(dateSize.height, lessThan(40.0));

        // H. Trailing area selector dropdown is present and contained
        expect(find.byType(DropdownButton<String>), findsOneWidget);

        // Progress bar and counters are present and properly laid out
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(find.text('0 of 1 active delivered'), findsOneWidget);
        expect(find.text('0% Completed'), findsOneWidget);
      },
    );

    testWidgets(
      'B, C, E, F: Route stop card with extreme customer, address, and publication name lengths lays out cleanly',
      (tester) async {
        // Test on narrow 320x640 mobile screen
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              morningRouteStopsProvider(testUser).overrideWith(
                (ref) async => [mockStopLong],
              ),
              deliveryAreasProvider('biz-test').overrideWith(
                (ref) => Stream.value(testAreas),
              ),
            ],
            child: const MaterialApp(
              home: MorningRoutePage(user: testUser),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // E. No layout overflow exceptions
        expect(tester.takeException(), isNull);

        // B. Long customer name renders with non-zero width and constrained lines
        final customerNameFinder = find.text(mockStopLong.customerName);
        expect(customerNameFinder, findsOneWidget);
        final custNameSize = tester.getSize(customerNameFinder);
        expect(custNameSize.width, greaterThan(150.0));
        // maxLines 2 ensures height does not blow up
        expect(custNameSize.height, lessThan(80.0));

        // B. Long address renders without overflow
        final addressFinder = find.text(mockStopLong.address);
        expect(addressFinder, findsOneWidget);
        final addressSize = tester.getSize(addressFinder);
        expect(addressSize.width, greaterThan(150.0));

        // C. Long publication name is rendered inside drop badge
        expect(
          find.textContaining('The International Financial'),
          findsOneWidget,
        );

        // Action button is visible and tappable
        expect(find.text('Mark Delivered'), findsOneWidget);
      },
    );

    testWidgets(
      'Safe on multiple screen form factors: 320px, 360px, 412px viewports',
      (tester) async {
        for (final width in [320.0, 360.0, 412.0]) {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 700);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                morningRouteStopsProvider(testUser).overrideWith(
                  (ref) async => [mockStopNormal, mockStopLong],
                ),
                deliveryAreasProvider('biz-test').overrideWith(
                  (ref) => Stream.value(testAreas),
                ),
              ],
              child: const MaterialApp(
                home: MorningRoutePage(user: testUser),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: 'Should not throw overflow on width $width',
          );
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );
  });
}

class _FixedMorningRouteDateNotifier extends MorningRouteDateNotifier {
  _FixedMorningRouteDateNotifier(this.initialDate);
  final LocalDate initialDate;

  @override
  LocalDate build() => initialDate;
}
