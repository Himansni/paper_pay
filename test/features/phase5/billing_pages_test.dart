import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/billing_repository.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/billing/presentation/bill_detail_page.dart';
import 'package:paper_route/features/billing/presentation/bill_preview_page.dart';
import 'package:paper_route/features/billing/presentation/billing_providers.dart';
import 'package:paper_route/features/billing/presentation/billing_workspace_page.dart';

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
  );

  testWidgets('workspace shows loading, empty, and finalized states', (
    tester,
  ) async {
    _useLargeTestView(tester);
    final repository = _FakeBillingRepository();
    await tester.pumpWidget(
      _app(repository, const BillingWorkspacePage(user: head)),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repository.workspaceCompleter.complete(
      const BillingWorkspaceResult(rows: [], nextCursor: null, hasMore: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('No active customers'), findsOneWidget);
  });

  testWidgets('employee workspace never presents preview action', (
    tester,
  ) async {
    _useLargeTestView(tester);
    final repository =
        _FakeBillingRepository()
          ..workspaceCompleter.complete(
            const BillingWorkspaceResult(
              rows: [
                BillingWorkspaceRow(
                  customerId: 'C-1',
                  customerCode: 'C-1',
                  customerName: 'Assigned Customer',
                  areaId: 'east',
                  finalizedBill: null,
                ),
              ],
              nextCursor: null,
              hasMore: false,
            ),
          );
    await tester.pumpWidget(
      _app(repository, const BillingWorkspacePage(user: employee)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assigned bills'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.textContaining('Not finalized'), findsOneWidget);
  });

  testWidgets('preview explains blocked data and disables finalization', (
    tester,
  ) async {
    _useLargeTestView(tester);
    final repository = _FakeBillingRepository(
      preview: _preview(
        issues: const [
          BillPreviewIssue(
            code: 'missing-price',
            message: 'Missing price for Synthetic Daily.',
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      _app(
        repository,
        const BillPreviewPage(
          user: head,
          customerId: 'C-1',
          billingMonth: '2026-05',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Read-only calculation'), findsOneWidget);
    expect(find.text('Finalization blocked'), findsOneWidget);
    expect(find.text('• Missing price for Synthetic Daily.'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('finalize-monthly-bill')),
    );
    expect(button.onPressed, isNull);
    expect(repository.finalizeCalls, 0);
  });

  testWidgets('preview shows daily source detail and enabled finalization', (
    tester,
  ) async {
    _useLargeTestView(tester);
    final repository = _FakeBillingRepository(preview: _preview());
    await tester.pumpWidget(
      _app(
        repository,
        const BillPreviewPage(
          user: head,
          customerId: 'C-1',
          billingMonth: '2026-05',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Synthetic Daily'), findsWidgets);
    expect(find.textContaining('Exact-date rule'), findsOneWidget);
    expect(find.textContaining('Current month charges'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('finalize-monthly-bill')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('finalized detail renders immutable summary and daily lines', (
    tester,
  ) async {
    _useLargeTestView(tester);
    final repository = _FakeBillingRepository(
      bill: _bill(),
      linePage: BillLinePage(
        items: _preview().lineItems,
        nextCursor: null,
        hasMore: false,
      ),
    );
    await tester.pumpWidget(
      _app(
        repository,
        const BillDetailPage(
          user: head,
          customerId: 'C-1',
          billingMonth: '2026-05',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Immutable financial snapshot'), findsOneWidget);
    expect(find.text('Synthetic Daily'), findsWidgets);
    expect(find.textContaining('2026-05-01'), findsOneWidget);
    expect(find.text('No adjustments were applied.'), findsOneWidget);
  });
}

Widget _app(BillingRepository repository, Widget child) => ProviderScope(
  overrides: [billingRepositoryProvider.overrideWithValue(repository)],
  child: MaterialApp(home: child),
);

void _useLargeTestView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 1800);
  addTearDown(tester.view.reset);
}

MonthlyBillPreview _preview({List<BillPreviewIssue> issues = const []}) =>
    MonthlyBillPreview(
      businessId: 'business-a',
      customerId: 'C-1',
      customerCode: 'C-1',
      customerName: 'Synthetic Customer',
      customerAddress: '1 Synthetic Road',
      billingMonth: '2026-05',
      lineItems: const [
        MonthlyBillLineItem(
          chargeKey: 'C-1:daily:2026-05-01',
          serviceDate: LocalDate(2026, 5, 1),
          subscriptionId: 'daily',
          versionId: 'v1',
          newspaperId: 'daily',
          newspaperName: 'Synthetic Daily',
          unitPricePaise: 650,
          quantity: 1,
          priceSource: BillPriceSource.exactDate,
          priceSourceId: 'rule-1',
          priceRuleRevision: 1,
        ),
      ],
      openingBalancePaise: 1000,
      previousBillId: '',
      previousOutstandingPaise: 0,
      adjustments: const [],
      issues: issues,
      alreadyFinalizedBill: null,
    );

FinalizedMonthlyBill _bill() => FinalizedMonthlyBill(
  id: '2026-05',
  businessId: 'business-a',
  customerId: 'C-1',
  customerCode: 'C-1',
  customerName: 'Synthetic Customer',
  customerAddress: '1 Synthetic Road',
  billingMonth: '2026-05',
  openingBalancePaise: 1000,
  previousBillId: '',
  previousOutstandingPaise: 0,
  priorBalancePaise: 1000,
  currentChargesPaise: 650,
  adjustmentsPaise: 0,
  totalDuePaise: 1650,
  lineItemCount: 1,
  newspaperSummaries: const [
    BillNewspaperSummary(
      newspaperId: 'daily',
      newspaperName: 'Synthetic Daily',
      deliveryCount: 1,
      subtotalPaise: 650,
    ),
  ],
  calculationVersion: phase5CalculationVersion,
  finalizedBy: 'head-a',
  lastAuditId: 'audit-1',
);

class _FakeBillingRepository implements BillingRepository {
  _FakeBillingRepository({
    MonthlyBillPreview? preview,
    this.bill,
    BillLinePage? linePage,
  }) : preview = preview ?? _preview(),
       linePage =
           linePage ??
           const BillLinePage(items: [], nextCursor: null, hasMore: false);

  final MonthlyBillPreview preview;
  final FinalizedMonthlyBill? bill;
  final BillLinePage linePage;
  Completer<BillingWorkspaceResult> workspaceCompleter = Completer();
  int finalizeCalls = 0;

  @override
  Future<String> createAdjustment({
    required AppUser actor,
    required String customerId,
    required BillingAdjustmentInput input,
  }) async => 'adjustment-1';

  @override
  Future<BillLinePage> fetchBillLines({
    required String businessId,
    required String customerId,
    required String billingMonth,
    BillLinePageCursor? cursor,
    int pageSize = 50,
  }) async => linePage;

  @override
  Future<BillingWorkspaceResult> fetchWorkspace({
    required AppUser actor,
    required LocalDate month,
    BillingWorkspaceCursor? cursor,
    int pageSize = 25,
  }) => workspaceCompleter.future;

  @override
  Future<FinalizedMonthlyBill> finalizeBill({
    required AppUser actor,
    required String customerId,
    required LocalDate month,
  }) async {
    finalizeCalls++;
    return bill ?? _bill();
  }

  @override
  Future<MonthlyBillPreview> previewBill({
    required AppUser actor,
    required String customerId,
    required LocalDate month,
  }) async => preview;

  @override
  Stream<List<BillingAdjustment>> watchAdjustments({
    required String businessId,
    required String customerId,
    required String billingMonth,
  }) => Stream.value(const []);

  @override
  Stream<FinalizedMonthlyBill?> watchBill({
    required String businessId,
    required String customerId,
    required String billingMonth,
  }) => Stream.value(bill);
}
