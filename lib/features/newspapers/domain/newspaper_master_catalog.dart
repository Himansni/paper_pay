import 'package:paper_route/features/business/domain/business_profile.dart';

class MasterNewspaperEntry {
  const MasterNewspaperEntry({
    required this.id,
    required this.state,
    required this.districtCity,
    required this.name,
    required this.edition,
    required this.language,
  });

  final String id;
  final String state;
  final String districtCity;
  final String name;
  final String edition;
  final String language;
}

/// Optional source for standardized suggestions. The business catalog remains
/// authoritative, and callers must always retain an Add Custom Newspaper path.
/// No national dataset or external API is bundled in Phase 7.
abstract interface class NewspaperMasterCatalog {
  Future<List<MasterNewspaperEntry>> suggestionsFor(PricingRegion region);
}
