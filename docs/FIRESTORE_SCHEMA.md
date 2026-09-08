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
    deliveryExceptions/{exceptionId}
    bills/{monthKey}
      lineItems/{chargeKey}
    adjustments/{adjustmentId}
    payments/{paymentId}
    paymentReversals/{reversalId}
  newspapers/{newspaperId}
    priceOverrides/{dateKey}
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

A newspaper stores name, edition/language, default price in paise, status, and timestamps. A price override document uses its `YYYY-MM-DD` date as ID and stores the authorized price plus audit fields.

A subscription stores newspaper ID, start/end date, quantity, optional fixed price/discount metadata, status, and timestamps. Pauses should be separate effective-date records once the operational repository is implemented so history is not overwritten.

## Bills and ledger

The bill ID is the deterministic month key under a customer, preventing more than one finalized bill per customer/month. It stores current charges, prior balance snapshot, adjustments, total due, status, engine version, finalized-by metadata, and timestamps.

Line item IDs use the deterministic charge key `customerId:subscriptionId:YYYY-MM-DD`. Each stores service date, newspaper/subscription snapshot, unit price, quantity, and total. These values never recalculate after finalization.

Payment IDs are generated once at collection start and reused as idempotency keys. Confirmed payment records store bill/customer/business, amount, method, manual-confirmation label, optional UPI reference, collector UID, and server timestamp. A QR request may be stored separately, but it is never counted as received money.

Corrections are new `paymentReversals` or `adjustments`; existing financial documents cannot be updated or deleted by the client.

## Summaries

`monthlySummaries` will hold rebuildable Head-only dashboard projections by month, employee, and area. They improve read cost but are not financial authority. The immutable bill/payment ledger remains the source of truth.

## Indexes

`firestore.indexes.json` includes only implemented query shapes:

- Head customer pages by business + status + normalized customer name, with an optional area filter
- employee customer pages by business + assigned employee + status + normalized customer name, with an optional area filter
- the same four customer page shapes with `searchTokens` array containment
- customer audit history by entity type + entity ID + descending creation time
- collection-group payments by business + employee + descending time
- collection-group payments by business + descending time

The Phase 3 customer and audit indexes are local until the owner explicitly approves deployment. Add indexes only for implemented queries; unused composite indexes increase storage and write fan-out.
