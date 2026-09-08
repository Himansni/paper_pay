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

A customer stores the required operational fields plus denormalized query fields:

- business ID, customer code, normalized name/phone
- name, phone, alternate phone
- address, area ID, landmark, house/flat number, building/floor, location notes
- optional consented coordinates
- assigned employee ID
- subscription status and preferences
- opening balance in paise
- status, notes, creator, timestamps

Customer assignment or transfer changes only the current `assignedEmployeeId`, `areaId`, and `updatedAt`; bills, subscriptions, payments, and audit history remain below the same customer document. The selected employee must be active and authorized for the selected area.

Phase 2 writes append `auditRecords` for business settings, invitations, member access, area lifecycle/coverage, and customer assignment changes. Audit records cannot be updated or deleted by clients.

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

`firestore.indexes.json` initially includes:

- assigned employee + status + normalized customer name
- area + status + normalized customer name
- collection-group payments by business + employee + descending time
- collection-group payments by business + descending time

Add indexes only for implemented queries; unused composite indexes increase storage and write fan-out.
