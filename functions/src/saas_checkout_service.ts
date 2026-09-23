import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {CallableRequest, HttpsError} from "firebase-functions/v2/https";
import {isSimulatedCheckoutPermitted} from "./environment";

export {isSimulatedCheckoutPermitted};

export type SaasPlanId = "starter" | "growth" | "agencyPro";
export type SaasBillingCycle = "monthly" | "annual";

export interface SaasCheckoutRequest {
  businessId: string;
  planId: SaasPlanId;
  billingCycle: SaasBillingCycle;
}

export interface SaasCheckoutSessionResponse {
  subscriptionId: string;
  keyId: string;
  planId: string;
  billingCycle: string;
  amountPaise: number;
  currency: string;
  businessId: string;
  businessName: string;
  customerEmail: string;
  isSimulated: boolean;
  notes: Record<string, string>;
}

export interface ApprovedPlanConfig {
  planId: SaasPlanId;
  billingCycle: SaasBillingCycle;
  amountPaise: number;
  currency: string;
  totalCount: number;
  razorpayPlanId: string;
  customerLimit: number;
  employeeLimit: number;
}

/**
 * Provisional default plan pricing (in paise).
 * Configurable via environment variables (e.g. PLAN_PRICE_STARTER_MONTHLY).
 */
export const PROVISIONAL_DEFAULT_PRICING_PAISE = {
  starter: { monthly: 29900, annual: 299900 },
  growth: { monthly: 59900, annual: 599900 },
  agencyPro: { monthly: 129900, annual: 1299900 },
};

export function getProvisionalPlanPrice(
  planId: SaasPlanId,
  billingCycle: SaasBillingCycle,
): number {
  const envVar = `PLAN_PRICE_${planId.toUpperCase()}_${billingCycle.toUpperCase()}`;
  const envVal = process.env[envVar];
  if (envVal) {
    const parsed = parseInt(envVal, 10);
    if (!isNaN(parsed) && parsed > 0) return parsed;
  }
  return PROVISIONAL_DEFAULT_PRICING_PAISE[planId][billingCycle];
}

/**
 * Authoritative server-approved SaaS plan configurations and Razorpay plan mappings.
 * Razorpay recurring subscriptions require server-approved plan IDs and cycle counts.
 * Prices remain configurable and provisional.
 */
export const SERVER_APPROVED_PLANS: Record<string, ApprovedPlanConfig> = {
  starter_monthly: {
    planId: "starter",
    billingCycle: "monthly",
    amountPaise: getProvisionalPlanPrice("starter", "monthly"),
    currency: "INR",
    totalCount: 120, // 10 years monthly recurring
    razorpayPlanId: process.env.RAZORPAY_PLAN_STARTER_MONTHLY || "plan_starter_monthly",
    customerLimit: 300,
    employeeLimit: 3,
  },
  starter_annual: {
    planId: "starter",
    billingCycle: "annual",
    amountPaise: getProvisionalPlanPrice("starter", "annual"),
    currency: "INR",
    totalCount: 10, // 10 years annual recurring
    razorpayPlanId: process.env.RAZORPAY_PLAN_STARTER_ANNUAL || "plan_starter_annual",
    customerLimit: 300,
    employeeLimit: 3,
  },
  growth_monthly: {
    planId: "growth",
    billingCycle: "monthly",
    amountPaise: getProvisionalPlanPrice("growth", "monthly"),
    currency: "INR",
    totalCount: 120,
    razorpayPlanId: process.env.RAZORPAY_PLAN_GROWTH_MONTHLY || "plan_growth_monthly",
    customerLimit: 1000,
    employeeLimit: 10,
  },
  growth_annual: {
    planId: "growth",
    billingCycle: "annual",
    amountPaise: getProvisionalPlanPrice("growth", "annual"),
    currency: "INR",
    totalCount: 10,
    razorpayPlanId: process.env.RAZORPAY_PLAN_GROWTH_ANNUAL || "plan_growth_annual",
    customerLimit: 1000,
    employeeLimit: 10,
  },
  agencyPro_monthly: {
    planId: "agencyPro",
    billingCycle: "monthly",
    amountPaise: getProvisionalPlanPrice("agencyPro", "monthly"),
    currency: "INR",
    totalCount: 120,
    razorpayPlanId: process.env.RAZORPAY_PLAN_AGENCYPRO_MONTHLY || "plan_agencypro_monthly",
    customerLimit: 10000,
    employeeLimit: 100,
  },
  agencyPro_annual: {
    planId: "agencyPro",
    billingCycle: "annual",
    amountPaise: getProvisionalPlanPrice("agencyPro", "annual"),
    currency: "INR",
    totalCount: 10,
    razorpayPlanId: process.env.RAZORPAY_PLAN_AGENCYPRO_ANNUAL || "plan_agencypro_annual",
    customerLimit: 10000,
    employeeLimit: 100,
  },
};

/**
 * Strict lookup mapping Razorpay plan ID to ApprovedPlanConfig.
 * Never defaults to Starter. Returns null for unknown plans.
 */
export function resolveInternalPlanConfig(razorpayPlanId?: string): ApprovedPlanConfig | null {
  if (!razorpayPlanId) return null;
  for (const config of Object.values(SERVER_APPROVED_PLANS)) {
    if (config.razorpayPlanId === razorpayPlanId) {
      return config;
    }
  }
  if (SERVER_APPROVED_PLANS[razorpayPlanId]) {
    return SERVER_APPROVED_PLANS[razorpayPlanId];
  }
  return null;
}

export const PLAN_PRICING_PAISE: Record<string, {monthly: number; annual: number}> = {
  starter: {
    monthly: getProvisionalPlanPrice("starter", "monthly"),
    annual: getProvisionalPlanPrice("starter", "annual"),
  },
  growth: {
    monthly: getProvisionalPlanPrice("growth", "monthly"),
    annual: getProvisionalPlanPrice("growth", "annual"),
  },
  agencyPro: {
    monthly: getProvisionalPlanPrice("agencyPro", "monthly"),
    annual: getProvisionalPlanPrice("agencyPro", "annual"),
  },
};

/**
 * Validates that the caller is an authenticated Head of the target business.
 */
async function requireHeadAuthorization(
  businessId: string,
  uid: string,
  email?: string,
): Promise<{businessName: string; userEmail: string}> {
  const db = getFirestore();
  const memberSnap = await db.doc(`businesses/${businessId}/members/${uid}`).get();

  if (!memberSnap.exists || memberSnap.get("role") !== "head" || memberSnap.get("status") !== "active") {
    throw new HttpsError(
      "permission-denied",
      "Only active Agency Heads can purchase or renew SaaS subscriptions.",
    );
  }

  const bizSnap = await db.doc(`businesses/${businessId}`).get();
  const businessName = bizSnap.get("name") || "PaperRoute Agency";
  const userEmail = email || memberSnap.get("email") || "";

  return {businessName, userEmail};
}

/**
 * Callable Cloud Function: Creates an authenticated Razorpay checkout session
 * for PaperRoute SaaS recurring subscriptions (Option A separate web checkout).
 *
 * Implements genuine Razorpay Subscriptions flow (/v1/subscriptions).
 * Persists an authenticated checkout session record binding businessId, Head UID,
 * internal plan, amount, currency, and Razorpay subscription ID.
 *
 * When real credentials are used, any API failure throws an error immediately.
 * A sandbox simulator is kept strictly isolated for non-credentialed test environments.
 */
export async function createSaasCheckoutSessionHandler(
  request: CallableRequest<SaasCheckoutRequest>,
): Promise<SaasCheckoutSessionResponse> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in before initiating checkout.");
  }

  const uid = request.auth.uid;
  const email = request.auth.token.email;
  const {businessId, planId, billingCycle} = request.data || {};

  if (!businessId || typeof businessId !== "string") {
    throw new HttpsError("invalid-argument", "Valid businessId is required.");
  }

  const planKey = `${planId}_${billingCycle}`;
  const planConfig = SERVER_APPROVED_PLANS[planKey];
  if (!planConfig) {
    throw new HttpsError(
      "invalid-argument",
      `Invalid planId (${planId}) or billingCycle (${billingCycle}).`,
    );
  }

  // Authorize caller as Head
  const {businessName, userEmail} = await requireHeadAuthorization(businessId, uid, email);

  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;

  const notes: Record<string, string> = {
    businessId,
    headUid: uid,
    planId: planConfig.planId,
    billingCycle: planConfig.billingCycle,
  };

  let subscriptionId: string;
  let isSimulated = false;

  if (keyId && keySecret) {
    // Genuine Razorpay Subscriptions API call
    const basicAuth = Buffer.from(`${keyId}:${keySecret}`).toString("base64");
    let res: globalThis.Response;
    try {
      res = await fetch("https://api.razorpay.com/v1/subscriptions", {
        method: "POST",
        headers: {
          Authorization: `Basic ${basicAuth}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          plan_id: planConfig.razorpayPlanId,
          total_count: planConfig.totalCount,
          quantity: 1,
          customer_notify: 1,
          notes,
        }),
      });
    } catch (fetchErr) {
      logger.error("Razorpay API connection error", {fetchErr});
      throw new HttpsError("unavailable", "Unable to connect to Razorpay Subscriptions API.");
    }

    if (!res.ok) {
      const errorText = await res.text();
      logger.error("Razorpay API subscription creation failed", {
        status: res.status,
        body: errorText,
      });
      // CRITICAL: Never return a fabricated ID when a real API request fails!
      throw new HttpsError(
        "internal",
        `Razorpay Subscriptions API rejected request: ${res.statusText} (${res.status})`,
      );
    }

    const data = (await res.json()) as {id: string};
    if (!data?.id) {
      logger.error("Razorpay response missing subscription id", {data});
      throw new HttpsError("internal", "Malformed response from Razorpay Subscriptions API.");
    }
    subscriptionId = data.id;
  } else {
    // Simulator strictly isolated: permitted ONLY when positive Dev/Emulator environment is identified
    // AND simulation has been deliberately enabled. Never permitted in Production.
    if (!isSimulatedCheckoutPermitted()) {
      throw new HttpsError(
        "failed-precondition",
        "Razorpay checkout credentials (RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET) are not configured.",
      );
    }
    isSimulated = true;
    subscriptionId = `sub_sim_${businessId}_${Date.now()}`;
    logger.info("Using isolated simulated checkout session (no credentials configured)", {
      businessId,
      subscriptionId,
    });
  }

  // Persist authenticated checkout session record binding businessId, Head UID, plan, amount, currency, and subscriptionId
  const db = getFirestore();
  const now = Timestamp.now();
  const expiresAt = Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000); // 24-hour checkout window

  const checkoutSessionRef = db.doc(`businesses/${businessId}/saasCheckoutSessions/${subscriptionId}`);
  await checkoutSessionRef.set({
    subscriptionId,
    businessId,
    headUid: uid,
    planId: planConfig.planId,
    billingCycle: planConfig.billingCycle,
    amountPaise: planConfig.amountPaise,
    currency: planConfig.currency,
    razorpayPlanId: planConfig.razorpayPlanId,
    customerLimit: planConfig.customerLimit,
    employeeLimit: planConfig.employeeLimit,
    isSimulated,
    status: "created",
    notes,
    createdAt: now,
    expiresAt,
  });

  // Record audit trail
  const auditRef = db.collection(`businesses/${businessId}/auditRecords`).doc();
  await auditRef.set({
    businessId,
    actorId: uid,
    action: "saasCheckoutSessionCreated",
    entityType: "saasSubscription",
    entityId: "saas",
    planId: planConfig.planId,
    billingCycle: planConfig.billingCycle,
    amountPaise: planConfig.amountPaise,
    subscriptionId,
    isSimulated,
    createdAt: now,
  });

  return {
    subscriptionId,
    keyId: keyId || "rzp_test_paperroute_demo",
    planId: planConfig.planId,
    billingCycle: planConfig.billingCycle,
    amountPaise: planConfig.amountPaise,
    currency: planConfig.currency,
    businessId,
    businessName,
    customerEmail: userEmail,
    isSimulated,
    notes,
  };
}
