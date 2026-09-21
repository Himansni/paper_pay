import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/business/data/firebase_business_repository.dart';
import 'package:paper_route/features/business/domain/business_profile.dart';
import 'package:paper_route/features/business/domain/business_repository.dart';

// BEGINNER NOTE:
// Riverpod provider providing singleton access to the [BusinessRepository].
// Presentation code reads this provider instead of constructing Firestore classes directly.
final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return FirebaseBusinessRepository.fromDefaultApp();
});

// BEGINNER NOTE:
// Real-time stream provider parameterized by `businessId`.
// Automatically subscribes to Firestore tenant changes and disposes the listener
// when no UI widgets are actively watching it.
final businessProfileProvider = StreamProvider.autoDispose
    .family<BusinessProfile, String>((ref, businessId) {
      return ref.watch(businessRepositoryProvider).watchBusiness(businessId);
    });
