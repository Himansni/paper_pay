import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import {readFileSync} from "node:fs";
import test from "node:test";
import {legalDocuments} from "../legal_documents";
import {parseProvisionAgencyOwnerRequest} from "../provisioning_contract";

const valid = {
  ownerDisplayName: "Owner Name",
  ownerPhone: "9999999999",
  agencyName: "Example News Agency",
  agencyPhone: "8888888888",
  agencyAddress: "10 Synthetic Road, Test City",
  termsVersion: "terms-v1",
  privacyVersion: "privacy-v1",
  locale: "en-IN",
  clientPlatform: "android",
  requestId: "123e4567-e89b-42d3-a456-426614174000",
};

test("normalizes the approved owner request contract", () => {
  const parsed = parseProvisionAgencyOwnerRequest({
    ...valid,
    ownerDisplayName: "  Owner   Name  ",
  });
  assert.equal(parsed.ownerDisplayName, "Owner Name");
  assert.deepEqual(Object.keys(parsed).sort(), Object.keys(valid).sort());
});

test("rejects client-supplied authority fields", () => {
  assert.throws(
    () => parseProvisionAgencyOwnerRequest({...valid, role: "head"}),
    /Unsupported request field: role/,
  );
  assert.throws(
    () => parseProvisionAgencyOwnerRequest({...valid, businessId: "target"}),
    /Unsupported request field: businessId/,
  );
});

test("rejects stale legal versions and malformed request IDs", () => {
  assert.throws(
    () => parseProvisionAgencyOwnerRequest({...valid, termsVersion: "old"}),
    /current Terms and Privacy Notice/,
  );
  assert.throws(
    () => parseProvisionAgencyOwnerRequest({...valid, requestId: "not-a-uuid"}),
    /requestId/,
  );
});

test("legal document hashes match the exact bundled Flutter assets", () => {
  for (const document of [legalDocuments.terms, legalDocuments.privacy]) {
    const contents = readFileSync(`../${document.assetPath}`);
    assert.equal(
      createHash("sha256").update(contents).digest("hex"),
      document.sha256,
    );
  }
});
