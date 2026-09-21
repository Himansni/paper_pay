import 'package:paper_route/features/business/domain/business_profile.dart';

// BEGINNER NOTE:
// [BusinessRepository] contract isolating tenant profile persistence from presentation code.
// Exposes real-time streams for reactive workspace updates and administrative update operations
// restricted to the Head distributor.
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
