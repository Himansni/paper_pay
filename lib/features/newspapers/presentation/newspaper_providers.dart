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
