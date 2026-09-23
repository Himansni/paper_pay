export const functionRegion = "asia-south1";

export const ownerProvisioningRuntime = {
  region: functionRegion,
  memory: "256MiB" as const,
  timeoutSeconds: 30,
  minInstances: 0,
  maxInstances: 2,
  concurrency: 20,
  enforceAppCheck: false,
};

export const provisionRateLimit = {
  maximumAttempts: 5,
  windowMilliseconds: 15 * 60 * 1000,
  cooldownMilliseconds: 30 * 60 * 1000,
};

export const optionsRateLimit = {
  maximumAttempts: 10,
  windowMilliseconds: 15 * 60 * 1000,
  cooldownMilliseconds: 30 * 60 * 1000,
};

export const deletionRateLimit = {
  maximumAttempts: 3,
  windowMilliseconds: 15 * 60 * 1000,
  cooldownMilliseconds: 60 * 60 * 1000,
};

export const accountDeletionRuntime = {
  region: functionRegion,
  memory: "256MiB" as const,
  timeoutSeconds: 30,
  minInstances: 0,
  maxInstances: 2,
  concurrency: 20,
  enforceAppCheck: false,
};

/**
 * Runtime config for the Razorpay payment webhook HTTP handler.
 * Higher maxInstances to handle burst traffic on billing cycle days.
 * enforceAppCheck is false because Razorpay is an external server, not a
 * Firebase client and cannot send App Check tokens.
 */
export const webhookRuntime = {
  region: functionRegion,
  memory: "256MiB" as const,
  timeoutSeconds: 30,
  minInstances: 0,
  maxInstances: 10,
  concurrency: 40,
  enforceAppCheck: false,
};

