import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';

void main() {
  const policy = AccessPolicy();

  AppUser employee({
    String businessId = 'business-a',
    Set<String> permissions = const {},
  }) => AppUser(
    uid: 'employee-1',
    email: 'employee@example.com',
    displayName: 'Employee',
    isEmailVerified: true,
    businessId: businessId,
    role: UserRole.employee,
    status: AccountStatus.active,
    permissions: permissions,
  );

  const head = AppUser(
    uid: 'head-1',
    email: 'head@example.com',
    displayName: 'Head',
    isEmailVerified: true,
    businessId: 'business-a',
    role: UserRole.head,
    status: AccountStatus.active,
  );

  test('head can read every customer in their own business', () {
    expect(
      policy.canReadCustomer(
        member: head,
        customerBusinessId: 'business-a',
        assignedEmployeeId: 'somebody-else',
      ),
      isTrue,
    );
  });

  test('business isolation denies even a head from another business', () {
    expect(
      policy.canReadCustomer(
        member: head,
        customerBusinessId: 'business-b',
        assignedEmployeeId: 'head-1',
      ),
      isFalse,
    );
  });

  test('employee sees only assigned customers', () {
    expect(
      policy.canReadCustomer(
        member: employee(),
        customerBusinessId: 'business-a',
        assignedEmployeeId: 'employee-1',
      ),
      isTrue,
    );
    expect(
      policy.canReadCustomer(
        member: employee(),
        customerBusinessId: 'business-a',
        assignedEmployeeId: 'employee-2',
      ),
      isFalse,
    );
  });

  test('employee actions require explicit permissions', () {
    expect(policy.canCreateCustomer(employee()), isFalse);
    expect(
      policy.canCreateCustomer(
        employee(permissions: const {PermissionKey.addCustomers}),
      ),
      isTrue,
    );
    expect(
      policy.canRecordPayment(
        member: employee(permissions: const {PermissionKey.recordPayments}),
        customerBusinessId: 'business-a',
        assignedEmployeeId: 'employee-1',
      ),
      isTrue,
    );
  });
}
