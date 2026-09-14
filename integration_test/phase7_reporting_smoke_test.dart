import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paper_route/core/config/firebase_bootstrap.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/data/firebase_billing_repository.dart';
import 'package:paper_route/features/business/data/firebase_business_repository.dart';
import 'package:paper_route/features/business/domain/business_profile.dart';
import 'package:paper_route/features/collections/data/firebase_collections_repository.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/dashboard/presentation/dashboard_page.dart';
import 'package:paper_route/features/newspapers/data/firebase_newspaper_repository.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/presentation/daily_pricing_page.dart';
import 'package:paper_route/features/reports/data/firebase_reporting_repository.dart';
import 'package:paper_route/features/reports/domain/report_csv.dart';
import 'package:paper_route/features/reports/domain/report_models.dart';
import 'package:paper_route/features/reports/presentation/reports_page.dart';
import 'package:paper_route/features/subscriptions/data/firebase_subscription_repository.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real repositories provide scoped dashboards, paginated reports, and pricing context',
    (tester) async {
      final startup = await FirebaseBootstrap.initialize();
      expect(startup.isReady, isTrue);
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      await auth.signOut();
      final headCredential = await auth.signInWithEmailAndPassword(
        email: 'phase4-head@example.test',
        password: 'Phase4-Smoke-2026!',
      );
      final head = AppUser(
        uid: headCredential.user!.uid,
        email: headCredential.user!.email!,
        displayName: 'Phase 7 Head',
        isEmailVerified: true,
        businessId: 'business-phase4',
        role: UserRole.head,
        status: AccountStatus.active,
      );
      final business = FirebaseBusinessRepository(firestore);
      final newspapers = FirebaseNewspaperRepository(firestore);
      final subscriptions = FirebaseSubscriptionRepository(firestore);
      final billing = FirebaseBillingRepository(firestore);
      final collections = FirebaseCollectionsRepository(firestore);
      final reports = FirebaseReportingRepository(firestore);

      await business.updatePrimaryPricingRegion(
        businessId: 'business-phase4',
        actorId: head.uid,
        region: const PricingRegion(
          state: 'Synthetic State',
          districtCity: 'Emulator City',
          editionServiceRegion: 'Central Test Edition',
        ),
      );
      debugPrint('Phase 7 connected step: region saved');
      final newspaperId = await newspapers.createNewspaper(
        actor: head,
        input: const NewspaperInput(
          name: 'Phase 7 Reporting Daily',
          edition: 'Emulator',
          language: 'English',
          defaultPricePaise: 1000,
        ),
      );
      await newspapers.createPriceRule(
        actor: head,
        newspaperId: newspaperId,
        input: const PriceRuleInput(
          kind: PriceRuleKind.exactDate,
          startDate: LocalDate(2026, 9, 13),
          endDate: null,
          pricePaise: 1500,
          reason: 'Synthetic Phase 7 daily-price verification',
        ),
      );
      await subscriptions.createSubscription(
        actor: head,
        customerId: 'C-HEAD',
        input: SubscriptionInput(
          newspaperId: newspaperId,
          startDate: const LocalDate(2026, 9, 1),
          endDate: null,
          quantity: 1,
          deliveryWeekdays: DeliveryWeekday.all,
          customPricePaise: null,
          customPriceReason: '',
        ),
      );
      debugPrint('Phase 7 connected step: catalog and subscriptions created');
      await subscriptions.createSubscription(
        actor: head,
        customerId: 'C-EMPLOYEE',
        input: SubscriptionInput(
          newspaperId: newspaperId,
          startDate: const LocalDate(2026, 9, 1),
          endDate: null,
          quantity: 1,
          deliveryWeekdays: const {DateTime.monday},
          customPricePaise: null,
          customPriceReason: '',
        ),
      );

      final headBill = await billing.finalizeBill(
        actor: head,
        customerId: 'C-HEAD',
        month: const LocalDate(2026, 9, 1),
      );
      final employeeBill = await billing.finalizeBill(
        actor: head,
        customerId: 'C-EMPLOYEE',
        month: const LocalDate(2026, 9, 1),
      );
      expect(headBill.currentChargesPaise, 30500);
      expect(employeeBill.currentChargesPaise, 4000);
      debugPrint('Phase 7 connected step: bills finalized');

      await collections.confirmPayment(
        actor: head,
        customerId: 'C-HEAD',
        input: const PaymentConfirmationInput(
          amountPaise: 1000,
          method: PaymentMethod.cash,
          idempotencyKey: 'phase7-head-cash-001',
          notes: 'Synthetic Phase 7 emulator receipt',
        ),
      );
      await collections.reversePayment(
        actor: head,
        customerId: 'C-HEAD',
        input: const PaymentReversalInput(
          paymentId: 'phase7-head-cash-001',
          amountPaise: 200,
          reason: 'Synthetic Phase 7 net-collection check',
          idempotencyKey: 'phase7-head-reversal-001',
        ),
      );
      debugPrint('Phase 7 connected step: Head ledger ready');

      await auth.signOut();
      final employeeCredential = await auth.signInWithEmailAndPassword(
        email: 'phase4-employee@example.test',
        password: 'Phase4-Employee-2026!',
      );
      final employee = AppUser(
        uid: employeeCredential.user!.uid,
        email: employeeCredential.user!.email!,
        displayName: 'Phase 7 Employee',
        isEmailVerified: true,
        businessId: 'business-phase4',
        role: UserRole.employee,
        status: AccountStatus.active,
        permissions: const {'recordPayments'},
        areaIds: const {'central'},
      );
      await collections.confirmPayment(
        actor: employee,
        customerId: 'C-EMPLOYEE',
        input: const PaymentConfirmationInput(
          amountPaise: 500,
          method: PaymentMethod.cash,
          idempotencyKey: 'phase7-employee-cash-001',
          notes: 'Synthetic assigned-customer emulator receipt',
        ),
      );
      debugPrint('Phase 7 connected step: employee payment ready');
      final employeeDashboard = await reports.fetchDashboard(
        actor: employee,
        now: DateTime.utc(2026, 9, 13),
      );
      expect(employeeDashboard.activeCustomers, 1);
      expect(employeeDashboard.currentMonthCollectionsPaise, 500);
      expect(employeeDashboard.currentOutstandingPaise, 3500);
      expect(employeeDashboard.recentPayments, hasLength(1));
      expect(
        employeeDashboard.recentPayments.single.id,
        'phase7-employee-cash-001',
      );
      expect(employeeDashboard.routeSummaries.single.id, 'central');
      debugPrint('Phase 7 connected step: employee dashboard verified');

      await expectLater(
        reports.fetchReport(
          actor: employee,
          filter: _filter(ReportKind.collections),
        ),
        throwsA(isA<Object>()),
      );

      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: 'phase4-head@example.test',
        password: 'Phase4-Smoke-2026!',
      );
      final dashboard = await reports.fetchDashboard(
        actor: head,
        now: DateTime.utc(2026, 9, 13),
      );
      expect(dashboard.activeCustomers, 2);
      expect(dashboard.currentMonthBilledPaise, 34500);
      expect(dashboard.currentMonthCollectionsPaise, 1500);
      expect(dashboard.currentMonthReversedPaise, 200);
      expect(dashboard.netCollectionsPaise, 1300);
      expect(dashboard.currentOutstandingPaise, 33200);
      expect(dashboard.partiallyPaidCustomers, 2);
      expect(dashboard.customersWithoutFinalizedBill, 0);
      debugPrint('Phase 7 connected step: Head dashboard verified');

      final firstCollections = await reports.fetchReport(
        actor: head,
        filter: _filter(ReportKind.collections),
        pageSize: 1,
      );
      expect(firstCollections.rows, hasLength(1));
      expect(firstCollections.hasMore, isTrue);
      expect(firstCollections.summary.totalPaise, 1500);
      expect(firstCollections.summary.secondaryPaise, 200);
      expect(firstCollections.summary.netPaise, 1300);
      debugPrint('Phase 7 connected step: first collection report verified');
      final secondCollections = await reports.fetchReport(
        actor: head,
        filter: _filter(ReportKind.collections),
        cursor: firstCollections.nextCursor,
        pageSize: 1,
      );
      expect(secondCollections.rows, hasLength(1));
      expect(
        {
          ...firstCollections.rows.map((row) => row.id),
          ...secondCollections.rows.map((row) => row.id),
        },
        {'phase7-head-cash-001', 'phase7-employee-cash-001'},
      );
      debugPrint('Phase 7 connected step: collection pagination verified');

      final billingReport = await reports.fetchReport(
        actor: head,
        filter: _filter(ReportKind.billing),
      );
      expect(billingReport.summary.totalCount, 2);
      expect(billingReport.summary.totalPaise, 34500);
      debugPrint('Phase 7 connected step: billing report verified');
      final outstandingReport = await reports.fetchReport(
        actor: head,
        filter: _filter(ReportKind.outstanding),
      );
      expect(outstandingReport.summary.totalCount, 2);
      expect(outstandingReport.summary.totalPaise, 33200);
      debugPrint('Phase 7 connected step: outstanding report verified');
      final customerReport = await reports.fetchReport(
        actor: head,
        filter: _filter(ReportKind.customers),
      );
      expect(customerReport.summary.totalCount, 2);
      debugPrint('Phase 7 connected step: customer report verified');
      final subscriptionReport = await reports.fetchReport(
        actor: head,
        filter: _filter(ReportKind.subscriptions),
      );
      expect(subscriptionReport.summary.totalCount, 2);
      final csv = ReportCsv.build(
        kind: ReportKind.collections,
        filter: _filter(ReportKind.collections),
        rows: [...firstCollections.rows, ...secondCollections.rows],
      );
      expect(csv, contains('phase7-head-cash-001'));
      expect(csv, contains('phase7-employee-cash-001'));

      final headBillRef = firestore
          .collection('businesses')
          .doc('business-phase4')
          .collection('customers')
          .doc('C-HEAD')
          .collection('bills')
          .doc('2026-09');
      final lineCountBefore =
          (await headBillRef.collection('lineItems').get()).size;
      await newspapers.createPriceRule(
        actor: head,
        newspaperId: newspaperId,
        input: const PriceRuleInput(
          kind: PriceRuleKind.exactDate,
          startDate: LocalDate(2026, 9, 14),
          endDate: null,
          pricePaise: 2500,
          reason: 'Synthetic post-finalization immutability check',
        ),
      );
      final persistedBill = (await headBillRef.get()).data()!;
      expect(persistedBill['currentChargesPaise'], 30500);
      expect(
        (await headBillRef.collection('lineItems').get()).size,
        lineCountBefore,
      );

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp(home: DashboardPage(user: head))),
      );
      await _settleRemote(tester);
      expect(find.text('Current outstanding'), findsOneWidget);
      expect(find.text('₹332.00'), findsWidgets);
      expect(find.text('Daily pricing'), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp(home: ReportsPage(user: head))),
      );
      await _settleRemote(tester);
      expect(find.text('Business reports'), findsOneWidget);
      expect(find.text('Synthetic C-EMPLOYEE'), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp(home: DailyPricingPage(user: head))),
      );
      await _settleRemote(tester);
      expect(find.text("Today's Paper Prices — Emulator City"), findsOneWidget);
      expect(find.textContaining('Central Test Edition'), findsWidgets);
      await auth.signOut();
    },
  );
}

ReportFilter _filter(ReportKind kind) => ReportFilter(
  kind: kind,
  period: ReportingPeriod.month(DateTime.utc(2026, 9)),
  billingMonth: '2026-09',
  customerStatus: 'active',
  billStatus: 'finalized',
);

Future<void> _settleRemote(WidgetTester tester) async {
  for (var index = 0; index < 40; index++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
        find.byType(LinearProgressIndicator).evaluate().isEmpty) {
      await tester.pump();
      return;
    }
  }
}
