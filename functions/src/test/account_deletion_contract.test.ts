import assert from "node:assert/strict";
import test from "node:test";
import {
  parseRequestAccountDeletionInput,
} from "../account_deletion_contract";

test("rejects empty or missing payload", () => {
  assert.throws(
    () => parseRequestAccountDeletionInput(undefined),
    /Account deletion request must be an object with confirmation: 'DELETE'/,
  );
  assert.throws(
    () => parseRequestAccountDeletionInput(null),
    /Account deletion request must be an object with confirmation: 'DELETE'/,
  );
  assert.throws(
    () => parseRequestAccountDeletionInput({}),
    /Account deletion requires exact confirmation === 'DELETE'/,
  );
});

test("accepts exact confirmation === 'DELETE' and optional reason", () => {
  const result = parseRequestAccountDeletionInput({
    confirmation: "DELETE",
    reason: "No longer managing distribution agency.",
  });
  assert.equal(result.confirmation, "DELETE");
  assert.equal(result.reason, "No longer managing distribution agency.");

  const withoutReason = parseRequestAccountDeletionInput({
    confirmation: "DELETE",
  });
  assert.equal(withoutReason.confirmation, "DELETE");
  assert.equal(withoutReason.reason, undefined);
});

test("rejects lowercase, partial, or alternative confirmation strings", () => {
  assert.throws(
    () => parseRequestAccountDeletionInput({confirmation: "delete"}),
    /Account deletion requires exact confirmation === 'DELETE'/,
  );
  assert.throws(
    () => parseRequestAccountDeletionInput({confirmation: "CONFIRMED"}),
    /Account deletion requires exact confirmation === 'DELETE'/,
  );
  assert.throws(
    () => parseRequestAccountDeletionInput({confirmation: "Delete"}),
    /Account deletion requires exact confirmation === 'DELETE'/,
  );
  assert.throws(
    () => parseRequestAccountDeletionInput({confirmation: "DELETE "}),
    /Account deletion requires exact confirmation === 'DELETE'/,
  );
  assert.throws(
    () => parseRequestAccountDeletionInput({confirmation: 123}),
    /Account deletion requires exact confirmation === 'DELETE'/,
  );
  assert.throws(
    () => parseRequestAccountDeletionInput({confirmation: true}),
    /Account deletion requires exact confirmation === 'DELETE'/,
  );
});

test("rejects client-supplied authority or privilege fields", () => {
  assert.throws(
    () => parseRequestAccountDeletionInput({confirmation: "DELETE", role: "head"}),
    /Unsupported request field: role/,
  );
  assert.throws(
    () => parseRequestAccountDeletionInput({confirmation: "DELETE", businessId: "biz-123"}),
    /Unsupported request field: businessId/,
  );
  assert.throws(
    () => parseRequestAccountDeletionInput({confirmation: "DELETE", uid: "target-user"}),
    /Unsupported request field: uid/,
  );
  assert.throws(
    () => parseRequestAccountDeletionInput({confirmation: "DELETE", permissions: ["recordPayments"]}),
    /Unsupported request field: permissions/,
  );
});
