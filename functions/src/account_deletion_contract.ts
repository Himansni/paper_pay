import {HttpsError} from "firebase-functions/v2/https";

export interface RequestAccountDeletionInput {
  confirmation: string;
  reason?: string;
}

export interface AccountDeletionResult {
  success: boolean;
  status: "deleted" | "blocked_active_employees" | "blocked_active_customers";
  role: "head" | "employee" | "unassigned";
  message: string;
  businessId?: string;
}

export function parseRequestAccountDeletionInput(
  raw: unknown,
): RequestAccountDeletionInput {
  if (raw === undefined || raw === null || typeof raw !== "object" || Array.isArray(raw)) {
    throw new HttpsError(
      "invalid-argument",
      "Account deletion request must be an object with confirmation: 'DELETE'.",
    );
  }
  const data = raw as Record<string, unknown>;
  const allowedKeys = new Set(["confirmation", "reason"]);
  for (const key of Object.keys(data)) {
    if (!allowedKeys.has(key)) {
      throw new HttpsError(
        "invalid-argument",
        `Unsupported request field: ${key}. Client authority fields are rejected.`,
      );
    }
  }

  const rawConfirmation = data.confirmation;
  if (typeof rawConfirmation !== "string" || rawConfirmation !== "DELETE") {
    throw new HttpsError(
      "invalid-argument",
      "Account deletion requires exact confirmation === 'DELETE'.",
    );
  }

  const rawReason = data.reason;
  let reason: string | undefined;
  if (rawReason !== undefined && rawReason !== null) {
    if (typeof rawReason !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "Reason must be a string if provided.",
      );
    }
    reason = rawReason.trim().slice(0, 300);
  }

  return {confirmation: rawConfirmation, reason};
}
