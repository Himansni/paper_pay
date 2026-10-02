import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/billing/presentation/manual_bill_page.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/collections/presentation/collections_providers.dart';
import 'package:paper_route/features/collections/presentation/customer_collection_summary.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';
import 'package:paper_route/features/employees/presentation/employee_providers.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';
import 'package:paper_route/features/subscriptions/presentation/subscription_providers.dart';

void main() {
  const head = AppUser(
    uid: 'head-a',
    email: 'head@example.test',
    displayName: 'Agency Head',
    isEmailVerified: true,
    businessId: 'business-a',
    role: UserRole.head,
    status: AccountStatus.active,
  );

  const employeeWithoutPricing = AppUser(
    uid: 'emp-1',
    email: 'emp1@example.test',
    displayName: 'Delivery Boy',
    isEmailVerified: true,
    businessId: 'business-a',
    role: UserRole.employee,
    status: AccountStatus.active,
    permissions: {},
  );

  const employeeWithPricing = AppUser(
    uid: 'emp-2',
    email: 'emp2@example.test',
    displayName: 'Manager',
    isEmailVerified: true,
    businessId: 'business-a',
    role: UserRole.employee,
    status: AccountStatus.active,
    permissions: {PermissionKey.allowGlobalPricing},
  );

  group('Section 17.F: Employee Permissions for Global Pricing', () {
    const policy = AccessPolicy();

    test('Head always can manage global pricing', () {
      expect(policy.canManageGlobalPricing(head), isTrue);
    });

    test('Employee without permission is rejected', () {
      expect(policy.canManageGlobalPricing(employeeWithoutPricing), isFalse);
    });

    test('Employee with allowGlobalPricing permission is allowed', () {
      expect(policy.canManageGlobalPricing(employeeWithPricing), isTrue);
    });
  });

  group('Section 17.C: Pricing Precedence & Resolution in MonthlyBillPlanner', () {
    const planner = MonthlyBillPlanner();

    const newspaperSnapshot = BillingNewspaperSnapshot(
      newspaperId: 'paper-et',
      name: 'The Economic Times',
      defaultPricePaise: 500, // ₹5.00 daily
      rules: [
        BillingPriceRuleSnapshot(
          ruleId: 'rule-et-month',
          startDate: LocalDate(2026, 9, 1),
          endDate: LocalDate(2026, 9, 30),
          pricePaise: 20000, // ₹200.00 / month
          isExactDate: false,
          revision: 1,
          pricingBasis: PricingBasis.monthly,
        ),
      ],
    );

    const term = BillingTermSnapshot(
      subscriptionId: 'sub-1',
      versionId: 'v-1',
      newspaperId: 'paper-et',
      newspaperName: 'The Economic Times',
      effectiveFrom: LocalDate(2026, 9, 1),
      effectiveTo: null,
      quantity: 1,
      deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
      customPricePaise: null,
    );

    test('Global monthly publication price rule applies to active unfinalized subscription', () {
      final lines = planner.calculate(
        customerId: 'cust-1',
        month: LocalDate(2026, 9, 1),
        terms: [term],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: {'paper-et': newspaperSnapshot},
      );

      expect(lines, hasLength(1));
      expect(lines.first.unitPricePaise, 20000);
      expect(lines.first.totalPaise, 20000);
      expect(lines.first.priceSourceId, 'rule-et-month');
      expect(lines.first.priceSource, BillPriceSource.effectivePeriod);
    });

    test('Customer-specific exception takes precedence over global monthly price', () {
      const termWithException = BillingTermSnapshot(
        subscriptionId: 'sub-2',
        versionId: 'v-2',
        newspaperId: 'paper-et',
        newspaperName: 'The Economic Times',
        effectiveFrom: LocalDate(2026, 9, 1),
        effectiveTo: null,
        quantity: 1,
        deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
        customPricePaise: 18000, // ₹180 exception
      );

      final lines = planner.calculate(
        customerId: 'cust-2',
        month: LocalDate(2026, 9, 1),
        terms: [termWithException],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: {'paper-et': newspaperSnapshot},
      );

      expect(lines, hasLength(1));
      expect(lines.first.unitPricePaise, 18000); // Exception strictly preserved
      expect(lines.first.priceSource, BillPriceSource.customerSpecific);
    });

    test('Section 5: Multi-customer propagation - 3 customers resolve central ₹200 rule, other paper unaffected, exception preserved', () {
      // Customer A, B, C subscribed to Economic Times with no overrides
      final custATerm = BillingTermSnapshot(
        subscriptionId: 'sub-a',
        versionId: 'v-a',
        newspaperId: 'paper-et',
        newspaperName: 'The Economic Times',
        effectiveFrom: LocalDate(2026, 9, 1),
        effectiveTo: null,
        quantity: 1,
        deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
        customPricePaise: null,
      );
      final custBTerm = BillingTermSnapshot(
        subscriptionId: 'sub-b',
        versionId: 'v-b',
        newspaperId: 'paper-et',
        newspaperName: 'The Economic Times',
        effectiveFrom: LocalDate(2026, 9, 1),
        effectiveTo: null,
        quantity: 1,
        deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
        customPricePaise: null,
      );
      final custCTerm = BillingTermSnapshot(
        subscriptionId: 'sub-c',
        versionId: 'v-c',
        newspaperId: 'paper-et',
        newspaperName: 'The Economic Times',
        effectiveFrom: LocalDate(2026, 9, 1),
        effectiveTo: null,
        quantity: 1,
        deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
        customPricePaise: null,
      );

      // Customer D subscribed to Navbharat Times (different publication)
      final custDTerm = BillingTermSnapshot(
        subscriptionId: 'sub-d',
        versionId: 'v-d',
        newspaperId: 'paper-nbt',
        newspaperName: 'Navbharat Times',
        effectiveFrom: LocalDate(2026, 9, 1),
        effectiveTo: null,
        quantity: 1,
        deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
        customPricePaise: null,
      );

      // Customer E has explicit ₹180 exception
      final custETerm = BillingTermSnapshot(
        subscriptionId: 'sub-e',
        versionId: 'v-e',
        newspaperId: 'paper-et',
        newspaperName: 'The Economic Times',
        effectiveFrom: LocalDate(2026, 9, 1),
        effectiveTo: null,
        quantity: 1,
        deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
        customPricePaise: 18000,
      );

      final nbtSnapshot = BillingNewspaperSnapshot(
        newspaperId: 'paper-nbt',
        name: 'Navbharat Times',
        defaultPricePaise: 400, // ₹4 daily
        rules: const [],
      );

      final newspapersMap = {
        'paper-et': newspaperSnapshot,
        'paper-nbt': nbtSnapshot,
      };

      // Customer A, B, C calculate applicable September price: ₹200
      final linesA = planner.calculate(
        customerId: 'cust-a',
        month: LocalDate(2026, 9, 1),
        terms: [custATerm],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: newspapersMap,
      );
      final linesB = planner.calculate(
        customerId: 'cust-b',
        month: LocalDate(2026, 9, 1),
        terms: [custBTerm],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: newspapersMap,
      );
      final linesC = planner.calculate(
        customerId: 'cust-c',
        month: LocalDate(2026, 9, 1),
        terms: [custCTerm],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: newspapersMap,
      );

      expect(linesA.single.unitPricePaise, 20000);
      expect(linesA.single.priceSource, BillPriceSource.effectivePeriod);

      expect(linesB.single.unitPricePaise, 20000);
      expect(linesB.single.priceSource, BillPriceSource.effectivePeriod);

      expect(linesC.single.unitPricePaise, 20000);
      expect(linesC.single.priceSource, BillPriceSource.effectivePeriod);

      // Customer D: Navbharat Times is completely unaffected by ET's rule
      final linesD = planner.calculate(
        customerId: 'cust-d',
        month: LocalDate(2026, 9, 1),
        terms: [custDTerm],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: newspapersMap,
      );
      expect(linesD.first.newspaperId, 'paper-nbt');
      expect(linesD.first.unitPricePaise, 400); // Daily default rate unaffected

      // Customer E: Exception ₹180 strictly preserved
      final linesE = planner.calculate(
        customerId: 'cust-e',
        month: LocalDate(2026, 9, 1),
        terms: [custETerm],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: newspapersMap,
      );
      expect(linesE.single.unitPricePaise, 18000);
      expect(linesE.single.priceSource, BillPriceSource.customerSpecific);

      // Paused Customer: 10 days paused, remaining 20 days still receives monthly price if active
      final linesPaused = planner.calculate(
        customerId: 'cust-a',
        month: LocalDate(2026, 9, 1),
        terms: [custATerm],
        pauses: [
          BillingPauseSnapshot(
            pauseId: 'pause-1',
            subscriptionId: 'sub-a',
            startDate: LocalDate(2026, 9, 10),
            endDate: LocalDate(2026, 9, 20),
          ),
        ],
        deliveryExceptions: const [],
        newspapers: newspapersMap,
      );
      expect(linesPaused.single.unitPricePaise, 20000);

      // Subscription outside effective period (starting Oct 1) is unaffected in September
      final linesOct = planner.calculate(
        customerId: 'cust-oct',
        month: LocalDate(2026, 9, 1),
        terms: [
          BillingTermSnapshot(
            subscriptionId: 'sub-oct',
            versionId: 'v-oct',
            newspaperId: 'paper-et',
            newspaperName: 'The Economic Times',
            effectiveFrom: LocalDate(2026, 10, 1),
            effectiveTo: null,
            quantity: 1,
            deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
            customPricePaise: null,
          ),
        ],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: newspapersMap,
      );
      expect(linesOct, isEmpty);
    });

    test('Exact-date override takes precedence on that date over period daily rate', () {
      const dailyRulesPaper = BillingNewspaperSnapshot(
        newspaperId: 'paper-et',
        name: 'The Economic Times',
        defaultPricePaise: 500,
        rules: [
          BillingPriceRuleSnapshot(
            ruleId: 'rule-et-period',
            startDate: LocalDate(2026, 9, 1),
            endDate: LocalDate(2026, 9, 30),
            pricePaise: 600, // ₹6.00 daily
            isExactDate: false,
            revision: 1,
            pricingBasis: PricingBasis.daily,
          ),
          BillingPriceRuleSnapshot(
            ruleId: 'rule-et-exact',
            startDate: LocalDate(2026, 9, 15),
            endDate: LocalDate(2026, 9, 15),
            pricePaise: 1000, // ₹10.00 on Sept 15
            isExactDate: true,
            revision: 1,
            pricingBasis: PricingBasis.daily,
          ),
        ],
      );

      final lines = planner.calculate(
        customerId: 'cust-1',
        month: LocalDate(2026, 9, 1),
        terms: [term],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: {'paper-et': dailyRulesPaper},
      );

      final sept15Line = lines.firstWhere((l) => l.serviceDate == LocalDate(2026, 9, 15));
      expect(sept15Line.unitPricePaise, 1000);
      expect(sept15Line.priceSourceId, 'rule-et-exact');
      expect(sept15Line.priceSource, BillPriceSource.exactDate);

      final sept1Line = lines.firstWhere((l) => l.serviceDate == LocalDate(2026, 9, 1));
      expect(sept1Line.unitPricePaise, 600);
      expect(sept1Line.priceSourceId, 'rule-et-period');
      expect(sept1Line.priceSource, BillPriceSource.effectivePeriod);
    });
  });

  group('Section 17.G & Section 3: Responsive UI and Layout Tests', () {
    const customerLong = Customer(
      id: 'cust-long-id-12345678901234567890',
      businessId: 'business-a',
      customerCode: 'CUST-LONG-CODE-ABCDEFGHIJKLMNOPQRSTUVWXYZ-999999999',
      name: 'Shri Ramachandra Venkatanarasimha Murthy',
      phone: '9876543210',
      areaId: 'north-sector-very-long-area-name-ext',
      assignedEmployeeId: 'emp-long-delivery-agent-name',
      status: CustomerStatus.active,
      address: 'Plot 402, Royal Residency, Beside New Shopping Complex',
      landmark: 'Near Water Tank',
    );

    final subscription = CustomerSubscription(
      id: 'sub-test',
      businessId: 'business-a',
      customerId: customerLong.id,
      newspaperId: 'paper-1',
      newspaperName: 'Daily News',
      currentVersionId: 'v-1',
      currentPauseId: '',
      status: SubscriptionStatus.active,
      startDate: LocalDate(2026, 9, 1),
      endDate: null,
      currentEffectiveFrom: LocalDate(2026, 9, 1),
      quantity: 1,
      deliveryWeekdays: const {1, 2, 3, 4, 5, 6, 7},
      customPricePaise: null,
      customPriceReason: '',
      createdBy: 'head-a',
      updatedBy: 'head-a',
      lastAuditId: 'audit-1',
    );

    for (final width in [320.0, 360.0, 390.0, 412.0]) {
      testWidgets('Customer header renders cleanly without overflow or vertical stacking at ${width}px width', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              customerProvider((businessId: 'business-a', customerId: customerLong.id))
                  .overrideWith((ref) => Stream.value(customerLong)),
              customerSubscriptionsProvider((businessId: 'business-a', customerId: customerLong.id))
                  .overrideWith((ref) => Stream.value([subscription])),
              deliveryAreasProvider('business-a')
                  .overrideWith((ref) => Stream.value([
                    const DeliveryArea(id: 'north-sector-very-long-area-name-ext', name: 'North Sector Extended Area', isActive: true, assignedEmployeeIds: {'emp-long-delivery-agent-name'}),
                  ]),),
              employeeMembersProvider('business-a')
                  .overrideWith((ref) => Stream.value([
                    const EmployeeMember(uid: 'emp-long-delivery-agent-name', email: 'agent@test.com', displayName: 'Dharmendra Kumar Sharma', phone: '9876543210', role: UserRole.employee, status: AccountStatus.active, permissions: {}, areaIds: {'north-sector-very-long-area-name-ext'}, notes: ''),
                  ]),),
            ],
            child: const MaterialApp(
              home: ManualBillPage(
                user: head,
                customerId: 'cust-long-id-12345678901234567890',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Ensure customer name is rendered
        expect(find.text(customerLong.name), findsOneWidget);
        // Ensure customer ID label is present
        expect(find.text('Customer ID: '), findsOneWidget);
        // Ensure no RenderFlex overflow
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('CustomerCollectionSummary displays primary/secondary/tertiary financial hierarchy', (tester) async {
      const summary = CustomerOutstandingSummary(
        businessId: 'business-a',
        customerId: 'cust-long-id-12345678901234567890',
        outstandingPaise: 100000, // ₹1,000
        confirmedPaise: 0,
        reversedPaise: 0,
        revision: 1,
        serverConfirmed: true,
        bills: [], // No finalized bills => collectiblePaise is 0
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerOutstandingProvider((businessId: 'business-a', customerId: customerLong.id))
                .overrideWith((ref) => Stream.value(summary)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CustomerCollectionSummary(
                user: head,
                customer: customerLong,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Collect payment is visible but clearly disabled explaining nothing collectible yet
      expect(find.byKey(const ValueKey('open-collect-payment')), findsOneWidget);
      expect(find.textContaining('Nothing collectible yet'), findsOneWidget);

      // Adjust outstanding and Create bill are visible as secondary actions
      expect(find.byKey(const ValueKey('open-outstanding-adjustment')), findsOneWidget);
      expect(find.byKey(const ValueKey('open-manual-bill')), findsOneWidget);

      // Payment history is visible
      expect(find.byKey(const ValueKey('open-customer-payments')), findsOneWidget);
    });
  });
}
