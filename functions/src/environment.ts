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
