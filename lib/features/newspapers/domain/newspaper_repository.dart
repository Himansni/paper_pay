import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';

abstract interface class NewspaperRepository {
  Future<NewspaperPage> fetchNewspapers(NewspaperListRequest request);

  Stream<Newspaper?> watchNewspaper({
    required String businessId,
    required String newspaperId,
  });

  Stream<List<NewspaperAuditEntry>> watchNewspaperHistory({
    required String businessId,
    required String newspaperId,
  });

  Future<String> createNewspaper({
    required AppUser actor,
    required NewspaperInput input,
  });

  Future<void> updateNewspaperProfile({
    required AppUser actor,
    required String newspaperId,
    required NewspaperProfileInput input,
  });

  Future<void> setNewspaperArchived({
    required AppUser actor,
    required String newspaperId,
    required bool archived,
  });

  Future<PriceRulePage> fetchPriceRules(PriceRuleListRequest request);

  Future<String> createPriceRule({
    required AppUser actor,
    required String newspaperId,
    required PriceRuleInput input,
  });

  Future<String> correctPriceRule({
    required AppUser actor,
    required String newspaperId,
    required String replacedRuleId,
    required PriceRuleInput replacement,
  });

  Future<ResolvedNewspaperPrice> resolvePriceOn({
    required String businessId,
    required String newspaperId,
    required LocalDate date,
  });
}
