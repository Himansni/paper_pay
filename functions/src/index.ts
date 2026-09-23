import {initializeApp} from "firebase-admin/app";
import {setGlobalOptions} from "firebase-functions/v2";
import {onCall} from "firebase-functions/v2/https";
import {
  accountDeletionRuntime,
  ownerProvisioningRuntime,
} from "./environment";
import {
  getAgencyRegistrationOptionsHandler,
  provisionAgencyOwnerHandler,
} from "./provision_agency_owner";
import {requestAccountDeletionHandler} from "./account_deletion";

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
