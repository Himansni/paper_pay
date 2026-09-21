import {HttpsError} from "firebase-functions/v2/https";
import {legalDocuments} from "./legal_documents";

export interface ProvisionAgencyOwnerRequest {
  ownerDisplayName: string;
  ownerPhone: string;
  agencyName: string;
  agencyPhone: string;
  agencyAddress: string;
  termsVersion: string;
  privacyVersion: string;
  locale: string;
  clientPlatform: "android" | "ios" | "web";
  requestId: string;
}

const allowedKeys = new Set<keyof ProvisionAgencyOwnerRequest>([
  "ownerDisplayName",
  "ownerPhone",
  "agencyName",
  "agencyPhone",
  "agencyAddress",
  "termsVersion",
  "privacyVersion",
  "locale",
  "clientPlatform",
  "requestId",
]);

function text(
  data: Record<string, unknown>,
  field: keyof ProvisionAgencyOwnerRequest,
  minimum: number,
  maximum: number,
): string {
  const value = data[field];
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} must be a string.`);
  }
  const normalized = value.trim().replace(/\s+/g, " ");
  if (normalized.length < minimum || normalized.length > maximum) {
    throw new HttpsError(
      "invalid-argument",
      `${field} must contain ${minimum}-${maximum} characters.`,
    );
  }
  return normalized;
}

export function parseProvisionAgencyOwnerRequest(
  value: unknown,
): ProvisionAgencyOwnerRequest {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "A request object is required.");
  }
  const data = value as Record<string, unknown>;
  const unexpected = Object.keys(data).filter(
    (key) => !allowedKeys.has(key as keyof ProvisionAgencyOwnerRequest),
  );
  if (unexpected.length > 0) {
    throw new HttpsError(
      "invalid-argument",
      `Unsupported request field: ${unexpected.sort()[0]}.`,
    );
  }

  const termsVersion = text(data, "termsVersion", 1, 40);
  const privacyVersion = text(data, "privacyVersion", 1, 40);
  if (
    termsVersion !== legalDocuments.terms.version ||
    privacyVersion !== legalDocuments.privacy.version
  ) {
    throw new HttpsError(
      "failed-precondition",
      "The current Terms and Privacy Notice must be accepted.",
    );
  }

  const clientPlatform = text(data, "clientPlatform", 3, 10);
  if (!["android", "ios", "web"].includes(clientPlatform)) {
    throw new HttpsError("invalid-argument", "Unsupported clientPlatform.");
  }
  const requestId = text(data, "requestId", 36, 36).toLowerCase();
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(requestId)) {
    throw new HttpsError("invalid-argument", "requestId must be a UUID v4.");
  }

  return {
    ownerDisplayName: text(data, "ownerDisplayName", 2, 100),
    ownerPhone: text(data, "ownerPhone", 7, 20),
    agencyName: text(data, "agencyName", 2, 120),
    agencyPhone: text(data, "agencyPhone", 7, 20),
    agencyAddress: text(data, "agencyAddress", 5, 300),
    termsVersion,
    privacyVersion,
    locale: text(data, "locale", 2, 35),
    clientPlatform: clientPlatform as ProvisionAgencyOwnerRequest["clientPlatform"],
    requestId,
  };
}
