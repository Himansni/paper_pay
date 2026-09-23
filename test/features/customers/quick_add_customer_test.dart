import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/domain/customer_removal_request.dart';
import 'package:paper_route/features/customers/domain/customer_repository.dart';
import 'package:paper_route/features/customers/presentation/customer_form_page.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';

class FakeCustomerRepository implements CustomerRepository {
  final List<CustomerInput> createdInputs = [];

  @override
  Future<String> createCustomer({
    required AppUser actor,
    required CustomerInput input,
  }) async {
    createdInputs.add(input);
    return 'C-TEST-${createdInputs.length}';
  }

  @override
  Future<CustomerPage> fetchCustomers(CustomerListRequest request) async =>
      const CustomerPage(customers: [], nextCursor: null, hasMore: false);

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
  Stream<Customer?> watchCustomer({
    required String businessId,
    required String customerId,
  }) => Stream.value(null);

  @override
  Stream<List<CustomerAuditEntry>> watchCustomerHistory({
    required String businessId,
    required String customerId,
  }) => Stream.value(const []);

  @override
  Future<String> requestCustomerRemoval({
    required AppUser actor,
    required String customerId,
    required String reason,
  }) async => 'req-1';

  @override
  Stream<List<CustomerRemovalRequest>> watchPendingRemovalRequests({
    required String businessId,
    required String requesterId,
    required bool isHead,
  }) => Stream.value(const []);

  @override
  Future<void> reviewRemovalRequest({
    required AppUser actor,
    required String requestId,
    required bool approved,
    String? reviewNotes,
  }) async {}
}

void main() {
  group('Quick Add Customer & Save & Add Next Flow', () {
    const headUser = AppUser(
      uid: 'head-uid',
      email: 'owner@paperroute.app',
      displayName: 'Agency Owner',
      businessId: 'biz-1',
      role: UserRole.head,
      status: AccountStatus.active,
      isEmailVerified: true,
    );

    const testAreas = [
      DeliveryArea(
        id: 'area-1',
        name: 'Sector 15',
        isActive: true,
        assignedEmployeeIds: {'head-uid'},
      ),
    ];

    testWidgets(
      'Quick Add allows minimal input and Save & Add Next resets customer details while retaining area',
      (tester) async {
        _useTallSurface(tester);
        final fakeRepo = FakeCustomerRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              customerRepositoryProvider.overrideWithValue(fakeRepo),
              deliveryAreasProvider('biz-1').overrideWith(
                (ref) => Stream.value(testAreas),
              ),
              activeNewspapersListProvider((
                businessId: 'biz-1',
                requesterId: 'head-uid',
              ),).overrideWith(
                (ref) => Future.value(const <Newspaper>[]),
              ),
            ],
            child: const MaterialApp(
              home: CustomerFormPage(user: headUser, isQuickAdd: true),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify Quick Add title & banner
        expect(find.text('Quick Customer Onboarding'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('save-and-add-next-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('save-customer-button')),
          findsOneWidget,
        );

        // Enter Customer 1
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Customer name'),
          'Ramesh Sharma',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Primary phone'),
          '9876543210',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'House / Flat number'),
          'Flat 201',
        );

        // Select Delivery Area
        await tester.tap(find.byKey(const ValueKey('customer-area-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sector 15').last);
        await tester.pumpAndSettle();

        // Tap Save & Add Next
        await tester.tap(
          find.byKey(const ValueKey('save-and-add-next-button')),
        );
        await tester.pumpAndSettle();

        // Verify Customer 1 was created with fallback address and correct area
        expect(fakeRepo.createdInputs.length, 1);
        expect(fakeRepo.createdInputs.first.name, 'Ramesh Sharma');
        expect(fakeRepo.createdInputs.first.phone, '9876543210');
        expect(fakeRepo.createdInputs.first.areaId, 'area-1');
        expect(fakeRepo.createdInputs.first.address, contains('Sector 15'));

        // Verify form fields were reset for Customer 2 while keeping the page active
        expect(find.text('Ramesh Sharma'), findsNothing);
        expect(find.text('9876543210'), findsNothing);

        // Enter Customer 2 immediately without re-selecting area
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Customer name'),
          'Sunita Verma',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Primary phone'),
          '9876543211',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'House / Flat number'),
          'Flat 202',
        );

        // Tap Save Customer (Final)
        await tester.tap(find.byKey(const ValueKey('save-customer-button')));
        await tester.pumpAndSettle();

        expect(fakeRepo.createdInputs.length, 2);
        expect(fakeRepo.createdInputs[1].name, 'Sunita Verma');
        expect(fakeRepo.createdInputs[1].phone, '9876543211');
        expect(fakeRepo.createdInputs[1].areaId, 'area-1'); // Retained sticky area
      },
    );
  });
}

void _useTallSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1800);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
