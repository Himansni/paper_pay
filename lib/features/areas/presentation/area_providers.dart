import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/areas/data/firebase_area_repository.dart';
import 'package:paper_route/features/areas/domain/area_repository.dart';
import 'package:paper_route/features/areas/domain/delivery_area.dart';

final areaRepositoryProvider = Provider<AreaRepository>((ref) {
  return FirebaseAreaRepository.fromDefaultApp();
});

final deliveryAreasProvider = StreamProvider.autoDispose
    .family<List<DeliveryArea>, String>((ref, businessId) {
      return ref.watch(areaRepositoryProvider).watchAreas(businessId);
    });
