enum AgencyRegistrationEligibility { eligible, alreadyProvisioned, blocked }

enum AgencyRegistrationIntent { acceptEmployeeInvitation, createAgency }

enum AgencyProvisioningStage {
  collectingDetails,
  awaitingEmailVerification,
  choosingAccountPath,
  readyToProvision,
  provisioning,
  completed,
  blocked,
}

class AgencyRegistrationDraft {
  const AgencyRegistrationDraft({
    required this.ownerDisplayName,
    required this.ownerPhone,
    required this.agencyName,
    required this.agencyPhone,
    required this.agencyAddress,
    required this.termsAccepted,
    required this.privacyAccepted,
    this.requestId,
  });

  final String ownerDisplayName;
  final String ownerPhone;
  final String agencyName;
  final String agencyPhone;
  final String agencyAddress;
  final bool termsAccepted;
  final bool privacyAccepted;
  final String? requestId;

  bool get isComplete =>
      ownerDisplayName.trim().length >= 2 &&
      ownerPhone.trim().length >= 7 &&
      agencyName.trim().length >= 2 &&
      agencyPhone.trim().length >= 7 &&
      agencyAddress.trim().length >= 5 &&
      termsAccepted &&
      privacyAccepted;

  AgencyRegistrationDraft copyWith({String? requestId}) =>
      AgencyRegistrationDraft(
        ownerDisplayName: ownerDisplayName,
        ownerPhone: ownerPhone,
        agencyName: agencyName,
        agencyPhone: agencyPhone,
        agencyAddress: agencyAddress,
        termsAccepted: termsAccepted,
        privacyAccepted: privacyAccepted,
        requestId: requestId ?? this.requestId,
      );
}

class AgencyRegistrationOptions {
  const AgencyRegistrationOptions({
    required this.eligibility,
    required this.pendingInvitationCount,
    this.conflictReason,
  });

  final AgencyRegistrationEligibility eligibility;
  final int pendingInvitationCount;
  final String? conflictReason;

  bool get hasPendingEmployeeInvitation => pendingInvitationCount > 0;
}

class AgencyProvisioningResult {
  const AgencyProvisioningResult({
    required this.businessId,
    required this.alreadyProvisioned,
  });

  final String businessId;
  final bool alreadyProvisioned;
}

abstract final class AgencyLegalDocuments {
  static const termsVersion = 'terms-v1';
  static const privacyVersion = 'privacy-v1';
  static const termsAsset = 'assets/legal/paperroute_terms_v1.txt';
  static const privacyAsset = 'assets/legal/paperroute_privacy_v1.txt';
}
