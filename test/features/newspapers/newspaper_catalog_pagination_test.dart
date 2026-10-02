import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/domain/newspaper_master_catalog.dart';
import 'package:paper_route/features/newspapers/domain/newspaper_repository.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_providers.dart';

class _PaginatedNewspaperRepository implements NewspaperRepository {
  _PaginatedNewspaperRepository(this.allNewspapers);

  final List<Newspaper> allNewspapers;
  final List<NewspaperListRequest> recordedRequests = [];

  @override
  Future<NewspaperPage> fetchNewspapers(NewspaperListRequest request) async {
    recordedRequests.add(request);

    // Filter by status
    var filtered = allNewspapers.where((n) => n.status == request.status).toList();

    // Filter by search token if present
    final searchToken = request.searchToken;
    if (searchToken != null && searchToken.isNotEmpty) {
      filtered = filtered.where((n) {
        if (request.isCodeSearch) {
          return n.newspaperCode.toUpperCase() == searchToken;
        }
        return n.searchName.contains(searchToken) ||
            n.name.toLowerCase().contains(searchToken);
      }).toList();
    }

    // Sort stably by searchName, then id
    filtered.sort((a, b) {
      final cmp = a.searchName.compareTo(b.searchName);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });

    // Handle cursor
    int startIndex = 0;
    if (request.cursor != null) {
      final cursor = request.cursor!;
      final idx = filtered.indexWhere(
        (n) => n.searchName == cursor.searchName && n.id == cursor.newspaperId,
      );
      if (idx != -1) {
        startIndex = idx + 1;
      }
    }

    final paged = filtered.skip(startIndex).take(request.pageSize).toList();
    final hasMore = startIndex + request.pageSize < filtered.length;
    final nextCursor = paged.isEmpty || !hasMore
        ? null
        : NewspaperPageCursor(
            searchName: paged.last.searchName,
            newspaperId: paged.last.id,
          );

    return NewspaperPage(
      newspapers: paged,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Newspaper Catalog Pagination & Deduplication Tests', () {
    // Generate 65 publications to simulate a 60+ catalog
    final List<Newspaper> catalog65 = List.generate(65, (i) {
      final padded = i.toString().padLeft(3, '0');
      return Newspaper(
        id: 'NP-$padded',
        newspaperCode: 'NP-$padded',
        businessId: 'biz-1',
        name: 'Publication $padded',
        searchName: 'publication $padded',
        edition: i % 2 == 0 ? 'City Edition' : 'Regional Edition',
        language: i % 3 == 0 ? 'Hindi' : 'English',
        defaultPricePaise: 400 + (i * 10),
        status: i == 64 ? NewspaperStatus.archived : NewspaperStatus.active,
        createdBy: 'head-1',
        updatedBy: 'head-1',
        lastAuditId: 'audit-$padded',
      );
    });

    test('activeNewspapersListProvider fetches across multiple pages (>50 publications)', () async {
      final repo = _PaginatedNewspaperRepository(catalog65);
      final container = ProviderContainer(
        overrides: [
          newspaperRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        activeNewspapersListProvider((
          businessId: 'biz-1',
          requesterId: 'head-1',
        ),).future,
      );

      // Total active is 64 (index 0 to 63), index 64 is archived
      expect(result.length, equals(64));
      // Proves page 1 and page 2 both loaded
      expect(repo.recordedRequests.length, greaterThanOrEqualTo(2));
      expect(repo.recordedRequests[0].pageSize, equals(50));
      expect(repo.recordedRequests[0].cursor, isNull);
      expect(repo.recordedRequests[1].cursor, isNotNull);

      // Verify first and last active publications are discoverable
      expect(result.any((n) => n.id == 'NP-000'), isTrue);
      expect(result.any((n) => n.id == 'NP-063'), isTrue);
    });

    test('inactive/archived publications are strictly excluded from activeNewspapersListProvider', () async {
      final repo = _PaginatedNewspaperRepository(catalog65);
      final container = ProviderContainer(
        overrides: [
          newspaperRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        activeNewspapersListProvider((
          businessId: 'biz-1',
          requesterId: 'head-1',
        ),).future,
      );

      // NP-064 is archived
      expect(result.any((n) => n.id == 'NP-064'), isFalse);
      expect(result.every((n) => n.status == NewspaperStatus.active), isTrue);
    });

    test('search can find an item beyond the first 50 items', () async {
      final repo = _PaginatedNewspaperRepository(catalog65);

      // Fetch with search term '055' (which would be on page 2 in a 50-item page)
      final searchResult = await repo.fetchNewspapers(
        const NewspaperListRequest(
          businessId: 'biz-1',
          requesterId: 'head-1',
          searchField: NewspaperSearchField.name,
          searchTerm: '055',
          pageSize: 50,
        ),
      );

      expect(searchResult.newspapers.length, equals(1));
      expect(searchResult.newspapers.first.id, equals('NP-055'));
      expect(searchResult.newspapers.first.name, equals('Publication 055'));
    });

    test('no duplicate results across page boundaries', () async {
      final repo = _PaginatedNewspaperRepository(catalog65);
      final container = ProviderContainer(
        overrides: [
          newspaperRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        activeNewspapersListProvider((
          businessId: 'biz-1',
          requesterId: 'head-1',
        ),).future,
      );

      final idSet = <String>{};
      for (final n in result) {
        expect(idSet.add(n.id), isTrue, reason: 'Duplicate ID found: ${n.id}');
      }
    });

    group('Semantic Identity Deduplication (A-D)', () {
      const basePaper = Newspaper(
        id: 'NP-101',
        newspaperCode: 'NP-101',
        businessId: 'biz-1',
        name: 'Dainik Bhaskar',
        searchName: 'dainik bhaskar',
        edition: 'Bhopal',
        language: 'Hindi',
        defaultPricePaise: 450,
        status: NewspaperStatus.active,
        createdBy: 'head-1',
        updatedBy: 'head-1',
        lastAuditId: 'audit-1',
      );

      test('A. Same Firestore document repeated -> display once', () async {
        final papersWithDocRepeat = [
          basePaper,
          basePaper, // Same instance/id
        ];

        final repo = _PaginatedNewspaperRepository(papersWithDocRepeat);
        final container = ProviderContainer(
          overrides: [
            newspaperRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          activeNewspapersListProvider((
            businessId: 'biz-1',
            requesterId: 'head-1',
          ),).future,
        );

        expect(result.length, equals(1));
        expect(result.first.id, equals('NP-101'));
      });

      test('B. Different documents with identical semantic identity -> display once', () async {
        const duplicateSemanticPaper = Newspaper(
          id: 'NP-101-DUP-DOC',
          newspaperCode: 'NP-101-DUP',
          businessId: 'biz-1',
          name: '  dainik bhaskar  ', // Whitespace/case variations
          searchName: 'dainik bhaskar',
          edition: 'bhopal',
          language: 'HINDI',
          defaultPricePaise: 450,
          status: NewspaperStatus.active,
          createdBy: 'head-1',
          updatedBy: 'head-1',
          lastAuditId: 'audit-dup',
        );

        final papers = [basePaper, duplicateSemanticPaper];
        final repo = _PaginatedNewspaperRepository(papers);
        final container = ProviderContainer(
          overrides: [
            newspaperRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          activeNewspapersListProvider((
            businessId: 'biz-1',
            requesterId: 'head-1',
          ),).future,
        );

        expect(result.length, equals(1));
        expect(result.first.id, equals('NP-101'));
      });

      test('C. Same publication name but different edition -> preserve both', () async {
        const indoreEdition = Newspaper(
          id: 'NP-102',
          newspaperCode: 'NP-102',
          businessId: 'biz-1',
          name: 'Dainik Bhaskar',
          searchName: 'dainik bhaskar',
          edition: 'Indore', // Different edition
          language: 'Hindi',
          defaultPricePaise: 450,
          status: NewspaperStatus.active,
          createdBy: 'head-1',
          updatedBy: 'head-1',
          lastAuditId: 'audit-2',
        );

        final papers = [basePaper, indoreEdition];
        final repo = _PaginatedNewspaperRepository(papers);
        final container = ProviderContainer(
          overrides: [
            newspaperRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          activeNewspapersListProvider((
            businessId: 'biz-1',
            requesterId: 'head-1',
          ),).future,
        );

        expect(result.length, equals(2));
        expect(result.map((n) => n.edition).toSet(), equals({'Bhopal', 'Indore'}));
      });

      test('D. Same publication/edition but different language -> preserve both', () async {
        const englishLanguage = Newspaper(
          id: 'NP-103',
          newspaperCode: 'NP-103',
          businessId: 'biz-1',
          name: 'Dainik Bhaskar',
          searchName: 'dainik bhaskar',
          edition: 'Bhopal',
          language: 'English', // Different language
          defaultPricePaise: 500,
          status: NewspaperStatus.active,
          createdBy: 'head-1',
          updatedBy: 'head-1',
          lastAuditId: 'audit-3',
        );

        final papers = [basePaper, englishLanguage];
        final repo = _PaginatedNewspaperRepository(papers);
        final container = ProviderContainer(
          overrides: [
            newspaperRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          activeNewspapersListProvider((
            businessId: 'biz-1',
            requesterId: 'head-1',
          ),).future,
        );

        expect(result.length, equals(2));
        expect(result.map((n) => n.language).toSet(), equals({'Hindi', 'English'}));
      });
    });

    group('LocalNewspaperMasterCatalog Diagnostics & Verification', () {
      test('bundled master catalog has unique IDs and valid legitimate variants', () {
        const entries = LocalNewspaperMasterCatalog.bundledEntries;
        expect(entries.length, greaterThan(60));

        final idSet = <String>{};
        final semanticSet = <String>{};
        final semanticDuplicates = <String>[];

        for (final entry in entries) {
          expect(idSet.add(entry.id), isTrue, reason: 'Duplicate ID: ${entry.id}');
          final key = '${entry.name.trim().toLowerCase()}|${entry.edition.trim().toLowerCase()}|${entry.language.trim().toLowerCase()}';
          if (!semanticSet.add(key)) {
            semanticDuplicates.add('${entry.id}: $key');
          }
        }

        // Verify no duplicate semantic items in master catalog
        expect(semanticDuplicates, isEmpty);

        // Verify legitimate edition variants exist (e.g. Bhopal vs Indore)
        final bhaskarEditions = entries.where((e) => e.name.toLowerCase().contains('dainik bhaskar')).map((e) => e.edition).toSet();
        expect(bhaskarEditions.length, greaterThanOrEqualTo(2));

        // Verify legitimate language variants exist (e.g. English vs Hindi)
        final languages = entries.map((e) => e.language).toSet();
        expect(languages.contains('Hindi'), isTrue);
        expect(languages.contains('English'), isTrue);
      });
    });
  });
}
