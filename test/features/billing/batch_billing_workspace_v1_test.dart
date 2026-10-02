import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/billing_repository.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/billing/presentation/billing_providers.dart';
import 'package:paper_route/features/billing/presentation/billing_workspace_page.dart';
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
  ];

  int finalizeCallCount = 0;
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

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        billingRepositoryProvider.overrideWithValue(mockBillingRepo),
        newspaperRepositoryProvider.overrideWithValue(mockNewspaperRepo),
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

    testWidgets('Customer filter narrows rows and clearing restores rows',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Select Aarav Sharma in customer filter
      await tester.tap(find.byKey(const ValueKey('customer-filter')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aarav Sharma (C-001)').last);
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Bhavna Patel'), findsNothing);
      expect(find.text('Chagganlal Seth'), findsNothing);

      // Clear customer filter by selecting All Customers
      await tester.tap(find.byKey(const ValueKey('customer-filter')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('All Customers').last);
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Bhavna Patel'), findsOneWidget);
      expect(find.text('Chagganlal Seth'), findsOneWidget);
    });

    testWidgets('Publication filter excludes non-subscribers and handles multi-publication customers',
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

      // Aarav (only TOI) should be excluded
      expect(find.text('Aarav Sharma'), findsNothing);
      // Bhavna (DJ) and Chagganlal (TOI + DJ) should be present
      expect(find.text('Bhavna Patel'), findsOneWidget);
      expect(find.text('Chagganlal Seth'), findsOneWidget);
    });

    testWidgets('Publication + Customer filters compose correctly',
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

      // Filter by Bhavna Patel
      await tester.tap(find.byKey(const ValueKey('customer-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bhavna Patel (C-002)').last);
      await tester.pumpAndSettle();

      expect(find.text('Bhavna Patel'), findsOneWidget);
      expect(find.text('Chagganlal Seth'), findsNothing);
      expect(find.text('Aarav Sharma'), findsNothing);
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
  });
}
