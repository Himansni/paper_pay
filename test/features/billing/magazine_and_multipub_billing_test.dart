import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/billing/domain/billing_models.dart';
import 'package:paper_route/features/billing/domain/monthly_billing_engine.dart';

void main() {
  group('Multi-Publication and Magazine Billing Invariants', () {
    const engine = MonthlyBillingEngine();
    const billingMonth = LocalDate(2026, 9, 1);

    test('Accurately bills a customer subscribed to multiple newspapers with distinct quantities', () {
      // Customer has 2 copies of Dainik Jagran (₹5.00) and 1 copy of The Times of India (₹6.00)
      final request = BillingRequest(
        customerId: 'C-101',
        billingMonth: billingMonth,
        subscriptions: const [
          NewspaperSubscription(
            id: 'sub-jagran',
            newspaperId: 'N-JAGRAN',
            startDate: LocalDate(2026, 1, 1),
            quantity: 2,
            deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7}, // Everyday
          ),
          NewspaperSubscription(
            id: 'sub-toi',
            newspaperId: 'N-TOI',
            startDate: LocalDate(2026, 1, 1),
            quantity: 1,
            deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
          ),
        ],
        priceSchedules: const [
          NewspaperPriceSchedule(
            newspaperId: 'N-JAGRAN',
            defaultPricePaise: 500,
            dateOverrides: {},
          ),
          NewspaperPriceSchedule(
            newspaperId: 'N-TOI',
            defaultPricePaise: 600,
            dateOverrides: {},
          ),
        ],
      );

      final result = engine.calculate(request);
      expect(result.charges.length, 30 * 2); // 30 days in September x 2 subscriptions

      // Daily total: (2 * 500) + (1 * 600) = 1600 paise (₹16.00)
      // Month total: 30 * 1600 = 48000 paise (₹480.00)
      expect(result.currentChargesPaise, 48000);
      expect(result.totalDuePaise, 48000);
    });

    test('Accurately bills weekly magazine delivery with effective-date price rule', () {
      // India Today delivered on Sundays only (weekday 7) with a date-specific price increase
      final request = BillingRequest(
        customerId: 'C-102',
        billingMonth: billingMonth,
        subscriptions: const [
          NewspaperSubscription(
            id: 'sub-india-today',
            newspaperId: 'MAG-IT',
            startDate: LocalDate(2026, 1, 1),
            quantity: 1,
            deliveryWeekdays: {7}, // Sundays only
          ),
        ],
        priceSchedules: [
          NewspaperPriceSchedule(
            newspaperId: 'MAG-IT',
            defaultPricePaise: 7500, // ₹75.00
            dateOverrides: {
              const LocalDate(2026, 9, 20): 10000, // Special issue on Sep 20: ₹100.00
            },
          ),
        ],
      );

      final result = engine.calculate(request);

      // September 2026 Sundays: Sep 6, Sep 13, Sep 20, Sep 27 (4 issues)
      expect(result.charges.length, 4);

      final sep20Charge = result.charges.firstWhere(
        (c) => c.serviceDate == const LocalDate(2026, 9, 20),
      );
      expect(sep20Charge.unitPricePaise, 10000);

      // Total: 3 regular issues @ ₹75 (22500) + 1 special issue @ ₹100 (10000) = 32500 paise (₹325.00)
      expect(result.currentChargesPaise, 32500);
    });

    test('Customer price override takes strict precedence over general price schedule', () {
      final request = BillingRequest(
        customerId: 'C-103',
        billingMonth: billingMonth,
        subscriptions: const [
          NewspaperSubscription(
            id: 'sub-custom-price',
            newspaperId: 'N-HINDU',
            startDate: LocalDate(2026, 1, 1),
            quantity: 1,
            fixedPricePaise: 400, // Negotiated custom ₹4.00 price
            deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
          ),
        ],
        priceSchedules: const [
          NewspaperPriceSchedule(
            newspaperId: 'N-HINDU',
            defaultPricePaise: 800, // Standard ₹8.00
            dateOverrides: {},
          ),
        ],
      );

      final result = engine.calculate(request);
      expect(result.charges.every((c) => c.unitPricePaise == 400), isTrue);
      expect(result.currentChargesPaise, 30 * 400); // ₹120.00
    });
  });
}
