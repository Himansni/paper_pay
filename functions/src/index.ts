import {initializeApp} from "firebase-admin/app";
import {setGlobalOptions} from "firebase-functions/v2";
import {onCall, onRequest} from "firebase-functions/v2/https";
import {
  accountDeletionRuntime,
  ownerProvisioningRuntime,
  webhookRuntime,
} from "./environment";
import {
  getAgencyRegistrationOptionsHandler,
  provisionAgencyOwnerHandler,
} from "./provision_agency_owner";
import {requestAccountDeletionHandler} from "./account_deletion";
import {razorpayWebhookHandler} from "./saas_webhook_handler";

initializeApp();
setGlobalOptions(ownerProvisioningRuntime);

export const getAgencyRegistrationOptions = onCall(
  ownerProvisioningRuntime,
  getAgencyRegistrationOptionsHandler,
);

export const provisionAgencyOwner = onCall(
  ownerProvisioningRuntime,
  provisionAgencyOwnerHandler,
);

export const requestAccountDeletion = onCall(
  accountDeletionRuntime,
  requestAccountDeletionHandler,
);

/**
 * Razorpay payment webhook endpoint.
 * Receives subscription lifecycle events from Razorpay, verifies the
 * HMAC-SHA256 signature, and idempotently updates the agency's SaaS
 * subscription state in Firestore.
 *
 * Configure in the Razorpay Dashboard → Webhooks → Add New Webhook.
 * Set the webhook secret and configure the endpoint URL after deployment.
 * Required events: subscription.activated, subscription.charged,
 *   subscription.halted, subscription.cancelled, subscription.completed,
 *   payment.failed.
 */
export const razorpayWebhook = onRequest(
  webhookRuntime,
  razorpayWebhookHandler,
);
