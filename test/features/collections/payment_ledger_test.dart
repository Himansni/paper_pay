import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/features/collections/domain/payment_ledger.dart';

void main() {
  const ledger = PaymentLedger();

  test('partial payment leaves the correct remaining balance', () {
    final summary = ledger.summarize(
      totalDuePaise: 60000,
      payments: const [
        PaymentRecord(
          id: 'payment-1',
          billId: 'bill-1',
          amountPaise: 25000,
          status: PaymentStatus.manuallyConfirmed,
        ),
      ],
    );

    expect(summary.netPaidPaise, 25000);
    expect(summary.remainingBalancePaise, 35000);
  });

  test('QR request and pending payment do not reduce balance', () {
    final summary = ledger.summarize(
      totalDuePaise: 60000,
      payments: const [
        PaymentRecord(
          id: 'request-1',
          billId: 'bill-1',
          amountPaise: 60000,
          status: PaymentStatus.requested,
        ),
        PaymentRecord(
          id: 'pending-1',
          billId: 'bill-1',
          amountPaise: 60000,
          status: PaymentStatus.pendingVerification,
        ),
      ],
    );

    expect(summary.netPaidPaise, 0);
    expect(summary.remainingBalancePaise, 60000);
  });

  test('rejects duplicate payment identifiers', () {
    expect(
      () => ledger.summarize(
        totalDuePaise: 60000,
        payments: const [
          PaymentRecord(
            id: 'same-id',
            billId: 'bill-1',
            amountPaise: 25000,
            status: PaymentStatus.manuallyConfirmed,
          ),
          PaymentRecord(
            id: 'same-id',
            billId: 'bill-1',
            amountPaise: 10000,
            status: PaymentStatus.manuallyConfirmed,
          ),
        ],
      ),
      throwsA(isA<PaymentLedgerException>()),
    );
  });

  test('head correction reverses confirmed value without deleting history', () {
    final summary = ledger.summarize(
      totalDuePaise: 60000,
      payments: const [
        PaymentRecord(
          id: 'payment-1',
          billId: 'bill-1',
          amountPaise: 25000,
          status: PaymentStatus.manuallyConfirmed,
        ),
      ],
      reversals: const [
        PaymentReversal(
          id: 'reversal-1',
          paymentId: 'payment-1',
          amountPaise: 5000,
        ),
      ],
    );

    expect(summary.netPaidPaise, 20000);
    expect(summary.remainingBalancePaise, 40000);
  });
}
