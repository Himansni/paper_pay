import {describe, it} from "node:test";
import assert from "node:assert/strict";
import {
  evaluateAgencySubscriptionState,
  verifyWebhookSignature,
  getSaasActivationDate,
  DEFAULT_SAAS_ACTIVATION_DATE_ISO,
} from "../saas_subscription_service";
import {
  deriveSubscriptionUpdate,
  resolveInternalPlanId,
  APPROVED_PLAN_LIMITS,
} from "../saas_webhook_handler";
import {PLAN_PRICING_PAISE} from "../saas_checkout_service";
import {createHmac} from "node:crypto";

describe("SaaS Activation Date Configuration", () => {
  it("resolves default activation date when no custom date is provided", () => {
    const defaultDate = getSaasActivationDate();
    assert.equal(defaultDate.toISOString(), DEFAULT_SAAS_ACTIVATION_DATE_ISO);
  });

  it("resolves custom Date or ISO string when provided", () => {
    const custom = new Date("2026-10-15T00:00:00.000Z");
    assert.equal(getSaasActivationDate(custom).toISOString(), "2026-10-15T00:00:00.000Z");
    assert.equal(getSaasActivationDate("2026-11-01T00:00:00.000Z").toISOString(), "2026-11-01T00:00:00.000Z");
  });
});

describe("evaluateAgencySubscriptionState", () => {
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
    // Agency created 60 days before launch
    const legacyCreatedAt = new Date("2026-07-25T00:00:00.000Z");
    // Evaluated 5 days after activation
    const now = new Date(activationDate.getTime() + 5 * 24 * 60 * 60 * 1000);

    const state = evaluateAgencySubscriptionState(
      "biz-legacy",
      legacyCreatedAt,
      undefined,
      now,
      activationDate,
    );

    assert.equal(state.status, "trial");
    // Anchored to activationDate, not legacyCreatedAt
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

describe("deriveSubscriptionUpdate (Webhook state machine)", () => {
  const testNow = new Date("2026-10-15T10:00:00.000Z");

  it("handles subscription.activated and subscription.charged", () => {
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

  it("resolves plan IDs correctly with case-insensitive matching", () => {
    assert.equal(resolveInternalPlanId("plan_starter_monthly"), "starter");
    assert.equal(resolveInternalPlanId("growth_annual"), "growth");
    assert.equal(resolveInternalPlanId("agencypro_quarterly"), "agencyPro");
    assert.equal(resolveInternalPlanId("agency-pro-plan"), "agencyPro");
    assert.equal(resolveInternalPlanId(undefined), "starter");
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

  it("returns null for unhandled events", () => {
    const update = deriveSubscriptionUpdate(
      "unrelated.event",
      {id: "sub_12345"},
      testNow,
    );
    assert.equal(update, null);
  });
});

describe("SaaS Checkout Pricing & Plan Limits", () => {
  it("enforces exact pricing table for monthly and annual plans", () => {
    assert.equal(PLAN_PRICING_PAISE.starter.monthly, 29900);
    assert.equal(PLAN_PRICING_PAISE.starter.annual, 299900);
    assert.equal(PLAN_PRICING_PAISE.growth.monthly, 59900);
    assert.equal(PLAN_PRICING_PAISE.growth.annual, 599900);
    assert.equal(PLAN_PRICING_PAISE.agencyPro.monthly, 129900);
    assert.equal(PLAN_PRICING_PAISE.agencyPro.annual, 1299900);
  });

  it("enforces approved plan limits", () => {
    assert.equal(APPROVED_PLAN_LIMITS.starter.customerLimit, 300);
    assert.equal(APPROVED_PLAN_LIMITS.growth.customerLimit, 1000);
    assert.equal(APPROVED_PLAN_LIMITS.agencyPro.customerLimit, 10000);
  });
});

describe("verifyWebhookSignature", () => {
  const secret = "whsec_test_secret_key_123456789";
  const body = JSON.stringify({
    event: "subscription.renewed",
    businessId: "biz-1",
    planId: "growth",
    timestamp: 1727100000,
  });

  it("accepts valid HMAC SHA-256 signature", () => {
    const validSignature = createHmac("sha256", secret).update(body).digest("hex");
    assert.equal(verifyWebhookSignature(body, secret, validSignature), true);
  });

  it("rejects invalid, tampered or empty signatures", () => {
    const tampered = "bad_signature_0000000000000000000000000000000000000000000000000000000000";
    assert.equal(verifyWebhookSignature(body, secret, tampered), false);
    assert.equal(verifyWebhookSignature(body, secret, ""), false);
    assert.equal(verifyWebhookSignature("", secret, "abc"), false);
  });
});
