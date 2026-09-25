import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/domain/newspaper_repository.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';
import 'package:paper_route/features/subscriptions/domain/subscription_repository.dart';
import 'package:paper_route/features/subscriptions/presentation/subscription_form_page.dart';
import 'package:paper_route/features/subscriptions/presentation/subscription_providers.dart';

class _FakeNewspaperRepository implements NewspaperRepository {
  _FakeNewspaperRepository(this.papers);
  final List<Newspaper> papers;

  @override
  Future<NewspaperPage> fetchNewspapers(NewspaperListRequest request) async {
    return NewspaperPage(
      newspapers: papers,
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  SubscriptionInput? lastCreatedInput;
  SubscriptionInput? lastReplacedInput;
  LocalDate? lastReplacedEffectiveFrom;

  @override
  Future<String> createSubscription({
    required AppUser actor,
    required String customerId,
    required SubscriptionInput input,
  }) async {
    lastCreatedInput = input;
    return 'SUB-NEW-123';
  }

  @override
  Future<void> replaceTerms({
    required AppUser actor,
    required String customerId,
    required String subscriptionId,
    required LocalDate effectiveFrom,
    required SubscriptionInput replacement,
  }) async {
    lastReplacedInput = replacement;
    lastReplacedEffectiveFrom = effectiveFrom;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const founderHead = AppUser(
    uid: 'head-001',
    email: 'head@test.local',
    displayName: 'Founder Head',
    isEmailVerified: true,
    businessId: 'biz-test',
    role: UserRole.head,
    status: AccountStatus.active,
    permissions: {
      PermissionKey.manageAssignedSubscriptions,
    },
  );

  const testCustomer = Customer(
    id: 'CUST-001',
    customerCode: 'CUST-001',
    businessId: 'biz-test',
    name: 'Rahul Sharma',
    phone: '9876543210',
    areaId: 'area-1',
    assignedEmployeeId: 'head-001',
    status: CustomerStatus.active,
    houseNumber: '101',
    address: 'Green Park',
    landmark: 'Near Temple',
  );

  const testPaper = Newspaper(
    id: 'NP-001',
    newspaperCode: 'NP-001',
    businessId: 'biz-test',
    name: 'The Economic Times',
    searchName: 'the economic times',
    edition: 'North India',
    language: 'English',
    defaultPricePaise: 500,
    status: NewspaperStatus.active,
    createdBy: 'head-001',
    updatedBy: 'head-001',
    lastAuditId: 'audit-001',
  );

  Widget createWidget({
    required _FakeSubscriptionRepository subRepo,
    required _FakeNewspaperRepository paperRepo,
    CustomerSubscription? subscription,
  }) {
    return ProviderScope(
      overrides: [
        subscriptionRepositoryProvider.overrideWithValue(subRepo),
        newspaperRepositoryProvider.overrideWithValue(paperRepo),
      ],
      child: MaterialApp(
        home: SubscriptionFormPage(
          user: founderHead,
          customer: testCustomer,
          subscription: subscription,
        ),
      ),
    );
  }

  group('Subscription Date Pickers UX', () {
    testWidgets(
      'new subscription pre-fills today as start date in YYYY-MM-DD format',
      (tester) async {
        final subRepo = _FakeSubscriptionRepository();
        final paperRepo = _FakeNewspaperRepository([testPaper]);

        await tester.pumpWidget(createWidget(subRepo: subRepo, paperRepo: paperRepo));
        await tester.pumpAndSettle();

        final todayStr = LocalDate.fromDateTime(DateTime.now()).toString();
        final startField = tester.widget<TextFormField>(
          find.byKey(const ValueKey('subscription-start-date-field')),
        );
        expect(startField.controller?.text, equals(todayStr));
      },
    );

    testWidgets(
      'tapping start date picker button opens Material calendar and updates start date',
      (tester) async {
        final subRepo = _FakeSubscriptionRepository();
        final paperRepo = _FakeNewspaperRepository([testPaper]);

        await tester.pumpWidget(createWidget(subRepo: subRepo, paperRepo: paperRepo));
        await tester.pumpAndSettle();

        // Tap start date picker icon
        await tester.tap(find.byKey(const ValueKey('subscription-start-date-picker-button')));
        await tester.pumpAndSettle();

        // Material DatePicker dialog is open
        expect(find.byType(DatePickerDialog), findsOneWidget);

        // Tap OK on the dialog
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(find.byType(DatePickerDialog), findsNothing);
      },
    );

    testWidgets(
      'tapping planned end picker opens calendar and selecting date sets YYYY-MM-DD, clear button clears it',
      (tester) async {
        final subRepo = _FakeSubscriptionRepository();
        final paperRepo = _FakeNewspaperRepository([testPaper]);

        await tester.pumpWidget(createWidget(subRepo: subRepo, paperRepo: paperRepo));
        await tester.pumpAndSettle();

        // Planned end initially empty
        final endFieldBefore = tester.widget<TextFormField>(
          find.byKey(const ValueKey('subscription-end-date-field')),
        );
        expect(endFieldBefore.controller?.text, isEmpty);

        // Tap planned end date picker icon
        await tester.tap(find.byKey(const ValueKey('subscription-end-date-picker-button')));
        await tester.pumpAndSettle();

        expect(find.byType(DatePickerDialog), findsOneWidget);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        final endFieldAfter = tester.widget<TextFormField>(
          find.byKey(const ValueKey('subscription-end-date-field')),
        );
        expect(endFieldAfter.controller?.text, isNotEmpty);
        expect(find.byKey(const ValueKey('clear-planned-end-date')), findsOneWidget);

        // Tap clear button
        await tester.tap(find.byKey(const ValueKey('clear-planned-end-date')));
        await tester.pumpAndSettle();

        final endFieldCleared = tester.widget<TextFormField>(
          find.byKey(const ValueKey('subscription-end-date-field')),
        );
        expect(endFieldCleared.controller?.text, isEmpty);
      },
    );

    testWidgets(
      'rejects planned end date if before start date',
      (tester) async {
        final subRepo = _FakeSubscriptionRepository();
        final paperRepo = _FakeNewspaperRepository([testPaper]);

        await tester.pumpWidget(createWidget(subRepo: subRepo, paperRepo: paperRepo));
        await tester.pumpAndSettle();

        final startController = tester.widget<TextFormField>(
          find.byKey(const ValueKey('subscription-start-date-field')),
        ).controller!;
        final endController = tester.widget<TextFormField>(
          find.byKey(const ValueKey('subscription-end-date-field')),
        ).controller!;

        // Set start date to 2026-10-15 and end date to 2026-10-10
        startController.text = '2026-10-15';
        endController.text = '2026-10-10';

        // Drag ListView to scroll down and reveal submit button
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();

        final submitButton = find.text('Create subscription');
        expect(submitButton, findsOneWidget);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(
          find.text('Subscription end date cannot be before its start date.'),
          findsOneWidget,
        );
        expect(subRepo.lastCreatedInput, isNull);
      },
    );

    testWidgets(
      'restarting an ended subscription starts a new service period with today as start date',
      (tester) async {
        final subRepo = _FakeSubscriptionRepository();
        final paperRepo = _FakeNewspaperRepository([testPaper]);

        final endedSubscription = CustomerSubscription(
          id: 'SUB-OLD-1',
          businessId: 'biz-test',
          customerId: 'CUST-001',
          newspaperId: 'NP-001',
          newspaperName: 'The Economic Times',
          currentVersionId: 'ver-1',
          currentPauseId: '',
          quantity: 1,
          status: SubscriptionStatus.ended,
          startDate: const LocalDate(2026, 1, 1),
          endDate: const LocalDate(2026, 6, 30),
          currentEffectiveFrom: const LocalDate(2026, 1, 1),
          deliveryWeekdays: DeliveryWeekday.all,
          customPricePaise: null,
          customPriceReason: '',
          createdBy: 'head-001',
          updatedBy: 'head-001',
          lastAuditId: 'audit-001',
        );

        await tester.pumpWidget(
          createWidget(
            subRepo: subRepo,
            paperRepo: paperRepo,
            subscription: endedSubscription,
          ),
        );
        await tester.pumpAndSettle();

        final todayStr = LocalDate.fromDateTime(DateTime.now()).toString();
        final startField = tester.widget<TextFormField>(
          find.byKey(const ValueKey('subscription-start-date-field')),
        );
        // Restarting subscription resets start date to today
        expect(startField.controller?.text, equals(todayStr));

        // And clears old planned end date
        final endField = tester.widget<TextFormField>(
          find.byKey(const ValueKey('subscription-end-date-field')),
        );
        expect(endField.controller?.text, isEmpty);
      },
    );
  });
}
