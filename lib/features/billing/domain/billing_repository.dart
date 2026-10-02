import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';

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

  Future<FinalizedMonthlyBill> finalizeBill({
    required AppUser actor,
    required String customerId,
    required LocalDate month,
  });

  Future<MonthlyBillPreview> previewManualBill({
    required AppUser actor,
    required ManualBillInput input,
  });

  Future<FinalizedMonthlyBill> finalizeManualBill({
    required AppUser actor,
    required ManualBillInput input,
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

  Future<BulkMonthEndBillSummary> previewBulkMonthEndBills({
    required AppUser actor,
    required String publicationId,
    required LocalDate month,
  });

  Stream<BulkMonthEndProgress> generateBulkMonthEndBills({
    required AppUser actor,
    required String publicationId,
    required LocalDate month,
  });

  Future<void> saveBillingMonthlyPrice({
    required AppUser actor,
    required String billingMonth,
    required String newspaperId,
    required String newspaperName,
    required int pricePaise,
    required PricingBasis pricingBasis,
  });

  Stream<List<BillingMonthlyPrice>> watchBillingMonthlyPrices({
    required String businessId,
    required String billingMonth,
  });

  Future<void> recordBillingFailure({
    required AppUser actor,
    required String customerId,
    required String billingMonth,
    required String error,
  });

  Future<void> clearBillingFailure({
    required String businessId,
    required String customerId,
    required String billingMonth,
  });
}

enum BulkMonthEndSubscriberStatus {
  readyToBill,
  alreadyFinalized,
  missingPricing,
  pausedNoCharge,
}

class BulkMonthEndSubscriberItem {
  const BulkMonthEndSubscriberItem({
    required this.customerId,
    required this.customerName,
    required this.customerCode,
    required this.status,
    required this.totalDuePaise,
    this.statusMessage,
  });

  final String customerId;
  final String customerName;
  final String customerCode;
  final BulkMonthEndSubscriberStatus status;
  final int totalDuePaise;
  final String? statusMessage;
}

class BulkMonthEndBillSummary {
  const BulkMonthEndBillSummary({
    required this.publicationId,
    required this.publicationName,
    required this.month,
    required this.eligibleSubscribersCount,
    required this.alreadyFinalizedCount,
    required this.readyToBillCount,
    required this.missingPricingCount,
    required this.pausedNoChargeCount,
    required this.subscribers,
  });

  final String publicationId;
  final String publicationName;
  final LocalDate month;
  final int eligibleSubscribersCount;
  final int alreadyFinalizedCount;
  final int readyToBillCount;
  final int missingPricingCount;
  final int pausedNoChargeCount;
  final List<BulkMonthEndSubscriberItem> subscribers;
}

class BulkMonthEndProgress {
  const BulkMonthEndProgress({
    required this.totalCount,
    required this.completedCount,
    required this.alreadyFinalizedCount,
    required this.failedCount,
    required this.currentCustomerName,
    required this.isDone,
    this.errorMessage,
  });

  final int totalCount;
  final int completedCount;
  final int alreadyFinalizedCount;
  final int failedCount;
  final String currentCustomerName;
  final bool isDone;
  final String? errorMessage;
}
