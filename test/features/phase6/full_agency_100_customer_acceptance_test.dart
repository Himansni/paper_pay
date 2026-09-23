import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/billing/domain/billing_models.dart';
import 'package:paper_route/features/billing/domain/monthly_billing_engine.dart';
import 'package:paper_route/features/collections/domain/payment_ledger.dart';
import 'package:paper_route/features/customers/domain/customer.dart';

void main() {
  group('Phase 6 Full V1 Acceptance Scenario: 100-Customer Multi-Employee Agency', () {
    const billingEngine = MonthlyBillingEngine();
    const ledger = PaymentLedger();

    const billingMonth = LocalDate(2026, 10, 1); // October 2026 (31 days)

    // Publications & Price Schedules
    // Dainik Jagran: 500 paise base, 700 paise Sundays, mid-month price change on Oct 15 to 550 paise
    final jagranOverrides = <LocalDate, int>{};
    for (var day = 1; day <= 31; day++) {
      final date = LocalDate(2026, 10, day);
      final isSunday = date.toDateTime().weekday == DateTime.sunday;
      if (day >= 15) {
        jagranOverrides[date] = isSunday ? 750 : 550;
      } else {
        if (isSunday) {
          jagranOverrides[date] = 700;
        }
      }
    }

    final jagranSchedule = NewspaperPriceSchedule(
      newspaperId: 'pub_jagran',
      defaultPricePaise: 500,
      dateOverrides: jagranOverrides,
    );

    // Times of India: 600 paise base, 800 paise Sundays
    final toiOverrides = <LocalDate, int>{};
    for (var day = 1; day <= 31; day++) {
      final date = LocalDate(2026, 10, day);
      if (date.toDateTime().weekday == DateTime.sunday) {
        toiOverrides[date] = 800;
      }
    }
    final toiSchedule = NewspaperPriceSchedule(
      newspaperId: 'pub_toi',
      defaultPricePaise: 600,
      dateOverrides: toiOverrides,
    );

    // 100 Synthetic Customers partitioned across 3 employees / delivery routes
    // Employee North (Area 1): Customers 1 to 35
    // Employee South (Area 2): Customers 36 to 70
    // Employee Central (Area 3): Customers 71 to 100
    final customers = <Customer>[];
    final customerSubscriptions = <String, List<NewspaperSubscription>>{};
    final customerOpeningBalances = <String, int>{};

    for (var i = 1; i <= 100; i++) {
      final custId = 'cust_${i.toString().padLeft(3, '0')}';
      final areaId = i <= 35 ? 'area_north' : (i <= 70 ? 'area_south' : 'area_central');
      final empId = i <= 35 ? 'emp_north' : (i <= 70 ? 'emp_south' : 'emp_central');
      final openingBalance = (i % 5 == 0) ? (i * 1000) : 0; // Some have prior carry-forward balance

      customers.add(
        Customer(
          id: custId,
          customerCode: 'C-${i.toString().padLeft(4, '0')}',
          businessId: 'biz_delhi_press',
          name: 'Subscriber $i',
          phone: '98${i.toString().padLeft(8, '0')}',
          areaId: areaId,
          assignedEmployeeId: empId,
          address: 'House $i, Sector ${(i % 10) + 1}',
          openingBalancePaise: openingBalance,
          status: CustomerStatus.active,
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 1),
        ),
      );
      customerOpeningBalances[custId] = openingBalance;

      // Subscriptions configuration:
      // Customers 1-50 subscribe to Dainik Jagran
      // Customers 51-100 subscribe to Times of India
      // Customers 20-30 subscribe to BOTH (dual delivery)
      final subs = <NewspaperSubscription>[];

      // Pause configuration: Customers 10-25 have a festival pause from Oct 18 to Oct 22 (5 days)
      final pauses = <LocalDateRange>[];
      if (i >= 10 && i <= 25) {
        pauses.add(
          const LocalDateRange(
            start: LocalDate(2026, 10, 18),
            end: LocalDate(2026, 10, 22),
          ),
        );
      }

      if (i <= 50 || (i >= 20 && i <= 30)) {
        subs.add(
          NewspaperSubscription(
            id: 'sub_jagran_$custId',
            newspaperId: 'pub_jagran',
            startDate: const LocalDate(2026, 10, 1),
            pauses: pauses,
          ),
        );
      }

      if (i > 50 || (i >= 20 && i <= 30)) {
        subs.add(
          NewspaperSubscription(
            id: 'sub_toi_$custId',
            newspaperId: 'pub_toi',
            startDate: const LocalDate(2026, 10, 1),
            pauses: pauses,
          ),
        );
      }

      customerSubscriptions[custId] = subs;
    }

    test('100-Customer Route Distribution & Morning Circulation Accuracy', () {
      expect(customers.length, 100);

      final northCustomers = customers.where((c) => c.assignedEmployeeId == 'emp_north').toList();
      final southCustomers = customers.where((c) => c.assignedEmployeeId == 'emp_south').toList();
      final centralCustomers = customers.where((c) => c.assignedEmployeeId == 'emp_central').toList();

      expect(northCustomers.length, 35);
      expect(southCustomers.length, 35);
      expect(centralCustomers.length, 30);

      // Verify Morning Route circulation on Oct 10 (normal day, no pauses active)
      var activeJagranOct10 = 0;
      var activeToiOct10 = 0;
      for (final cust in customers) {
        final subs = customerSubscriptions[cust.id]!;
        for (final sub in subs) {
          if (sub.isDeliveredOn(const LocalDate(2026, 10, 10))) {
            if (sub.newspaperId == 'pub_jagran') activeJagranOct10++;
            if (sub.newspaperId == 'pub_toi') activeToiOct10++;
          }
        }
      }

      // Customers 1-50 (50) + dual 20-30 (already counted in 1-50) = 50 Jagran
      // Customers 51-100 (50) + dual 20-30 (11) = 61 TOI
      expect(activeJagranOct10, 50);
      expect(activeToiOct10, 61);
      expect(activeJagranOct10 + activeToiOct10, 111, reason: 'Total morning circulation copies');

      // Verify Morning Route on Oct 20 (during festival pause for customers 10-25: 16 customers paused)
      var activeJagranOct20 = 0;
      var activeToiOct20 = 0;
      for (final cust in customers) {
        final subs = customerSubscriptions[cust.id]!;
        for (final sub in subs) {
          if (sub.isDeliveredOn(const LocalDate(2026, 10, 20))) {
            if (sub.newspaperId == 'pub_jagran') activeJagranOct20++;
            if (sub.newspaperId == 'pub_toi') activeToiOct20++;
          }
        }
      }

      // 16 paused customers (cust 10-25).
      // Jagran (cust 1-50): 50 - 16 paused = 34 active copies
      // TOI (cust 51-100 [50] + dual 20-30 [11]): 61 - 6 paused (cust 20-25) = 55 active copies
      expect(activeJagranOct20, 34);
      expect(activeToiOct20, 55);
    });

    test('100-Customer Monthly Bill Generation, Dynamic Pricing & Pause Exclusions', () {
      final billingResults = <String, BillingResult>{};
      var agencyTotalCurrentCharges = 0;

      for (final cust in customers) {
        final result = billingEngine.calculate(
          BillingRequest(
            customerId: cust.id,
            billingMonth: billingMonth,
            subscriptions: customerSubscriptions[cust.id]!,
            priceSchedules: [jagranSchedule, toiSchedule],
          ),
        );

        billingResults[cust.id] = result;
        agencyTotalCurrentCharges += result.currentChargesPaise;

        // Customer without pause (e.g. Cust 1) vs Customer with pause (Cust 10)
        if (cust.id == 'cust_001') {
          // Unpaused single Jagran: 31 days
          expect(result.charges.length, 31);
        } else if (cust.id == 'cust_010') {
          // Paused Oct 18-22 (5 days): 31 - 5 = 26 delivery charges
          expect(result.charges.length, 26);
        } else if (cust.id == 'cust_020') {
          // Dual subscription (Jagran + TOI) with pause (5 days each): (31 - 5) * 2 = 52 delivery charges
          expect(result.charges.length, 52);
        }
      }

      expect(billingResults.length, 100);
      expect(agencyTotalCurrentCharges, greaterThan(1500000), reason: 'Agency total charges exceed ₹15,000');
    });

    test('Ledger Reconciliation: Partial Payments, Full Settlements, and Head Reversals', () {
      var agencyTotalOpening = 0;
      var agencyTotalBilled = 0;
      var agencyTotalNetPaid = 0;
      var agencyTotalEndingBalance = 0;

      for (var idx = 0; idx < customers.length; idx++) {
        final cust = customers[idx];
        final opening = customerOpeningBalances[cust.id]!;
        agencyTotalOpening += opening;

        final billing = billingEngine.calculate(
          BillingRequest(
            customerId: cust.id,
            billingMonth: billingMonth,
            subscriptions: customerSubscriptions[cust.id]!,
            priceSchedules: [jagranSchedule, toiSchedule],
          ),
        );
        final billed = billing.currentChargesPaise;
        agencyTotalBilled += billed;

        final totalDue = opening + billed;
        final payments = <PaymentRecord>[];
        final reversals = <PaymentReversal>[];

        if (idx < 40) {
          // Full settlement via UPI / Cash
          payments.add(
            PaymentRecord(
              id: 'pay_full_${cust.id}',
              billId: 'bill_202610_${cust.id}',
              amountPaise: totalDue,
              status: PaymentStatus.manuallyConfirmed,
            ),
          );
        } else if (idx < 80) {
          // Partial collection (pays 50%)
          final partialAmount = (totalDue / 2).round();
          payments.add(
            PaymentRecord(
              id: 'pay_part_${cust.id}',
              billId: 'bill_202610_${cust.id}',
              amountPaise: partialAmount,
              status: PaymentStatus.manuallyConfirmed,
            ),
          );
        } else if (idx < 82) {
          // 2 Payments with Head corrections/reversals
          final paymentId = 'pay_rev_${cust.id}';
          payments.add(
            PaymentRecord(
              id: paymentId,
              billId: 'bill_202610_${cust.id}',
              amountPaise: totalDue,
              status: PaymentStatus.manuallyConfirmed,
            ),
          );
          reversals.add(
            PaymentReversal(
              id: 'rev_${cust.id}',
              paymentId: paymentId,
              amountPaise: totalDue,
            ),
          );
        }
        // Remaining customers (idx 82-99) remain unpaid (0 payments)

        final summary = ledger.summarize(
          totalDuePaise: totalDue,
          payments: payments,
          reversals: reversals,
        );

        agencyTotalNetPaid += summary.netPaidPaise;
        agencyTotalEndingBalance += summary.remainingBalancePaise;

        // Invariant check for every individual customer
        expect(
          summary.netPaidPaise + summary.remainingBalancePaise,
          totalDue,
          reason: 'Customer ${cust.id} ledger integrity invariant',
        );

        if (idx < 40) {
          expect(summary.remainingBalancePaise, 0, reason: 'Full payers have 0 balance');
        } else if (idx >= 80) {
          expect(summary.remainingBalancePaise, totalDue, reason: 'Unpaid / fully reversed have full due remaining');
        }
      }

      // Strict Agency-Wide Ledger Reconciliation Invariant:
      // Opening Balance + Total Billed Charges - Net Paid Collections = Ending Outstanding Balance
      expect(
        agencyTotalOpening + agencyTotalBilled - agencyTotalNetPaid,
        agencyTotalEndingBalance,
        reason: 'Mathematical closing balance exact equality across 100 customers',
      );

      expect(agencyTotalNetPaid, greaterThan(0));
      expect(agencyTotalEndingBalance, greaterThan(0));
    });
  });
}
