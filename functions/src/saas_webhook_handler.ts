import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {Request, Response} from "firebase-functions/v2/https";
import {evaluateAgencySubscriptionState, verifyWebhookSignature} from "./saas_subscription_service";

// ---------------------------------------------------------------------------
// Razorpay webhook payload types (minimal — only fields we consume)
// ---------------------------------------------------------------------------

interface RazorpaySubscriptionEntity {
  id: string;
  plan_id?: string;
  status?: string;
  /** Unix timestamp (seconds) */
  current_start?: number;
  /** Unix timestamp (seconds) */
  current_end?: number;
  notes?: Record<string, string>;
}

interface RazorpayWebhookPayload {
  entity?: "event";
  event?: string;
  /** Razorpay-assigned unique event ID — used for idempotency. */
  id?: string;
  payload?: {
    subscription?: {
      entity?: RazorpaySubscriptionEntity;
    };
  };
}

// ---------------------------------------------------------------------------
// Subscription state derivation from a Razorpay event
// ---------------------------------------------------------------------------

interface SubscriptionUpdate {
  planId: string;
  status: "trial" | "active" | "gracePeriod" | "expired";
  currentPeriodStartsAt?: Timestamp;
  currentPeriodEndsAt?: Timestamp;
  graceDays: number;
  customerLimit: number;
  employeeLimit: number;
  effectiveExpiresAt: Timestamp;
  lastPaymentReference?: string;
}

const PLAN_LIMITS: Record<string, {customerLimit: number; employeeLimit: number}> = {
  starter: {customerLimit: 300, employeeLimit: 3},
  growth: {customerLimit: 1000, employeeLimit: 10},
  agencyPro: {customerLimit: 10000, employeeLimit: 100},
};

/** Maps a Razorpay plan_id (e.g. "plan_growth_monthly") to our internal planId. */
function resolveInternalPlanId(razorpayPlanId?: string): string {
  if (!razorpayPlanId) return "starter";
  const lower = razorpayPlanId.toLowerCase();
  if (lower.includes("agencypro") || lower.includes("agency_pro")) return "agencyPro";
  if (lower.includes("growth")) return "growth";
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
  const limits = PLAN_LIMITS[planId] ?? PLAN_LIMITS.starter;
  const graceDays = 7;
  const graceDurationMs = graceDays * 24 * 60 * 60 * 1000;

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
      };
    }

    case "subscription.cancelled":
    case "subscription.completed": {
      // Expired: effectiveExpiresAt set to epoch (always in the past) so the
      // Firestore rules gate immediately blocks new writes.
      return {
        planId,
        status: "expired",
        graceDays,
        customerLimit: limits.customerLimit,
        employeeLimit: limits.employeeLimit,
        effectiveExpiresAt: Timestamp.fromMillis(0),
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
 * Idempotency: if `payload.id` matches the `lastProcessedEventId` stored on
 * the subscription/saas document, the event is acknowledged without re-applying.
 *
 * businessId source: payload.payload.subscription.entity.notes.businessId
 * (populated by the PaperRoute web checkout portal when creating the Razorpay
 * subscription).
 */
export async function razorpayWebhookHandler(
  request: Request,
  response: Response,
): Promise<void> {
  // 1. Collect raw body for HMAC verification (must happen before any parsing).
  const rawBody: string =
    typeof request.rawBody === "object" && Buffer.isBuffer(request.rawBody)
      ? request.rawBody.toString("utf8")
      : typeof request.body === "string"
        ? request.body
        : JSON.stringify(request.body);

  const signature = request.headers["x-razorpay-signature"];
  if (typeof signature !== "string") {
    logger.warn("Razorpay webhook: missing signature header.");
    response.status(400).json({error: "Missing X-Razorpay-Signature header."});
    return;
  }

  const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET ?? "";
  if (!webhookSecret) {
    logger.error("Razorpay webhook: RAZORPAY_WEBHOOK_SECRET environment variable not set.");
    response.status(500).json({error: "Webhook secret not configured."});
    return;
  }

  // 2. Verify signature.
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
  const eventId = webhookPayload.id;
  const subscriptionEntity = webhookPayload.payload?.subscription?.entity;

  if (!event || !subscriptionEntity) {
    logger.info("Razorpay webhook: unrecognised event shape, ignoring.", {event});
    response.status(200).json({status: "ignored"});
    return;
  }

  // 4. Extract businessId from Razorpay notes field.
  const businessId = subscriptionEntity.notes?.businessId;
  if (!businessId) {
    logger.warn("Razorpay webhook: missing businessId in subscription notes.", {event});
    response.status(400).json({error: "Missing businessId in subscription notes."});
    return;
  }

  // 5. Derive subscription update.
  const now = new Date();
  const update = deriveSubscriptionUpdate(event, subscriptionEntity, now);
  if (!update) {
    logger.info("Razorpay webhook: no-op event, acknowledged.", {event, businessId});
    response.status(200).json({status: "acknowledged", event});
    return;
  }

  const firestore = getFirestore();
  const subRef = firestore.doc(`businesses/${businessId}/subscription/saas`);
  const auditRef = firestore.collection(`businesses/${businessId}/auditRecords`).doc();

  try {
    await firestore.runTransaction(async (tx) => {
      const subSnap = await tx.get(subRef);

      // 6. Idempotency check.
      if (eventId && subSnap.exists && subSnap.get("lastProcessedEventId") === eventId) {
        logger.info("Razorpay webhook: duplicate event, skipping.", {eventId, businessId});
        return; // Will still respond 200 below — idempotent success.
      }

      // 7. Build update payload.
      const nowTs = Timestamp.fromDate(now);
      const subscriptionData: Record<string, unknown> = {
        businessId,
        planId: update.planId,
        status: update.status,
        graceDays: update.graceDays,
        customerLimit: update.customerLimit,
        employeeLimit: update.employeeLimit,
        effectiveExpiresAt: update.effectiveExpiresAt,
        updatedAt: nowTs,
        ...(eventId ? {lastProcessedEventId: eventId} : {}),
        ...(update.currentPeriodStartsAt
          ? {currentPeriodStartsAt: update.currentPeriodStartsAt}
          : {}),
        ...(update.currentPeriodEndsAt
          ? {currentPeriodEndsAt: update.currentPeriodEndsAt}
          : {}),
        ...(update.lastPaymentReference
          ? {lastPaymentReference: update.lastPaymentReference}
          : {}),
      };

      // 8. Preserve trialStartsAt / trialEndsAt from existing doc if present.
      if (subSnap.exists) {
        const existing = subSnap.data()!;
        if (existing.trialStartsAt) subscriptionData.trialStartsAt = existing.trialStartsAt;
        if (existing.trialEndsAt) subscriptionData.trialEndsAt = existing.trialEndsAt;
        tx.update(subRef, subscriptionData);
      } else {
        // No existing subscription doc (edge case): evaluate from scratch to
        // get correct trial timestamps then merge with the renewal data.
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

      // 9. Immutable audit record.
      tx.create(auditRef, {
        businessId,
        actorId: "system:razorpay-webhook",
        action: "saasSubscriptionRenewed",
        entityType: "saasSubscription",
        entityId: "saas",
        razorpayEvent: event,
        razorpayEventId: eventId ?? null,
        newStatus: update.status,
        newPlanId: update.planId,
        effectiveExpiresAt: update.effectiveExpiresAt,
        createdAt: nowTs,
      });
    });

    logger.info("Razorpay webhook: processed successfully.", {event, businessId});
    response.status(200).json({status: "processed", event});
  } catch (error) {
    logger.error("Razorpay webhook: transaction failed.", {event, businessId, error});
    response.status(500).json({error: "Internal server error."});
  }
}
