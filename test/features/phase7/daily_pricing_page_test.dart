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
  final created = <PriceRuleInput>[];
  var resolved = const ResolvedNewspaperPrice(
    pricePaise: 650,
    source: ResolvedPriceSource.defaultPrice,
  );

  @override
  Future<NewspaperPage> fetchNewspapers(NewspaperListRequest request) async =>
      const NewspaperPage(
        newspapers: [_paper],
        nextCursor: null,
        hasMore: false,
      );

  @override
  Future<ResolvedNewspaperPrice> resolvePriceOn({
    required String businessId,
    required String newspaperId,
    required LocalDate date,
  }) async => resolved;

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
  Future<String> createNewspaper({
    required AppUser actor,
    required NewspaperInput input,
  }) => throw UnimplementedError();

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
  }) => Stream.value(_paper);

  @override
  Stream<List<NewspaperAuditEntry>> watchNewspaperHistory({
    required String businessId,
    required String newspaperId,
  }) => Stream.value(const []);
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
