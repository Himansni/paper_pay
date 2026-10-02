import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { validateFinalizeBillAuthorization } from "../billing/finalize_bill";

describe("finalizeMonthlyBill Authorization & Boundary Tests", () => {
  const validMember = {
    role: "employee",
    status: "active",
    areaIds: ["area-north", "area-east"],
    permissions: ["allowManualBilling"],
  };

  const validCustomer = {
    status: "active",
    areaId: "area-north",
    assignedEmployeeId: "emp-123",
  };

  it("1. unauthenticated caller -> DENIED", () => {
    assert.throws(
      () =>
        validateFinalizeBillAuthorization({
          uid: undefined,
          businessId: "biz-1",
          customerId: "cust-1",
          billingMonth: "2026-09",
          member: validMember,
          customer: validCustomer,
        }),
      (err: any) => err.code === "unauthenticated" || /unauthenticated/.test(err.message),
    );
  });

  it("2. employee without allowManualBilling -> DENIED", () => {
    const memberNoBilling = {
      ...validMember,
      permissions: [],
    };
    assert.throws(
      () =>
        validateFinalizeBillAuthorization({
          uid: "emp-123",
          businessId: "biz-1",
          customerId: "cust-1",
          billingMonth: "2026-09",
          member: memberNoBilling,
          customer: validCustomer,
        }),
      (err: any) => err.code === "permission-denied",
    );
  });

  it("3. employee assigned to customer and area with permission -> ALLOWED", () => {
    const result = validateFinalizeBillAuthorization({
      uid: "emp-123",
      businessId: "biz-1",
      customerId: "cust-1",
      billingMonth: "2026-09",
      member: validMember,
      customer: validCustomer,
    });
    assert.equal(result.isHead, false);
    assert.equal(result.hasManualBilling, true);
  });

  it("4. employee assigned to wrong customer -> DENIED", () => {
    const otherCustomer = {
      ...validCustomer,
      assignedEmployeeId: "emp-456", // Different employee
    };
    assert.throws(
      () =>
        validateFinalizeBillAuthorization({
          uid: "emp-123",
          businessId: "biz-1",
          customerId: "cust-1",
          billingMonth: "2026-09",
          member: validMember,
          customer: otherCustomer,
        }),
      (err: any) => err.code === "permission-denied",
    );
  });

  it("5. employee assigned to wrong area -> DENIED", () => {
    const customerDifferentArea = {
      ...validCustomer,
      areaId: "area-south", // Not in member.areaIds
    };
    assert.throws(
      () =>
        validateFinalizeBillAuthorization({
          uid: "emp-123",
          businessId: "biz-1",
          customerId: "cust-1",
          billingMonth: "2026-09",
          member: validMember,
          customer: customerDifferentArea,
        }),
      (err: any) => err.code === "permission-denied",
    );
  });

  it("6. employee from another business (non-member) -> DENIED", () => {
    assert.throws(
      () =>
        validateFinalizeBillAuthorization({
          uid: "emp-foreign",
          businessId: "biz-1",
          customerId: "cust-1",
          billingMonth: "2026-09",
          member: null, // Not a member of biz-1
          customer: validCustomer,
        }),
      (err: any) => err.code === "permission-denied",
    );
  });

  it("7. Head caller -> ALLOWED (even if unassigned)", () => {
    const headMember = {
      role: "head",
      status: "active",
      areaIds: [],
      permissions: [],
    };
    const unassignedCustomer = {
      status: "active",
      areaId: "any-area",
      assignedEmployeeId: "emp-999",
    };
    const result = validateFinalizeBillAuthorization({
      uid: "head-admin",
      businessId: "biz-1",
      customerId: "cust-1",
      billingMonth: "2026-09",
      member: headMember,
      customer: unassignedCustomer,
    });
    assert.equal(result.isHead, true);
  });

  it("8. missing/forged businessId parameter -> DENIED", () => {
    assert.throws(
      () =>
        validateFinalizeBillAuthorization({
          uid: "emp-123",
          businessId: "",
          customerId: "cust-1",
          billingMonth: "2026-09",
          member: validMember,
          customer: validCustomer,
        }),
      (err: any) => err.code === "invalid-argument",
    );
  });

  it("9. non-existent / forged customerId -> DENIED (not-found)", () => {
    assert.throws(
      () =>
        validateFinalizeBillAuthorization({
          uid: "emp-123",
          businessId: "biz-1",
          customerId: "forged-customer-999",
          billingMonth: "2026-09",
          member: validMember,
          customer: null, // Customer not found
        }),
      (err: any) => err.code === "not-found",
    );
  });

  it("10. inactive customer -> DENIED (failed-precondition)", () => {
    const inactiveCustomer = {
      ...validCustomer,
      status: "inactive",
    };
    assert.throws(
      () =>
        validateFinalizeBillAuthorization({
          uid: "emp-123",
          businessId: "biz-1",
          customerId: "cust-1",
          billingMonth: "2026-09",
          member: validMember,
          customer: inactiveCustomer,
        }),
      (err: any) => err.code === "failed-precondition",
    );
  });
});
