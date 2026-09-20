import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/business/data/firebase_business_repository.dart';
import 'package:paper_route/features/business/domain/business_profile.dart';
import 'package:paper_route/features/business/domain/business_repository.dart';

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return FirebaseBusinessRepository.fromDefaultApp();
});

final businessProfileProvider = StreamProvider.autoDispose
    .family<BusinessProfile, String>((ref, businessId) {
      return ref.watch(businessRepositoryProvider).watchBusiness(businessId);
    });
