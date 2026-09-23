import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/domain/customer_removal_request.dart';
import 'package:paper_route/features/customers/domain/customer_repository.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:paper_route/features/customers/presentation/customers_page.dart';
import 'package:paper_route/features/employees/presentation/employee_providers.dart';

class _FakeCustomerRepository implements CustomerRepository {
  final List<CustomerRemovalRequest> pendingRequests = [];
  final List<Customer> customers = [];
  bool reviewCalled = false;
  bool lastApproved = false;
  String? lastReviewedId;

  @override
  Future<CustomerPage> fetchCustomers(CustomerListRequest request) async {
    return CustomerPage(
      customers: customers,
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Stream<Customer?> watchCustomer({
    required String businessId,
    required String customerId,
  }) {
    final match = customers.where((c) => c.id == customerId).firstOrNull;
    return Stream.value(match);
  }

  @override
  Stream<List<CustomerAuditEntry>> watchCustomerHistory({
    required String businessId,
    required String customerId,
  }) {
    return Stream.value([]);
  }

  @override
  Future<String> createCustomer({
    required AppUser actor,
    required CustomerInput input,
  }) async => 'cust-1';

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
  }) async {
    final req = CustomerRemovalRequest(
      id: 'req-${pendingRequests.length + 1}',
      businessId: actor.businessId!,
      customerId: customerId,
      customerName: 'Customer $customerId',
      customerCode: 'C-$customerId',
      areaId: 'area-1',
      assignedEmployeeId: actor.uid,
      requestedBy: actor.uid,
      requestedByName: actor.displayName,
      reason: reason,
      status: RemovalRequestStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    pendingRequests.add(req);
    return req.id;
  }

  @override
  Stream<List<CustomerRemovalRequest>> watchPendingRemovalRequests({
    required String businessId,
    required String requesterId,
    required bool isHead,
  }) {
    return Stream.value(pendingRequests);
  }

  @override
  Future<void> reviewRemovalRequest({
    required AppUser actor,
    required String requestId,
    required bool approved,
    String? reviewNotes,
  }) async {
    reviewCalled = true;
    lastReviewedId = requestId;
    lastApproved = approved;
    pendingRequests.removeWhere((r) => r.id == requestId);
  }
}

void main() {
  group('Customer Removal Approval Workflow', () {
    const headUser = AppUser(
      uid: 'head-1',
      email: 'head@paperroute.test',
      displayName: 'Agency Head',
      businessId: 'biz-1',
      role: UserRole.head,
      isEmailVerified: true,
      status: AccountStatus.active,
    );

    test('CustomerRemovalRequest model serializes and deserializes correctly', () {
      final req = CustomerRemovalRequest(
        id: 'req-101',
        businessId: 'biz-1',
        customerId: 'cust-1',
        customerName: 'Rahul Verma',
        customerCode: 'C101',
        areaId: 'area-north',
        assignedEmployeeId: 'emp-1',
        requestedBy: 'emp-1',
        requestedByName: 'Delivery Boy',
        reason: 'Customer relocated to Mumbai',
        status: RemovalRequestStatus.pending,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      );

      final map = req.toMap();
      expect(map['customerId'], 'cust-1');
      expect(map['reason'], 'Customer relocated to Mumbai');
      expect(map['status'], 'pending');

      final reconstructed = CustomerRemovalRequest.fromMap(req.id, map);
      expect(reconstructed.id, 'req-101');
      expect(reconstructed.customerName, 'Rahul Verma');
      expect(reconstructed.isPending, isTrue);
    });

    testWidgets('CustomersPage renders red Pending Removal Request card positioned after active customers', (tester) async {
      _useTallSurface(tester);
      final fakeRepo = _FakeCustomerRepository();
      fakeRepo.customers.add(
        const Customer(
          id: 'cust-1',
          customerCode: 'C101',
          businessId: 'biz-1',
          name: 'Active Customer 1',
          phone: '9876543210',
          areaId: 'area-1',
          assignedEmployeeId: 'emp-1',
          status: CustomerStatus.active,
        ),
      );
      fakeRepo.pendingRequests.add(
        CustomerRemovalRequest(
          id: 'req-1',
          businessId: 'biz-1',
          customerId: 'cust-1',
          customerName: 'Active Customer 1',
          customerCode: 'C101',
          areaId: 'area-1',
          assignedEmployeeId: 'emp-1',
          requestedBy: 'emp-1',
          requestedByName: 'Delivery Staff',
          reason: 'Customer shifted to another sector',
          status: RemovalRequestStatus.pending,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerRepositoryProvider.overrideWithValue(fakeRepo),
            deliveryAreasProvider('biz-1').overrideWith(
              (ref) => Stream.value([
                const DeliveryArea(
                  id: 'area-1',
                  name: 'Main Market',
                  isActive: true,
                  assignedEmployeeIds: {},
                ),
              ]),
            ),
            employeeMembersProvider('biz-1').overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
          child: const MaterialApp(
            home: CustomersPage(user: headUser),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Active customer rendered
      expect(find.text('Active Customer 1'), findsWidgets);

      // Pending removal request red section rendered
      expect(find.text('Pending Removal Requests (1)'), findsOneWidget);
      expect(find.text('REMOVAL REQUESTED'), findsOneWidget);
      expect(find.text('Reason: Customer shifted to another sector'), findsOneWidget);

      // Head sees Approve & Archive and Reject buttons
      expect(find.text('Approve & Archive'), findsOneWidget);
      expect(find.text('Reject Request'), findsOneWidget);

      // Tap Approve & Archive
      await tester.tap(find.text('Approve & Archive'));
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Approve Customer Removal & Archive?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Approve & Archive'));
      await tester.pumpAndSettle();

      expect(fakeRepo.reviewCalled, isTrue);
      expect(fakeRepo.lastReviewedId, 'req-1');
      expect(fakeRepo.lastApproved, isTrue);
    });
  });
}

void _useTallSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1400);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

