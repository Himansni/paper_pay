# Firestore schema

All monetary values are integer paise. Timestamps are server timestamps. Delivery/billing dates use `YYYY-MM-DD` strings and month keys use `YYYY-MM`.

```text
userProfiles/{uid}
businesses/{businessId}
  members/{uid}
  invitations/{invitationId}
  areas/{areaId}
  customers/{customerId}
    subscriptions/{subscriptionId}
      versions/{versionId}
      pauses/{pauseId}
    deliveryExceptions/{exceptionId}
    billingSources/service
    bills/{monthKey}
      lineItems/{chargeKey}
    billingControls/{monthKey}
    adjustments/{adjustmentId}
    collectionState/current
    billBalances/{monthKey}
    payments/{paymentId}
    paymentStates/{paymentId}
    paymentReversals/{reversalId}
  newspapers/{newspaperId}
    priceRules/{priceRuleId}
  configuration/upi
  monthlySummaries/{monthKey}
  auditRecords/{auditId}
```

## Identity and tenancy

`userProfiles/{uid}` is a small self-readable routing projection: UID, email, display name, phone, business ID, role, status, permissions, accepted invite ID, and timestamps. It is not queryable by other clients.

`businesses/{businessId}/members/{uid}` is the authorization source used by Security Rules. It also stores assigned area IDs and notes. A role is immutable after creation. Disabling a member changes status; the historical member is not deleted.

`invitations/{invitationId}` stores exact normalized email, fixed employee role, permissions, area IDs, pending/accepted/revoked status, creator, expiry, and acceptance metadata. The document ID is the one-time invitation code. Only the exact verified email can accept it.

## Areas and customers

An area stores name, active status, assigned employee IDs, and timestamps. Head assignment writes update both the area's `assignedEmployeeIds` and each affected member's authoritative `areaIds` in one batch. Areas are archived as inactive instead of hard-deleted.

A Phase 3 customer document is strict and stores these operational and denormalized query fields:

- `businessId`; stable `customerCode` equal to the document ID
- `name`, `searchName`, `phone`, `searchPhone`, and optional `alternatePhone`
- `address`, `areaId`, `landmark`, `searchLandmark`, `houseNumber`, `buildingInfo`, and `locationNotes`
- bounded `searchTokens` for normalized name, phone, alternate phone, and landmark prefixes
- `locationConsent` and either a `{latitude, longitude}` `coordinates` map or `null`
- `assignedEmployeeId`, which may be empty for an unassigned Head-managed customer
- `status` (`active` or `archived`) and reserved `subscriptionStatus: notConfigured`
- `deliveryPreferences.placement` and `billingPreferences.cycle`
- Head-authorized `openingBalancePaise`, which is immutable after creation
- `notes`, `createdBy`, `updatedBy`, `lastAuditId`, `createdAt`, and `updatedAt`

Customer IDs use a full random UUID-derived code such as `C-...`. Creation is accepted only when the path does not already exist; a collision is evaluated as an update and rejected by immutable-field rules, so an existing customer cannot be overwritten.

Customer assignment or transfer changes only the current `assignedEmployeeId`, `areaId`, `updatedBy`, `lastAuditId`, and `updatedAt`; bills, subscriptions, payments, and audit history remain attached to the same stable customer. The selected employee must be active and authorized for the selected area. Lifecycle changes archive/reactivate the document and never delete it.

Phase 2 writes append `auditRecords` for business settings, invitations, member access, and area lifecycle/coverage. Phase 3 customer creation, profile edits, assignment transfers, archive, and reactivation update `lastAuditId` and create their matching audit document in the same atomic write. Customer audits record the actor, action, entity, timestamp, and action-specific assignment, area, opening-balance, or changed-field metadata. Audit records cannot be updated or deleted by clients.

## Customer authorization and queries

Heads can read every customer in their active business. Employees can read only active-business records whose `assignedEmployeeId` equals their authenticated UID. Employees with `addCustomers` may create only a zero-opening-balance record assigned to themselves in an area listed by their authoritative member document. Employees with `editAssignedCustomers` may edit only permitted profile fields of their active, currently assigned customers. Tenant ownership, stable code, assignment, status, subscription placeholder, opening balance, creator, and creation timestamp remain immutable in that workflow.

Directories use pages of 25 records, with a maximum repository page size of 50. The cursor contains the stored `searchName` and document ID, matching the two query order clauses. Name, phone, and landmark searches use a single normalized prefix token with `array-contains`; customer-code lookup uses exact equality; area search uses the `areaId` filter. Employee queries always include their assignment UID and all queries include tenant and status constraints.

## Catalog, prices, and subscriptions

A newspaper uses a stable random `N-...` document/code and stores `businessId`, `newspaperCode`, name, normalized `searchName`, optional edition/language, immutable initial `defaultPricePaise`, active/archived status, creator/updater, `lastAuditId`, and timestamps. Catalog pages are tenant- and status-constrained, ordered by normalized name and document ID, and use a cursor; code lookup is an exact tenant/status-constrained query. Archiving never deletes pricing or subscription references.

`newspapers/{newspaperId}/priceRules/{priceRuleId}` is append-preserving price history. A rule stores tenant/newspaper IDs, kind (`exactDate` or `period`), inclusive `startDate`/`endDate` strings, integer `pricePaise`, reason, active/superseded status, revision and predecessor/replacement IDs, actor/audit IDs, and timestamps. Exact-date rules outrank periods, which outrank the newspaper default. Active periods may not overlap. Corrections create a new revision and supersede the previous rule atomically; existing records are never silently overwritten. Finalized bills in Phase 5 will snapshot resolved prices and will not recalculate after later corrections.

`customers/{customerId}/subscriptions/{newspaperId}` is one stable series for a customer's newspaper, allowing multiple different newspapers per customer. It stores the current version/pause references and current projection: newspaper snapshot, active/paused/ended status, start/end and current-effective dates, quantity, delivery weekdays, optional Head-only custom price and reason, immutable ownership/creator fields, updater/audit IDs, and timestamps.

Each terms change or restart writes a new `versions/{versionId}` and closes the prior current version with predecessor/successor links and effective bounds. `pauses/{pauseId}` stores finite scheduled service exceptions or the one current open pause; resuming closes that pause. Series, versions, pauses, and matching `auditRecords` are retained rather than deleted. Employees require an active assigned customer, coverage of the customer's current area, and `manageAssignedSubscriptions`; only Heads may set custom prices or administer shared catalog pricing.

`billingSources/service` is a narrow transaction lock for collection membership. Its monotonic `revision` advances only in the same authorized atomic write that creates a subscription series or append-only no-delivery exception. A billing preview snapshots either that revision or the document's absence; finalization rechecks it so a newly added service source cannot be omitted silently. Existing subscription term/pause changes remain protected by each series' `lastAuditId`, and newspaper pricing changes by each newspaper's `lastAuditId`.

## Bills and collection ledger

The bill ID is the deterministic `YYYY-MM` month key under a customer, preventing more than one finalized bill per customer/month. A finalized header stores immutable customer identity/address snapshots, the opening balance snapshot, prior-balance source (`previousBillId` and `previousOutstandingPaise`), current charges, signed adjustments, total due, compact per-newspaper summaries, line count, calculation version, finalizer/audit IDs, and server timestamps.

Line item IDs use the deterministic charge key `customerId:subscriptionId:YYYY-MM-DD`. Each stores service date, subscription/version/newspaper snapshots, unit price, quantity, arithmetic total, price-source kind and source record/revision, finalization audit ID, and timestamp. Lines are paginated and never recalculate after finalization. One atomic bill is limited to 475 lines so the header, control, audit, and all lines remain below Firestore's 500-write transaction ceiling.

`billingControls/{YYYY-MM}` serializes Head adjustments against finalization with a monotonically increasing `adjustmentRevision`. Its final state points to the deterministic bill and cannot be reopened. `adjustments/{adjustmentId}` stores a non-zero signed paise amount, reason, target month, optional earlier finalized bill reference, creator/audit IDs, and timestamp. Adjustments are append-only; a finalized month rejects new adjustments. A later open month can carry an explicitly audited correction referencing an earlier immutable bill.

The earliest finalized bill uses the customer's immutable opening balance as `priorBalancePaise`. Finalization also creates `collectionState/current` and `billBalances/{YYYY-MM}` in the same transaction. The collection state is the transactionally maintained signed account outstanding; each bill-balance projection stores only that bill's incremental debt, allocations, reversals, remaining positive component, revision, and last mutation. A later bill snapshots the collection state's actual remaining outstanding as `previousOutstandingPaise`, then adds only the new month's charges and signed adjustments. Opening balance, an earlier cumulative bill total, payments, and reversals are therefore never applied twice.

Payment IDs are generated once when the collector opens the flow and reused as idempotency keys. A confirmed `payments/{paymentId}` document stores immutable business/customer snapshots, integer-paise amount, method, external reference or notes, collector UID, allocation list, paired audit ID, and server confirmation timestamp. Cash, UPI, bank transfer, and controlled other methods all use the same transaction. A payment may not exceed the positive account outstanding. Allocation defaults to the oldest positive bill component, or gives one explicitly selected bill priority before continuing oldest-first. One transaction can cover at most two bill components so the complete allocation validation stays within Firestore Rules evaluation limits; a longer arrears span is collected through separate idempotent payments.

`paymentStates/{paymentId}` is a transaction-only derived projection containing refundable amount, status, revision, and per-allocation reversal totals. It may be created only with its immutable payment and may advance only with a valid Head reversal. The original payment never changes. Each `paymentReversals/{reversalId}` is a separate immutable, reasoned, audited entry that restores the newest refundable allocation first and cannot make cumulative reversals exceed the confirmed payment.

Displaying an amount-specific UPI QR, opening a UPI app, or using the static business QR creates no financial document and changes no balance. Only an authorized collector's explicit receipt confirmation, followed by a server readback of the complete transaction, creates the ledger entry. `configuration/upi` contains only the UPI ID, display name, optional reference prefix, enabled state, audit link, and timestamps; active employees may read it for collection, while only a Head may create or update it.

Legacy finalized bills created before these projections remain readable, but payment confirmation and the next bill are blocked with `collection-projection-required`. They need a separately reviewed trusted backfill before collections begin. Corrections to bills remain new adjustments; corrections to payments remain new reversals. Finalized bills, line items, payments, reversals, and audits cannot be updated or deleted by clients.

## Summaries

`monthlySummaries` will hold rebuildable Head-only dashboard projections by month, employee, and area. They improve read cost but are not financial authority. The immutable bill/payment ledger remains the source of truth.

## Indexes

`firestore.indexes.json` includes only implemented query shapes:

- Head customer pages by business + status + normalized customer name, with an optional area filter
- employee customer pages by business + assigned employee + status + normalized customer name, with an optional area filter
- the same four customer page shapes with `searchTokens` array containment
- customer audit history by entity type + entity ID + descending creation time
- newspaper pages by business + status + normalized name
- price history by business + newspaper + descending start date
- active exact-date and period conflict/resolution queries by business + newspaper + kind + status + date bounds
- collection-group payments by business + collector + descending confirmation time
- collection-group payments by business + descending time

Phase 6 replaces the two unused provisional payment-history definitions with the connected query fields `collectorUid` and `confirmedAt`. Customer-specific history stays under one customer path; tenant-wide Head and collector-specific employee history use the two collection-group indexes above and cursor pagination.

All 15 indexes are deployed and `READY` in `paperroutedev`, including the two Phase 6 payment-history replacements using `collectorUid` and `confirmedAt`. Add indexes only for implemented queries; unused composite indexes increase storage and write fan-out.
