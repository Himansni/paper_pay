import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/domain/customer_removal_request.dart';
import 'package:paper_route/features/customers/domain/customer_repository.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:paper_route/features/delivery/data/firebase_delivery_repository.dart';
import 'package:paper_route/features/delivery/presentation/arrange_route_page.dart';
import 'package:paper_route/features/delivery/presentation/delivery_providers.dart';
import 'package:paper_route/l10n/app_localizations.dart';

class _FakeCustomerRepository implements CustomerRepository {
  _FakeCustomerRepository(this.customers);
  final List<Customer> customers;

  @override
  Future<CustomerPage> fetchCustomers(CustomerListRequest request) async {
    return CustomerPage(
      customers: customers
          .where((c) => request.areaId.isEmpty || c.areaId == request.areaId)
          .toList(),
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Stream<Customer?> watchCustomer({
    required String businessId,
    required String customerId,
  }) =>
      Stream.value(customers.firstWhere((c) => c.id == customerId));

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
      'new-id';

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
  const testHeadUser = AppUser(
    uid: 'head-1',
    email: 'head@paperroute.test',
    displayName: 'Head Distributor',
    businessId: 'biz-1',
    role: UserRole.head,
    status: AccountStatus.active,
    isEmailVerified: true,
  );

  const testEmployeeWithoutPerm = AppUser(
    uid: 'emp-1',
    email: 'emp@paperroute.test',
    displayName: 'Employee Without Perm',
    businessId: 'biz-1',
    role: UserRole.employee,
    status: AccountStatus.active,
    isEmailVerified: true,
    areaIds: {'area-north'},
    permissions: {},
  );

  const testEmployeeWithPerm = AppUser(
    uid: 'emp-2',
    email: 'emp2@paperroute.test',
    displayName: 'Employee With Perm',
    businessId: 'biz-1',
    role: UserRole.employee,
    status: AccountStatus.active,
    isEmailVerified: true,
    areaIds: {'area-north'},
    permissions: {PermissionKey.arrangeDeliveryRoutes},
  );

  final mockCustomers = [
    Customer(
      id: 'cust-1',
      businessId: 'biz-1',
      name: 'Ramesh Sharma',
      phone: '9876543210',
      address: 'Flat 101, Sunshine Heights',
      houseNumber: '101',
      buildingInfo: 'Sunshine Heights',
      landmark: 'Near Water Tank',
      areaId: 'area-north',
      deliveryPlacement: DeliveryPlacement.doorstep,
      billingCycle: BillingCyclePreference.monthly,
      status: CustomerStatus.active,
      assignedEmployeeId: 'emp-2',
      customerCode: 'C001',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Customer(
      id: 'cust-2',
      businessId: 'biz-1',
      name: 'Priya Verma',
      phone: '9876543211',
      address: 'House 42, Sector 14',
      houseNumber: '42',
      buildingInfo: '',
      landmark: 'Opposite Park',
      areaId: 'area-north',
      deliveryPlacement: DeliveryPlacement.doorstep,
      billingCycle: BillingCyclePreference.monthly,
      status: CustomerStatus.active,
      assignedEmployeeId: 'emp-2',
      customerCode: 'C002',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  group('ArrangeRoutePage Widget Tests', () {
    testWidgets('renders numbered customer list with drag handles and disabled Save button', (tester) async {
      final repo = InMemoryDeliveryRepository();
      final customerRepo = _FakeCustomerRepository(mockCustomers);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryRepositoryProvider.overrideWithValue(repo),
            customerRepositoryProvider.overrideWithValue(customerRepo),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArrangeRoutePage(
              user: testHeadUser,
              areaId: 'area-north',
              areaName: 'North Area',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Arrange Delivery Route'), findsOneWidget);
      expect(find.text('North Area'), findsOneWidget);

      // Verify Customers are rendered with sequence numbers
      expect(find.text('Ramesh Sharma'), findsOneWidget);
      expect(find.text('Priya Verma'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Verify Drag handles exist
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));

      // Save button is initially present and disabled because not dirty
      final saveButtonFinder = find.widgetWithText(FilledButton, 'Save');
      expect(saveButtonFinder, findsOneWidget);
      final FilledButton saveButton = tester.widget(saveButtonFinder);
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('denies route arrangement when employee lacks arrangeDeliveryRoutes permission', (tester) async {
      final repo = InMemoryDeliveryRepository();
      final customerRepo = _FakeCustomerRepository(mockCustomers);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryRepositoryProvider.overrideWithValue(repo),
            customerRepositoryProvider.overrideWithValue(customerRepo),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArrangeRoutePage(
              user: testEmployeeWithoutPerm,
              areaId: 'area-north',
              areaName: 'North Area',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify permission denial card is displayed
      expect(
        find.text('You do not have permission to rearrange route stops for this area.'),
        findsOneWidget,
      );
      // No drag list displayed
      expect(find.byIcon(Icons.drag_handle), findsNothing);
    });

    testWidgets('allows route arrangement when employee has arrangeDeliveryRoutes permission for assigned area', (tester) async {
      final repo = InMemoryDeliveryRepository();
      final customerRepo = _FakeCustomerRepository(mockCustomers);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryRepositoryProvider.overrideWithValue(repo),
            customerRepositoryProvider.overrideWithValue(customerRepo),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArrangeRoutePage(
              user: testEmployeeWithPerm,
              areaId: 'area-north',
              areaName: 'North Area',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Ramesh Sharma'), findsOneWidget);
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
    });

    testWidgets('reordering customers enables Save button and saving persists order', (tester) async {
      final repo = InMemoryDeliveryRepository();
      final customerRepo = _FakeCustomerRepository(mockCustomers);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryRepositoryProvider.overrideWithValue(repo),
            customerRepositoryProvider.overrideWithValue(customerRepo),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArrangeRoutePage(
              user: testHeadUser,
              areaId: 'area-north',
              areaName: 'North Area',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Trigger reorder programmatically via ReorderableListView callback
      final reorderableListView = tester.widget<ReorderableListView>(find.byType(ReorderableListView));
      reorderableListView.onReorder(0, 2);
      await tester.pumpAndSettle();

      // Save button should now be enabled
      final saveButtonFinder = find.widgetWithText(FilledButton, 'Save');
      FilledButton saveButton = tester.widget(saveButtonFinder);
      expect(saveButton.onPressed, isNotNull);

      // Tap Save
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      // Verify repo received the updated customer IDs order ['cust-2', 'cust-1']
      final order = await repo.getRouteOrder(businessId: 'biz-1', areaId: 'area-north');
      expect(order, isNotNull);
      expect(order!.customerIds, ['cust-2', 'cust-1']);
      expect(order.updatedBy, 'head-1');
    });
  });
}
