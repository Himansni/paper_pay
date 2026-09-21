import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';

/// Boundary between collection screens and the persistent financial ledger.
///
/// Implementations preserve tenant/customer authorization and atomic balance
/// updates. Firestore Rules remain authoritative even when the UI has already
/// hidden an action from an unauthorized employee.
abstract interface class CollectionsRepository {
  Stream<CustomerOutstandingSummary> watchCustomerOutstanding({
    required String businessId,
    required String customerId,
  });

  Future<CustomerOutstandingSummary> fetchCustomerOutstanding({
    required AppUser actor,
    required String customerId,
  });

  Future<PaymentHistoryPage> fetchPaymentHistory({
    required AppUser actor,
    String? customerId,
    PaymentHistoryCursor? cursor,
    int pageSize = 25,
  });

  Future<ConfirmedPayment> getPayment({
    required AppUser actor,
    required String customerId,
    required String paymentId,
  });

  Future<PaymentConfirmationResult> confirmPayment({
    required AppUser actor,
    required String customerId,
    required PaymentConfirmationInput input,
  });

  Future<PaymentReversalResult> reversePayment({
    required AppUser actor,
    required String customerId,
    required PaymentReversalInput input,
  });

  Stream<UpiSettings> watchUpiSettings(String businessId);

  Future<void> updateUpiSettings({
    required AppUser actor,
    required UpiSettingsInput input,
  });
}
