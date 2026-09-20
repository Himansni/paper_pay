import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/billing/domain/billing_models.dart';
import 'package:paper_route/features/billing/domain/monthly_billing_engine.dart';

void main() {
  const engine = MonthlyBillingEngine();

  group('LocalDate calendar semantics', () {
    test('parses canonical leap dates and exposes ISO weekdays', () {
      final leapDay = LocalDate.parse('2024-02-29');

      expect(leapDay, const LocalDate(2024, 2, 29));
      expect(leapDay.isoWeekday, DateTime.thursday);
      expect(leapDay.toString(), '2024-02-29');
    });

    test('rejects noncanonical and impossible calendar dates', () {
      for (final value in [
        '2023-02-29',
        '2026-04-31',
        '2026-2-01',
        '2026-02-1',
        '0000-01-01',
        '2026-01-01T00:00:00Z',
      ]) {
        expect(
          () => LocalDate.parse(value),
          throwsFormatException,
          reason: value,
        );
      }

      const impossible = LocalDate(2026, 2, 30);
      expect(impossible.isValid, isFalse);
      expect(impossible.toDateTime, throwsStateError);
    });
  });

  group('Phase 4 delivery and pricing', () {
    test('delivers only on configured ISO weekdays', () {
      final result = engine.calculate(
        BillingRequest(
          customerId: 'customer-1',
          billingMonth: const LocalDate(2026, 6, 1),
          subscriptions: const [
            NewspaperSubscription(
              id: 'subscription-1',
              newspaperId: 'paper-1',
              startDate: LocalDate(2026, 6, 1),
              endDate: LocalDate(2026, 6, 7),
              deliveryWeekdays: {
                DateTime.monday,
                DateTime.wednesday,
                DateTime.friday,
              },
            ),
          ],
          priceSchedules: [
            NewspaperPriceSchedule(
              newspaperId: 'paper-1',
              defaultPricePaise: 500,
            ),
          ],
        ),
      );

      expect(result.charges.map((charge) => charge.serviceDate.day), [1, 3, 5]);
    });

    test('uses exact date then inclusive period then default price', () {
      final result = engine.calculate(
        BillingRequest(
          customerId: 'customer-1',
          billingMonth: const LocalDate(2026, 5, 1),
          subscriptions: const [
            NewspaperSubscription(
              id: 'subscription-1',
              newspaperId: 'paper-1',
              startDate: LocalDate(2026, 5, 1),
              endDate: LocalDate(2026, 5, 5),
            ),
          ],
          priceSchedules: [
            NewspaperPriceSchedule(
              newspaperId: 'paper-1',
              defaultPricePaise: 500,
              effectivePeriods: [
                NewspaperPricePeriod(
                  startDate: LocalDate(2026, 5, 2),
                  endDate: LocalDate(2026, 5, 4),
                  pricePaise: 550,
                ),
              ],
              dateOverrides: {const LocalDate(2026, 5, 3): 650},
            ),
          ],
        ),
      );

      expect(result.charges.map((charge) => charge.unitPricePaise), [
        500,
        550,
        650,
        550,
        500,
      ]);
    });

    test('retains customer date and fixed-price precedence over catalog', () {
      final result = engine.calculate(
        BillingRequest(
          customerId: 'customer-1',
          billingMonth: const LocalDate(2026, 5, 1),
          subscriptions: const [
            NewspaperSubscription(
              id: 'subscription-1',
              newspaperId: 'paper-1',
              startDate: LocalDate(2026, 5, 1),
              endDate: LocalDate(2026, 5, 2),
              fixedPricePaise: 450,
            ),
          ],
          priceSchedules: [
            NewspaperPriceSchedule(
              newspaperId: 'paper-1',
              defaultPricePaise: 500,
              effectivePeriods: [
                NewspaperPricePeriod(
                  startDate: LocalDate(2026, 5, 1),
                  endDate: LocalDate(2026, 5, 2),
                  pricePaise: 600,
                ),
              ],
              dateOverrides: {const LocalDate(2026, 5, 1): 700},
            ),
          ],
          customerDatePrices: {
            'subscription-1': {LocalDate(2026, 5, 2): 400},
          },
        ),
      );

      expect(result.charges.map((charge) => charge.unitPricePaise), [450, 400]);
    });

    test('resolves the approved live-smoke price dates deterministically', () {
      final schedule = NewspaperPriceSchedule(
        newspaperId: 'phase-4-live-smoke-alpha',
        defaultPricePaise: 500,
        effectivePeriods: [
          NewspaperPricePeriod(
            startDate: LocalDate(2026, 9, 14),
            endDate: LocalDate(2026, 9, 20),
            pricePaise: 600,
          ),
        ],
        dateOverrides: {LocalDate(2026, 9, 15): 850},
      );
      final catalogResult = engine.calculate(
        BillingRequest(
          customerId: 'phase-4-live-smoke-customer',
          billingMonth: const LocalDate(2026, 9, 1),
          subscriptions: const [
            NewspaperSubscription(
              id: 'catalog-price-subscription',
              newspaperId: 'phase-4-live-smoke-alpha',
              startDate: LocalDate(2026, 9, 13),
              endDate: LocalDate(2026, 9, 15),
            ),
          ],
          priceSchedules: [schedule],
        ),
      );
      final customerPriceResult = engine.calculate(
        BillingRequest(
          customerId: 'phase-4-live-smoke-customer',
          billingMonth: const LocalDate(2026, 9, 1),
          subscriptions: const [
            NewspaperSubscription(
              id: 'customer-price-subscription',
              newspaperId: 'phase-4-live-smoke-alpha',
              startDate: LocalDate(2026, 9, 14),
              endDate: LocalDate(2026, 9, 15),
              quantity: 2,
              fixedPricePaise: 450,
            ),
          ],
          priceSchedules: [schedule],
        ),
      );

      expect(catalogResult.charges.map((charge) => charge.unitPricePaise), [
        500,
        600,
        850,
      ]);
      expect(
        customerPriceResult.charges.map((charge) => charge.unitPricePaise),
        [450, 450],
      );
      expect(customerPriceResult.currentChargesPaise, 1800);
    });

    test('allows adjacent periods and treats both boundaries as inclusive', () {
      final result = engine.calculate(
        BillingRequest(
          customerId: 'customer-1',
          billingMonth: const LocalDate(2026, 5, 1),
          subscriptions: const [
            NewspaperSubscription(
              id: 'subscription-1',
              newspaperId: 'paper-1',
              startDate: LocalDate(2026, 5, 1),
              endDate: LocalDate(2026, 5, 4),
            ),
          ],
          priceSchedules: const [
            NewspaperPriceSchedule(
              newspaperId: 'paper-1',
              defaultPricePaise: 500,
              effectivePeriods: [
                NewspaperPricePeriod(
                  startDate: LocalDate(2026, 5, 1),
                  endDate: LocalDate(2026, 5, 2),
                  pricePaise: 550,
                ),
                NewspaperPricePeriod(
                  startDate: LocalDate(2026, 5, 3),
                  endDate: LocalDate(2026, 5, 4),
                  pricePaise: 600,
                ),
              ],
            ),
          ],
        ),
      );

      expect(result.charges.map((charge) => charge.unitPricePaise), [
        550,
        550,
        600,
        600,
      ]);
    });
  });

  group('Phase 4 billing invariants', () {
    test('rejects duplicate newspaper schedules', () {
      expect(
        () => engine.calculate(
          BillingRequest(
            customerId: 'customer-1',
            billingMonth: const LocalDate(2026, 5, 1),
            subscriptions: const [],
            priceSchedules: [
              NewspaperPriceSchedule(
                newspaperId: 'paper-1',
                defaultPricePaise: 500,
              ),
              NewspaperPriceSchedule(
                newspaperId: 'paper-1',
                defaultPricePaise: 600,
              ),
            ],
          ),
        ),
        throwsA(isA<BillingException>()),
      );
    });

    test('rejects overlapping same-precedence catalog periods', () {
      expect(
        () => engine.calculate(
          BillingRequest(
            customerId: 'customer-1',
            billingMonth: const LocalDate(2026, 5, 1),
            subscriptions: const [],
            priceSchedules: [
              NewspaperPriceSchedule(
                newspaperId: 'paper-1',
                defaultPricePaise: 500,
                effectivePeriods: [
                  NewspaperPricePeriod(
                    startDate: LocalDate(2026, 5, 1),
                    endDate: LocalDate(2026, 5, 3),
                    pricePaise: 550,
                  ),
                  NewspaperPricePeriod(
                    startDate: LocalDate(2026, 5, 3),
                    endDate: LocalDate(2026, 5, 5),
                    pricePaise: 600,
                  ),
                ],
              ),
            ],
          ),
        ),
        throwsA(isA<BillingException>()),
      );
    });

    test('rejects invalid dates and values at runtime', () {
      final invalidSubscriptions = [
        const NewspaperSubscription(
          id: 'zero-quantity',
          newspaperId: 'paper-1',
          startDate: LocalDate(2026, 5, 1),
          quantity: 0,
        ),
        const NewspaperSubscription(
          id: 'negative-price',
          newspaperId: 'paper-1',
          startDate: LocalDate(2026, 5, 1),
          fixedPricePaise: -1,
        ),
        const NewspaperSubscription(
          id: 'no-weekdays',
          newspaperId: 'paper-1',
          startDate: LocalDate(2026, 5, 1),
          deliveryWeekdays: {},
        ),
        const NewspaperSubscription(
          id: 'bad-weekday',
          newspaperId: 'paper-1',
          startDate: LocalDate(2026, 5, 1),
          deliveryWeekdays: {8},
        ),
        const NewspaperSubscription(
          id: 'bad-calendar-date',
          newspaperId: 'paper-1',
          startDate: LocalDate(2026, 2, 30),
        ),
      ];

      for (final subscription in invalidSubscriptions) {
        expect(
          () => engine.calculate(
            BillingRequest(
              customerId: 'customer-1',
              billingMonth: const LocalDate(2026, 5, 1),
              subscriptions: [subscription],
              priceSchedules: const [
                NewspaperPriceSchedule(
                  newspaperId: 'paper-1',
                  defaultPricePaise: 500,
                ),
              ],
            ),
          ),
          throwsA(isA<BillingException>()),
          reason: subscription.id,
        );
      }
    });

    test('validates unused price data instead of ignoring it', () {
      expect(
        () => engine.calculate(
          BillingRequest(
            customerId: 'customer-1',
            billingMonth: const LocalDate(2026, 5, 1),
            subscriptions: const [],
            priceSchedules: [
              NewspaperPriceSchedule(
                newspaperId: 'paper-1',
                defaultPricePaise: 500,
                dateOverrides: {const LocalDate(2026, 6, 1): -1},
              ),
            ],
          ),
        ),
        throwsA(isA<BillingException>()),
      );
    });
  });
}
