import {describe, it} from "node:test";
import assert from "node:assert/strict";
import {
  evaluateAgencySubscriptionState,
  verifyWebhookSignature,
  SAAS_LAUNCH_DATE,
} from "../saas_subscription_service";
import {
  deriveSubscriptionUpdate,
} from "../saas_webhook_handler";
import {createHmac} from "node:crypto";

describe("evaluateAgencySubscriptionState", () => {
  const postLaunchTime = new Date("2026-10-01T00:00:00.000Z");

  it("newly activated agency after launch receives exact 30-day trial starting at activation", () => {
    const activation = new Date("2026-10-01T00:00:00.000Z");
    const now = new Date("2026-10-01T12:00:00.000Z");

    const state = evaluateAgencySubscriptionState(
      "biz-1",
      activation,
      undefined,
      now,
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

  it("legacy agency created before launch has trial anchored to SAAS_LAUNCH_DATE (migration policy)", () => {
    // Agency created 60 days before launch
    const legacyCreatedAt = new Date("2026-07-25T00:00:00.000Z");
    // Evaluated 5 days after launch
    const now = new Date(SAAS_LAUNCH_DATE.getTime() + 5 * 24 * 60 * 60 * 1000);

    const state = evaluateAgencySubscriptionState(
      "biz-legacy",
      legacyCreatedAt,
      undefined,
      now,
    );

    assert.equal(state.status, "trial");
    // Anchored to SAAS_LAUNCH_DATE, not legacyCreatedAt
    assert.equal(state.trialStartsAt.toISOString(), SAAS_LAUNCH_DATE.toISOString());
    assert.equal(
      state.trialEndsAt.toISOString(),
      new Date(SAAS_LAUNCH_DATE.getTime() + 30 * 24 * 60 * 60 * 1000).toISOString(),
    );
    assert.equal(state.daysRemaining, 25);
    assert.equal(state.isReadOnly, false);
  });

  it("post-launch agency with historical createdAt never receives duplicate trial", () => {
    // Agency created 25 days before current time, post launch
    const createdAt = new Date("2026-10-01T00:00:00.000Z");
    const now = new Date("2026-10-26T00:00:00.000Z");

    const state = evaluateAgencySubscriptionState(
      "biz-existing",
      createdAt,
      undefined,
      now,
    );

    assert.equal(state.status, "trial");
    assert.equal(state.trialStartsAt.toISOString(), createdAt.toISOString());
    // Only 5 days remain, NOT 30
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
    );

    assert.equal(state.status, "trial");
    assert.equal(state.trialStartsAt.toISOString(), originalTrialStart.toISOString());
    assert.equal(state.trialEndsAt.toISOString(), originalTrialEnd.toISOString());
    assert.equal(state.daysRemaining, 11);
    assert.equal(state.isReadOnly, false);
  });

  it("agency enters 7-day grace period immediately when trial expires", () => {
    // Agency created on postLaunchTime, evaluated 32 days later (2 days into grace)
    const createdAt = postLaunchTime;
    const now = new Date(postLaunchTime.getTime() + 32 * 24 * 60 * 60 * 1000);

    const state = evaluateAgencySubscriptionState(
      "biz-grace",
      createdAt,
      undefined,
      now,
    );

    assert.equal(state.status, "gracePeriod");
    assert.equal(state.daysRemaining, 0);
    assert.equal(state.graceDaysRemaining, 5);
    // Writes are still allowed during grace period
    assert.equal(state.isReadOnly, false);
  });

  it("agency switches to read-only mode after trial + grace period expires", () => {
    // Agency created on postLaunchTime, evaluated 40 days later (30 trial + 7 grace = 37, 3 days expired)
    const createdAt = postLaunchTime;
    const now = new Date(postLaunchTime.getTime() + 40 * 24 * 60 * 60 * 1000);

    const state = evaluateAgencySubscriptionState(
      "biz-expired",
      createdAt,
      undefined,
      now,
    );

    assert.equal(state.status, "expired");
    assert.equal(state.daysRemaining, 0);
    assert.equal(state.graceDaysRemaining, 0);
    assert.equal(state.isReadOnly, true);
    // effectiveExpiresAt is in the past
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
    assert.ok(update?.effectiveExpiresAt);
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
    assert.equal(update?.effectiveExpiresAt.toMillis(), 0); // epoch = immediately expired in rules
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
