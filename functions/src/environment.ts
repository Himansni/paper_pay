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

/**
 * Positively identifies whether the current runtime environment is a local emulator
 * or an explicitly approved development project ("paperroutedev").
 * Unsafe negative project-ID comparisons (e.g. `!== "..."`) are strictly prohibited.
 */
export function isExplicitDevOrEmulatorEnvironment(): boolean {
  const projectId =
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    "";
  const isEmulator =
    process.env.FUNCTIONS_EMULATOR === "true" ||
    Boolean(process.env.FIREBASE_EMULATOR_HUB);
  const isDevProject = projectId === "paperroutedev";
  return isEmulator || isDevProject;
}

/**
 * Checks if simulated checkout is permitted.
 * Simulation is ONLY permitted when:
 * 1. An explicit Development or local emulator environment is positively identified, AND
 * 2. Simulation has been deliberately enabled via ALLOW_SIMULATED_CHECKOUT === "true".
 * In Production or any unverified environment, this strictly returns false.
 */
export function isSimulatedCheckoutPermitted(): boolean {
  if (!isExplicitDevOrEmulatorEnvironment()) {
    return false;
  }
  return process.env.ALLOW_SIMULATED_CHECKOUT === "true";
}

/**
 * Resolves the Razorpay webhook signing secret.
 * Deployed functions require a securely configured RAZORPAY_WEBHOOK_SECRET and fail closed (return null)
 * if unconfigured, even in Development.
 * Public or hardcoded fallback secrets in code are strictly prohibited in deployed environments.
 */
export function getWebhookSigningSecret(): string | null {
  if (process.env.RAZORPAY_WEBHOOK_SECRET) {
    return process.env.RAZORPAY_WEBHOOK_SECRET;
  }
  // Fail closed if unconfigured
  return null;
}



