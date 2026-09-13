import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paper_route/core/config/firebase_bootstrap.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/data/firebase_billing_repository.dart';
import 'package:paper_route/features/collections/data/firebase_collections_repository.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/collections/domain/upi_payment_uri.dart';
import 'package:paper_route/features/collections/presentation/collections_workspace_page.dart';
import 'package:paper_route/features/collections/presentation/payment_receipt_page.dart';
import 'package:paper_route/features/newspapers/data/firebase_newspaper_repository.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/subscriptions/data/firebase_subscription_repository.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real repositories preserve an idempotent allocated collection ledger',
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
        displayName: 'Phase 6 Head',
        isEmailVerified: true,
        businessId: 'business-phase4',
        role: UserRole.head,
        status: AccountStatus.active,
      );
      final newspapers = FirebaseNewspaperRepository(firestore);
      final subscriptions = FirebaseSubscriptionRepository(firestore);
      final billing = FirebaseBillingRepository(firestore);
      final collections = FirebaseCollectionsRepository(firestore);

      final newspaperId = await newspapers.createNewspaper(
        actor: head,
        input: const NewspaperInput(
          name: 'Phase 6 Synthetic Daily',
          edition: 'Emulator',
          language: 'English',
          defaultPricePaise: 1000,
        ),
      );
      await subscriptions.createSubscription(
        actor: head,
        customerId: 'C-HEAD',
        input: SubscriptionInput(
          newspaperId: newspaperId,
          startDate: const LocalDate(2026, 10, 1),
          endDate: null,
          quantity: 1,
          deliveryWeekdays: DeliveryWeekday.all,
          customPricePaise: null,
          customPriceReason: '',
        ),
      );
      await subscriptions.createSubscription(
        actor: head,
        customerId: 'C-EMPLOYEE',
        input: SubscriptionInput(
          newspaperId: newspaperId,
          startDate: const LocalDate(2026, 10, 1),
          endDate: null,
          quantity: 1,
          deliveryWeekdays: const {DateTime.monday},
          customPricePaise: null,
          customPriceReason: '',
        ),
      );

      final october = await billing.finalizeBill(
        actor: head,
        customerId: 'C-HEAD',
        month: const LocalDate(2026, 10, 1),
      );
      expect(october.currentChargesPaise, 31000);
      expect(october.totalDuePaise, 31000);
      var outstanding = await collections.fetchCustomerOutstanding(
        actor: head,
        customerId: 'C-HEAD',
      );
      expect(outstanding.outstandingPaise, 31000);
      expect(outstanding.serverConfirmed, isTrue);

      const cashInput = PaymentConfirmationInput(
        amountPaise: 1000,
        method: PaymentMethod.cash,
        idempotencyKey: 'phase6-smoke-cash-001',
        notes: 'Synthetic emulator cash receipt',
      );
      final cashAttempts = await Future.wait([
        collections.confirmPayment(
          actor: head,
          customerId: 'C-HEAD',
          input: cashInput,
        ),
        collections.confirmPayment(
          actor: head,
          customerId: 'C-HEAD',
          input: cashInput,
        ),
      ]);
      expect(cashAttempts.map((result) => result.payment.id).toSet(), {
        cashInput.idempotencyKey,
      });
      expect(cashAttempts.every((result) => result.serverConfirmed), isTrue);
      expect(cashAttempts.first.payment.allocations.single.amountPaise, 1000);
      expect(cashAttempts.first.remainingOutstandingPaise, 30000);

      final novemberPreview = await billing.previewBill(
        actor: head,
        customerId: 'C-HEAD',
        month: const LocalDate(2026, 11, 1),
      );
      expect(novemberPreview.previousBillId, '2026-10');
      expect(novemberPreview.previousOutstandingPaise, 30000);
      expect(novemberPreview.priorBalancePaise, 30000);
      expect(novemberPreview.currentChargesPaise, 30000);
      expect(novemberPreview.totalDuePaise, 60000);
      await billing.finalizeBill(
        actor: head,
        customerId: 'C-HEAD',
        month: const LocalDate(2026, 11, 1),
      );

      await collections.updateUpiSettings(
        actor: head,
        input: const UpiSettingsInput(
          upiId: 'phase6-smoke@paperroute.test',
          payeeName: 'PaperRoute Phase 6 Smoke',
          referencePrefix: 'PHASE6SMOKE',
          enabled: true,
        ),
      );
      final settings = await collections
          .watchUpiSettings('business-phase4')
          .firstWhere((value) => value.serverConfirmed && value.enabled);
      final upiReference = UpiPaymentUriBuilder.deterministicReference(
        settings: settings,
        customerId: 'C-HEAD',
        idempotencyKey: 'phase6-smoke-upi-001',
      );
      final upiUri = UpiPaymentUriBuilder.build(
        settings: settings,
        amountPaise: 500,
        paymentReference: upiReference,
        note: 'Synthetic emulator collection',
      );
      expect(upiUri.queryParameters['am'], '5.00');
      expect(upiUri.queryParameters['tr'], upiReference);
      // URI construction is deliberately side-effect free.
      expect(
        (await firestore
                .collection(
                  'businesses/business-phase4/customers/C-HEAD/payments',
                )
                .get())
            .size,
        1,
      );

      final upi = await collections.confirmPayment(
        actor: head,
        customerId: 'C-HEAD',
        input: PaymentConfirmationInput(
          amountPaise: 500,
          method: PaymentMethod.upi,
          idempotencyKey: 'phase6-smoke-upi-001',
          externalReference: upiReference,
          notes: 'Manually verified synthetic UPI receipt',
        ),
      );
      expect(upi.payment.allocations, hasLength(1));
      expect(
        upi.payment.allocations
            .map(
              (allocation) => '${allocation.billId}:${allocation.amountPaise}',
            )
            .toList(),
        ['2026-10:500'],
      );
      expect(upi.remainingOutstandingPaise, 59500);

      final partialCashReversal = await collections.reversePayment(
        actor: head,
        customerId: 'C-HEAD',
        input: const PaymentReversalInput(
          paymentId: 'phase6-smoke-cash-001',
          amountPaise: 400,
          reason: 'Synthetic partial cash reversal',
          idempotencyKey: 'phase6-smoke-reversal-cash-001',
        ),
      );
      expect(
        partialCashReversal.paymentStatus,
        ConfirmedPaymentStatus.partiallyReversed,
      );
      expect(partialCashReversal.remainingOutstandingPaise, 59900);
      expect(partialCashReversal.reversal.allocations.single.billId, '2026-10');

      final remainingCashReversal = await collections.reversePayment(
        actor: head,
        customerId: 'C-HEAD',
        input: const PaymentReversalInput(
          paymentId: 'phase6-smoke-cash-001',
          amountPaise: 600,
          reason: 'Synthetic remaining cash reversal',
          idempotencyKey: 'phase6-smoke-reversal-cash-002',
        ),
      );
      expect(
        remainingCashReversal.paymentStatus,
        ConfirmedPaymentStatus.reversed,
      );
      expect(remainingCashReversal.remainingOutstandingPaise, 60500);

      final upiReversal = await collections.reversePayment(
        actor: head,
        customerId: 'C-HEAD',
        input: const PaymentReversalInput(
          paymentId: 'phase6-smoke-upi-001',
          amountPaise: 500,
          reason: 'Synthetic UPI reversal',
          idempotencyKey: 'phase6-smoke-reversal-upi-001',
        ),
      );
      expect(upiReversal.paymentStatus, ConfirmedPaymentStatus.reversed);
      expect(upiReversal.remainingOutstandingPaise, 61000);
      outstanding = await collections.fetchCustomerOutstanding(
        actor: head,
        customerId: 'C-HEAD',
      );
      expect(outstanding.outstandingPaise, 61000);
      expect(outstanding.confirmedPaise, 1500);
      expect(outstanding.reversedPaise, 1500);

      await collections.updateUpiSettings(
        actor: head,
        input: const UpiSettingsInput(
          upiId: '',
          payeeName: '',
          referencePrefix: 'PAPERROUTE',
          enabled: false,
        ),
      );
      final disabledSettings = await collections
          .watchUpiSettings('business-phase4')
          .firstWhere((value) => value.serverConfirmed && !value.enabled);
      expect(disabledSettings.upiId, isEmpty);
      expect(disabledSettings.payeeName, isEmpty);
      expect(disabledSettings.referencePrefix, 'PAPERROUTE');

      final december = await billing.previewBill(
        actor: head,
        customerId: 'C-HEAD',
        month: const LocalDate(2026, 12, 1),
      );
      expect(december.previousOutstandingPaise, 61000);
      expect(december.priorBalancePaise, 61000);

      final employeeOctober = await billing.finalizeBill(
        actor: head,
        customerId: 'C-EMPLOYEE',
        month: const LocalDate(2026, 10, 1),
      );
      expect(employeeOctober.totalDuePaise, greaterThan(0));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: CollectionsWorkspacePage(user: head)),
        ),
      );
      await _settleRemote(tester);
      expect(find.text('Payment history'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('payment-phase6-smoke-cash-001')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PaymentReceiptPage(
              user: head,
              customerId: 'C-HEAD',
              paymentId: 'phase6-smoke-upi-001',
            ),
          ),
        ),
      );
      await _settleRemote(tester);
      expect(find.text('Server-confirmed ledger entry'), findsOneWidget);
      expect(find.text('Reversed'), findsWidgets);
      expect(find.text('2026-10'), findsOneWidget);

      final firstHistory = await collections.fetchPaymentHistory(
        actor: head,
        pageSize: 1,
      );
      expect(firstHistory.items, hasLength(1));
      expect(firstHistory.hasMore, isTrue);
      final secondHistory = await collections.fetchPaymentHistory(
        actor: head,
        cursor: firstHistory.nextCursor,
        pageSize: 1,
      );
      expect(secondHistory.items, hasLength(1));
      expect(
        secondHistory.items.single.id,
        isNot(firstHistory.items.single.id),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await auth.signOut();
      final employeeCredential = await auth.signInWithEmailAndPassword(
        email: 'phase4-employee@example.test',
        password: 'Phase4-Employee-2026!',
      );
      final employee = AppUser(
        uid: employeeCredential.user!.uid,
        email: employeeCredential.user!.email!,
        displayName: 'Phase 6 Employee',
        isEmailVerified: true,
        businessId: 'business-phase4',
        role: UserRole.employee,
        status: AccountStatus.active,
        permissions: const {PermissionKey.recordPayments},
        areaIds: const {'central'},
      );
      final employeePayment = await collections.confirmPayment(
        actor: employee,
        customerId: 'C-EMPLOYEE',
        input: const PaymentConfirmationInput(
          amountPaise: 1000,
          method: PaymentMethod.cash,
          idempotencyKey: 'phase6_employee_cash_001',
        ),
      );
      expect(employeePayment.serverConfirmed, isTrue);
      expect(employeePayment.payment.collectorUid, employee.uid);
      await expectLater(
        collections.confirmPayment(
          actor: employee,
          customerId: 'C-HEAD',
          input: const PaymentConfirmationInput(
            amountPaise: 1000,
            method: PaymentMethod.cash,
            idempotencyKey: 'phase6_employee_denied_001',
          ),
        ),
        throwsA(isA<AppException>()),
      );
      final employeeHistory = await collections.fetchPaymentHistory(
        actor: employee,
        pageSize: 10,
      );
      expect(employeeHistory.items.map((payment) => payment.id), [
        'phase6_employee_cash_001',
      ]);

      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: 'phase4-head@example.test',
        password: 'Phase4-Smoke-2026!',
      );
      final business = firestore
          .collection('businesses')
          .doc('business-phase4');
      final headCustomer = business.collection('customers').doc('C-HEAD');
      final persistedPayments = await headCustomer.collection('payments').get();
      expect(persistedPayments.docs.map((document) => document.id).toSet(), {
        'phase6-smoke-cash-001',
        'phase6-smoke-upi-001',
      });
      final persistedPaymentStates =
          await headCustomer.collection('paymentStates').get();
      expect(
        persistedPaymentStates.docs.map((document) => document.id).toSet(),
        {'phase6-smoke-cash-001', 'phase6-smoke-upi-001'},
      );
      expect(
        persistedPaymentStates.docs
            .map((document) => document.data()['status'])
            .toSet(),
        {'reversed'},
      );
      final persistedReversals =
          await headCustomer.collection('paymentReversals').get();
      expect(persistedReversals.docs.map((document) => document.id).toSet(), {
        'phase6-smoke-reversal-cash-001',
        'phase6-smoke-reversal-cash-002',
        'phase6-smoke-reversal-upi-001',
      });
      final persistedCollectionState =
          (await headCustomer
                  .collection('collectionState')
                  .doc('current')
                  .get())
              .data()!;
      expect(persistedCollectionState['outstandingPaise'], 61000);
      expect(persistedCollectionState['confirmedPaise'], 1500);
      expect(persistedCollectionState['reversedPaise'], 1500);
      final persistedBillBalances =
          await headCustomer.collection('billBalances').get();
      expect(
        persistedBillBalances.docs.fold<int>(
          0,
          (total, document) => total + document.data()['allocatedPaise'] as int,
        ),
        1500,
      );
      expect(
        persistedBillBalances.docs.fold<int>(
          0,
          (total, document) => total + document.data()['reversedPaise'] as int,
        ),
        1500,
      );
      expect(
        (await headCustomer
                .collection('paymentStates')
                .doc(upi.payment.id)
                .get())
            .data()?['status'],
        'reversed',
      );
      final audits = await business.collection('auditRecords').get();
      expect(
        audits.docs
            .where(
              (document) => document.data()['action'] == 'paymentConfirmed',
            )
            .length,
        3,
      );
      expect(
        audits.docs
            .where(
              (document) =>
                  document.data()['action'] == 'paymentConfirmed' &&
                  document.data()['entityId'] == 'phase6-smoke-cash-001',
            )
            .length,
        1,
      );
      expect(
        audits.docs
            .where((document) => document.data()['action'] == 'paymentReversed')
            .length,
        3,
      );
      expect(
        audits.docs
            .where(
              (document) => document.data()['action'] == 'upiSettingsUpdated',
            )
            .length,
        2,
      );
      await auth.signOut();
    },
  );
}

Future<void> _settleRemote(WidgetTester tester) async {
  for (var index = 0; index < 32; index++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
        find.byType(LinearProgressIndicator).evaluate().isEmpty) {
      await tester.pump();
      return;
    }
  }
}
