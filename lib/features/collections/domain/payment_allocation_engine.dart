import 'dart:math' as math;

import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';

class PaymentAllocationPlan {
  const PaymentAllocationPlan({required this.allocations});

  final List<BillAllocation> allocations;

  int get totalPaise => allocations.fold(
    0,
    (total, allocation) => total + allocation.amountPaise,
  );
}

class ReversalAllocationPlan {
  const ReversalAllocationPlan({
    required this.allocations,
    required this.nextAllocationStates,
  });

  final List<BillAllocation> allocations;
  final List<PaymentAllocationState> nextAllocationStates;

  int get totalPaise => allocations.fold(
    0,
    (total, allocation) => total + allocation.amountPaise,
  );
}

/// Pure deterministic allocator used by the Firestore transaction layer.
///
/// Each bill balance represents only incremental debt. The first projection
/// includes the opening balance; later projections include current charges and
/// signed adjustments, never the cumulative `totalDuePaise` again.
class PaymentAllocationEngine {
  const PaymentAllocationEngine();

  PaymentAllocationPlan allocate({
    required int amountPaise,
    required int accountOutstandingPaise,
    required Iterable<OutstandingBill> bills,
    String preferredBillId = '',
  }) {
    if (amountPaise <= 0) {
      throw const AppException('The payment amount must be positive.');
    }
    if (accountOutstandingPaise <= 0) {
      throw const AppException(
        'This customer has no positive outstanding balance.',
        code: 'nothing-outstanding',
      );
    }
    if (amountPaise > accountOutstandingPaise) {
      throw const AppException(
        'The payment is greater than the current outstanding balance.',
        code: 'overpayment',
      );
    }

    final sorted =
        bills.toList()..sort((left, right) {
          final byMonth = left.billingMonth.compareTo(right.billingMonth);
          return byMonth != 0 ? byMonth : left.billId.compareTo(right.billId);
        });
    final seen = <String>{};
    for (final bill in sorted) {
      if (!seen.add(bill.billId) ||
          bill.billId.isEmpty ||
          bill.billingMonth.isEmpty ||
          bill.allocatedPaise < 0 ||
          bill.reversedPaise < 0 ||
          bill.outstandingPaise < 0) {
        throw const AppException(
          'The bill-balance projection is invalid.',
          code: 'invalid-bill-balance',
        );
      }
    }
    if (preferredBillId.isNotEmpty) {
      final index = sorted.indexWhere((bill) => bill.billId == preferredBillId);
      if (index < 0 || sorted[index].allocatablePaise == 0) {
        throw const AppException(
          'The selected bill no longer has an outstanding balance.',
          code: 'preferred-bill-unavailable',
        );
      }
      sorted.insert(0, sorted.removeAt(index));
    }

    var remaining = amountPaise;
    final allocations = <BillAllocation>[];
    for (final bill in sorted) {
      if (remaining == 0) break;
      final available = bill.allocatablePaise;
      if (available == 0) continue;
      if (allocations.length == maximumPaymentAllocations) {
        throw const AppException(
          'This payment spans too many billing months. Record a smaller payment first.',
          code: 'allocation-limit',
        );
      }
      final amount = math.min(remaining, available);
      allocations.add(
        BillAllocation(
          billId: bill.billId,
          billingMonth: bill.billingMonth,
          amountPaise: amount,
        ),
      );
      remaining -= amount;
    }
    if (remaining != 0) {
      throw const AppException(
        'The account balance changed. Refresh before confirming payment.',
        code: 'collection-state-changed',
      );
    }
    return PaymentAllocationPlan(allocations: List.unmodifiable(allocations));
  }

  ReversalAllocationPlan reverse({
    required int amountPaise,
    required List<PaymentAllocationState> allocationStates,
  }) {
    if (amountPaise <= 0) {
      throw const AppException('The reversal amount must be positive.');
    }
    final refundable = allocationStates.fold<int>(
      0,
      (total, allocation) => total + allocation.refundablePaise,
    );
    if (allocationStates.isEmpty ||
        allocationStates.length > maximumPaymentAllocations ||
        allocationStates.any(
          (allocation) =>
              allocation.billId.isEmpty ||
              allocation.amountPaise <= 0 ||
              allocation.reversedPaise < 0 ||
              allocation.reversedPaise > allocation.amountPaise,
        )) {
      throw const AppException(
        'The payment allocation history is invalid.',
        code: 'invalid-payment-allocation',
      );
    }
    if (amountPaise > refundable) {
      throw const AppException(
        'The reversal exceeds the payment’s remaining confirmed amount.',
        code: 'reversal-exceeds-payment',
      );
    }

    final next = [...allocationStates];
    final restored = <BillAllocation>[];
    var remaining = amountPaise;
    // Undo the newest allocation first, preserving oldest-bill-first payoff.
    for (var index = next.length - 1; index >= 0 && remaining > 0; index--) {
      final available = next[index].refundablePaise;
      if (available == 0) continue;
      final amount = math.min(remaining, available);
      next[index] = next[index].reverse(amount);
      restored.add(
        BillAllocation(
          billId: next[index].billId,
          billingMonth: next[index].billingMonth,
          amountPaise: amount,
        ),
      );
      remaining -= amount;
    }
    return ReversalAllocationPlan(
      allocations: List.unmodifiable(restored),
      nextAllocationStates: List.unmodifiable(next),
    );
  }
}
