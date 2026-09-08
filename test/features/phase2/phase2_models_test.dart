import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/business/domain/business_profile.dart';
import 'package:paper_route/features/customers/domain/customer_assignment.dart';
import 'package:paper_route/features/employees/domain/employee_invitation.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';

void main() {
  test(
    'employee member parses authoritative permissions and area assignments',
    () {
      final member = EmployeeMember.fromMap('employee-1', {
        'email': 'employee@example.com',
        'displayName': 'Employee One',
        'phone': '9999999999',
        'role': 'employee',
        'status': 'active',
        'permissions': ['addCustomers', 'recordPayments'],
        'areaIds': ['east', 'west'],
        'notes': 'Morning route',
      });

      expect(member.uid, 'employee-1');
      expect(member.role, UserRole.employee);
      expect(member.isActive, isTrue);
      expect(member.permissions, {'addCustomers', 'recordPayments'});
      expect(member.areaIds, {'east', 'west'});
    },
  );

  test('unknown member role is never treated as an employee or Head', () {
    final member = EmployeeMember.fromMap('unknown', {
      'role': 'administrator',
      'status': 'active',
      'permissions': <String>[],
      'areaIds': <String>[],
    });

    expect(member.role, isNull);
    expect(member.isHead, isFalse);
    expect(member.isEmployee, isFalse);
  });

  test('invitation retains empty permissions and areas as empty sets', () {
    final data = <String, Object?>{
      'email': 'invited@example.com',
      'status': 'pending',
      'permissions': <String>[],
      'areaIds': <String>[],
    };
    final expiry = DateTime.now().add(const Duration(days: 1));
    final invitation = EmployeeInvitation.fromMap(
      'invite-1',
      data,
      expiresAt: expiry,
    );

    expect(invitation.isPending, isTrue);
    expect(invitation.permissions, isEmpty);
    expect(invitation.areaIds, isEmpty);
    expect(invitation.isExpired, isFalse);
  });

  test('area and customer assignment projections preserve live IDs', () {
    final area = DeliveryArea.fromMap('east', {
      'name': 'East',
      'status': 'active',
      'assignedEmployeeIds': ['employee-1'],
    });
    final customer = CustomerAssignment.fromMap('customer-1', {
      'customerCode': 'C-001',
      'name': 'Customer One',
      'phone': '8888888888',
      'areaId': 'east',
      'assignedEmployeeId': 'employee-1',
      'status': 'active',
    });

    expect(area.assignedEmployeeIds, {'employee-1'});
    expect(customer.customerCode, 'C-001');
    expect(customer.areaId, area.id);
    expect(customer.assignedEmployeeId, 'employee-1');
  });

  test('business profile parses only editable presentation fields', () {
    final business = BusinessProfile.fromMap('business-a', {
      'name': 'A News',
      'phone': '9999999999',
      'address': 'Main Road',
      'ownerId': 'head-1',
    });

    expect(business.id, 'business-a');
    expect(business.name, 'A News');
    expect(business.phone, '9999999999');
    expect(business.address, 'Main Road');
  });
}
