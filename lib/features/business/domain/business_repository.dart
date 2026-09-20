import 'package:paper_route/features/business/domain/business_profile.dart';

abstract interface class BusinessRepository {
  Stream<BusinessProfile> watchBusiness(String businessId);

  Future<void> updateBusiness({
    required String businessId,
    required String actorId,
    required String name,
    required String phone,
    required String address,
  });

  Future<void> updatePrimaryPricingRegion({
    required String businessId,
    required String actorId,
    required PricingRegion region,
  });
}
