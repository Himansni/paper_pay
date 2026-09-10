import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/features/areas/domain/area_repository.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/domain/customer_repository.dart';
import 'package:paper_route/features/customers/presentation/customer_detail_page.dart';
import 'package:paper_route/features/customers/presentation/customer_form_page.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:paper_route/features/customers/presentation/customers_page.dart';
import 'package:paper_route/features/employees/domain/employee_invitation.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';
import 'package:paper_route/features/employees/domain/employee_repository.dart';
import 'package:paper_route/features/employees/presentation/employee_providers.dart';

void main() {
  const head = AppUser(
    uid: 'head-1',
    email: 'head@example.com',
    displayName: 'Head',
    isEmailVerified: true,
    businessId: 'business-a',
    role: UserRole.head,
    status: AccountStatus.active,
  );
  const employeeUser = AppUser(
    uid: 'employee-1',
    email: 'employee@example.com',
    displayName: 'Employee One',
    isEmailVerified: true,
    businessId: 'business-a',
    role: UserRole.employee,
    status: AccountStatus.active,
    permissions: {
      PermissionKey.addCustomers,
      PermissionKey.editAssignedCustomers,
    },
    areaIds: {'east'},
  );
  const east = DeliveryArea(
    id: 'east',
    name: 'East',
    isActive: true,
    assignedEmployeeIds: {'employee-1'},
  );
  const west = DeliveryArea(
    id: 'west',
    name: 'West',
    isActive: true,
    assignedEmployeeIds: {},
  );
  const employeeMember = EmployeeMember(
    uid: 'employee-1',
    email: 'employee@example.com',
    displayName: 'Employee One',
    phone: '9999999999',
    role: UserRole.employee,
    status: AccountStatus.active,
    permissions: {
      PermissionKey.addCustomers,
      PermissionKey.editAssignedCustomers,
    },
    areaIds: {'east'},
    notes: '',
  );

  testWidgets('directory uses cursor pagination and server search requests', (
    tester,
  ) async {
    final repository = _FakeCustomerRepository(
      pages: [
        CustomerPage(
          customers: [_customer(id: 'C-ONE', name: 'Asha Shah')],
          nextCursor: const CustomerPageCursor(
            searchName: 'asha shah',
            customerId: 'C-ONE',
          ),
          hasMore: true,
        ),
        CustomerPage(
          customers: [_customer(id: 'C-TWO', name: 'Ravi Kumar')],
          nextCursor: null,
          hasMore: false,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerRepositoryProvider.overrideWithValue(repository),
          areaRepositoryProvider.overrideWithValue(
            _FakeAreaRepository(const [east, west]),
          ),
          employeeRepositoryProvider.overrideWithValue(
            _FakeEmployeeRepository(const [employeeMember]),
          ),
        ],
        child: const MaterialApp(home: CustomersPage(user: head)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Asha Shah'), findsOneWidget);
    expect(repository.requests.single.cursor, isNull);
    final loadMore = find.text('Load more customers');
    await tester.scrollUntilVisible(
      loadMore,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(loadMore);
    await tester.pumpAndSettle();
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(repository.requests[1].cursor?.customerId, 'C-ONE');

    await tester.drag(find.byType(ListView), const Offset(0, 1400));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search name'),
      ' Ravi ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    final request = repository.requests.last;
    expect(request.searchField, CustomerSearchField.name);
    expect(request.searchTerm, 'Ravi');
    expect(request.cursor, isNull);
  });

  testWidgets('employee directory request is assignment-scoped', (
    tester,
  ) async {
    final repository = _FakeCustomerRepository(
      pages: [
        CustomerPage(
          customers: [_customer(assignedEmployeeId: 'employee-1')],
          nextCursor: null,
          hasMore: false,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerRepositoryProvider.overrideWithValue(repository),
          areaRepositoryProvider.overrideWithValue(
            _FakeAreaRepository(const [east]),
          ),
        ],
        child: const MaterialApp(home: CustomersPage(user: employeeUser)),
      ),
    );
    await tester.pumpAndSettle();

    final request = repository.requests.single;
    expect(request.isHead, isFalse);
    expect(request.requesterId, 'employee-1');
    expect(
      find.text(
        'Only customers currently assigned to you are returned by Firestore.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Head creates a complete customer with exact opening balance', (
    tester,
  ) async {
    _useTallSurface(tester);
    final repository = _FakeCustomerRepository();
    final router = GoRouter(
      initialLocation: '/new',
      routes: [
        GoRoute(
          path: '/new',
          builder: (context, state) => const CustomerFormPage(user: head),
        ),
        GoRoute(
          path: '/customers',
          builder: (context, state) => const Scaffold(body: Text('Directory')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerRepositoryProvider.overrideWithValue(repository),
          areaRepositoryProvider.overrideWithValue(
            _FakeAreaRepository(const [east]),
          ),
          employeeRepositoryProvider.overrideWithValue(
            _FakeEmployeeRepository(const [employeeMember]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Customer name'),
      'Ravi Kumar',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Primary phone'),
      '9876543210',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full address'),
      '12 Market Road',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Recognizable landmark'),
      'Clock Tower',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    final areaDropdown = find.byKey(const ValueKey('customer-area-dropdown'));
    await tester.ensureVisible(areaDropdown);
    await tester.tap(areaDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('East').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Opening balance (₹)'),
      '125.50',
    );
    final create = find.text('Create customer');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(repository.createdActor?.uid, 'head-1');
    expect(repository.createdInput?.name, 'Ravi Kumar');
    expect(repository.createdInput?.areaId, 'east');
    expect(repository.createdInput?.openingBalancePaise, 12550);
    expect(find.text('Directory'), findsOneWidget);
  });

  testWidgets('employee form exposes only permitted areas and zero balance', (
    tester,
  ) async {
    _useTallSurface(tester);
    final repository = _FakeCustomerRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerRepositoryProvider.overrideWithValue(repository),
          areaRepositoryProvider.overrideWithValue(
            _FakeAreaRepository(const [east, west]),
          ),
        ],
        child: const MaterialApp(home: CustomerFormPage(user: employeeUser)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    final areaDropdown = find.byKey(const ValueKey('customer-area-dropdown'));
    await tester.ensureVisible(areaDropdown);
    await tester.tap(areaDropdown);
    await tester.pumpAndSettle();
    expect(find.text('East'), findsOneWidget);
    expect(find.text('West'), findsNothing);
    await tester.tap(find.text('East').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pumpAndSettle();
    expect(
      find.text('₹0.00 — employees cannot set financial opening data'),
      findsOneWidget,
    );
    expect(
      find.textContaining('This customer will be assigned to you'),
      findsOneWidget,
    );
  });

  testWidgets(
    'authorized employee edits profile while assignment and balance stay protected',
    (tester) async {
      _useTallSurface(tester);
      final repository = _FakeCustomerRepository();
      final existing = _customer(
        assignedEmployeeId: 'employee-1',
        openingBalancePaise: 12550,
      );
      final router = GoRouter(
        initialLocation: '/edit',
        routes: [
          GoRoute(
            path: '/edit',
            builder:
                (context, state) =>
                    CustomerFormPage(user: employeeUser, customer: existing),
          ),
          GoRoute(
            path: '/customers',
            builder:
                (context, state) => const Scaffold(body: Text('Directory')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerRepositoryProvider.overrideWithValue(repository),
            areaRepositoryProvider.overrideWithValue(
              _FakeAreaRepository(const [east]),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Customer name'),
        'Ravi Kumar Updated',
      );
      final save = find.text('Save customer changes');
      await tester.scrollUntilVisible(
        save,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Protected — only the Head can view or set opening balance'),
        findsOneWidget,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repository.updatedActor?.uid, 'employee-1');
      expect(repository.updatedCustomerId, 'C-ONE');
      expect(repository.updatedInput?.name, 'Ravi Kumar Updated');
      expect(repository.updatedInput?.assignedEmployeeId, 'employee-1');
      expect(repository.updatedInput?.areaId, 'east');
      expect(repository.updatedInput?.openingBalancePaise, 12550);
      expect(find.text('Directory'), findsOneWidget);
    },
  );

  testWidgets(
    'detail prioritizes house identification and shows append-only history',
    (tester) async {
      final repository = _FakeCustomerRepository(
        current: _customer(
          houseNumber: '12-A',
          buildingInfo: 'Second floor',
          locationNotes: 'Blue gate beside the pharmacy',
        ),
        history: [
          CustomerAuditEntry(
            id: 'audit-1',
            action: 'customerAssignmentUpdated',
            actorId: 'head-1',
            createdAt: DateTime(2026, 9, 8, 10),
            previousEmployeeId: '',
            employeeId: 'employee-1',
            previousAreaId: '',
            areaId: 'east',
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerRepositoryProvider.overrideWithValue(repository),
            areaRepositoryProvider.overrideWithValue(
              _FakeAreaRepository(const [east]),
            ),
            employeeRepositoryProvider.overrideWithValue(
              _FakeEmployeeRepository(const [employeeMember]),
            ),
          ],
          child: const MaterialApp(
            home: CustomerDetailPage(user: head, customerId: 'C-ONE'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Find the house'), findsOneWidget);
      expect(find.text('12-A'), findsOneWidget);
      expect(find.text('Second floor'), findsOneWidget);
      expect(find.text('LANDMARK: Clock Tower'), findsOneWidget);
      expect(find.text('Blue gate beside the pharmacy'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Assignment transferred'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Assignment transferred'), findsOneWidget);

      final archive = find.text('Archive customer');
      await tester.ensureVisible(archive);
      await tester.tap(archive);
      await tester.pumpAndSettle();
      expect(find.text('Archive customer?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await tester.pumpAndSettle();
      expect(repository.archived, isTrue);
    },
  );
}

void _useTallSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1200);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Customer _customer({
  String id = 'C-ONE',
  String name = 'Ravi Kumar',
  String assignedEmployeeId = '',
  String houseNumber = '12',
  String buildingInfo = 'Ground floor',
  String locationNotes = 'Blue gate',
  int openingBalancePaise = 0,
}) => Customer(
  id: id,
  customerCode: id,
  businessId: 'business-a',
  name: name,
  phone: '9876543210',
  alternatePhone: '',
  address: '12 Market Road',
  areaId: 'east',
  landmark: 'Clock Tower',
  houseNumber: houseNumber,
  buildingInfo: buildingInfo,
  locationNotes: locationNotes,
  assignedEmployeeId: assignedEmployeeId,
  status: CustomerStatus.active,
  openingBalancePaise: openingBalancePaise,
  createdBy: 'head-1',
  updatedBy: 'head-1',
);

class _FakeCustomerRepository implements CustomerRepository {
  _FakeCustomerRepository({
    this.pages = const [],
    this.current,
    this.history = const [],
  });

  final List<CustomerPage> pages;
  final Customer? current;
  final List<CustomerAuditEntry> history;
  final requests = <CustomerListRequest>[];
  AppUser? createdActor;
  CustomerInput? createdInput;
  AppUser? updatedActor;
  String? updatedCustomerId;
  CustomerInput? updatedInput;
  bool? archived;

  @override
  Future<CustomerPage> fetchCustomers(CustomerListRequest request) async {
    requests.add(request);
    if (pages.isEmpty) {
      return const CustomerPage(
        customers: [],
        nextCursor: null,
        hasMore: false,
      );
    }
    final index = request.cursor == null ? 0 : 1;
    return pages[index.clamp(0, pages.length - 1)];
  }

  @override
  Stream<Customer?> watchCustomer({
    required String businessId,
    required String customerId,
  }) => Stream.value(
    current ??
        (pages
            .expand((page) => page.customers)
            .where((customer) => customer.id == customerId)
            .firstOrNull),
  );

  @override
  Stream<List<CustomerAuditEntry>> watchCustomerHistory({
    required String businessId,
    required String customerId,
  }) => Stream.value(history);

  @override
  Future<String> createCustomer({
    required AppUser actor,
    required CustomerInput input,
  }) async {
    createdActor = actor;
    createdInput = input;
    return 'C-CREATED';
  }

  @override
  Future<void> updateCustomerProfile({
    required AppUser actor,
    required String customerId,
    required CustomerInput input,
  }) async {
    updatedActor = actor;
    updatedCustomerId = customerId;
    updatedInput = input;
  }

  @override
  Future<void> setCustomerArchived({
    required AppUser actor,
    required String customerId,
    required bool archived,
  }) async {
    this.archived = archived;
  }

  @override
  Future<void> assignCustomer({
    required AppUser actor,
    required String customerId,
    required String employeeId,
    required String areaId,
  }) async {}
}

class _FakeAreaRepository implements AreaRepository {
  const _FakeAreaRepository(this.areas);

  final List<DeliveryArea> areas;

  @override
  Stream<List<DeliveryArea>> watchAreas(String businessId) =>
      Stream.value(areas);

  @override
  Future<void> createArea({
    required String businessId,
    required String actorId,
    required String name,
  }) async {}

  @override
  Future<void> setEmployeeAssignments({
    required String businessId,
    required String actorId,
    required String areaId,
    required Set<String> previousEmployeeIds,
    required Set<String> employeeIds,
  }) async {}

  @override
  Future<void> updateArea({
    required String businessId,
    required String actorId,
    required String areaId,
    required String name,
    required bool isActive,
  }) async {}
}

class _FakeEmployeeRepository implements EmployeeRepository {
  const _FakeEmployeeRepository(this.members);

  final List<EmployeeMember> members;

  @override
  Stream<List<EmployeeMember>> watchMembers(String businessId) =>
      Stream.value(members);

  @override
  Stream<List<EmployeeInvitation>> watchInvitations(String businessId) =>
      Stream.value(const []);

  @override
  Future<String> createInvitation({
    required String businessId,
    required String actorId,
    required String email,
    required Set<String> permissions,
    required Set<String> areaIds,
    required DateTime expiresAt,
  }) async => 'invite';

  @override
  Future<void> revokeInvitation({
    required String businessId,
    required String actorId,
    required String invitationId,
  }) async {}

  @override
  Future<void> updateMemberAccess({
    required String businessId,
    required String actorId,
    required String memberId,
    required String displayName,
    required String phone,
    required String notes,
    required bool isActive,
    required Set<String> permissions,
  }) async {}
}

extension<T> on Iterable<T> {
  T? get firstOrNull => this.isEmpty ? null : first;
}
