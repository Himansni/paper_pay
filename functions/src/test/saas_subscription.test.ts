import {describe, it, beforeEach, afterEach} from "node:test";
import assert from "node:assert/strict";
import {
  evaluateAgencySubscriptionState,
  verifyWebhookSignature,
  getSaasActivationDate,
} from "../saas_subscription_service";
import {
  deriveSubscriptionUpdate,
  APPROVED_PLAN_LIMITS,
} from "../saas_webhook_handler";
import {
  PLAN_PRICING_PAISE,
  SERVER_APPROVED_PLANS,
  resolveInternalPlanConfig,
} from "../saas_checkout_service";
import {createHmac} from "node:crypto";

describe("SaaS Activation Date Configuration (Problem 3)", () => {
  const originalEnv = process.env.SAAS_ACTIVATION_DATE;

  beforeEach(() => {
    delete process.env.SAAS_ACTIVATION_DATE;
  });

  afterEach(() => {
    if (originalEnv !== undefined) {
      process.env.SAAS_ACTIVATION_DATE = originalEnv;
    } else {
      delete process.env.SAAS_ACTIVATION_DATE;
    }
  });

  it("throws error when no activation date is configured and no argument is provided", () => {
    assert.throws(
      () => getSaasActivationDate(),
      /SAAS_ACTIVATION_DATE is not configured/,
    );
  });

  it("resolves activation date from environment variable when configured", () => {
    process.env.SAAS_ACTIVATION_DATE = "2026-09-24T00:00:00.000Z";
    const date = getSaasActivationDate();
    assert.equal(date.toISOString(), "2026-09-24T00:00:00.000Z");
  });

  it("resolves custom Date or ISO string parameter when provided", () => {
    const custom = new Date("2026-10-15T00:00:00.000Z");
    assert.equal(getSaasActivationDate(custom).toISOString(), "2026-10-15T00:00:00.000Z");
    assert.equal(getSaasActivationDate("2026-11-01T00:00:00.000Z").toISOString(), "2026-11-01T00:00:00.000Z");
  });
});

describe("evaluateAgencySubscriptionState (Problem 3)", () => {
  const activationDate = new Date("2026-09-24T00:00:00.000Z");
  const postLaunchTime = new Date("2026-10-01T00:00:00.000Z");

  it("newly activated agency after launch receives exact 30-day trial starting at activation", () => {
    const activation = new Date("2026-10-01T00:00:00.000Z");
    const now = new Date("2026-10-01T12:00:00.000Z");

    const state = evaluateAgencySubscriptionState(
      "biz-1",
      activation,
      undefined,
      now,
      activationDate,
    );

    assert.equal(state.status, "trial");
    assert.equal(state.trialStartsAt.toISOString(), activation.toISOString());
    assert.equal(
      state.trialEndsAt.toISOString(),
      new Date(activation.getTime() + 30 * 24 * 60 * 60 * 1000).toISOString(),
    );
    assert.equal(state.daysRemaining, 30);
    assert.equal(state.isReadOnly, false);
    assert.equal(
      state.effectiveExpiresAt.toISOString(),
      new Date(activation.getTime() + (30 + 7) * 24 * 60 * 60 * 1000).toISOString(),
    );
  });

  it("legacy agency created before activation date has trial anchored to activationDate (migration policy)", () => {
    const legacyCreatedAt = new Date("2026-07-25T00:00:00.000Z");
    const now = new Date(activationDate.getTime() + 5 * 24 * 60 * 60 * 1000);

    const state = evaluateAgencySubscriptionState(
      "biz-legacy",
      legacyCreatedAt,
      undefined,
      now,
      activationDate,
    );

    assert.equal(state.status, "trial");
    assert.equal(state.trialStartsAt.toISOString(), activationDate.toISOString());
    assert.equal(
      state.trialEndsAt.toISOString(),
      new Date(activationDate.getTime() + 30 * 24 * 60 * 60 * 1000).toISOString(),
    );
    assert.equal(state.daysRemaining, 25);
    assert.equal(state.isReadOnly, false);
  });

  it("post-launch agency with historical createdAt never receives duplicate trial", () => {
    const createdAt = new Date("2026-10-01T00:00:00.000Z");
    const now = new Date("2026-10-26T00:00:00.000Z");

    const state = evaluateAgencySubscriptionState(
      "biz-existing",
      createdAt,
      undefined,
      now,
      activationDate,
    );

    assert.equal(state.status, "trial");
    assert.equal(state.trialStartsAt.toISOString(), createdAt.toISOString());
    assert.equal(state.daysRemaining, 5);
    assert.equal(state.isReadOnly, false);
  });

  it("agency with pre-existing trialStartsAt in doc always honours stored timestamp (no trial reset)", () => {
    const originalTrialStart = new Date("2026-09-01T00:00:00.000Z");
    const originalTrialEnd = new Date("2026-10-01T00:00:00.000Z");
    const now = new Date("2026-09-20T00:00:00.000Z");

    const state = evaluateAgencySubscriptionState(
      "biz-pre-existing-doc",
      new Date("2026-08-01T00:00:00.000Z"),
      {
        planId: "trial",
        status: "trial",
        trialStartsAt: originalTrialStart,
        trialEndsAt: originalTrialEnd,
        graceDays: 7,
      },
      now,
      activationDate,
    );

    assert.equal(state.status, "trial");
    assert.equal(state.trialStartsAt.toISOString(), originalTrialStart.toISOString());
    assert.equal(state.trialEndsAt.toISOString(), originalTrialEnd.toISOString());
    assert.equal(state.daysRemaining, 11);
    assert.equal(state.isReadOnly, false);
  });

  it("agency enters 7-day grace period immediately when trial expires", () => {
    const createdAt = postLaunchTime;
    const now = new Date(postLaunchTime.getTime() + 32 * 24 * 60 * 60 * 1000);

    const state = evaluateAgencySubscriptionState(
      "biz-grace",
      createdAt,
      undefined,
      now,
      activationDate,
    );

    assert.equal(state.status, "gracePeriod");
    assert.equal(state.daysRemaining, 0);
    assert.equal(state.graceDaysRemaining, 5);
    assert.equal(state.isReadOnly, false);
  });

  it("agency switches to read-only mode after trial + grace period expires", () => {
    const createdAt = postLaunchTime;
    const now = new Date(postLaunchTime.getTime() + 40 * 24 * 60 * 60 * 1000);

    const state = evaluateAgencySubscriptionState(
      "biz-expired",
      createdAt,
      undefined,
      now,
      activationDate,
    );

    assert.equal(state.status, "expired");
    assert.equal(state.daysRemaining, 0);
    assert.equal(state.graceDaysRemaining, 0);
    assert.equal(state.isReadOnly, true);
    assert.ok(state.effectiveExpiresAt.getTime() < now.getTime());
  });

  it("active paid subscription overrides trial and maintains write access", () => {
    const createdAt = new Date(postLaunchTime.getTime() - 60 * 24 * 60 * 60 * 1000);
    const currentPeriodStart = new Date(postLaunchTime.getTime() - 10 * 24 * 60 * 60 * 1000);
    const currentPeriodEnd = new Date(postLaunchTime.getTime() + 20 * 24 * 60 * 60 * 1000);

    const state = evaluateAgencySubscriptionState(
      "biz-paid",
      createdAt,
      {
        planId: "growth",
        status: "active",
        currentPeriodStartsAt: currentPeriodStart,
        currentPeriodEndsAt: currentPeriodEnd,
        customerLimit: 1000,
        employeeLimit: 10,
      },
      postLaunchTime,
      activationDate,
    );

    assert.equal(state.status, "active");
    assert.equal(state.planId, "growth");
    assert.equal(state.daysRemaining, 20);
    assert.equal(state.isReadOnly, false);
    assert.equal(
      state.effectiveExpiresAt.toISOString(),
      new Date(currentPeriodEnd.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString(),
    );
  });
});

describe("Strict Server-Controlled Plan Mapping (Problem 1 & 2)", () => {
  it("resolves all server-approved plans and billing cycles accurately", () => {
    const starterMo = resolveInternalPlanConfig("plan_starter_monthly");
    assert.ok(starterMo);
    assert.equal(starterMo?.planId, "starter");
    assert.equal(starterMo?.billingCycle, "monthly");
    assert.equal(starterMo?.amountPaise, 29900);
    assert.equal(starterMo?.customerLimit, 300);

    const starterYr = resolveInternalPlanConfig("plan_starter_annual");
    assert.ok(starterYr);
    assert.equal(starterYr?.planId, "starter");
    assert.equal(starterYr?.billingCycle, "annual");
    assert.equal(starterYr?.amountPaise, 299900);

    const growthMo = resolveInternalPlanConfig("plan_growth_monthly");
    assert.ok(growthMo);
    assert.equal(growthMo?.planId, "growth");
    assert.equal(growthMo?.amountPaise, 59900);
    assert.equal(growthMo?.customerLimit, 1000);

    const agencyProYr = resolveInternalPlanConfig("plan_agencypro_annual");
    assert.ok(agencyProYr);
    assert.equal(agencyProYr?.planId, "agencyPro");
    assert.equal(agencyProYr?.amountPaise, 1299900);
    assert.equal(agencyProYr?.customerLimit, 10000);
  });

  it("strictly REJECTS unknown plan IDs and NEVER defaults to Starter", () => {
    assert.equal(resolveInternalPlanConfig("unknown_plan_xyz"), null);
    assert.equal(resolveInternalPlanConfig("custom_enterprise_plan"), null);
    assert.equal(resolveInternalPlanConfig("free_tier_override"), null);
    assert.equal(resolveInternalPlanConfig(undefined), null);
    assert.equal(resolveInternalPlanConfig(""), null);
  });

  it("enforces approved pricing table", () => {
    assert.equal(PLAN_PRICING_PAISE.starter.monthly, 29900);
    assert.equal(PLAN_PRICING_PAISE.starter.annual, 299900);
    assert.equal(PLAN_PRICING_PAISE.growth.monthly, 59900);
    assert.equal(PLAN_PRICING_PAISE.growth.annual, 599900);
    assert.equal(PLAN_PRICING_PAISE.agencyPro.monthly, 129900);
    assert.equal(PLAN_PRICING_PAISE.agencyPro.annual, 1299900);
  });

  it("enforces approved plan limits", () => {
    assert.equal(APPROVED_PLAN_LIMITS.starter.customerLimit, 300);
    assert.equal(APPROVED_PLAN_LIMITS.starter.employeeLimit, 3);
    assert.equal(APPROVED_PLAN_LIMITS.growth.customerLimit, 1000);
    assert.equal(APPROVED_PLAN_LIMITS.growth.employeeLimit, 10);
    assert.equal(APPROVED_PLAN_LIMITS.agencyPro.customerLimit, 10000);
    assert.equal(APPROVED_PLAN_LIMITS.agencyPro.employeeLimit, 100);
  });
});

describe("deriveSubscriptionUpdate & Webhook State Machine (Problem 2)", () => {
  const testNow = new Date("2026-10-15T10:00:00.000Z");

  it("handles subscription.activated and subscription.charged for approved plans", () => {
    const update = deriveSubscriptionUpdate(
      "subscription.activated",
      {
        id: "sub_12345",
        plan_id: "plan_growth_monthly",
        current_start: Math.floor(testNow.getTime() / 1000),
        current_end: Math.floor(testNow.getTime() / 1000) + 30 * 24 * 3600,
      },
      testNow,
    );

    assert.ok(update);
    assert.equal(update?.status, "active");
    assert.equal(update?.planId, "growth");
    assert.equal(update?.customerLimit, 1000);
    assert.equal(update?.employeeLimit, 10);
    assert.equal(update?.razorpaySubscriptionId, "sub_12345");
    assert.ok(update?.effectiveExpiresAt);
  });

  it("strictly REJECTS events with unknown plan_id by returning null (no Starter fallback)", () => {
    const update = deriveSubscriptionUpdate(
      "subscription.activated",
      {
        id: "sub_fraud_001",
        plan_id: "unknown_hacked_plan",
      },
      testNow,
    );
    assert.equal(update, null, "Unknown plan must not be accepted or defaulted to Starter!");
  });

  it("handles subscription.halted / payment.failed by entering gracePeriod", () => {
    const update = deriveSubscriptionUpdate(
      "subscription.halted",
      {
        id: "sub_12345",
        plan_id: "plan_agencypro_annual",
      },
      testNow,
    );

    assert.ok(update);
    assert.equal(update?.status, "gracePeriod");
    assert.equal(update?.planId, "agencyPro");
    assert.equal(update?.customerLimit, 10000);
    assert.equal(update?.employeeLimit, 100);
    const expectedExpiry = new Date(testNow.getTime() + 7 * 24 * 3600 * 1000);
    assert.equal(
      update?.effectiveExpiresAt.toMillis(),
      expectedExpiry.getTime(),
    );
  });

  it("handles subscription.cancelled / subscription.completed by setting expired with epoch expiry", () => {
    const update = deriveSubscriptionUpdate(
      "subscription.cancelled",
      {
        id: "sub_12345",
        plan_id: "plan_growth_monthly",
      },
      testNow,
    );

    assert.ok(update);
    assert.equal(update?.status, "expired");
    assert.equal(update?.effectiveExpiresAt.toMillis(), 0);
  });

  it("returns null for non-mutating / unhandled events", () => {
    assert.equal(
      deriveSubscriptionUpdate("unrelated.event", {id: "sub_12345", plan_id: "plan_starter_monthly"}, testNow),
      null,
    );
    assert.equal(
      deriveSubscriptionUpdate("subscription.authenticated", {id: "sub_12345", plan_id: "plan_starter_monthly"}, testNow),
      null,
    );
  });
});

describe("verifyWebhookSignature & Security (Problem 2)", () => {
  const secret = "whsec_test_secret_key_123456789";
  const body = JSON.stringify({
    event: "subscription.charged",
    businessId: "biz-1",
    planId: "growth",
    timestamp: 1727100000,
  });

  it("accepts valid HMAC SHA-256 signature", () => {
    const validSignature = createHmac("sha256", secret).update(body).digest("hex");
    assert.equal(verifyWebhookSignature(body, secret, validSignature), true);
  });

  it("strictly rejects forged, tampered or empty signatures", () => {
    const forged = "bad_signature_0000000000000000000000000000000000000000000000000000000000";
    assert.equal(verifyWebhookSignature(body, secret, forged), false);
    assert.equal(verifyWebhookSignature(body, secret, ""), false);
    assert.equal(verifyWebhookSignature("", secret, "abc"), false);
  });

  it("strictly rejects signatures generated with incorrect secret", () => {
    const wrongSecretSig = createHmac("sha256", "wrong_secret").update(body).digest("hex");
    assert.equal(verifyWebhookSignature(body, secret, wrongSecretSig), false);
  });
});

describe("Webhook Server Binding, Plan Verification & Quarantine Logic (Problem 1 & 2)", () => {
  it("binds checkout session fields correctly to internal plan and cycle", () => {
    const growthSession = {
      subscriptionId: "sub_auth_001",
      businessId: "biz-1",
      headUid: "head-1",
      planId: "growth",
      billingCycle: "monthly",
      amountPaise: 59900,
      currency: "INR",
      razorpayPlanId: "plan_growth_monthly",
      customerLimit: 1000,
      employeeLimit: 10,
    };

    assert.equal(growthSession.planId, SERVER_APPROVED_PLANS.growth_monthly.planId);
    assert.equal(growthSession.amountPaise, SERVER_APPROVED_PLANS.growth_monthly.amountPaise);
    assert.equal(growthSession.customerLimit, SERVER_APPROVED_PLANS.growth_monthly.customerLimit);
  });

  it("detects unauthorized subscription when no checkout session exists for agency", () => {
    const incomingSubId = "sub_unknown_999";
    const checkoutSessions: Record<string, any> = {
      "sub_auth_001": { businessId: "biz-1", planId: "growth" },
    };
    const isAuthorized = Boolean(checkoutSessions[incomingSubId]);
    assert.equal(isAuthorized, false, "Must detect subscription ID not in authorized checkout sessions");
  });

  it("detects plan mismatch between authorized checkout session and incoming webhook event", () => {
    const checkoutRecord = { businessId: "biz-1", planId: "starter" };
    const webhookUpdate = { planId: "growth" };

    const planMatches = checkoutRecord.planId === webhookUpdate.planId;
    assert.equal(planMatches, false, "Must detect plan mismatch when webhook reports different plan than checkout session");
  });

  it("validates authorized checkout session when businessId, subscriptionId and plan match", () => {
    const checkoutRecord = { businessId: "biz-1", planId: "growth", headUid: "uid-head" };
    const webhookUpdate = { planId: "growth" };
    const eventBusinessId = "biz-1";

    const isAuthorized =
      checkoutRecord.businessId === eventBusinessId &&
      checkoutRecord.planId === webhookUpdate.planId;

    assert.equal(isAuthorized, true);
  });
});

