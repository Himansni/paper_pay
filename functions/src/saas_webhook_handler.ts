import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {Request, Response} from "firebase-functions/v2/https";
import {evaluateAgencySubscriptionState, verifyWebhookSignature} from "./saas_subscription_service";
import {
  ApprovedPlanConfig,
  resolveInternalPlanConfig,
  SERVER_APPROVED_PLANS,
} from "./saas_checkout_service";

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
  starter: {
    customerLimit: SERVER_APPROVED_PLANS.starter_monthly.customerLimit,
    employeeLimit: SERVER_APPROVED_PLANS.starter_monthly.employeeLimit,
  },
  growth: {
    customerLimit: SERVER_APPROVED_PLANS.growth_monthly.customerLimit,
    employeeLimit: SERVER_APPROVED_PLANS.growth_monthly.employeeLimit,
  },
  agencyPro: {
    customerLimit: SERVER_APPROVED_PLANS.agencyPro_monthly.customerLimit,
    employeeLimit: SERVER_APPROVED_PLANS.agencyPro_monthly.employeeLimit,
  },
};

/**
 * Derives the Firestore subscription update from a Razorpay webhook event.
 * Uses exact server-controlled mapping of plan IDs.
 * Rejects unknown plan IDs (returns null) rather than defaulting to Starter.
 */
export function deriveSubscriptionUpdate(
  event: string,
  entity: RazorpaySubscriptionEntity,
  now: Date = new Date(),
): SubscriptionUpdate | null {
  const planConfig = resolveInternalPlanConfig(entity.plan_id);
  // CRITICAL: Unknown plan IDs MUST be rejected; never default to Starter!
  if (!planConfig) {
    logger.warn("Razorpay webhook: unrecognised or unapproved plan_id, rejecting.", {
      plan_id: entity.plan_id,
      event,
    });
    return null;
  }

  const planId = planConfig.planId;
  const limits = {
    customerLimit: planConfig.customerLimit,
    employeeLimit: planConfig.employeeLimit,
  };
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
        : new Date(
            now.getTime() +
              (planConfig.billingCycle === "annual" ? 365 : 30) * 24 * 60 * 60 * 1000,
          );
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
      // Payment failed: enter 7-day grace period. effectiveExpiresAt = now + graceDays.
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
      // Subscription cancelled: effectiveExpiresAt set to epoch 0 so security rules immediately lock writes.
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
 * Security:
 * - Rejects forged HMAC signatures.
 * - Strict server plan mapping: rejects unknown plan IDs (never defaults to Starter).
 * - Checkout binding verification: safely quarantines events whose subscription ID
 *   does not match an authorized, server-created checkout session.
 * - Plan mismatch quarantine: quarantines events where plan does not match checkout session.
 * - Durable Idempotency: persisted in `businesses/{businessId}/saasWebhookEvents/{eventId}`.
 * - Out-of-order delivery protection against stale downgrades.
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

  const webhookSecret =
    process.env.RAZORPAY_WEBHOOK_SECRET ||
    (process.env.GCLOUD_PROJECT !== "paperrouteprod" ? "whsec_paperroute_dev_test" : "");
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
  const eventId =
    typeof headerEventId === "string" && headerEventId.length > 0
      ? headerEventId
      : webhookPayload.id;

  if (!eventId) {
    logger.warn("Razorpay webhook: missing event ID.");
    response.status(400).json({error: "Missing event ID."});
    return;
  }

  const subscriptionEntity = webhookPayload.payload?.subscription?.entity;
  if (!event || !subscriptionEntity) {
    logger.info("Razorpay webhook: non-subscription event shape, ignored.", {event});
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

  // 5. Strict Server Plan Mapping Check:
  // Reject unknown plan IDs immediately; never default to Starter!
  const planConfig = resolveInternalPlanConfig(subscriptionEntity.plan_id);
  if (!planConfig) {
    logger.warn("Razorpay webhook: unknown or unapproved plan ID, quarantining event.", {
      plan_id: subscriptionEntity.plan_id,
      businessId,
      eventId,
    });
    const firestore = getFirestore();
    await firestore.doc(`businesses/${businessId}/saasQuarantinedEvents/${eventId}`).set({
      eventId,
      event,
      businessId,
      subscriptionId: subscriptionEntity.id,
      quarantineReason: "unknown_or_unapproved_plan_id",
      receivedPlanId: subscriptionEntity.plan_id ?? null,
      payload: webhookPayload,
      quarantinedAt: Timestamp.now(),
    });
    response.status(400).json({
      error: `Unknown or unapproved Razorpay plan ID: ${subscriptionEntity.plan_id}. Event quarantined.`,
      eventId,
    });
    return;
  }

  // 6. Derive subscription update.
  const now = new Date();
  const update = deriveSubscriptionUpdate(event, subscriptionEntity, now);
  if (!update) {
    logger.info("Razorpay webhook: subscription event requires no state update, acknowledged.", {
      event,
      businessId,
    });
    response.status(200).json({status: "acknowledged", event});
    return;
  }

  const eventTimestamp = webhookPayload.created_at
    ? new Date(webhookPayload.created_at * 1000)
    : now;

  const firestore = getFirestore();
  const subRef = firestore.doc(`businesses/${businessId}/subscription/saas`);
  const idempotencyRef = firestore.doc(`businesses/${businessId}/saasWebhookEvents/${eventId}`);
  const checkoutSessionRef = firestore.doc(
    `businesses/${businessId}/saasCheckoutSessions/${subscriptionEntity.id}`,
  );
  const quarantineRef = firestore.doc(`businesses/${businessId}/saasQuarantinedEvents/${eventId}`);
  const auditRef = firestore.collection(`businesses/${businessId}/auditRecords`).doc();

  try {
    let alreadyProcessed = false;
    let quarantined = false;
    let quarantineReason = "";

    await firestore.runTransaction(async (tx) => {
      const nowTs = Timestamp.fromDate(now);
      const eventTs = Timestamp.fromDate(eventTimestamp);

      // 7. Durable Idempotency Check
      const eventSnap = await tx.get(idempotencyRef);
      if (eventSnap.exists) {
        logger.info("Razorpay webhook: duplicate event in durable collection, skipping.", {
          eventId,
          businessId,
        });
        alreadyProcessed = true;
        return;
      }

      // 8. Server-Created Checkout Record Verification
      // Reject or quarantine events whose Razorpay subscription ID does not match
      // an authorized, server-created checkout/subscription record for that business.
      const checkoutSnap = await tx.get(checkoutSessionRef);
      const subSnap = await tx.get(subRef);

      let isAuthorizedSubscription = false;
      let checkoutData: Record<string, any> | undefined;

      if (checkoutSnap.exists) {
        checkoutData = checkoutSnap.data();
        if (checkoutData?.businessId === businessId) {
          isAuthorizedSubscription = true;
        }
      } else if (
        subSnap.exists &&
        subSnap.data()?.razorpaySubscriptionId === subscriptionEntity.id
      ) {
        // Legitimate recurring renewal for an already verified active subscription
        isAuthorizedSubscription = true;
      }

      if (!isAuthorizedSubscription) {
        logger.warn(
          "Razorpay webhook: subscription ID does not match server checkout record, quarantining.",
          {
            subscriptionId: subscriptionEntity.id,
            businessId,
            eventId,
          },
        );
        tx.set(quarantineRef, {
          eventId,
          event,
          businessId,
          subscriptionId: subscriptionEntity.id,
          quarantineReason: "unauthorized_subscription_no_checkout_record",
          payload: webhookPayload,
          quarantinedAt: nowTs,
        });
        quarantined = true;
        quarantineReason = "unauthorized_subscription_no_checkout_record";
        return;
      }

      // Plan Mismatch Check: If server checkout session exists, verify plan matches
      if (checkoutData && checkoutData.planId !== update.planId) {
        logger.warn("Razorpay webhook: plan mismatch between checkout session and event, quarantining.", {
          checkoutPlan: checkoutData.planId,
          webhookPlan: update.planId,
          businessId,
          eventId,
        });
        tx.set(quarantineRef, {
          eventId,
          event,
          businessId,
          subscriptionId: subscriptionEntity.id,
          quarantineReason: "plan_mismatch_with_checkout_session",
          checkoutPlan: checkoutData.planId,
          webhookPlan: update.planId,
          payload: webhookPayload,
          quarantinedAt: nowTs,
        });
        quarantined = true;
        quarantineReason = "plan_mismatch_with_checkout_session";
        return;
      }

      // 9. Out-of-Order & Stale Event Protection
      if (subSnap.exists) {
        const existingData = subSnap.data()!;
        const lastEventTs = existingData.lastProcessedEventTimestamp as Timestamp | undefined;

        if (lastEventTs && eventTimestamp.getTime() < lastEventTs.toDate().getTime()) {
          // Stale cancellation/halt arriving after a newer active renewal: protect active subscription
          if (
            existingData.status === "active" &&
            (update.status === "expired" || update.status === "gracePeriod")
          ) {
            logger.warn(
              "Razorpay webhook: ignoring out-of-order cancellation/halt that predates active renewal.",
              {
                eventId,
                businessId,
                eventTimestamp: eventTimestamp.toISOString(),
                lastProcessedTimestamp: lastEventTs.toDate().toISOString(),
              },
            );
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
      }

      // 10. Build subscription update payload
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
        ...(update.currentPeriodEndsAt ? {currentPeriodEndsAt: update.currentPeriodEndsAt} : {}),
      };

      // Preserve existing trial timestamps
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

      // Mark checkout session completed if present
      if (checkoutSnap.exists) {
        tx.update(checkoutSessionRef, {
          status: "completed",
          activatedAt: nowTs,
        });
      }

      // 11. Persist Durable Idempotency Record
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

      // 12. Immutable Audit Record
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

    if (quarantined) {
      response.status(400).json({
        error: "Webhook event quarantined.",
        quarantineReason,
        eventId,
      });
      return;
    }

    if (alreadyProcessed) {
      response.status(200).json({status: "duplicate", eventId});
      return;
    }

    logger.info("Razorpay webhook: event processed successfully.", {
      event,
      eventId,
      businessId,
    });
    response.status(200).json({status: "processed", event, eventId});
  } catch (error) {
    logger.error("Razorpay webhook: transaction failed.", {event, eventId, businessId, error});
    response.status(500).json({error: "Internal server error."});
  }
}
