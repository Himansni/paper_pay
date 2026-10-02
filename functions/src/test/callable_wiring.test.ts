import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { finalizeMonthlyBill, recordPayment } from "../index";

describe("Cloud Functions Callable Wiring & Export Verification", () => {
  it("finalizeMonthlyBill is exported as an onCall Cloud Function in asia-south1", () => {
    assert.ok(finalizeMonthlyBill);
    assert.equal(typeof finalizeMonthlyBill, "function");
    assert.equal(finalizeMonthlyBill.__endpoint?.platform, "gcfv2");
    assert.deepEqual(finalizeMonthlyBill.__endpoint?.region, ["asia-south1"]);
  });

  it("recordPayment is exported as an onCall Cloud Function in asia-south1", () => {
    assert.ok(recordPayment);
    assert.equal(typeof recordPayment, "function");
    assert.equal(recordPayment.__endpoint?.platform, "gcfv2");
    assert.deepEqual(recordPayment.__endpoint?.region, ["asia-south1"]);
  });
});
