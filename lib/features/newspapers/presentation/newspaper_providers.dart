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
      final page = await ref
          .watch(newspaperRepositoryProvider)
          .fetchNewspapers(
            NewspaperListRequest(
              businessId: key.businessId,
              requesterId: key.requesterId,
              status: NewspaperStatus.active,
              pageSize: 50,
            ),
          );
      final uniqueMap = <String, Newspaper>{};
      for (final n in page.newspapers) {
        final key = n.displayName.trim().toLowerCase();
        uniqueMap.putIfAbsent(key.isEmpty ? n.id : key, () => n);
      }
      return uniqueMap.values.toList();
    });
