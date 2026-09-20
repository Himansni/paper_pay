import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';

// The UI depends on this contract while the Firebase implementation owns
// tenant paths, source validation, transactions, and audit persistence.
abstract interface class BillingRepository {
  Future<BillingWorkspaceResult> fetchWorkspace({
    required AppUser actor,
    required LocalDate month,
    BillingWorkspaceCursor? cursor,
    int pageSize = 25,
  });

  Future<MonthlyBillPreview> previewBill({
    required AppUser actor,
    required String customerId,
    required LocalDate month,
  });

  // Finalization must be safe to retry: the same customer/month returns the
  // existing deterministic bill instead of creating another financial record.
  Future<FinalizedMonthlyBill> finalizeBill({
    required AppUser actor,
    required String customerId,
    required LocalDate month,
  });

  Future<String> createAdjustment({
    required AppUser actor,
    required String customerId,
    required BillingAdjustmentInput input,
  });

  Stream<FinalizedMonthlyBill?> watchBill({
    required String businessId,
    required String customerId,
    required String billingMonth,
  });

  Future<BillLinePage> fetchBillLines({
    required String businessId,
    required String customerId,
    required String billingMonth,
    BillLinePageCursor? cursor,
    int pageSize = 50,
  });

  Stream<List<BillingAdjustment>> watchAdjustments({
    required String businessId,
    required String customerId,
    required String billingMonth,
  });
}
