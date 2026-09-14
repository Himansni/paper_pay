import 'dart:math' as math;

import 'package:paper_route/core/errors/app_exception.dart';

String collectionReportingStatus({
  required int outstandingPaise,
  required int confirmedPaise,
  required int reversedPaise,
}) {
  if (outstandingPaise < 0) return 'credit';
  if (outstandingPaise == 0) return 'fullyPaid';
  return confirmedPaise > reversedPaise ? 'partiallyPaid' : 'unpaid';
}

class CollectionAccountBalance {
  const CollectionAccountBalance({
    required this.outstandingPaise,
    required this.confirmedPaise,
    required this.reversedPaise,
  });

  final int outstandingPaise;
  final int confirmedPaise;
  final int reversedPaise;

  int get payablePaise => math.max(0, outstandingPaise);
  int get creditPaise => math.max(0, -outstandingPaise);
  int get netConfirmedPaise => confirmedPaise - reversedPaise;
}

class BillCollectionProjection {
  const BillCollectionProjection({
    required this.sourceAmountPaise,
    required this.componentOutstandingPaise,
    required this.componentStatus,
    required this.account,
  });

  /// Incremental debt contributed by this bill. Only the first projected bill
  /// includes opening/prior legacy value; later bills never repeat prior debt.
  final int sourceAmountPaise;
  final int componentOutstandingPaise;
  final String componentStatus;
  final CollectionAccountBalance account;
}

/// Arithmetic shared by billing and collections so cumulative statement totals
/// cannot accidentally be summed as independent obligations.
class CollectionBalanceEngine {
  const CollectionBalanceEngine();

  BillCollectionProjection finalizeBill({
    required CollectionAccountBalance? existingAccount,
    required int openingBalancePaise,
    required int currentChargesPaise,
    required int adjustmentsPaise,
    required int expectedTotalDuePaise,
  }) {
    if (currentChargesPaise < 0 ||
        openingBalancePaise < 0 ||
        existingAccount?.confirmedPaise.isNegative == true ||
        existingAccount?.reversedPaise.isNegative == true ||
        (existingAccount != null &&
            existingAccount.reversedPaise > existingAccount.confirmedPaise)) {
      throw const AppException(
        'The collection balance inputs are invalid.',
        code: 'invalid-collection-balance',
      );
    }
    final prior = existingAccount?.outstandingPaise ?? openingBalancePaise;
    final total = prior + currentChargesPaise + adjustmentsPaise;
    if (total != expectedTotalDuePaise) {
      throw const AppException(
        'The billing total no longer matches the collection balance.',
        code: 'collection-total-mismatch',
      );
    }
    final source =
        existingAccount == null
            ? total
            : currentChargesPaise + adjustmentsPaise;
    return BillCollectionProjection(
      sourceAmountPaise: source,
      componentOutstandingPaise: math.max(0, source),
      componentStatus:
          source > 0
              ? 'outstanding'
              : source < 0
              ? 'credit'
              : 'settled',
      account: CollectionAccountBalance(
        outstandingPaise: total,
        confirmedPaise: existingAccount?.confirmedPaise ?? 0,
        reversedPaise: existingAccount?.reversedPaise ?? 0,
      ),
    );
  }

  CollectionAccountBalance applyPayment({
    required CollectionAccountBalance account,
    required int amountPaise,
  }) {
    if (amountPaise <= 0 || amountPaise > account.payablePaise) {
      throw const AppException(
        'The payment exceeds the positive outstanding balance.',
        code: 'overpayment',
      );
    }
    return CollectionAccountBalance(
      outstandingPaise: account.outstandingPaise - amountPaise,
      confirmedPaise: account.confirmedPaise + amountPaise,
      reversedPaise: account.reversedPaise,
    );
  }

  CollectionAccountBalance applyReversal({
    required CollectionAccountBalance account,
    required int amountPaise,
  }) {
    if (amountPaise <= 0 || amountPaise > account.netConfirmedPaise) {
      throw const AppException(
        'The reversal exceeds the net confirmed collections.',
        code: 'reversal-exceeds-payment',
      );
    }
    return CollectionAccountBalance(
      outstandingPaise: account.outstandingPaise + amountPaise,
      confirmedPaise: account.confirmedPaise,
      reversedPaise: account.reversedPaise + amountPaise,
    );
  }
}
