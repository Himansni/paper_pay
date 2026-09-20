import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/areas/data/firebase_area_repository.dart';
import 'package:paper_route/features/areas/domain/area_repository.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';

/// Supplies the Firebase implementation while keeping widgets repository-agnostic.
final areaRepositoryProvider = Provider<AreaRepository>((ref) {
  return FirebaseAreaRepository.fromDefaultApp();
});

// BEGINNER NOTE:
// A provider family creates a separate stream for each business ID. autoDispose
// releases the tenant listener after no screen is watching it.
final deliveryAreasProvider = StreamProvider.autoDispose
    .family<List<DeliveryArea>, String>((ref, businessId) {
      return ref.watch(areaRepositoryProvider).watchAreas(businessId);
    });
