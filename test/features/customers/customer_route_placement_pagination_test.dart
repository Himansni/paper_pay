import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/domain/customer_removal_request.dart';
import 'package:paper_route/features/customers/domain/customer_repository.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';

Customer _buildCustomer(int index, {String areaId = 'area-1'}) {
  return Customer(
    id: 'cust-$index',
    businessId: 'biz-1',
    customerCode: 'C-$index',
    name: 'Customer $index',
    phone: '9876543210',
    address: 'Address $index',
    areaId: areaId,
    assignedEmployeeId: 'emp-1',
    deliveryPlacement: DeliveryPlacement.doorstep,
    billingCycle: BillingCyclePreference.monthly,
    status: CustomerStatus.active,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

class _MockPaginatedCustomerRepository implements CustomerRepository {
  _MockPaginatedCustomerRepository(this.allCustomers, {this.simulateStall = false});

  final List<Customer> allCustomers;
  final bool simulateStall;
  final List<int> requestedPageSizes = [];

  @override
  Future<CustomerPage> fetchCustomers(CustomerListRequest request) async {
    requestedPageSizes.add(request.pageSize);

    if (request.pageSize > 50) {
      throw const AppException('Page size cannot exceed 50.');
    }

    if (simulateStall && request.cursor != null) {
      // Return same cursor without advancing
      return CustomerPage(
        customers: [_buildCustomer(999)],
        nextCursor: request.cursor,
        hasMore: true,
      );
    }

    int startIndex = 0;
    if (request.cursor != null) {
      final idx = allCustomers.indexWhere((c) => c.id == request.cursor!.customerId);
      if (idx >= 0) {
        startIndex = idx + 1;
      }
    }

    final remaining = allCustomers.skip(startIndex).toList();
    final pageCustomers = remaining.take(request.pageSize).toList();
    final hasMore = remaining.length > request.pageSize;

    CustomerPageCursor? nextCursor;
    if (hasMore && pageCustomers.isNotEmpty) {
      final last = pageCustomers.last;
      nextCursor = CustomerPageCursor(
        customerId: last.id,
        searchName: last.name.toLowerCase(),
      );
    }

    return CustomerPage(
      customers: pageCustomers,
      nextCursor: nextCursor,
      hasMore: hasMore,
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
      Stream.value(const []);

  @override
  Future<String> createCustomer({
    required AppUser actor,
    required CustomerInput input,
  }) async =>
      'id';

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

  @override
  Future<String> requestCustomerRemoval({
    required AppUser actor,
    required String customerId,
    required String reason,
  }) async =>
      'req-id';

  @override
  Stream<List<CustomerRemovalRequest>> watchPendingRemovalRequests({
    required String businessId,
    required String requesterId,
    required bool isHead,
  }) =>
      Stream.value(const []);

  @override
  Future<void> reviewRemovalRequest({
    required AppUser actor,
    required String requestId,
    required bool approved,
    String? reviewNotes,
  }) async {}
}

void main() {
  group('areaCustomersProvider cursor pagination', () {
    test('fetches 0 customers correctly', () async {
      final repo = _MockPaginatedCustomerRepository([]);
      final container = ProviderContainer(
        overrides: [
          customerRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        areaCustomersProvider((businessId: 'biz-1', areaId: 'area-1')).future,
      );

      expect(result, isEmpty);
      expect(repo.requestedPageSizes, [50]);
    });

    test('fetches exactly 1 customer correctly', () async {
      final repo = _MockPaginatedCustomerRepository([_buildCustomer(1)]);
      final container = ProviderContainer(
        overrides: [
          customerRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        areaCustomersProvider((businessId: 'biz-1', areaId: 'area-1')).future,
      );

      expect(result.length, 1);
      expect(result.first.id, 'cust-1');
      expect(repo.requestedPageSizes, [50]);
    });

    test('fetches exactly 50 customers in a single page', () async {
      final customers = List.generate(50, (i) => _buildCustomer(i + 1));
      final repo = _MockPaginatedCustomerRepository(customers);
      final container = ProviderContainer(
        overrides: [
          customerRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        areaCustomersProvider((businessId: 'biz-1', areaId: 'area-1')).future,
      );

      expect(result.length, 50);
      expect(result.first.id, 'cust-1');
      expect(result.last.id, 'cust-50');
      expect(repo.requestedPageSizes, [50]);
    });

    test('fetches 51+ customers across multiple pages (e.g. 105 customers)', () async {
      final customers = List.generate(105, (i) => _buildCustomer(i + 1));
      final repo = _MockPaginatedCustomerRepository(customers);
      final container = ProviderContainer(
        overrides: [
          customerRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        areaCustomersProvider((businessId: 'biz-1', areaId: 'area-1')).future,
      );

      expect(result.length, 105);
      expect(result.first.id, 'cust-1');
      expect(result.last.id, 'cust-105');
      // 105 items at 50 per page requires 3 page requests: [50, 50, 50]
      expect(repo.requestedPageSizes, [50, 50, 50]);
      for (final pageSize in repo.requestedPageSizes) {
        expect(pageSize, lessThanOrEqualTo(50));
      }
    });

    test('throws AppException on cursor progression failure', () async {
      final customers = List.generate(60, (i) => _buildCustomer(i + 1));
      final repo = _MockPaginatedCustomerRepository(customers, simulateStall: true);
      final container = ProviderContainer(
        overrides: [
          customerRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final completer = Completer<void>();
      late AsyncValue<List<Customer>> finalState;

      final sub = container.listen<AsyncValue<List<Customer>>>(
        areaCustomersProvider((businessId: 'biz-1', areaId: 'area-1')),
        (prev, next) {
          finalState = next;
          if (next.hasError && !completer.isCompleted) {
            completer.complete();
          }
        },
      );
      addTearDown(sub.close);

      await completer.future;

      expect(finalState.hasError, isTrue);
      expect(finalState.error, isA<AppException>());
      expect(
        (finalState.error as AppException).message,
        contains('Customer route pagination did not advance'),
      );
    });
  });
}
