import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/billing/domain/billing_models.dart';

/// Pure, deterministic monthly calculation. Finalized bill documents store the
/// returned charge snapshot so future price changes cannot rewrite history.
class MonthlyBillingEngine {
  const MonthlyBillingEngine();

  BillingResult calculate(BillingRequest request) {
    if (request.billingMonth.day != 1) {
      throw const BillingException('Billing month must use its first day.');
    }
    for (final subscription in request.subscriptions) {
      for (final pause in subscription.pauses) {
        if (pause.end.isBefore(pause.start)) {
          throw BillingException(
            'Pause end date is before its start for ${subscription.id}.',
          );
        }
      }
    }

    final schedules = {
      for (final schedule in request.priceSchedules)
        schedule.newspaperId: schedule,
    };
    final noDeliveryKeys = {
      for (final exception in request.deliveryExceptions)
        '${exception.subscriptionId}:${exception.date}',
    };
    final seenChargeKeys = <String>{};
    final charges = <BillCharge>[];

    for (final subscription in request.subscriptions) {
      final schedule = schedules[subscription.newspaperId];
      if (schedule == null) {
        throw BillingException(
          'Missing price schedule for newspaper ${subscription.newspaperId}.',
        );
      }

      for (var day = 1; day <= request.billingMonth.daysInMonth; day++) {
        final date = LocalDate(
          request.billingMonth.year,
          request.billingMonth.month,
          day,
        );
        if (!subscription.isDeliveredOn(date)) continue;
        if (noDeliveryKeys.contains('${subscription.id}:$date')) continue;

        final chargeKey = '${request.customerId}:${subscription.id}:$date';
        if (!seenChargeKeys.add(chargeKey)) {
          throw BillingException('Duplicate daily charge detected: $chargeKey');
        }

        final unitPrice =
            request.customerDatePrices[subscription.id]?[date] ??
            subscription.fixedPricePaise ??
            schedule.priceOn(date);
        if (unitPrice < 0) {
          throw BillingException('A newspaper price cannot be negative.');
        }

        charges.add(
          BillCharge(
            chargeKey: chargeKey,
            subscriptionId: subscription.id,
            newspaperId: subscription.newspaperId,
            serviceDate: date,
            unitPricePaise: unitPrice,
            quantity: subscription.quantity,
          ),
        );
      }
    }

    charges.sort((left, right) {
      final byDate = left.serviceDate.compareTo(right.serviceDate);
      return byDate != 0
          ? byDate
          : left.subscriptionId.compareTo(right.subscriptionId);
    });

    return BillingResult(
      customerId: request.customerId,
      billingMonth: request.billingMonth,
      charges: List.unmodifiable(charges),
      previousBalancePaise: request.previousBalancePaise,
      adjustmentsPaise: request.adjustmentsPaise,
    );
  }
}
