import {createHmac, timingSafeEqual} from "node:crypto";

export interface SaasSubscriptionContract {
  businessId: string;
  planId: string;
  status: "trial" | "active" | "gracePeriod" | "expired";
  trialStartsAt: Date;
  trialEndsAt: Date;
  currentPeriodStartsAt?: Date;
  currentPeriodEndsAt?: Date;
  graceDays: number;
  customerLimit: number;
  employeeLimit: number;
  isReadOnly: boolean;
  daysRemaining: number;
  graceDaysRemaining: number;
  /** Pre-computed expiry timestamp (trial or paid period end + grace days).
   * Stored in the Firestore subscription document so Firestore Security Rules
   * can enforce the server-authoritative entitlement gate without runtime
   * duration arithmetic. Updated by the server on every subscription change. */
  effectiveExpiresAt: Date;
}

const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;
const ONE_DAY_MS = 24 * 60 * 60 * 1000;

/** Default fallback activation date for migrations if not configured in environment. */
export const DEFAULT_SAAS_ACTIVATION_DATE_ISO = "2026-09-24T00:00:00.000Z";

/**
 * Returns the controlled SaaS activation date for legacy agency migration.
 * Reads from process.env.SAAS_ACTIVATION_DATE if provided.
 */
export function getSaasActivationDate(customDate?: Date | string): Date {
  if (customDate instanceof Date && !isNaN(customDate.getTime())) {
    return customDate;
  }
  if (typeof customDate === "string") {
    const parsed = new Date(customDate);
    if (!isNaN(parsed.getTime())) return parsed;
  }
  const envDate = process.env.SAAS_ACTIVATION_DATE;
  if (envDate) {
    const parsed = new Date(envDate);
    if (!isNaN(parsed.getTime())) return parsed;
  }
  return new Date(DEFAULT_SAAS_ACTIVATION_DATE_ISO);
}

/**
 * Evaluates the authoritative SaaS subscription/trial state for an agency.
 *
 * Migration policy for legacy agencies (created before activationDate):
 *   effectiveTrialStart = max(businessCreatedAt, activationDate)
 *
 * This guarantees:
 * - Newly registered agencies always get exactly 30 days from activation.
 * - Pre-launch agencies are not immediately expired; they get 30 days from
 *   the controlled activation date.
 * - Trial resets are impossible: the cutoff is a fixed server configuration and
 *   clients cannot delete or recreate the subscription document.
 */
export function evaluateAgencySubscriptionState(
  businessId: string,
  businessCreatedAt: Date,
  existingSubscription?: {
    planId?: string;
    status?: string;
    trialStartsAt?: Date;
    trialEndsAt?: Date;
    currentPeriodStartsAt?: Date;
    currentPeriodEndsAt?: Date;
    graceDays?: number;
    customerLimit?: number;
    employeeLimit?: number;
  },
  now: Date = new Date(),
  activationDate: Date = getSaasActivationDate(),
): SaasSubscriptionContract {
  const graceDays = existingSubscription?.graceDays ?? 7;
  const graceDurationMs = graceDays * ONE_DAY_MS;
  const planId = existingSubscription?.planId ?? "trial";
  const customerLimit = existingSubscription?.customerLimit ?? 500;
  const employeeLimit = existingSubscription?.employeeLimit ?? 10;

  const currentPeriodStart = existingSubscription?.currentPeriodStartsAt;
  const currentPeriodEnd = existingSubscription?.currentPeriodEndsAt;

  // --- Trial start resolution with migration policy ---
  let trialStart: Date;
  if (existingSubscription?.trialStartsAt) {
    // Existing subscription document: always honour the stored trialStartsAt.
    trialStart = existingSubscription.trialStartsAt;
  } else {
    // No subscription document (legacy or new agency):
    // Apply migration policy — anchor to max(createdAt, activationDate).
    trialStart = businessCreatedAt < activationDate
      ? activationDate
      : businessCreatedAt;
  }

  const trialEnd = existingSubscription?.trialEndsAt
    ?? new Date(trialStart.getTime() + THIRTY_DAYS_MS);

  let status: "trial" | "active" | "gracePeriod" | "expired";
  let effectiveEnd: Date;

  if (existingSubscription?.status === "active") {
    effectiveEnd = currentPeriodEnd ?? trialEnd;
    if (now.getTime() < effectiveEnd.getTime()) {
      status = "active";
    } else if (now.getTime() < effectiveEnd.getTime() + graceDurationMs) {
      status = "gracePeriod";
    } else {
      status = "expired";
    }
  } else {
    // Trial evaluation
    effectiveEnd = trialEnd;
    if (now.getTime() < effectiveEnd.getTime()) {
      status = "trial";
    } else if (now.getTime() < effectiveEnd.getTime() + graceDurationMs) {
      status = "gracePeriod";
    } else {
      status = "expired";
    }
  }

  const msRemaining = Math.max(0, effectiveEnd.getTime() - now.getTime());
  const daysRemaining = Math.ceil(msRemaining / ONE_DAY_MS);

  const graceEnd = new Date(effectiveEnd.getTime() + graceDurationMs);
  const msGraceRemaining = Math.max(0, graceEnd.getTime() - now.getTime());
  const graceDaysRemaining = Math.min(
    graceDays,
    Math.ceil(msGraceRemaining / ONE_DAY_MS),
  );

  const isReadOnly = status === "expired";

  // Pre-compute the authoritative expiry timestamp stored in Firestore.
  // Firestore Security Rules read this field directly to gate operational
  // mutation operations — no duration arithmetic required in rules.
  const effectiveExpiresAt = graceEnd;

  return {
    businessId,
    planId,
    status,
    trialStartsAt: trialStart,
    trialEndsAt: trialEnd,
    currentPeriodStartsAt: currentPeriodStart,
    currentPeriodEndsAt: currentPeriodEnd,
    graceDays,
    customerLimit,
    employeeLimit,
    isReadOnly,
    daysRemaining,
    graceDaysRemaining,
    effectiveExpiresAt,
  };
}

/**
 * Validates HMAC SHA-256 webhook signatures from payment providers
 * to ensure tamper-proof server-to-server subscription verification.
 *
 * Compatible with Razorpay webhook signature format:
 * signature = HMAC-SHA256(rawBody, webhookSecret) encoded as hex
 */
export function verifyWebhookSignature(
  rawBody: string,
  secret: string,
  providedSignature: string,
): boolean {
  if (!rawBody || !secret || !providedSignature) return false;
  try {
    const expected = createHmac("sha256", secret).update(rawBody).digest("hex");
    const expectedBuffer = Buffer.from(expected, "utf8");
    const providedBuffer = Buffer.from(providedSignature, "utf8");
    if (expectedBuffer.length !== providedBuffer.length) return false;
    return timingSafeEqual(expectedBuffer, providedBuffer);
  } catch {
    return false;
  }
}
