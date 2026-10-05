import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/business/domain/business_profile.dart';
import 'package:paper_route/features/business/domain/business_repository.dart';
import 'package:paper_route/features/business/presentation/business_providers.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/domain/newspaper_repository.dart';
import 'package:paper_route/features/newspapers/presentation/daily_pricing_page.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';

void main() {
  testWidgets(
    'Daily Pricing uses saved region and appends one exact-date price',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 1500);
      addTearDown(tester.view.reset);
      final newspapers = _FakeNewspapers();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessRepositoryProvider.overrideWithValue(_FakeBusiness()),
            newspaperRepositoryProvider.overrideWithValue(newspapers),
          ],
          child: const MaterialApp(home: DailyPricingPage(user: _head)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Daily Pricing'));
      await tester.pumpAndSettle();

      expect(find.text("Today's Paper Prices — Raipur"), findsOneWidget);
      expect(find.text('Chhattisgarh · Central'), findsOneWidget);
      expect(find.text('Add Custom Newspaper'), findsOneWidget);
      expect(find.textContaining('Finalized bills'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('daily-price-amount')),
        '7.25',
      );
      await tester.enterText(
        find.byKey(const ValueKey('daily-price-reason')),
        'Daily market price',
      );
      await tester.tap(find.byKey(const ValueKey('save-daily-price')));
      await tester.pumpAndSettle();

      expect(newspapers.created, hasLength(1));
      expect(newspapers.created.single.kind, PriceRuleKind.exactDate);
      expect(newspapers.created.single.pricePaise, 725);
      expect(find.textContaining('Unfinalized previews'), findsOneWidget);
    },
  );

  testWidgets(
    'Multi-newspaper workspace shows all papers and bulk updates only changed prices',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 1800);
      addTearDown(tester.view.reset);
      final newspapers = _FakeNewspapers(catalog: [_paper, _paper2]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessRepositoryProvider.overrideWithValue(_FakeBusiness()),
            newspaperRepositoryProvider.overrideWithValue(newspapers),
          ],
          child: const MaterialApp(home: DailyPricingPage(user: _head)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Daily Pricing'));
      await tester.pumpAndSettle();

      // Verify both newspapers appear
      expect(find.text('Synthetic Daily'), findsOneWidget);
      expect(find.text('Navbharat Times'), findsOneWidget);

      // Verify price inputs exist for each paper
      expect(
        find.byKey(const ValueKey('price-input-paper-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('price-input-paper-b')),
        findsOneWidget,
      );

      // Change only paper-b's price
      await tester.enterText(
        find.byKey(const ValueKey('price-input-paper-b')),
        '8.00',
      );

      // Save all prices
      await tester.tap(
        find.byKey(const ValueKey('save-all-prices-button')),
      );
      await tester.pumpAndSettle();

      // Only paper-b was changed and saved
      expect(newspapers.bulkUpdates, hasLength(1));
      expect(newspapers.bulkUpdates.single, hasLength(1));
      expect(newspapers.bulkUpdates.single.single.newspaperId, 'paper-b');
      expect(newspapers.bulkUpdates.single.single.pricePaise, 800);

      // SnackBar confirms update count
      expect(
        find.textContaining('Daily price saved for 1 newspaper(s)'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Global Pricing tab allows browsing Indian Master Catalogue to populate publication and default price',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 1800);
      addTearDown(tester.view.reset);
      final newspapers = _FakeNewspapers(catalog: [_paper]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessRepositoryProvider.overrideWithValue(_FakeBusiness()),
            newspaperRepositoryProvider.overrideWithValue(newspapers),
          ],
          child: const MaterialApp(home: DailyPricingPage(user: _head)),
        ),
      );
      await tester.pumpAndSettle();

      // We are on Global Pricing tab (default tab)
      expect(find.text('Publication Price Rule'), findsOneWidget);

      // Verify Browse Indian Master Catalogue button is visible
      final browseBtn =
          find.byKey(const ValueKey('browse-catalog-pricing-button'));
      expect(browseBtn, findsOneWidget);

      // Tap Browse button
      await tester.tap(browseBtn);
      await tester.pumpAndSettle();

      // Master catalog picker sheet is displayed
      expect(find.text('Indian Publication Catalogue'), findsOneWidget);

      // Tap The Times of India
      await tester.tap(find.text('The Times of India').first);
      await tester.pumpAndSettle();

      // Newly added from catalog or selected
      expect(newspapers.createdInputs, hasLength(1));
      expect(newspapers.createdInputs.single.name, 'The Times of India');

      // Price rule was NOT created yet (user must explicitly submit)
      expect(newspapers.created, isEmpty);
    },
  );
}

const _head = AppUser(
  uid: 'head-a',
  email: 'head@example.test',
  displayName: 'Head',
  isEmailVerified: true,
  businessId: 'business-a',
  role: UserRole.head,
  status: AccountStatus.active,
);

class _FakeBusiness implements BusinessRepository {
  @override
  Stream<BusinessProfile> watchBusiness(String businessId) => Stream.value(
    const BusinessProfile(
      id: 'business-a',
      name: 'Synthetic Agency',
      phone: '',
      address: '',
      primaryPricingRegion: PricingRegion(
        state: 'Chhattisgarh',
        districtCity: 'Raipur',
        editionServiceRegion: 'Central',
      ),
    ),
  );

  @override
  Future<void> updateBusiness({
    required String businessId,
    required String actorId,
    required String name,
    required String phone,
    required String address,
  }) async {}

  @override
  Future<void> updatePrimaryPricingRegion({
    required String businessId,
    required String actorId,
    required PricingRegion region,
  }) async {}
}

class _FakeNewspapers implements NewspaperRepository {
  _FakeNewspapers({List<Newspaper>? catalog}) : catalog = catalog ?? const [_paper];

  final List<Newspaper> catalog;
  final created = <PriceRuleInput>[];
  final bulkUpdates = <List<DailyPriceUpdateItem>>[];
  var resolved = const ResolvedNewspaperPrice(
    pricePaise: 650,
    source: ResolvedPriceSource.defaultPrice,
  );

  @override
  Future<NewspaperPage> fetchNewspapers(NewspaperListRequest request) async =>
      NewspaperPage(
        newspapers: catalog,
        nextCursor: null,
        hasMore: false,
      );

  @override
  Future<ResolvedNewspaperPrice> resolvePriceOn({
    required String businessId,
    required String newspaperId,
    required LocalDate date,
  }) async {
    final paper = catalog.firstWhere((p) => p.id == newspaperId, orElse: () => _paper);
    return ResolvedNewspaperPrice(
      pricePaise: paper.defaultPricePaise,
      source: ResolvedPriceSource.defaultPrice,
    );
  }

  @override
  Future<String> createPriceRule({
    required AppUser actor,
    required String newspaperId,
    required PriceRuleInput input,
  }) async {
    created.add(input.normalized());
    resolved = ResolvedNewspaperPrice(
      pricePaise: input.pricePaise,
      source: ResolvedPriceSource.exactDate,
      ruleId: 'rule-1',
    );
    return 'rule-1';
  }

  @override
  Future<String> correctPriceRule({
    required AppUser actor,
    required String newspaperId,
    required String replacedRuleId,
    required PriceRuleInput replacement,
  }) => throw UnimplementedError();

  @override
  Future<BulkDailyPriceUpdateResult> updateDailyPrices({
    required AppUser actor,
    required LocalDate date,
    required List<DailyPriceUpdateItem> updates,
  }) async {
    bulkUpdates.add(updates);
    for (final update in updates) {
      await createPriceRule(
        actor: actor,
        newspaperId: update.newspaperId,
        input: PriceRuleInput(
          kind: PriceRuleKind.exactDate,
          startDate: date,
          endDate: null,
          pricePaise: update.pricePaise,
          reason: update.reason,
        ),
      );
    }
    return BulkDailyPriceUpdateResult(
      updatedCount: updates.length,
      updatedNewspaperIds: updates.map((u) => u.newspaperId).toList(),
    );
  }

  final createdInputs = <NewspaperInput>[];

  @override
  Future<String> createNewspaper({
    required AppUser actor,
    required NewspaperInput input,
  }) async {
    createdInputs.add(input);
    final id = 'paper-${catalog.length + 1}';
    final paper = Newspaper(
      id: id,
      businessId: actor.businessId!,
      newspaperCode: id.toUpperCase(),
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
  Future<PriceRulePage> fetchPriceRules(PriceRuleListRequest request) =>
      throw UnimplementedError();

  @override
  Future<void> setNewspaperArchived({
    required AppUser actor,
    required String newspaperId,
    required bool archived,
  }) => throw UnimplementedError();

  @override
  Future<void> updateNewspaperProfile({
    required AppUser actor,
    required String newspaperId,
    required NewspaperProfileInput input,
  }) => throw UnimplementedError();

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
  Future<PricingImpactPreview> calculatePricingImpact({
    required AppUser actor,
    required String newspaperId,
    required PriceRuleInput input,
  }) async {
    final paper = catalog.firstWhere((p) => p.id == newspaperId, orElse: () => _paper);
    return PricingImpactPreview(
      newspaperId: newspaperId,
      newspaperName: paper.name,
      currentPricePaise: paper.defaultPricePaise,
      proposedPricePaise: input.pricePaise,
      pricingBasis: input.pricingBasis,
      startDate: input.startDate,
      endDate: input.endDate ?? input.startDate,
      affectedSubscriptionsCount: 12,
      unfinalizedBillsCount: 10,
      finalizedBillsCount: 2,
      customerOverridesCount: 1,
      pausedSubscriptionsCount: 1,
      projectedAdditionalBillingPaise: 5000,
    );
  }
}

const _paper = Newspaper(
  id: 'paper-a',
  businessId: 'business-a',
  newspaperCode: 'N-PAPER-A',
  name: 'Synthetic Daily',
  searchName: 'synthetic daily',
  edition: 'Central',
  language: 'English',
  defaultPricePaise: 650,
  status: NewspaperStatus.active,
  createdBy: 'head-a',
  updatedBy: 'head-a',
  lastAuditId: 'audit-a',
);

const _paper2 = Newspaper(
  id: 'paper-b',
  businessId: 'business-a',
  newspaperCode: 'N-PAPER-B',
  name: 'Navbharat Times',
  searchName: 'navbharat times',
  edition: 'Raipur',
  language: 'Hindi',
  defaultPricePaise: 500,
  status: NewspaperStatus.active,
  createdBy: 'head-a',
  updatedBy: 'head-a',
  lastAuditId: 'audit-b',
);
