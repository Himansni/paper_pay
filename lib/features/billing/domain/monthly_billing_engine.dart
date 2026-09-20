import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/billing/domain/billing_models.dart';

/// Pure, deterministic monthly calculation. Finalized bill documents store the
/// returned charge snapshot so future price changes cannot rewrite history.
class MonthlyBillingEngine {
  const MonthlyBillingEngine();

  BillingResult calculate(BillingRequest request) {
    _validateRequest(request);

    final schedules = <String, NewspaperPriceSchedule>{};
    for (final schedule in request.priceSchedules) {
      if (schedules.containsKey(schedule.newspaperId)) {
        throw BillingException(
          'Duplicate price schedule for newspaper ${schedule.newspaperId}.',
        );
      }
      schedules[schedule.newspaperId] = schedule;
    }

    // Delivery exceptions and charge keys are normalized into sets so each
    // subscription/date is either skipped or charged exactly once.
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

        // A dated customer price is most specific, followed by the authorized
        // subscription price, then the newspaper's catalog schedule.
        final unitPrice =
            request.customerDatePrices[subscription.id]?[date] ??
            subscription.fixedPricePaise ??
            schedule.priceOn(date);

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

  void _validateRequest(BillingRequest request) {
    _requireValidDate(request.billingMonth, 'Billing month');
    if (request.billingMonth.day != 1) {
      throw const BillingException('Billing month must use its first day.');
    }

    final subscriptionIds = <String>{};
    for (final subscription in request.subscriptions) {
      if (subscription.id.trim().isEmpty) {
        throw const BillingException('A subscription ID cannot be empty.');
      }
      if (!subscriptionIds.add(subscription.id)) {
        throw BillingException(
          'Duplicate subscription ID: ${subscription.id}.',
        );
      }
      if (subscription.newspaperId.trim().isEmpty) {
        throw BillingException(
          'A newspaper ID is required for ${subscription.id}.',
        );
      }
      _requireValidDate(
        subscription.startDate,
        'Subscription start date for ${subscription.id}',
      );
      final endDate = subscription.endDate;
      if (endDate != null) {
        _requireValidDate(
          endDate,
          'Subscription end date for ${subscription.id}',
        );
        if (endDate.isBefore(subscription.startDate)) {
          throw BillingException(
            'Subscription end date is before its start for ${subscription.id}.',
          );
        }
      }
      if (subscription.quantity <= 0) {
        throw BillingException(
          'Subscription quantity must be positive for ${subscription.id}.',
        );
      }
      if (subscription.fixedPricePaise != null &&
          subscription.fixedPricePaise! < 0) {
        throw BillingException(
          'A subscription price cannot be negative for ${subscription.id}.',
        );
      }
      if (subscription.deliveryWeekdays.isEmpty ||
          subscription.deliveryWeekdays.any(
            (weekday) => weekday < 1 || weekday > 7,
          )) {
        throw BillingException(
          'Delivery weekdays must use ISO values 1 through 7 for ${subscription.id}.',
        );
      }

      for (final pause in subscription.pauses) {
        _requireValidDate(
          pause.start,
          'Pause start date for ${subscription.id}',
        );
        _requireValidDate(pause.end, 'Pause end date for ${subscription.id}');
        if (pause.end.isBefore(pause.start)) {
          throw BillingException(
            'Pause end date is before its start for ${subscription.id}.',
          );
        }
        if (pause.start.isBefore(subscription.startDate) ||
            (endDate != null && pause.end.isAfter(endDate))) {
          throw BillingException(
            'A pause is outside the subscription dates for ${subscription.id}.',
          );
        }
      }
      for (var left = 0; left < subscription.pauses.length; left++) {
        for (
          var right = left + 1;
          right < subscription.pauses.length;
          right++
        ) {
          if (subscription.pauses[left].overlaps(subscription.pauses[right])) {
            throw BillingException(
              'Overlapping pauses for subscription ${subscription.id}.',
            );
          }
        }
      }
    }

    final scheduleIds = <String>{};
    for (final schedule in request.priceSchedules) {
      if (schedule.newspaperId.trim().isEmpty) {
        throw const BillingException('A price schedule ID cannot be empty.');
      }
      if (!scheduleIds.add(schedule.newspaperId)) {
        throw BillingException(
          'Duplicate price schedule for newspaper ${schedule.newspaperId}.',
        );
      }
      if (schedule.defaultPricePaise < 0) {
        throw BillingException(
          'The default price cannot be negative for ${schedule.newspaperId}.',
        );
      }
      for (final entry in schedule.dateOverrides.entries) {
        _requireValidDate(
          entry.key,
          'Price override date for ${schedule.newspaperId}',
        );
        if (entry.value < 0) {
          throw BillingException(
            'A newspaper price cannot be negative for ${schedule.newspaperId}.',
          );
        }
      }
      for (final period in schedule.effectivePeriods) {
        _requireValidDate(
          period.startDate,
          'Price period start date for ${schedule.newspaperId}',
        );
        _requireValidDate(
          period.endDate,
          'Price period end date for ${schedule.newspaperId}',
        );
        if (period.endDate.isBefore(period.startDate)) {
          throw BillingException(
            'Price period end date is before its start for ${schedule.newspaperId}.',
          );
        }
        if (period.pricePaise < 0) {
          throw BillingException(
            'A newspaper price cannot be negative for ${schedule.newspaperId}.',
          );
        }
      }
      for (var left = 0; left < schedule.effectivePeriods.length; left++) {
        final leftPeriod = schedule.effectivePeriods[left];
        final leftRange = LocalDateRange(
          start: leftPeriod.startDate,
          end: leftPeriod.endDate,
        );
        for (
          var right = left + 1;
          right < schedule.effectivePeriods.length;
          right++
        ) {
          final rightPeriod = schedule.effectivePeriods[right];
          if (leftRange.overlaps(
            LocalDateRange(
              start: rightPeriod.startDate,
              end: rightPeriod.endDate,
            ),
          )) {
            throw BillingException(
              'Conflicting price periods for ${schedule.newspaperId}.',
            );
          }
        }
      }
    }

    for (final subscriptionEntry in request.customerDatePrices.entries) {
      if (!subscriptionIds.contains(subscriptionEntry.key)) {
        throw BillingException(
          'Customer pricing references unknown subscription ${subscriptionEntry.key}.',
        );
      }
      for (final priceEntry in subscriptionEntry.value.entries) {
        _requireValidDate(
          priceEntry.key,
          'Customer price date for ${subscriptionEntry.key}',
        );
        if (priceEntry.value < 0) {
          throw BillingException(
            'A customer price cannot be negative for ${subscriptionEntry.key}.',
          );
        }
      }
    }

    for (final exception in request.deliveryExceptions) {
      if (!subscriptionIds.contains(exception.subscriptionId)) {
        throw BillingException(
          'Delivery exception references unknown subscription ${exception.subscriptionId}.',
        );
      }
      _requireValidDate(
        exception.date,
        'Delivery exception date for ${exception.subscriptionId}',
      );
    }
  }

  void _requireValidDate(LocalDate date, String label) {
    if (!date.isValid) throw BillingException('$label is invalid: $date.');
  }
}
