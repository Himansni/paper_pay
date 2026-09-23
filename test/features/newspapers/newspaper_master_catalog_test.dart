import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/features/business/domain/business_profile.dart';
import 'package:paper_route/features/newspapers/domain/newspaper_master_catalog.dart';

void main() {
  group('NewspaperMasterCatalog & Indian Publication Dataset', () {
    const catalog = LocalNewspaperMasterCatalog();

    test('Contains rich dataset of Indian newspapers and magazines', () {
      expect(LocalNewspaperMasterCatalog.bundledEntries.length, greaterThanOrEqualTo(40));
    });

    test('Finds publications by common English and Hindi aliases', () async {
      // Times of India by TOI
      final toiResults = await catalog.search(query: 'TOI');
      expect(toiResults, isNotEmpty);
      expect(toiResults.any((e) => e.name.contains('Times of India')), isTrue);

      // Dainik Jagran by Hindi Devanagari query
      final jagranResults = await catalog.search(query: 'जागरण');
      expect(jagranResults, isNotEmpty);
      expect(jagranResults.any((e) => e.name.contains('Dainik Jagran')), isTrue);

      // Anandabazar Patrika by ABP alias
      final abpResults = await catalog.search(query: 'ABP');
      expect(abpResults, isNotEmpty);
      expect(abpResults.any((e) => e.name.contains('Anandabazar')), isTrue);

      // Pratiyogita Darpan by PD alias
      final pdResults = await catalog.search(query: 'Darpan');
      expect(pdResults, isNotEmpty);
      expect(pdResults.any((e) => e.name.contains('Pratiyogita Darpan')), isTrue);
    });

    test('Filters accurately by publication type (Newspaper vs Magazine)', () async {
      final newspapers = await catalog.search(type: PublicationType.newspaper);
      expect(newspapers.every((e) => e.type == PublicationType.newspaper), isTrue);

      final magazines = await catalog.search(type: PublicationType.magazine);
      expect(magazines.isNotEmpty, isTrue);
      expect(magazines.every((e) => e.type == PublicationType.magazine), isTrue);
      expect(magazines.any((e) => e.name == 'India Today'), isTrue);
      expect(magazines.any((e) => e.name == 'Grihshobha'), isTrue);
    });

    test('Filters accurately by language', () async {
      final hindiResults = await catalog.search(language: 'Hindi');
      expect(hindiResults.every((e) => e.language == 'Hindi'), isTrue);
      expect(hindiResults.any((e) => e.name == 'Amar Ujala'), isTrue);

      final marathiResults = await catalog.search(language: 'Marathi');
      expect(marathiResults.every((e) => e.language == 'Marathi'), isTrue);
      expect(marathiResults.any((e) => e.name == 'Lokmat'), isTrue);
    });

    test('SuggestionsFor returns state-specific and national publications', () async {
      const delhiRegion = PricingRegion(
        state: 'Delhi',
        districtCity: 'Delhi',
        editionServiceRegion: 'Central',
      );
      final suggestions = await catalog.suggestionsFor(delhiRegion);
      expect(suggestions, isNotEmpty);
      expect(suggestions.any((e) => e.state == 'Delhi' || e.state == 'National'), isTrue);
    });
  });
}
