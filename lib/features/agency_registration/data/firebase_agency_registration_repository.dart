import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/agency_registration/domain/agency_registration.dart';
import 'package:paper_route/features/agency_registration/domain/agency_registration_repository.dart';
import 'package:uuid/uuid.dart';

class FirebaseAgencyRegistrationRepository
    implements AgencyRegistrationRepository {
  FirebaseAgencyRegistrationRepository({
    required FirebaseAuth auth,
    required FirebaseFunctions functions,
  }) : _auth = auth,
       _functions = functions;

  factory FirebaseAgencyRegistrationRepository.fromDefaultApp() =>
      FirebaseAgencyRegistrationRepository(
        auth: FirebaseAuth.instance,
        functions: FirebaseFunctions.instanceFor(region: 'asia-south1'),
      );

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  @override
  Future<void> createOwnerIdentity({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      await credential.user?.updateDisplayName(displayName.trim());
      await credential.user?.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw _authError(error);
    }
  }

  @override
  Future<AgencyRegistrationOptions> getRegistrationOptions() async {
    try {
      final callable = _functions.httpsCallable('getAgencyRegistrationOptions');
      final response = await callable.call<Map<String, dynamic>>({});
      final data = response.data;
      final eligibility = switch (data['eligibility']) {
        'eligible' => AgencyRegistrationEligibility.eligible,
        'alreadyProvisioned' =>
          AgencyRegistrationEligibility.alreadyProvisioned,
        _ => AgencyRegistrationEligibility.blocked,
      };
      return AgencyRegistrationOptions(
        eligibility: eligibility,
        pendingInvitationCount:
            (data['pendingInvitationCount'] as num?)?.toInt() ?? 0,
        conflictReason: data['conflictReason'] as String?,
      );
    } on FirebaseFunctionsException catch (error) {
      throw _functionsError(error);
    }
  }

  @override
  Future<AgencyProvisioningResult> provisionAgencyOwner({
    required AgencyRegistrationDraft draft,
  }) async {
    if (!draft.isComplete) {
      throw const AppException(
        'Complete the agency details and accept the current legal documents.',
        code: 'incomplete-registration',
      );
    }
    final requestId = draft.requestId ?? const Uuid().v4();
    try {
      final callable = _functions.httpsCallable('provisionAgencyOwner');
      final response = await callable.call<Map<String, dynamic>>({
        'ownerDisplayName': draft.ownerDisplayName,
        'ownerPhone': draft.ownerPhone,
        'agencyName': draft.agencyName,
        'agencyPhone': draft.agencyPhone,
        'agencyAddress': draft.agencyAddress,
        'termsVersion': AgencyLegalDocuments.termsVersion,
        'privacyVersion': AgencyLegalDocuments.privacyVersion,
        'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
        'clientPlatform':
            kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase(),
        'requestId': requestId,
      });
      return AgencyProvisioningResult(
        businessId: response.data['businessId'] as String,
        alreadyProvisioned:
            response.data['alreadyProvisioned'] as bool? ?? false,
      );
    } on FirebaseFunctionsException catch (error) {
      throw _functionsError(error);
    }
  }

  AppException _authError(FirebaseAuthException error) {
    final message = switch (error.code) {
      'email-already-in-use' =>
        'An account already exists for this email. Sign in to continue.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' => 'Use a password with at least 8 characters.',
      'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
      'network-request-failed' =>
        'Check your internet connection and try again.',
      _ => 'Could not create the account. Please try again.',
    };
    return AppException(message, code: error.code);
  }

  AppException _functionsError(FirebaseFunctionsException error) {
    final message = switch (error.code) {
      'unauthenticated' => 'Your session ended. Sign in and try again.',
      'failed-precondition' =>
        error.message ??
            'This account cannot create an agency in its current state.',
      'resource-exhausted' =>
        error.message ?? 'Too many attempts. Wait before trying again.',
      'invalid-argument' => error.message ?? 'Check the registration details.',
      _ => 'Agency setup could not be completed. Please try again.',
    };
    return AppException(message, code: error.code);
  }
}
