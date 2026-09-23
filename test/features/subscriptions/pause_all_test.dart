import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';

void main() {
  group('Pause-All & Inclusive Pause Logic', () {
    test('LocalDateRange is strictly inclusive of both start and end date', () {
      final range = LocalDateRange(
        start: const LocalDate(2026, 10, 10),
        end: const LocalDate(2026, 10, 15),
      );

      // Before start
      expect(range.contains(const LocalDate(2026, 10, 9)), isFalse);
      // Start date (inclusive)
      expect(range.contains(const LocalDate(2026, 10, 10)), isTrue);
      // Intermediate days
      expect(range.contains(const LocalDate(2026, 10, 12)), isTrue);
      // End date (inclusive)
      expect(range.contains(const LocalDate(2026, 10, 15)), isTrue);
      // After end (delivery resumed)
      expect(range.contains(const LocalDate(2026, 10, 16)), isFalse);
    });

    test('SubscriptionPause accurately verifies inclusive delivery boundaries', () {
      const pause = SubscriptionPause(
        id: 'P-123',
        businessId: 'biz-1',
        customerId: 'cust-1',
        subscriptionId: 'sub-1',
        startDate: LocalDate(2026, 10, 10),
        endDate: LocalDate(2026, 10, 15),
        reason: 'Vacation',
        status: 'closed',
        createdBy: 'user-1',
        updatedBy: 'user-1',
        lastAuditId: 'audit-1',
      );

      // Day before pause: delivered
      expect(pause.contains(const LocalDate(2026, 10, 9)), isFalse);
      // Paused days
      expect(pause.contains(const LocalDate(2026, 10, 10)), isTrue);
      expect(pause.contains(const LocalDate(2026, 10, 15)), isTrue);
      // Resumed day
      expect(pause.contains(const LocalDate(2026, 10, 16)), isFalse);
    });

    test('Open pause remains active until closed with resumeDate - 1', () {
      const openPause = SubscriptionPause(
        id: 'P-OPEN',
        businessId: 'biz-1',
        customerId: 'cust-1',
        subscriptionId: 'sub-1',
        startDate: LocalDate(2026, 10, 10),
        endDate: null,
        reason: 'Out of town',
        status: 'open',
        createdBy: 'user-1',
        updatedBy: 'user-1',
        lastAuditId: 'audit-1',
      );

      expect(openPause.isOpen, isTrue);
      expect(openPause.contains(const LocalDate(2026, 10, 10)), isTrue);
      expect(openPause.contains(const LocalDate(2026, 11, 1)), isTrue);

      // Closing when delivery resumes on 16 Oct sets end date to 15 Oct
      final resumeDate = const LocalDate(2026, 10, 16);
      final closedEnd = resumeDate.addDays(-1);
      expect(closedEnd, equals(const LocalDate(2026, 10, 15)));
    });
  });
}
