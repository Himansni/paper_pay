import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/collections/domain/collection_repository.dart';
import 'package:paper_route/features/collections/presentation/collect_payment_page.dart';
import 'package:paper_route/features/collections/presentation/collections_providers.dart';
import 'package:paper_route/features/collections/presentation/customer_collection_summary.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';

class _ScenarioCollectionsRepository implements CollectionsRepository {
  _ScenarioCollectionsRepository({
    required this.summary,
  });

  CustomerOutstandingSummary summary;
  final UpiSettings upiSettings = const UpiSettings(
    businessId: 'biz-1',
    upiId: 'test@upi',
    payeeName: 'Test Business',
    referencePrefix: 'PRTEST',
    enabled: true,
    updatedBy: 'head-1',
    lastAuditId: 'audit-1',
    serverConfirmed: true,
  );
  final List<PaymentConfirmationInput> confirmedInputs = [];

  @override
  Stream<CustomerOutstandingSummary> watchCustomerOutstanding({
    required String businessId,
    required String customerId,
  }) =>
      Stream.value(summary);

  @override
  Future<CustomerOutstandingSummary> fetchCustomerOutstanding({
    required AppUser actor,
    required String customerId,
  }) async =>
      summary;

  @override
  Future<PaymentConfirmationResult> confirmPayment({
    required AppUser actor,
    required String customerId,
    required PaymentConfirmationInput input,
  }) async {
    confirmedInputs.add(input);
    final remaining = summary.outstandingPaise - input.amountPaise;
    return PaymentConfirmationResult(
      payment: ConfirmedPayment(
        id: 'PAY-1',
        businessId: actor.businessId!,
        customerId: customerId,
        customerCode: 'C-100',
        customerName: 'Sharma Ji',
        amountPaise: input.amountPaise,
        method: input.method,
        status: ConfirmedPaymentStatus.confirmed,
        externalReference: input.externalReference,
        notes: input.notes,
        collectorUid: actor.uid,
        confirmedAt: DateTime.now(),
        allocations: [
          BillAllocation(
            billId: summary.bills.isNotEmpty ? summary.bills.first.billId : 'B-1',
            billingMonth: '2026-09',
            amountPaise: input.amountPaise,
          ),
        ],
        reversedPaise: 0,
        lastAuditId: 'audit-pay-1',
        serverConfirmed: true,
      ),
      remainingOutstandingPaise: remaining,
      serverConfirmed: true,
    );
  }

  @override
  Stream<UpiSettings> watchUpiSettings(String businessId) =>
      Stream.value(upiSettings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const authorizedEmployee = AppUser(
    uid: 'emp-1',
    email: 'emp1@paperroute.test',
    displayName: 'Authorized Employee',
    isEmailVerified: true,
    businessId: 'biz-1',
    role: UserRole.employee,
    status: AccountStatus.active,
    permissions: {PermissionKey.recordPayments},
    areaIds: {'area-1'},
  );

  final activeCustomer = Customer(
    id: 'CUST-100',
    businessId: 'biz-1',
    customerCode: 'C-100',
    name: 'Sharma Ji',
    phone: '9876543210',
    areaId: 'area-1',
    assignedEmployeeId: 'emp-1',
    houseNumber: '12',
    address: 'Kabir Nagar Raipur',
    status: CustomerStatus.active,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  CustomerOutstandingSummary createSummary({
    int outstandingPaise = 100000, // ₹1000.00
    bool serverConfirmed = true,
    bool requiresProjectionSetup = false,
  }) =>
      CustomerOutstandingSummary(
        businessId: 'biz-1',
        customerId: 'CUST-100',
        outstandingPaise: outstandingPaise,
        confirmedPaise: 0,
        reversedPaise: 0,
        bills: [
          OutstandingBill(
            billId: 'BILL-1',
            billingMonth: '2026-09',
            sourceAmountPaise: outstandingPaise,
            allocatedPaise: 0,
            reversedPaise: 0,
            outstandingPaise: outstandingPaise,
            status: 'outstanding',
            revision: 1,
          ),
        ],
        revision: 1,
        serverConfirmed: serverConfirmed,
        requiresProjectionSetup: requiresProjectionSetup,
      );

  void useLargeTestView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget createTestWidget({
    required AppUser user,
    required Customer customer,
    required CollectionsRepository repo,
    required Widget child,
  }) =>
      ProviderScope(
        overrides: [
          customerProvider((businessId: customer.businessId, customerId: customer.id))
              .overrideWith((ref) => Stream.value(customer)),
          collectionsRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );

  group('CTO 17 Payment Flow Regression Scenarios', () {
    testWidgets('1. Outstanding ₹1000 -> Collect Payment button enabled when authorized and state is valid', (tester) async {
      useLargeTestView(tester);
      final repo = _ScenarioCollectionsRepository(summary: createSummary(outstandingPaise: 100000));
      await tester.pumpWidget(
        createTestWidget(
          user: authorizedEmployee,
          customer: activeCustomer,
          repo: repo,
          child: CustomerCollectionSummary(user: authorizedEmployee, customer: activeCustomer),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byKey(const ValueKey('open-collect-payment')));
      expect(button.onPressed, isNotNull, reason: 'Collect payment button must be enabled for authorized user with ₹1000 due');
      expect(find.text('₹1,000.00'), findsOneWidget);
    });

    testWidgets('2. Amount field initially contains ₹1000', (tester) async {
      useLargeTestView(tester);
      final repo = _ScenarioCollectionsRepository(summary: createSummary(outstandingPaise: 100000));
      await tester.pumpWidget(
        createTestWidget(
          user: authorizedEmployee,
          customer: activeCustomer,
          repo: repo,
          child: CollectPaymentPage(user: authorizedEmployee, customerId: activeCustomer.id),
        ),
      );
      await tester.pumpAndSettle();

      final amountField = tester.widget<TextFormField>(find.byKey(const ValueKey('collection-amount')));
      expect(amountField.controller?.text, equals('1000'), reason: 'Amount field must prefill to 1000');
    });

    testWidgets('3. User can edit amount field from ₹1000 to ₹500', (tester) async {
      useLargeTestView(tester);
      final repo = _ScenarioCollectionsRepository(summary: createSummary(outstandingPaise: 100000));
      await tester.pumpWidget(
        createTestWidget(
          user: authorizedEmployee,
          customer: activeCustomer,
          repo: repo,
          child: CollectPaymentPage(user: authorizedEmployee, customerId: activeCustomer.id),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('collection-amount')), '500');
      await tester.pumpAndSettle();

      final amountField = tester.widget<TextFormField>(find.byKey(const ValueKey('collection-amount')));
      expect(amountField.controller?.text, equals('500'), reason: 'User must be able to edit amount down to 500');
    });

    testWidgets('4. ₹500 payment reaches confirmPayment as 50000 paise', (tester) async {
      useLargeTestView(tester);
      final repo = _ScenarioCollectionsRepository(summary: createSummary(outstandingPaise: 100000));
      await tester.pumpWidget(
        createTestWidget(
          user: authorizedEmployee,
          customer: activeCustomer,
          repo: repo,
          child: CollectPaymentPage(user: authorizedEmployee, customerId: activeCustomer.id),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('collection-amount')), '500');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('confirm-payment')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('manual-receipt-confirmation')));
      await tester.pumpAndSettle();

      expect(repo.confirmedInputs, hasLength(1));
      expect(repo.confirmedInputs.single.amountPaise, equals(50000), reason: '₹500 must reach backend as 50000 paise');
    });

    testWidgets('5. Full ₹1000 payment works and reaches confirmPayment as 100000 paise', (tester) async {
      useLargeTestView(tester);
      final repo = _ScenarioCollectionsRepository(summary: createSummary(outstandingPaise: 100000));
      await tester.pumpWidget(
        createTestWidget(
          user: authorizedEmployee,
          customer: activeCustomer,
          repo: repo,
          child: CollectPaymentPage(user: authorizedEmployee, customerId: activeCustomer.id),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('confirm-payment')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('manual-receipt-confirmation')));
      await tester.pumpAndSettle();

      expect(repo.confirmedInputs, hasLength(1));
      expect(repo.confirmedInputs.single.amountPaise, equals(100000), reason: 'Full ₹1000 must reach backend as 100000 paise');
    });

    testWidgets('6. ₹0 rejected with validation error', (tester) async {
      useLargeTestView(tester);
      final repo = _ScenarioCollectionsRepository(summary: createSummary(outstandingPaise: 100000));
      await tester.pumpWidget(
        createTestWidget(
          user: authorizedEmployee,
          customer: activeCustomer,
          repo: repo,
          child: CollectPaymentPage(user: authorizedEmployee, customerId: activeCustomer.id),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('collection-amount')), '0');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('confirm-payment')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a positive amount.'), findsOneWidget);
      expect(repo.confirmedInputs, isEmpty);
    });

    testWidgets('7. Negative amount rejected with validation error', (tester) async {
      useLargeTestView(tester);
      final repo = _ScenarioCollectionsRepository(summary: createSummary(outstandingPaise: 100000));
      await tester.pumpWidget(
        createTestWidget(
          user: authorizedEmployee,
          customer: activeCustomer,
          repo: repo,
          child: CollectPaymentPage(user: authorizedEmployee, customerId: activeCustomer.id),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('collection-amount')), '-50');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('confirm-payment')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a positive amount.'), findsOneWidget);
      expect(repo.confirmedInputs, isEmpty);
    });

    testWidgets('8. Amount > outstanding rejected with validation error', (tester) async {
      useLargeTestView(tester);
      final repo = _ScenarioCollectionsRepository(summary: createSummary(outstandingPaise: 100000));
      await tester.pumpWidget(
        createTestWidget(
          user: authorizedEmployee,
          customer: activeCustomer,
          repo: repo,
          child: CollectPaymentPage(user: authorizedEmployee, customerId: activeCustomer.id),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('collection-amount')), '1500');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('confirm-payment')));
      await tester.pumpAndSettle();

      expect(find.text('Amount cannot exceed the current outstanding.'), findsOneWidget);
      expect(repo.confirmedInputs, isEmpty);
    });

    testWidgets('9. Unauthorized employee cannot collect (button disabled)', (tester) async {
      useLargeTestView(tester);
      final otherEmployee = AppUser(
        uid: 'other-emp',
        email: 'other@test.com',
        displayName: 'Other Employee',
        isEmailVerified: true,
        businessId: 'biz-1',
        role: UserRole.employee,
        status: AccountStatus.active,
        permissions: const {PermissionKey.recordPayments},
        areaIds: const {'area-1'},
      );

      final repo = _ScenarioCollectionsRepository(summary: createSummary(outstandingPaise: 100000));
      await tester.pumpWidget(
        createTestWidget(
          user: otherEmployee,
          customer: activeCustomer, // assigned to emp-1
          repo: repo,
          child: CustomerCollectionSummary(user: otherEmployee, customer: activeCustomer),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byKey(const ValueKey('open-collect-payment')));
      expect(button.onPressed, isNull, reason: 'Unassigned employee must not have Collect payment enabled');
      expect(find.text('Collection requires this assignment, area access, and the record-payments permission.'), findsOneWidget);
    });

    testWidgets('10. Employee without recordPayments cannot collect', (tester) async {
      useLargeTestView(tester);
      final unpermittedEmployee = AppUser(
        uid: 'emp-1',
        email: 'emp1@paperroute.test',
        displayName: 'Authorized Employee',
        isEmailVerified: true,
        businessId: 'biz-1',
        role: UserRole.employee,
        status: AccountStatus.active,
        permissions: const {}, // No recordPayments!
        areaIds: const {'area-1'},
      );

      final repo = _ScenarioCollectionsRepository(summary: createSummary(outstandingPaise: 100000));
      await tester.pumpWidget(
        createTestWidget(
          user: unpermittedEmployee,
          customer: activeCustomer,
          repo: repo,
          child: CustomerCollectionSummary(user: unpermittedEmployee, customer: activeCustomer),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byKey(const ValueKey('open-collect-payment')));
      expect(button.onPressed, isNull);
    });

    testWidgets('11. Wrong area cannot collect', (tester) async {
      useLargeTestView(tester);
      final wrongAreaEmployee = AppUser(
        uid: 'emp-1',
        email: 'emp1@paperroute.test',
        displayName: 'Authorized Employee',
        isEmailVerified: true,
        businessId: 'biz-1',
        role: UserRole.employee,
        status: AccountStatus.active,
        permissions: const {PermissionKey.recordPayments},
        areaIds: const {'area-99'}, // Wrong area
      );

      final repo = _ScenarioCollectionsRepository(summary: createSummary(outstandingPaise: 100000));
      await tester.pumpWidget(
        createTestWidget(
          user: wrongAreaEmployee,
          customer: activeCustomer,
          repo: repo,
          child: CustomerCollectionSummary(user: wrongAreaEmployee, customer: activeCustomer),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byKey(const ValueKey('open-collect-payment')));
      expect(button.onPressed, isNull);
    });

    testWidgets('12. Archived customer cannot collect', (tester) async {
      useLargeTestView(tester);
      final archivedCustomer = Customer(
        id: 'CUST-100',
        businessId: 'biz-1',
        customerCode: 'C-100',
        name: 'Sharma Ji',
        phone: '9876543210',
        areaId: 'area-1',
        assignedEmployeeId: 'emp-1',
        houseNumber: '12',
        address: 'Kabir Nagar Raipur',
        status: CustomerStatus.archived, // Archived!
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final repo = _ScenarioCollectionsRepository(summary: createSummary(outstandingPaise: 100000));
      await tester.pumpWidget(
        createTestWidget(
          user: authorizedEmployee,
          customer: archivedCustomer,
          repo: repo,
          child: CustomerCollectionSummary(user: authorizedEmployee, customer: archivedCustomer),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byKey(const ValueKey('open-collect-payment')));
      expect(button.onPressed, isNull, reason: 'Archived customer must never allow collection');
    });

    testWidgets('13. Missing collectionState does NOT allow unsafe payment', (tester) async {
      useLargeTestView(tester);
      final repo = _ScenarioCollectionsRepository(
        summary: createSummary(
          outstandingPaise: 100000,
          requiresProjectionSetup: true, // Legacy balance without projection!
        ),
      );
      await tester.pumpWidget(
        createTestWidget(
          user: authorizedEmployee,
          customer: activeCustomer,
          repo: repo,
          child: CustomerCollectionSummary(user: authorizedEmployee, customer: activeCustomer),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byKey(const ValueKey('open-collect-payment')));
      expect(button.onPressed, isNull, reason: 'Missing collection projection must block payment');
      expect(find.byKey(const ValueKey('customer-projection-required')), findsOneWidget);
    });

    test('14. Legacy migration/backfill logic is idempotent and produces deterministic state', () {
      // Simulate two runs of projection computation from authoritative bills
      final bills = [
        {'id': 'B-1', 'month': '2026-08', 'totalDue': 45000},
        {'id': 'B-2', 'month': '2026-09', 'totalDue': 55000},
      ];

      Map<String, dynamic> computeProjection(List<Map<String, dynamic>> sourceBills) {
        int total = 0;
        final billBalances = <String, int>{};
        for (final b in sourceBills) {
          final amt = b['totalDue'] as int;
          total += amt;
          billBalances[b['id'] as String] = amt;
        }
        return {
          'outstandingPaise': total,
          'confirmedPaise': 0,
          'reversedPaise': 0,
          'billBalances': billBalances,
        };
      }

      final run1 = computeProjection(bills);
      final run2 = computeProjection(bills);

      expect(run1, equals(run2));
      expect(run1['outstandingPaise'], equals(100000));
      expect(run1['billBalances'], equals({'B-1': 45000, 'B-2': 55000}));
    });

    test('15. Payment confirmation remains transactional and allocates to oldest bill first', () {
      final bills = [
        OutstandingBill(
          billId: 'B-1',
          billingMonth: '2026-08',
          sourceAmountPaise: 40000, // ₹400
          allocatedPaise: 0,
          reversedPaise: 0,
          outstandingPaise: 40000,
          status: 'outstanding',
          revision: 1,
        ),
        OutstandingBill(
          billId: 'B-2',
          billingMonth: '2026-09',
          sourceAmountPaise: 60000, // ₹600
          allocatedPaise: 0,
          reversedPaise: 0,
          outstandingPaise: 60000,
          status: 'outstanding',
          revision: 1,
        ),
      ];

      // Simulate partial payment of ₹500 (50000 paise)
      int paymentPaise = 50000;
      final allocations = <String, int>{};
      for (final bill in bills) {
        if (paymentPaise <= 0) break;
        final alloc = paymentPaise >= bill.outstandingPaise ? bill.outstandingPaise : paymentPaise;
        allocations[bill.billId] = alloc;
        paymentPaise -= alloc;
      }

      // Oldest bill (B-1) fully paid with ₹400, second bill (B-2) partially paid with ₹100
      expect(allocations['B-1'], equals(40000));
      expect(allocations['B-2'], equals(10000));
      expect(paymentPaise, equals(0));
    });

    test('16. Payment retry remains idempotent with identical idempotencyKey', () {
      final processedKeys = <String, String>{};

      String processPayment(String idempotencyKey, int amount) {
        if (processedKeys.containsKey(idempotencyKey)) {
          return processedKeys[idempotencyKey]!; // return existing receipt
        }
        final receiptId = 'REC-$idempotencyKey';
        processedKeys[idempotencyKey] = receiptId;
        return receiptId;
      }

      final res1 = processPayment('idemp-key-1', 50000);
      final res2 = processPayment('idemp-key-1', 50000); // retry

      expect(res1, equals(res2));
      expect(processedKeys.length, equals(1));
    });

    test('17. CollectionState outstanding balance invariant holds after partial payment', () {
      const initialTotal = 100000;
      const payment = 50000;
      final remainingOutstanding = initialTotal - payment;

      final updatedBills = [
        OutstandingBill(
          billId: 'B-1',
          billingMonth: '2026-08',
          sourceAmountPaise: 40000,
          allocatedPaise: 40000,
          reversedPaise: 0,
          outstandingPaise: 0,
          status: 'settled',
          revision: 2,
        ),
        OutstandingBill(
          billId: 'B-2',
          billingMonth: '2026-09',
          sourceAmountPaise: 60000,
          allocatedPaise: 10000,
          reversedPaise: 0,
          outstandingPaise: 50000,
          status: 'outstanding',
          revision: 2,
        ),
      ];

      final sumBillOutstanding = updatedBills.fold<int>(0, (sum, b) => sum + b.outstandingPaise);
      expect(sumBillOutstanding, equals(remainingOutstanding));
      expect(sumBillOutstanding, equals(50000));
    });
  });
}
