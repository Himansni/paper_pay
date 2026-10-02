import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';

void main() {
  group('Monthly Bill Type-Safe Decoding', () {
    test('canonical String billingMonth "2026-09" is preserved', () {
      expect(
        parseBillingMonthFromFirestore('2026-09'),
        equals('2026-09'),
      );
    });

    test('known legacy integer representation 202609 is parsed to "2026-09"', () {
      expect(
        parseBillingMonthFromFirestore(202609),
        equals('2026-09'),
      );
    });

    test('known legacy 6-digit string representation "202609" is parsed to "2026-09"', () {
      expect(
        parseBillingMonthFromFirestore('202609'),
        equals('2026-09'),
      );
    });

    test('fallbackId is used when raw billingMonth is null and fallbackId is valid', () {
      expect(
        parseBillingMonthFromFirestore(null, fallbackId: '2026-09'),
        equals('2026-09'),
      );
    });

    test('invalid billingMonth throws AppException with code invalid-billing-month', () {
      expect(
        () => parseBillingMonthFromFirestore('invalid-month'),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            equals('invalid-billing-month'),
          ),
        ),
      );

      expect(
        () => parseBillingMonthFromFirestore(12345),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            equals('invalid-billing-month'),
          ),
        ),
      );

      expect(
        () => parseBillingMonthFromFirestore(null, fallbackId: ''),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            equals('invalid-billing-month'),
          ),
        ),
      );
    });

    test('parseCalculationVersionFromFirestore decodes int, num, string, or null safely', () {
      expect(parseCalculationVersionFromFirestore(null), equals(''));
      expect(parseCalculationVersionFromFirestore('v1'), equals('v1'));
      expect(parseCalculationVersionFromFirestore(1), equals('1'));
      expect(parseCalculationVersionFromFirestore(2.5), equals('2.5'));
    });

    test('FinalizedMonthlyBill.fromMap handles legacy integer calculationVersion and int fields without crash', () {
      final bill = FinalizedMonthlyBill.fromMap('2026-09', {
        'businessId': 'biz_test',
        'customerId': 'cust_test',
        'customerCode': 'C-TEST',
        'customerName': 'Test Customer',
        'customerAddress': 'Test Address',
        'billingMonth': 202609, // Legacy int representation
        'openingBalancePaise': 0,
        'previousBillId': 100, // Legacy int representation
        'previousOutstandingPaise': 0,
        'priorBalancePaise': 0,
        'currentChargesPaise': 24000,
        'adjustmentsPaise': 0,
        'totalDuePaise': 24000,
        'lineItemCount': 30,
        'calculationVersion': 1, // Legacy int calculationVersion that caused crash
        'finalizedBy': 'user_head',
        'lastAuditId': 'audit_1',
        'newspaperSummaries': [
          {
            'newspaperId': 'news_1',
            'newspaperName': 'Test Paper',
            'deliveryCount': 30,
            'totalPaise': 24000, // Legacy field name totalPaise vs subtotalPaise
          },
        ],
      });

      expect(bill.billingMonth, equals('2026-09'));
      expect(bill.calculationVersion, equals('1'));
      expect(bill.previousBillId, equals('100'));
      expect(bill.newspaperSummaries.first.subtotalPaise, equals(24000));
    });

    test('BillingAdjustment.fromMap handles legacy integer billingMonth safely', () {
      final adj = BillingAdjustment.fromMap('adj_1', {
        'billingMonth': 202609,
        'amountPaise': 5000,
        'reason': 'Correction',
        'referenceBillMonth': 202608,
        'createdBy': 'user_head',
      });

      expect(adj.billingMonth, equals('2026-09'));
      expect(adj.referenceBillMonth, equals('2026-08'));
      expect(adj.amountPaise, equals(5000));
    });
  });
}
