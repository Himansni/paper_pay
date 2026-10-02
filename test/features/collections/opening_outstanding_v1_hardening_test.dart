import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/collections/presentation/collections_providers.dart';
import 'package:paper_route/features/collections/presentation/customer_collection_summary.dart';
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
    permissions: {
      PermissionKey.recordPayments,
      PermissionKey.allowIncreaseOutstanding,
      PermissionKey.allowDecreaseOutstanding,
    },
  );

  const assignedEmployee = AppUser(
    uid: 'emp-001',
    email: 'emp@test.local',
    displayName: 'Assigned Hawker',
    isEmailVerified: true,
    businessId: 'biz-test',
    role: UserRole.employee,
    status: AccountStatus.active,
    permissions: {
      PermissionKey.recordPayments,
    },
  );

  const testCustomerWithOpening = Customer(
    id: 'cust-100',
    customerCode: 'C-100',
    businessId: 'biz-test',
    name: 'Shri Vikram Malhotra',
    phone: '9876543210',
    areaId: 'area-1',
    assignedEmployeeId: 'emp-001',
    status: CustomerStatus.active,
    openingBalancePaise: 10000, // ₹100 opening outstanding
  );

  group('₹100 Opening Outstanding V1 Hardening & Data Integrity', () {
    test('CustomerOutstandingSummary computes unbilledOpeningPaise and collectiblePaise accurately', () {
      // Case 1: Fresh customer with ₹100 opening balance, no finalized bills
      final unbilledOpeningSummary = CustomerOutstandingSummary(
        businessId: 'biz-test',
        customerId: 'cust-100',
        outstandingPaise: 10000, // ₹100.00 total
        confirmedPaise: 0,
        reversedPaise: 0,
        bills: const [], // No finalized monthly bills yet
        revision: 1,
        serverConfirmed: true,
        requiresProjectionSetup: false,
      );

      expect(unbilledOpeningSummary.outstandingPaise, equals(10000));
      expect(unbilledOpeningSummary.collectiblePaise, equals(0));
      expect(unbilledOpeningSummary.unbilledOpeningPaise, equals(10000));

      // Case 2: Customer with ₹100 opening balance + ₹300 finalized bill
      final withBillSummary = CustomerOutstandingSummary(
        businessId: 'biz-test',
        customerId: 'cust-100',
        outstandingPaise: 40000, // ₹400.00 total
        confirmedPaise: 0,
        reversedPaise: 0,
        bills: const [
          OutstandingBill(
            billId: '2026-09',
            billingMonth: '2026-09',
            sourceAmountPaise: 30000,
            allocatedPaise: 0,
            reversedPaise: 0,
            outstandingPaise: 30000,
            status: 'outstanding',
            revision: 1,
          ),
        ],
        revision: 2,
        serverConfirmed: true,
        requiresProjectionSetup: false,
      );

      expect(withBillSummary.outstandingPaise, equals(40000));
      expect(withBillSummary.collectiblePaise, equals(30000));
      expect(withBillSummary.unbilledOpeningPaise, equals(10000));

      // Case 3: Partial payment of ₹100 against bill
      final partialPaymentSummary = CustomerOutstandingSummary(
        businessId: 'biz-test',
        customerId: 'cust-100',
        outstandingPaise: 30000,
        confirmedPaise: 10000,
        reversedPaise: 0,
        bills: const [
          OutstandingBill(
            billId: '2026-09',
            billingMonth: '2026-09',
            sourceAmountPaise: 30000,
            allocatedPaise: 10000,
            reversedPaise: 0,
            outstandingPaise: 20000,
            status: 'partially_paid',
            revision: 2,
          ),
        ],
        revision: 3,
        serverConfirmed: true,
        requiresProjectionSetup: false,
      );

      expect(partialPaymentSummary.outstandingPaise, equals(30000));
      expect(partialPaymentSummary.collectiblePaise, equals(20000));
      expect(partialPaymentSummary.unbilledOpeningPaise, equals(10000));

      // Case 4: Full payment of bill
      final fullPaymentSummary = CustomerOutstandingSummary(
        businessId: 'biz-test',
        customerId: 'cust-100',
        outstandingPaise: 10000,
        confirmedPaise: 30000,
        reversedPaise: 0,
        bills: const [
          OutstandingBill(
            billId: '2026-09',
            billingMonth: '2026-09',
            sourceAmountPaise: 30000,
            allocatedPaise: 30000,
            reversedPaise: 0,
            outstandingPaise: 0,
            status: 'paid',
            revision: 3,
          ),
        ],
        revision: 4,
        serverConfirmed: true,
        requiresProjectionSetup: false,
      );

      expect(fullPaymentSummary.outstandingPaise, equals(10000));
      expect(fullPaymentSummary.collectiblePaise, equals(0));
      expect(fullPaymentSummary.unbilledOpeningPaise, equals(10000));
    });

    testWidgets(
      'Head sees ₹100.00 outstanding with unbilled notice and disabled collect button',
      (tester) async {
        final key = (businessId: 'biz-test', customerId: 'cust-100');
        final summary = CustomerOutstandingSummary(
          businessId: 'biz-test',
          customerId: 'cust-100',
          outstandingPaise: 10000,
          confirmedPaise: 0,
          reversedPaise: 0,
          bills: const [],
          revision: 1,
          serverConfirmed: true,
          requiresProjectionSetup: false,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              customerOutstandingProvider(key).overrideWith(
                (ref) => Stream.value(summary),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CustomerCollectionSummary(
                  user: headUser,
                  customer: testCustomerWithOpening,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Total outstanding shows ₹100.00
        expect(find.text('₹100.00'), findsOneWidget);
        // Collectible breakdown shows ₹0.00 collectible
        expect(
          find.text('Collectible now: ₹0.00'),
          findsOneWidget,
        );
        // Unbilled explanation is presented
        expect(
          find.text(
            'Unbilled opening balance will become collectible after the first monthly bill is finalized.',
          ),
          findsOneWidget,
        );

        // Collect payment button is disabled because collectiblePaise is 0
        final collectBtnFinder = find.byKey(const ValueKey('open-collect-payment'));
        expect(collectBtnFinder, findsOneWidget);
        final filledButton = tester.widget<FilledButton>(collectBtnFinder);
        expect(filledButton.onPressed, isNull);
      },
    );

    testWidgets(
      'Assigned employee sees exact same ₹100.00 outstanding and collectible ₹0.00',
      (tester) async {
        final key = (businessId: 'biz-test', customerId: 'cust-100');
        final summary = CustomerOutstandingSummary(
          businessId: 'biz-test',
          customerId: 'cust-100',
          outstandingPaise: 10000,
          confirmedPaise: 0,
          reversedPaise: 0,
          bills: const [],
          revision: 1,
          serverConfirmed: true,
          requiresProjectionSetup: false,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              customerOutstandingProvider(key).overrideWith(
                (ref) => Stream.value(summary),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CustomerCollectionSummary(
                  user: assignedEmployee,
                  customer: testCustomerWithOpening,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Employee sees ₹100.00 outstanding (NOT ₹0.00!)
        expect(find.text('₹100.00'), findsOneWidget);
        expect(
          find.text('Collectible now: ₹0.00'),
          findsOneWidget,
        );

        // Collect payment button is disabled for employee as well
        final collectBtnFinder = find.byKey(const ValueKey('open-collect-payment'));
        expect(collectBtnFinder, findsOneWidget);
        final filledButton = tester.widget<FilledButton>(collectBtnFinder);
        expect(filledButton.onPressed, isNull);
      },
    );
  });
}
