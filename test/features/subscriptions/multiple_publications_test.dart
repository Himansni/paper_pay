import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/domain/customer_repository.dart';
import 'package:paper_route/features/customers/presentation/customer_form_page.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';
import 'package:paper_route/features/subscriptions/domain/subscription_repository.dart';
import 'package:paper_route/features/subscriptions/presentation/subscription_detail_page.dart';
import 'package:paper_route/features/subscriptions/presentation/subscription_providers.dart';

class _FakeCustomerRepo implements CustomerRepository {
  final List<CustomerInput> createdCustomers = [];

  @override
  Future<String> createCustomer({
    required AppUser actor,
    required CustomerInput input,
  }) async {
    createdCustomers.add(input);
    return 'CUST-CREATED-${createdCustomers.length}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSubRepo implements SubscriptionRepository {
  final List<SubscriptionInput> createdSubscriptions = [];
  bool failNext = false;

  @override
  Future<String> createSubscription({
    required AppUser actor,
    required String customerId,
    required SubscriptionInput input,
  }) async {
    if (failNext) {
      throw const AppException('Failed to create subscription: network error');
    }
    createdSubscriptions.add(input);
    return 'SUB-ID-${createdSubscriptions.length}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const headUser = AppUser(
    uid: 'head-001',
    email: 'head@paperroute.test',
    displayName: 'Founder Head',
    businessId: 'biz-1',
    role: UserRole.head,
    status: AccountStatus.active,
    isEmailVerified: true,
    permissions: {
      PermissionKey.manageAssignedSubscriptions,
    },
  );

  const testAreas = [
    DeliveryArea(
      id: 'area-1',
      name: 'Sector 15',
      isActive: true,
      assignedEmployeeIds: {'head-001'},
    ),
  ];

  const paperDainik = Newspaper(
    id: 'NP-001',
    newspaperCode: 'NP-001',
    businessId: 'biz-1',
    name: 'Dainik Jagran',
    searchName: 'dainik jagran',
    edition: 'Kanpur',
    language: 'Hindi',
    defaultPricePaise: 450,
    status: NewspaperStatus.active,
    createdBy: 'head-001',
    updatedBy: 'head-001',
    lastAuditId: 'audit-1',
  );

  const paperTOI = Newspaper(
    id: 'NP-002',
    newspaperCode: 'NP-002',
    businessId: 'biz-1',
    name: 'Times of India',
    searchName: 'times of india',
    edition: 'Delhi',
    language: 'English',
    defaultPricePaise: 500,
    status: NewspaperStatus.active,
    createdBy: 'head-001',
    updatedBy: 'head-001',
    lastAuditId: 'audit-2',
  );

  const paperHindu = Newspaper(
    id: 'NP-003',
    newspaperCode: 'NP-003',
    businessId: 'biz-1',
    name: 'The Hindu',
    searchName: 'the hindu',
    edition: 'National',
    language: 'English',
    defaultPricePaise: 600,
    status: NewspaperStatus.active,
    createdBy: 'head-001',
    updatedBy: 'head-001',
    lastAuditId: 'audit-3',
  );

  final allPapers = [paperDainik, paperTOI, paperHindu];

  void useTallSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 2400);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Multiple Newspapers for One Customer Flow', () {
    testWidgets(
      'Quick Add allows adding multiple newspaper rows, increments quantity, and creates all subscriptions',
      (tester) async {
        useTallSurface(tester);
        final custRepo = _FakeCustomerRepo();
        final subRepo = _FakeSubRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              customerRepositoryProvider.overrideWithValue(custRepo),
              subscriptionRepositoryProvider.overrideWithValue(subRepo),
              deliveryAreasProvider('biz-1').overrideWith(
                (ref) => Stream.value(testAreas),
              ),
              activeNewspapersListProvider((
                businessId: 'biz-1',
                requesterId: 'head-001',
              ),).overrideWith(
                (ref) => Future.value(allPapers),
              ),
            ],
            child: const MaterialApp(
              home: CustomerFormPage(user: headUser, isQuickAdd: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Customer Details
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Customer name'),
          'Vikram Mehta',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Primary phone'),
          '9876500001',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'House / Flat number'),
          'Flat 402',
        );

        // Select Area
        await tester.tap(find.byKey(const ValueKey('customer-area-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sector 15').last);
        await tester.pumpAndSettle();

        // Select Dainik Jagran in Row 0
        expect(find.byKey(const ValueKey('initial-newspaper-dropdown-0')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('initial-newspaper-dropdown-0')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dainik Jagran (Kanpur • Hindi)').last);
        await tester.pumpAndSettle();

        // Increment quantity on Row 0 to 2
        expect(find.byKey(const ValueKey('increase-qty-0')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('increase-qty-0')));
        await tester.pumpAndSettle();
        expect(find.text('2'), findsOneWidget);

        // Tap Add another newspaper button to add Row 1
        expect(find.byKey(const ValueKey('add-another-newspaper-button')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('add-another-newspaper-button')));
        await tester.pumpAndSettle();

        // Should now have 2 rows with distinct papers
        expect(find.byKey(const ValueKey('initial-newspaper-dropdown-0')), findsOneWidget);
        expect(find.byKey(const ValueKey('initial-newspaper-dropdown-1')), findsOneWidget);

        // Submit form via Save Customer
        await tester.tap(find.byKey(const ValueKey('save-customer-button')));
        await tester.pumpAndSettle();

        // Check created customer
        expect(custRepo.createdCustomers.length, equals(1));
        expect(custRepo.createdCustomers.first.name, equals('Vikram Mehta'));

        // Check created subscriptions: 2 subscriptions created!
        expect(subRepo.createdSubscriptions.length, equals(2));
        expect(subRepo.createdSubscriptions[0].newspaperId, equals('NP-001'));
        expect(subRepo.createdSubscriptions[0].quantity, equals(2));
        expect(subRepo.createdSubscriptions[1].newspaperId, equals('NP-002'));
        expect(subRepo.createdSubscriptions[1].quantity, equals(1));
      },
    );

    testWidgets(
      'Save & Add Next retains multiple subscription rows for rapid data entry',
      (tester) async {
        useTallSurface(tester);
        final custRepo = _FakeCustomerRepo();
        final subRepo = _FakeSubRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              customerRepositoryProvider.overrideWithValue(custRepo),
              subscriptionRepositoryProvider.overrideWithValue(subRepo),
              deliveryAreasProvider('biz-1').overrideWith(
                (ref) => Stream.value(testAreas),
              ),
              activeNewspapersListProvider((
                businessId: 'biz-1',
                requesterId: 'head-001',
              ),).overrideWith(
                (ref) => Future.value(allPapers),
              ),
            ],
            child: const MaterialApp(
              home: CustomerFormPage(user: headUser, isQuickAdd: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // First Customer
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Customer name'),
          'Anil Kumar',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Primary phone'),
          '9876500002',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'House / Flat number'),
          'Flat 101',
        );

        // Select Area
        await tester.tap(find.byKey(const ValueKey('customer-area-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sector 15').last);
        await tester.pumpAndSettle();

        // Select Dainik Jagran in Row 0
        await tester.tap(find.byKey(const ValueKey('initial-newspaper-dropdown-0')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dainik Jagran (Kanpur • Hindi)').last);
        await tester.pumpAndSettle();

        // Add 2nd row
        await tester.tap(find.byKey(const ValueKey('add-another-newspaper-button')));
        await tester.pumpAndSettle();

        // Tap Save & Add Next
        await tester.tap(find.byKey(const ValueKey('save-and-add-next-button')));
        await tester.pumpAndSettle();

        expect(custRepo.createdCustomers.length, equals(1));
        expect(subRepo.createdSubscriptions.length, equals(2));

        // Rows are preserved for next customer!
        expect(find.byKey(const ValueKey('initial-newspaper-dropdown-0')), findsOneWidget);
        expect(find.byKey(const ValueKey('initial-newspaper-dropdown-1')), findsOneWidget);
        expect(find.text('Anil Kumar'), findsNothing); // Customer name reset
      },
    );

    testWidgets(
      'Displays error snackbar if subscription creation fails',
      (tester) async {
        useTallSurface(tester);
        final custRepo = _FakeCustomerRepo();
        final subRepo = _FakeSubRepo()..failNext = true;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              customerRepositoryProvider.overrideWithValue(custRepo),
              subscriptionRepositoryProvider.overrideWithValue(subRepo),
              deliveryAreasProvider('biz-1').overrideWith(
                (ref) => Stream.value(testAreas),
              ),
              activeNewspapersListProvider((
                businessId: 'biz-1',
                requesterId: 'head-001',
              ),).overrideWith(
                (ref) => Future.value(allPapers),
              ),
            ],
            child: const MaterialApp(
              home: CustomerFormPage(user: headUser, isQuickAdd: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Customer name'),
          'Pooja Gupta',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Primary phone'),
          '9876500003',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'House / Flat number'),
          'Flat 303',
        );

        await tester.tap(find.byKey(const ValueKey('customer-area-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sector 15').last);
        await tester.pumpAndSettle();

        // Select Dainik Jagran in Row 0
        await tester.tap(find.byKey(const ValueKey('initial-newspaper-dropdown-0')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dainik Jagran (Kanpur • Hindi)').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('save-customer-button')));
        await tester.pumpAndSettle();

        // SnackBar error should be visible
        expect(
          find.textContaining('could not be set up'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'CustomerSubscriptionsSection displays Add newspaper button and all active subscriptions',
      (tester) async {
        const customer = Customer(
          id: 'CUST-100',
          customerCode: 'CUST-100',
          businessId: 'biz-1',
          name: 'Rohan Sharma',
          phone: '9876543210',
          areaId: 'area-1',
          assignedEmployeeId: 'head-001',
          status: CustomerStatus.active,
          houseNumber: '101',
          address: 'Sector 15',
        );

        final sub1 = CustomerSubscription(
          id: 'SUB-1',
          businessId: 'biz-1',
          customerId: 'CUST-100',
          newspaperId: 'NP-001',
          newspaperName: 'Dainik Jagran',
          currentVersionId: 'v1',
          currentPauseId: '',
          quantity: 1,
          status: SubscriptionStatus.active,
          startDate: const LocalDate(2026, 1, 1),
          endDate: null,
          currentEffectiveFrom: const LocalDate(2026, 1, 1),
          deliveryWeekdays: DeliveryWeekday.all,
          customPricePaise: null,
          customPriceReason: '',
          createdBy: 'head-001',
          updatedBy: 'head-001',
          lastAuditId: 'audit-1',
        );

        final sub2 = CustomerSubscription(
          id: 'SUB-2',
          businessId: 'biz-1',
          customerId: 'CUST-100',
          newspaperId: 'NP-002',
          newspaperName: 'Times of India',
          currentVersionId: 'v2',
          currentPauseId: '',
          quantity: 2,
          status: SubscriptionStatus.active,
          startDate: const LocalDate(2026, 2, 1),
          endDate: null,
          currentEffectiveFrom: const LocalDate(2026, 2, 1),
          deliveryWeekdays: DeliveryWeekday.all,
          customPricePaise: null,
          customPriceReason: '',
          createdBy: 'head-001',
          updatedBy: 'head-001',
          lastAuditId: 'audit-2',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              customerSubscriptionsProvider((
                businessId: 'biz-1',
                customerId: 'CUST-100',
              ),).overrideWith(
                (ref) => Stream.value([sub1, sub2]),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CustomerSubscriptionsSection(
                  user: headUser,
                  customer: customer,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Both subscriptions rendered
        expect(find.text('Dainik Jagran'), findsOneWidget);
        expect(find.text('Times of India'), findsOneWidget);

        // Prominent Add newspaper button is visible
        expect(find.byKey(const ValueKey('add-newspaper-bottom-button')), findsOneWidget);
        expect(find.text('Add newspaper'), findsOneWidget);
      },
    );
  });
}
