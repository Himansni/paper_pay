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
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/billing/presentation/bill_detail_page.dart';
import 'package:paper_route/features/billing/presentation/bill_preview_page.dart';
import 'package:paper_route/features/newspapers/data/firebase_newspaper_repository.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/subscriptions/data/firebase_subscription_repository.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real repositories preview and atomically finalize one immutable month',
    (tester) async {
      final startup = await FirebaseBootstrap.initialize();
      expect(startup.isReady, isTrue);
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      await auth.signOut();
      final credential = await auth.signInWithEmailAndPassword(
        email: 'phase4-head@example.test',
        password: 'Phase4-Smoke-2026!',
      );
      final head = AppUser(
        uid: credential.user!.uid,
        email: credential.user!.email!,
        displayName: 'Phase 5 Head',
        isEmailVerified: true,
        businessId: 'business-phase4',
        role: UserRole.head,
        status: AccountStatus.active,
      );
      final newspaperRepository = FirebaseNewspaperRepository(firestore);
      final subscriptionRepository = FirebaseSubscriptionRepository(firestore);
      final billingRepository = FirebaseBillingRepository(firestore);

      final dailyId = await newspaperRepository.createNewspaper(
        actor: head,
        input: const NewspaperInput(
          name: 'Phase 5 Synthetic Daily',
          edition: 'Emulator',
          language: 'English',
          defaultPricePaise: 500,
        ),
      );
      final weeklyId = await newspaperRepository.createNewspaper(
        actor: head,
        input: const NewspaperInput(
          name: 'Phase 5 Synthetic Weekly',
          edition: 'Emulator',
          language: 'English',
          defaultPricePaise: 900,
        ),
      );
      await newspaperRepository.createPriceRule(
        actor: head,
        newspaperId: dailyId,
        input: const PriceRuleInput(
          kind: PriceRuleKind.period,
          startDate: LocalDate(2026, 10, 10),
          endDate: LocalDate(2026, 10, 20),
          pricePaise: 600,
          reason: 'Synthetic October period price',
        ),
      );
      await newspaperRepository.createPriceRule(
        actor: head,
        newspaperId: dailyId,
        input: const PriceRuleInput(
          kind: PriceRuleKind.exactDate,
          startDate: LocalDate(2026, 10, 15),
          endDate: null,
          pricePaise: 800,
          reason: 'Synthetic exact-date price',
        ),
      );
      await subscriptionRepository.createSubscription(
        actor: head,
        customerId: 'C-HEAD',
        input: SubscriptionInput(
          newspaperId: dailyId,
          startDate: const LocalDate(2026, 10, 1),
          endDate: null,
          quantity: 1,
          deliveryWeekdays: DeliveryWeekday.all,
          customPricePaise: null,
          customPriceReason: '',
        ),
      );
      await subscriptionRepository.createSubscription(
        actor: head,
        customerId: 'C-HEAD',
        input: SubscriptionInput(
          newspaperId: weeklyId,
          startDate: const LocalDate(2026, 10, 1),
          endDate: null,
          quantity: 2,
          deliveryWeekdays: const {DateTime.monday},
          customPricePaise: 350,
          customPriceReason: 'Head-authorized emulator exception',
        ),
      );
      await subscriptionRepository.addPause(
        actor: head,
        customerId: 'C-HEAD',
        subscriptionId: dailyId,
        startDate: const LocalDate(2026, 10, 5),
        endDate: const LocalDate(2026, 10, 6),
        reason: 'Synthetic scheduled pause',
      );
      final customerRef = firestore
          .collection('businesses')
          .doc('business-phase4')
          .collection('customers')
          .doc('C-HEAD');
      final exceptionRef = customerRef
          .collection('deliveryExceptions')
          .doc('phase5-no-delivery');
      final billingSourceRef = customerRef
          .collection('billingSources')
          .doc('service');
      await firestore.runTransaction((transaction) async {
        final billingSource = await transaction.get(billingSourceRef);
        final billingSourceData = billingSource.data();
        final now = FieldValue.serverTimestamp();
        transaction.set(exceptionRef, {
          'businessId': 'business-phase4',
          'customerId': 'C-HEAD',
          'exceptionId': 'phase5-no-delivery',
          'subscriptionId': dailyId,
          'type': 'noDelivery',
          'serviceDate': '2026-10-07',
          'reason': 'Synthetic no-delivery verification',
          'createdBy': head.uid,
          'createdAt': now,
        });
        transaction.set(billingSourceRef, {
          'businessId': 'business-phase4',
          'customerId': 'C-HEAD',
          'sourceId': 'service',
          'revision': (billingSourceData?['revision'] as int? ?? 0) + 1,
          'lastMutationType': 'deliveryExceptionCreated',
          'lastMutationId': 'phase5-no-delivery',
          'updatedBy': head.uid,
          'createdAt': billingSourceData?['createdAt'] ?? now,
          'updatedAt': now,
        });
      });
      await billingRepository.createAdjustment(
        actor: head,
        customerId: 'C-HEAD',
        input: const BillingAdjustmentInput(
          billingMonth: '2026-10',
          amountPaise: -100,
          reason: 'Synthetic audited monthly credit',
        ),
      );

      final preview = await billingRepository.previewBill(
        actor: head,
        customerId: 'C-HEAD',
        month: const LocalDate(2026, 10, 1),
      );
      expect(preview.issues, isEmpty);
      expect(preview.canFinalize, isTrue);
      expect(
        preview.lineItems.any(
          (line) => line.subscriptionId == dailyId && line.serviceDate.day == 5,
        ),
        isFalse,
      );
      expect(
        preview.lineItems.any(
          (line) => line.subscriptionId == dailyId && line.serviceDate.day == 7,
        ),
        isFalse,
      );
      expect(
        preview.lineItems
            .singleWhere(
              (line) =>
                  line.subscriptionId == dailyId && line.serviceDate.day == 15,
            )
            .priceSource,
        BillPriceSource.exactDate,
      );
      expect(
        preview.lineItems
            .where((line) => line.subscriptionId == weeklyId)
            .every(
              (line) =>
                  line.priceSource == BillPriceSource.customerSpecific &&
                  line.quantity == 2,
            ),
        isTrue,
      );
      expect(preview.adjustmentsPaise, -100);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: BillPreviewPage(
              user: head,
              customerId: 'C-HEAD',
              billingMonth: '2026-10',
            ),
          ),
        ),
      );
      await _settleRemote(tester);
      expect(find.text('Read-only calculation'), findsOneWidget);
      expect(find.text('Review before finalization'), findsOneWidget);

      final attempts = await Future.wait([
        billingRepository.finalizeBill(
          actor: head,
          customerId: 'C-HEAD',
          month: const LocalDate(2026, 10, 1),
        ),
        billingRepository.finalizeBill(
          actor: head,
          customerId: 'C-HEAD',
          month: const LocalDate(2026, 10, 1),
        ),
      ]);
      expect(attempts.map((bill) => bill.id).toSet(), {'2026-10'});
      expect(attempts.first.totalDuePaise, preview.totalDuePaise);

      final billRef = firestore
          .collection('businesses')
          .doc('business-phase4')
          .collection('customers')
          .doc('C-HEAD')
          .collection('bills')
          .doc('2026-10');
      expect((await billRef.get()).exists, isTrue);
      expect(
        (await billRef.collection('lineItems').get()).size,
        preview.lineItems.length,
      );
      final billAudits =
          await firestore
              .collection('businesses')
              .doc('business-phase4')
              .collection('auditRecords')
              .where('action', isEqualTo: 'billFinalized')
              .get();
      expect(billAudits.size, 1);
      final firstLinePage = await billingRepository.fetchBillLines(
        businessId: 'business-phase4',
        customerId: 'C-HEAD',
        billingMonth: '2026-10',
        pageSize: 10,
      );
      expect(firstLinePage.items, hasLength(10));
      expect(firstLinePage.hasMore, isTrue);
      final secondLinePage = await billingRepository.fetchBillLines(
        businessId: 'business-phase4',
        customerId: 'C-HEAD',
        billingMonth: '2026-10',
        pageSize: 10,
        cursor: firstLinePage.nextCursor,
      );
      expect(
        firstLinePage.items
            .map((line) => line.chargeKey)
            .toSet()
            .intersection(
              secondLinePage.items.map((line) => line.chargeKey).toSet(),
            ),
        isEmpty,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: BillDetailPage(
              user: head,
              customerId: 'C-HEAD',
              billingMonth: '2026-10',
            ),
          ),
        ),
      );
      await _settleRemote(tester);
      expect(find.text('Immutable financial snapshot'), findsOneWidget);
      expect(find.text('Finalized monthly bill'), findsOneWidget);

      final november = await billingRepository.previewBill(
        actor: head,
        customerId: 'C-HEAD',
        month: const LocalDate(2026, 11, 1),
      );
      expect(november.previousBillId, '2026-10');
      expect(november.priorBalancePaise, preview.totalDuePaise);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: 'phase4-employee@example.test',
        password: 'Phase4-Employee-2026!',
      );
      await expectLater(billRef.get(), throwsA(isA<FirebaseException>()));
    },
  );
}

Future<void> _settleRemote(WidgetTester tester) async {
  for (var index = 0; index < 24; index++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
        find.byType(LinearProgressIndicator).evaluate().isEmpty) {
      await tester.pump();
      return;
    }
  }
}
