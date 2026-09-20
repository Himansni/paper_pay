import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';

void main() {
  const planner = MonthlyBillPlanner();

  BillingTermSnapshot term({
    String subscriptionId = 'daily',
    String versionId = 'v1',
    String newspaperId = 'daily',
    LocalDate start = const LocalDate(2026, 1, 1),
    LocalDate? end,
    int quantity = 1,
    Set<int> weekdays = const {1, 2, 3, 4, 5, 6, 7},
    int? customPrice,
  }) => BillingTermSnapshot(
    subscriptionId: subscriptionId,
    versionId: versionId,
    newspaperId: newspaperId,
    newspaperName: newspaperId,
    effectiveFrom: start,
    effectiveTo: end,
    quantity: quantity,
    deliveryWeekdays: weekdays,
    customPricePaise: customPrice,
  );

  BillingNewspaperSnapshot paper({
    String id = 'daily',
    int defaultPrice = 503,
    List<BillingPriceRuleSnapshot> rules = const [],
  }) => BillingNewspaperSnapshot(
    newspaperId: id,
    name: id,
    defaultPricePaise: defaultPrice,
    rules: rules,
  );

  group('deterministic calendar billing', () {
    test('uses exact 28, 29, 30, and 31-day calendar boundaries', () {
      for (final scenario in const [
        (month: LocalDate(2023, 2, 1), days: 28),
        (month: LocalDate(2024, 2, 1), days: 29),
        (month: LocalDate(2026, 4, 1), days: 30),
        (month: LocalDate(2026, 5, 1), days: 31),
      ]) {
        final lines = planner.calculate(
          customerId: 'C-1',
          month: scenario.month,
          terms: [term(start: const LocalDate(2020, 1, 1))],
          pauses: const [],
          deliveryExceptions: const [],
          newspapers: {'daily': paper(defaultPrice: 100)},
        );

        expect(lines, hasLength(scenario.days));
        expect(
          lines.fold(0, (total, line) => total + line.totalPaise),
          scenario.days * 100,
        );
      }
    });

    test('handles leap February and exact integer-paise arithmetic', () {
      final lines = planner.calculate(
        customerId: 'C-1',
        month: const LocalDate(2024, 2, 1),
        terms: [term(start: const LocalDate(2024, 1, 1), quantity: 3)],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: {'daily': paper()},
      );

      expect(lines, hasLength(29));
      expect(lines.fold(0, (total, line) => total + line.totalPaise), 43761);
      expect(lines.last.serviceDate, const LocalDate(2024, 2, 29));
    });

    test('honors mid-month start/end, weekdays, pause, and exception', () {
      final lines = planner.calculate(
        customerId: 'C-1',
        month: const LocalDate(2026, 6, 1),
        terms: [
          term(
            start: const LocalDate(2026, 6, 5),
            end: const LocalDate(2026, 6, 19),
            weekdays: const {1, 3, 5},
          ),
        ],
        pauses: const [
          BillingPauseSnapshot(
            subscriptionId: 'daily',
            pauseId: 'pause-1',
            startDate: LocalDate(2026, 6, 10),
            endDate: LocalDate(2026, 6, 12),
          ),
        ],
        deliveryExceptions: const [
          BillingDeliveryExceptionSnapshot(
            id: 'exception-1',
            subscriptionId: 'daily',
            serviceDate: LocalDate(2026, 6, 15),
          ),
        ],
        newspapers: {'daily': paper()},
      );

      expect(lines.map((line) => line.serviceDate.day), [5, 8, 17, 19]);
    });

    test('an open pause excludes service through the end of the month', () {
      final lines = planner.calculate(
        customerId: 'C-1',
        month: const LocalDate(2026, 4, 1),
        terms: [term(start: const LocalDate(2026, 4, 1))],
        pauses: const [
          BillingPauseSnapshot(
            subscriptionId: 'daily',
            pauseId: 'open-pause',
            startDate: LocalDate(2026, 4, 10),
            endDate: null,
          ),
        ],
        deliveryExceptions: const [],
        newspapers: {'daily': paper()},
      );

      expect(lines, hasLength(9));
      expect(lines.last.serviceDate, const LocalDate(2026, 4, 9));
    });

    test(
      'billing month identity is deterministic and rejects non-month dates',
      () {
        expect(billingMonthKey(const LocalDate(2026, 4, 1)), '2026-04');
        expect(billingMonthFromKey('2026-04'), const LocalDate(2026, 4, 1));
        expect(
          () => billingMonthKey(const LocalDate(2026, 4, 2)),
          throwsA(isA<AppException>()),
        );
      },
    );

    test('uses immutable term versions and multiple newspapers', () {
      final lines = planner.calculate(
        customerId: 'C-1',
        month: const LocalDate(2026, 5, 1),
        terms: [
          term(
            versionId: 'v1',
            start: const LocalDate(2026, 5, 1),
            end: const LocalDate(2026, 5, 10),
            quantity: 1,
          ),
          term(
            versionId: 'v2',
            start: const LocalDate(2026, 5, 11),
            end: const LocalDate(2026, 5, 12),
            quantity: 2,
          ),
          term(
            subscriptionId: 'weekly',
            versionId: 'weekly-v1',
            newspaperId: 'weekly',
            start: const LocalDate(2026, 5, 1),
            end: const LocalDate(2026, 5, 31),
            weekdays: const {7},
          ),
        ],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: {
          'daily': paper(),
          'weekly': paper(id: 'weekly', defaultPrice: 1000),
        },
      );

      expect(lines.where((line) => line.versionId == 'v1'), hasLength(10));
      expect(lines.where((line) => line.versionId == 'v2'), hasLength(2));
      expect(lines.where((line) => line.newspaperId == 'weekly'), hasLength(5));
      expect(
        lines
            .where((line) => line.versionId == 'v2')
            .fold(0, (total, line) => total + line.totalPaise),
        2012,
      );
    });

    test('applies custom, exact, period, then default price precedence', () {
      final catalog = paper(
        rules: const [
          BillingPriceRuleSnapshot(
            ruleId: 'period-1',
            startDate: LocalDate(2026, 5, 2),
            endDate: LocalDate(2026, 5, 4),
            pricePaise: 600,
            isExactDate: false,
            revision: 1,
          ),
          BillingPriceRuleSnapshot(
            ruleId: 'exact-1',
            startDate: LocalDate(2026, 5, 3),
            endDate: LocalDate(2026, 5, 3),
            pricePaise: 750,
            isExactDate: true,
            revision: 2,
          ),
        ],
      );
      final catalogLines = planner.calculate(
        customerId: 'C-1',
        month: const LocalDate(2026, 5, 1),
        terms: [
          term(
            start: const LocalDate(2026, 5, 1),
            end: const LocalDate(2026, 5, 5),
          ),
        ],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: {'daily': catalog},
      );
      expect(catalogLines.map((line) => line.unitPricePaise), [
        503,
        600,
        750,
        600,
        503,
      ]);
      expect(catalogLines.map((line) => line.priceSource), [
        BillPriceSource.defaultPrice,
        BillPriceSource.effectivePeriod,
        BillPriceSource.exactDate,
        BillPriceSource.effectivePeriod,
        BillPriceSource.defaultPrice,
      ]);

      final customLines = planner.calculate(
        customerId: 'C-1',
        month: const LocalDate(2026, 5, 1),
        terms: [
          term(
            start: const LocalDate(2026, 5, 2),
            end: const LocalDate(2026, 5, 3),
            customPrice: 425,
          ),
        ],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: {'daily': catalog},
      );
      expect(customLines.map((line) => line.unitPricePaise), [425, 425]);
      expect(
        customLines.every(
          (line) => line.priceSource == BillPriceSource.customerSpecific,
        ),
        isTrue,
      );
    });

    test('blocks missing and ambiguous pricing instead of using zero', () {
      expect(
        () => planner.calculate(
          customerId: 'C-1',
          month: const LocalDate(2026, 5, 1),
          terms: [term(start: const LocalDate(2026, 5, 1))],
          pauses: const [],
          deliveryExceptions: const [],
          newspapers: {'daily': paper(defaultPrice: -1)},
        ),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            'missing-price',
          ),
        ),
      );
      expect(
        () => planner.calculate(
          customerId: 'C-1',
          month: const LocalDate(2026, 5, 1),
          terms: [
            term(
              start: const LocalDate(2026, 5, 1),
              end: const LocalDate(2026, 5, 1),
            ),
          ],
          pauses: const [],
          deliveryExceptions: const [],
          newspapers: {
            'daily': paper(
              rules: const [
                BillingPriceRuleSnapshot(
                  ruleId: 'a',
                  startDate: LocalDate(2026, 5, 1),
                  endDate: LocalDate(2026, 5, 1),
                  pricePaise: 600,
                  isExactDate: true,
                  revision: 1,
                ),
                BillingPriceRuleSnapshot(
                  ruleId: 'b',
                  startDate: LocalDate(2026, 5, 1),
                  endDate: LocalDate(2026, 5, 1),
                  pricePaise: 700,
                  isExactDate: true,
                  revision: 1,
                ),
              ],
            ),
          },
        ),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            'ambiguous-price',
          ),
        ),
      );
    });

    test('charge keys are stable and overlapping versions are rejected', () {
      final lines = planner.calculate(
        customerId: 'C-1',
        month: const LocalDate(2026, 5, 1),
        terms: [
          term(
            start: const LocalDate(2026, 5, 1),
            end: const LocalDate(2026, 5, 1),
          ),
        ],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: {'daily': paper()},
      );
      expect(lines.single.chargeKey, 'C-1:daily:2026-05-01');

      expect(
        () => planner.calculate(
          customerId: 'C-1',
          month: const LocalDate(2026, 5, 1),
          terms: [
            term(
              versionId: 'v1',
              start: const LocalDate(2026, 5, 1),
              weekdays: const {DateTime.monday},
            ),
            term(
              versionId: 'v2',
              start: const LocalDate(2026, 5, 1),
              weekdays: const {DateTime.tuesday},
            ),
          ],
          pauses: const [],
          deliveryExceptions: const [],
          newspapers: {'daily': paper()},
        ),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            'ambiguous-subscription-terms',
          ),
        ),
      );
    });
  });

  group('balance source and adjustments', () {
    test('formats rupees from integer paise without floating-point money', () {
      expect(BillingMoney.formatPaise(0), '₹0.00');
      expect(BillingMoney.formatPaise(123456789), '₹12,34,567.89');
      expect(BillingMoney.formatPaise(-505), '-₹5.05');
    });

    MonthlyBillPreview preview({String previousId = '', int previous = 0}) =>
        MonthlyBillPreview(
          businessId: 'business-a',
          customerId: 'C-1',
          customerCode: 'C-1',
          customerName: 'Test Customer',
          customerAddress: 'Synthetic address',
          billingMonth: '2026-05',
          lineItems: const [
            MonthlyBillLineItem(
              chargeKey: 'C-1:daily:2026-05-01',
              serviceDate: LocalDate(2026, 5, 1),
              subscriptionId: 'daily',
              versionId: 'v1',
              newspaperId: 'daily',
              newspaperName: 'Daily',
              unitPricePaise: 505,
              quantity: 2,
              priceSource: BillPriceSource.defaultPrice,
              priceSourceId: 'daily',
              priceRuleRevision: 0,
            ),
          ],
          openingBalancePaise: 10000,
          previousBillId: previousId,
          previousOutstandingPaise: previous,
          adjustments: const [
            BillingAdjustment(
              id: 'credit',
              billingMonth: '2026-05',
              amountPaise: -500,
              reason: 'Audited credit',
              referenceBillMonth: '',
              createdBy: 'head-a',
            ),
            BillingAdjustment(
              id: 'debit',
              billingMonth: '2026-05',
              amountPaise: 250,
              reason: 'Audited debit',
              referenceBillMonth: '',
              createdBy: 'head-a',
            ),
          ],
          issues: const [],
          alreadyFinalizedBill: null,
        );

    test('first bill uses opening balance exactly once', () {
      final value = preview();
      expect(value.priorBalancePaise, 10000);
      expect(value.currentChargesPaise, 1010);
      expect(value.adjustmentsPaise, -250);
      expect(value.totalDuePaise, 10760);
    });

    test(
      'later bill carries prior finalized outstanding, not opening again',
      () {
        final value = preview(previousId: '2026-04', previous: 7600);
        expect(value.priorBalancePaise, 7600);
        expect(value.totalDuePaise, 8360);
      },
    );

    test(
      'adjustment input requires signed nonzero amount and earlier reference',
      () {
        expect(
          () =>
              const BillingAdjustmentInput(
                billingMonth: '2026-05',
                amountPaise: 0,
                reason: 'Invalid zero',
              ).validate(),
          throwsA(isA<AppException>()),
        );
        expect(
          () =>
              const BillingAdjustmentInput(
                billingMonth: '2026-05',
                amountPaise: -500,
                reason: 'Correction',
                referenceBillMonth: '2026-06',
              ).validate(),
          throwsA(isA<AppException>()),
        );
      },
    );
  });
}
