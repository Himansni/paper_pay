import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';
import 'package:paper_route/features/subscriptions/domain/subscription_repository.dart';

class _FakeAtomicSubscriptionRepository implements SubscriptionRepository {
  _FakeAtomicSubscriptionRepository({
    required this.validNewspaperIds,
    required this.activeNewspaperIds,
    required this.businessId,
    this.failTransaction = false,
  });

  final Set<String> validNewspaperIds;
  final Set<String> activeNewspaperIds;
  final String businessId;
  final bool failTransaction;

  final Map<String, CustomerSubscription> createdSubscriptions = {};
  final List<String> billingSourceAuditLog = [];

  @override
  Future<List<String>> createInitialSubscriptions({
    required AppUser actor,
    required String customerId,
    required List<SubscriptionInput> inputs,
  }) async {
    if (inputs.isEmpty) return const [];

    // In-memory pre-validation: duplicate check
    final requestedIds = <String>{};
    for (final input in inputs) {
      if (!requestedIds.add(input.newspaperId)) {
        throw const AppException('Duplicate publication selected.');
      }
      input.normalized().validate();
    }

    if (!actor.isHead && inputs.any((i) => i.customPricePaise != null)) {
      throw const AppException('Only the Head can authorize customer-specific pricing.');
    }

    // Atomic Transaction Simulation
    if (failTransaction) {
      throw const AppException('Transaction aborted due to network or contention failure.', code: 'transaction-failed');
    }

    // Validation inside transaction: all newspapers must exist, belong to business, and be active
    for (final input in inputs) {
      if (!validNewspaperIds.contains(input.newspaperId) ||
          !activeNewspaperIds.contains(input.newspaperId)) {
        throw const AppException('Select an active newspaper.');
      }
      if (createdSubscriptions.containsKey(input.newspaperId)) {
        throw const AppException('This customer already has a history for that newspaper.');
      }
    }

    // All checks passed -> Atomic writes for all subscriptions
    for (final input in inputs) {
      createdSubscriptions[input.newspaperId] = CustomerSubscription(
        id: input.newspaperId,
        businessId: businessId,
        customerId: customerId,
        newspaperId: input.newspaperId,
        newspaperName: 'Newspaper ${input.newspaperId}',
        currentVersionId: 'V-1',
        currentPauseId: '',
        quantity: input.quantity,
        status: SubscriptionStatus.active,
        startDate: input.startDate,
        endDate: input.endDate,
        currentEffectiveFrom: input.startDate,
        deliveryWeekdays: input.deliveryWeekdays,
        customPricePaise: input.customPricePaise,
        customPriceReason: input.customPriceReason,
        createdBy: actor.uid,
        updatedBy: actor.uid,
        lastAuditId: 'audit-${input.newspaperId}',
      );
    }

    billingSourceAuditLog.add('initialSubscriptionsCreated:${inputs.map((i) => i.newspaperId).join(',')}');
    return inputs.map((i) => i.newspaperId).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const headUser = AppUser(
    uid: 'head-001',
    email: 'head@paperroute.test',
    displayName: 'Founder Head',
    businessId: 'biz-1',
    role: UserRole.head,
    status: AccountStatus.active,
    isEmailVerified: true,
  );

  group('Atomic Multiple Initial Subscriptions Creation Tests (A-E)', () {
    test('A. Two valid publications -> both created atomically', () async {
      final repo = _FakeAtomicSubscriptionRepository(
        validNewspaperIds: {'NP-001', 'NP-002'},
        activeNewspaperIds: {'NP-001', 'NP-002'},
        businessId: 'biz-1',
      );

      final inputs = [
        const SubscriptionInput(
          newspaperId: 'NP-001',
          startDate: LocalDate(2026, 10, 1),
          endDate: null,
          quantity: 1,
          deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
          customPricePaise: null,
          customPriceReason: '',
        ),
        const SubscriptionInput(
          newspaperId: 'NP-002',
          startDate: LocalDate(2026, 10, 1),
          endDate: null,
          quantity: 2,
          deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
          customPricePaise: null,
          customPriceReason: '',
        ),
      ];

      final createdIds = await repo.createInitialSubscriptions(
        actor: headUser,
        customerId: 'CUST-100',
        inputs: inputs,
      );

      expect(createdIds, equals(['NP-001', 'NP-002']));
      expect(repo.createdSubscriptions.length, equals(2));
      expect(repo.createdSubscriptions['NP-001']!.quantity, equals(1));
      expect(repo.createdSubscriptions['NP-002']!.quantity, equals(2));
      expect(repo.billingSourceAuditLog.length, equals(1));
    });

    test('B. One invalid/inactive/cross-tenant publication -> zero created (all-or-nothing)', () async {
      final repo = _FakeAtomicSubscriptionRepository(
        validNewspaperIds: {'NP-001'}, // NP-002 is invalid/missing/cross-tenant
        activeNewspaperIds: {'NP-001'},
        businessId: 'biz-1',
      );

      final inputs = [
        const SubscriptionInput(
          newspaperId: 'NP-001', // Valid
          startDate: LocalDate(2026, 10, 1),
          endDate: null,
          quantity: 1,
          deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
          customPricePaise: null,
          customPriceReason: '',
        ),
        const SubscriptionInput(
          newspaperId: 'NP-INVALID', // Invalid
          startDate: LocalDate(2026, 10, 1),
          endDate: null,
          quantity: 1,
          deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
          customPricePaise: null,
          customPriceReason: '',
        ),
      ];

      expect(
        () => repo.createInitialSubscriptions(
          actor: headUser,
          customerId: 'CUST-100',
          inputs: inputs,
        ),
        throwsA(isA<AppException>().having((e) => e.message, 'message', contains('active newspaper'))),
      );

      // Verify ZERO partial writes occurred
      expect(repo.createdSubscriptions.isEmpty, isTrue);
      expect(repo.billingSourceAuditLog.isEmpty, isTrue);
    });

    test('C. Duplicate publication IDs -> rejected with zero partial writes', () async {
      final repo = _FakeAtomicSubscriptionRepository(
        validNewspaperIds: {'NP-001'},
        activeNewspaperIds: {'NP-001'},
        businessId: 'biz-1',
      );

      final inputs = [
        const SubscriptionInput(
          newspaperId: 'NP-001',
          startDate: LocalDate(2026, 10, 1),
          endDate: null,
          quantity: 1,
          deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
          customPricePaise: null,
          customPriceReason: '',
        ),
        const SubscriptionInput(
          newspaperId: 'NP-001', // Duplicate ID
          startDate: LocalDate(2026, 10, 1),
          endDate: null,
          quantity: 2,
          deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
          customPricePaise: null,
          customPriceReason: '',
        ),
      ];

      expect(
        () => repo.createInitialSubscriptions(
          actor: headUser,
          customerId: 'CUST-100',
          inputs: inputs,
        ),
        throwsA(isA<AppException>().having((e) => e.message, 'message', contains('Duplicate publication'))),
      );

      expect(repo.createdSubscriptions.isEmpty, isTrue);
    });

    test('D. Transaction/write failure -> zero partial requested subscriptions', () async {
      final repo = _FakeAtomicSubscriptionRepository(
        validNewspaperIds: {'NP-001', 'NP-002'},
        activeNewspaperIds: {'NP-001', 'NP-002'},
        businessId: 'biz-1',
        failTransaction: true, // Simulating failure
      );

      final inputs = [
        const SubscriptionInput(
          newspaperId: 'NP-001',
          startDate: LocalDate(2026, 10, 1),
          endDate: null,
          quantity: 1,
          deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
          customPricePaise: null,
          customPriceReason: '',
        ),
        const SubscriptionInput(
          newspaperId: 'NP-002',
          startDate: LocalDate(2026, 10, 1),
          endDate: null,
          quantity: 1,
          deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
          customPricePaise: null,
          customPriceReason: '',
        ),
      ];

      expect(
        () => repo.createInitialSubscriptions(
          actor: headUser,
          customerId: 'CUST-100',
          inputs: inputs,
        ),
        throwsA(isA<AppException>().having((e) => e.code, 'code', equals('transaction-failed'))),
      );

      expect(repo.createdSubscriptions.isEmpty, isTrue);
    });

    test('E. Separate legitimate editions/languages remain independent subscriptions', () async {
      final repo = _FakeAtomicSubscriptionRepository(
        validNewspaperIds: {'NP-BHOPAL-HINDI', 'NP-INDORE-HINDI', 'NP-BHOPAL-ENGLISH'},
        activeNewspaperIds: {'NP-BHOPAL-HINDI', 'NP-INDORE-HINDI', 'NP-BHOPAL-ENGLISH'},
        businessId: 'biz-1',
      );

      final inputs = [
        const SubscriptionInput(
          newspaperId: 'NP-BHOPAL-HINDI',
          startDate: LocalDate(2026, 10, 1),
          endDate: null,
          quantity: 1,
          deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
          customPricePaise: null,
          customPriceReason: '',
        ),
        const SubscriptionInput(
          newspaperId: 'NP-INDORE-HINDI', // Different edition
          startDate: LocalDate(2026, 10, 1),
          endDate: null,
          quantity: 1,
          deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
          customPricePaise: null,
          customPriceReason: '',
        ),
        const SubscriptionInput(
          newspaperId: 'NP-BHOPAL-ENGLISH', // Different language
          startDate: LocalDate(2026, 10, 1),
          endDate: null,
          quantity: 1,
          deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
          customPricePaise: null,
          customPriceReason: '',
        ),
      ];

      final createdIds = await repo.createInitialSubscriptions(
        actor: headUser,
        customerId: 'CUST-100',
        inputs: inputs,
      );

      expect(createdIds.length, equals(3));
      expect(repo.createdSubscriptions.length, equals(3));
      expect(repo.createdSubscriptions.containsKey('NP-BHOPAL-HINDI'), isTrue);
      expect(repo.createdSubscriptions.containsKey('NP-INDORE-HINDI'), isTrue);
      expect(repo.createdSubscriptions.containsKey('NP-BHOPAL-ENGLISH'), isTrue);
    });
  });
}
