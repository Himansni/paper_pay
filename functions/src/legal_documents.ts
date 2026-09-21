export const legalDocuments = {
  terms: {
    version: "terms-v1",
    assetPath: "assets/legal/paperroute_terms_v1.txt",
    sha256: "683e85126b4eeb065a00308600aa5d8069f2e692b951801f48945a7aa6c6be0b",
  },
  privacy: {
    version: "privacy-v1",
    assetPath: "assets/legal/paperroute_privacy_v1.txt",
    sha256: "5ef2621bf6916c903e700f56623c155b930252c2075e1c3396a59b8893b892cd",
  },
} as const;

export const consentAcceptanceId =
  `${legalDocuments.terms.version}__${legalDocuments.privacy.version}`;
