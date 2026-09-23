import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/delivery/domain/delivery_models.dart';

abstract class DeliveryRepository {
  Future<void> recordDropStatus({
    required String businessId,
    required String areaId,
    required LocalDate date,
    required String customerId,
    required DeliveryStopStatus status,
    String? exceptionReason,
    required String actorUid,
  });

  Future<Map<String, DeliveryDropRecord>> fetchRouteDrops({
    required String businessId,
    required String areaId,
    required LocalDate date,
  });

  Stream<Map<String, DeliveryDropRecord>> watchRouteDrops({
    required String businessId,
    required String areaId,
    required LocalDate date,
  });

  Future<List<DeliveryDropRecord>> fetchTodayExceptions({
    required String businessId,
    required LocalDate date,
  });
}
