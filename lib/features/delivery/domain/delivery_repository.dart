import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/features/delivery/domain/delivery_models.dart';
import 'package:paper_route/features/delivery/domain/route_order.dart';

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

  Future<RouteOrder?> getRouteOrder({
    required String businessId,
    required String areaId,
  });

  Stream<RouteOrder?> watchRouteOrder({
    required String businessId,
    required String areaId,
  });

  Future<void> saveRouteOrder({
    required String businessId,
    required String areaId,
    required List<String> customerIds,
    required String actorUid,
  });

  Future<void> insertCustomerInRoute({
    required String businessId,
    required String areaId,
    required String customerId,
    required RoutePlacement placement,
    String? afterCustomerId,
    required String actorUid,
  });
}
