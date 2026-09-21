# Create Agency Account

## Status and deployment boundary

Create Agency Account is implemented for local Firebase Auth, Firestore, and
Functions emulators only. No Firebase project, billing plan, App Check policy,
or production data is changed by this implementation. A real deployment needs
separate founder approval at the boundary described below.

## Product flow

1. The signed-out user enters owner name/phone, agency name/phone/address,
   email/password, and accepts `terms-v1` plus `privacy-v1`.
2. Firebase Auth creates the identity and sends email verification. The form
   draft exists only in Riverpod memory; it is not written as unfinished PII.
3. After verification, the callable options check reports trusted conflicts
   and valid pending employee invitations.
4. A pending invitation presents an explicit choice: accept it as an employee,
   or create an independent agency. It never grants Head authority and the
   owner path does not consume or change it.
5. The verified owner submits agency setup. A trusted callable derives UID and
   email from Admin Auth, validates the exact request allowlist and legal
   versions, then creates the complete agency atomically.
6. The existing Auth/profile/membership stream observes the new authoritative
   membership and opens the Head workspace.

If the app restarts before provisioning, the user signs in, verifies email if
needed, and re-enters the non-persisted agency form. If the callable committed
but the response was lost, the private owner registry makes a retry return the
same business rather than creating another.

## Callable contracts

`getAgencyRegistrationOptions` accepts no identity or authority input. It
returns `eligible`, `alreadyProvisioned`, or `blocked`, plus only a pending
invitation boolean/count and a controlled conflict code.

`provisionAgencyOwner` accepts exactly:

- `ownerDisplayName`, `ownerPhone`
- `agencyName`, `agencyPhone`, `agencyAddress`
- `termsVersion`, `privacyVersion`
- `locale`, `clientPlatform`, `requestId` (UUID v4)

UID and email come only from verified Admin Auth. The callable rejects unknown
keys, including client-supplied `uid`, `email`, `businessId`, `ownerId`, `role`,
`status`, `permissions`, or `areaIds`.

## Atomic records

One successful transaction creates:

- `businesses/{randomBusinessId}`: `businessId`, Auth-derived `ownerId`, agency
  name/phone/address, and server timestamps.
- `businesses/{businessId}/members/{uid}`: Auth-derived identity, `role: head`,
  `status: active`, empty permissions/area arrays, and server timestamps.
- `userProfiles/{uid}`: the routing projection for the same business and Head.
- `agencyOwners/{uid}`: private business/idempotency/consent/request metadata.
- `userConsents/{uid}/acceptances/terms-v1__privacy-v1`: immutable versions,
  legal asset paths and hashes, locale/platform/request ID, and acceptance time.
- `businesses/{businessId}/auditRecords/agencyProvisioned-{uid}`: append-only,
  non-PII provisioning audit.

Membership is the sole runtime authority. `agencyOwners` cannot authorize any
business operation. Existing manually bootstrapped Heads are grandfathered and
are never required to have a registry or historical consent record.

## Conflict and abuse policy

Any existing profile, membership, accepted employee invitation for the same
verified identity, or inconsistent partial trusted state fails closed. A valid
pending invitation is only a choice; expired/revoked invitations grant nothing.

The backend keeps client-inaccessible `agencyProvisioningControls/{uid}` state.
Options are limited to 10 attempts per 15 minutes and provisioning to 5 per 15
minutes, followed by a 30-minute cooldown. Limit failures return
`resource-exhausted` with a bounded retry delay. Runtime configuration uses
zero minimum instances, two maximum instances, 20 concurrency, 30 seconds, and
256 MiB. Logs exclude names, email, phones, addresses, tokens, passwords,
legal text, and request payloads. App Check enforcement remains off under the
existing rollout policy. Rate-limit warnings contain only a one-way UID hash,
operation kind, and retry delay. Before release, monitor callable error and
`resource-exhausted` rates in the existing Firebase/Cloud Logging views and
configure a project budget alert; neither requires another runtime service.

## Required deployment order (not yet approved)

1. Perform a read-only compatibility inventory in the selected Firebase
   project.
2. Obtain approval and deploy only the two reviewed index field overrides;
   wait until ready.
3. Obtain approval and deploy only the reviewed Firestore Rules.
4. Obtain explicit founder approval to enable Blaze/Functions.
5. Deploy only `getAgencyRegistrationOptions` and `provisionAgencyOwner`, then
   run a controlled synthetic non-production smoke test.

Do not expose the real registration entry point before steps 1–5 are complete.

# Legal release status

The bundled Terms and Privacy documents are development drafts. Final Terms and Privacy copy requires founder/legal approval before enabling agency registration in any shipped release. Existing Heads are not retroactively required to accept these documents.
