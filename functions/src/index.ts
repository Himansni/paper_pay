import {initializeApp} from "firebase-admin/app";
import {setGlobalOptions} from "firebase-functions/v2";
import {onCall} from "firebase-functions/v2/https";
import {ownerProvisioningRuntime} from "./environment";
import {
  getAgencyRegistrationOptionsHandler,
  provisionAgencyOwnerHandler,
} from "./provision_agency_owner";

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
