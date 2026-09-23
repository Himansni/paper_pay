import 'dart:math' as math;

enum SaasSubscriptionStatus {
  trial('trial', 'Free Trial'),
  active('active', 'Active Subscription'),
  gracePeriod('gracePeriod', 'Grace Period'),
  expired('expired', 'Subscription Expired');

  const SaasSubscriptionStatus(this.value, this.label);

  final String value;
  final String label;

  static SaasSubscriptionStatus fromValue(Object? value) =>
      values.firstWhere((item) => item.value == value, orElse: () => trial);
}

enum SaasPlanTier {
  trial('trial', 'Free 30-Day Trial'),
  starter('starter', 'Starter Plan'),
  growth('growth', 'Growth Plan'),
  agencyPro('agencyPro', 'Agency Pro Plan');

  const SaasPlanTier(this.id, this.label);

  final String id;
  final String label;

  static SaasPlanTier fromId(String? id) =>
      values.firstWhere((tier) => tier.id == id, orElse: () => trial);
}

class SaasPlan {
  const SaasPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.customerLimit,
    required this.employeeLimit,
    required this.features,
    required this.priceDescription,
    this.isPopular = false,
  });

  final String id;
  final String name;
  final String description;
  final int customerLimit;
  final int employeeLimit;
  final List<String> features;
  final String priceDescription;
  final bool isPopular;

  static List<SaasPlan> get catalog => const [
    SaasPlan(
      id: 'starter',
      name: 'Starter Plan',
      description: 'Ideal for independent newspaper distributors and single-line agencies.',
      customerLimit: 300,
      employeeLimit: 3,
      priceDescription: 'Tiered subscription (Configurable by agency scale)',
      features: [
        'Up to 300 active customer records',
        'Up to 3 delivery employee logins',
        'Daily morning delivery route checklist',
        'Monthly billing calculation & ledger',
        'Agency-owned direct UPI QR collections',
        'WhatsApp bill and statement sharing',
      ],
    ),
    SaasPlan(
      id: 'growth',
      name: 'Growth Plan',
      description: 'For growing agencies with multiple lines, delivery boys, and areas.',
      customerLimit: 1000,
      employeeLimit: 10,
      isPopular: true,
      priceDescription: 'Tiered subscription (Configurable by agency scale)',
      features: [
        'Up to 1,000 active customer records',
        'Up to 10 delivery employee logins',
        'Multi-area line management & reassignments',
        'Bulk CSV & Excel customer onboarding',
        'Real-time collection reconciliation',
        'Circulation count reports for depot pickup',
        'Customer self-service pause & stop logs',
      ],
    ),
    SaasPlan(
      id: 'agencyPro',
      name: 'Agency Pro Plan',
      description: 'Comprehensive operations and enterprise management for large agencies.',
      customerLimit: 10000,
      employeeLimit: 100,
      priceDescription: 'Tiered subscription (Configurable by agency scale)',
      features: [
        'Unlimited customer records',
        'Unlimited delivery employee accounts',
        'Multi-depot circulation distribution',
        'Comprehensive audit trail & reversals',
        'Automated monthly financial statement exports',
        'Dedicated account manager & priority support',
      ],
    ),
  ];
}

class SaasSubscription {
  const SaasSubscription({
    required this.businessId,
    required this.planId,
    required this.status,
    required this.trialStartsAt,
    required this.trialEndsAt,
    this.currentPeriodStartsAt,
    this.currentPeriodEndsAt,
    this.graceDays = 7,
    this.customerLimit = 500,
    this.employeeLimit = 10,
    this.lastPaymentReference,
    this.updatedAt,
  });

  final String businessId;
  final String planId;
  final SaasSubscriptionStatus status;
  final DateTime trialStartsAt;
  final DateTime trialEndsAt;
  final DateTime? currentPeriodStartsAt;
  final DateTime? currentPeriodEndsAt;
  final int graceDays;
  final int customerLimit;
  final int employeeLimit;
  final String? lastPaymentReference;
  final DateTime? updatedAt;

  /// Creates authoritative initial 30-day trial attached to the agency's activation timestamp.
  factory SaasSubscription.initialTrial({
    required String businessId,
    required DateTime activationTime,
  }) {
    final endsAt = activationTime.add(const Duration(days: 30));
    return SaasSubscription(
      businessId: businessId,
      planId: SaasPlanTier.trial.id,
      status: SaasSubscriptionStatus.trial,
      trialStartsAt: activationTime,
      trialEndsAt: endsAt,
      graceDays: 7,
      customerLimit: 500,
      employeeLimit: 10,
    );
  }

  factory SaasSubscription.fromMap(
    String businessId,
    Map<String, dynamic>? data, {
    DateTime? fallbackActivationTime,
  }) {
    if (data == null || data.isEmpty) {
      final activation = fallbackActivationTime ?? DateTime.now();
      return SaasSubscription.initialTrial(
        businessId: businessId,
        activationTime: activation,
      );
    }

    final trialStart = _parseDate(data['trialStartsAt']) ??
        fallbackActivationTime ??
        DateTime.now();
    final trialEnd = _parseDate(data['trialEndsAt']) ??
        trialStart.add(const Duration(days: 30));

    return SaasSubscription(
      businessId: businessId,
      planId: data['planId'] as String? ?? SaasPlanTier.trial.id,
      status: SaasSubscriptionStatus.fromValue(data['status']),
      trialStartsAt: trialStart,
      trialEndsAt: trialEnd,
      currentPeriodStartsAt: _parseDate(data['currentPeriodStartsAt']),
      currentPeriodEndsAt: _parseDate(data['currentPeriodEndsAt']),
      graceDays: data['graceDays'] as int? ?? 7,
      customerLimit: data['customerLimit'] as int? ?? 500,
      employeeLimit: data['employeeLimit'] as int? ?? 10,
      lastPaymentReference: data['lastPaymentReference'] as String?,
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'businessId': businessId,
    'planId': planId,
    'status': status.value,
    'trialStartsAt': trialStartsAt.toIso8601String(),
    'trialEndsAt': trialEndsAt.toIso8601String(),
    if (currentPeriodStartsAt != null)
      'currentPeriodStartsAt': currentPeriodStartsAt!.toIso8601String(),
    if (currentPeriodEndsAt != null)
      'currentPeriodEndsAt': currentPeriodEndsAt!.toIso8601String(),
    'graceDays': graceDays,
    'customerLimit': customerLimit,
    'employeeLimit': employeeLimit,
    if (lastPaymentReference != null)
      'lastPaymentReference': lastPaymentReference,
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  /// Authoritative effective status evaluated against the current timestamp.
  SaasSubscriptionStatus effectiveStatus(DateTime now) {
    if (status == SaasSubscriptionStatus.active) {
      if (currentPeriodEndsAt == null) return SaasSubscriptionStatus.active;
      if (now.isBefore(currentPeriodEndsAt!)) {
        return SaasSubscriptionStatus.active;
      }
      final graceEnd = currentPeriodEndsAt!.add(Duration(days: graceDays));
      if (now.isBefore(graceEnd)) {
        return SaasSubscriptionStatus.gracePeriod;
      }
      return SaasSubscriptionStatus.expired;
    }

    // Trial evaluation
    if (now.isBefore(trialEndsAt)) {
      return SaasSubscriptionStatus.trial;
    }
    final trialGraceEnd = trialEndsAt.add(Duration(days: graceDays));
    if (now.isBefore(trialGraceEnd)) {
      return SaasSubscriptionStatus.gracePeriod;
    }
    return SaasSubscriptionStatus.expired;
  }

  /// Calculates days remaining in the active trial or paid period.
  int daysRemaining(DateTime now) {
    final effectiveEnd = status == SaasSubscriptionStatus.active
        ? (currentPeriodEndsAt ?? trialEndsAt)
        : trialEndsAt;
    final diff = effectiveEnd.difference(now).inSeconds;
    if (diff <= 0) return 0;
    return (diff / 86400).ceil();
  }

  /// Calculates grace days remaining when the trial or subscription is past expiry.
  int graceDaysRemaining(DateTime now) {
    final effectiveEnd = status == SaasSubscriptionStatus.active
        ? (currentPeriodEndsAt ?? trialEndsAt)
        : trialEndsAt;
    final graceEnd = effectiveEnd.add(Duration(days: graceDays));
    final diff = graceEnd.difference(now).inSeconds;
    if (diff <= 0) return 0;
    return math.min(graceDays, (diff / 86400).ceil());
  }

  /// True if the account has expired past both normal entitlement and grace period.
  bool isReadOnly(DateTime now) =>
      effectiveStatus(now) == SaasSubscriptionStatus.expired;

  /// True if the account can perform mutations (customer adding, billing, collections).
  bool canPerformWrites(DateTime now) => !isReadOnly(now);

  /// True if the account is in grace period.
  bool isInGracePeriod(DateTime now) =>
      effectiveStatus(now) == SaasSubscriptionStatus.gracePeriod;

  /// True if agency is currently within free trial.
  bool isTrial(DateTime now) =>
      effectiveStatus(now) == SaasSubscriptionStatus.trial;

  static DateTime? _parseDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
