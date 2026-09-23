import {Firestore, getFirestore, Timestamp} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {
  evaluateAgencySubscriptionState,
  getSaasActivationDate,
} from "./saas_subscription_service";

export interface MigrationSummary {
  totalAgencies: number;
  updatedCount: number;
  skippedCount: number;
  details: Array<{
    businessId: string;
    status: string;
    action: "created" | "updated" | "skipped";
    effectiveExpiresAt: string;
  }>;
}

/**
 * Safely backfills all agencies in Firestore with a compliant `subscription/saas`
 * document and `effectiveExpiresAt` timestamp before strict default-deny rules
 * are enabled.
 *
 * Migration guarantees:
 * 1. Fully idempotent: running multiple times does not alter established timestamps.
 * 2. Pre-launch legacy agencies receive their trial anchored to `activationDate`.
 * 3. Pre-existing trials or active paid subscriptions are strictly preserved.
 */
export async function migrateAllAgencySubscriptions(
  db: Firestore = getFirestore(),
  customActivationDate?: Date | string,
  now: Date = new Date(),
): Promise<MigrationSummary> {
  const activationDate = getSaasActivationDate(customActivationDate);
  logger.info("Starting agency SaaS subscription migration", {
    activationDate: activationDate.toISOString(),
    now: now.toISOString(),
  });

  const businessesSnap = await db.collection("businesses").get();
  const summary: MigrationSummary = {
    totalAgencies: businessesSnap.size,
    updatedCount: 0,
    skippedCount: 0,
    details: [],
  };

  for (const bizDoc of businessesSnap.docs) {
    const businessId = bizDoc.id;
    const bizData = bizDoc.data();
    
    // Resolve createdAt
    let businessCreatedAt: Date;
    if (bizData.createdAt instanceof Timestamp) {
      businessCreatedAt = bizData.createdAt.toDate();
    } else if (bizData.createdAt && typeof bizData.createdAt.toDate === "function") {
      businessCreatedAt = bizData.createdAt.toDate();
    } else if (typeof bizData.createdAt === "string") {
      businessCreatedAt = new Date(bizData.createdAt);
    } else {
      businessCreatedAt = now;
    }

    const subRef = db.doc(`businesses/${businessId}/subscription/saas`);
    const subSnap = await subRef.get();

    if (subSnap.exists) {
      const existingData = subSnap.data() || {};
      const hasValidExpiresAt =
        existingData.effectiveExpiresAt instanceof Timestamp ||
        (existingData.effectiveExpiresAt && typeof existingData.effectiveExpiresAt.toDate === "function");

      if (hasValidExpiresAt && existingData.status && existingData.trialStartsAt) {
        // Already fully migrated and compliant — skip
        summary.skippedCount++;
        const expiresAtDate = existingData.effectiveExpiresAt.toDate();
        summary.details.push({
          businessId,
          status: existingData.status,
          action: "skipped",
          effectiveExpiresAt: expiresAtDate.toISOString(),
        });
        continue;
      }

      // Existing doc is missing effectiveExpiresAt — compute and patch
      const existingTrialStarts = existingData.trialStartsAt instanceof Timestamp
        ? existingData.trialStartsAt.toDate()
        : (existingData.trialStartsAt ? new Date(existingData.trialStartsAt) : undefined);
      const existingTrialEnds = existingData.trialEndsAt instanceof Timestamp
        ? existingData.trialEndsAt.toDate()
        : (existingData.trialEndsAt ? new Date(existingData.trialEndsAt) : undefined);
      const currentPeriodStarts = existingData.currentPeriodStartsAt instanceof Timestamp
        ? existingData.currentPeriodStartsAt.toDate()
        : (existingData.currentPeriodStartsAt ? new Date(existingData.currentPeriodStartsAt) : undefined);
      const currentPeriodEnds = existingData.currentPeriodEndsAt instanceof Timestamp
        ? existingData.currentPeriodEndsAt.toDate()
        : (existingData.currentPeriodEndsAt ? new Date(existingData.currentPeriodEndsAt) : undefined);

      const computed = evaluateAgencySubscriptionState(
        businessId,
        businessCreatedAt,
        {
          planId: existingData.planId,
          status: existingData.status,
          trialStartsAt: existingTrialStarts,
          trialEndsAt: existingTrialEnds,
          currentPeriodStartsAt: currentPeriodStarts,
          currentPeriodEndsAt: currentPeriodEnds,
          graceDays: existingData.graceDays,
          customerLimit: existingData.customerLimit,
          employeeLimit: existingData.employeeLimit,
        },
        now,
        activationDate,
      );

      await subRef.set(
        {
          businessId,
          planId: computed.planId,
          status: computed.status,
          trialStartsAt: Timestamp.fromDate(computed.trialStartsAt),
          trialEndsAt: Timestamp.fromDate(computed.trialEndsAt),
          graceDays: computed.graceDays,
          customerLimit: computed.customerLimit,
          employeeLimit: computed.employeeLimit,
          effectiveExpiresAt: Timestamp.fromDate(computed.effectiveExpiresAt),
          updatedAt: Timestamp.fromDate(now),
        },
        {merge: true},
      );

      summary.updatedCount++;
      summary.details.push({
        businessId,
        status: computed.status,
        action: "updated",
        effectiveExpiresAt: computed.effectiveExpiresAt.toISOString(),
      });
    } else {
      // Document does not exist at all — create initial trial subscription
      const computed = evaluateAgencySubscriptionState(
        businessId,
        businessCreatedAt,
        undefined,
        now,
        activationDate,
      );

      await subRef.set({
        businessId,
        planId: computed.planId,
        status: computed.status,
        trialStartsAt: Timestamp.fromDate(computed.trialStartsAt),
        trialEndsAt: Timestamp.fromDate(computed.trialEndsAt),
        graceDays: computed.graceDays,
        customerLimit: computed.customerLimit,
        employeeLimit: computed.employeeLimit,
        effectiveExpiresAt: Timestamp.fromDate(computed.effectiveExpiresAt),
        createdAt: Timestamp.fromDate(now),
        updatedAt: Timestamp.fromDate(now),
      });

      summary.updatedCount++;
      summary.details.push({
        businessId,
        status: computed.status,
        action: "created",
        effectiveExpiresAt: computed.effectiveExpiresAt.toISOString(),
      });
    }
  }

  logger.info("Migration completed", {
    total: summary.totalAgencies,
    updated: summary.updatedCount,
    skipped: summary.skippedCount,
  });

  return summary;
}
