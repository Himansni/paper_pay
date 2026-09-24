import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paper_route/core/config/firebase_bootstrap.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/areas/data/firebase_area_repository.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/data/firebase_billing_repository.dart';
import 'package:paper_route/features/collections/data/firebase_collections_repository.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/customers/data/firebase_customer_repository.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/newspapers/data/firebase_newspaper_repository.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/subscriptions/data/firebase_subscription_repository.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';
import 'package:paper_route/features/delivery/data/firebase_delivery_repository.dart';
import 'package:paper_route/features/delivery/domain/delivery_models.dart';

const _businessId = 'biz_founder_acceptance';
const _headEmail = 'dev-founder-head@paperroute.test';
const _headPassword = String.fromEnvironment('FOUNDER_HEAD_PASSWORD');
const _employeeEmail = 'dev-founder-emp@paperroute.test';
const _employeePassword = String.fromEnvironment('FOUNDER_EMP_PASSWORD');

void main() {
  if (_headPassword.isEmpty || _employeePassword.isEmpty) {
    throw Exception('Test credentials missing. Pass using --dart-define');
  }
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'PaperRoute V1 Real Authenticated Founder Journey against paperroutedev',
    (tester) async {
      print('=== STARTING PAPERROUTE V1 FOUNDER JOURNEY ACCEPTANCE TEST ===');

      // 0. Initialize Firebase (connected to paperroutedev)
      final startup = await FirebaseBootstrap.initialize();
      expect(startup.isReady, isTrue);
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      // 1. Head Login
      await auth.signOut();
      final headCredential = await auth.signInWithEmailAndPassword(
        email: _headEmail,
        password: _headPassword,
      );
      expect(headCredential.user, isNotNull);
      final headUid = headCredential.user!.uid;
      print('✔ Step 1: Head authenticated (UID: $headUid)');

      final head = AppUser(
        uid: headUid,
        email: _headEmail,
        displayName: 'Founder Head (Dev)',
        isEmailVerified: true,
        businessId: _businessId,
        role: UserRole.head,
        status: AccountStatus.active,
      );

      // Initialize Repositories
      final areaRepo = FirebaseAreaRepository(firestore);
      final customerRepo = FirebaseCustomerRepository(firestore);
      final newspaperRepo = FirebaseNewspaperRepository(firestore);
      final subscriptionRepo = FirebaseSubscriptionRepository(firestore);
      final billingRepo = FirebaseBillingRepository(firestore);
      final collectionsRepo = FirebaseCollectionsRepository(firestore);

      // 2. Create Area
      final areaName = 'Founder Route Area ${DateTime.now().millisecondsSinceEpoch}';
      await areaRepo.createArea(
        businessId: _businessId,
        actorId: headUid,
        name: areaName,
      );
      final areas = await areaRepo.watchAreas(_businessId).first;
      final createdArea = areas.firstWhere((a) => a.name == areaName);
      final areaId = createdArea.id;
      print('✔ Step 2: Area created: $areaName (ID: $areaId)');

      // Sign in as employee briefly to get employee UID
      await auth.signOut();
      final empCredential = await auth.signInWithEmailAndPassword(
        email: _employeeEmail,
        password: _employeePassword,
      );
      final employeeUid = empCredential.user!.uid;
      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: _headEmail,
        password: _headPassword,
      );

      // 3. Assign Employee to Area
      await areaRepo.setEmployeeAssignments(
        businessId: _businessId,
        actorId: headUid,
        areaId: areaId,
        previousEmployeeIds: {},
        employeeIds: {employeeUid},
      );
      print('✔ Step 3: Assigned Employee $employeeUid to Area $areaId');

      // 4. Add Customer
      final customerInput = CustomerInput(
        name: 'Shri Vikram Malhotra',
        phone: '9811223344',
        alternatePhone: '',
        address: 'Villa 101, Palm Avenue, Sector 54',
        areaId: areaId,
        landmark: 'Near Club House',
        houseNumber: '101',
        buildingInfo: 'Palm Avenue',
        locationNotes: 'Deliver on porch table',
        locationConsent: false,
        coordinates: null,
        assignedEmployeeId: employeeUid,
        deliveryPlacement: DeliveryPlacement.doorstep,
        billingCycle: BillingCyclePreference.monthly,
        openingBalancePaise: 0,
        notes: 'Founder acceptance test customer',
      );
      final customerCode = await customerRepo.createCustomer(
        actor: head,
        input: customerInput,
      );
      print('✔ Step 4: Customer created with Code: $customerCode');

      // 5. Configure Publication
      final newspaperInput = NewspaperInput(
        name: 'The Economic Times',
        edition: 'North India',
        language: 'English',
        defaultPricePaise: 800, // ₹8.00 weekdays
      );
      final newspaperId = await newspaperRepo.createNewspaper(
        actor: head,
        input: newspaperInput,
      );
      print('✔ Step 5: Publication created: The Economic Times (ID: $newspaperId)');

      // Create Subscription
      final subInput = SubscriptionInput(
        newspaperId: newspaperId,
        startDate: const LocalDate(2026, 9, 1),
        endDate: null,
        quantity: 1,
        deliveryWeekdays: DeliveryWeekday.all,
        customPricePaise: null,
        customPriceReason: '',
      );
      final subscriptionId = await subscriptionRepo.createSubscription(
        actor: head,
        customerId: customerCode,
        input: subInput,
      );
      print('✔ Step 5b: Subscription active (ID: $subscriptionId)');

      // 6. Generate Route & Record Delivery
      final deliveryRepo = FirebaseDeliveryRepository(firestore);
      await deliveryRepo.saveRouteOrder(
        businessId: _businessId,
        areaId: areaId,
        customerIds: [customerCode],
        actorUid: headUid,
      );
      print('✔ Step 6: Morning Route generated for area $areaId');

      // 7. Record Delivery Stop
      await deliveryRepo.recordDropStatus(
        businessId: _businessId,
        areaId: areaId,
        date: const LocalDate(2026, 9, 24),
        customerId: customerCode,
        status: DeliveryStopStatus.delivered,
        actorUid: headUid,
      );
      print('✔ Step 7: Delivery marked as completed');

      // 8. Generate Monthly Bill
      final billMonth = const LocalDate(2026, 9, 1);
      final preview = await billingRepo.previewBill(
        actor: head,
        customerId: customerCode,
        month: billMonth,
      );
      print('Preview issues: ${preview.issues.map((i) => "${i.code}: ${i.message}").toList()}');
      print('Preview line items: ${preview.lineItems.length}');
      print('Preview current charges: ${preview.currentChargesPaise}');
      print('Preview total due: ${preview.totalDuePaise}');
      print('Preview prior balance: ${preview.priorBalancePaise}');
      print('Preview previousBillId: "${preview.previousBillId}"');
      print('Preview previousOutstanding: ${preview.previousOutstandingPaise}');
      print('Preview openingBalance: ${preview.openingBalancePaise}');

      final dynamic bill;
      try {
        bill = await billingRepo.finalizeBill(
          actor: head,
          customerId: customerCode,
          month: billMonth,
        );
      } catch (e, st) {
        print('finalizeBill failed with error: $e');
        if (e is AppException) {
          print('AppException code: ${e.code}, message: ${e.message}');
        }
        print('stackTrace: $st');
        rethrow;
      }
      expect(bill.currentChargesPaise, greaterThan(0));
      expect(bill.totalDuePaise, equals(bill.currentChargesPaise));
      print('✔ Step 8: Bill finalized: Total Due ₹${bill.totalDuePaise / 100} (${bill.totalDuePaise} paise)');

      // Check Outstanding Balance
      var outstanding = await collectionsRepo.fetchCustomerOutstanding(
        actor: head,
        customerId: customerCode,
      );
      expect(outstanding.outstandingPaise, equals(bill.totalDuePaise));
      expect(outstanding.serverConfirmed, isTrue);

      // 9. Record Partial Cash Payment
      const paymentAmountPaise = 10000; // ₹100.00
      final paymentInput = PaymentConfirmationInput(
        amountPaise: paymentAmountPaise,
        method: PaymentMethod.cash,
        idempotencyKey: 'founder-smoke-cash-${DateTime.now().millisecondsSinceEpoch}',
        notes: 'Founder acceptance test cash receipt',
      );
      final paymentResult = await collectionsRepo.confirmPayment(
        actor: head,
        customerId: customerCode,
        input: paymentInput,
      );
      expect(paymentResult.payment.status, equals(ConfirmedPaymentStatus.confirmed));
      expect(paymentResult.payment.amountPaise, equals(paymentAmountPaise));
      print('✔ Step 9: Partial payment recorded: ₹100.00 (ID: ${paymentResult.payment.id})');

      // 10. Verify Ledger Invariant
      final expectedOutstandingAfterPay = bill.totalDuePaise - paymentAmountPaise;
      outstanding = await collectionsRepo.fetchCustomerOutstanding(
        actor: head,
        customerId: customerCode,
      );
      expect(outstanding.outstandingPaise, equals(expectedOutstandingAfterPay));
      print('✔ Step 10: Ledger verified: Outstanding is ₹${outstanding.outstandingPaise / 100} (Billed ₹${bill.totalDuePaise / 100} - Paid ₹100.00)');

      // 11. Head Reversal
      final reversalInput = PaymentReversalInput(
        paymentId: paymentResult.payment.id,
        amountPaise: paymentAmountPaise,
        reason: 'Payment recorded against incorrect bill during test',
        idempotencyKey: 'founder-smoke-rev-${DateTime.now().millisecondsSinceEpoch}',
      );
      final reversalResult = await collectionsRepo.reversePayment(
        actor: head,
        customerId: customerCode,
        input: reversalInput,
      );
      expect(reversalResult.reversal.amountPaise, equals(paymentAmountPaise));
      print('✔ Step 11: Head reversed payment successfully');

      // Verify Ledger rollback to full balance
      outstanding = await collectionsRepo.fetchCustomerOutstanding(
        actor: head,
        customerId: customerCode,
      );
      expect(outstanding.outstandingPaise, equals(bill.totalDuePaise));
      print('✔ Step 11b: Ledger rollback verified: Outstanding restored to ₹${outstanding.outstandingPaise / 100}');

      // 12. Verify Employee Access & Permissions Separately
      print('\n--> Step 12: Testing Employee Permissions & Security Boundaries...');
      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: _employeeEmail,
        password: _employeePassword,
      );

      final employee = AppUser(
        uid: employeeUid,
        email: _employeeEmail,
        displayName: 'Founder Employee (Dev)',
        isEmailVerified: true,
        businessId: _businessId,
        role: UserRole.employee,
        status: AccountStatus.active,
        permissions: const {'deliveries', 'collections', 'addCustomers'},
        areaIds: {areaId},
      );

      // 12a: Employee CAN read assigned customer
      final empCustomerPage = await customerRepo.fetchCustomers(
        CustomerListRequest(
          businessId: _businessId,
          requesterId: employeeUid,
          isHead: false,
          areaId: areaId,
        ),
      );
      expect(empCustomerPage.customers.any((c) => c.customerCode == customerCode), isTrue);
      print('✔ Step 12a: Employee can view assigned customer');

      // 12b: Employee CANNOT reverse payments (Head-only action)
      expect(
        () => collectionsRepo.reversePayment(
          actor: employee,
          customerId: customerCode,
          input: reversalInput,
        ),
        throwsA(isA<AppException>()),
      );
      print('✔ Step 12b: Employee reversal attempt was strictly BLOCKED');

      // 12c: Employee CANNOT finalize bills (Head-only action)
      expect(
        () => billingRepo.finalizeBill(
          actor: employee,
          customerId: customerCode,
          month: billMonth,
        ),
        throwsA(isA<AppException>()),
      );
      print('✔ Step 12c: Employee bill finalization attempt was strictly BLOCKED');

      // 13. Clean Up Test Records
      print('\n--> Step 13: Cleaning up test records in biz_founder_acceptance...');
      await auth.signOut();
      await auth.signInWithEmailAndPassword(
        email: _headEmail,
        password: _headPassword,
      );

      // Safely archive the test customer to deactivate records while preserving immutable audit trails
      await customerRepo.setCustomerArchived(
        actor: head,
        customerId: customerCode,
        archived: true,
      );
      print('✔ Step 13: Test customer $customerCode safely archived in isolated tenant biz_founder_acceptance.');
      print('\n=== ALL 13 FOUNDER ACCEPTANCE STEPS COMPLETED SUCCESSFULLY ===');
    },
  );
}
