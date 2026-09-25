import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/collections/domain/collection_repository.dart';
import 'package:paper_route/features/collections/presentation/collections_providers.dart';
import 'package:paper_route/features/collections/presentation/customer_collection_summary.dart';
import 'package:paper_route/features/customers/domain/customer.dart';

class _FakeCollectionsRepository implements CollectionsRepository {
  _FakeCollectionsRepository({
    CustomerOutstandingSummary? initialSummary,
    Object? initialError,
  })  : _current = initialSummary,
        _initialError = initialError;

  CustomerOutstandingSummary? _current;
  final Object? _initialError;
  final StreamController<CustomerOutstandingSummary> _controller =
      StreamController<CustomerOutstandingSummary>.broadcast(sync: true);

  void emit(CustomerOutstandingSummary summary) {
    _current = summary;
    _controller.add(summary);
  }

  void emitError(Object error) {
    _controller.addError(error);
  }

  @override
  Stream<CustomerOutstandingSummary> watchCustomerOutstanding({
    required String businessId,
    required String customerId,
  }) {
    final streamController = StreamController<CustomerOutstandingSummary>(sync: true);
    if (_initialError != null) {
      streamController.addError(_initialError);
    } else if (_current != null) {
      streamController.add(_current!);
    }
    final sub = _controller.stream.listen(
      streamController.add,
      onError: streamController.addError,
      onDone: streamController.close,
    );
    streamController.onCancel = sub.cancel;
    return streamController.stream;
  }

  @override
  Future<CustomerOutstandingSummary> fetchCustomerOutstanding({
    required AppUser actor,
    required String customerId,
  }) async => _current ?? await _controller.stream.first;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const founderHead = AppUser(
    uid: 'head-001',
    email: 'head@test.local',
    displayName: 'Founder Head',
    isEmailVerified: true,
    businessId: 'biz-test',
    role: UserRole.head,
    status: AccountStatus.active,
    permissions: {
      PermissionKey.recordPayments,
      PermissionKey.manageAssignedSubscriptions,
    },
  );

  const testCustomer = Customer(
    id: 'CUST-001',
    customerCode: 'CUST-001',
    businessId: 'biz-test',
    name: 'Rahul Sharma',
    phone: '9876543210',
    areaId: 'area-1',
    assignedEmployeeId: 'head-001',
    status: CustomerStatus.active,
    houseNumber: '101',
    address: 'Green Park',
    landmark: 'Near Temple',
  );

  group('Customer Outstanding Stream & Collection Summary', () {
    testWidgets(
      'customer has no collectionState + no finalized bills -> resolves to ₹0.00 without hanging',
      (tester) async {
        final zeroSummary = CustomerOutstandingSummary(
          businessId: 'biz-test',
          customerId: 'CUST-001',
          outstandingPaise: 0,
          confirmedPaise: 0,
          reversedPaise: 0,
          bills: const [],
          revision: 0,
          serverConfirmed: true,
          requiresProjectionSetup: false,
        );

        final fakeRepo = _FakeCollectionsRepository(initialSummary: zeroSummary);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              collectionsRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CustomerCollectionSummary(
                  user: founderHead,
                  customer: testCustomer,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Verify ₹0.00 outstanding is displayed
        expect(find.text('₹0.00'), findsOneWidget);
        expect(find.byKey(const ValueKey('customer-current-outstanding')), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);

        // Collect payment is disabled for zero balance
        final collectBtn = tester.widget<FilledButton>(
          find.byKey(const ValueKey('open-collect-payment')),
        );
        expect(collectBtn.onPressed, isNull);

        // Payment history button is enabled
        final historyBtn = tester.widget<OutlinedButton>(
          find.byKey(const ValueKey('open-customer-payments')),
        );
        expect(historyBtn.onPressed, isNotNull);
      },
    );

    testWidgets(
      'customer has finalized bill but no collectionState -> displays legacy bill amount and projection setup notice',
      (tester) async {
        final legacySummary = CustomerOutstandingSummary(
          businessId: 'biz-test',
          customerId: 'CUST-001',
          outstandingPaise: 45000,
          confirmedPaise: 0,
          reversedPaise: 0,
          bills: const [
            OutstandingBill(
              billId: '2026-08',
              billingMonth: '2026-08',
              sourceAmountPaise: 45000,
              allocatedPaise: 0,
              reversedPaise: 0,
              outstandingPaise: 45000,
              status: 'outstanding',
              revision: 0,
            ),
          ],
          revision: 0,
          serverConfirmed: true,
          requiresProjectionSetup: true,
        );

        final fakeRepo = _FakeCollectionsRepository(initialSummary: legacySummary);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              collectionsRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CustomerCollectionSummary(
                  user: founderHead,
                  customer: testCustomer,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('₹450.00'), findsOneWidget);
        expect(find.byKey(const ValueKey('customer-projection-required')), findsOneWidget);

        // Direct payment is disabled until projection is migrated
        final collectBtn = tester.widget<FilledButton>(
          find.byKey(const ValueKey('open-collect-payment')),
        );
        expect(collectBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'customer has active collectionState -> displays projected outstanding and allows payment collection',
      (tester) async {
        final projectedSummary = CustomerOutstandingSummary(
          businessId: 'biz-test',
          customerId: 'CUST-001',
          outstandingPaise: 30000,
          confirmedPaise: 10000,
          reversedPaise: 0,
          bills: const [
            OutstandingBill(
              billId: '2026-09',
              billingMonth: '2026-09',
              sourceAmountPaise: 40000,
              allocatedPaise: 10000,
              reversedPaise: 0,
              outstandingPaise: 30000,
              status: 'outstanding',
              revision: 1,
            ),
          ],
          revision: 1,
          serverConfirmed: true,
          requiresProjectionSetup: false,
        );

        final fakeRepo = _FakeCollectionsRepository(initialSummary: projectedSummary);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              collectionsRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CustomerCollectionSummary(
                  user: founderHead,
                  customer: testCustomer,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('₹300.00'), findsOneWidget);
        expect(find.byKey(const ValueKey('customer-projection-required')), findsNothing);

        final collectBtn = tester.widget<FilledButton>(
          find.byKey(const ValueKey('open-collect-payment')),
        );
        expect(collectBtn.onPressed, isNotNull);
      },
    );

    testWidgets(
      'payment and reversal mutations stream updates to outstanding summary dynamically',
      (tester) async {
        final fakeRepo = _FakeCollectionsRepository(
          initialSummary: CustomerOutstandingSummary(
            businessId: 'biz-test',
            customerId: 'CUST-001',
            outstandingPaise: 50000,
            confirmedPaise: 0,
            reversedPaise: 0,
            bills: const [],
            revision: 1,
            serverConfirmed: true,
            requiresProjectionSetup: false,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              collectionsRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CustomerCollectionSummary(
                  user: founderHead,
                  customer: testCustomer,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('₹500.00'), findsOneWidget);

        // After ₹200 payment collected -> ₹300.00
        fakeRepo.emit(
          CustomerOutstandingSummary(
            businessId: 'biz-test',
            customerId: 'CUST-001',
            outstandingPaise: 30000,
            confirmedPaise: 20000,
            reversedPaise: 0,
            bills: const [],
            revision: 2,
            serverConfirmed: true,
            requiresProjectionSetup: false,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('₹300.00'), findsOneWidget);

        // After payment reversal -> ₹500.00
        fakeRepo.emit(
          CustomerOutstandingSummary(
            businessId: 'biz-test',
            customerId: 'CUST-001',
            outstandingPaise: 50000,
            confirmedPaise: 20000,
            reversedPaise: 20000,
            bills: const [],
            revision: 3,
            serverConfirmed: true,
            requiresProjectionSetup: false,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('₹500.00'), findsOneWidget);
      },
    );

    testWidgets(
      'error state shows error message and Try again button',
      (tester) async {
        final key = (businessId: 'biz-test', customerId: 'CUST-001');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              customerOutstandingProvider(key).overrideWith(
                (ref) => Stream.error(const AppException('Firestore permission denied')),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CustomerCollectionSummary(
                  user: founderHead,
                  customer: testCustomer,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.textContaining('Could not load current outstanding'), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
      },
    );
  });
}
