import {getAuth} from "firebase-admin/auth";
import {createHash} from "node:crypto";
import {
  FieldValue,
  Firestore,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {CallableRequest, HttpsError} from "firebase-functions/v2/https";
import {optionsRateLimit, provisionRateLimit} from "./environment";
import {consentAcceptanceId, legalDocuments} from "./legal_documents";
import {
  parseProvisionAgencyOwnerRequest,
  ProvisionAgencyOwnerRequest,
} from "./provisioning_contract";
import {enforceUidRateLimit} from "./rate_limit";

interface Identity {
  uid: string;
  email: string;
}

async function requireVerifiedIdentity(
  request: CallableRequest<unknown>,
): Promise<Identity> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in before continuing.");
  }
  const user = await getAuth().getUser(request.auth.uid);
  const email = user.email?.trim().toLowerCase();
  if (!user.emailVerified || !email) {
    throw new HttpsError(
      "failed-precondition",
      "Verify the account email before creating an agency.",
    );
  }
  return {uid: user.uid, email};
}

async function identityState(firestore: Firestore, identity: Identity) {
  const ownerReference = firestore.doc(`agencyOwners/${identity.uid}`);
  const profileReference = firestore.doc(`userProfiles/${identity.uid}`);
  const membersQuery = firestore
    .collectionGroup("members")
    .where("uid", "==", identity.uid)
    .limit(2);
  const invitationsQuery = firestore
    .collectionGroup("invitations")
    .where("email", "==", identity.email);
  const businessesQuery = firestore
    .collection("businesses")
    .where("ownerId", "==", identity.uid)
    .limit(2);
  const [owner, profile, members, invitations, businesses] = await Promise.all([
    ownerReference.get(),
    profileReference.get(),
    membersQuery.get(),
    invitationsQuery.get(),
    businessesQuery.get(),
  ]);
  return {owner, profile, members, invitations, businesses};
}

function validPendingInvitationCount(
  invitations: FirebaseFirestore.QuerySnapshot,
): number {
  const now = Timestamp.now().toMillis();
  return invitations.docs.filter((document) => {
    const data = document.data();
    return data.status === "pending" &&
      data.role === "employee" &&
      data.expiresAt instanceof Timestamp &&
      data.expiresAt.toMillis() > now;
  }).length;
}

function legacyConflictReason(
  state: Awaited<ReturnType<typeof identityState>>,
): string | null {
  if (state.profile.exists) return "existing-profile";
  if (!state.members.empty) return "existing-membership";
  if (!state.businesses.empty) return "existing-business-ownership";
  const accepted = state.invitations.docs.some((document) => {
    const data = document.data();
    return data.status === "accepted" || data.acceptedBy != null;
  });
  return accepted ? "accepted-employee-invitation" : null;
}

export async function getAgencyRegistrationOptionsHandler(
  request: CallableRequest<unknown>,
) {
  const identity = await requireVerifiedIdentity(request);
  const firestore = getFirestore();
  await enforceUidRateLimit(
    firestore,
    identity.uid,
    "options",
    optionsRateLimit,
  );
  if (
    request.data !== undefined &&
    request.data !== null &&
    (typeof request.data !== "object" ||
      Array.isArray(request.data) ||
      Object.keys(request.data as Record<string, unknown>).length > 0)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Registration options accepts no request fields.",
    );
  }
  const state = await identityState(firestore, identity);
  if (state.owner.exists) {
    if (!(await existingOwnerIsConsistent(firestore, state, identity))) {
      return {
        eligibility: "blocked",
        conflictReason: "inconsistent-owner-registry",
        hasPendingEmployeeInvitation: false,
        pendingInvitationCount: 0,
      };
    }
    return {
      eligibility: "alreadyProvisioned",
      hasPendingEmployeeInvitation: false,
      pendingInvitationCount: 0,
    };
  }
  const conflictReason = legacyConflictReason(state);
  if (conflictReason) {
    return {
      eligibility: "blocked",
      conflictReason,
      hasPendingEmployeeInvitation: false,
      pendingInvitationCount: 0,
    };
  }
  const pendingInvitationCount = validPendingInvitationCount(state.invitations);
  return {
    eligibility: "eligible",
    hasPendingEmployeeInvitation: pendingInvitationCount > 0,
    pendingInvitationCount,
  };
}

function assertConsistentExistingOwner(
  owner: FirebaseFirestore.DocumentSnapshot,
  profile: FirebaseFirestore.DocumentSnapshot,
  business: FirebaseFirestore.DocumentSnapshot,
  membership: FirebaseFirestore.DocumentSnapshot,
  consent: FirebaseFirestore.DocumentSnapshot,
  audit: FirebaseFirestore.DocumentSnapshot,
  identity: Identity,
): string {
  const businessId = owner.get("businessId");
  const acceptanceId = owner.get("consentAcceptanceId");
  const requestId = owner.get("provisioningRequestId");
  if (
    typeof businessId !== "string" ||
    typeof acceptanceId !== "string" ||
    typeof requestId !== "string" ||
    owner.get("uid") !== identity.uid ||
    owner.get("email") !== identity.email ||
    !profile.exists ||
    profile.get("businessId") !== businessId ||
    profile.get("uid") !== identity.uid ||
    !business.exists ||
    business.get("businessId") !== businessId ||
    business.get("ownerId") !== identity.uid ||
    !membership.exists ||
    membership.get("uid") !== identity.uid ||
    membership.get("businessId") !== businessId ||
    membership.get("role") !== "head" ||
    membership.get("status") !== "active" ||
    !consent.exists ||
    consent.get("uid") !== identity.uid ||
    consent.get("acceptanceId") !== acceptanceId ||
    consent.get("requestId") !== requestId ||
    !audit.exists ||
    audit.get("businessId") !== businessId ||
    audit.get("actorId") !== identity.uid ||
    audit.get("action") !== "agencyOwnerProvisioned" ||
    audit.get("entityId") !== businessId ||
    audit.get("provisioningRequestId") !== requestId
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Existing agency provisioning is inconsistent. Contact support.",
    );
  }
  return businessId;
}

async function existingOwnerIsConsistent(
  firestore: Firestore,
  state: Awaited<ReturnType<typeof identityState>>,
  identity: Identity,
): Promise<boolean> {
  const businessId = state.owner.get("businessId");
  const acceptanceId = state.owner.get("consentAcceptanceId");
  if (typeof businessId !== "string" || typeof acceptanceId !== "string") {
    return false;
  }
  const [business, membership, consent, audit] = await Promise.all([
    firestore.doc(`businesses/${businessId}`).get(),
    firestore.doc(`businesses/${businessId}/members/${identity.uid}`).get(),
    firestore.doc(
      `userConsents/${identity.uid}/acceptances/${acceptanceId}`,
    ).get(),
    firestore.doc(
      `businesses/${businessId}/auditRecords/agencyProvisioned-${identity.uid}`,
    ).get(),
  ]);
  try {
    assertConsistentExistingOwner(
      state.owner,
      state.profile,
      business,
      membership,
      consent,
      audit,
      identity,
    );
    return true;
  } catch (error) {
    if (error instanceof HttpsError) return false;
    throw error;
  }
}

export async function provisionAgencyOwnerHandler(
  request: CallableRequest<unknown>,
) {
  const identity = await requireVerifiedIdentity(request);
  const firestore = getFirestore();
  await enforceUidRateLimit(
    firestore,
    identity.uid,
    "provision",
    provisionRateLimit,
  );
  const input = parseProvisionAgencyOwnerRequest(request.data);

  const businessReference = firestore.collection("businesses").doc();
  const result = await firestore.runTransaction(async (transaction) => {
    const ownerReference = firestore.doc(`agencyOwners/${identity.uid}`);
    const profileReference = firestore.doc(`userProfiles/${identity.uid}`);
    const membersQuery = firestore
      .collectionGroup("members")
      .where("uid", "==", identity.uid)
      .limit(2);
    const invitationsQuery = firestore
      .collectionGroup("invitations")
      .where("email", "==", identity.email);
    const businessesQuery = firestore
      .collection("businesses")
      .where("ownerId", "==", identity.uid)
      .limit(2);

    const owner = await transaction.get(ownerReference);
    const profile = await transaction.get(profileReference);
    const members = await transaction.get(membersQuery);
    const invitations = await transaction.get(invitationsQuery);
    const businesses = await transaction.get(businessesQuery);

    if (owner.exists) {
      const businessId = owner.get("businessId");
      if (typeof businessId !== "string") {
        throw new HttpsError(
          "failed-precondition",
          "Existing agency provisioning is inconsistent. Contact support.",
        );
      }
      const business = await transaction.get(
        firestore.doc(`businesses/${businessId}`),
      );
      const membership = await transaction.get(
        firestore.doc(`businesses/${businessId}/members/${identity.uid}`),
      );
      const acceptanceId = owner.get("consentAcceptanceId");
      if (typeof acceptanceId !== "string") {
        throw new HttpsError(
          "failed-precondition",
          "Existing agency provisioning is inconsistent. Contact support.",
        );
      }
      const consent = await transaction.get(
        firestore.doc(
          `userConsents/${identity.uid}/acceptances/${acceptanceId}`,
        ),
      );
      const audit = await transaction.get(
        firestore.doc(
          `businesses/${businessId}/auditRecords/agencyProvisioned-${identity.uid}`,
        ),
      );
      return {
        businessId: assertConsistentExistingOwner(
          owner,
          profile,
          business,
          membership,
          consent,
          audit,
          identity,
        ),
        alreadyProvisioned: true,
      };
    }

    const conflictReason = legacyConflictReason({
      owner,
      profile,
      members,
      invitations,
      businesses,
    });
    if (conflictReason) {
      throw new HttpsError(
        "failed-precondition",
        `Owner registration conflicts with trusted account state: ${conflictReason}.`,
      );
    }

    const businessId = businessReference.id;
    const membershipReference = firestore.doc(
      `businesses/${businessId}/members/${identity.uid}`,
    );
    const consentReference = firestore.doc(
      `userConsents/${identity.uid}/acceptances/${consentAcceptanceId}`,
    );
    const auditReference = firestore.doc(
      `businesses/${businessId}/auditRecords/agencyProvisioned-${identity.uid}`,
    );
    const subscriptionReference = firestore.doc(
      `businesses/${businessId}/subscription/saas`,
    );
    const [business, membership, consent, audit, subscription] = await Promise.all([
      transaction.get(businessReference),
      transaction.get(membershipReference),
      transaction.get(consentReference),
      transaction.get(auditReference),
      transaction.get(subscriptionReference),
    ]);
    if (business.exists || membership.exists || consent.exists || audit.exists || subscription.exists) {
      throw new HttpsError(
        "failed-precondition",
        "A target provisioning record already exists unexpectedly.",
      );
    }

    const now = FieldValue.serverTimestamp();
    const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;
    const nowMs = Timestamp.now().toMillis();
    const trialStartsAt = Timestamp.fromMillis(nowMs);
    const trialEndsAt = Timestamp.fromMillis(nowMs + thirtyDaysMs);

    transaction.create(businessReference, {
      businessId,
      ownerId: identity.uid,
      name: input.agencyName,
      phone: input.agencyPhone,
      address: input.agencyAddress,
      createdAt: now,
      updatedAt: now,
    });
    transaction.create(subscriptionReference, {
      businessId,
      planId: "trial",
      status: "trial",
      trialStartsAt,
      trialEndsAt,
      graceDays: 7,
      customerLimit: 500,
      employeeLimit: 10,
      createdAt: now,
      updatedAt: now,
    });
    transaction.create(membershipReference, {
      businessId,
      uid: identity.uid,
      email: identity.email,
      displayName: input.ownerDisplayName,
      phone: input.ownerPhone,
      role: "head",
      status: "active",
      permissions: [],
      areaIds: [],
      createdAt: now,
      updatedAt: now,
    });
    transaction.create(profileReference, {
      uid: identity.uid,
      email: identity.email,
      displayName: input.ownerDisplayName,
      phone: input.ownerPhone,
      businessId,
      role: "head",
      status: "active",
      permissions: [],
      createdAt: now,
      updatedAt: now,
    });
    transaction.create(ownerReference, {
      uid: identity.uid,
      businessId,
      email: identity.email,
      consentAcceptanceId,
      provisioningRequestId: input.requestId,
      provisioningVersion: 1,
      createdAt: now,
    });
    transaction.create(consentReference, {
      uid: identity.uid,
      acceptanceId: consentAcceptanceId,
      termsVersion: input.termsVersion,
      termsDocumentPath: legalDocuments.terms.assetPath,
      termsSha256: legalDocuments.terms.sha256,
      privacyVersion: input.privacyVersion,
      privacyDocumentPath: legalDocuments.privacy.assetPath,
      privacySha256: legalDocuments.privacy.sha256,
      locale: input.locale,
      clientPlatform: input.clientPlatform,
      requestId: input.requestId,
      acceptedAt: now,
    });
    transaction.create(auditReference, {
      businessId,
      actorId: identity.uid,
      action: "agencyOwnerProvisioned",
      entityType: "business",
      entityId: businessId,
      provisioningRequestId: input.requestId,
      provisioningVersion: 1,
      createdAt: now,
    });
    return {businessId, alreadyProvisioned: false};
  });

  logger.info("Agency owner provisioning completed.", {
    uidHash: createHash("sha256").update(identity.uid).digest("hex").slice(0, 16),
    businessId: result.businessId,
    alreadyProvisioned: result.alreadyProvisioned,
  });
  return result;
}
