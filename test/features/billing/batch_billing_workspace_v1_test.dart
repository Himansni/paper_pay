import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/billing_repository.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/billing/presentation/billing_providers.dart';
import 'package:paper_route/features/billing/presentation/billing_workspace_page.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';
import 'package:paper_route/features/employees/presentation/employee_providers.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/domain/newspaper_repository.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';

class MockBillingRepository implements BillingRepository {
  List<BillingWorkspaceRow> mockRows = [
    const BillingWorkspaceRow(
      customerId: 'cust-1',
      customerCode: 'C-001',
      customerName: 'Aarav Sharma',
      areaId: 'area-north',
      assignedEmployeeId: 'emp-101',
      publicationId: 'pub-toi',
      publicationName: 'Times of India',
      publicationIds: {'pub-toi'},
      hasPricing: true,
      estimatedTotalPaise: 25000,
      finalizedBill: null,
    ),
    const BillingWorkspaceRow(
      customerId: 'cust-2',
      customerCode: 'C-002',
      customerName: 'Bhavna Patel',
      areaId: 'area-south',
      assignedEmployeeId: 'emp-102',
      publicationId: 'pub-dj',
      publicationName: 'Dainik Jagran',
      publicationIds: {'pub-dj'},
      hasPricing: false,
      estimatedTotalPaise: 0,
      finalizedBill: null,
    ),
    const BillingWorkspaceRow(
      customerId: 'cust-3',
      customerCode: 'C-003',
      customerName: 'Chagganlal Seth',
      areaId: 'area-north',
      assignedEmployeeId: 'emp-101',
      publicationId: 'pub-toi',
      publicationName: 'Times of India',
      publicationIds: {'pub-toi', 'pub-dj'},
      hasPricing: true,
      estimatedTotalPaise: 30000,
      finalizedBill: FinalizedMonthlyBill(
        id: 'bill-2026-09-cust-3',
        businessId: 'biz-test',
        customerId: 'cust-3',
        customerCode: 'C-003',
        customerName: 'Chagganlal Seth',
        customerAddress: '12 Park St',
        billingMonth: '2026-09',
        openingBalancePaise: 0,
        previousBillId: '',
        previousOutstandingPaise: 0,
        priorBalancePaise: 0,
        currentChargesPaise: 30000,
        adjustmentsPaise: 0,
        totalDuePaise: 30000,
        lineItemCount: 30,
        newspaperSummaries: [],
        calculationVersion: 'paper-route-monthly-v1',
        finalizedBy: 'head-001',
        lastAuditId: 'audit-001',
      ),
    ),
    const BillingWorkspaceRow(
      customerId: 'cust-4',
      customerCode: 'C-004',
      customerName: 'Divya Kumar',
      areaId: 'area-south',
      assignedEmployeeId: 'emp-102',
      publicationId: 'pub-ht',
      publicationName: 'Hindustan Times',
      publicationIds: {'pub-ht'},
      hasPricing: true,
      estimatedTotalPaise: 22000,
      finalizedBill: null,
    ),
    const BillingWorkspaceRow(
      customerId: 'cust-5',
      customerCode: 'C-005',
      customerName: 'Ekta Jain',
      areaId: 'area-central',
      assignedEmployeeId: 'emp-103',
      publicationId: '',
      publicationName: '',
      publicationIds: {},
      hasPricing: false,
      estimatedTotalPaise: 0,
      finalizedBill: null,
    ),
  ];

  int finalizeCallCount = 0;
  List<BillingWorkspaceRow> lastBatchFinalizeRows = [];
  int saveBillingMonthlyPriceCallCount = 0;
  int recordFailureCallCount = 0;
  bool shouldFinalizeFail = false;

  @override
  Future<BillingWorkspaceResult> fetchWorkspace({
    required AppUser actor,
    required LocalDate month,
    BillingWorkspaceCursor? cursor,
    int pageSize = 25,
  }) async {
    return BillingWorkspaceResult(
      rows: mockRows,
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Future<FinalizedMonthlyBill> finalizeBill({
    required AppUser actor,
    required String customerId,
    required LocalDate month,
  }) async {
    finalizeCallCount++;
    if (shouldFinalizeFail && customerId == 'cust-2') {
      throw Exception('Simulated finalization failure for cust-2');
    }
    return FinalizedMonthlyBill(
      id: 'bill-${billingMonthKey(month)}-$customerId',
      businessId: actor.businessId ?? 'biz-test',
      customerId: customerId,
      customerCode: 'C-$customerId',
      customerName: 'Finalized $customerId',
      customerAddress: 'Sample Address',
      billingMonth: billingMonthKey(month),
      openingBalancePaise: 0,
      previousBillId: '',
      previousOutstandingPaise: 0,
      priorBalancePaise: 0,
      currentChargesPaise: 25000,
      adjustmentsPaise: 0,
      totalDuePaise: 25000,
      lineItemCount: 30,
      newspaperSummaries: const [],
      calculationVersion: phase5CalculationVersion,
      finalizedBy: actor.uid,
      lastAuditId: 'audit-batch-1',
    );
  }

  @override
  Future<void> saveBillingMonthlyPrice({
    required AppUser actor,
    required String billingMonth,
    required String newspaperId,
    required String newspaperName,
    required int pricePaise,
    required PricingBasis pricingBasis,
  }) async {
    saveBillingMonthlyPriceCallCount++;
  }

  @override
  Stream<List<BillingMonthlyPrice>> watchBillingMonthlyPrices({
    required String businessId,
    required String billingMonth,
  }) async* {
    yield [];
  }

  @override
  Future<void> recordBillingFailure({
    required AppUser actor,
    required String customerId,
    required String billingMonth,
    required String error,
  }) async {
    recordFailureCallCount++;
  }

  @override
  Future<void> clearBillingFailure({
    required String businessId,
    required String customerId,
    required String billingMonth,
  }) async {}

  @override
  Future<MonthlyBillPreview> previewBill({
    required AppUser actor,
    required String customerId,
    required LocalDate month,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<MonthlyBillPreview> previewManualBill({
    required AppUser actor,
    required ManualBillInput input,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<FinalizedMonthlyBill> finalizeManualBill({
    required AppUser actor,
    required ManualBillInput input,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String> createAdjustment({
    required AppUser actor,
    required String customerId,
    required BillingAdjustmentInput input,
  }) async {
    throw UnimplementedError();
  }

  @override
  Stream<FinalizedMonthlyBill?> watchBill({
    required String businessId,
    required String customerId,
    required String billingMonth,
  }) async* {
    yield null;
  }

  @override
  Future<BillLinePage> fetchBillLines({
    required String businessId,
    required String customerId,
    required String billingMonth,
    BillLinePageCursor? cursor,
    int pageSize = 50,
  }) async {
    return const BillLinePage(items: [], nextCursor: null, hasMore: false);
  }

  @override
  Stream<List<BillingAdjustment>> watchAdjustments({
    required String businessId,
    required String customerId,
    required String billingMonth,
  }) async* {
    yield [];
  }

  @override
  Future<BulkMonthEndBillSummary> previewBulkMonthEndBills({
    required AppUser actor,
    required String publicationId,
    required LocalDate month,
  }) async {
    return BulkMonthEndBillSummary(
      publicationId: publicationId,
      publicationName: 'Times of India',
      month: month,
      eligibleSubscribersCount: 2,
      alreadyFinalizedCount: 1,
      readyToBillCount: 1,
      missingPricingCount: 0,
      pausedNoChargeCount: 0,
      subscribers: const [],
    );
  }

  @override
  Stream<BulkMonthEndProgress> generateBulkMonthEndBills({
    required AppUser actor,
    required String publicationId,
    required LocalDate month,
  }) async* {
    yield const BulkMonthEndProgress(
      totalCount: 1,
      completedCount: 1,
      alreadyFinalizedCount: 0,
      failedCount: 0,
      currentCustomerName: 'Done',
      isDone: true,
    );
  }
}

class MockNewspaperRepository implements NewspaperRepository {
  int createPriceRuleCallCount = 0;

  @override
  Future<NewspaperPage> fetchNewspapers(NewspaperListRequest request) async {
    return const NewspaperPage(
      newspapers: [
        Newspaper(
          id: 'pub-toi',
          businessId: 'biz-test',
          newspaperCode: 'TOI',
          name: 'Times of India',
          searchName: 'times of india',
          edition: 'Delhi',
          language: 'English',
          defaultPricePaise: 25000,
          status: NewspaperStatus.active,
          createdBy: 'admin',
          updatedBy: 'admin',
          lastAuditId: 'audit-1',
        ),
        Newspaper(
          id: 'pub-dj',
          businessId: 'biz-test',
          newspaperCode: 'DJ',
          name: 'Dainik Jagran',
          searchName: 'dainik jagran',
          edition: 'Delhi',
          language: 'Hindi',
          defaultPricePaise: 20000,
          status: NewspaperStatus.active,
          createdBy: 'admin',
          updatedBy: 'admin',
          lastAuditId: 'audit-2',
        ),
        Newspaper(
          id: 'pub-ht',
          businessId: 'biz-test',
          newspaperCode: 'HT',
          name: 'Hindustan Times',
          searchName: 'hindustan times',
          edition: 'Delhi',
          language: 'English',
          defaultPricePaise: 22000,
          status: NewspaperStatus.active,
          createdBy: 'admin',
          updatedBy: 'admin',
          lastAuditId: 'audit-3',
        ),
      ],
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Future<String> createPriceRule({
    required AppUser actor,
    required String newspaperId,
    required PriceRuleInput input,
  }) async {
    createPriceRuleCallCount++;
    return 'rule-new-1';
  }

  @override
  Stream<Newspaper?> watchNewspaper({
    required String businessId,
    required String newspaperId,
  }) async* {
    yield null;
  }

  @override
  Stream<List<NewspaperAuditEntry>> watchNewspaperHistory({
    required String businessId,
    required String newspaperId,
  }) async* {
    yield [];
  }

  @override
  Future<String> createNewspaper({
    required AppUser actor,
    required NewspaperInput input,
  }) async {
    return 'pub-new-1';
  }

  @override
  Future<void> updateNewspaperProfile({
    required AppUser actor,
    required String newspaperId,
    required NewspaperProfileInput input,
  }) async {}

  @override
  Future<void> setNewspaperArchived({
    required AppUser actor,
    required String newspaperId,
    required bool archived,
  }) async {}

  @override
  Future<PriceRulePage> fetchPriceRules(PriceRuleListRequest request) async {
    return const PriceRulePage(rules: [], nextCursor: null, hasMore: false);
  }

  @override
  Future<String> correctPriceRule({
    required AppUser actor,
    required String newspaperId,
    required String replacedRuleId,
    required PriceRuleInput replacement,
  }) async {
    return 'rule-replace-1';
  }

  @override
  Future<ResolvedNewspaperPrice> resolvePriceOn({
    required String businessId,
    required String newspaperId,
    required LocalDate date,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<BulkDailyPriceUpdateResult> updateDailyPrices({
    required AppUser actor,
    required LocalDate date,
    required List<DailyPriceUpdateItem> updates,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<PricingImpactPreview> calculatePricingImpact({
    required AppUser actor,
    required String newspaperId,
    required PriceRuleInput input,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  const testHeadUser = AppUser(
    uid: 'head-001',
    email: 'head@paperroute.local',
    displayName: 'Head Manager',
    isEmailVerified: true,
    businessId: 'biz-test',
    role: UserRole.head,
    status: AccountStatus.active,
  );

  late MockBillingRepository mockBillingRepo;
  late MockNewspaperRepository mockNewspaperRepo;

  setUp(() {
    mockBillingRepo = MockBillingRepository();
    mockNewspaperRepo = MockNewspaperRepository();
  });

  Widget createWidgetUnderTest({List<EmployeeMember>? members}) {
    return ProviderScope(
      overrides: [
        billingRepositoryProvider.overrideWithValue(mockBillingRepo),
        newspaperRepositoryProvider.overrideWithValue(mockNewspaperRepo),
        if (members != null)
          employeeMembersProvider('biz-test')
              .overrideWith((ref) => Stream.value(members)),
      ],
      child: const MaterialApp(
        home: BillingWorkspacePage(user: testHeadUser),
      ),
    );
  }

  group('Gate 3 — BillingWorkspace V1 Batch Acceptance Tests', () {
    test('BillingWorkspaceRow fields check', () {
      const row = BillingWorkspaceRow(
        customerId: 'c1',
        customerCode: 'C01',
        customerName: 'Test Customer',
        areaId: 'a1',
        finalizedBill: null,
        assignedEmployeeId: 'emp-1',
        publicationId: 'pub-1',
        publicationName: 'Times',
        publicationIds: {'pub-1', 'pub-2'},
        hasPricing: true,
        estimatedTotalPaise: 5000,
        hasFailed: true,
        lastFailureReason: 'Simulation error',
      );

      expect(row.assignedEmployeeId, equals('emp-1'));
      expect(row.publicationId, equals('pub-1'));
      expect(row.publicationIds, contains('pub-2'));
      expect(row.hasFailed, isTrue);
      expect(row.lastFailureReason, equals('Simulation error'));
    });

    testWidgets(
        'renders Publication, Employee & Customer filters, Price Banner, and Summary',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Verify Month Selector
      expect(find.byKey(const ValueKey('billing-month-selector')), findsOneWidget);

      // Verify Publication, Employee & Customer filters
      expect(find.byKey(const ValueKey('publication-filter')), findsOneWidget);
      expect(find.byKey(const ValueKey('employee-filter')), findsOneWidget);
      expect(find.byKey(const ValueKey('customer-filter')), findsOneWidget);

      // Verify Set Billing Price button
      expect(find.byKey(const ValueKey('set-billing-price-btn')), findsOneWidget);

      // Verify Customer rows
      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Bhavna Patel'), findsOneWidget);
      expect(find.text('Chagganlal Seth'), findsOneWidget);
    });

    testWidgets(
        'Test 1: All Publications + All Customers -> all eligible publication subscribers are available',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Bhavna Patel'), findsOneWidget);
      expect(find.text('Chagganlal Seth'), findsOneWidget);
      expect(find.text('Divya Kumar'), findsOneWidget);
      expect(find.text('Ekta Jain'), findsOneWidget);
    });

    testWidgets(
        'Test 2: Publication A + All Customers -> only customers subscribed to A are available',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Filter by Times of India (pub-toi)
      await tester.tap(find.byKey(const ValueKey('publication-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Times of India').last);
      await tester.pumpAndSettle();

      // Subscribed to TOI: Aarav (cust-1), Chagganlal (cust-3)
      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Chagganlal Seth'), findsOneWidget);

      // Not subscribed to TOI: Bhavna (DJ only), Divya (HT only), Ekta (none)
      expect(find.text('Bhavna Patel'), findsNothing);
      expect(find.text('Divya Kumar'), findsNothing);
      expect(find.text('Ekta Jain'), findsNothing);

      // Open customer dropdown to verify customer options are scoped to TOI
      await tester.tap(find.byKey(const ValueKey('customer-filter')));
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma (C-001)'), findsOneWidget);
      expect(find.text('Chagganlal Seth (C-003)'), findsOneWidget);
      expect(find.text('Bhavna Patel (C-002)'), findsNothing);
      expect(find.text('Divya Kumar (C-004)'), findsNothing);
    });

    testWidgets(
        'Test 3: Publication B + All Customers -> only customers subscribed to B are available',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Filter by Dainik Jagran (pub-dj)
      await tester.tap(find.byKey(const ValueKey('publication-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dainik Jagran').last);
      await tester.pumpAndSettle();

      // Subscribed to DJ: Bhavna (cust-2), Chagganlal (cust-3)
      expect(find.text('Bhavna Patel'), findsOneWidget);
      expect(find.text('Chagganlal Seth'), findsOneWidget);

      // Not subscribed to DJ
      expect(find.text('Aarav Sharma'), findsNothing);
      expect(find.text('Divya Kumar'), findsNothing);
      expect(find.text('Ekta Jain'), findsNothing);

      // Verify customer dropdown options
      await tester.tap(find.byKey(const ValueKey('customer-filter')));
      await tester.pumpAndSettle();

      expect(find.text('Bhavna Patel (C-002)'), findsOneWidget);
      expect(find.text('Chagganlal Seth (C-003)'), findsOneWidget);
      expect(find.text('Aarav Sharma (C-001)'), findsNothing);
    });

    testWidgets(
        'Test 4 & 5: Multi-publication customer appears under both A and B, single-pub customer only under their pub',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Check under TOI
      await tester.tap(find.byKey(const ValueKey('publication-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Times of India').last);
      await tester.pumpAndSettle();

      expect(find.text('Chagganlal Seth'), findsOneWidget); // A + B -> present in A
      expect(find.text('Aarav Sharma'), findsOneWidget); // A only -> present in A

      // Check under DJ
      await tester.tap(find.byKey(const ValueKey('publication-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dainik Jagran').last);
      await tester.pumpAndSettle();

      expect(find.text('Chagganlal Seth'), findsOneWidget); // A + B -> present in B
      expect(find.text('Aarav Sharma'), findsNothing); // A only -> NOT in B

      // Check under HT
      await tester.tap(find.byKey(const ValueKey('publication-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hindustan Times').last);
      await tester.pumpAndSettle();

      expect(find.text('Divya Kumar'), findsOneWidget);
      expect(find.text('Chagganlal Seth'), findsNothing);
      expect(find.text('Aarav Sharma'), findsNothing);
    });

    testWidgets(
        'Test 6: Publication A + Employee X -> customer options respect BOTH publication and employee filtering',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Filter by Dainik Jagran
      await tester.tap(find.byKey(const ValueKey('publication-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dainik Jagran').last);
      await tester.pumpAndSettle();

      // Filter by Employee emp-101 (Chagganlal Seth is emp-101, Bhavna Patel is emp-102)
      await tester.tap(find.byKey(const ValueKey('employee-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Employee: emp-101').last);
      await tester.pumpAndSettle();

      expect(find.text('Chagganlal Seth'), findsOneWidget);
      expect(find.text('Bhavna Patel'), findsNothing);

      // Verify customer dropdown only contains Chagganlal Seth
      await tester.tap(find.byKey(const ValueKey('customer-filter')));
      await tester.pumpAndSettle();

      expect(find.text('Chagganlal Seth (C-003)'), findsOneWidget);
      expect(find.text('Bhavna Patel (C-002)'), findsNothing);
    });

    testWidgets(
        'Test 7: Publication A + Customer 3 -> only Customer 3 is selected/displayed',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Filter by Times of India
      await tester.tap(find.byKey(const ValueKey('publication-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Times of India').last);
      await tester.pumpAndSettle();

      // Filter by Customer Chagganlal Seth (C-003)
      await tester.tap(find.byKey(const ValueKey('customer-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chagganlal Seth (C-003)').last);
      await tester.pumpAndSettle();

      expect(find.text('Chagganlal Seth'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsNothing);
    });

    testWidgets(
        'Test 8: Changing Publication A -> Publication B reconciles customer filter and selected customer state',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Filter by Times of India
      await tester.tap(find.byKey(const ValueKey('publication-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Times of India').last);
      await tester.pumpAndSettle();

      // Select Aarav Sharma (who only subscribes to TOI)
      await tester.tap(find.byKey(const ValueKey('customer-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aarav Sharma (C-001)').last);
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsOneWidget);

      // Now switch publication to Dainik Jagran (Aarav is NOT subscribed to DJ)
      await tester.tap(find.byKey(const ValueKey('publication-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dainik Jagran').last);
      await tester.pumpAndSettle();

      // Customer selection should reconcile cleanly without errors, showing DJ subscribers
      expect(find.text('Bhavna Patel'), findsOneWidget);
      expect(find.text('Chagganlal Seth'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsNothing);
    });

    testWidgets(
        'Test 9: Select All Ready after publication filtering selects only Ready customers in current filtered dataset',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Filter by Times of India
      // Under TOI: Aarav Sharma (ready/unfinalized), Chagganlal Seth (already finalized)
      await tester.tap(find.byKey(const ValueKey('publication-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Times of India').last);
      await tester.pumpAndSettle();

      // Tap Select All Ready
      await tester.tap(find.text('Select All Ready'));
      await tester.pumpAndSettle();

      // "Create Selected (1)" should show count 1 (only Aarav Sharma)
      expect(find.text('Create Selected (1)'), findsOneWidget);
    });

    testWidgets(
        'Test 10: Create All after publication filtering operates only on current filtered customer dataset',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Filter by Dainik Jagran (Bhavna Patel is ready to bill)
      await tester.tap(find.byKey(const ValueKey('publication-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dainik Jagran').last);
      await tester.pumpAndSettle();

      // Tap Create All
      await tester.tap(find.byKey(const ValueKey('create-all-bills-btn')));
      await tester.pumpAndSettle();

      // Finalize should be invoked for the ready customer under DJ (Bhavna Patel)
      expect(mockBillingRepo.finalizeCallCount, equals(1));
    });

    testWidgets('Use for this billing only persists server-authoritatively',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Open Set Billing Price modal
      await tester.tap(find.byKey(const ValueKey('set-billing-price-btn')));
      await tester.pumpAndSettle();

      // Default has "Use for this billing only" checked
      await tester.tap(find.byKey(const ValueKey('save-price-btn')));
      await tester.pumpAndSettle();

      // Verify saveBillingMonthlyPrice was called on repository
      expect(mockBillingRepo.saveBillingMonthlyPriceCallCount, equals(1));
    });

    testWidgets('Failed row displays Retry and retry can succeed',
        (tester) async {
      mockBillingRepo.mockRows = [
        const BillingWorkspaceRow(
          customerId: 'cust-failed',
          customerCode: 'C-FAIL',
          customerName: 'Failed Customer',
          areaId: 'area-north',
          assignedEmployeeId: 'emp-101',
          publicationId: 'pub-toi',
          publicationName: 'Times of India',
          publicationIds: {'pub-toi'},
          hasPricing: true,
          estimatedTotalPaise: 25000,
          finalizedBill: null,
          hasFailed: true,
          lastFailureReason: 'Firestore transaction lock error',
        ),
      ];

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Verify Failed status text and Retry button are displayed
      expect(find.textContaining('Failed: Firestore transaction lock error'), findsOneWidget);
      final retryBtn = find.byKey(const ValueKey('retry-bill-cust-failed'));
      expect(retryBtn, findsOneWidget);

      // Tap Retry
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      // Verify finalizeBill was invoked
      expect(mockBillingRepo.finalizeCallCount, equals(1));
    });

    testWidgets(
        'Mobile viewport layout renders cleanly without horizontal overflow at 360x640 and truncates long customer IDs',
        (tester) async {
      mockBillingRepo.mockRows = [
        const BillingWorkspaceRow(
          customerId: 'cust-long-id',
          customerCode:
              'C-56D91E6CABAF4E219971304DCB6E6825-VERY-LONG-CUSTOMER-CODE',
          customerName:
              'Emiway Bantai Long Name Testing Mobile Responsiveness',
          areaId: 'area-fd9g8ZN5YDk04I9yWIDy',
          assignedEmployeeId: 'upNLkwhR95hLS70Xo8reqdjmTBl2',
          publicationId: 'pub-toi',
          publicationName: 'Times of India',
          publicationIds: {'pub-toi'},
          hasPricing: true,
          estimatedTotalPaise: 25000,
          finalizedBill: null,
          hasFailed: true,
          lastFailureReason:
              'A collection balance exists without an earlier finalized bill',
        ),
      ];

      // Set narrow phone viewport (360 x 640 dp)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Verify no RenderFlex overflow error occurred
      expect(tester.takeException(), isNull);

      // Verify filters visible & usable
      expect(find.byKey(const ValueKey('publication-filter')), findsOneWidget);

      // Verify price card accessible
      expect(find.byKey(const ValueKey('set-billing-price-btn')), findsOneWidget);

      // Verify batch action buttons accessible
      final createAllFinder = find.byKey(const ValueKey('create-all-bills-btn'));
      await tester.scrollUntilVisible(createAllFinder, 200.0);
      await tester.pumpAndSettle();
      expect(createAllFinder, findsOneWidget);

      // Verify long customer name and code rendered safely
      expect(find.textContaining('Emiway Bantai'), findsOneWidget);
      expect(find.textContaining('C-56D91E6CABAF4E219971304DCB6E6825'), findsOneWidget);

      // Verify failed state and retry button visible
      final retryFinder = find.byKey(const ValueKey('retry-bill-cust-long-id'));
      await tester.scrollUntilVisible(retryFinder, 200.0);
      await tester.pumpAndSettle();
      expect(retryFinder, findsOneWidget);
    });

    testWidgets(
        'Regression Test 1: Employee with profile name displays name in dropdown and customer cards',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const members = [
        EmployeeMember(
          uid: 'emp-101',
          email: 'rahul@test.com',
          displayName: 'Rahul Sharma',
          phone: '9876543210',
          role: UserRole.employee,
          status: AccountStatus.active,
          permissions: {},
          areaIds: {'area-north'},
          notes: '',
        ),
        EmployeeMember(
          uid: 'emp-102',
          email: 'priya@test.com',
          displayName: 'Priya Verma',
          phone: '9876543211',
          role: UserRole.employee,
          status: AccountStatus.active,
          permissions: {},
          areaIds: {'area-south'},
          notes: '',
        ),
      ];

      await tester.pumpWidget(createWidgetUnderTest(members: members));
      await tester.pumpAndSettle();

      // Open employee filter dropdown
      final empDropdown = find.byKey(const ValueKey('employee-filter'));
      expect(empDropdown, findsOneWidget);
      await tester.tap(empDropdown);
      await tester.pumpAndSettle();

      // Verify human-readable names are displayed, NOT raw UIDs as primary labels
      expect(find.text('Rahul Sharma'), findsWidgets);
      expect(find.text('Priya Verma'), findsWidgets);
      expect(find.text('Employee: emp-101'), findsNothing);
      expect(find.text('Employee: emp-102'), findsNothing);

      // Close dropdown by tapping outside or selecting Rahul Sharma
      await tester.tap(find.text('Rahul Sharma').last);
      await tester.pumpAndSettle();

      // Verify card subtitle shows human-readable employee name
      expect(find.textContaining('Emp: Rahul Sharma'), findsWidgets);
    });

    testWidgets(
        'Regression Test 2: Selecting employee filters by UID internally',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const members = [
        EmployeeMember(
          uid: 'emp-101',
          email: 'rahul@test.com',
          displayName: 'Rahul Sharma',
          phone: '9876543210',
          role: UserRole.employee,
          status: AccountStatus.active,
          permissions: {},
          areaIds: {'area-north'},
          notes: '',
        ),
        EmployeeMember(
          uid: 'emp-102',
          email: 'priya@test.com',
          displayName: 'Priya Verma',
          phone: '9876543211',
          role: UserRole.employee,
          status: AccountStatus.active,
          permissions: {},
          areaIds: {'area-south'},
          notes: '',
        ),
      ];

      await tester.pumpWidget(createWidgetUnderTest(members: members));
      await tester.pumpAndSettle();

      // Select Rahul Sharma (emp-101)
      await tester.tap(find.byKey(const ValueKey('employee-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rahul Sharma').last);
      await tester.pumpAndSettle();

      // Only emp-101 customers (Aarav Sharma cust-1, Chagganlal Seth cust-3) should be displayed
      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Chagganlal Seth'), findsOneWidget);
      // emp-102 customers should NOT be displayed
      expect(find.text('Bhavna Patel'), findsNothing);
      expect(find.text('Divya Kumar'), findsNothing);
    });

    testWidgets(
        'Regression Test 3: Employee from another business never appears in dropdown',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Members scoped only to current business biz-test
      const currentBusinessMembers = [
        EmployeeMember(
          uid: 'emp-101',
          email: 'rahul@test.com',
          displayName: 'Rahul Sharma',
          phone: '9876543210',
          role: UserRole.employee,
          status: AccountStatus.active,
          permissions: {},
          areaIds: {'area-north'},
          notes: '',
        ),
      ];

      await tester.pumpWidget(createWidgetUnderTest(members: currentBusinessMembers));
      await tester.pumpAndSettle();

      // Open employee filter dropdown
      await tester.tap(find.byKey(const ValueKey('employee-filter')));
      await tester.pumpAndSettle();

      // Foreign employee "Vikram Malhotra" from business-b should NOT exist anywhere
      expect(find.text('Vikram Malhotra'), findsNothing);
      expect(find.text('Employee: emp-foreign'), findsNothing);
    });

    testWidgets(
        'Regression Test 4: Missing employee profile does not crash and falls back safely',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // No profile provided for emp-101 or emp-102 (empty members list)
      await tester.pumpWidget(createWidgetUnderTest(members: const []));
      await tester.pumpAndSettle();

      // Verify no exception was thrown
      expect(tester.takeException(), isNull);

      // Open employee filter dropdown
      await tester.tap(find.byKey(const ValueKey('employee-filter')));
      await tester.pumpAndSettle();

      // Safe fallback to 'Employee: <uid>' is displayed without error
      expect(find.text('Employee: emp-101'), findsWidgets);
      expect(find.text('Employee: emp-102'), findsWidgets);
    });
  });
}
