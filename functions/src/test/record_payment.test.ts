import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  validateRecordPaymentAuthorization,
  calculateOldestFirstAllocations,
} from "../collections/record_payment";

describe("Server-Authoritative Payment Authorization & Oldest-First Allocation Tests", () => {
  const validMember = {
    role: "employee",
    status: "active",
    areaIds: ["area-east", "area-west"],
    permissions: ["recordPayments"],
  };

  const validCustomer = {
    status: "active",
    areaId: "area-east",
    assignedEmployeeId: "emp-101",
  };

  describe("Authorization & Security Boundary", () => {
    it("1. unauthenticated caller -> DENIED", () => {
      assert.throws(
        () =>
          validateRecordPaymentAuthorization({
            uid: undefined,
            businessId: "biz-1",
            customerId: "cust-1",
            amountPaise: 5000,
            method: "cash",
            idempotencyKey: "pay-12345",
            member: validMember,
            customer: validCustomer,
          }),
        (err: any) => err.code === "unauthenticated",
      );
    });

    it("2. employee without recordPayments permission -> DENIED", () => {
      const memberNoPermission = {
        ...validMember,
        permissions: [],
      };
      assert.throws(
        () =>
          validateRecordPaymentAuthorization({
            uid: "emp-101",
            businessId: "biz-1",
            customerId: "cust-1",
            amountPaise: 5000,
            method: "cash",
            idempotencyKey: "pay-12345",
            member: memberNoPermission,
            customer: validCustomer,
          }),
        (err: any) => err.code === "permission-denied",
      );
    });

    it("3. employee assigned to customer and area with permission -> ALLOWED", () => {
      const result = validateRecordPaymentAuthorization({
        uid: "emp-101",
        businessId: "biz-1",
        customerId: "cust-1",
        amountPaise: 5000,
        method: "cash",
        idempotencyKey: "pay-12345",
        member: validMember,
        customer: validCustomer,
      });
      assert.equal(result.isHead, false);
    });

    it("4. employee assigned to wrong customer -> DENIED", () => {
      const wrongCustomer = {
        ...validCustomer,
        assignedEmployeeId: "emp-999",
      };
      assert.throws(
        () =>
          validateRecordPaymentAuthorization({
            uid: "emp-101",
            businessId: "biz-1",
            customerId: "cust-1",
            amountPaise: 5000,
            method: "cash",
            idempotencyKey: "pay-12345",
            member: validMember,
            customer: wrongCustomer,
          }),
        (err: any) => err.code === "permission-denied",
      );
    });

    it("5. employee assigned to wrong area -> DENIED", () => {
      const wrongAreaCustomer = {
        ...validCustomer,
        areaId: "area-north",
      };
      assert.throws(
        () =>
          validateRecordPaymentAuthorization({
            uid: "emp-101",
            businessId: "biz-1",
            customerId: "cust-1",
            amountPaise: 5000,
            method: "cash",
            idempotencyKey: "pay-12345",
            member: validMember,
            customer: wrongAreaCustomer,
          }),
        (err: any) => err.code === "permission-denied",
      );
    });

    it("6. employee from another business (non-member) -> DENIED", () => {
      assert.throws(
        () =>
          validateRecordPaymentAuthorization({
            uid: "emp-foreign",
            businessId: "biz-1",
            customerId: "cust-1",
            amountPaise: 5000,
            method: "cash",
            idempotencyKey: "pay-12345",
            member: null,
            customer: validCustomer,
          }),
        (err: any) => err.code === "permission-denied",
      );
    });

    it("7. Head caller -> ALLOWED for any customer in business", () => {
      const headMember = {
        role: "head",
        status: "active",
        areaIds: [],
        permissions: [],
      };
      const unassignedCustomer = {
        status: "active",
        areaId: "area-north",
        assignedEmployeeId: "emp-other",
      };
      const result = validateRecordPaymentAuthorization({
        uid: "head-admin",
        businessId: "biz-1",
        customerId: "cust-1",
        amountPaise: 5000,
        method: "cash",
        idempotencyKey: "pay-12345",
        member: headMember,
        customer: unassignedCustomer,
      });
      assert.equal(result.isHead, true);
    });

    it("8. invalid / negative / zero amount -> DENIED", () => {
      assert.throws(
        () =>
          validateRecordPaymentAuthorization({
            uid: "emp-101",
            businessId: "biz-1",
            customerId: "cust-1",
            amountPaise: -500,
            method: "cash",
            idempotencyKey: "pay-12345",
            member: validMember,
            customer: validCustomer,
          }),
        (err: any) => err.code === "invalid-argument",
      );
      assert.throws(
        () =>
          validateRecordPaymentAuthorization({
            uid: "emp-101",
            businessId: "biz-1",
            customerId: "cust-1",
            amountPaise: 0,
            method: "cash",
            idempotencyKey: "pay-12345",
            member: validMember,
            customer: validCustomer,
          }),
        (err: any) => err.code === "invalid-argument",
      );
    });

    it("9. inactive customer -> DENIED", () => {
      const inactiveCustomer = {
        ...validCustomer,
        status: "inactive",
      };
      assert.throws(
        () =>
          validateRecordPaymentAuthorization({
            uid: "emp-101",
            businessId: "biz-1",
            customerId: "cust-1",
            amountPaise: 5000,
            method: "cash",
            idempotencyKey: "pay-12345",
            member: validMember,
            customer: inactiveCustomer,
          }),
        (err: any) => err.code === "failed-precondition",
      );
    });

    it("10. invalid / unsupported payment method -> DENIED", () => {
      assert.throws(
        () =>
          validateRecordPaymentAuthorization({
            uid: "emp-101",
            businessId: "biz-1",
            customerId: "cust-1",
            amountPaise: 5000,
            method: "bitcoin",
            idempotencyKey: "pay-12345",
            member: validMember,
            customer: validCustomer,
          }),
        (err: any) => err.code === "invalid-argument",
      );
    });

    it("11. invalid / malformed idempotencyKey -> DENIED", () => {
      assert.throws(
        () =>
          validateRecordPaymentAuthorization({
            uid: "emp-101",
            businessId: "biz-1",
            customerId: "cust-1",
            amountPaise: 5000,
            method: "cash",
            idempotencyKey: "short",
            member: validMember,
            customer: validCustomer,
          }),
        (err: any) => err.code === "invalid-argument",
      );
    });
  });

  describe("Server-Authoritative Oldest-First Allocation Logic", () => {
    it("A & B: ₹50 payment with July ₹100 and August ₹209 MUST allocate July ₹50, August ₹0", () => {
      const openBills = [
        { billId: "2026-08", billingMonth: "2026-08", outstandingPaise: 20900 },
        { billId: "2026-07", billingMonth: "2026-07", outstandingPaise: 10000 },
      ];
      // Note: openBills passed in reverse order to ensure sorting works
      const allocations = calculateOldestFirstAllocations(5000, openBills);

      assert.equal(allocations.length, 1);
      assert.equal(allocations[0].billId, "2026-07");
      assert.equal(allocations[0].billingMonth, "2026-07");
      assert.equal(allocations[0].amountPaise, 5000);
    });

    it("₹150 payment with July ₹100 and August ₹209 allocates July ₹100 (full) and August ₹50 (partial)", () => {
      const openBills = [
        { billId: "2026-07", billingMonth: "2026-07", outstandingPaise: 10000 },
        { billId: "2026-08", billingMonth: "2026-08", outstandingPaise: 20900 },
      ];
      const allocations = calculateOldestFirstAllocations(15000, openBills);

      assert.equal(allocations.length, 2);
      assert.equal(allocations[0].billId, "2026-07");
      assert.equal(allocations[0].amountPaise, 10000);
      assert.equal(allocations[1].billId, "2026-08");
      assert.equal(allocations[1].amountPaise, 5000);
    });

    it("Multi-month 4-period bill draining sequentially from oldest", () => {
      const openBills = [
        { billId: "2026-04", billingMonth: "2026-04", outstandingPaise: 5000 },
        { billId: "2026-05", billingMonth: "2026-05", outstandingPaise: 5000 },
        { billId: "2026-06", billingMonth: "2026-06", outstandingPaise: 5000 },
        { billId: "2026-07", billingMonth: "2026-07", outstandingPaise: 5000 },
      ];
      const allocations = calculateOldestFirstAllocations(12000, openBills);

      assert.equal(allocations.length, 3);
      assert.equal(allocations[0].billingMonth, "2026-04");
      assert.equal(allocations[0].amountPaise, 5000);
      assert.equal(allocations[1].billingMonth, "2026-05");
      assert.equal(allocations[1].amountPaise, 5000);
      assert.equal(allocations[2].billingMonth, "2026-06");
      assert.equal(allocations[2].amountPaise, 2000);
    });

    it("Zero or settled bills are ignored", () => {
      const openBills = [
        { billId: "2026-06", billingMonth: "2026-06", outstandingPaise: 0 },
        { billId: "2026-07", billingMonth: "2026-07", outstandingPaise: 10000 },
      ];
      const allocations = calculateOldestFirstAllocations(3000, openBills);

      assert.equal(allocations.length, 1);
      assert.equal(allocations[0].billId, "2026-07");
      assert.equal(allocations[0].amountPaise, 3000);
    });
  });
});
