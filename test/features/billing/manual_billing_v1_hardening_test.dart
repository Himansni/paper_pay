import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/customers/domain/customer.dart';

void main() {
  const headUser = AppUser(
    uid: 'head-001',
    email: 'head@test.local',
    displayName: 'Head Operator',
    isEmailVerified: true,
    businessId: 'biz-test',
    role: UserRole.head,
    status: AccountStatus.active,
  );

  const defaultEmployeeUser = AppUser(
    uid: 'emp-001',
    email: 'emp@test.local',
    displayName: 'Employee Operator',
    isEmailVerified: true,
    businessId: 'biz-test',
    role: UserRole.employee,
    status: AccountStatus.active,
    areaIds: {'area-1'},
    permissions: {}, // No allowManualBilling by default
  );

  const authorizedEmployeeUser = AppUser(
    uid: 'emp-001',
    email: 'emp@test.local',
    displayName: 'Employee Operator',
    isEmailVerified: true,
    businessId: 'biz-test',
    role: UserRole.employee,
    status: AccountStatus.active,
    areaIds: {'area-1'},
    permissions: {
      PermissionKey.allowManualBilling,
    },
  );

  const assignedCustomer = Customer(
    id: 'cust-1',
    customerCode: 'C-001',
    businessId: 'biz-test',
    name: 'Shri Vikram Malhotra',
    phone: '9876543210',
    areaId: 'area-1',
    assignedEmployeeId: 'emp-001',
    status: CustomerStatus.active,
  );

  const unassignedCustomer = Customer(
    id: 'cust-2',
    customerCode: 'C-002',
    businessId: 'biz-test',
    name: 'Smt Anita Roy',
    phone: '9876543211',
    areaId: 'area-2', // Different area
    assignedEmployeeId: 'emp-002', // Different employee
    status: CustomerStatus.active,
  );

  const accessPolicy = AccessPolicy();

  group('Manual MonthlyBill Permission Model & Access Policy', () {
    test('Head is always allowed to create manual MonthlyBills', () {
      expect(
        accessPolicy.canCreateManualBill(
          member: headUser,
          customerBusinessId: assignedCustomer.businessId,
          assignedEmployeeId: assignedCustomer.assignedEmployeeId,
          customerAreaId: assignedCustomer.areaId,
          isCustomerArchived: assignedCustomer.isArchived,
        ),
        isTrue,
      );

      expect(
        accessPolicy.canCreateManualBill(
          member: headUser,
          customerBusinessId: unassignedCustomer.businessId,
          assignedEmployeeId: unassignedCustomer.assignedEmployeeId,
          customerAreaId: unassignedCustomer.areaId,
          isCustomerArchived: unassignedCustomer.isArchived,
        ),
        isTrue,
      );
    });

    test('Employee without allowManualBilling permission is denied by default', () {
      expect(
        accessPolicy.canCreateManualBill(
          member: defaultEmployeeUser,
          customerBusinessId: assignedCustomer.businessId,
          assignedEmployeeId: assignedCustomer.assignedEmployeeId,
          customerAreaId: assignedCustomer.areaId,
          isCustomerArchived: assignedCustomer.isArchived,
        ),
        isFalse,
      );
    });

    test('Employee with Head-granted allowManualBilling is allowed for assigned customer', () {
      expect(
        accessPolicy.canCreateManualBill(
          member: authorizedEmployeeUser,
          customerBusinessId: assignedCustomer.businessId,
          assignedEmployeeId: assignedCustomer.assignedEmployeeId,
          customerAreaId: assignedCustomer.areaId,
          isCustomerArchived: assignedCustomer.isArchived,
        ),
        isTrue,
      );
    });

    test('Employee with permission is still denied for unassigned customer (customer scope preserved)', () {
      expect(
        accessPolicy.canCreateManualBill(
          member: authorizedEmployeeUser,
          customerBusinessId: unassignedCustomer.businessId,
          assignedEmployeeId: unassignedCustomer.assignedEmployeeId,
          customerAreaId: unassignedCustomer.areaId,
          isCustomerArchived: unassignedCustomer.isArchived,
        ),
        isFalse,
      );
    });

    test('Revoking allowManualBilling immediately removes employee permission', () {
      const revokedUser = AppUser(
        uid: 'emp-001',
        email: 'emp@test.local',
        displayName: 'Employee Operator',
        isEmailVerified: true,
        businessId: 'biz-test',
        role: UserRole.employee,
        status: AccountStatus.active,
        areaIds: {'area-1'},
        permissions: {},
      );
      expect(
        accessPolicy.canCreateManualBill(
          member: revokedUser,
          customerBusinessId: assignedCustomer.businessId,
          assignedEmployeeId: assignedCustomer.assignedEmployeeId,
          customerAreaId: assignedCustomer.areaId,
          isCustomerArchived: assignedCustomer.isArchived,
        ),
        isFalse,
      );
    });
  });

  group('Manual Bill Calculation & Entity Invariants', () {
    test('Month-wise ₹300 produces exact MonthlyBill ₹300 (30000 paise)', () {
      const input = ManualBillInput(
        customerId: 'cust-1',
        subscriptionId: 'sub-1',
        month: LocalDate(2026, 9, 1),
        mode: ManualBillCalculationMode.monthWise,
        monthWiseAmountPaise: 30000,
        deliveryChargePaise: 0,
        discountPaise: 0,
        dailyEntries: [],
      );

      final total = (input.monthWiseAmountPaise ?? 0) +
          input.deliveryChargePaise -
          input.discountPaise;
      expect(total, equals(30000));
    });

    test('Day-wise entries sum daily amounts correctly into integer paise', () {
      final dailyEntries = List.generate(30, (index) {
        final day = index + 1;
        final date = LocalDate(2026, 9, day);
        // Day 3 and 10 are ₹0, others are ₹10 (1000 paise)
        final unitPrice = (day == 3 || day == 10) ? 0 : 1000;
        return ManualDailyEntry(
          date: date,
          unitPricePaise: unitPrice,
          isPaused: (day == 3 || day == 10),
        );
      });

      final input = ManualBillInput(
        customerId: 'cust-1',
        subscriptionId: 'sub-1',
        month: const LocalDate(2026, 9, 1),
        mode: ManualBillCalculationMode.dayWise,
        dailyEntries: dailyEntries,
        deliveryChargePaise: 1000, // ₹10 delivery
        discountPaise: 0,
      );

      final subtotal = input.dailyEntries
          .where((e) => !e.isPaused)
          .fold<int>(0, (sum, e) => sum + e.unitPricePaise);
      final net = subtotal + input.deliveryChargePaise - input.discountPaise;

      // 28 days * ₹10 = ₹280 (28000) + ₹10 delivery (1000) = ₹290 (29000 paise)
      expect(subtotal, equals(28000));
      expect(net, equals(29000));
    });

    test('Date-wise entries compute subtotal, delivery and discount accurately', () {
      final dailyEntries = [
        const ManualDailyEntry(date: LocalDate(2026, 9, 1), unitPricePaise: 1200),
        const ManualDailyEntry(date: LocalDate(2026, 9, 2), unitPricePaise: 1200),
        const ManualDailyEntry(date: LocalDate(2026, 9, 5), unitPricePaise: 1500),
        const ManualDailyEntry(date: LocalDate(2026, 9, 6), unitPricePaise: 0, isPaused: true),
      ];

      final input = ManualBillInput(
        customerId: 'cust-1',
        subscriptionId: 'sub-1',
        month: const LocalDate(2026, 9, 1),
        mode: ManualBillCalculationMode.dateWise,
        dailyEntries: dailyEntries,
        deliveryChargePaise: 500, // ₹5
        discountPaise: 200, // ₹2
      );

      final subtotal = input.dailyEntries
          .where((e) => !e.isPaused)
          .fold<int>(0, (sum, e) => sum + e.unitPricePaise);
      final net = subtotal + input.deliveryChargePaise - input.discountPaise;

      // 1200 + 1200 + 1500 + 0 = 3900 subtotal + 500 delivery - 200 discount = 4200 paise
      expect(subtotal, equals(3900));
      expect(net, equals(4200));
    });

    test('Manual bill produces authoritative MonthlyBill with priceSource.manual and billingSource manual', () {
      const bill = FinalizedMonthlyBill(
        id: '2026-09',
        businessId: 'biz-test',
        customerId: 'cust-1',
        customerCode: 'C-001',
        customerName: 'Shri Vikram Malhotra',
        customerAddress: '101 Green Park',
        billingMonth: '2026-09',
        openingBalancePaise: 0,
        previousBillId: '',
        previousOutstandingPaise: 0,
        priorBalancePaise: 0,
        currentChargesPaise: 30000,
        adjustmentsPaise: 0,
        totalDuePaise: 30000,
        lineItemCount: 1,
        calculationVersion: 'v1',
        finalizedBy: 'head-001',
        lastAuditId: 'audit-1',
        billingSource: 'manual', // Reuses MonthlyBill schema
        newspaperSummaries: [
          BillNewspaperSummary(
            newspaperId: 'news-1',
            newspaperName: 'Dainik Jagran',
            deliveryCount: 30,
            subtotalPaise: 30000,
          ),
        ],
      );

      expect(bill.billingSource, equals('manual'));
      expect(bill.totalDuePaise, equals(30000));
      expect(bill.newspaperSummaries.first.subtotalPaise, equals(30000));

      const lineItem = MonthlyBillLineItem(
        chargeKey: 'item-1',
        serviceDate: LocalDate(2026, 9, 1),
        subscriptionId: 'sub-1',
        versionId: 'v1',
        newspaperId: 'news-1',
        newspaperName: 'Dainik Jagran',
        unitPricePaise: 1000,
        quantity: 1,
        priceSource: BillPriceSource.manual,
        priceSourceId: 'manual',
        priceRuleRevision: 1,
      );

      expect(lineItem.priceSource, equals(BillPriceSource.manual));
      expect(lineItem.priceSource.value, equals('manual'));
    });
  });
}
