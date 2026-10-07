export const legalDocuments = {
  terms: {
    version: "terms-v1",
    assetPath: "assets/legal/paperroute_terms_v1.txt",
    sha256: "a5207c141927d174c6ab19ee73be1728d0b7473c4f59a868377f2af7f5437083",
  },
  privacy: {
    version: "privacy-v1",
    assetPath: "assets/legal/paperroute_privacy_v1.txt",
    sha256: "d0c63aebe321016df075dbbb0956ffcdbc0e43cbb1777bdfc66f585843bfa1ad",
  },
} as const;

export const consentAcceptanceId =
  `${legalDocuments.terms.version}__${legalDocuments.privacy.version}`;
