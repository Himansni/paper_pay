import 'package:paper_route/features/agency_registration/domain/agency_registration.dart';

abstract interface class AgencyRegistrationRepository {
  Future<void> createOwnerIdentity({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AgencyRegistrationOptions> getRegistrationOptions();

  Future<AgencyProvisioningResult> provisionAgencyOwner({
    required AgencyRegistrationDraft draft,
  });
}
