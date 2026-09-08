import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/features/areas/domain/area_repository.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/areas/presentation/areas_page.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/business/domain/business_profile.dart';
import 'package:paper_route/features/business/domain/business_repository.dart';
import 'package:paper_route/features/business/presentation/business_providers.dart';
import 'package:paper_route/features/business/presentation/business_settings_page.dart';
import 'package:paper_route/features/customers/domain/customer_assignment.dart';
import 'package:paper_route/features/customers/domain/customer_assignment_repository.dart';
import 'package:paper_route/features/customers/presentation/customer_assignment_providers.dart';
import 'package:paper_route/features/customers/presentation/customer_assignments_page.dart';
import 'package:paper_route/features/employees/domain/employee_invitation.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';
import 'package:paper_route/features/employees/domain/employee_repository.dart';
import 'package:paper_route/features/employees/presentation/employee_providers.dart';
import 'package:paper_route/features/employees/presentation/employees_page.dart';

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
  const headMember = EmployeeMember(
    uid: 'head-1',
    email: 'head@example.com',
    displayName: 'Head',
    phone: '',
    role: UserRole.head,
    status: AccountStatus.active,
    permissions: {},
    areaIds: {},
    notes: '',
  );
  const employee = EmployeeMember(
    uid: 'employee-1',
    email: 'employee@example.com',
    displayName: 'Employee One',
    phone: '9999999999',
    role: UserRole.employee,
    status: AccountStatus.active,
    permissions: {},
    areaIds: {'east'},
    notes: '',
  );
  const east = DeliveryArea(
    id: 'east',
    name: 'East',
    isActive: true,
    assignedEmployeeIds: {'employee-1'},
  );

  testWidgets('Head updates permitted business settings', (tester) async {
    final businessRepository = _FakeBusinessRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessRepositoryProvider.overrideWithValue(businessRepository),
        ],
        child: const MaterialApp(home: BusinessSettingsPage(user: head)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Business name'),
      'PaperRoute News',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Business phone'),
      '9876543210',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      'Market Road',
    );
    await tester.tap(find.text('Save business settings'));
    await tester.pumpAndSettle();

    expect(businessRepository.updatedName, 'PaperRoute News');
    expect(businessRepository.updatedPhone, '9876543210');
    expect(businessRepository.updatedAddress, 'Market Road');
    expect(find.text('Business settings updated.'), findsOneWidget);
  });

  testWidgets('Head creates a validated employee invitation', (tester) async {
    final employeeRepository = _FakeEmployeeRepository(
      members: const [headMember],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          employeeRepositoryProvider.overrideWithValue(employeeRepository),
          areaRepositoryProvider.overrideWithValue(_FakeAreaRepository()),
        ],
        child: const MaterialApp(home: EmployeesPage(user: head)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Invite employee'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Employee email'),
      ' Employee@Example.com ',
    );
    await tester.tap(find.text('Add customers'));
    await tester.tap(find.text('Create invitation'));
    await tester.pumpAndSettle();

    expect(employeeRepository.invitedEmail, ' Employee@Example.com ');
    expect(employeeRepository.invitedPermissions, {'addCustomers'});
    expect(find.text('Invitation created'), findsOneWidget);
    expect(find.text('invite-code'), findsOneWidget);
  });

  testWidgets('Head creates an area and updates employee coverage', (
    tester,
  ) async {
    final employeeRepository = _FakeEmployeeRepository(
      members: const [headMember, employee],
    );
    final areaRepository = _FakeAreaRepository(areas: const [east]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          employeeRepositoryProvider.overrideWithValue(employeeRepository),
          areaRepositoryProvider.overrideWithValue(areaRepository),
        ],
        child: const MaterialApp(home: AreasPage(user: head)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New area'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Area name'),
      'North',
    );
    await tester.tap(find.text('Create area').last);
    await tester.pumpAndSettle();
    expect(areaRepository.createdAreaName, 'North');

    await tester.tap(find.byTooltip('Edit area'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Area name'),
      'East Zone',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(areaRepository.updatedAreaId, 'east');
    expect(areaRepository.updatedAreaName, 'East Zone');

    await tester.tap(find.byTooltip('Assign employees'));
    await tester.pumpAndSettle();
    expect(find.text('Assign East'), findsOneWidget);
    await tester.tap(find.text('Save assignments'));
    await tester.pumpAndSettle();
    expect(areaRepository.assignmentAreaId, 'east');
    expect(areaRepository.assignedEmployeeIds, {'employee-1'});
  });

  testWidgets(
    'Head manages permitted employee details, status, and permissions',
    (tester) async {
      final employeeRepository = _FakeEmployeeRepository(
        members: const [headMember, employee],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            employeeRepositoryProvider.overrideWithValue(employeeRepository),
            areaRepositoryProvider.overrideWithValue(_FakeAreaRepository()),
          ],
          child: const MaterialApp(home: EmployeesPage(user: head)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Manage employee'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display name'),
        'Employee Updated',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Internal notes'),
        'Evening route',
      );
      final activeAccessTile = find.ancestor(
        of: find.text('Active access'),
        matching: find.byType(SwitchListTile),
      );
      await tester.ensureVisible(activeAccessTile);
      await tester.tap(activeAccessTile);

      final paymentPermissionTile = find.ancestor(
        of: find.text('Record payments'),
        matching: find.byType(CheckboxListTile),
      );
      await tester.ensureVisible(paymentPermissionTile);
      await tester.tap(paymentPermissionTile);

      final saveButton = find.text('Save changes');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(employeeRepository.updatedMemberId, 'employee-1');
      expect(employeeRepository.updatedDisplayName, 'Employee Updated');
      expect(employeeRepository.updatedNotes, 'Evening route');
      expect(employeeRepository.updatedIsActive, isFalse);
      expect(employeeRepository.updatedPermissions, {'recordPayments'});
    },
  );

  testWidgets('Head transfers an existing customer to an authorized employee', (
    tester,
  ) async {
    final customerRepository = _FakeCustomerRepository(
      customers: const [
        CustomerAssignment(
          id: 'customer-1',
          customerCode: 'C-001',
          name: 'Customer One',
          phone: '8888888888',
          areaId: '',
          assignedEmployeeId: '',
          status: 'active',
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          employeeRepositoryProvider.overrideWithValue(
            _FakeEmployeeRepository(members: const [headMember, employee]),
          ),
          areaRepositoryProvider.overrideWithValue(
            _FakeAreaRepository(areas: const [east]),
          ),
          customerAssignmentRepositoryProvider.overrideWithValue(
            customerRepository,
          ),
        ],
        child: const MaterialApp(home: CustomerAssignmentsPage(user: head)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Change assignment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unassigned').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('East').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unassigned').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Employee One').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save assignment'));
    await tester.pumpAndSettle();

    expect(customerRepository.assignedCustomerId, 'customer-1');
    expect(customerRepository.assignedAreaId, 'east');
    expect(customerRepository.assignedEmployeeId, 'employee-1');
    expect(find.text('Customer assignment updated.'), findsOneWidget);
  });

  testWidgets('customer assignments show a real-data empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          employeeRepositoryProvider.overrideWithValue(
            _FakeEmployeeRepository(members: const [headMember]),
          ),
          areaRepositoryProvider.overrideWithValue(_FakeAreaRepository()),
          customerAssignmentRepositoryProvider.overrideWithValue(
            _FakeCustomerRepository(),
          ),
        ],
        child: const MaterialApp(home: CustomerAssignmentsPage(user: head)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No customer records yet'), findsOneWidget);
    expect(
      find.textContaining('This screen reads real Firestore customers only.'),
      findsOneWidget,
    );
  });
}

class _FakeBusinessRepository implements BusinessRepository {
  String? updatedName;
  String? updatedPhone;
  String? updatedAddress;

  @override
  Stream<BusinessProfile> watchBusiness(String businessId) => Stream.value(
    const BusinessProfile(
      id: 'business-a',
      name: 'A News',
      phone: '',
      address: '',
    ),
  );

  @override
  Future<void> updateBusiness({
    required String businessId,
    required String actorId,
    required String name,
    required String phone,
    required String address,
  }) async {
    updatedName = name;
    updatedPhone = phone;
    updatedAddress = address;
  }
}

class _FakeEmployeeRepository implements EmployeeRepository {
  _FakeEmployeeRepository({this.members = const []});

  final List<EmployeeMember> members;
  String? invitedEmail;
  Set<String>? invitedPermissions;
  String? updatedMemberId;
  String? updatedDisplayName;
  String? updatedNotes;
  bool? updatedIsActive;
  Set<String>? updatedPermissions;

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
  }) async {
    invitedEmail = email;
    invitedPermissions = permissions;
    return 'invite-code';
  }

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
  }) async {
    updatedMemberId = memberId;
    updatedDisplayName = displayName;
    updatedNotes = notes;
    updatedIsActive = isActive;
    updatedPermissions = permissions;
  }
}

class _FakeAreaRepository implements AreaRepository {
  _FakeAreaRepository({this.areas = const []});

  final List<DeliveryArea> areas;
  String? createdAreaName;
  String? assignmentAreaId;
  Set<String>? assignedEmployeeIds;
  String? updatedAreaId;
  String? updatedAreaName;

  @override
  Stream<List<DeliveryArea>> watchAreas(String businessId) =>
      Stream.value(areas);

  @override
  Future<void> createArea({
    required String businessId,
    required String actorId,
    required String name,
  }) async {
    createdAreaName = name;
  }

  @override
  Future<void> setEmployeeAssignments({
    required String businessId,
    required String actorId,
    required String areaId,
    required Set<String> previousEmployeeIds,
    required Set<String> employeeIds,
  }) async {
    assignmentAreaId = areaId;
    assignedEmployeeIds = employeeIds;
  }

  @override
  Future<void> updateArea({
    required String businessId,
    required String actorId,
    required String areaId,
    required String name,
    required bool isActive,
  }) async {
    updatedAreaId = areaId;
    updatedAreaName = name;
  }
}

class _FakeCustomerRepository implements CustomerAssignmentRepository {
  _FakeCustomerRepository({this.customers = const []});

  final List<CustomerAssignment> customers;
  String? assignedCustomerId;
  String? assignedEmployeeId;
  String? assignedAreaId;

  @override
  Stream<List<CustomerAssignment>> watchCustomers(String businessId) =>
      Stream.value(customers);

  @override
  Future<void> assignCustomer({
    required String businessId,
    required String actorId,
    required String customerId,
    required String employeeId,
    required String areaId,
  }) async {
    assignedCustomerId = customerId;
    assignedEmployeeId = employeeId;
    assignedAreaId = areaId;
  }
}
