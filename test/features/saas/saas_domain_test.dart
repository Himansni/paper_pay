import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/features/saas/domain/saas_models.dart';

void main() {
  group('SaasSubscription domain and trial calculations', () {
    final activationTime = DateTime(2026, 9, 1, 10, 0);

    test('initial trial creates exact 30-day duration starting at activation', () {
      final sub = SaasSubscription.initialTrial(
        businessId: 'biz-1',
        activationTime: activationTime,
      );

      expect(sub.businessId, 'biz-1');
      expect(sub.planId, SaasPlanTier.trial.id);
      expect(sub.status, SaasSubscriptionStatus.trial);
      expect(sub.trialStartsAt, activationTime);
      expect(sub.trialEndsAt, activationTime.add(const Duration(days: 30)));
      expect(sub.graceDays, 7);
      expect(sub.customerLimit, 500);
      expect(sub.employeeLimit, 10);
    });

    test('existing agency with historical activation time never receives duplicate 30 days', () {
      // Activated 20 days ago
      final historicalActivation = DateTime(2026, 8, 12, 10, 0);
      final checkTime = DateTime(2026, 9, 1, 10, 0);

      final sub = SaasSubscription.fromMap(
        'biz-existing',
        null,
        fallbackActivationTime: historicalActivation,
      );

      expect(sub.trialStartsAt, historicalActivation);
      expect(sub.trialEndsAt, historicalActivation.add(const Duration(days: 30)));
      // Exactly 10 days remaining, NOT 30
      expect(sub.daysRemaining(checkTime), 10);
      expect(sub.canPerformWrites(checkTime), isTrue);
      expect(sub.isReadOnly(checkTime), isFalse);
    });

    test('evaluates day remaining countdown accurately at different intervals', () {
      final sub = SaasSubscription.initialTrial(
        businessId: 'biz-1',
        activationTime: activationTime,
      );

      // On day 1 (same day, 5 hours later)
      expect(sub.daysRemaining(activationTime.add(const Duration(hours: 5))), 30);
      // On day 15
      expect(sub.daysRemaining(activationTime.add(const Duration(days: 15))), 15);
      // On day 29
      expect(sub.daysRemaining(activationTime.add(const Duration(days: 29))), 1);
      // On day 30 exact expiration moment
      expect(sub.daysRemaining(activationTime.add(const Duration(days: 30))), 0);
      // Past day 30
      expect(sub.daysRemaining(activationTime.add(const Duration(days: 31))), 0);
    });

    test('agency enters 7-day grace period immediately when trial expires', () {
      final sub = SaasSubscription.initialTrial(
        businessId: 'biz-1',
        activationTime: activationTime,
      );

      // 32 days after activation (2 days past trial end, within 7 day grace)
      final checkTime = activationTime.add(const Duration(days: 32));

      expect(sub.effectiveStatus(checkTime), SaasSubscriptionStatus.gracePeriod);
      expect(sub.isInGracePeriod(checkTime), isTrue);
      expect(sub.daysRemaining(checkTime), 0);
      expect(sub.graceDaysRemaining(checkTime), 5);
      // Writes are still allowed during grace period
      expect(sub.canPerformWrites(checkTime), isTrue);
      expect(sub.isReadOnly(checkTime), isFalse);
    });

    test('agency switches to read-only mode after trial + grace period expires', () {
      final sub = SaasSubscription.initialTrial(
        businessId: 'biz-1',
        activationTime: activationTime,
      );

      // 38 days after activation (30 days trial + 7 days grace = 37 days, so 38 is expired)
      final checkTime = activationTime.add(const Duration(days: 38));

      expect(sub.effectiveStatus(checkTime), SaasSubscriptionStatus.expired);
      expect(sub.isInGracePeriod(checkTime), isFalse);
      expect(sub.daysRemaining(checkTime), 0);
      expect(sub.graceDaysRemaining(checkTime), 0);
      // Account is strictly in read-only mode
      expect(sub.isReadOnly(checkTime), isTrue);
      expect(sub.canPerformWrites(checkTime), isFalse);
    });

    test('active paid subscription overrides trial and maintains writes', () {
      final sub = SaasSubscription(
        businessId: 'biz-1',
        planId: 'growth',
        status: SaasSubscriptionStatus.active,
        trialStartsAt: activationTime,
        trialEndsAt: activationTime.add(const Duration(days: 30)),
        currentPeriodStartsAt: activationTime.add(const Duration(days: 30)),
        currentPeriodEndsAt: activationTime.add(const Duration(days: 60)),
        customerLimit: 1000,
        employeeLimit: 10,
      );

      final checkTime = activationTime.add(const Duration(days: 45));

      expect(sub.effectiveStatus(checkTime), SaasSubscriptionStatus.active);
      expect(sub.daysRemaining(checkTime), 15);
      expect(sub.canPerformWrites(checkTime), isTrue);
      expect(sub.isReadOnly(checkTime), isFalse);
    });

    test('plan catalog defines realistic tier limits and features', () {
      final catalog = SaasPlan.catalog;
      expect(catalog, hasLength(3));

      final starter = catalog.firstWhere((p) => p.id == 'starter');
      expect(starter.customerLimit, 300);
      expect(starter.employeeLimit, 3);

      final growth = catalog.firstWhere((p) => p.id == 'growth');
      expect(growth.customerLimit, 1000);
      expect(growth.employeeLimit, 10);
      expect(growth.isPopular, isTrue);

      final pro = catalog.firstWhere((p) => p.id == 'agencyPro');
      expect(pro.customerLimit, 10000);
      expect(pro.employeeLimit, 100);
    });
  });
}
