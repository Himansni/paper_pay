import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {Request, Response} from "firebase-functions/v2/https";
import {evaluateAgencySubscriptionState, verifyWebhookSignature} from "./saas_subscription_service";

// ---------------------------------------------------------------------------
// Razorpay webhook payload types
// ---------------------------------------------------------------------------

export interface RazorpaySubscriptionEntity {
  id: string;
  plan_id?: string;
  status?: string;
  /** Unix timestamp (seconds) */
  current_start?: number;
  /** Unix timestamp (seconds) */
  current_end?: number;
  notes?: Record<string, string>;
}

export interface RazorpayWebhookPayload {
  entity?: "event";
  event?: string;
  /** Razorpay-assigned unique event ID */
  id?: string;
  /** Unix timestamp (seconds) when the event was created on Razorpay */
  created_at?: number;
  payload?: {
    subscription?: {
      entity?: RazorpaySubscriptionEntity;
    };
    payment?: {
      entity?: {
        id?: string;
        amount?: number;
        currency?: string;
        status?: string;
        order_id?: string;
        notes?: Record<string, string>;
      };
    };
  };
}

// ---------------------------------------------------------------------------
// Subscription state derivation from a Razorpay event
// ---------------------------------------------------------------------------

export interface SubscriptionUpdate {
  planId: string;
  status: "trial" | "active" | "gracePeriod" | "expired";
  currentPeriodStartsAt?: Timestamp;
  currentPeriodEndsAt?: Timestamp;
  graceDays: number;
  customerLimit: number;
  employeeLimit: number;
  effectiveExpiresAt: Timestamp;
  razorpaySubscriptionId: string;
  lastPaymentReference?: string;
}

export const APPROVED_PLAN_LIMITS: Record<string, {customerLimit: number; employeeLimit: number}> = {
  starter: {customerLimit: 300, employeeLimit: 3},
  growth: {customerLimit: 1000, employeeLimit: 10},
  agencyPro: {customerLimit: 10000, employeeLimit: 100},
};

/** Maps a Razorpay plan_id (e.g. "plan_growth_monthly", "growth", "plan_agencypro_annual") to internal planId. */
export function resolveInternalPlanId(razorpayPlanId?: string): string {
  if (!razorpayPlanId) return "starter";
  const lower = razorpayPlanId.toLowerCase();
  if (lower.includes("agencypro") || lower.includes("agency_pro") || lower.includes("agency-pro")) {
    return "agencyPro";
  }
  if (lower.includes("growth")) {
    return "growth";
  }
  if (lower.includes("starter")) {
    return "starter";
  }
  return "starter";
}

/**
 * Derives the Firestore subscription update from a Razorpay webhook event.
 * Returns null for events that require no subscription state change.
 */
export function deriveSubscriptionUpdate(
  event: string,
  entity: RazorpaySubscriptionEntity,
  now: Date = new Date(),
): SubscriptionUpdate | null {
  const planId = resolveInternalPlanId(entity.plan_id);
  const limits = APPROVED_PLAN_LIMITS[planId] ?? APPROVED_PLAN_LIMITS.starter;
  const graceDays = 7;
  const graceDurationMs = graceDays * 24 * 60 * 60 * 1000;
  const razorpaySubscriptionId = entity.id;

  switch (event) {
    case "subscription.activated":
    case "subscription.charged": {
      const periodStart = entity.current_start
        ? new Date(entity.current_start * 1000)
        : now;
      const periodEnd = entity.current_end
        ? new Date(entity.current_end * 1000)
        : new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
      const effectiveExpiry = new Date(periodEnd.getTime() + graceDurationMs);
      return {
        planId,
        status: "active",
        currentPeriodStartsAt: Timestamp.fromDate(periodStart),
        currentPeriodEndsAt: Timestamp.fromDate(periodEnd),
        graceDays,
        customerLimit: limits.customerLimit,
        employeeLimit: limits.employeeLimit,
        effectiveExpiresAt: Timestamp.fromDate(effectiveExpiry),
        razorpaySubscriptionId,
      };
    }

    case "subscription.halted":
    case "payment.failed": {
      // Payment failed: begin grace period. effectiveExpiresAt = now + graceDays.
      const graceEnd = new Date(now.getTime() + graceDurationMs);
      return {
        planId,
        status: "gracePeriod",
        graceDays,
        customerLimit: limits.customerLimit,
        employeeLimit: limits.employeeLimit,
        effectiveExpiresAt: Timestamp.fromDate(graceEnd),
        razorpaySubscriptionId,
      };
    }

    case "subscription.cancelled":
    case "subscription.completed": {
      // Expired: effectiveExpiresAt set to epoch (always in the past) so the
      // Firestore rules gate immediately blocks operational writes.
      return {
        planId,
        status: "expired",
        graceDays,
        customerLimit: limits.customerLimit,
        employeeLimit: limits.employeeLimit,
        effectiveExpiresAt: Timestamp.fromMillis(0),
        razorpaySubscriptionId,
      };
    }

    default:
      return null;
  }
}

// ---------------------------------------------------------------------------
// HTTP handler
// ---------------------------------------------------------------------------

/**
 * Razorpay webhook HTTP handler.
 *
 * URL: POST /razorpayWebhook
 * Auth: verified via X-Razorpay-Signature HMAC-SHA256 header.
 *
 * Idempotency: Persisted in durable `businesses/{businessId}/saasWebhookEvents/{eventId}` collection.
 * Uses `x-razorpay-event-id` header (fallback to body `id`).
 *
 * Out-of-order protection: Checks event timestamp against lastProcessedEventTimestamp
 * and ensures newer active subscription periods are never downgraded by stale events.
 */
export async function razorpayWebhookHandler(
  request: Request,
  response: Response,
): Promise<void> {
  // 1. Collect raw body for HMAC verification.
  const rawBody: string =
    typeof request.rawBody === "object" && Buffer.isBuffer(request.rawBody)
      ? request.rawBody.toString("utf8")
      : typeof request.body === "string"
        ? request.body
        : JSON.stringify(request.body);

  const signature = request.headers["x-razorpay-signature"];
  if (typeof signature !== "string") {
    logger.warn("Razorpay webhook: missing X-Razorpay-Signature header.");
    response.status(400).json({error: "Missing X-Razorpay-Signature header."});
    return;
  }

  const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET ?? "";
  if (!webhookSecret) {
    logger.error("Razorpay webhook: RAZORPAY_WEBHOOK_SECRET environment variable not configured.");
    response.status(500).json({error: "Webhook secret not configured."});
    return;
  }

  // 2. Verify HMAC SHA-256 signature.
  if (!verifyWebhookSignature(rawBody, webhookSecret, signature)) {
    logger.warn("Razorpay webhook: signature verification failed.");
    response.status(400).json({error: "Invalid webhook signature."});
    return;
  }

  // 3. Parse payload.
  let webhookPayload: RazorpayWebhookPayload;
  try {
    webhookPayload = JSON.parse(rawBody) as RazorpayWebhookPayload;
  } catch {
    logger.warn("Razorpay webhook: invalid JSON body.");
    response.status(400).json({error: "Invalid JSON payload."});
    return;
  }

  const event = webhookPayload.event;
  // Use documented x-razorpay-event-id header with fallback to body id
  const headerEventId = request.headers["x-razorpay-event-id"];
  const eventId = (typeof headerEventId === "string" && headerEventId.length > 0)
    ? headerEventId
    : webhookPayload.id;

  if (!eventId) {
    logger.warn("Razorpay webhook: missing event ID.");
    response.status(400).json({error: "Missing event ID."});
    return;
  }

  const subscriptionEntity = webhookPayload.payload?.subscription?.entity;
  if (!event || !subscriptionEntity) {
    logger.info("Razorpay webhook: unrecognised or non-subscription event shape, ignored.", {event});
    response.status(200).json({status: "ignored"});
    return;
  }

  // 4. Extract and validate businessId from notes.
  const businessId = subscriptionEntity.notes?.businessId;
  if (!businessId) {
    logger.warn("Razorpay webhook: missing businessId in subscription notes.", {event, eventId});
    response.status(400).json({error: "Missing businessId in subscription notes."});
    return;
  }

  // 5. Derive subscription update.
  const now = new Date();
  const update = deriveSubscriptionUpdate(event, subscriptionEntity, now);
  if (!update) {
    logger.info("Razorpay webhook: unhandled subscription event, acknowledged.", {event, businessId});
    response.status(200).json({status: "acknowledged", event});
    return;
  }

  const eventTimestamp = webhookPayload.created_at
    ? new Date(webhookPayload.created_at * 1000)
    : now;

  const firestore = getFirestore();
  const subRef = firestore.doc(`businesses/${businessId}/subscription/saas`);
  const idempotencyRef = firestore.doc(`businesses/${businessId}/saasWebhookEvents/${eventId}`);
  const auditRef = firestore.collection(`businesses/${businessId}/auditRecords`).doc();

  try {
    let alreadyProcessed = false;

    await firestore.runTransaction(async (tx) => {
      // 6. Durable Idempotency Check
      const eventSnap = await tx.get(idempotencyRef);
      if (eventSnap.exists) {
        logger.info("Razorpay webhook: duplicate event in durable collection, skipping.", {eventId, businessId});
        alreadyProcessed = true;
        return;
      }

      const subSnap = await tx.get(subRef);
      const nowTs = Timestamp.fromDate(now);
      const eventTs = Timestamp.fromDate(eventTimestamp);

      // 7. Out-of-Order & Stale Event Protection
      if (subSnap.exists) {
        const existingData = subSnap.data()!;
        const lastEventTs = existingData.lastProcessedEventTimestamp as Timestamp | undefined;
        
        // If an event is older than the latest processed event timestamp, check for stale state downgrade
        if (lastEventTs && eventTimestamp.getTime() < lastEventTs.toDate().getTime()) {
          // Stale cancel/halt event arriving after a newer renewal: protect active subscription
          if (existingData.status === "active" && (update.status === "expired" || update.status === "gracePeriod")) {
            logger.warn("Razorpay webhook: ignoring out-of-order cancellation/halt that predates active renewal.", {
              eventId,
              businessId,
              eventTimestamp: eventTimestamp.toISOString(),
              lastProcessedTimestamp: lastEventTs.toDate().toISOString(),
            });
            // Record event as processed to maintain idempotency without downgrading subscription
            tx.set(idempotencyRef, {
              eventId,
              event,
              businessId,
              ignoredReason: "stale_out_of_order",
              eventTimestamp: eventTs,
              processedAt: nowTs,
            });
            return;
          }
        }

        // Validate exact Razorpay subscription ID if previously registered
        if (existingData.razorpaySubscriptionId && existingData.razorpaySubscriptionId !== subscriptionEntity.id) {
          logger.warn("Razorpay webhook: subscription ID mismatch for agency.", {
            existing: existingData.razorpaySubscriptionId,
            incoming: subscriptionEntity.id,
            businessId,
          });
        }
      }

      // 8. Build update payload
      const subscriptionData: Record<string, unknown> = {
        businessId,
        planId: update.planId,
        status: update.status,
        graceDays: update.graceDays,
        customerLimit: update.customerLimit,
        employeeLimit: update.employeeLimit,
        effectiveExpiresAt: update.effectiveExpiresAt,
        razorpaySubscriptionId: update.razorpaySubscriptionId,
        lastProcessedEventId: eventId,
        lastProcessedEventTimestamp: eventTs,
        updatedAt: nowTs,
        ...(update.currentPeriodStartsAt
          ? {currentPeriodStartsAt: update.currentPeriodStartsAt}
          : {}),
        ...(update.currentPeriodEndsAt
          ? {currentPeriodEndsAt: update.currentPeriodEndsAt}
          : {}),
      };

      // 9. Preserve trial timestamps
      if (subSnap.exists) {
        const existing = subSnap.data()!;
        if (existing.trialStartsAt) subscriptionData.trialStartsAt = existing.trialStartsAt;
        if (existing.trialEndsAt) subscriptionData.trialEndsAt = existing.trialEndsAt;
        tx.update(subRef, subscriptionData);
      } else {
        const bizSnap = await tx.get(firestore.doc(`businesses/${businessId}`));
        const createdAt = bizSnap.exists
          ? (bizSnap.get("createdAt") as Timestamp | undefined)?.toDate() ?? now
          : now;
        const baseline = evaluateAgencySubscriptionState(
          businessId,
          createdAt,
          undefined,
          now,
        );
        subscriptionData.trialStartsAt = Timestamp.fromDate(baseline.trialStartsAt);
        subscriptionData.trialEndsAt = Timestamp.fromDate(baseline.trialEndsAt);
        subscriptionData.createdAt = nowTs;
        tx.set(subRef, subscriptionData);
      }

      // 10. Persist Durable Idempotency Record
      tx.set(idempotencyRef, {
        eventId,
        event,
        businessId,
        razorpaySubscriptionId: update.razorpaySubscriptionId,
        newStatus: update.status,
        newPlanId: update.planId,
        eventTimestamp: eventTs,
        processedAt: nowTs,
      });

      // 11. Immutable Audit Record
      tx.create(auditRef, {
        businessId,
        actorId: "system:razorpay-webhook",
        action: "saasSubscriptionRenewed",
        entityType: "saasSubscription",
        entityId: "saas",
        razorpayEvent: event,
        razorpayEventId: eventId,
        newStatus: update.status,
        newPlanId: update.planId,
        effectiveExpiresAt: update.effectiveExpiresAt,
        createdAt: nowTs,
      });
    });

    logger.info("Razorpay webhook: event processed successfully.", {event, eventId, businessId, alreadyProcessed});
    response.status(200).json({status: "processed", event, eventId});
  } catch (error) {
    logger.error("Razorpay webhook: transaction failed.", {event, eventId, businessId, error});
    response.status(500).json({error: "Internal server error."});
  }
}
