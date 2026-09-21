import {
  DocumentReference,
  Firestore,
  Timestamp,
} from "firebase-admin/firestore";
import {createHash} from "node:crypto";
import {logger} from "firebase-functions";
import {HttpsError} from "firebase-functions/v2/https";

interface RateLimit {
  maximumAttempts: number;
  windowMilliseconds: number;
  cooldownMilliseconds: number;
}

export async function enforceUidRateLimit(
  firestore: Firestore,
  uid: string,
  kind: "options" | "provision",
  limit: RateLimit,
): Promise<void> {
  const reference = firestore.doc(`agencyProvisioningControls/${uid}`);
  const exceeded = await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const now = Timestamp.now();
    const prefix = kind === "options" ? "options" : "provision";
    const data = snapshot.data() ?? {};
    const cooldownUntil = data[`${prefix}CooldownUntil`];
    if (cooldownUntil instanceof Timestamp && cooldownUntil.toMillis() > now.toMillis()) {
      const retryAfterSeconds = Math.ceil(
        (cooldownUntil.toMillis() - now.toMillis()) / 1000,
      );
      return retryAfterSeconds;
    }

    const windowStartedAt = data[`${prefix}WindowStartedAt`];
    const inWindow =
      windowStartedAt instanceof Timestamp &&
      now.toMillis() - windowStartedAt.toMillis() < limit.windowMilliseconds;
    const previousCount = inWindow ? Number(data[`${prefix}AttemptCount`] ?? 0) : 0;
    const attemptCount = previousCount + 1;
    const update: Record<string, unknown> = {
      uid,
      [`${prefix}WindowStartedAt`]: inWindow ? windowStartedAt : now,
      [`${prefix}AttemptCount`]: attemptCount,
      updatedAt: now,
    };
    if (attemptCount > limit.maximumAttempts) {
      const nextCooldown = Timestamp.fromMillis(
        now.toMillis() + limit.cooldownMilliseconds,
      );
      update[`${prefix}CooldownUntil`] = nextCooldown;
      transaction.set(reference, update, {merge: true});
      return Math.ceil(limit.cooldownMilliseconds / 1000);
    }
    transaction.set(reference, update, {merge: true});
    return null;
  });
  if (exceeded != null) {
    logger.warn("Agency provisioning rate limit exceeded.", {
      uidHash: createHash("sha256").update(uid).digest("hex").slice(0, 16),
      operation: kind,
      retryAfterSeconds: exceeded,
    });
    throw new HttpsError(
      "resource-exhausted",
      `Too many attempts. Retry after ${exceeded} seconds.`,
      {retryAfterSeconds: exceeded},
    );
  }
}

export function rateLimitReference(
  firestore: Firestore,
  uid: string,
): DocumentReference {
  return firestore.doc(`agencyProvisioningControls/${uid}`);
}
