enum PaymentStatus {
  requested,
  pendingVerification,
  manuallyConfirmed,
  failed,
  cancelled,
}

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.billId,
    required this.amountPaise,
    required this.status,
  }) : assert(amountPaise > 0);

  final String id;
  final String billId;
  final int amountPaise;
  final PaymentStatus status;
}

class PaymentReversal {
  const PaymentReversal({
    required this.id,
    required this.paymentId,
    required this.amountPaise,
  }) : assert(amountPaise > 0);

  final String id;
  final String paymentId;
  final int amountPaise;
}

class PaymentLedgerSummary {
  const PaymentLedgerSummary({
    required this.totalDuePaise,
    required this.confirmedPaymentsPaise,
    required this.reversedPaise,
  });

  final int totalDuePaise;
  final int confirmedPaymentsPaise;
  final int reversedPaise;

  int get netPaidPaise => confirmedPaymentsPaise - reversedPaise;
  int get remainingBalancePaise => totalDuePaise - netPaidPaise;
}

class PaymentLedgerException implements Exception {
  const PaymentLedgerException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Computes balances from an append-only payment and reversal ledger. Merely
/// requesting a payment or showing a QR code never reduces the balance.
///
/// BEGINNER NOTE:
/// Reversals compensate for confirmed money; they never erase its receipt.
/// That is why net paid equals confirmed payments minus reversal records.
class PaymentLedger {
  const PaymentLedger();

  PaymentLedgerSummary summarize({
    required int totalDuePaise,
    required List<PaymentRecord> payments,
    List<PaymentReversal> reversals = const [],
  }) {
    final paymentsById = <String, PaymentRecord>{};
    for (final payment in payments) {
      if (paymentsById.containsKey(payment.id)) {
        throw PaymentLedgerException('Duplicate payment ID: ${payment.id}');
      }
      paymentsById[payment.id] = payment;
    }

    final reversalIds = <String>{};
    final reversedByPayment = <String, int>{};
    for (final reversal in reversals) {
      if (!reversalIds.add(reversal.id)) {
        throw PaymentLedgerException('Duplicate reversal ID: ${reversal.id}');
      }
      final original = paymentsById[reversal.paymentId];
      if (original == null ||
          original.status != PaymentStatus.manuallyConfirmed) {
        throw PaymentLedgerException(
          'Reversal ${reversal.id} has no confirmed original payment.',
        );
      }
      final newTotal =
          (reversedByPayment[reversal.paymentId] ?? 0) + reversal.amountPaise;
      if (newTotal > original.amountPaise) {
        throw PaymentLedgerException(
          'Reversals exceed payment ${reversal.paymentId}.',
        );
      }
      reversedByPayment[reversal.paymentId] = newTotal;
    }

    final confirmed = payments
        .where((payment) => payment.status == PaymentStatus.manuallyConfirmed)
        .fold(0, (total, payment) => total + payment.amountPaise);
    final reversed = reversals.fold(
      0,
      (total, reversal) => total + reversal.amountPaise,
    );

    return PaymentLedgerSummary(
      totalDuePaise: totalDuePaise,
      confirmedPaymentsPaise: confirmed,
      reversedPaise: reversed,
    );
  }
}
