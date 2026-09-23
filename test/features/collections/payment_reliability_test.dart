import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/collections/domain/collection_repository.dart';
import 'package:paper_route/features/collections/presentation/collect_payment_page.dart';
import 'package:paper_route/features/collections/presentation/collections_providers.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/domain/customer_repository.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';

void main() {
  const employee = AppUser(
    uid: 'emp-001',
    email: 'emp@test.local',
    displayName: 'Collector Test',
    isEmailVerified: true,
    businessId: 'biz-test',
    role: UserRole.employee,
    status: AccountStatus.active,
    permissions: {PermissionKey.recordPayments},
    areaIds: {'route-1'},
  );

  const testCustomer = Customer(
    id: 'CUST-101',
    customerCode: 'CUST-101',
    businessId: 'biz-test',
    name: 'Ramesh Sharma',
    phone: '9876543210',
    areaId: 'route-1',
    assignedEmployeeId: 'emp-001',
    status: CustomerStatus.active,
    houseNumber: '101',
    address: 'Flat 101, Galaxy Apts',
    landmark: 'Near Clock Tower',
  );

  final defaultSummary = CustomerOutstandingSummary(
    businessId: 'biz-test',
    customerId: 'CUST-101',
    outstandingPaise: 10000,
    confirmedPaise: 0,
    reversedPaise: 0,
    bills: const [
      OutstandingBill(
        billId: '2026-09',
        billingMonth: '2026-09',
        sourceAmountPaise: 10000,
        allocatedPaise: 0,
        reversedPaise: 0,
        outstandingPaise: 10000,
        status: 'outstanding',
        revision: 0,
      ),
    ],
    revision: 1,
    serverConfirmed: true,
  );

  Widget createTestWidget({
    required CollectionsRepository collectionsRepo,
    required CustomerRepository customerRepo,
    void Function(PaymentConfirmationResult)? onConfirmed,
  }) {
    return ProviderScope(
      overrides: [
        collectionsRepositoryProvider.overrideWithValue(collectionsRepo),
        customerRepositoryProvider.overrideWithValue(customerRepo),
      ],
      child: MaterialApp(
        home: CollectPaymentPage(
          user: employee,
          customerId: 'CUST-101',
          onConfirmed: onConfirmed,
        ),
      ),
    );
  }

  void useTestViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1800);
    addTearDown(tester.view.reset);
  }

  group('Payment Reliability & Idempotency UX', () {
    testWidgets(
      'submitting a payment sends a non-empty unique operation key',
      (tester) async {
        useTestViewport(tester);
        final fakeRepo = _ReliableFakeCollectionsRepository(summary: defaultSummary);
        final fakeCustomerRepo = _FakeCustomerRepository(testCustomer);

        await tester.pumpWidget(
          createTestWidget(
            collectionsRepo: fakeRepo,
            customerRepo: fakeCustomerRepo,
          ),
        );
        await tester.pumpAndSettle();

        // Tap confirm payment button
        await tester.tap(find.byKey(const ValueKey('confirm-payment')));
        await tester.pumpAndSettle();

        // Confirm in dialog
        await tester.tap(find.byKey(const ValueKey('manual-receipt-confirmation')));
        await tester.pumpAndSettle();

        expect(fakeRepo.confirmCalls, hasLength(1));
        final call = fakeRepo.confirmCalls.single;
        expect(call.idempotencyKey, isNotNull);
        expect(call.idempotencyKey.isNotEmpty, isTrue);
      },
    );

    testWidgets(
      'network failure preserves operation ID for safe retry without duplicate creation',
      (tester) async {
        useTestViewport(tester);
        final fakeRepo = _ReliableFakeCollectionsRepository(
          summary: defaultSummary,
          shouldSimulateNetworkFailure: true,
        );
        final fakeCustomerRepo = _FakeCustomerRepository(testCustomer);

        await tester.pumpWidget(
          createTestWidget(
            collectionsRepo: fakeRepo,
            customerRepo: fakeCustomerRepo,
          ),
        );
        await tester.pumpAndSettle();

        // Trigger payment confirmation
        await tester.tap(find.byKey(const ValueKey('confirm-payment')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('manual-receipt-confirmation')));
        await tester.pumpAndSettle();

        // First attempt failed with network error
        expect(fakeRepo.confirmCalls, hasLength(1));
        final initialOpId = fakeRepo.confirmCalls[0].idempotencyKey;

        // Verify offline/network error banner is visible
        expect(
          find.textContaining('Payment confirmation unverified'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Payment confirmation could not be verified because the connection was interrupted'),
          findsOneWidget,
        );

        // Turn off network failure on fake repo so retry succeeds
        fakeRepo.shouldSimulateNetworkFailure = false;

        // Tap Retry confirmation button in the error banner
        final retryButton = find.byKey(const ValueKey('retry-payment-confirmation'));
        expect(retryButton, findsOneWidget);
        await tester.tap(retryButton);
        await tester.pumpAndSettle();

        // Confirm again in dialog
        await tester.tap(find.byKey(const ValueKey('manual-receipt-confirmation')));
        await tester.pumpAndSettle();

        // Check that retry was attempted with the EXACT SAME operation ID
        expect(fakeRepo.confirmCalls, hasLength(2));
        final retryOpId = fakeRepo.confirmCalls[1].idempotencyKey;
        expect(retryOpId, equals(initialOpId));
      },
    );

    testWidgets(
      'two legitimate same-amount payments on same day have distinct operation IDs',
      (tester) async {
        useTestViewport(tester);
        final fakeRepo = _ReliableFakeCollectionsRepository(summary: defaultSummary);
        final fakeCustomerRepo = _FakeCustomerRepository(testCustomer);

        // First payment
        await tester.pumpWidget(
          createTestWidget(
            collectionsRepo: fakeRepo,
            customerRepo: fakeCustomerRepo,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('confirm-payment')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('manual-receipt-confirmation')));
        await tester.pumpAndSettle();

        expect(fakeRepo.confirmCalls, hasLength(1));
        final opId1 = fakeRepo.confirmCalls[0].idempotencyKey;

        // Second payment (new form instance representing another legitimate collection)
        await tester.pumpWidget(
          createTestWidget(
            collectionsRepo: fakeRepo,
            customerRepo: fakeCustomerRepo,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('confirm-payment')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('manual-receipt-confirmation')));
        await tester.pumpAndSettle();

        expect(fakeRepo.confirmCalls, hasLength(2));
        final opId2 = fakeRepo.confirmCalls[1].idempotencyKey;

        // Both are for the same amount (10000 paise / ₹100)
        expect(fakeRepo.confirmCalls[0].amountPaise, equals(fakeRepo.confirmCalls[1].amountPaise));
        // But operation IDs MUST be different to avoid accidental deduplication
        expect(opId1, isNot(equals(opId2)));
      },
    );

    testWidgets(
      'double tapping confirm button does not trigger parallel confirmation dialogs',
      (tester) async {
        useTestViewport(tester);
        final fakeRepo = _ReliableFakeCollectionsRepository(summary: defaultSummary);
        final fakeCustomerRepo = _FakeCustomerRepository(testCustomer);

        await tester.pumpWidget(
          createTestWidget(
            collectionsRepo: fakeRepo,
            customerRepo: fakeCustomerRepo,
          ),
        );
        await tester.pumpAndSettle();

        // Rapid double tap on confirm button
        await tester.tap(find.byKey(const ValueKey('confirm-payment')));
        await tester.tap(find.byKey(const ValueKey('confirm-payment')), warnIfMissed: false);
        await tester.pumpAndSettle();

        // Only one confirmation dialog should be presented
        expect(find.text('Confirm receipt of payment?'), findsOneWidget);
      },
    );
  });

  group('Transactional Idempotency & Concurrency Invariants', () {
    test('two concurrent submissions with EXACT SAME operationId execute safely', () async {
      final ledger = _TransactionalLedger(initialBalancePaise: 20000);
      const input = PaymentConfirmationInput(
        idempotencyKey: 'op-concurrent-001',
        amountPaise: 10000,
        method: PaymentMethod.cash,
        externalReference: 'CASH-REC',
        notes: 'Monthly collection',
      );

      // Execute TWO concurrent submissions with the EXACT SAME operationId
      final results = await Future.wait([
        ledger.confirmPayment(actor: employee, customerId: 'CUST-101', input: input),
        ledger.confirmPayment(actor: employee, customerId: 'CUST-101', input: input),
      ]);

      // INVARIANT 1: exactly one payment exists in the ledger
      expect(ledger.payments.length, equals(1));
      expect(ledger.payments.containsKey('op-concurrent-001'), isTrue);

      // INVARIANT 2: customer balance changed exactly once (20000 - 10000 = 10000, not 0)
      expect(ledger.customerBalancePaise, equals(10000));

      // INVARIANT 3: second request resolves to the existing result
      expect(results[0].payment.id, equals('PAY-op-concurrent-001'));
      expect(results[1].payment.id, equals('PAY-op-concurrent-001'));
      expect(results[0].payment.amountPaise, equals(10000));
      expect(results[1].payment.amountPaise, equals(10000));
      expect(results[0].remainingOutstandingPaise, equals(10000));
      expect(results[1].remainingOutstandingPaise, equals(10000));

      // INVARIANT 4: exactly one audit record created (no duplicate audit/ledger effects)
      expect(ledger.auditRecords.length, equals(1));
      expect(ledger.auditRecords.single['action'], equals('paymentConfirmed'));
      expect(ledger.auditRecords.single['entityId'], equals('op-concurrent-001'));
    });

    test('same customer/date/amount with TWO DIFFERENT operationIds succeeds twice', () async {
      final ledger = _TransactionalLedger(initialBalancePaise: 20000);

      const input1 = PaymentConfirmationInput(
        idempotencyKey: 'op-legit-001',
        amountPaise: 10000,
        method: PaymentMethod.cash,
        externalReference: 'CASH-MORNING',
        notes: 'Morning payment',
      );

      const input2 = PaymentConfirmationInput(
        idempotencyKey: 'op-legit-002',
        amountPaise: 10000,
        method: PaymentMethod.cash,
        externalReference: 'CASH-EVENING',
        notes: 'Evening payment',
      );

      // Both payments submitted for same customer, same date, same amount
      final res1 = await ledger.confirmPayment(actor: employee, customerId: 'CUST-101', input: input1);
      final res2 = await ledger.confirmPayment(actor: employee, customerId: 'CUST-101', input: input2);

      // INVARIANT: both payments recorded separately
      expect(ledger.payments.length, equals(2));
      expect(res1.payment.id, equals('PAY-op-legit-001'));
      expect(res2.payment.id, equals('PAY-op-legit-002'));

      // Balance reduced twice (20000 -> 10000 -> 0)
      expect(res1.remainingOutstandingPaise, equals(10000));
      expect(res2.remainingOutstandingPaise, equals(0));
      expect(ledger.customerBalancePaise, equals(0));

      // Two distinct audit records
      expect(ledger.auditRecords.length, equals(2));
    });

    test('reusing same operationId with different details is rejected as idempotency conflict', () async {
      final ledger = _TransactionalLedger(initialBalancePaise: 20000);
      const input = PaymentConfirmationInput(
        idempotencyKey: 'op-conflict-001',
        amountPaise: 10000,
        method: PaymentMethod.cash,
      );

      await ledger.confirmPayment(actor: employee, customerId: 'CUST-101', input: input);

      // Attempt to reuse same key with different amount (15000 instead of 10000)
      const conflictingInput = PaymentConfirmationInput(
        idempotencyKey: 'op-conflict-001',
        amountPaise: 15000,
        method: PaymentMethod.cash,
      );

      expect(
        () => ledger.confirmPayment(actor: employee, customerId: 'CUST-101', input: conflictingInput),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

class _TransactionalLedger {
  _TransactionalLedger({required int initialBalancePaise})
      : customerBalancePaise = initialBalancePaise;

  int customerBalancePaise;
  final Map<String, ConfirmedPayment> payments = {};
  final List<Map<String, dynamic>> auditRecords = [];
  final List<Future<void>> _locks = [];

  Future<PaymentConfirmationResult> confirmPayment({
    required AppUser actor,
    required String customerId,
    required PaymentConfirmationInput input,
  }) async {
    // Artificial small delay to test concurrency
    await Future<void>.delayed(const Duration(milliseconds: 5));

    // Simulate serialized atomic transaction block on payment document
    final previousLock = _locks.isNotEmpty ? _locks.last : Future<void>.value();
    final completer = Completer<void>();
    _locks.add(completer.future);

    await previousLock;
    try {
      final existing = payments[input.idempotencyKey];
      if (existing != null) {
        if (existing.amountPaise != input.amountPaise ||
            existing.method != input.method ||
            existing.collectorUid != actor.uid) {
          throw const FormatException(
            'This payment retry key was already used for different details.',
          );
        }
        return PaymentConfirmationResult(
          payment: existing,
          remainingOutstandingPaise: customerBalancePaise,
          serverConfirmed: true,
        );
      }

      final nextBalance = customerBalancePaise - input.amountPaise;
      customerBalancePaise = nextBalance;

      final payment = ConfirmedPayment(
        id: 'PAY-${input.idempotencyKey}',
        businessId: actor.businessId!,
        customerId: customerId,
        customerCode: 'CUST-101',
        customerName: 'Ramesh Sharma',
        amountPaise: input.amountPaise,
        method: input.method,
        status: ConfirmedPaymentStatus.confirmed,
        externalReference: input.externalReference,
        notes: input.notes,
        collectorUid: actor.uid,
        allocations: [
          BillAllocation(
            billId: '2026-09',
            billingMonth: '2026-09',
            amountPaise: input.amountPaise,
          ),
        ],
        reversedPaise: 0,
        lastAuditId: 'audit-${input.idempotencyKey}',
        serverConfirmed: true,
        confirmedAt: DateTime.utc(2026, 9, 23, 10, 0),
      );

      payments[input.idempotencyKey] = payment;
      auditRecords.add({
        'action': 'paymentConfirmed',
        'entityId': input.idempotencyKey,
        'actorId': actor.uid,
        'amountPaise': input.amountPaise,
      });

      return PaymentConfirmationResult(
        payment: payment,
        remainingOutstandingPaise: nextBalance,
        serverConfirmed: true,
      );
    } finally {
      completer.complete();
    }
  }
}

class _FakeCustomerRepository implements CustomerRepository {
  const _FakeCustomerRepository(this.customer);
  final Customer customer;

  @override
  Stream<Customer?> watchCustomer({
    required String businessId,
    required String customerId,
  }) => Stream.value(customer);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReliableFakeCollectionsRepository implements CollectionsRepository {
  _ReliableFakeCollectionsRepository({
    required this.summary,
    this.shouldSimulateNetworkFailure = false,
  });

  final CustomerOutstandingSummary summary;
  bool shouldSimulateNetworkFailure;
  final confirmCalls = <PaymentConfirmationInput>[];

  @override
  Stream<CustomerOutstandingSummary> watchCustomerOutstanding({
    required String businessId,
    required String customerId,
  }) => Stream.value(summary);

  @override
  Future<CustomerOutstandingSummary> fetchCustomerOutstanding({
    required AppUser actor,
    required String customerId,
  }) async => summary;

  @override
  Future<PaymentConfirmationResult> confirmPayment({
    required AppUser actor,
    required String customerId,
    required PaymentConfirmationInput input,
  }) async {
    confirmCalls.add(input);
    if (shouldSimulateNetworkFailure) {
      throw const FormatException(
        'Server confirmation could not be verified due to network timeout. Please retry.',
      );
    }
    return PaymentConfirmationResult(
      payment: ConfirmedPayment(
        id: 'PAY-${input.idempotencyKey}',
        businessId: actor.businessId!,
        customerId: customerId,
        customerCode: 'CUST-101',
        customerName: 'Ramesh Sharma',
        amountPaise: input.amountPaise,
        method: input.method,
        status: ConfirmedPaymentStatus.confirmed,
        externalReference: input.externalReference,
        notes: input.notes,
        collectorUid: actor.uid,
        allocations: const [
          BillAllocation(
            billId: '2026-09',
            billingMonth: '2026-09',
            amountPaise: 10000,
          ),
        ],
        reversedPaise: 0,
        lastAuditId: 'audit-001',
        serverConfirmed: true,
        confirmedAt: DateTime.utc(2026, 9, 22, 10, 0),
      ),
      remainingOutstandingPaise: summary.outstandingPaise - input.amountPaise,
      serverConfirmed: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
