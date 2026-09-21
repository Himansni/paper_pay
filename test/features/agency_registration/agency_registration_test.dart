import 'package:flutter_test/flutter_test.dart';
import 'package:paper_route/features/agency_registration/domain/agency_registration.dart';

void main() {
  test('draft is complete only with all agency details and both consents', () {
    const incomplete = AgencyRegistrationDraft(
      ownerDisplayName: 'Owner',
      ownerPhone: '9999999999',
      agencyName: 'Agency',
      agencyPhone: '8888888888',
      agencyAddress: 'Test address',
      termsAccepted: true,
      privacyAccepted: false,
    );
    expect(incomplete.isComplete, isFalse);
    expect(
      const AgencyRegistrationDraft(
        ownerDisplayName: 'Owner',
        ownerPhone: '9999999999',
        agencyName: 'Agency',
        agencyPhone: '8888888888',
        agencyAddress: 'Test address',
        termsAccepted: true,
        privacyAccepted: true,
      ).isComplete,
      isTrue,
    );
  });

  test('pending invitations are an explicit choice, not owner authority', () {
    const options = AgencyRegistrationOptions(
      eligibility: AgencyRegistrationEligibility.eligible,
      pendingInvitationCount: 2,
    );
    expect(options.hasPendingEmployeeInvitation, isTrue);
    expect(options.eligibility, AgencyRegistrationEligibility.eligible);
  });
}
