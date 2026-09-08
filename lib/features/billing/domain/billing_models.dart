import 'package:paper_route/core/domain/local_date.dart';

class NewspaperSubscription {
  const NewspaperSubscription({
    required this.id,
    required this.newspaperId,
    required this.startDate,
    this.endDate,
    this.quantity = 1,
    this.fixedPricePaise,
    this.pauses = const [],
  }) : assert(quantity > 0),
       assert(fixedPricePaise == null || fixedPricePaise >= 0);

  final String id;
  final String newspaperId;
  final LocalDate startDate;
  final LocalDate? endDate;
  final int quantity;

  /// Authorized customer-specific price. When present it takes precedence over
  /// catalog prices until the subscription is replaced or ended.
  final int? fixedPricePaise;
  final List<LocalDateRange> pauses;

  bool isDeliveredOn(LocalDate date) {
    if (date.isBefore(startDate)) return false;
    if (endDate != null && date.isAfter(endDate!)) return false;
    return !pauses.any((pause) => pause.contains(date));
  }
}

class NewspaperPriceSchedule {
  const NewspaperPriceSchedule({
    required this.newspaperId,
    required this.defaultPricePaise,
    this.dateOverrides = const {},
  }) : assert(defaultPricePaise >= 0);

  final String newspaperId;
  final int defaultPricePaise;
  final Map<LocalDate, int> dateOverrides;

  int priceOn(LocalDate date) => dateOverrides[date] ?? defaultPricePaise;
}

class DeliveryException {
  const DeliveryException.noDelivery({
    required this.subscriptionId,
    required this.date,
  });

  final String subscriptionId;
  final LocalDate date;
}

class BillingRequest {
  const BillingRequest({
    required this.customerId,
    required this.billingMonth,
    required this.subscriptions,
    required this.priceSchedules,
    this.deliveryExceptions = const [],
    this.customerDatePrices = const {},
    this.previousBalancePaise = 0,
    this.adjustmentsPaise = 0,
  });

  final String customerId;
  final LocalDate billingMonth;
  final List<NewspaperSubscription> subscriptions;
  final List<NewspaperPriceSchedule> priceSchedules;
  final List<DeliveryException> deliveryExceptions;

  /// subscriptionId -> date -> price in paise.
  final Map<String, Map<LocalDate, int>> customerDatePrices;
  final int previousBalancePaise;
  final int adjustmentsPaise;
}

class BillCharge {
  const BillCharge({
    required this.chargeKey,
    required this.subscriptionId,
    required this.newspaperId,
    required this.serviceDate,
    required this.unitPricePaise,
    required this.quantity,
  });

  final String chargeKey;
  final String subscriptionId;
  final String newspaperId;
  final LocalDate serviceDate;
  final int unitPricePaise;
  final int quantity;

  int get totalPaise => unitPricePaise * quantity;
}

class BillingResult {
  BillingResult({
    required this.customerId,
    required this.billingMonth,
    required this.charges,
    required this.previousBalancePaise,
    required this.adjustmentsPaise,
  });

  final String customerId;
  final LocalDate billingMonth;
  final List<BillCharge> charges;
  final int previousBalancePaise;
  final int adjustmentsPaise;

  int get currentChargesPaise =>
      charges.fold(0, (total, charge) => total + charge.totalPaise);

  int get totalDuePaise =>
      currentChargesPaise + previousBalancePaise + adjustmentsPaise;

  Map<String, int> get newspaperSubtotalsPaise {
    final subtotals = <String, int>{};
    for (final charge in charges) {
      subtotals.update(
        charge.newspaperId,
        (value) => value + charge.totalPaise,
        ifAbsent: () => charge.totalPaise,
      );
    }
    return subtotals;
  }
}

class BillingException implements Exception {
  const BillingException(this.message);

  final String message;

  @override
  String toString() => message;
}
