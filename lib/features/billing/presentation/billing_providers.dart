import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/billing/data/firebase_billing_repository.dart';
import 'package:paper_route/features/billing/domain/billing_repository.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';

// Including business, customer, and month in the Riverpod key keeps live bill
// state tenant-scoped and prevents one month's data from being reused for another.
typedef BillDocumentKey =
    ({String businessId, String customerId, String billingMonth});

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return FirebaseBillingRepository.fromDefaultApp();
});

final monthlyBillProvider = StreamProvider.autoDispose
    .family<FinalizedMonthlyBill?, BillDocumentKey>((ref, key) {
      return ref
          .watch(billingRepositoryProvider)
          .watchBill(
            businessId: key.businessId,
            customerId: key.customerId,
            billingMonth: key.billingMonth,
          );
    });

final billingAdjustmentsProvider = StreamProvider.autoDispose
    .family<List<BillingAdjustment>, BillDocumentKey>((ref, key) {
      return ref
          .watch(billingRepositoryProvider)
          .watchAdjustments(
            businessId: key.businessId,
            customerId: key.customerId,
            billingMonth: key.billingMonth,
          );
    });
