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

class _TrackingCustomerRepo implements CustomerRepository {
  int fetchCallCount = 0;

  @override
  Future<CustomerPage> fetchCustomers(CustomerListRequest request) async {
    fetchCallCount += 1;
    return CustomerPage(
      customers: [
        Customer(
          id: 'cust-1',
          businessId: request.businessId,
          customerCode: 'C-001',
          name: 'Ramesh Patel',
          phone: '9876543210',
          areaId: request.areaId,
          assignedEmployeeId: request.requesterId,
          houseNumber: '101',
          address: 'Sector 4',
          status: CustomerStatus.active,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ],
      hasMore: false,
      nextCursor: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TrackingSubscriptionRepo implements SubscriptionRepository {
  int watchCallCount = 0;

  @override
  Stream<List<CustomerSubscription>> watchCustomerSubscriptions({
    required String businessId,
    required String customerId,
  }) {
    watchCallCount += 1;
    return Stream.value([
      const CustomerSubscription(
        id: 'sub-1',
        businessId: 'biz-1',
        customerId: 'cust-1',
        newspaperId: 'np-1',
        newspaperName: 'Dainik Bhaskar',
        currentVersionId: 'v-1',
        currentPauseId: '',
        status: SubscriptionStatus.active,
        startDate: LocalDate(2026, 1, 1),
        endDate: null,
        currentEffectiveFrom: LocalDate(2026, 1, 1),
        quantity: 1,
        deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
        customPricePaise: null,
        customPriceReason: '',
        createdBy: 'head',
        updatedBy: 'head',
        lastAuditId: 'audit-1',
      ),
    ]);
  }

  @override
  Stream<List<SubscriptionPause>> watchPauses({
    required String businessId,
    required String customerId,
    required String subscriptionId,
  }) {
    return Stream.value([]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AppUser Equality and HashCode', () {
    test('two instances with identical values are equal and have identical hashCode', () {
      const user1 = AppUser(
        uid: 'uid-123',
        email: 'agent@paperroute.test',
        displayName: 'Test Agent',
        isEmailVerified: true,
        businessId: 'biz-1',
        role: UserRole.employee,
        status: AccountStatus.active,
        permissions: {'recordPayments', 'addCustomers'},
        areaIds: {'area-1', 'area-2'},
      );

      const user2 = AppUser(
        uid: 'uid-123',
        email: 'agent@paperroute.test',
        displayName: 'Test Agent',
        isEmailVerified: true,
        businessId: 'biz-1',
        role: UserRole.employee,
        status: AccountStatus.active,
        permissions: {'addCustomers', 'recordPayments'},
        areaIds: {'area-2', 'area-1'},
      );

      expect(user1, equals(user2));
      expect(user1.hashCode, equals(user2.hashCode));
    });

    test('instances with different values are not equal', () {
      const user1 = AppUser(
        uid: 'uid-123',
        email: 'agent@paperroute.test',
        displayName: 'Test Agent',
        isEmailVerified: true,
        businessId: 'biz-1',
        role: UserRole.employee,
        status: AccountStatus.active,
        permissions: {'recordPayments'},
        areaIds: {'area-1'},
      );

      const user2 = AppUser(
        uid: 'uid-456',
        email: 'agent@paperroute.test',
        displayName: 'Test Agent',
        isEmailVerified: true,
        businessId: 'biz-1',
        role: UserRole.employee,
        status: AccountStatus.active,
        permissions: {'recordPayments'},
        areaIds: {'area-1'},
      );

      expect(user1, isNot(equals(user2)));
      expect(user1.hashCode, isNot(equals(user2.hashCode)));
    });
  });

  group('Morning Route Decoupled Providers', () {
    test('marking delivery stop status updates in-memory without re-fetching customer or subscriptions', () async {
      final customerRepo = _TrackingCustomerRepo();
      final subRepo = _TrackingSubscriptionRepo();
      final fixedDate = const LocalDate(2026, 10, 15); // Thursday

      const user = AppUser(
        uid: 'emp-1',
        email: 'emp@test.com',
        displayName: 'Employee',
        isEmailVerified: true,
        businessId: 'biz-1',
        role: UserRole.employee,
        status: AccountStatus.active,
        permissions: {'recordDeliveryExceptions', 'recordPayments'},
        areaIds: {'area-1'},
      );

      final container = ProviderContainer(
        overrides: [
          morningRouteDateProvider.overrideWith(
            () => _FixedDateNotifier(fixedDate),
          ),
          selectedRouteAreaProvider.overrideWith(
            () => _FixedAreaNotifier('area-1'),
          ),
          customerRepositoryProvider.overrideWithValue(customerRepo),
          subscriptionRepositoryProvider.overrideWithValue(subRepo),
          deliveryRepositoryProvider.overrideWithValue(InMemoryDeliveryRepository()),
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
          routeDropsStreamProvider((
            businessId: 'biz-1',
            areaId: 'area-1',
            date: fixedDate,
          ),).overrideWith(
            (ref) => Stream.value(const <String, DeliveryDropRecord>{}),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Initial read
      final initialStops = await container.read(morningRouteStopsProvider(user).future);
      expect(initialStops, hasLength(1));
      expect(initialStops.first.status, equals(DeliveryStopStatus.pending));
      expect(customerRepo.fetchCallCount, equals(1));
      expect(subRepo.watchCallCount, equals(1));

      // Mark delivered locally in deliveryStatusStateProvider
      await container.read(deliveryStatusStateProvider.notifier).markDelivered('cust-1');

      // Re-read morningRouteStopsProvider
      final updatedStops = await container.read(morningRouteStopsProvider(user).future);
      expect(updatedStops, hasLength(1));
      expect(updatedStops.first.status, equals(DeliveryStopStatus.delivered));

      // Base customer and subscription fetch call counts MUST NOT have incremented!
      expect(customerRepo.fetchCallCount, equals(1), reason: 'Base route customers should NOT re-fetch on status update');
      expect(subRepo.watchCallCount, equals(1), reason: 'Subscriptions should NOT re-query on status update');
    });
  });
}

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
