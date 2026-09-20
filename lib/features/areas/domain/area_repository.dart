import 'package:paper_route/features/areas/domain/delivery_area.dart';

/// Tenant-scoped boundary for area storage. Presentation code depends on this
/// contract rather than constructing Firestore paths itself.
abstract interface class AreaRepository {
  Stream<List<DeliveryArea>> watchAreas(String businessId);

  Future<void> createArea({
    required String businessId,
    required String actorId,
    required String name,
  });

  Future<void> updateArea({
    required String businessId,
    required String actorId,
    required String areaId,
    required String name,
    required bool isActive,
  });

  Future<void> setEmployeeAssignments({
    required String businessId,
    required String actorId,
    required String areaId,
    required Set<String> previousEmployeeIds,
    required Set<String> employeeIds,
  });
}
