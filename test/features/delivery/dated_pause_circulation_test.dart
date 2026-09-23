import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/domain/customer_repository.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:paper_route/features/delivery/data/firebase_delivery_repository.dart';
import 'package:paper_route/features/delivery/domain/delivery_models.dart';
import 'package:paper_route/features/delivery/presentation/delivery_providers.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';
import 'package:paper_route/features/subscriptions/domain/subscription_repository.dart';
import 'package:paper_route/features/subscriptions/presentation/subscription_providers.dart';

/// Minimal in-memory subscription repository for testing pause reads.
class _StubSubscriptionRepository implements SubscriptionRepository {
  final Map<String, List<SubscriptionPause>> _pauses = {};
  final Map<String, List<CustomerSubscription>> _subscriptions = {};

  void seedPauses(String key, List<SubscriptionPause> pauses) {
    _pauses[key] = pauses;
  }

  void seedSubscriptions(String key, List<CustomerSubscription> subscriptions) {
    _subscriptions[key] = subscriptions;
  }

  @override
  Stream<List<SubscriptionPause>> watchPauses({
    required String businessId,
    required String customerId,
    required String subscriptionId,
  }) {
    final key = '$businessId:$customerId:$subscriptionId';
    return Stream.value(_pauses[key] ?? const []);
  }

  @override
  Stream<List<CustomerSubscription>> watchCustomerSubscriptions({
    required String businessId,
    required String customerId,
  }) {
    final key = '$businessId:$customerId';
    return Stream.value(_subscriptions[key] ?? const []);
  }

  @override
  Stream<CustomerSubscription?> watchSubscription({
    required String businessId,
    required String customerId,
    required String subscriptionId,
  }) =>
      Stream.value(null);

  @override
  Stream<List<SubscriptionVersion>> watchVersions({
    required String businessId,
    required String customerId,
    required String subscriptionId,
  }) =>
      Stream.value([]);

  @override
  Stream<List<SubscriptionAuditEntry>> watchHistory({
    required String businessId,
    required String customerId,
    required String subscriptionId,
  }) =>
      Stream.value([]);

  @override
  Future<String> createSubscription({
    required AppUser actor,
    required String customerId,
    required SubscriptionInput input,
  }) async =>
      '';

  @override
  Future<void> replaceTerms({
    required AppUser actor,
    required String customerId,
    required String subscriptionId,
    required LocalDate effectiveFrom,
    required SubscriptionInput replacement,
  }) async {}

  @override
  Future<void> addPause({
    required AppUser actor,
    required String customerId,
    required String subscriptionId,
    required LocalDate startDate,
    required LocalDate? endDate,
    required String reason,
  }) async {}

  @override
  Future<void> resumeSubscription({
    required AppUser actor,
    required String customerId,
    required String subscriptionId,
    required String pauseId,
    required LocalDate resumeDate,
  }) async {}

  @override
  Future<void> endSubscription({
    required AppUser actor,
    required String customerId,
    required String subscriptionId,
    required LocalDate endDate,
  }) async {}

  @override
  Future<void> pauseAllCustomerSubscriptions({
    required AppUser actor,
    required String customerId,
    required LocalDate startDate,
    required LocalDate? endDate,
    required String reason,
    required List<String> subscriptionIds,
  }) async {}

  @override
  Future<void> resumeAllCustomerSubscriptions({
    required AppUser actor,
    required String customerId,
    required LocalDate resumeDate,
    required List<String> subscriptionIds,
  }) async {}
}

/// Minimal CustomerRepository that returns canned customers.
class _InlineCustomerRepository implements CustomerRepository {
  _InlineCustomerRepository({required this.customers});
  final List<Customer> customers;

  @override
  Future<CustomerPage> fetchCustomers(CustomerListRequest request) async {
    final filtered = customers
        .where(
          (c) =>
              c.businessId == request.businessId &&
              (request.areaId.isEmpty || c.areaId == request.areaId) &&
              c.status == request.status,
        )
        .toList();
    return CustomerPage(
      customers: filtered,
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Stream<Customer?> watchCustomer({
    required String businessId,
    required String customerId,
  }) =>
      Stream.value(null);

  @override
  Stream<List<CustomerAuditEntry>> watchCustomerHistory({
    required String businessId,
    required String customerId,
  }) =>
      Stream.value([]);

  @override
  Future<String> createCustomer({
    required AppUser actor,
    required CustomerInput input,
  }) async =>
      '';

  @override
  Future<void> updateCustomerProfile({
    required AppUser actor,
    required String customerId,
    required CustomerInput input,
  }) async {}

  @override
  Future<void> setCustomerArchived({
    required AppUser actor,
    required String customerId,
    required bool archived,
  }) async {}

  @override
  Future<void> assignCustomer({
    required AppUser actor,
    required String customerId,
    required String employeeId,
    required String areaId,
  }) async {}
}

void main() {
  const today = LocalDate(2026, 10, 15); // Wednesday = isoWeekday 3

  const testUser = AppUser(
    uid: 'emp-1',
    email: 'emp@test.local',
    displayName: 'Ramesh',
    isEmailVerified: true,
    businessId: 'biz-1',
    role: UserRole.employee,
    status: AccountStatus.active,
    areaIds: {'area-1'},
  );

  /// A subscription that is active on today (Wed) and delivered all weekdays.
  CustomerSubscription activeSub({
    String id = 'sub-1',
    SubscriptionStatus status = SubscriptionStatus.active,
  }) =>
      CustomerSubscription(
        id: id,
        businessId: 'biz-1',
        customerId: 'cust-1',
        newspaperId: id,
        newspaperName: 'Test Paper',
        currentVersionId: 'v-1',
        currentPauseId: '',
        status: status,
        startDate: const LocalDate(2026, 1, 1),
        endDate: null,
        currentEffectiveFrom: const LocalDate(2026, 1, 1),
        quantity: 2,
        deliveryWeekdays: const {1, 2, 3, 4, 5, 6, 7},
        customPricePaise: null,
        customPriceReason: '',
        createdBy: 'head',
        updatedBy: 'head',
        lastAuditId: 'audit-1',
      );

  Customer testCustomer() => const Customer(
        id: 'cust-1',
        businessId: 'biz-1',
        customerCode: 'C001',
        name: 'Raj Kumar',
        phone: '9876543210',
        houseNumber: '12-B',
        buildingInfo: 'Tower A',
        address: 'MG Road',
        landmark: 'Near Temple',
        deliveryPlacement: DeliveryPlacement.doorstep,
        assignedEmployeeId: 'emp-1',
        areaId: 'area-1',
        status: CustomerStatus.active,
      );

  /// Creates the standard set of provider overrides used across all tests.
  /// Creates a ProviderContainer with standard test overrides.
  ProviderContainer createContainer({
    required _StubSubscriptionRepository stubSubRepo,
    required List<CustomerSubscription> subscriptions,
  }) {
    stubSubRepo.seedSubscriptions('biz-1:cust-1', subscriptions);
    return ProviderContainer(
      overrides: [
        morningRouteDateProvider.overrideWith(
          () => _FixedDateNotifier(today),
        ),
        selectedRouteAreaProvider.overrideWith(
          () => _FixedAreaNotifier('area-1'),
        ),
        deliveryRepositoryProvider.overrideWith(
          (ref) => InMemoryDeliveryRepository(),
        ),
        subscriptionRepositoryProvider.overrideWith(
          (ref) => stubSubRepo,
        ),
        deliveryAreasProvider('biz-1').overrideWith(
          (ref) => Stream.value([
            const DeliveryArea(
              id: 'area-1',
              name: 'Sector 4',
              isActive: true,
              assignedEmployeeIds: {'emp-1'},
            ),
          ]),
        ),
        customerSubscriptionsProvider((
          businessId: 'biz-1',
          customerId: 'cust-1',
        ),).overrideWith(
          (ref) => Stream.value(subscriptions),
        ),
        customerRepositoryProvider.overrideWith(
          (ref) => _InlineCustomerRepository(customers: [testCustomer()]),
        ),
        routeDropsStreamProvider((
          businessId: 'biz-1',
          areaId: 'area-1',
          date: today,
        ),).overrideWith(
          (ref) => Stream.value(const <String, DeliveryDropRecord>{}),
        ),
      ],
    );
  }

  group('Dated Pause Circulation Tests', () {
    test(
      'marks subscription as paused when a dated pause covers today',
      () async {
        final stubSubRepo = _StubSubscriptionRepository();
        // Seed a dated pause covering today: Oct 12 – Oct 18
        stubSubRepo.seedPauses('biz-1:cust-1:sub-1', [
          const SubscriptionPause(
            id: 'P-DATED',
            businessId: 'biz-1',
            customerId: 'cust-1',
            subscriptionId: 'sub-1',
            startDate: LocalDate(2026, 10, 12),
            endDate: LocalDate(2026, 10, 18),
            reason: 'Family vacation',
            status: 'closed',
            createdBy: 'head',
            updatedBy: 'head',
            lastAuditId: 'a-1',
          ),
        ]);

        final container = createContainer(
          stubSubRepo: stubSubRepo,
          subscriptions: [activeSub()],
        );
        addTearDown(container.dispose);

        final stops = await container
            .read(morningRouteStopsProvider(testUser).future);

        expect(stops, hasLength(1));
        expect(stops.first.drops, hasLength(1));
        expect(stops.first.drops.first.isPaused, isTrue);
        expect(
          stops.first.drops.first.pauseReason,
          equals('Family vacation'),
        );
        expect(stops.first.isPausedToday, isTrue);
      },
    );

    test(
      'does NOT pause when dated pause is in the future',
      () async {
        final stubSubRepo = _StubSubscriptionRepository();
        // Future pause: Oct 20 – Oct 25 (today is Oct 15)
        stubSubRepo.seedPauses('biz-1:cust-1:sub-1', [
          const SubscriptionPause(
            id: 'P-FUTURE',
            businessId: 'biz-1',
            customerId: 'cust-1',
            subscriptionId: 'sub-1',
            startDate: LocalDate(2026, 10, 20),
            endDate: LocalDate(2026, 10, 25),
            reason: 'Future trip',
            status: 'closed',
            createdBy: 'head',
            updatedBy: 'head',
            lastAuditId: 'a-1',
          ),
        ]);

        final container = createContainer(
          stubSubRepo: stubSubRepo,
          subscriptions: [activeSub()],
        );
        addTearDown(container.dispose);

        final stops = await container
            .read(morningRouteStopsProvider(testUser).future);

        expect(stops, hasLength(1));
        expect(stops.first.drops.first.isPaused, isFalse);
        expect(stops.first.isPausedToday, isFalse);
      },
    );

    test(
      'treats inclusive end date correctly (last day of pause)',
      () async {
        final stubSubRepo = _StubSubscriptionRepository();
        // Pause ends today: Oct 10 – Oct 15 (today is Oct 15 — still paused)
        stubSubRepo.seedPauses('biz-1:cust-1:sub-1', [
          const SubscriptionPause(
            id: 'P-LAST-DAY',
            businessId: 'biz-1',
            customerId: 'cust-1',
            subscriptionId: 'sub-1',
            startDate: LocalDate(2026, 10, 10),
            endDate: LocalDate(2026, 10, 15),
            reason: 'Last day inclusive',
            status: 'closed',
            createdBy: 'head',
            updatedBy: 'head',
            lastAuditId: 'a-1',
          ),
        ]);

        final container = createContainer(
          stubSubRepo: stubSubRepo,
          subscriptions: [activeSub()],
        );
        addTearDown(container.dispose);

        final stops = await container
            .read(morningRouteStopsProvider(testUser).future);

        expect(stops, hasLength(1));
        expect(
          stops.first.drops.first.isPaused,
          isTrue,
          reason: 'Last day of a dated pause should still be paused',
        );
      },
    );

    test(
      'resumes delivery the day after pause end date',
      () async {
        final stubSubRepo = _StubSubscriptionRepository();
        // Pause expired yesterday: Oct 10 – Oct 14 (today is Oct 15)
        stubSubRepo.seedPauses('biz-1:cust-1:sub-1', [
          const SubscriptionPause(
            id: 'P-EXPIRED',
            businessId: 'biz-1',
            customerId: 'cust-1',
            subscriptionId: 'sub-1',
            startDate: LocalDate(2026, 10, 10),
            endDate: LocalDate(2026, 10, 14),
            reason: 'Expired yesterday',
            status: 'closed',
            createdBy: 'head',
            updatedBy: 'head',
            lastAuditId: 'a-1',
          ),
        ]);

        final container = createContainer(
          stubSubRepo: stubSubRepo,
          subscriptions: [activeSub()],
        );
        addTearDown(container.dispose);

        final stops = await container
            .read(morningRouteStopsProvider(testUser).future);

        expect(stops, hasLength(1));
        expect(
          stops.first.drops.first.isPaused,
          isFalse,
          reason: 'Pause ended yesterday so delivery should resume today',
        );
      },
    );

    test(
      'per-publication quantity correctly splits paused vs active drops',
      () async {
        final stubSubRepo = _StubSubscriptionRepository();
        // First subscription has a dated pause today, second has no pauses
        stubSubRepo.seedPauses('biz-1:cust-1:sub-dj', [
          const SubscriptionPause(
            id: 'P-DJ',
            businessId: 'biz-1',
            customerId: 'cust-1',
            subscriptionId: 'sub-dj',
            startDate: LocalDate(2026, 10, 12),
            endDate: LocalDate(2026, 10, 18),
            reason: 'Vacation',
            status: 'closed',
            createdBy: 'head',
            updatedBy: 'head',
            lastAuditId: 'a-1',
          ),
        ]);
        stubSubRepo.seedPauses('biz-1:cust-1:sub-toi', []);

        final container = createContainer(
          stubSubRepo: stubSubRepo,
          subscriptions: [
            activeSub(id: 'sub-dj'),
            activeSub(id: 'sub-toi'),
          ],
        );
        addTearDown(container.dispose);

        final stops = await container
            .read(morningRouteStopsProvider(testUser).future);

        expect(stops, hasLength(1));
        expect(stops.first.drops, hasLength(2));
        // sub-dj should be paused, sub-toi should be active
        final pausedDrop = stops.first.drops
            .firstWhere((d) => d.newspaperId == 'sub-dj');
        final activeDrop = stops.first.drops
            .firstWhere((d) => d.newspaperId == 'sub-toi');
        expect(pausedDrop.isPaused, isTrue);
        expect(activeDrop.isPaused, isFalse);
        // Customer should NOT be fully paused (one active sub)
        expect(stops.first.isPausedToday, isFalse);
      },
    );
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _FixedDateNotifier extends MorningRouteDateNotifier {
  _FixedDateNotifier(this._date);
  final LocalDate _date;
  @override
  LocalDate build() => _date;
}

class _FixedAreaNotifier extends SelectedRouteAreaNotifier {
  _FixedAreaNotifier(this._areaId);
  final String _areaId;
  @override
  String build() => _areaId;
}
