import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/newspapers/data/firebase_newspaper_repository.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/domain/newspaper_repository.dart';

typedef NewspaperDocumentKey = ({String businessId, String newspaperId});

final newspaperRepositoryProvider = Provider<NewspaperRepository>((ref) {
  return FirebaseNewspaperRepository.fromDefaultApp();
});

final newspaperProvider = StreamProvider.autoDispose
    .family<Newspaper?, NewspaperDocumentKey>((ref, key) {
      return ref
          .watch(newspaperRepositoryProvider)
          .watchNewspaper(
            businessId: key.businessId,
            newspaperId: key.newspaperId,
          );
    });

final newspaperAuditProvider = StreamProvider.autoDispose
    .family<List<NewspaperAuditEntry>, NewspaperDocumentKey>((ref, key) {
      return ref
          .watch(newspaperRepositoryProvider)
          .watchNewspaperHistory(
            businessId: key.businessId,
            newspaperId: key.newspaperId,
          );
    });

final activeNewspapersListProvider = FutureProvider.autoDispose
    .family<List<Newspaper>, ({String businessId, String requesterId})>((
      ref,
      key,
    ) async {
      final repository = ref.watch(newspaperRepositoryProvider);
      final all = <Newspaper>[];
      NewspaperPageCursor? cursor;
      while (true) {
        final page = await repository.fetchNewspapers(
          NewspaperListRequest(
            businessId: key.businessId,
            requesterId: key.requesterId,
            status: NewspaperStatus.active,
            pageSize: 50,
            cursor: cursor,
          ),
        );
        all.addAll(page.newspapers);
        if (!page.hasMore || page.nextCursor == null) break;
        if (cursor != null && cursor.newspaperId == page.nextCursor!.newspaperId) {
          break;
        }
        cursor = page.nextCursor;
      }
      final uniqueMap = <String, Newspaper>{};
      for (final n in all) {
        if (n.status != NewspaperStatus.active) continue;
        final semanticKey = n.semanticIdentityKey;
        uniqueMap.putIfAbsent(
          semanticKey.isEmpty ? n.id : semanticKey,
          () => n,
        );
      }
      return uniqueMap.values.toList();
    });
