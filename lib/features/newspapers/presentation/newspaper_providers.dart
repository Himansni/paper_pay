import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/newspapers/data/firebase_newspaper_repository.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/domain/newspaper_repository.dart';

// Riverpod supplies one repository instance to the UI and keys live document
// streams by both tenant and newspaper so state cannot be mixed across businesses.
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
