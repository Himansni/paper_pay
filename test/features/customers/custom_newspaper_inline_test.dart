import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/domain/customer_removal_request.dart';
import 'package:paper_route/features/customers/domain/customer_repository.dart';
import 'package:paper_route/features/customers/presentation/customer_form_page.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:paper_route/features/employees/domain/employee_member.dart';
import 'package:paper_route/features/employees/presentation/employee_providers.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/domain/newspaper_repository.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';

void main() {
  const headUser = AppUser(
    uid: 'head-uid',
    email: 'owner@paperroute.app',
    displayName: 'Agency Owner',
    businessId: 'biz-1',
    role: UserRole.head,
    status: AccountStatus.active,
    isEmailVerified: true,
  );

  const employeeUser = AppUser(
    uid: 'emp-uid',
    email: 'staff@paperroute.app',
    displayName: 'Delivery Staff',
    businessId: 'biz-1',
    role: UserRole.employee,
    status: AccountStatus.active,
    isEmailVerified: true,
  );

  const testAreas = [
    DeliveryArea(
      id: 'area-1',
      name: 'Sector 15',
      isActive: true,
      assignedEmployeeIds: {'head-uid', 'emp-uid'},
    ),
  ];

  testWidgets(
    'Head sees "+ Add custom newspaper" when catalog is empty, creates publication inline and selects it',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 1600);
      addTearDown(tester.view.reset);

      final fakeCustomerRepo = _FakeCustomerRepository();
      final fakeNewspaperRepo = _FakeNewspaperRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerRepositoryProvider.overrideWithValue(fakeCustomerRepo),
            newspaperRepositoryProvider.overrideWithValue(fakeNewspaperRepo),
            deliveryAreasProvider('biz-1').overrideWith(
              (ref) => Stream.value(testAreas),
            ),
            employeeMembersProvider('biz-1').overrideWith(
              (ref) => Stream.value(const <EmployeeMember>[]),
            ),
          ],
          child: const MaterialApp(
            home: CustomerFormPage(user: headUser),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Catalog is empty, but Head sees "Newspaper Subscriptions" and "+ Add custom newspaper"
      expect(find.text('Newspaper Subscriptions'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('add-custom-newspaper-btn')),
        findsOneWidget,
      );

      // Tap button to open dialog
      await tester.ensureVisible(
        find.byKey(const ValueKey('add-custom-newspaper-btn')),
      );
      await tester.tap(find.byKey(const ValueKey('add-custom-newspaper-btn')));
      await tester.pumpAndSettle();

      expect(find.text('Add custom newspaper'), findsWidgets);

      // Fill in details
      await tester.enterText(
        find.byKey(const ValueKey('custom-newspaper-name')),
        'Dainik Bhaskar',
      );
      await tester.enterText(
        find.byKey(const ValueKey('custom-newspaper-edition')),
        'Raipur',
      );
      await tester.enterText(
        find.byKey(const ValueKey('custom-newspaper-language')),
        'Hindi',
      );
      await tester.enterText(
        find.byKey(const ValueKey('custom-newspaper-price')),
        '5.50',
      );

      // Submit
      await tester.tap(find.byKey(const ValueKey('custom-newspaper-submit')));
      await tester.pumpAndSettle();

      // Check creation in repo
      expect(fakeNewspaperRepo.createdInputs, hasLength(1));
      final input = fakeNewspaperRepo.createdInputs.single;
      expect(input.name, 'Dainik Bhaskar');
      expect(input.edition, 'Raipur');
      expect(input.language, 'Hindi');
      expect(input.defaultPricePaise, 550);

      // Verify SnackBar and draft auto-selection
      expect(find.text('Created publication "Dainik Bhaskar"'), findsOneWidget);
      expect(find.text('Dainik Bhaskar (Raipur • Hindi)'), findsWidgets);
    },
  );

  testWidgets(
    'Employee does not see "+ Add custom newspaper" button',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 1600);
      addTearDown(tester.view.reset);

      final fakeCustomerRepo = _FakeCustomerRepository();
      final fakeNewspaperRepo = _FakeNewspaperRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerRepositoryProvider.overrideWithValue(fakeCustomerRepo),
            newspaperRepositoryProvider.overrideWithValue(fakeNewspaperRepo),
            deliveryAreasProvider('biz-1').overrideWith(
              (ref) => Stream.value(testAreas),
            ),
            employeeMembersProvider('biz-1').overrideWith(
              (ref) => Stream.value(const <EmployeeMember>[]),
            ),
          ],
          child: const MaterialApp(
            home: CustomerFormPage(user: employeeUser),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Employee cannot see add-custom-newspaper-btn
      expect(
        find.byKey(const ValueKey('add-custom-newspaper-btn')),
        findsNothing,
      );
    },
  );
}

class _FakeNewspaperRepository implements NewspaperRepository {
  final List<NewspaperInput> createdInputs = [];
  final List<Newspaper> catalog = [];

  @override
  Future<String> createNewspaper({
    required AppUser actor,
    required NewspaperInput input,
  }) async {
    createdInputs.add(input);
    final id = 'news-${createdInputs.length}';
    final paper = Newspaper(
      id: id,
      businessId: actor.businessId!,
      newspaperCode: 'NP-$id',
      name: input.name,
      searchName: input.name.toLowerCase(),
      edition: input.edition,
      language: input.language,
      defaultPricePaise: input.defaultPricePaise,
      status: NewspaperStatus.active,
      createdBy: actor.uid,
      updatedBy: actor.uid,
      createdAt: DateTime.now(),
      lastAuditId: 'audit-$id',
    );
    catalog.add(paper);
    return id;
  }

  @override
  Future<NewspaperPage> fetchNewspapers(NewspaperListRequest request) async {
    return NewspaperPage(
      newspapers: List.unmodifiable(catalog),
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Stream<Newspaper?> watchNewspaper({
    required String businessId,
    required String newspaperId,
  }) {
    final matches = catalog.where((n) => n.id == newspaperId);
    return Stream.value(matches.isEmpty ? null : matches.first);
  }

  @override
  Stream<List<NewspaperAuditEntry>> watchNewspaperHistory({
    required String businessId,
    required String newspaperId,
  }) => Stream.value(const []);

  @override
  Future<void> updateNewspaperProfile({
    required AppUser actor,
    required String newspaperId,
    required NewspaperProfileInput input,
  }) async {}

  @override
  Future<void> setNewspaperArchived({
    required AppUser actor,
    required String newspaperId,
    required bool archived,
  }) async {}

  @override
  Future<PriceRulePage> fetchPriceRules(PriceRuleListRequest request) async =>
      const PriceRulePage(rules: [], nextCursor: null, hasMore: false);

  @override
  Future<String> createPriceRule({
    required AppUser actor,
    required String newspaperId,
    required PriceRuleInput input,
  }) async => 'rule-1';

  @override
  Future<String> correctPriceRule({
    required AppUser actor,
    required String newspaperId,
    required String replacedRuleId,
    required PriceRuleInput replacement,
  }) async => 'rule-1';

  @override
  Future<ResolvedNewspaperPrice> resolvePriceOn({
    required String businessId,
    required String newspaperId,
    required LocalDate date,
  }) async =>
      const ResolvedNewspaperPrice(
        pricePaise: 500,
        source: ResolvedPriceSource.defaultPrice,
      );

  @override
  Future<BulkDailyPriceUpdateResult> updateDailyPrices({
    required AppUser actor,
    required LocalDate date,
    required List<DailyPriceUpdateItem> updates,
  }) async =>
      BulkDailyPriceUpdateResult(
        updatedCount: updates.length,
        updatedNewspaperIds: updates.map((u) => u.newspaperId).toList(),
      );
}

class _FakeCustomerRepository implements CustomerRepository {
  @override
  Future<String> createCustomer({
    required AppUser actor,
    required CustomerInput input,
  }) async => 'C-TEST-1';

  @override
  Future<CustomerPage> fetchCustomers(CustomerListRequest request) async =>
      const CustomerPage(customers: [], nextCursor: null, hasMore: false);

  @override
  Future<void> updateCustomerProfile({
    required AppUser actor,
    required String customerId,
    required CustomerInput input,
  }) async {}

  @override
  Future<void> setCustomerArchived({
    required AppUser actor,
    required String customerId,
    required bool archived,
  }) async {}

  @override
  Future<void> assignCustomer({
    required AppUser actor,
    required String customerId,
    required String employeeId,
    required String areaId,
  }) async {}

  @override
  Stream<Customer?> watchCustomer({
    required String businessId,
    required String customerId,
  }) => Stream.value(null);

  @override
  Stream<List<CustomerAuditEntry>> watchCustomerHistory({
    required String businessId,
    required String customerId,
  }) => Stream.value(const []);

  @override
  Future<String> requestCustomerRemoval({
    required AppUser actor,
    required String customerId,
    required String reason,
  }) async => 'req-1';

  @override
  Stream<List<CustomerRemovalRequest>> watchPendingRemovalRequests({
    required String businessId,
    required String requesterId,
    required bool isHead,
  }) => Stream.value(const []);

  @override
  Future<void> reviewRemovalRequest({
    required AppUser actor,
    required String requestId,
    required bool approved,
    String? reviewNotes,
  }) async {}
}
