# Privacy and operations

This is an operational baseline, not legal advice or a claim of compliance.
The business owner should obtain advice appropriate to their location and use.

## Data handling and retention

- Collect only information needed for delivery, billing, and collection. Limit
  employee permissions and area assignments; disable access promptly when work
  ends. Disabling membership is authoritative even if an Auth account remains.
- GPS is optional. Record coordinates only after the customer consents; retain
  the consent flag with the coordinates. Delivery notes should identify the
  house without including unrelated sensitive information.
- Archive customers and catalog entries instead of deleting history. Retain
  finalized bills, line snapshots, payment allocations, payments, reversals,
  price revisions, subscription versions, and audit records as immutable
  business records. A deletion request may therefore require restricted access
  or permitted redaction instead of deleting financial history; review each case.
- Define and document an owner-approved retention period for inactive customer
  contact/location details. The app currently does not automate retention or
  deletion.
- Exports contain personal and financial data. Generate only for authorized
  Head users, store encrypted, share through an approved channel, and delete
  working copies when no longer needed.

## Incident response and recovery

1. Disable affected member access, pause financial operations if ledger truth is
   uncertain, preserve logs/evidence, and record the time and scope.
2. Rotate compromised passwords, Firebase/Google administrator sessions, CI
   secrets, and Android upload credentials as applicable. Revoke old access;
   never edit immutable ledger documents to hide an incident.
3. Compare deployed rules/indexes and app version with the verified Git release.
   Follow the rollback runbook and record all trusted migrations.
4. Notify affected people and authorities only according to applicable advice;
   do not make unverified legal claims.

Use least-privilege Google/Firebase roles and at least two protected project
owners. Secure owner accounts with MFA and recovery methods. Periodically test
project access recovery.

Firestore backup/export availability, retention, restore behavior, location,
and cost depend on the selected plan and current Firebase/Google Cloud terms.
No paid backup is enabled. Before launch, the owner must choose an approved,
tested backup approach or explicitly accept the recovery limitation. Any restore
must use an isolated project first to validate tenant boundaries and immutable
financial records before production cutover.
