import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/billing/domain/billing_models.dart';
import 'package:paper_route/features/billing/domain/monthly_billing_engine.dart';

void main() {
  const engine = MonthlyBillingEngine();
  const may = LocalDate(2026, 5, 1);

  NewspaperPriceSchedule schedule({Map<LocalDate, int> overrides = const {}}) {
    return NewspaperPriceSchedule(
      newspaperId: 'times',
      defaultPricePaise: 500,
      dateOverrides: overrides,
    );
  }

  test('uses the price for every delivery date instead of current price', () {
    final result = engine.calculate(
      BillingRequest(
        customerId: 'customer-1',
        billingMonth: may,
        subscriptions: const [
          NewspaperSubscription(
            id: 'subscription-1',
            newspaperId: 'times',
            startDate: LocalDate(2026, 5, 1),
          ),
        ],
        priceSchedules: [
          schedule(overrides: {const LocalDate(2026, 5, 15): 600}),
        ],
      ),
    );

    expect(result.charges, hasLength(31));
    expect(result.currentChargesPaise, 15600);
  });

  test('honors start, end, pause, and no-delivery dates', () {
    final result = engine.calculate(
      BillingRequest(
        customerId: 'customer-1',
        billingMonth: may,
        subscriptions: const [
          NewspaperSubscription(
            id: 'subscription-1',
            newspaperId: 'times',
            startDate: LocalDate(2026, 5, 10),
            endDate: LocalDate(2026, 5, 20),
            pauses: [
              LocalDateRange(
                start: LocalDate(2026, 5, 12),
                end: LocalDate(2026, 5, 14),
              ),
            ],
          ),
        ],
        priceSchedules: [schedule()],
        deliveryExceptions: const [
          DeliveryException.noDelivery(
            subscriptionId: 'subscription-1',
            date: LocalDate(2026, 5, 18),
          ),
        ],
      ),
    );

    expect(result.charges, hasLength(7));
    expect(result.currentChargesPaise, 3500);
  });

  test('applies quantity and authorized customer pricing precedence', () {
    final result = engine.calculate(
      BillingRequest(
        customerId: 'customer-1',
        billingMonth: may,
        subscriptions: const [
          NewspaperSubscription(
            id: 'subscription-1',
            newspaperId: 'times',
            startDate: LocalDate(2026, 5, 1),
            endDate: LocalDate(2026, 5, 2),
            quantity: 2,
            fixedPricePaise: 450,
          ),
        ],
        priceSchedules: [
          schedule(overrides: {const LocalDate(2026, 5, 1): 600}),
        ],
        customerDatePrices: {
          'subscription-1': {const LocalDate(2026, 5, 2): 400},
        },
      ),
    );

    expect(result.currentChargesPaise, 1700);
  });

  test('includes previous balance and signed adjustments', () {
    final result = engine.calculate(
      BillingRequest(
        customerId: 'customer-1',
        billingMonth: may,
        subscriptions: const [],
        priceSchedules: const [],
        previousBalancePaise: 60000,
        adjustmentsPaise: -5000,
      ),
    );

    expect(result.totalDuePaise, 55000);
  });

  test('rejects duplicate customer, subscription, and date charges', () {
    const duplicate = NewspaperSubscription(
      id: 'subscription-1',
      newspaperId: 'times',
      startDate: LocalDate(2026, 5, 1),
      endDate: LocalDate(2026, 5, 1),
    );

    expect(
      () => engine.calculate(
        BillingRequest(
          customerId: 'customer-1',
          billingMonth: may,
          subscriptions: const [duplicate, duplicate],
          priceSchedules: [schedule()],
        ),
      ),
      throwsA(isA<BillingException>()),
    );
  });
}
