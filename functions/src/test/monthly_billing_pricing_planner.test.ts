import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { MonthlyBillPlanner } from "../billing/monthly_bill_planner";
import { BillingTerm, Newspaper } from "../billing/billing_types";

describe("Monthly Billing Pricing Resolution & Precedence Tests", () => {
  const terms: BillingTerm[] = [
    {
      subscriptionId: "sub-1",
      versionId: "v-1",
      newspaperId: "np-1",
      quantity: 1,
      deliveryWeekdays: [1, 2, 3, 4, 5, 6, 7],
      customPricePaise: null,
      effectiveFrom: "2026-09-01",
      effectiveTo: "2026-09-30",
    },
  ];

  it("1. Global monthly price ₹209/month -> finalized bill uses ₹209/month", () => {
    const newspapers: Record<string, Newspaper> = {
      "np-1": {
        newspaperId: "np-1",
        name: "Morning Post",
        defaultPricePaise: 500,
        rules: [
          {
            ruleId: "rule-global-209",
            revision: 1,
            startDate: "2026-01-01",
            endDate: "2026-12-31",
            isExactDate: false,
            pricingBasis: "monthly",
            pricePaise: 20900,
          },
        ],
      },
    };

    const lines = MonthlyBillPlanner.calculate(
      "cust-1",
      "2026-09",
      terms,
      [],
      [],
      newspapers
    );

    assert.equal(lines.length, 1);
    assert.equal(lines[0].unitPricePaise, 20900);
    assert.equal(lines[0].totalPaise, 20900);
    assert.equal(lines[0].priceSourceId, "rule-global-209");
  });

  it("2. Billing-only price ₹199/month overrides global ₹209/month", () => {
    const newspapers: Record<string, Newspaper> = {
      "np-1": {
        newspaperId: "np-1",
        name: "Morning Post",
        defaultPricePaise: 500,
        rules: [
          // Prepend monthly billing price snapshot
          {
            ruleId: "monthly_snapshot_2026-09_np-1",
            revision: 999999,
            startDate: "2026-09-01",
            endDate: "2026-09-30",
            isExactDate: false,
            pricingBasis: "monthly",
            pricePaise: 19900,
          },
          // Global rule
          {
            ruleId: "rule-global-209",
            revision: 1,
            startDate: "2026-01-01",
            endDate: "2026-12-31",
            isExactDate: false,
            pricingBasis: "monthly",
            pricePaise: 20900,
          },
        ],
      },
    };

    const lines = MonthlyBillPlanner.calculate(
      "cust-1",
      "2026-09",
      terms,
      [],
      [],
      newspapers
    );

    assert.equal(lines.length, 1);
    assert.equal(lines[0].unitPricePaise, 19900);
    assert.equal(lines[0].totalPaise, 19900);
    assert.equal(lines[0].priceSourceId, "monthly_snapshot_2026-09_np-1");
  });

  it("3. Different month (2026-10) without snapshot falls back to global price ₹209", () => {
    const octTerms: BillingTerm[] = [
      {
        subscriptionId: "sub-1",
        versionId: "v-1",
        newspaperId: "np-1",
        quantity: 1,
        deliveryWeekdays: [1, 2, 3, 4, 5, 6, 7],
        customPricePaise: null,
        effectiveFrom: "2026-10-01",
        effectiveTo: "2026-10-31",
      },
    ];

    const newspapers: Record<string, Newspaper> = {
      "np-1": {
        newspaperId: "np-1",
        name: "Morning Post",
        defaultPricePaise: 500,
        rules: [
          {
            ruleId: "rule-global-209",
            revision: 1,
            startDate: "2026-01-01",
            endDate: "2026-12-31",
            isExactDate: false,
            pricingBasis: "monthly",
            pricePaise: 20900,
          },
        ],
      },
    };

    const lines = MonthlyBillPlanner.calculate(
      "cust-1",
      "2026-10",
      octTerms,
      [],
      [],
      newspapers
    );

    assert.equal(lines.length, 1);
    assert.equal(lines[0].unitPricePaise, 20900);
    assert.equal(lines[0].totalPaise, 20900);
    assert.equal(lines[0].priceSourceId, "rule-global-209");
  });

  it("4. Customer custom price overrides both global and billing-only snapshot", () => {
    const customTerms: BillingTerm[] = [
      {
        subscriptionId: "sub-1",
        versionId: "v-1",
        newspaperId: "np-1",
        quantity: 1,
        deliveryWeekdays: [1, 2, 3, 4, 5, 6, 7],
        customPricePaise: 15000,
        effectiveFrom: "2026-09-01",
        effectiveTo: "2026-09-30",
      },
    ];

    const newspapers: Record<string, Newspaper> = {
      "np-1": {
        newspaperId: "np-1",
        name: "Morning Post",
        defaultPricePaise: 500,
        rules: [
          {
            ruleId: "monthly_snapshot_2026-09_np-1",
            revision: 999999,
            startDate: "2026-09-01",
            endDate: "2026-09-30",
            isExactDate: false,
            pricingBasis: "monthly",
            pricePaise: 19900,
          },
        ],
      },
    };

    const lines = MonthlyBillPlanner.calculate(
      "cust-1",
      "2026-09",
      customTerms,
      [],
      [],
      newspapers
    );

    assert.equal(lines.length, 1);
    assert.equal(lines[0].unitPricePaise, 15000);
    assert.equal(lines[0].priceSource, "customerSpecific");
  });
});
