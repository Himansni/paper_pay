import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';

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
  const employee = AppUser(
    uid: 'employee-1',
    email: 'employee@example.com',
    displayName: 'Employee',
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

  test('customer parses the complete operational profile', () {
    final createdAt = DateTime(2026, 9, 8, 9, 30);
    final customer = Customer.fromMap('C-ONE', {
      'businessId': 'business-a',
      'customerCode': 'C-ONE',
      'name': 'Ravi Kumar',
      'phone': '+91 98765 43210',
      'alternatePhone': '9988776655',
      'address': '12 Market Road',
      'areaId': 'east',
      'landmark': 'Clock Tower',
      'houseNumber': '12-A',
      'buildingInfo': 'Second floor',
      'locationNotes': 'Blue gate',
      'locationConsent': true,
      'coordinates': {'latitude': 28.6139, 'longitude': 77.2090},
      'assignedEmployeeId': 'employee-1',
      'status': 'archived',
      'deliveryPreferences': {'placement': 'handToCustomer'},
      'billingPreferences': {'cycle': 'fortnightly'},
      'subscriptionStatus': 'notConfigured',
      'openingBalancePaise': 12550,
      'notes': 'Call before delivery',
      'createdBy': 'head-1',
      'updatedBy': 'head-1',
      'createdAt': createdAt,
      'updatedAt': createdAt,
    });

    expect(customer.customerCode, 'C-ONE');
    expect(customer.isArchived, isTrue);
    expect(customer.coordinates?.latitude, 28.6139);
    expect(customer.deliveryPlacement, DeliveryPlacement.handToCustomer);
    expect(customer.billingCycle, BillingCyclePreference.fortnightly);
    expect(customer.openingBalancePaise, 12550);
    expect(customer.addressSummary, contains('Near Clock Tower'));
  });

  test('search index creates bounded native prefix tokens for every field', () {
    final tokens = CustomerSearchIndex.buildTokens(
      customerCode: 'C-ABC',
      name: 'Ravi Kumar',
      phone: '+91 98765 43210',
      alternatePhone: '9988776655',
      landmark: 'Old Clock Tower',
    );

    expect(tokens, containsAll(['name:ra', 'name:ravi', 'name:ku']));
    expect(tokens, containsAll(['phone:919', 'phone:998']));
    expect(tokens, containsAll(['landmark:ol', 'landmark:cl']));
    expect(tokens, contains('code:C-ABC'));
    expect(tokens.length, lessThanOrEqualTo(300));
  });

  test('search requests normalize field terms and preserve cursor data', () {
    const cursor = CustomerPageCursor(
      searchName: 'ravi kumar',
      customerId: 'C-ONE',
    );
    const nameRequest = CustomerListRequest(
      businessId: 'business-a',
      requesterId: 'employee-1',
      isHead: false,
      searchField: CustomerSearchField.name,
      searchTerm: ' Ravi ',
      cursor: cursor,
    );
    const codeRequest = CustomerListRequest(
      businessId: 'business-a',
      requesterId: 'head-1',
      isHead: true,
      searchField: CustomerSearchField.customerCode,
      searchTerm: 'c-abc',
    );

    expect(nameRequest.searchToken, 'name:ravi');
    expect(nameRequest.cursor?.customerId, 'C-ONE');
    expect(codeRequest.searchToken, 'C-ABC');
    expect(codeRequest.isCodeSearch, isTrue);
    expect(
      () =>
          const CustomerListRequest(
            businessId: 'business-a',
            requesterId: 'head-1',
            isHead: true,
            searchField: CustomerSearchField.phone,
            searchTerm: '98',
          ).searchToken,
      throwsA(isA<AppException>()),
    );
  });

  test('opening balance conversion uses exact integer paise', () {
    expect(CustomerMoney.parseRupeesToPaise('1,250.75'), 125075);
    expect(CustomerMoney.parseRupeesToPaise('100'), 10000);
    expect(CustomerMoney.formatPaiseForInput(125075), '1250.75');
    expect(
      () => CustomerMoney.parseRupeesToPaise('12.345'),
      throwsA(isA<AppException>()),
    );
  });

  test('customer input rejects unfit identity, area, and financial data', () {
    const base = CustomerInput(
      name: 'Ravi Kumar',
      phone: '9876543210',
      alternatePhone: '',
      address: '12 Market Road',
      areaId: 'east',
      landmark: 'Clock Tower',
      houseNumber: '12-A',
      buildingInfo: '',
      locationNotes: '',
      locationConsent: false,
      coordinates: null,
      assignedEmployeeId: 'employee-1',
      deliveryPlacement: DeliveryPlacement.doorstep,
      billingCycle: BillingCyclePreference.monthly,
      openingBalancePaise: 0,
      notes: '',
    );
    base.validate();

    expect(
      () =>
          CustomerInput(
            name: base.name,
            phone: base.phone,
            alternatePhone: base.phone,
            address: base.address,
            areaId: base.areaId,
            landmark: base.landmark,
            houseNumber: base.houseNumber,
            buildingInfo: base.buildingInfo,
            locationNotes: base.locationNotes,
            locationConsent: base.locationConsent,
            coordinates: base.coordinates,
            assignedEmployeeId: base.assignedEmployeeId,
            deliveryPlacement: base.deliveryPlacement,
            billingCycle: base.billingCycle,
            openingBalancePaise: base.openingBalancePaise,
            notes: base.notes,
          ).validate(),
      throwsA(isA<AppException>()),
    );
  });

  test(
    'customer input rejects non-finite coordinates and oversized phones',
    () {
      expect(
        () =>
            _validInput(
              locationConsent: true,
              coordinates: const CustomerCoordinates(
                latitude: double.infinity,
                longitude: 77.209,
              ),
            ).validate(),
        throwsA(isA<AppException>()),
      );
      expect(
        () => _validInput(phone: '9 (876) 543-210 extension 123').validate(),
        throwsA(isA<AppException>()),
      );
    },
  );

  test(
    'access policy combines active membership, assignment, permission, and area',
    () {
      const policy = AccessPolicy();
      expect(policy.canCreateCustomer(head), isTrue);
      expect(policy.canCreateCustomer(employee), isTrue);
      expect(policy.canUseArea(employee, 'east'), isTrue);
      expect(policy.canUseArea(employee, 'west'), isFalse);
      expect(
        policy.canEditCustomer(
          member: employee,
          customerBusinessId: 'business-a',
          assignedEmployeeId: 'employee-1',
          isArchived: false,
        ),
        isTrue,
      );
      expect(
        policy.canEditCustomer(
          member: employee,
          customerBusinessId: 'business-a',
          assignedEmployeeId: 'employee-2',
          isArchived: false,
        ),
        isFalse,
      );
      expect(policy.canSetOpeningBalance(employee), isFalse);
    },
  );
}

CustomerInput _validInput({
  String phone = '9876543210',
  bool locationConsent = false,
  CustomerCoordinates? coordinates,
}) => CustomerInput(
  name: 'Ravi Kumar',
  phone: phone,
  alternatePhone: '',
  address: '12 Market Road',
  areaId: 'east',
  landmark: 'Clock Tower',
  houseNumber: '12-A',
  buildingInfo: '',
  locationNotes: '',
  locationConsent: locationConsent,
  coordinates: coordinates,
  assignedEmployeeId: 'employee-1',
  deliveryPlacement: DeliveryPlacement.doorstep,
  billingCycle: BillingCyclePreference.monthly,
  openingBalancePaise: 0,
  notes: '',
);
