import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/domain/newspaper_repository.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_form_page.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_pricing_page.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';
import 'package:paper_route/features/newspapers/presentation/newspapers_page.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';
import 'package:paper_route/features/subscriptions/domain/subscription_repository.dart';
import 'package:paper_route/features/subscriptions/presentation/subscription_detail_page.dart';
import 'package:paper_route/features/subscriptions/presentation/subscription_form_page.dart';
import 'package:paper_route/features/subscriptions/presentation/subscription_providers.dart';

void main() {
  const head = AppUser(
    uid: 'head-1',
    email: 'head@example.test',
    displayName: 'Head',
    isEmailVerified: true,
    businessId: 'business-a',
    role: UserRole.head,
    status: AccountStatus.active,
  );
  const employee = AppUser(
    uid: 'employee-1',
    email: 'employee@example.test',
    displayName: 'Employee',
    isEmailVerified: true,
    businessId: 'business-a',
    role: UserRole.employee,
    status: AccountStatus.active,
    permissions: {PermissionKey.manageAssignedSubscriptions},
    areaIds: {'east'},
  );

  group('Phase 4 domain rules', () {
    test('normalizes catalog search and parses integer paise exactly', () {
      expect(
        NewspaperSearchIndex.normalizeText('  City—DAILY  '),
        'city daily',
      );
      expect(
        NewspaperSearchIndex.tokenFor(
          NewspaperSearchField.newspaperCode,
          ' n-city ',
        ),
        'N-CITY',
      );
      expect(NewspaperMoney.parseRupeesToPaise('12.5'), 1250);
      expect(NewspaperMoney.formatPaiseForInput(1250), '12.50');
      expect(
        () => NewspaperMoney.parseRupeesToPaise('12.999'),
        throwsA(isA<AppException>()),
      );
    });

    test('resolves exact date over period over immutable default', () {
      final rules = [
        _priceRule(
          id: 'period',
          kind: PriceRuleKind.period,
          start: const LocalDate(2026, 10, 1),
          end: const LocalDate(2026, 10, 31),
          pricePaise: 700,
        ),
        _priceRule(
          id: 'special',
          kind: PriceRuleKind.exactDate,
          start: const LocalDate(2026, 10, 12),
          pricePaise: 900,
        ),
      ];

      expect(
        DateSpecificPriceResolver.resolve(
          defaultPricePaise: 650,
          date: const LocalDate(2026, 9, 30),
          rules: rules,
        ).source,
        ResolvedPriceSource.defaultPrice,
      );
      expect(
        DateSpecificPriceResolver.resolve(
          defaultPricePaise: 650,
          date: const LocalDate(2026, 10, 10),
          rules: rules,
        ).pricePaise,
        700,
      );
      final special = DateSpecificPriceResolver.resolve(
        defaultPricePaise: 650,
        date: const LocalDate(2026, 10, 12),
        rules: rules,
      );
      expect(special.pricePaise, 900);
      expect(special.ruleId, 'special');
    });

    test('rejects ambiguous price history and invalid subscription input', () {
      final duplicateExactRules = [
        _priceRule(
          id: 'one',
          kind: PriceRuleKind.exactDate,
          start: const LocalDate(2026, 10, 12),
          pricePaise: 800,
        ),
        _priceRule(
          id: 'two',
          kind: PriceRuleKind.exactDate,
          start: const LocalDate(2026, 10, 12),
          pricePaise: 900,
        ),
      ];
      expect(
        () => DateSpecificPriceResolver.resolve(
          defaultPricePaise: 650,
          date: const LocalDate(2026, 10, 12),
          rules: duplicateExactRules,
        ),
        throwsA(isA<AppException>()),
      );
      expect(
        () =>
            const SubscriptionInput(
              newspaperId: 'times',
              startDate: LocalDate(2026, 10, 1),
              endDate: null,
              quantity: 0,
              deliveryWeekdays: {1, 2, 3},
              customPricePaise: null,
              customPriceReason: '',
            ).validate(),
        throwsA(isA<AppException>()),
      );
    });

    test(
      'employee subscription authority requires permission, assignment, and area',
      () {
        const policy = AccessPolicy();
        expect(
          policy.canManageSubscription(
            member: employee,
            customerBusinessId: 'business-a',
            assignedEmployeeId: 'employee-1',
            customerAreaId: 'east',
            isCustomerArchived: false,
          ),
          isTrue,
        );
        expect(
          policy.canManageSubscription(
            member: employee,
            customerBusinessId: 'business-a',
            assignedEmployeeId: 'employee-1',
            customerAreaId: 'west',
            isCustomerArchived: false,
          ),
          isFalse,
        );
        expect(policy.canSetSubscriptionPrice(employee), isFalse);
        expect(policy.canSetSubscriptionPrice(head), isTrue);
        expect(
          policy.canEndSubscription(
            member: head,
            customerBusinessId: 'business-a',
            assignedEmployeeId: '',
            customerAreaId: 'east',
            isCustomerArchived: true,
          ),
          isTrue,
        );
      },
    );
  });

  testWidgets('catalog uses cursor pagination and exposes Head creation', (
    tester,
  ) async {
    _useTallSurface(tester);
    final repository = _FakeNewspaperRepository(
      pages: [
        NewspaperPage(
          newspapers: const [_paper],
          nextCursor: const NewspaperPageCursor(
            searchName: 'daily times',
            newspaperId: 'times',
          ),
          hasMore: true,
        ),
        const NewspaperPage(
          newspapers: [_secondPaper],
          nextCursor: null,
          hasMore: false,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [newspaperRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: NewspapersPage(user: head)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily Times'), findsOneWidget);
    expect(find.text('New newspaper'), findsOneWidget);
    await tester.tap(find.text('Load more newspapers'));
    await tester.pumpAndSettle();

    expect(find.text('Morning Herald'), findsOneWidget);
    expect(repository.requests, hasLength(2));
    expect(repository.requests.last.cursor?.newspaperId, 'times');
  });

  testWidgets(
    'changing the search term resets the cursor and ignores stale results',
    (tester) async {
      _useTallSurface(tester);
      final repository = _ControlledNewspaperRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            newspaperRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: NewspapersPage(user: head)),
        ),
      );
      await tester.pump();

      expect(repository.requests, hasLength(1));
      repository.complete(
        0,
        const NewspaperPage(
          newspapers: [_alphaPaper],
          nextCursor: NewspaperPageCursor(
            searchName: 'phase 4 daily alpha',
            newspaperId: 'alpha',
          ),
          hasMore: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Alpha Edited');
      await tester.tap(find.text('Search'));
      await tester.pump();
      expect(repository.requests, hasLength(2));

      await tester.enterText(find.byType(TextField), '  Phase 4 Daily Alpha  ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(repository.requests, hasLength(3));
      expect(repository.requests.last.searchToken, 'phase 4 daily alpha');
      expect(repository.requests.last.cursor, isNull);

      repository.complete(
        2,
        const NewspaperPage(
          newspapers: [_alphaPaper],
          nextCursor: null,
          hasMore: false,
        ),
      );
      await tester.pump();
      repository.complete(
        1,
        const NewspaperPage(newspapers: [], nextCursor: null, hasMore: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('Phase 4 Daily Alpha'), findsOneWidget);
      expect(find.text('No matching newspapers'), findsNothing);
    },
  );

  testWidgets('Head newspaper form sends validated values to repository', (
    tester,
  ) async {
    final repository = _FakeNewspaperRepository();
    final router = GoRouter(
      initialLocation: '/newspapers/new',
      routes: [
        GoRoute(
          path: '/newspapers/new',
          builder: (_, _) => const NewspaperFormPage(user: head),
        ),
        GoRoute(
          path: '/newspapers',
          builder: (_, _) => const Scaffold(body: Text('Catalog returned')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [newspaperRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('newspaper-name-field')),
      ' City Chronicle ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('newspaper-default-price-field')),
      '7.50',
    );
    await tester.tap(find.text('Create newspaper'));
    await tester.pumpAndSettle();

    expect(repository.createdInput?.normalized().name, 'City Chronicle');
    expect(repository.createdInput?.defaultPricePaise, 750);
    expect(find.text('Catalog returned'), findsOneWidget);
  });

  testWidgets('Head price form creates an exact-date rule through repository', (
    tester,
  ) async {
    final repository = _FakeNewspaperRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [newspaperRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: NewspaperPricingPage(user: head, newspaperId: 'times'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Price rule'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Service date'),
      '2026-10-12',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Unit price (₹)'),
      '9.50',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Pricing reason'),
      'Sunday special edition',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add rule'));
    await tester.pumpAndSettle();

    expect(repository.createdPriceInput?.kind, PriceRuleKind.exactDate);
    expect(
      repository.createdPriceInput?.startDate,
      const LocalDate(2026, 10, 12),
    );
    expect(repository.createdPriceInput?.pricePaise, 950);
  });

  testWidgets('connected subscription form creates dated weekly terms', (
    tester,
  ) async {
    _useTallSurface(tester);
    final newspaperRepository = _FakeNewspaperRepository(
      pages: const [
        NewspaperPage(newspapers: [_paper], nextCursor: null, hasMore: false),
      ],
    );
    final subscriptionRepository = _FakeSubscriptionRepository();
    final router = GoRouter(
      initialLocation: '/form',
      routes: [
        GoRoute(
          path: '/form',
          builder:
              (_, _) =>
                  const SubscriptionFormPage(user: head, customer: _customer),
        ),
        GoRoute(
          path: '/customers/:customerId',
          builder: (_, _) => const Scaffold(body: Text('Customer returned')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          newspaperRepositoryProvider.overrideWithValue(newspaperRepository),
          subscriptionRepositoryProvider.overrideWithValue(
            subscriptionRepository,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Subscription start date'),
      '2026-10-01',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Daily quantity'),
      '2',
    );
    await tester.tap(find.text('Sun'));
    final create = find.text('Create subscription');
    await tester.scrollUntilVisible(
      create,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(subscriptionRepository.createdCustomerId, 'customer-1');
    expect(subscriptionRepository.createdInput?.newspaperId, 'times');
    expect(subscriptionRepository.createdInput?.quantity, 2);
    expect(
      subscriptionRepository.createdInput?.deliveryWeekdays,
      isNot(contains(7)),
    );
    expect(find.text('Customer returned'), findsOneWidget);
  });

  testWidgets(
    'ended restart starts blank and creates one open-ended replacement',
    (tester) async {
      _useTallSurface(tester);
      final repository = _FakeSubscriptionRepository();
      final router = _restartRouter(head);
      addTearDown(router.dispose);
      await _pumpRestartForm(tester, repository: repository, router: router);

      final plannedEnd = find.widgetWithText(
        TextFormField,
        'Planned end date (optional)',
      );
      expect(
        tester.widget<TextFormField>(plannedEnd).controller?.text,
        isEmpty,
      );
      expect(_endedSubscription.endDate, const LocalDate(2026, 9, 30));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'New terms effective date'),
        '2026-10-01',
      );
      await _submitRestart(tester);

      expect(repository.replaceCalls, 1);
      expect(repository.replacementEffectiveFrom, const LocalDate(2026, 10, 1));
      expect(
        repository.replacementInput?.startDate,
        const LocalDate(2026, 10, 1),
      );
      expect(repository.replacementInput?.endDate, isNull);
      expect(_endedSubscription.endDate, const LocalDate(2026, 9, 30));
      expect(find.text('Customer returned'), findsOneWidget);
    },
  );

  testWidgets('ended restart accepts a new valid planned end date', (
    tester,
  ) async {
    _useTallSurface(tester);
    final repository = _FakeSubscriptionRepository();
    final router = _restartRouter(head);
    addTearDown(router.dispose);
    await _pumpRestartForm(tester, repository: repository, router: router);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'New terms effective date'),
      '2026-10-01',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Planned end date (optional)'),
      '2026-10-31',
    );
    await _submitRestart(tester);

    expect(repository.replaceCalls, 1);
    expect(repository.replacementInput?.endDate, const LocalDate(2026, 10, 31));
    expect(_endedSubscription.endDate, const LocalDate(2026, 9, 30));
  });

  testWidgets('ended restart rejects a planned end before its new start', (
    tester,
  ) async {
    _useTallSurface(tester);
    final repository = _FakeSubscriptionRepository();
    final router = _restartRouter(head);
    addTearDown(router.dispose);
    await _pumpRestartForm(tester, repository: repository, router: router);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'New terms effective date'),
      '2026-10-01',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Planned end date (optional)'),
      '2026-09-30',
    );
    await _submitRestart(tester, settle: false);
    await tester.pumpAndSettle();

    expect(repository.replaceCalls, 0);
    expect(
      find.text('Subscription end date cannot be before its start date.'),
      findsOneWidget,
    );
    expect(_endedSubscription.endDate, const LocalDate(2026, 9, 30));
  });

  testWidgets(
    'employee form hides privileged price and enforces current area',
    (tester) async {
      final newspaperRepository = _FakeNewspaperRepository(
        pages: const [
          NewspaperPage(newspapers: [_paper], nextCursor: null, hasMore: false),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            newspaperRepositoryProvider.overrideWithValue(newspaperRepository),
            subscriptionRepositoryProvider.overrideWithValue(
              _FakeSubscriptionRepository(),
            ),
          ],
          child: const MaterialApp(
            home: SubscriptionFormPage(user: employee, customer: _customer),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Customer-specific price exception'), findsNothing);
      expect(find.text('Create subscription'), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            newspaperRepositoryProvider.overrideWithValue(newspaperRepository),
            subscriptionRepositoryProvider.overrideWithValue(
              _FakeSubscriptionRepository(),
            ),
          ],
          child: const MaterialApp(
            home: SubscriptionFormPage(user: employee, customer: _westCustomer),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Subscription action unavailable'), findsOneWidget);
    },
  );

  testWidgets('subscription detail connects pause and end operations', (
    tester,
  ) async {
    _useTallSurface(tester);
    final repository = _FakeSubscriptionRepository(
      versions: const [_version],
      audits: const [_audit],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: SubscriptionDetailPage(
            user: head,
            customer: _customer,
            subscription: _subscription,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Terms history'), findsOneWidget);
    expect(find.text('Subscription created'), findsOneWidget);
    await tester.tap(find.text('Add pause'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Pause starts'),
      '2026-10-10',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Pause ends (optional)'),
      '2026-10-12',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Reason'),
      'Customer travelling',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add pause'));
    await tester.pumpAndSettle();
    expect(repository.pauseStart, const LocalDate(2026, 10, 10));
    expect(repository.pauseEnd, const LocalDate(2026, 10, 12));

    await tester.tap(find.text('End subscription'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Final delivery date'),
      '2026-10-31',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    expect(repository.endedOn, const LocalDate(2026, 10, 31));
  });
}

const _paper = Newspaper(
  id: 'times',
  businessId: 'business-a',
  newspaperCode: 'times',
  name: 'Daily Times',
  searchName: 'daily times',
  edition: 'City',
  language: 'English',
  defaultPricePaise: 650,
  status: NewspaperStatus.active,
  createdBy: 'head-1',
  updatedBy: 'head-1',
  lastAuditId: 'audit-1',
);

const _secondPaper = Newspaper(
  id: 'herald',
  businessId: 'business-a',
  newspaperCode: 'herald',
  name: 'Morning Herald',
  searchName: 'morning herald',
  edition: '',
  language: 'Hindi',
  defaultPricePaise: 500,
  status: NewspaperStatus.active,
  createdBy: 'head-1',
  updatedBy: 'head-1',
  lastAuditId: 'audit-2',
);

const _alphaPaper = Newspaper(
  id: 'alpha',
  businessId: 'business-a',
  newspaperCode: 'N-ALPHA',
  name: 'Phase 4 Daily Alpha',
  searchName: 'phase 4 daily alpha',
  edition: 'Synthetic Morning',
  language: 'Test',
  defaultPricePaise: 500,
  status: NewspaperStatus.active,
  createdBy: 'head-1',
  updatedBy: 'head-1',
  lastAuditId: 'audit-alpha',
);

const _customer = Customer(
  id: 'customer-1',
  customerCode: 'C-001',
  businessId: 'business-a',
  name: 'Customer One',
  phone: '9999999999',
  areaId: 'east',
  assignedEmployeeId: 'employee-1',
  status: CustomerStatus.active,
);

const _westCustomer = Customer(
  id: 'customer-2',
  customerCode: 'C-002',
  businessId: 'business-a',
  name: 'West Customer',
  phone: '8888888888',
  areaId: 'west',
  assignedEmployeeId: 'employee-1',
  status: CustomerStatus.active,
);

const _subscription = CustomerSubscription(
  id: 'times',
  businessId: 'business-a',
  customerId: 'customer-1',
  newspaperId: 'times',
  newspaperName: 'Daily Times',
  currentVersionId: 'version-1',
  currentPauseId: '',
  status: SubscriptionStatus.active,
  startDate: LocalDate(2026, 10, 1),
  endDate: null,
  currentEffectiveFrom: LocalDate(2026, 10, 1),
  quantity: 1,
  deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
  customPricePaise: null,
  customPriceReason: '',
  createdBy: 'head-1',
  updatedBy: 'head-1',
  lastAuditId: 'audit-1',
);

const _endedSubscription = CustomerSubscription(
  id: 'times',
  businessId: 'business-a',
  customerId: 'customer-1',
  newspaperId: 'times',
  newspaperName: 'Daily Times',
  currentVersionId: 'version-2',
  currentPauseId: '',
  status: SubscriptionStatus.ended,
  startDate: LocalDate(2026, 9, 14),
  endDate: LocalDate(2026, 9, 30),
  currentEffectiveFrom: LocalDate(2026, 9, 16),
  quantity: 3,
  deliveryWeekdays: {1, 2, 3, 4, 5, 6},
  customPricePaise: 450,
  customPriceReason: 'Head-approved Phase 4 synthetic rate',
  createdBy: 'head-1',
  updatedBy: 'head-1',
  lastAuditId: 'audit-ended',
);

const _version = SubscriptionVersion(
  id: 'version-1',
  businessId: 'business-a',
  customerId: 'customer-1',
  subscriptionId: 'times',
  newspaperId: 'times',
  effectiveFrom: LocalDate(2026, 10, 1),
  effectiveTo: null,
  quantity: 1,
  deliveryWeekdays: {1, 2, 3, 4, 5, 6, 7},
  customPricePaise: null,
  customPriceReason: '',
  predecessorVersionId: '',
  successorVersionId: '',
  status: 'current',
  createdBy: 'head-1',
);

const _audit = SubscriptionAuditEntry(
  id: 'audit-1',
  action: 'subscriptionCreated',
  actorId: 'head-1',
  createdAt: null,
  changedFields: [],
);

NewspaperPriceRule _priceRule({
  required String id,
  required PriceRuleKind kind,
  required LocalDate start,
  LocalDate? end,
  required int pricePaise,
}) => NewspaperPriceRule(
  id: id,
  businessId: 'business-a',
  newspaperId: 'times',
  kind: kind,
  startDate: start,
  endDate: end,
  pricePaise: pricePaise,
  status: PriceRuleStatus.active,
  supersedesRuleId: '',
  supersededByRuleId: '',
  revision: 1,
  reason: 'Publisher notice',
  createdBy: 'head-1',
  updatedBy: 'head-1',
  lastAuditId: 'audit-$id',
);

void _useTallSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1400);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

GoRouter _restartRouter(AppUser user) => GoRouter(
  initialLocation: '/restart',
  routes: [
    GoRoute(
      path: '/restart',
      builder:
          (_, _) => SubscriptionFormPage(
            user: user,
            customer: _customer,
            subscription: _endedSubscription,
          ),
    ),
    GoRoute(
      path: '/customers/:customerId',
      builder: (_, _) => const Scaffold(body: Text('Customer returned')),
    ),
  ],
);

Future<void> _pumpRestartForm(
  WidgetTester tester, {
  required _FakeSubscriptionRepository repository,
  required GoRouter router,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        newspaperRepositoryProvider.overrideWithValue(
          _FakeNewspaperRepository(
            pages: const [
              NewspaperPage(
                newspapers: [_paper],
                nextCursor: null,
                hasMore: false,
              ),
            ],
          ),
        ),
        subscriptionRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submitRestart(WidgetTester tester, {bool settle = true}) async {
  final restart = find.byWidgetPredicate(
    (widget) => widget is FilledButton,
    description: 'restart subscription button',
    skipOffstage: false,
  );
  await tester.scrollUntilVisible(
    restart,
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(restart);
  if (settle) await tester.pumpAndSettle();
}

class _FakeNewspaperRepository extends Fake implements NewspaperRepository {
  _FakeNewspaperRepository({List<NewspaperPage> pages = const []})
    : _pages = [...pages];

  final List<NewspaperPage> _pages;
  final List<NewspaperListRequest> requests = [];
  NewspaperInput? createdInput;
  PriceRuleInput? createdPriceInput;

  @override
  Future<NewspaperPage> fetchNewspapers(NewspaperListRequest request) async {
    requests.add(request);
    if (_pages.isEmpty) {
      return const NewspaperPage(
        newspapers: [],
        nextCursor: null,
        hasMore: false,
      );
    }
    return _pages.removeAt(0);
  }

  @override
  Future<String> createNewspaper({
    required AppUser actor,
    required NewspaperInput input,
  }) async {
    createdInput = input;
    return 'N-CREATED';
  }

  @override
  Stream<Newspaper?> watchNewspaper({
    required String businessId,
    required String newspaperId,
  }) => Stream.value(_paper);

  @override
  Future<PriceRulePage> fetchPriceRules(PriceRuleListRequest request) async =>
      const PriceRulePage(rules: [], nextCursor: null, hasMore: false);

  @override
  Future<String> createPriceRule({
    required AppUser actor,
    required String newspaperId,
    required PriceRuleInput input,
  }) async {
    createdPriceInput = input;
    return 'price-created';
  }
}

class _ControlledNewspaperRepository extends Fake
    implements NewspaperRepository {
  final List<NewspaperListRequest> requests = [];
  final List<Completer<NewspaperPage>> _pending = [];

  @override
  Future<NewspaperPage> fetchNewspapers(NewspaperListRequest request) {
    requests.add(request);
    final completer = Completer<NewspaperPage>();
    _pending.add(completer);
    return completer.future;
  }

  void complete(int index, NewspaperPage page) =>
      _pending[index].complete(page);
}

class _FakeSubscriptionRepository extends Fake
    implements SubscriptionRepository {
  _FakeSubscriptionRepository({
    this.versions = const [],
    this.audits = const [],
  });

  final List<SubscriptionVersion> versions;
  final List<SubscriptionAuditEntry> audits;
  String? createdCustomerId;
  SubscriptionInput? createdInput;
  int replaceCalls = 0;
  LocalDate? replacementEffectiveFrom;
  SubscriptionInput? replacementInput;
  LocalDate? pauseStart;
  LocalDate? pauseEnd;
  LocalDate? endedOn;

  @override
  Stream<List<CustomerSubscription>> watchCustomerSubscriptions({
    required String businessId,
    required String customerId,
  }) => const Stream.empty();

  @override
  Stream<List<SubscriptionVersion>> watchVersions({
    required String businessId,
    required String customerId,
    required String subscriptionId,
  }) => Stream.value(versions);

  @override
  Stream<List<SubscriptionPause>> watchPauses({
    required String businessId,
    required String customerId,
    required String subscriptionId,
  }) => Stream.value(const []);

  @override
  Stream<List<SubscriptionAuditEntry>> watchHistory({
    required String businessId,
    required String customerId,
    required String subscriptionId,
  }) => Stream.value(audits);

  @override
  Future<String> createSubscription({
    required AppUser actor,
    required String customerId,
    required SubscriptionInput input,
  }) async {
    createdCustomerId = customerId;
    createdInput = input;
    return input.newspaperId;
  }

  @override
  Future<void> replaceTerms({
    required AppUser actor,
    required String customerId,
    required String subscriptionId,
    required LocalDate effectiveFrom,
    required SubscriptionInput replacement,
  }) async {
    replaceCalls += 1;
    replacementEffectiveFrom = effectiveFrom;
    replacementInput = replacement;
  }

  @override
  Future<void> addPause({
    required AppUser actor,
    required String customerId,
    required String subscriptionId,
    required LocalDate startDate,
    required LocalDate? endDate,
    required String reason,
  }) async {
    pauseStart = startDate;
    pauseEnd = endDate;
  }

  @override
  Future<void> endSubscription({
    required AppUser actor,
    required String customerId,
    required String subscriptionId,
    required LocalDate endDate,
  }) async {
    endedOn = endDate;
  }
}
