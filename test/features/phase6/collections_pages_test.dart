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
import 'package:paper_route/features/collections/presentation/collections_workspace_page.dart';
import 'package:paper_route/features/collections/presentation/payment_receipt_page.dart';
import 'package:paper_route/features/collections/presentation/upi_settings_page.dart';
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
    permissions: {PermissionKey.recordPayments},
    areaIds: {'east'},
  );

  testWidgets('cash confirmation is explicit and produces one server receipt', (
    tester,
  ) async {
    _useLargeTestView(tester);
    final collections = _FakeCollectionsRepository();
    PaymentConfirmationResult? confirmed;
    await tester.pumpWidget(
      _app(
        collections,
        const _FakeCustomerRepository(_customer),
        CollectPaymentPage(
          user: employee,
          customerId: 'C-001',
          onConfirmed: (result) => confirmed = result,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Synthetic Customer'), findsOneWidget);
    expect(find.textContaining('Near Clock Tower'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('collection-outstanding')),
      findsOneWidget,
    );
    expect(collections.confirmCalls, isEmpty);

    await tester.tap(find.byKey(const ValueKey('confirm-payment')));
    await tester.pumpAndSettle();
    expect(find.text('Confirm receipt of payment?'), findsOneWidget);
    expect(collections.confirmCalls, isEmpty);

    await tester.tap(find.byKey(const ValueKey('manual-receipt-confirmation')));
    await tester.pumpAndSettle();

    expect(collections.confirmCalls, hasLength(1));
    expect(collections.confirmCalls.single.method, PaymentMethod.cash);
    expect(collections.confirmCalls.single.amountPaise, 10000);
    expect(confirmed?.serverConfirmed, isTrue);
  });

  testWidgets('UPI QR remains a request until manual confirmation', (
    tester,
  ) async {
    _useLargeTestView(tester);
    final collections = _FakeCollectionsRepository();
    await tester.pumpWidget(
      _app(
        collections,
        const _FakeCustomerRepository(_customer),
        const CollectPaymentPage(user: employee, customerId: 'C-001'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('collection-method')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UPI').last);
    await tester.pumpAndSettle();

    final confirmBeforeQr = tester.widget<FilledButton>(
      find.byKey(const ValueKey('confirm-payment')),
    );
    expect(confirmBeforeQr.onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('generate-upi-request')));
    await tester.pumpAndSettle();

    expect(find.text('Payment requested — not confirmed'), findsOneWidget);
    expect(find.byKey(const ValueKey('upi-payment-qr')), findsOneWidget);
    expect(collections.confirmCalls, isEmpty);

    await tester.tap(find.byKey(const ValueKey('confirm-payment')));
    await tester.pumpAndSettle();
    expect(collections.confirmCalls, isEmpty);
    await tester.tap(find.byKey(const ValueKey('manual-receipt-confirmation')));
    await tester.pumpAndSettle();

    expect(collections.confirmCalls, hasLength(1));
    expect(collections.confirmCalls.single.method, PaymentMethod.upi);
    expect(
      collections.confirmCalls.single.externalReference,
      startsWith('PAPERROUTE-C-001-'),
    );
  });

  testWidgets('legacy or locally pending balances cannot be collected', (
    tester,
  ) async {
    _useLargeTestView(tester);
    final collections = _FakeCollectionsRepository(
      summary: _summary(serverConfirmed: false, requiresProjectionSetup: true),
    );
    await tester.pumpWidget(
      _app(
        collections,
        const _FakeCustomerRepository(_customer),
        const CollectPaymentPage(user: head, customerId: 'C-001'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('collection-projection-required')),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('confirm-payment')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('receipt shows immutable allocations and Head-only reversal', (
    tester,
  ) async {
    _useLargeTestView(tester);
    final collections = _FakeCollectionsRepository();
    PaymentReversalResult? reversed;
    await tester.pumpWidget(
      _app(
        collections,
        const _FakeCustomerRepository(_customer),
        PaymentReceiptPage(
          user: head,
          customerId: 'C-001',
          paymentId: 'payment-1',
          onReversed: (result) => reversed = result,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Server-confirmed ledger entry'), findsOneWidget);
    expect(find.text('2026-09'), findsOneWidget);
    expect(find.byKey(const ValueKey('reverse-payment')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reverse-payment')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('reversal-amount')),
      '10.00',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reversal-reason')),
      'Synthetic correction',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-reversal')));
    await tester.pumpAndSettle();

    expect(collections.reverseCalls, hasLength(1));
    expect(collections.reverseCalls.single.amountPaise, 1000);
    expect(reversed?.paymentStatus, ConfirmedPaymentStatus.partiallyReversed);
  });

  testWidgets('employee receipt cannot expose reversal action', (tester) async {
    _useLargeTestView(tester);
    final collections = _FakeCollectionsRepository();
    await tester.pumpWidget(
      _app(
        collections,
        const _FakeCustomerRepository(_customer),
        const PaymentReceiptPage(
          user: employee,
          customerId: 'C-001',
          paymentId: 'payment-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reverse-payment')), findsNothing);
  });

  testWidgets('Head saves normalized UPI settings and employee is blocked', (
    tester,
  ) async {
    _useLargeTestView(tester);
    final collections = _FakeCollectionsRepository(
      upiSettings: UpiSettings.empty('business-a'),
    );
    UpiSettingsInput? saved;
    await tester.pumpWidget(
      _app(
        collections,
        const _FakeCustomerRepository(_customer),
        UpiSettingsPage(user: head, onSaved: (value) => saved = value),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('upi-id')),
      'Paper.Route@Bank',
    );
    await tester.enterText(
      find.byKey(const ValueKey('upi-payee-name')),
      'Paper Route Test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('upi-reference-prefix')),
      'test_pay',
    );
    await tester.tap(find.byKey(const ValueKey('upi-enabled')));
    await tester.tap(find.byKey(const ValueKey('save-upi-settings')));
    await tester.pumpAndSettle();

    expect(collections.upiUpdates, hasLength(1));
    expect(saved?.upiId, 'paper.route@bank');
    expect(saved?.referencePrefix, 'TEST_PAY');
    expect(saved?.enabled, isTrue);

    await tester.pumpWidget(
      _app(
        collections,
        const _FakeCustomerRepository(_customer),
        const UpiSettingsPage(user: employee),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Head access required'), findsOneWidget);
    expect(find.byKey(const ValueKey('save-upi-settings')), findsNothing);
  });

  testWidgets('payment history is empty-aware and cursor paginated', (
    tester,
  ) async {
    _useLargeTestView(tester);
    final collections = _FakeCollectionsRepository(
      historyPages: [
        PaymentHistoryPage(
          items: [_payment(id: 'payment-1')],
          nextCursor: PaymentHistoryCursor(
            confirmedAt: _confirmedDate,
            documentPath:
                'businesses/business-a/customers/C-001/payments/payment-1',
          ),
          hasMore: true,
        ),
        PaymentHistoryPage(
          items: [_payment(id: 'payment-2')],
          nextCursor: null,
          hasMore: false,
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        collections,
        const _FakeCustomerRepository(_customer),
        const CollectionsWorkspacePage(user: head),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('payment-payment-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('load-more-payments')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('payment-payment-2')), findsOneWidget);
    expect(collections.historyCursors, hasLength(2));
    expect(collections.historyCursors.first, isNull);
    expect(
      collections.historyCursors.last?.documentPath,
      endsWith('payment-1'),
    );
  });
}

final _confirmedDate = DateTime.utc(2026, 9, 30, 12);

const _customer = Customer(
  id: 'C-001',
  customerCode: 'C-001',
  businessId: 'business-a',
  name: 'Synthetic Customer',
  phone: '9000000000',
  areaId: 'east',
  assignedEmployeeId: 'employee-a',
  status: CustomerStatus.active,
  houseNumber: '1',
  address: 'Synthetic Street',
  landmark: 'Clock Tower',
);

CustomerOutstandingSummary _summary({
  bool serverConfirmed = true,
  bool requiresProjectionSetup = false,
}) => CustomerOutstandingSummary(
  businessId: 'business-a',
  customerId: 'C-001',
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
  serverConfirmed: serverConfirmed,
  requiresProjectionSetup: requiresProjectionSetup,
);

ConfirmedPayment _payment({String id = 'payment-1'}) => ConfirmedPayment(
  id: id,
  businessId: 'business-a',
  customerId: 'C-001',
  customerCode: 'C-001',
  customerName: 'Synthetic Customer',
  amountPaise: 5000,
  method: PaymentMethod.cash,
  status: ConfirmedPaymentStatus.confirmed,
  externalReference: '',
  notes: '',
  collectorUid: 'employee-a',
  allocations: const [
    BillAllocation(
      billId: '2026-09',
      billingMonth: '2026-09',
      amountPaise: 5000,
    ),
  ],
  reversedPaise: 0,
  lastAuditId: 'payment-audit',
  serverConfirmed: true,
  confirmedAt: _confirmedDate,
);

Widget _app(
  CollectionsRepository collections,
  CustomerRepository customers,
  Widget child,
) => ProviderScope(
  overrides: [
    collectionsRepositoryProvider.overrideWithValue(collections),
    customerRepositoryProvider.overrideWithValue(customers),
  ],
  child: MaterialApp(home: child),
);

void _useLargeTestView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 1800);
  addTearDown(tester.view.reset);
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

class _FakeCollectionsRepository implements CollectionsRepository {
  _FakeCollectionsRepository({
    CustomerOutstandingSummary? summary,
    UpiSettings? upiSettings,
    List<PaymentHistoryPage>? historyPages,
  }) : summary = summary ?? _summary(),
       upiSettings =
           upiSettings ??
           const UpiSettings(
             businessId: 'business-a',
             upiId: 'paper.route@bank',
             payeeName: 'Paper Route Test',
             referencePrefix: 'PAPERROUTE',
             enabled: true,
             updatedBy: 'head-a',
             lastAuditId: 'upi-audit',
             serverConfirmed: true,
           ),
       historyPages = historyPages ?? const [];

  final CustomerOutstandingSummary summary;
  final UpiSettings upiSettings;
  final List<PaymentHistoryPage> historyPages;
  final confirmCalls = <PaymentConfirmationInput>[];
  final reverseCalls = <PaymentReversalInput>[];
  final upiUpdates = <UpiSettingsInput>[];
  final historyCursors = <PaymentHistoryCursor?>[];

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
    return PaymentConfirmationResult(
      payment: _payment(),
      remainingOutstandingPaise: summary.outstandingPaise - input.amountPaise,
      serverConfirmed: true,
    );
  }

  @override
  Future<PaymentHistoryPage> fetchPaymentHistory({
    required AppUser actor,
    String? customerId,
    PaymentHistoryCursor? cursor,
    int pageSize = 25,
  }) async {
    historyCursors.add(cursor);
    if (historyPages.isEmpty) {
      return const PaymentHistoryPage(
        items: [],
        nextCursor: null,
        hasMore: false,
      );
    }
    final index = historyCursors.length - 1;
    return historyPages[index < historyPages.length
        ? index
        : historyPages.length - 1];
  }

  @override
  Future<ConfirmedPayment> getPayment({
    required AppUser actor,
    required String customerId,
    required String paymentId,
  }) async => _payment(id: paymentId);

  @override
  Future<PaymentReversalResult> reversePayment({
    required AppUser actor,
    required String customerId,
    required PaymentReversalInput input,
  }) async {
    reverseCalls.add(input);
    return PaymentReversalResult(
      reversal: PaymentReversalRecord(
        id: input.idempotencyKey,
        businessId: 'business-a',
        customerId: customerId,
        paymentId: input.paymentId,
        amountPaise: input.amountPaise,
        reason: input.reason,
        reversedBy: actor.uid,
        allocations: const [
          BillAllocation(
            billId: '2026-09',
            billingMonth: '2026-09',
            amountPaise: 1000,
          ),
        ],
        lastAuditId: 'reversal-audit',
        serverConfirmed: true,
        reversedAt: _confirmedDate,
      ),
      paymentStatus: ConfirmedPaymentStatus.partiallyReversed,
      paymentReversedPaise: input.amountPaise,
      remainingOutstandingPaise: 6000,
      serverConfirmed: true,
    );
  }

  @override
  Future<void> updateUpiSettings({
    required AppUser actor,
    required UpiSettingsInput input,
  }) async {
    upiUpdates.add(input.normalized());
  }

  @override
  Stream<UpiSettings> watchUpiSettings(String businessId) =>
      Stream.value(upiSettings);
}
