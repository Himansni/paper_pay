import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';

abstract interface class SubscriptionRepository {
  Stream<List<CustomerSubscription>> watchCustomerSubscriptions({
    required String businessId,
    required String customerId,
  });

  Stream<CustomerSubscription?> watchSubscription({
    required String businessId,
    required String customerId,
    required String subscriptionId,
  });

  Stream<List<SubscriptionVersion>> watchVersions({
    required String businessId,
    required String customerId,
    required String subscriptionId,
  });

  Stream<List<SubscriptionPause>> watchPauses({
    required String businessId,
    required String customerId,
    required String subscriptionId,
  });

  Stream<List<SubscriptionAuditEntry>> watchHistory({
    required String businessId,
    required String customerId,
    required String subscriptionId,
  });

  Future<String> createSubscription({
    required AppUser actor,
    required String customerId,
    required SubscriptionInput input,
  });

  Future<void> replaceTerms({
    required AppUser actor,
    required String customerId,
    required String subscriptionId,
    required LocalDate effectiveFrom,
    required SubscriptionInput replacement,
  });

  Future<void> addPause({
    required AppUser actor,
    required String customerId,
    required String subscriptionId,
    required LocalDate startDate,
    required LocalDate? endDate,
    required String reason,
  });

  Future<void> resumeSubscription({
    required AppUser actor,
    required String customerId,
    required String subscriptionId,
    required String pauseId,
    required LocalDate resumeDate,
  });

  Future<void> endSubscription({
    required AppUser actor,
    required String customerId,
    required String subscriptionId,
    required LocalDate endDate,
  });
}
