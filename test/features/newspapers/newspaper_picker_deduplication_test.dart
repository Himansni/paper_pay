import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/presentation/customer_form_page.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/domain/newspaper_repository.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';
import 'package:paper_route/features/subscriptions/presentation/subscription_form_page.dart';

class _MockNewspaperRepo implements NewspaperRepository {
  _MockNewspaperRepo(this.papers);
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

  const testCustomer = Customer(
    id: 'CUST-001',
    customerCode: 'CUST-001',
    businessId: 'biz-1',
    name: 'Test Customer',
    phone: '9876543210',
    areaId: 'area-1',
    assignedEmployeeId: 'head-001',
    status: CustomerStatus.active,
    houseNumber: '101',
    address: 'Sector 15',
  );

  const testAreas = [
    DeliveryArea(
      id: 'area-1',
      name: 'Sector 15',
      isActive: true,
      assignedEmployeeIds: {'head-001'},
    ),
  ];

  const paper1 = Newspaper(
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

  // Duplicate with same ID
  const paper1Duplicate = Newspaper(
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
    lastAuditId: 'audit-1-dup',
  );

  const veryLongNamePaper = Newspaper(
    id: 'NP-LONG',
    newspaperCode: 'NP-LONG',
    businessId: 'biz-1',
    name:
        'The International Financial And Commercial Daily Chronicle of Global Markets and Regional Business Analytics Special Collector Edition',
    searchName: 'the international financial and commercial daily chronicle',
    edition: 'Comprehensive Greater Metropolitan Extended Special Zone',
    language: 'English and Hindi Bilingual Edition',
    defaultPricePaise: 1500,
    status: NewspaperStatus.active,
    createdBy: 'head-001',
    updatedBy: 'head-001',
    lastAuditId: 'audit-long',
  );

  group('Newspaper Picker Deduplication & Long Name Formatting', () {
    test(
      'activeNewspapersListProvider deduplicates duplicate newspapers by ID',
      () async {
        final container = ProviderContainer(
          overrides: [
            newspaperRepositoryProvider.overrideWithValue(
              _MockNewspaperRepo([paper1, paper1Duplicate, veryLongNamePaper]),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          activeNewspapersListProvider((
            businessId: 'biz-1',
            requesterId: 'head-001',
          ),).future,
        );

        expect(result.length, equals(2));
        expect(result.map((p) => p.id).toList(), equals(['NP-001', 'NP-LONG']));
      },
    );

    testWidgets(
      'SubscriptionFormPage deduplicates newspapers and handles very long names without overflow',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        // Narrow mobile viewport (320px width) to test overflow resilience
        tester.view.physicalSize = const Size(320, 640);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockRepo = _MockNewspaperRepo([
          paper1,
          paper1Duplicate,
          veryLongNamePaper,
        ]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              newspaperRepositoryProvider.overrideWithValue(mockRepo),
            ],
            child: const MaterialApp(
              home: SubscriptionFormPage(
                user: headUser,
                customer: testCustomer,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // No overflow exception thrown during layout
        expect(tester.takeException(), isNull);

        // Open Dropdown
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();

        // Check deduplication in dropdown items: only 1 unique entry for NP-001
        final menuItems = tester.widgetList<DropdownMenuItem<String>>(
          find.byType(DropdownMenuItem<String>),
        );
        final values = menuItems.map((m) => m.value).where((v) => v != null && v.isNotEmpty).toSet().toList();
        expect(values, equals(['NP-001', 'NP-LONG']));
      },
    );

    testWidgets(
      'CustomerFormPage deduplicates newspapers in multi-subscription selector without overflow',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 1000);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deliveryAreasProvider('biz-1').overrideWith(
                (ref) => Stream.value(testAreas),
              ),
              activeNewspapersListProvider((
                businessId: 'biz-1',
                requesterId: 'head-001',
              ),).overrideWith(
                (ref) => Future.value([paper1, veryLongNamePaper]),
              ),
            ],
            child: const MaterialApp(
              home: CustomerFormPage(user: headUser, isQuickAdd: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Scroll down to reveal newspaper dropdown
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();

        // Open Dropdown
        expect(find.byKey(const ValueKey('initial-newspaper-dropdown-0')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('initial-newspaper-dropdown-0')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
