import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/collections/domain/collection_balance_engine.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/collections/domain/payment_allocation_engine.dart';
import 'package:paper_route/features/collections/domain/upi_payment_uri.dart';

void main() {
  group('payment allocation', () {
    const engine = PaymentAllocationEngine();

    test('partial and exact payments allocate oldest outstanding first', () {
      final partial = engine.allocate(
        amountPaise: 25000,
        accountOutstandingPaise: 60000,
        bills: [_bill('2026-04', 60000)],
      );
      expect(partial.totalPaise, 25000);
      expect(partial.allocations.single.billId, '2026-04');
      expect(partial.allocations.single.amountPaise, 25000);

      final exact = engine.allocate(
        amountPaise: 60000,
        accountOutstandingPaise: 60000,
        bills: [_bill('2026-04', 60000)],
      );
      expect(exact.totalPaise, 60000);
    });

    test('multiple payments use the remaining immutable projection', () {
      final first = engine.allocate(
        amountPaise: 25000,
        accountOutstandingPaise: 60000,
        bills: [_bill('2026-04', 60000)],
      );
      expect(first.totalPaise, 25000);

      final second = engine.allocate(
        amountPaise: 35000,
        accountOutstandingPaise: 35000,
        bills: [
          _bill('2026-04', 35000, source: 60000, allocated: 25000, revision: 1),
        ],
      );
      expect(second.totalPaise, 35000);
    });

    test('multi-bill allocation is deterministic and oldest first', () {
      final plan = engine.allocate(
        amountPaise: 35000,
        accountOutstandingPaise: 50000,
        bills: [_bill('2026-04', 20000), _bill('2026-05', 30000)],
      );

      expect(
        plan.allocations
            .map((entry) => '${entry.billId}:${entry.amountPaise}')
            .toList(),
        ['2026-04:20000', '2026-05:15000'],
      );
    });

    test('an explicitly preferred bill is allocated before older bills', () {
      final plan = engine.allocate(
        amountPaise: 25000,
        accountOutstandingPaise: 60000,
        bills: [_bill('2026-04', 30000), _bill('2026-05', 30000)],
        preferredBillId: '2026-05',
      );

      expect(plan.allocations.single.billId, '2026-05');
      expect(plan.allocations.single.amountPaise, 25000);
    });

    test('overpayment and unavailable preferred bills are rejected', () {
      expect(
        () => engine.allocate(
          amountPaise: 60001,
          accountOutstandingPaise: 60000,
          bills: [_bill('2026-04', 60000)],
        ),
        _appError('overpayment'),
      );
      expect(
        () => engine.allocate(
          amountPaise: 100,
          accountOutstandingPaise: 60000,
          bills: [_bill('2026-04', 60000)],
          preferredBillId: '2026-05',
        ),
        _appError('preferred-bill-unavailable'),
      );
    });

    test('a payment spanning more than two bills is rejected safely', () {
      expect(
        () => engine.allocate(
          amountPaise: 300,
          accountOutstandingPaise: 300,
          bills: [
            for (var month = 1; month <= 3; month++)
              _bill('2026-${month.toString().padLeft(2, '0')}', 100),
          ],
        ),
        _appError('allocation-limit'),
      );
    });
  });

  group('payment reversal allocation', () {
    const engine = PaymentAllocationEngine();
    const allocations = [
      PaymentAllocationState(
        billId: '2026-04',
        billingMonth: '2026-04',
        amountPaise: 20000,
        reversedPaise: 0,
      ),
      PaymentAllocationState(
        billId: '2026-05',
        billingMonth: '2026-05',
        amountPaise: 25000,
        reversedPaise: 0,
      ),
    ];

    test('partial reversal restores the newest allocation first', () {
      final plan = engine.reverse(
        amountPaise: 5000,
        allocationStates: allocations,
      );

      expect(plan.totalPaise, 5000);
      expect(plan.allocations.single.billId, '2026-05');
      expect(plan.nextAllocationStates[0].reversedPaise, 0);
      expect(plan.nextAllocationStates[1].reversedPaise, 5000);
    });

    test('full reversal preserves every allocation as immutable context', () {
      final plan = engine.reverse(
        amountPaise: 45000,
        allocationStates: allocations,
      );

      expect(plan.totalPaise, 45000);
      expect(plan.allocations.map((entry) => entry.billId).toList(), [
        '2026-05',
        '2026-04',
      ]);
      expect(
        plan.nextAllocationStates.map((entry) => entry.refundablePaise),
        everyElement(0),
      );
    });

    test('cumulative reversal cannot exceed the remaining payment', () {
      expect(
        () => engine.reverse(amountPaise: 45001, allocationStates: allocations),
        _appError('reversal-exceeds-payment'),
      );
    });
  });

  group('collection balance and Phase 5 carry-forward', () {
    const engine = CollectionBalanceEngine();

    test(
      'opening balance is included once and partial payment carries forward',
      () {
        final october = engine.finalizeBill(
          existingAccount: null,
          openingBalancePaise: 1234,
          currentChargesPaise: 28050,
          adjustmentsPaise: -100,
          expectedTotalDuePaise: 29184,
        );
        expect(october.sourceAmountPaise, 29184);
        expect(october.account.outstandingPaise, 29184);

        final paid = engine.applyPayment(
          account: october.account,
          amountPaise: 10000,
        );
        expect(paid.outstandingPaise, 19184);
        expect(paid.confirmedPaise, 10000);

        final november = engine.finalizeBill(
          existingAccount: paid,
          openingBalancePaise: 1234,
          currentChargesPaise: 8000,
          adjustmentsPaise: 0,
          expectedTotalDuePaise: 27184,
        );
        expect(november.sourceAmountPaise, 8000);
        expect(november.account.outstandingPaise, 27184);
        expect(november.account.confirmedPaise, 10000);
      },
    );

    test('reversal restores outstanding without re-adding opening balance', () {
      final initial = engine.finalizeBill(
        existingAccount: null,
        openingBalancePaise: 1000,
        currentChargesPaise: 5000,
        adjustmentsPaise: 0,
        expectedTotalDuePaise: 6000,
      );
      final paid = engine.applyPayment(
        account: initial.account,
        amountPaise: 2500,
      );
      final reversed = engine.applyReversal(account: paid, amountPaise: 500);

      expect(reversed.outstandingPaise, 4000);
      expect(reversed.netConfirmedPaise, 2000);
      expect(reversed.reversedPaise, 500);
    });

    test('signed adjustment credit is not an allocatable negative bill', () {
      final result = engine.finalizeBill(
        existingAccount: const CollectionAccountBalance(
          outstandingPaise: 0,
          confirmedPaise: 5000,
          reversedPaise: 0,
        ),
        openingBalancePaise: 1000,
        currentChargesPaise: 0,
        adjustmentsPaise: -250,
        expectedTotalDuePaise: -250,
      );

      expect(result.sourceAmountPaise, -250);
      expect(result.componentOutstandingPaise, 0);
      expect(result.componentStatus, 'credit');
      expect(result.account.creditPaise, 250);
    });

    test('mismatched cumulative total is rejected before finalization', () {
      expect(
        () => engine.finalizeBill(
          existingAccount: const CollectionAccountBalance(
            outstandingPaise: 35000,
            confirmedPaise: 25000,
            reversedPaise: 0,
          ),
          openingBalancePaise: 0,
          currentChargesPaise: 10000,
          adjustmentsPaise: 0,
          expectedTotalDuePaise: 70000,
        ),
        _appError('collection-total-mismatch'),
      );
    });

    test('a projection cannot contain more reversals than confirmations', () {
      expect(
        () => engine.finalizeBill(
          existingAccount: const CollectionAccountBalance(
            outstandingPaise: 1000,
            confirmedPaise: 100,
            reversedPaise: 101,
          ),
          openingBalancePaise: 0,
          currentChargesPaise: 0,
          adjustmentsPaise: 0,
          expectedTotalDuePaise: 1000,
        ),
        _appError('invalid-collection-balance'),
      );
    });
  });

  group('payment inputs and UPI requests', () {
    const settings = UpiSettings(
      businessId: 'business-a',
      upiId: 'paper.route@bank',
      payeeName: 'Paper Route Test',
      referencePrefix: 'PAPERROUTE',
      enabled: true,
      updatedBy: 'head-a',
      lastAuditId: 'audit-1',
      serverConfirmed: true,
    );

    test('cash, UPI, bank transfer, and controlled other validation', () {
      const PaymentConfirmationInput(
        amountPaise: 100,
        method: PaymentMethod.cash,
        idempotencyKey: 'payment_cash_1',
      ).validate();
      expect(
        () =>
            const PaymentConfirmationInput(
              amountPaise: 100,
              method: PaymentMethod.upi,
              idempotencyKey: 'payment_upi_1',
            ).validate(),
        throwsA(isA<AppException>()),
      );
      const PaymentConfirmationInput(
        amountPaise: 100,
        method: PaymentMethod.bankTransfer,
        idempotencyKey: 'payment_bank_1',
        externalReference: 'BANK-123',
      ).validate();
      expect(
        () =>
            const PaymentConfirmationInput(
              amountPaise: 100,
              method: PaymentMethod.other,
              idempotencyKey: 'payment_other_1',
            ).validate(),
        throwsA(isA<AppException>()),
      );
    });

    test(
      'amount-specific URI is standard, deterministic, and integer-paise',
      () {
        final reference = UpiPaymentUriBuilder.deterministicReference(
          settings: settings,
          customerId: 'C-001',
          idempotencyKey: 'stable_retry_12345678',
        );
        final repeated = UpiPaymentUriBuilder.deterministicReference(
          settings: settings,
          customerId: 'C-001',
          idempotencyKey: 'stable_retry_12345678',
        );
        final uri = UpiPaymentUriBuilder.build(
          settings: settings,
          amountPaise: 25025,
          paymentReference: reference,
          note: 'PaperRoute collection C-001',
        );

        expect(reference, repeated);
        expect(reference.length, lessThanOrEqualTo(35));
        expect(uri.scheme, 'upi');
        expect(uri.host, 'pay');
        expect(uri.queryParameters['pa'], 'paper.route@bank');
        expect(uri.queryParameters['am'], '250.25');
        expect(uri.queryParameters['cu'], 'INR');
        expect(uri.queryParameters['tr'], reference);
      },
    );

    test(
      'static QR has no amount and disabled settings cannot build a URI',
      () {
        final uri = UpiPaymentUriBuilder.buildStatic(settings: settings);
        expect(uri.queryParameters, isNot(contains('am')));
        expect(uri.queryParameters, isNot(contains('tr')));

        expect(
          () => UpiPaymentUriBuilder.buildStatic(
            settings: UpiSettings.empty('business-a'),
          ),
          throwsA(isA<AppException>()),
        );
      },
    );
  });
}

OutstandingBill _bill(
  String month,
  int outstanding, {
  int? source,
  int allocated = 0,
  int reversed = 0,
  int revision = 0,
}) => OutstandingBill(
  billId: month,
  billingMonth: month,
  sourceAmountPaise: source ?? outstanding,
  allocatedPaise: allocated,
  reversedPaise: reversed,
  outstandingPaise: outstanding,
  status: outstanding == 0 ? 'settled' : 'outstanding',
  revision: revision,
);

Matcher _appError(String code) =>
    throwsA(isA<AppException>().having((error) => error.code, 'code', code));
