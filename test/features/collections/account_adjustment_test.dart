import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/collections/domain/collection_repository.dart';
import 'package:paper_route/features/collections/presentation/adjust_outstanding_page.dart';
import 'package:paper_route/features/collections/presentation/collect_payment_page.dart';
import 'package:paper_route/features/collections/presentation/collections_providers.dart';
import 'package:paper_route/features/collections/presentation/customer_collection_summary.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/domain/customer_repository.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';

void main() {
  const head = AppUser(
    uid: 'head-a',
    email: 'head@example.test',
    displayName: 'Head',
    isEmailVerified: true,
    businessId: 'business-a',
    role: UserRole.head,
    status: AccountStatus.active,
  );

  const employee = AppUser(
    uid: 'employee-a',
    email: 'employee@example.test',
    displayName: 'Employee',
    isEmailVerified: true,
    businessId: 'business-a',
    role: UserRole.employee,
    status: AccountStatus.active,
    permissions: {
      PermissionKey.allowIncreaseOutstanding,
      PermissionKey.allowDecreaseOutstanding,
      PermissionKey.recordPayments,
    },
    areaIds: {'east'},
  );

  const customer = Customer(
    id: 'C-001',
    businessId: 'business-a',
    customerCode: 'C-001',
    name: 'Test Customer',
    phone: '9876543210',
    areaId: 'east',
    assignedEmployeeId: 'employee-a',
    status: CustomerStatus.active,
    address: '123 Market Road',
    landmark: 'Clock Tower',
  );

  group('Account Adjustment Domain & Policy Tests', () {
    test('increase and decrease permissions are independent and scoped', () {
      const policy = AccessPolicy();

      expect(
        policy.canIncreaseOutstanding(
          member: head,
          customerBusinessId: customer.businessId,
          assignedEmployeeId: customer.assignedEmployeeId,
          customerAreaId: customer.areaId,
          isCustomerArchived: false,
        ),
        isTrue,
      );
      expect(
        policy.canDecreaseOutstanding(
          member: employee,
          customerBusinessId: customer.businessId,
          assignedEmployeeId: customer.assignedEmployeeId,
          customerAreaId: customer.areaId,
          isCustomerArchived: false,
        ),
        isTrue,
      );

      final increaseOnlyEmployee = AppUser(
        uid: 'employee-a',
        email: 'employee@example.test',
        displayName: 'Employee',
        isEmailVerified: true,
        businessId: 'business-a',
        role: UserRole.employee,
        status: AccountStatus.active,
        permissions: {PermissionKey.allowIncreaseOutstanding},
        areaIds: {'east'},
      );
      expect(
        policy.canIncreaseOutstanding(
          member: increaseOnlyEmployee,
          customerBusinessId: customer.businessId,
          assignedEmployeeId: customer.assignedEmployeeId,
          customerAreaId: customer.areaId,
          isCustomerArchived: false,
        ),
        isTrue,
      );
      expect(
        policy.canDecreaseOutstanding(
          member: increaseOnlyEmployee,
          customerBusinessId: customer.businessId,
          assignedEmployeeId: customer.assignedEmployeeId,
          customerAreaId: customer.areaId,
          isCustomerArchived: false,
        ),
        isFalse,
      );

      final otherEmployee = AppUser(
        uid: 'employee-b',
        email: 'employeeb@example.test',
        displayName: 'Employee B',
        isEmailVerified: true,
        businessId: 'business-a',
        role: UserRole.employee,
        status: AccountStatus.active,
        permissions: {
          PermissionKey.allowIncreaseOutstanding,
          PermissionKey.allowDecreaseOutstanding,
        },
        areaIds: {'west'},
      );
      expect(
        policy.canIncreaseOutstanding(
          member: otherEmployee,
          customerBusinessId: customer.businessId,
          assignedEmployeeId: customer.assignedEmployeeId,
          customerAreaId: customer.areaId,
          isCustomerArchived: false,
        ),
        isFalse,
      );
      expect(
        policy.canDecreaseOutstanding(
          member: otherEmployee,
          customerBusinessId: customer.businessId,
          assignedEmployeeId: customer.assignedEmployeeId,
          customerAreaId: customer.areaId,
          isCustomerArchived: false,
        ),
        isFalse,
      );
    });

    test('AccountAdjustmentInput validation enforces rules', () {
      // Valid input
      const valid = AccountAdjustmentInput(
        amountPaise: 50000,
        direction: AdjustmentDirection.increase,
        reason: 'Past due ledger balance',
        idempotencyKey: 'adj-uuid-1234',
        billingMonth: '2026-09',
      );
      expect(() => valid.validate(), returnsNormally);

      // Non-positive amount
      const zeroAmount = AccountAdjustmentInput(
        amountPaise: 0,
        direction: AdjustmentDirection.increase,
        reason: 'Valid reason',
        idempotencyKey: 'adj-uuid-1234',
      );
      expect(() => zeroAmount.validate(), throwsA(isA<AppException>()));

      // Negative amount
      const negativeAmount = AccountAdjustmentInput(
        amountPaise: -500,
        direction: AdjustmentDirection.increase,
        reason: 'Valid reason',
        idempotencyKey: 'adj-uuid-1234',
      );
      expect(() => negativeAmount.validate(), throwsA(isA<AppException>()));

      // Reason too short
      const shortReason = AccountAdjustmentInput(
        amountPaise: 1000,
        direction: AdjustmentDirection.increase,
        reason: 'ab',
        idempotencyKey: 'adj-uuid-1234',
      );
      expect(() => shortReason.validate(), throwsA(isA<AppException>()));

      // Missing idempotency key
      const emptyKey = AccountAdjustmentInput(
        amountPaise: 1000,
        direction: AdjustmentDirection.increase,
        reason: 'Valid reason',
        idempotencyKey: '',
      );
      expect(() => emptyKey.validate(), throwsA(isA<AppException>()));

      const invalidMonth = AccountAdjustmentInput(
        amountPaise: 1000,
        direction: AdjustmentDirection.increase,
        reason: 'Valid reason',
        idempotencyKey: 'adj-uuid-1234',
        billingMonth: '2026-13',
      );
      expect(() => invalidMonth.validate(), throwsA(isA<AppException>()));
    });
  });

  group('Account Adjustment UI Workflow Tests', () {
    testWidgets(
      'A. ZERO -> INCREASE: Customer Details opens adjustment workflow at zero and records ₹100 increase',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1200, 1800);
        addTearDown(tester.view.reset);

        final zeroSummary = CustomerOutstandingSummary(
          businessId: 'business-a',
          customerId: 'C-001',
          outstandingPaise: 0,
          confirmedPaise: 0,
          reversedPaise: 0,
          bills: const [],
          revision: 1,
          serverConfirmed: true,
          requiresProjectionSetup: false,
        );
        final collections = _MockCollectionsRepository(summary: zeroSummary);
        final router = GoRouter(
          initialLocation: '/customers/C-001',
          routes: [
            GoRoute(
              path: '/customers/C-001',
              builder:
                  (context, state) => Scaffold(
                    body: CustomerCollectionSummary(
                      user: employee,
                      customer: customer,
                    ),
                  ),
            ),
            GoRoute(
              path: '/customers/:customerId/adjust-outstanding',
              builder:
                  (context, state) => AdjustOutstandingPage(
                    user: employee,
                    customerId: state.pathParameters['customerId']!,
                  ),
            ),
          ],
        );
        addTearDown(router.dispose);
        const customerKey = (businessId: 'business-a', customerId: 'C-001');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              collectionsRepositoryProvider.overrideWithValue(collections),
              customerProvider(
                customerKey,
              ).overrideWith((ref) => Stream.value(customer)),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('open-outstanding-adjustment')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Adjust outstanding'), findsOneWidget);
        expect(find.text('Adjustment amount (₹)'), findsOneWidget);
        expect(find.text('Amount received (₹)'), findsNothing);

        await tester.enterText(
          find.byKey(const ValueKey('adjustment-amount')),
          '100',
        );
        await tester.enterText(
          find.byKey(const ValueKey('adjustment-reason')),
          'Prior unbilled balance',
        );
        await tester.pumpAndSettle();

        expect(find.text('Current outstanding: ₹0.00'), findsOneWidget);
        expect(find.text('Adjustment: +₹100.00'), findsOneWidget);
        expect(find.text('₹100.00'), findsWidgets);

        await tester.tap(find.byKey(const ValueKey('submit-adjustment')));
        await tester.pumpAndSettle();

        expect(collections.adjustmentCalls, hasLength(1));
        expect(collections.adjustmentCalls.single.amountPaise, 10000);
        expect(
          collections.adjustmentCalls.single.direction,
          AdjustmentDirection.increase,
        );
      },
    );

    testWidgets('B. ₹1,000 -> ₹1,010: Increase adjustment of ₹10', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 1800);
      addTearDown(tester.view.reset);

      final summary = CustomerOutstandingSummary(
        businessId: 'business-a',
        customerId: 'C-001',
        outstandingPaise: 100000,
        confirmedPaise: 100000,
        reversedPaise: 0,
        bills: const [],
        revision: 1,
        serverConfirmed: true,
        requiresProjectionSetup: false,
      );
      final collections = _MockCollectionsRepository(summary: summary);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionsRepositoryProvider.overrideWithValue(collections),
            customerRepositoryProvider.overrideWithValue(
              const _MockCustomerRepository(customer),
            ),
          ],
          child: const MaterialApp(
            home: AdjustOutstandingPage(user: employee, customerId: 'C-001'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('adjustment-amount')),
        '10',
      );
      await tester.enterText(
        find.byKey(const ValueKey('adjustment-reason')),
        'Manual rate correction',
      );
      await tester.pumpAndSettle();

      expect(find.text('Current outstanding: ₹1,000.00'), findsOneWidget);
      expect(find.text('Adjustment: +₹10.00'), findsOneWidget);
      expect(find.text('₹1,010.00'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('submit-adjustment')));
      await tester.pumpAndSettle();

      expect(collections.adjustmentCalls, hasLength(1));
      expect(collections.adjustmentCalls.single.amountPaise, 1000);
      expect(
        collections.adjustmentCalls.single.direction,
        AdjustmentDirection.increase,
      );
    });

    testWidgets(
      'C & D. ₹1,000 -> ₹2,000: Increase adjustment of ₹1,000 has NO upper bound',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1200, 1800);
        addTearDown(tester.view.reset);

        final summary = CustomerOutstandingSummary(
          businessId: 'business-a',
          customerId: 'C-001',
          outstandingPaise: 100000,
          confirmedPaise: 100000,
          reversedPaise: 0,
          bills: const [],
          revision: 1,
          serverConfirmed: true,
          requiresProjectionSetup: false,
        );
        final collections = _MockCollectionsRepository(summary: summary);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              collectionsRepositoryProvider.overrideWithValue(collections),
              customerRepositoryProvider.overrideWithValue(
                const _MockCustomerRepository(customer),
              ),
            ],
            child: const MaterialApp(
              home: AdjustOutstandingPage(user: employee, customerId: 'C-001'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('adjustment-amount')),
          '1000',
        );
        await tester.enterText(
          find.byKey(const ValueKey('adjustment-reason')),
          'Additional arrear billing',
        );
        await tester.pumpAndSettle();

        expect(find.text('Current outstanding: ₹1,000.00'), findsOneWidget);
        expect(find.text('Adjustment: +₹1,000.00'), findsOneWidget);
        expect(find.text('₹2,000.00'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('submit-adjustment')));
        await tester.pumpAndSettle();

        expect(find.text('Amount cannot exceed the current outstanding'), findsNothing);
        expect(collections.adjustmentCalls, hasLength(1));
        expect(collections.adjustmentCalls.single.amountPaise, 100000);
        expect(
          collections.adjustmentCalls.single.direction,
          AdjustmentDirection.increase,
        );
      },
    );

    testWidgets('E. DECREASE: ₹1,000 - ₹10 = ₹990', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 1800);
      addTearDown(tester.view.reset);

      final summary = CustomerOutstandingSummary(
        businessId: 'business-a',
        customerId: 'C-001',
        outstandingPaise: 100000,
        confirmedPaise: 100000,
        reversedPaise: 0,
        bills: const [],
        revision: 1,
        serverConfirmed: true,
        requiresProjectionSetup: false,
      );
      final collections = _MockCollectionsRepository(summary: summary);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionsRepositoryProvider.overrideWithValue(collections),
            customerRepositoryProvider.overrideWithValue(
              const _MockCustomerRepository(customer),
            ),
          ],
          child: const MaterialApp(
            home: AdjustOutstandingPage(user: employee, customerId: 'C-001'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Decrease'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('adjustment-amount')),
        '10',
      );
      await tester.enterText(
        find.byKey(const ValueKey('adjustment-reason')),
        'Waiver of charge',
      );
      await tester.pumpAndSettle();

      expect(find.text('Current outstanding: ₹1,000.00'), findsOneWidget);
      expect(find.text('Adjustment: -₹10.00'), findsOneWidget);
      expect(find.text('₹990.00'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('submit-adjustment')));
      await tester.pumpAndSettle();

      expect(collections.adjustmentCalls, hasLength(1));
      expect(collections.adjustmentCalls.single.amountPaise, 1000);
      expect(
        collections.adjustmentCalls.single.direction,
        AdjustmentDirection.decrease,
      );
    });

    testWidgets(
      'F. DECREASE OVER BALANCE: ₹1,000 - ₹1,001 must be rejected',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1200, 1800);
        addTearDown(tester.view.reset);

        final summary = CustomerOutstandingSummary(
          businessId: 'business-a',
          customerId: 'C-001',
          outstandingPaise: 100000,
          confirmedPaise: 100000,
          reversedPaise: 0,
          bills: const [],
          revision: 1,
          serverConfirmed: true,
          requiresProjectionSetup: false,
        );
        final collections = _MockCollectionsRepository(summary: summary);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              collectionsRepositoryProvider.overrideWithValue(collections),
              customerRepositoryProvider.overrideWithValue(
                const _MockCustomerRepository(customer),
              ),
            ],
            child: const MaterialApp(
              home: AdjustOutstandingPage(user: employee, customerId: 'C-001'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Decrease'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('adjustment-amount')),
          '1001',
        );
        await tester.enterText(
          find.byKey(const ValueKey('adjustment-reason')),
          'Excess waiver',
        );
        await tester.tap(find.byKey(const ValueKey('submit-adjustment')));
        await tester.pumpAndSettle();

        expect(
          find.text('Decrease amount cannot exceed current outstanding.'),
          findsOneWidget,
        );
        expect(collections.adjustmentCalls, isEmpty);
      },
    );

    testWidgets('G. ZERO DECREASE: Decrease unavailable at zero balance', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 1800);
      addTearDown(tester.view.reset);

      const decreaseOnlyEmployee = AppUser(
        uid: 'employee-a',
        email: 'employee@example.test',
        displayName: 'Employee',
        isEmailVerified: true,
        businessId: 'business-a',
        role: UserRole.employee,
        status: AccountStatus.active,
        permissions: {PermissionKey.allowDecreaseOutstanding},
        areaIds: {'east'},
      );
      final zeroSummary = CustomerOutstandingSummary(
        businessId: 'business-a',
        customerId: 'C-001',
        outstandingPaise: 0,
        confirmedPaise: 0,
        reversedPaise: 0,
        bills: const [],
        revision: 1,
        serverConfirmed: true,
        requiresProjectionSetup: false,
      );
      final collections = _MockCollectionsRepository(summary: zeroSummary);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionsRepositoryProvider.overrideWithValue(collections),
            customerRepositoryProvider.overrideWithValue(
              const _MockCustomerRepository(customer),
            ),
          ],
          child: const MaterialApp(
            home: AdjustOutstandingPage(
              user: decreaseOnlyEmployee,
              customerId: 'C-001',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('There is no outstanding balance to decrease.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('submit-adjustment')), findsNothing);
      expect(collections.adjustmentCalls, isEmpty);
    });

    testWidgets(
      'H. PAYMENT REGRESSION: Collect Payment overcollection (₹1,000 collectible, payment ₹1,010) is rejected',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1200, 1800);
        addTearDown(tester.view.reset);

        final summary = CustomerOutstandingSummary(
          businessId: 'business-a',
          customerId: 'C-001',
          outstandingPaise: 100000,
          confirmedPaise: 100000,
          reversedPaise: 0,
          bills: const [],
          revision: 1,
          serverConfirmed: true,
          requiresProjectionSetup: false,
        );
        final collections = _MockCollectionsRepository(summary: summary);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              collectionsRepositoryProvider.overrideWithValue(collections),
              customerRepositoryProvider.overrideWithValue(
                const _MockCustomerRepository(customer),
              ),
            ],
            child: const MaterialApp(
              home: CollectPaymentPage(user: employee, customerId: 'C-001'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Amount received (₹)'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('collection-amount')),
          '1010',
        );
        await tester.tap(find.byKey(const ValueKey('confirm-payment')));
        await tester.pumpAndSettle();

        expect(
          find.text('Amount cannot exceed the current outstanding.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'I. PAYMENT QR REGRESSION: Adjust Outstanding does NOT render payment controls or UPI QR',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1200, 1800);
        addTearDown(tester.view.reset);

        final summary = CustomerOutstandingSummary(
          businessId: 'business-a',
          customerId: 'C-001',
          outstandingPaise: 100000,
          confirmedPaise: 100000,
          reversedPaise: 0,
          bills: const [],
          revision: 1,
          serverConfirmed: true,
          requiresProjectionSetup: false,
        );
        final collections = _MockCollectionsRepository(summary: summary);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              collectionsRepositoryProvider.overrideWithValue(collections),
              customerRepositoryProvider.overrideWithValue(
                const _MockCustomerRepository(customer),
              ),
            ],
            child: const MaterialApp(
              home: AdjustOutstandingPage(user: employee, customerId: 'C-001'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Amount received (₹)'), findsNothing);
        expect(find.text('Payment method'), findsNothing);
        expect(find.text('UPI transaction / receipt reference'), findsNothing);
        expect(find.byKey(const ValueKey('generate-upi-request')), findsNothing);
        expect(find.textContaining('Collector-confirmed'), findsNothing);
      },
    );

    testWidgets(
      'J. PERMISSION REGRESSION: Employee without allowIncreaseOutstanding cannot choose Increase',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1200, 1800);
        addTearDown(tester.view.reset);

        const decreaseOnlyEmployee = AppUser(
          uid: 'employee-a',
          email: 'employee@example.test',
          displayName: 'Employee',
          isEmailVerified: true,
          businessId: 'business-a',
          role: UserRole.employee,
          status: AccountStatus.active,
          permissions: {PermissionKey.allowDecreaseOutstanding},
          areaIds: {'east'},
        );
        final summary = CustomerOutstandingSummary(
          businessId: 'business-a',
          customerId: 'C-001',
          outstandingPaise: 100000,
          confirmedPaise: 100000,
          reversedPaise: 0,
          bills: const [],
          revision: 1,
          serverConfirmed: true,
          requiresProjectionSetup: false,
        );
        final collections = _MockCollectionsRepository(summary: summary);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              collectionsRepositoryProvider.overrideWithValue(collections),
              customerRepositoryProvider.overrideWithValue(
                const _MockCustomerRepository(customer),
              ),
            ],
            child: const MaterialApp(
              home: AdjustOutstandingPage(
                user: decreaseOnlyEmployee,
                customerId: 'C-001',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Decrease'), findsOneWidget);
        expect(find.text('Increase'), findsNothing);
      },
    );
  });
}

class _MockCustomerRepository implements CustomerRepository {
  const _MockCustomerRepository(this.customer);

  final Customer customer;

  @override
  Stream<Customer?> watchCustomer({
    required String businessId,
    required String customerId,
  }) => Stream.value(customer);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCollectionsRepository implements CollectionsRepository {
  _MockCollectionsRepository({required this.summary});

  final CustomerOutstandingSummary summary;
  final adjustmentCalls = <AccountAdjustmentInput>[];

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
  Future<AccountAdjustmentResult> recordAccountAdjustment({
    required AppUser actor,
    required String customerId,
    required AccountAdjustmentInput input,
  }) async {
    adjustmentCalls.add(input);
    return AccountAdjustmentResult(
      adjustment: AccountAdjustment(
        id: input.idempotencyKey,
        businessId: actor.businessId ?? 'business-a',
        customerId: customerId,
        billingMonth: input.billingMonth,
        amountPaise: input.amountPaise,
        direction: input.direction,
        reason: input.reason,
        actorUid: actor.uid,
        actorRole: actor.role?.name ?? 'unknown',
        createdAt: DateTime.now(),
        lastAuditId: 'adj-audit',
      ),
      newOutstandingPaise:
          input.direction == AdjustmentDirection.increase
              ? summary.outstandingPaise + input.amountPaise
              : summary.outstandingPaise - input.amountPaise,
      serverConfirmed: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
