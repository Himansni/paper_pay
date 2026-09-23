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
}

const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;
const ONE_DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Evaluates the authoritative SaaS subscription/trial state for an agency.
 * Existing agencies without an explicit subscription document use their original
 * business creation timestamp to prevent duplicate trial resets.
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
): SaasSubscriptionContract {
  const trialStart = existingSubscription?.trialStartsAt ?? businessCreatedAt;
  const trialEnd =
    existingSubscription?.trialEndsAt ??
    new Date(trialStart.getTime() + THIRTY_DAYS_MS);
  const graceDays = existingSubscription?.graceDays ?? 7;
  const graceDurationMs = graceDays * ONE_DAY_MS;
  const planId = existingSubscription?.planId ?? "trial";
  const customerLimit = existingSubscription?.customerLimit ?? 500;
  const employeeLimit = existingSubscription?.employeeLimit ?? 10;

  const currentPeriodStart = existingSubscription?.currentPeriodStartsAt;
  const currentPeriodEnd = existingSubscription?.currentPeriodEndsAt;

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
  const graceDaysRemaining = Math.min(graceDays, Math.ceil(msGraceRemaining / ONE_DAY_MS));

  const isReadOnly = status === "expired";

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
  };
}

/**
 * Validates HMAC SHA-256 webhook signatures from payment providers
 * to ensure tamper-proof server-to-server subscription verification.
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
