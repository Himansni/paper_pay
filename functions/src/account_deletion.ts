import {getAuth} from "firebase-admin/auth";
import {createHash} from "node:crypto";
import {
  FieldValue,
  Firestore,
  getFirestore,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {CallableRequest, HttpsError} from "firebase-functions/v2/https";
import {deletionRateLimit} from "./environment";
import {enforceUidRateLimit} from "./rate_limit";
import {
  AccountDeletionResult,
  parseRequestAccountDeletionInput,
} from "./account_deletion_contract";

interface VerifiedIdentity {
  uid: string;
  email: string;
}

async function requireVerifiedDeletionIdentity(
  request: CallableRequest<unknown>,
): Promise<VerifiedIdentity> {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Sign in before requesting account deletion.",
    );
  }

  const authTime = request.auth.token.auth_time;
  if (typeof authTime !== "number") {
    throw new HttpsError(
      "failed-precondition",
      "Recent authentication required. Please re-authenticate before deleting your account.",
    );
  }
  const ageSeconds = Math.floor(Date.now() / 1000) - authTime;
  if (ageSeconds > 15 * 60) {
    throw new HttpsError(
      "failed-precondition",
      "Recent authentication required. Please re-authenticate before deleting your account.",
    );
  }

  const uid = request.auth.uid;
  let user;
  try {
    user = await getAuth().getUser(uid);
  } catch (error: unknown) {
    const errorCode = (error as {code?: string})?.code;
    if (errorCode === "auth/user-not-found") {
      throw new HttpsError("not-found", "User account not found.");
    }
    throw error;
  }

  const email = user.email?.trim().toLowerCase();
  if (!user.emailVerified || !email) {
    throw new HttpsError(
      "failed-precondition",
      "Verify the account email before requesting account deletion.",
    );
  }

  return {uid, email};
}

function computeAnonymizedHash(uid: string): string {
  return createHash("sha256").update(uid).digest("hex").slice(0, 12);
}

export async function requestAccountDeletionHandler(
  request: CallableRequest<unknown>,
): Promise<AccountDeletionResult> {
  const identity = await requireVerifiedDeletionIdentity(request);
  const firestore = getFirestore();

  await enforceUidRateLimit(
    firestore,
    identity.uid,
    "deletion",
    deletionRateLimit,
  );

  const input = parseRequestAccountDeletionInput(request.data);
  const anonymizedHash = computeAnonymizedHash(identity.uid);
  const now = FieldValue.serverTimestamp();

  // Inspect existing records linked to this UID
  const ownerReference = firestore.doc(`agencyOwners/${identity.uid}`);
  const profileReference = firestore.doc(`userProfiles/${identity.uid}`);
  const membersQuery = firestore
    .collectionGroup("members")
    .where("uid", "==", identity.uid)
    .limit(2);
  const businessesQuery = firestore
    .collection("businesses")
    .where("ownerId", "==", identity.uid)
    .limit(2);

  const [owner, profile, members, businesses] = await Promise.all([
    ownerReference.get(),
    profileReference.get(),
    membersQuery.get(),
    businessesQuery.get(),
  ]);

  const isHead = owner.exists ||
    !businesses.empty ||
    members.docs.some((doc) => doc.data().role === "head");

  if (isHead) {
    const businessId = owner.get("businessId") ||
      businesses.docs[0]?.id ||
      members.docs.find((doc) => doc.data().role === "head")?.data().businessId;

    if (!businessId || typeof businessId !== "string") {
      throw new HttpsError(
        "failed-precondition",
        "Could not determine business ownership for this account.",
      );
    }

    const businessReference = firestore.doc(`businesses/${businessId}`);
    const businessSnapshot = await businessReference.get();
    const businessStatus = businessSnapshot.get("status");

    // Check if the business was already closed idempotently
    if (businessStatus === "closed") {
      try {
        await getAuth().deleteUser(identity.uid);
      } catch (error: unknown) {
        const code = (error as {code?: string})?.code;
        if (code !== "auth/user-not-found") throw error;
      }
      return {
        success: true,
        status: "deleted",
        role: "head",
        businessId,
        message: "Agency was already closed and account has been removed.",
      };
    }

    // Check for active employees
    const activeEmployeesSnapshot = await firestore
      .collection(`businesses/${businessId}/members`)
      .where("status", "==", "active")
      .where("role", "==", "employee")
      .limit(5)
      .get();

    if (!activeEmployeesSnapshot.empty) {
      await firestore.doc(`accountDeletionRequests/${identity.uid}`).set({
        uid: identity.uid,
        role: "head",
        businessId,
        status: "blocked_active_employees",
        activeEmployeesCount: activeEmployeesSnapshot.size,
        reason: input.reason ?? null,
        requestedAt: now,
      }, {merge: true});

      throw new HttpsError(
        "failed-precondition",
        `Cannot delete agency account while ${activeEmployeesSnapshot.size} active employee(s) remain. Remove all employees before closing the agency.`,
      );
    }

    // Check for active customers (status == 'active' or archived == false)
    const [activeByStatus, activeByArchived] = await Promise.all([
      firestore
        .collection(`businesses/${businessId}/customers`)
        .where("status", "==", "active")
        .limit(5)
        .get(),
      firestore
        .collection(`businesses/${businessId}/customers`)
        .where("archived", "==", false)
        .limit(5)
        .get(),
    ]);

    const activeCustomersCount = activeByStatus.size || activeByArchived.size;
    if (activeCustomersCount > 0) {
      await firestore.doc(`accountDeletionRequests/${identity.uid}`).set({
        uid: identity.uid,
        role: "head",
        businessId,
        status: "blocked_active_customers",
        activeCustomersCount,
        reason: input.reason ?? null,
        requestedAt: now,
      }, {merge: true});

      throw new HttpsError(
        "failed-precondition",
        "Cannot delete agency account while active customer routes exist. Archive all customers before closing the agency.",
      );
    }

    // Agency has no active employees and no active customers: proceed with closure
    const batch = firestore.batch();

    // Revoke any pending invitations and anonymize owner invitations
    const pendingInvites = await firestore
      .collection(`businesses/${businessId}/invitations`)
      .where("status", "==", "pending")
      .get();
    for (const inviteDoc of pendingInvites.docs) {
      batch.update(inviteDoc.ref, {
        status: "revoked",
        revokedAt: now,
        revocationReason: "Agency closed by owner",
      });
    }

    const ownerInvites = await firestore
      .collection(`businesses/${businessId}/invitations`)
      .where("email", "==", identity.email)
      .get();
    for (const inviteDoc of ownerInvites.docs) {
      batch.update(inviteDoc.ref, {
        email: `deleted-${anonymizedHash}@deleted.paperroute.local`,
        updatedAt: now,
      });
    }

    // Archive active delivery areas
    const activeAreas = await firestore
      .collection(`businesses/${businessId}/areas`)
      .where("status", "==", "active")
      .get();
    for (const areaDoc of activeAreas.docs) {
      batch.update(areaDoc.ref, {
        status: "archived",
        archivedAt: now,
      });
    }

    batch.update(businessReference, {
      status: "closed",
      phone: "",
      closedAt: now,
      closedBy: identity.uid,
      updatedAt: now,
    });

    const memberReference = firestore.doc(
      `businesses/${businessId}/members/${identity.uid}`,
    );
    batch.set(memberReference, {
      status: "closed",
      displayName: "Former Owner",
      email: `deleted-${anonymizedHash}@deleted.paperroute.local`,
      phone: "",
      closedAt: now,
      updatedAt: now,
    }, {merge: true});

    if (profile.exists) {
      batch.update(profileReference, {
        status: "deleted",
        displayName: "Former Owner",
        email: `deleted-${anonymizedHash}@deleted.paperroute.local`,
        phone: "",
        businessId: null,
        updatedAt: now,
      });
    }

    if (owner.exists) {
      batch.update(ownerReference, {
        status: "closed",
        email: `deleted-${anonymizedHash}@deleted.paperroute.local`,
        closedAt: now,
        updatedAt: now,
      });
    }

    const auditReference = firestore
      .collection(`businesses/${businessId}/auditRecords`)
      .doc();
    batch.set(auditReference, {
      businessId,
      actorId: identity.uid,
      action: "agencyClosedAndOwnerDeleted",
      entityType: "business",
      entityId: businessId,
      createdAt: now,
    });

    batch.set(firestore.doc(`accountDeletionRequests/${identity.uid}`), {
      uid: identity.uid,
      role: "head",
      businessId,
      status: "completed",
      reason: input.reason ?? null,
      completedAt: now,
    });

    await batch.commit();

    try {
      await getAuth().deleteUser(identity.uid);
    } catch (error: unknown) {
      const code = (error as {code?: string})?.code;
      if (code !== "auth/user-not-found") throw error;
    }

    logger.info("Agency closed and owner account deleted.", {
      uidHash: anonymizedHash,
      businessId,
      role: "head",
    });

    return {
      success: true,
      status: "deleted",
      role: "head",
      businessId,
      message: "Agency closed and owner account deleted successfully.",
    };
  }

  // Check if Employee
  const employeeMember = members.docs.find(
    (doc) => doc.data().role === "employee",
  );

  if (employeeMember) {
    const businessId = employeeMember.data().businessId;
    const batch = firestore.batch();

    batch.update(employeeMember.ref, {
      status: "removed",
      displayName: "Former Employee",
      email: `deleted-${anonymizedHash}@deleted.paperroute.local`,
      phone: "",
      permissions: [],
      areaIds: [],
      deletedAt: now,
      updatedAt: now,
    });

    if (profile.exists) {
      batch.update(profileReference, {
        status: "deleted",
        displayName: "Former Employee",
        email: `deleted-${anonymizedHash}@deleted.paperroute.local`,
        phone: "",
        businessId: null,
        updatedAt: now,
      });
    }

    // Anonymize any invitations referencing this employee's email
    const employeeInvites = await firestore
      .collection(`businesses/${businessId}/invitations`)
      .where("email", "==", identity.email)
      .get();
    for (const inviteDoc of employeeInvites.docs) {
      batch.update(inviteDoc.ref, {
        email: `deleted-${anonymizedHash}@deleted.paperroute.local`,
        updatedAt: now,
      });
    }

    const auditReference = firestore
      .collection(`businesses/${businessId}/auditRecords`)
      .doc();
    batch.set(auditReference, {
      businessId,
      actorId: identity.uid,
      action: "employeeAccountDeleted",
      entityType: "member",
      entityId: identity.uid,
      createdAt: now,
    });

    batch.set(firestore.doc(`accountDeletionRequests/${identity.uid}`), {
      uid: identity.uid,
      role: "employee",
      businessId,
      status: "completed",
      reason: input.reason ?? null,
      completedAt: now,
    });

    await batch.commit();

    try {
      await getAuth().deleteUser(identity.uid);
    } catch (error: unknown) {
      const code = (error as {code?: string})?.code;
      if (code !== "auth/user-not-found") throw error;
    }

    logger.info("Employee account deleted and personal details removed.", {
      uidHash: anonymizedHash,
      businessId,
      role: "employee",
    });

    return {
      success: true,
      status: "deleted",
      role: "employee",
      businessId,
      message: "Employee account and personal details deleted successfully.",
    };
  }

  // Unassigned user (no agency ownership, no employee membership)
  if (profile.exists) {
    await profileReference.delete();
  }

  await firestore.doc(`accountDeletionRequests/${identity.uid}`).set({
    uid: identity.uid,
    role: "unassigned",
    status: "completed",
    reason: input.reason ?? null,
    completedAt: now,
  });

  try {
    await getAuth().deleteUser(identity.uid);
  } catch (error: unknown) {
    const code = (error as {code?: string})?.code;
    if (code !== "auth/user-not-found") throw error;
  }

  logger.info("Unassigned account deleted.", {
    uidHash: anonymizedHash,
    role: "unassigned",
  });

  return {
    success: true,
    status: "deleted",
    role: "unassigned",
    message: "Account deleted successfully.",
  };
}
