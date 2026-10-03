import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';

void main() {
  const planner = MonthlyBillPlanner();

  BillingTermSnapshot term({
    String subscriptionId = 'sub-1',
    String versionId = 'v-1',
    String newspaperId = 'paper-1',
    String newspaperName = 'The Economic Times',
    LocalDate start = const LocalDate(2026, 10, 1),
    LocalDate? end = const LocalDate(2026, 10, 31),
    int quantity = 1,
    Set<int> weekdays = const {1, 2, 3, 4, 5, 6, 7},
    int? customPricePaise,
  }) => BillingTermSnapshot(
    subscriptionId: subscriptionId,
    versionId: versionId,
    newspaperId: newspaperId,
    newspaperName: newspaperName,
    effectiveFrom: start,
    effectiveTo: end,
    quantity: quantity,
    deliveryWeekdays: weekdays,
    customPricePaise: customPricePaise,
  );

  BillingNewspaperSnapshot paper({
    String id = 'paper-1',
    String name = 'The Economic Times',
    int defaultPricePaise = 500,
    List<BillingPriceRuleSnapshot> rules = const [],
    BillingPriceRuleSnapshot? monthlyOverridePrice,
  }) => BillingNewspaperSnapshot(
    newspaperId: id,
    name: name,
    defaultPricePaise: defaultPricePaise,
    rules: rules,
    monthlyOverridePrice: monthlyOverridePrice,
  );

  group('V1 Financial Pricing Precedence Tests', () {
    // 1. Customer-specific price + monthly override + global price -> customer-specific price wins
    test('1. Customer-specific price wins over monthly override and global price', () {
      final override = const BillingPriceRuleSnapshot(
        ruleId: 'monthly-override-1',
        startDate: LocalDate(2026, 10, 1),
        endDate: LocalDate(2026, 10, 31),
        pricePaise: 9800, // ₹98.00/month
        isExactDate: false,
        revision: 1,
        pricingBasis: PricingBasis.monthly,
      );
      final globalRule = const BillingPriceRuleSnapshot(
        ruleId: 'global-period-1',
        startDate: LocalDate(2026, 1, 1),
        endDate: LocalDate(2026, 12, 31),
        pricePaise: 500, // ₹5.00/day
        isExactDate: false,
        revision: 1,
        pricingBasis: PricingBasis.daily,
      );
      final p = paper(
        rules: [globalRule],
        monthlyOverridePrice: override,
      );
      final t = term(customPricePaise: 12000); // ₹120.00 customer price

      final lines = planner.calculate(
        customerId: 'c-1',
        month: const LocalDate(2026, 10, 1),
        terms: [t],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: {'paper-1': p},
      );

      expect(lines, hasLength(1));
      expect(lines.first.unitPricePaise, 12000);
      expect(lines.first.priceSource, BillPriceSource.customerSpecific);
    });

    // 2. Monthly override + global monthly price -> monthly override wins, NO "Too many elements"
    test('2. Monthly override wins over global monthly price without throwing Too many elements', () {
      final override = const BillingPriceRuleSnapshot(
        ruleId: 'monthly-override-1',
        startDate: LocalDate(2026, 10, 1),
        endDate: LocalDate(2026, 10, 31),
        pricePaise: 9800, // ₹98.00/month
        isExactDate: false,
        revision: 1,
        pricingBasis: PricingBasis.monthly,
      );
      final globalMonthlyRule = const BillingPriceRuleSnapshot(
        ruleId: 'global-monthly-1',
        startDate: LocalDate(2026, 1, 1),
        endDate: LocalDate(2026, 12, 31),
        pricePaise: 15000, // ₹150.00/month
        isExactDate: false,
        revision: 1,
        pricingBasis: PricingBasis.monthly,
      );
      final p = paper(
        rules: [globalMonthlyRule],
        monthlyOverridePrice: override,
      );

      final lines = planner.calculate(
        customerId: 'c-1',
        month: const LocalDate(2026, 10, 1),
        terms: [term()],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: {'paper-1': p},
      );

      expect(lines, hasLength(1));
      expect(lines.first.unitPricePaise, 9800);
      expect(lines.first.priceSource, BillPriceSource.effectivePeriod);
      expect(lines.first.priceSourceId, 'monthly-override-1');
    });

    // 3. Monthly override + global exact-date price -> monthly override wins
    test('3. Monthly override wins over global exact-date price', () {
      final override = const BillingPriceRuleSnapshot(
        ruleId: 'monthly-override-1',
        startDate: LocalDate(2026, 10, 1),
        endDate: LocalDate(2026, 10, 31),
        pricePaise: 9800, // ₹98.00/month
        isExactDate: false,
        revision: 1,
        pricingBasis: PricingBasis.monthly,
      );
      final exactDateRule = const BillingPriceRuleSnapshot(
        ruleId: 'exact-date-1',
        startDate: LocalDate(2026, 10, 15),
        endDate: LocalDate(2026, 10, 15),
        pricePaise: 2000,
        isExactDate: true,
        revision: 1,
        pricingBasis: PricingBasis.daily,
      );
      final p = paper(
        rules: [exactDateRule],
        monthlyOverridePrice: override,
      );

      final lines = planner.calculate(
        customerId: 'c-1',
        month: const LocalDate(2026, 10, 1),
        terms: [term()],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: {'paper-1': p},
      );

      expect(lines, hasLength(1));
      expect(lines.first.unitPricePaise, 9800);
      expect(lines.first.priceSource, BillPriceSource.effectivePeriod);
    });

    // 4. No monthly override + one global period price -> global period price
    test('4. No monthly override resolves single global period price', () {
      final globalPeriod = const BillingPriceRuleSnapshot(
        ruleId: 'global-period-1',
        startDate: LocalDate(2026, 1, 1),
        endDate: LocalDate(2026, 12, 31),
        pricePaise: 600,
        isExactDate: false,
        revision: 1,
        pricingBasis: PricingBasis.daily,
      );
      final p = paper(rules: [globalPeriod]);

      final lines = planner.calculate(
        customerId: 'c-1',
        month: const LocalDate(2026, 10, 1),
        terms: [term()],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: {'paper-1': p},
      );

      expect(lines, hasLength(31));
      expect(lines.every((l) => l.unitPricePaise == 600), isTrue);
      expect(lines.first.priceSource, BillPriceSource.effectivePeriod);
    });

    // 5. No monthly override + one exact-date price -> exact-date price
    test('5. No monthly override resolves exact-date price for exact date', () {
      final exactDateRule = const BillingPriceRuleSnapshot(
        ruleId: 'exact-date-1',
        startDate: LocalDate(2026, 10, 15),
        endDate: LocalDate(2026, 10, 15),
        pricePaise: 2000,
        isExactDate: true,
        revision: 1,
        pricingBasis: PricingBasis.daily,
      );
      final p = paper(rules: [exactDateRule]);

      final lines = planner.calculate(
        customerId: 'c-1',
        month: const LocalDate(2026, 10, 1),
        terms: [term()],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: {'paper-1': p},
      );

      final oct15 = lines.firstWhere((l) => l.serviceDate == const LocalDate(2026, 10, 15));
      expect(oct15.unitPricePaise, 2000);
      expect(oct15.priceSource, BillPriceSource.exactDate);

      final oct1 = lines.firstWhere((l) => l.serviceDate == const LocalDate(2026, 10, 1));
      expect(oct1.unitPricePaise, 500); // default publication price fallback
      expect(oct1.priceSource, BillPriceSource.defaultPrice);
    });

    // 6. Two conflicting global period rules -> explicit ambiguous-price error
    test('6. Two conflicting global period rules throw explicit ambiguous-price AppException', () {
      final rule1 = const BillingPriceRuleSnapshot(
        ruleId: 'g-period-1',
        startDate: LocalDate(2026, 1, 1),
        endDate: LocalDate(2026, 12, 31),
        pricePaise: 500,
        isExactDate: false,
        revision: 1,
        pricingBasis: PricingBasis.monthly,
      );
      final rule2 = const BillingPriceRuleSnapshot(
        ruleId: 'g-period-2',
        startDate: LocalDate(2026, 1, 1),
        endDate: LocalDate(2026, 12, 31),
        pricePaise: 600,
        isExactDate: false,
        revision: 1,
        pricingBasis: PricingBasis.monthly,
      );
      final p = paper(rules: [rule1, rule2]);

      expect(
        () => planner.calculate(
          customerId: 'c-1',
          month: const LocalDate(2026, 10, 1),
          terms: [term()],
          pauses: const [],
          deliveryExceptions: const [],
          newspapers: {'paper-1': p},
        ),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', 'ambiguous-price')
              .having(
                (e) => e.message,
                'message',
                contains('Ambiguous active pricing for The Economic Times in 2026-10'),
              ),
        ),
      );
    });

    // 7. Two conflicting global exact-date rules -> explicit ambiguous-price error
    test('7. Two conflicting global exact-date rules throw explicit ambiguous-price AppException', () {
      final exact1 = const BillingPriceRuleSnapshot(
        ruleId: 'exact-1',
        startDate: LocalDate(2026, 10, 15),
        endDate: LocalDate(2026, 10, 15),
        pricePaise: 1000,
        isExactDate: true,
        revision: 1,
        pricingBasis: PricingBasis.daily,
      );
      final exact2 = const BillingPriceRuleSnapshot(
        ruleId: 'exact-2',
        startDate: LocalDate(2026, 10, 15),
        endDate: LocalDate(2026, 10, 15),
        pricePaise: 1200,
        isExactDate: true,
        revision: 1,
        pricingBasis: PricingBasis.daily,
      );
      final p = paper(rules: [exact1, exact2]);

      expect(
        () => planner.calculate(
          customerId: 'c-1',
          month: const LocalDate(2026, 10, 1),
          terms: [term()],
          pauses: const [],
          deliveryExceptions: const [],
          newspapers: {'paper-1': p},
        ),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', 'ambiguous-price')
              .having(
                (e) => e.message,
                'message',
                contains('Ambiguous active pricing for The Economic Times on 2026-10-15'),
              ),
        ),
      );
    });

    // 8. Monthly override changed after a previous bill was finalized -> existing finalized bill remains immutable
    test('8. Finalized bill remains immutable when monthly override changes', () {
      final existingFinalizedBill = const FinalizedMonthlyBill(
        id: 'bill-2026-10-c-1',
        businessId: 'biz-1',
        customerId: 'c-1',
        customerCode: 'C-001',
        customerName: 'Aarav',
        customerAddress: 'Addr',
        billingMonth: '2026-10',
        openingBalancePaise: 0,
        previousBillId: '',
        previousOutstandingPaise: 0,
        priorBalancePaise: 0,
        currentChargesPaise: 9800,
        adjustmentsPaise: 0,
        totalDuePaise: 9800,
        lineItemCount: 1,
        newspaperSummaries: [],
        calculationVersion: 'paper-route-monthly-v1',
        finalizedBy: 'head-1',
        lastAuditId: 'audit-1',
      );

      // Mutating override to ₹120.00 afterwards must NOT change existingFinalizedBill
      expect(existingFinalizedBill.currentChargesPaise, 9800);
      expect(existingFinalizedBill.totalDuePaise, 9800);
    });

    // 9. Monthly override must not modify global priceRules
    test('9. Monthly override does not modify global priceRules list', () {
      final globalRule = const BillingPriceRuleSnapshot(
        ruleId: 'global-1',
        startDate: LocalDate(2026, 1, 1),
        endDate: LocalDate(2026, 12, 31),
        pricePaise: 500,
        isExactDate: false,
        revision: 1,
        pricingBasis: PricingBasis.daily,
      );
      final override = const BillingPriceRuleSnapshot(
        ruleId: 'override-1',
        startDate: LocalDate(2026, 10, 1),
        endDate: LocalDate(2026, 10, 31),
        pricePaise: 9800,
        isExactDate: false,
        revision: 1,
        pricingBasis: PricingBasis.monthly,
      );

      final p = paper(
        rules: [globalRule],
        monthlyOverridePrice: override,
      );

      expect(p.rules, hasLength(1));
      expect(p.rules.first.ruleId, 'global-1');
      expect(p.monthlyOverridePrice?.ruleId, 'override-1');
    });

    // 10. Preview with monthly override -> preview succeeds
    test('10. Preview with monthly override generates line items without throwing', () {
      final override = const BillingPriceRuleSnapshot(
        ruleId: 'monthly-override-1',
        startDate: LocalDate(2026, 10, 1),
        endDate: LocalDate(2026, 10, 31),
        pricePaise: 9800,
        isExactDate: false,
        revision: 1,
        pricingBasis: PricingBasis.monthly,
      );
      final p = paper(monthlyOverridePrice: override);

      final lines = planner.calculate(
        customerId: 'c-1',
        month: const LocalDate(2026, 10, 1),
        terms: [term()],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: {'paper-1': p},
      );

      final preview = MonthlyBillPreview(
        businessId: 'biz-1',
        customerId: 'c-1',
        customerCode: 'C-001',
        customerName: 'Aarav',
        customerAddress: 'Addr',
        billingMonth: '2026-10',
        lineItems: lines,
        openingBalancePaise: 0,
        previousBillId: '',
        previousOutstandingPaise: 0,
        adjustments: const [],
        issues: const [],
        alreadyFinalizedBill: null,
      );

      expect(preview.lineItems, hasLength(1));
      expect(preview.currentChargesPaise, 9800);
      expect(preview.totalDuePaise, 9800);
    });

    // 11. Finalization with monthly override -> finalization succeeds
    test('11. Finalization with monthly override constructs valid FinalizedMonthlyBill', () {
      final override = const BillingPriceRuleSnapshot(
        ruleId: 'monthly-override-1',
        startDate: LocalDate(2026, 10, 1),
        endDate: LocalDate(2026, 10, 31),
        pricePaise: 9800,
        isExactDate: false,
        revision: 1,
        pricingBasis: PricingBasis.monthly,
      );
      final p = paper(monthlyOverridePrice: override);

      final lines = planner.calculate(
        customerId: 'c-1',
        month: const LocalDate(2026, 10, 1),
        terms: [term()],
        pauses: const [],
        deliveryExceptions: const [],
        newspapers: {'paper-1': p},
      );

      final bill = FinalizedMonthlyBill(
        id: 'bill-2026-10-c-1',
        businessId: 'biz-1',
        customerId: 'c-1',
        customerCode: 'C-001',
        customerName: 'Aarav',
        customerAddress: 'Addr',
        billingMonth: '2026-10',
        openingBalancePaise: 0,
        previousBillId: '',
        previousOutstandingPaise: 0,
        priorBalancePaise: 0,
        currentChargesPaise: lines.fold(0, (sum, line) => sum + line.totalPaise),
        adjustmentsPaise: 0,
        totalDuePaise: lines.fold(0, (sum, line) => sum + line.totalPaise),
        lineItemCount: lines.length,
        newspaperSummaries: const [],
        calculationVersion: 'paper-route-monthly-v1',
        finalizedBy: 'head-1',
        lastAuditId: 'audit-1',
      );

      expect(bill.currentChargesPaise, 9800);
      expect(bill.totalDuePaise, 9800);
    });

    // 12. Retry after billing failure caused by this condition -> retry succeeds
    test('12. Retry succeeds after fixing pricing ambiguity', () {
      var hasAmbiguity = true;

      MonthlyBillPreview getPreview() {
        final rules = hasAmbiguity
            ? [
                const BillingPriceRuleSnapshot(
                  ruleId: 'g1',
                  startDate: LocalDate(2026, 1, 1),
                  endDate: LocalDate(2026, 12, 31),
                  pricePaise: 500,
                  isExactDate: false,
                  revision: 1,
                  pricingBasis: PricingBasis.monthly,
                ),
                const BillingPriceRuleSnapshot(
                  ruleId: 'g2',
                  startDate: LocalDate(2026, 1, 1),
                  endDate: LocalDate(2026, 12, 31),
                  pricePaise: 600,
                  isExactDate: false,
                  revision: 1,
                  pricingBasis: PricingBasis.monthly,
                ),
              ]
            : <BillingPriceRuleSnapshot>[];
        final override = hasAmbiguity
            ? null
            : const BillingPriceRuleSnapshot(
                ruleId: 'monthly-override-1',
                startDate: LocalDate(2026, 10, 1),
                endDate: LocalDate(2026, 10, 31),
                pricePaise: 9800,
                isExactDate: false,
                revision: 1,
                pricingBasis: PricingBasis.monthly,
              );

        final p = paper(rules: rules, monthlyOverridePrice: override);
        final lines = planner.calculate(
          customerId: 'c-1',
          month: const LocalDate(2026, 10, 1),
          terms: [term()],
          pauses: const [],
          deliveryExceptions: const [],
          newspapers: {'paper-1': p},
        );

        return MonthlyBillPreview(
          businessId: 'biz-1',
          customerId: 'c-1',
          customerCode: 'C-001',
          customerName: 'Aarav',
          customerAddress: 'Addr',
          billingMonth: '2026-10',
          lineItems: lines,
          openingBalancePaise: 0,
          previousBillId: '',
          previousOutstandingPaise: 0,
          adjustments: const [],
          issues: const [],
          alreadyFinalizedBill: null,
        );
      }

      // Initial attempt fails with ambiguous price AppException
      expect(() => getPreview(), throwsA(isA<AppException>()));

      // Set monthly override / resolve pricing ambiguity
      hasAmbiguity = false;

      // Retry succeeds
      final preview = getPreview();
      expect(preview.lineItems, hasLength(1));
      expect(preview.currentChargesPaise, 9800);
    });
  });
}
