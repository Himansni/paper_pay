import {describe, it} from "node:test";
import assert from "node:assert/strict";
import {
  evaluateAgencySubscriptionState,
  verifyWebhookSignature,
} from "../saas_subscription_service";
import {createHmac} from "node:crypto";

describe("evaluateAgencySubscriptionState", () => {
  const baseTime = new Date("2026-09-01T00:00:00.000Z");

  it("newly activated agency receives exact 30-day trial starting at activation", () => {
    const activation = new Date("2026-09-01T00:00:00.000Z");
    const now = new Date("2026-09-01T12:00:00.000Z");

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
  });

  it("existing agency with historical createdAt never receives duplicate trial", () => {
    // Agency was activated 25 days ago
    const createdAt = new Date(baseTime.getTime() - 25 * 24 * 60 * 60 * 1000);
    const now = baseTime;

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

  it("agency enters 7-day grace period immediately when trial expires", () => {
    // Agency activated 32 days ago (trial expired 2 days ago, within 7 day grace)
    const createdAt = new Date(baseTime.getTime() - 32 * 24 * 60 * 60 * 1000);
    const now = baseTime;

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
    // Agency activated 40 days ago (30 days trial + 7 days grace = 37 days, now 40)
    const createdAt = new Date(baseTime.getTime() - 40 * 24 * 60 * 60 * 1000);
    const now = baseTime;

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
  });

  it("active paid subscription overrides trial and maintains write access", () => {
    const createdAt = new Date(baseTime.getTime() - 60 * 24 * 60 * 60 * 1000);
    const currentPeriodStart = new Date(baseTime.getTime() - 10 * 24 * 60 * 60 * 1000);
    const currentPeriodEnd = new Date(baseTime.getTime() + 20 * 24 * 60 * 60 * 1000);

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
      baseTime,
    );

    assert.equal(state.status, "active");
    assert.equal(state.planId, "growth");
    assert.equal(state.daysRemaining, 20);
    assert.equal(state.isReadOnly, false);
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
