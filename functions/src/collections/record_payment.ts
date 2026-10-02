import * as functions from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export interface RecordPaymentRequest {
  businessId: string;
  customerId: string;
  amountPaise: number;
  method: string;
  notes?: string;
  externalReference?: string;
  idempotencyKey: string;
}

const ALLOWED_PAYMENT_METHODS = ['cash', 'upi', 'cheque', 'bank_transfer', 'online', 'other', 'custom'];

export function validateRecordPaymentAuthorization({
  uid,
  businessId,
  customerId,
  amountPaise,
  method,
  idempotencyKey,
  member,
  customer,
}: {
  uid?: string;
  businessId?: string;
  customerId?: string;
  amountPaise?: number;
  method?: string;
  idempotencyKey?: string;
  member?: any;
  customer?: any;
}): { isHead: boolean } {
  if (!uid) {
    throw new functions.HttpsError('unauthenticated', 'User must be signed in.');
  }
  if (
    !businessId ||
    typeof businessId !== 'string' ||
    businessId.trim().length === 0 ||
    businessId.includes('/') ||
    !customerId ||
    typeof customerId !== 'string' ||
    customerId.trim().length === 0 ||
    customerId.includes('/') ||
    !idempotencyKey ||
    typeof idempotencyKey !== 'string' ||
    idempotencyKey.trim().length < 8 ||
    idempotencyKey.length > 128 ||
    !/^[a-zA-Z0-9_-]+$/.test(idempotencyKey) ||
    typeof amountPaise !== 'number' ||
    !Number.isSafeInteger(amountPaise) ||
    amountPaise <= 0 ||
    amountPaise > 1000000000
  ) {
    throw new functions.HttpsError('invalid-argument', 'Invalid or missing payment parameters.');
  }
  if (!method || typeof method !== 'string' || !ALLOWED_PAYMENT_METHODS.includes(method)) {
    throw new functions.HttpsError('invalid-argument', `Invalid payment method '${method}'.`);
  }
  if (!member || member.status !== 'active') {
    throw new functions.HttpsError('permission-denied', 'Unauthorized membership.');
  }
  const isHead = member.role === 'head';
  const hasPaymentPermission =
    member.permissions?.includes('recordPayments') ||
    member.permissions?.includes('allowCollectPayment');

  if (!customer) {
    throw new functions.HttpsError('not-found', 'Customer not found.');
  }
  if (customer.status !== 'active') {
    throw new functions.HttpsError('failed-precondition', 'Customer is not active.');
  }

  if (!isHead) {
    if (!hasPaymentPermission) {
      throw new functions.HttpsError('permission-denied', 'Employee lacks payment collection permission.');
    }
    if (customer.assignedEmployeeId !== uid) {
      throw new functions.HttpsError('permission-denied', 'Customer is not assigned to this employee.');
    }
    if (!member.areaIds?.includes(customer.areaId)) {
      throw new functions.HttpsError('permission-denied', 'Customer area is not covered by employee.');
    }
  }

  return { isHead };
}

export interface PaymentAllocationResult {
  billId: string;
  billingMonth: string;
  amountPaise: number;
}

export function calculateOldestFirstAllocations(
  amountPaise: number,
  openBills: Array<{ billId: string; billingMonth: string; outstandingPaise: number }>
): PaymentAllocationResult[] {
  // Sort oldest billingMonth first, with deterministic billId tie-breaker
  const sorted = [...openBills].sort((a, b) => 
    a.billingMonth.localeCompare(b.billingMonth) || a.billId.localeCompare(b.billId)
  );
  const allocations: PaymentAllocationResult[] = [];
  let remaining = amountPaise;

  for (const bill of sorted) {
    if (remaining <= 0) break;
    if (bill.outstandingPaise <= 0) continue;
    const allocate = Math.min(remaining, bill.outstandingPaise);
    allocations.push({
      billId: bill.billId,
      billingMonth: bill.billingMonth,
      amountPaise: allocate,
    });
    remaining -= allocate;
  }
  return allocations;
}

export const recordPayment = functions.onCall({
  region: "asia-south1",
  enforceAppCheck: false,
}, async (request) => {
  const data = request.data as RecordPaymentRequest;
  const { businessId, customerId, amountPaise, method, notes = '', externalReference = '', idempotencyKey } = data;
  const uid = request.auth?.uid;

  const db = getFirestore();

  // 1. Authorization lookup
  const memberDoc = await db.collection(`businesses/${businessId}/members`).doc(uid ?? '').get();
  const member = memberDoc.exists ? memberDoc.data() : null;
  const customerRef = db.collection(`businesses/${businessId}/customers`).doc(customerId);
  const customerDoc = await customerRef.get();
  const customer = customerDoc.exists ? customerDoc.data() : null;

  validateRecordPaymentAuthorization({
    uid,
    businessId,
    customerId,
    amountPaise,
    method,
    idempotencyKey,
    member,
    customer,
  });

  const memberData = member!;
  const customerData = customer!;

  return db.runTransaction(async (transaction) => {
    // Check idempotency
    const paymentRef = customerRef.collection('payments').doc(idempotencyKey);
    const existingPayment = await transaction.get(paymentRef);
    if (existingPayment.exists) {
      const pData = existingPayment.data()!;
      if (
        pData.amountPaise === amountPaise &&
        pData.customerId === customerId &&
        pData.businessId === businessId &&
        pData.method === method
      ) {
        return {
          success: true,
          paymentId: idempotencyKey,
          alreadyRecorded: true,
          amountPaise: pData.amountPaise,
        };
      }
      throw new functions.HttpsError('failed-precondition', 'Idempotency key was used with different parameters.');
    }

    // Read collection state
    const accountRef = customerRef.collection('collectionState').doc('current');
    const stateDoc = await transaction.get(accountRef);
    if (!stateDoc.exists) {
      throw new functions.HttpsError('failed-precondition', 'Customer has no active collection state.');
    }
    const stateData = stateDoc.data()!;
    const currentOutstanding = stateData.outstandingPaise ?? 0;
    if (amountPaise > currentOutstanding) {
      throw new functions.HttpsError(
        'failed-precondition',
        `Payment amount (₹${amountPaise / 100}) exceeds customer outstanding (₹${currentOutstanding / 100}).`
      );
    }

    // Read bill balances
    const balancesSnap = await transaction.get(customerRef.collection('billBalances'));
    const openBills: Array<{
      billId: string;
      billingMonth: string;
      sourceAmountPaise: number;
      allocatedPaise: number;
      reversedPaise: number;
      outstandingPaise: number;
      status: string;
      revision: number;
      docRef: FirebaseFirestore.DocumentReference;
    }> = [];

    for (const bDoc of balancesSnap.docs) {
      const bData = bDoc.data();
      const outstanding = bData.outstandingPaise ?? 0;
      if (outstanding > 0) {
        openBills.push({
          billId: bDoc.id,
          billingMonth: bData.billingMonth ?? bDoc.id,
          sourceAmountPaise: bData.sourceAmountPaise ?? 0,
          allocatedPaise: bData.allocatedPaise ?? 0,
          reversedPaise: bData.reversedPaise ?? 0,
          outstandingPaise: outstanding,
          status: bData.status ?? 'outstanding',
          revision: bData.revision ?? 0,
          docRef: bDoc.ref,
        });
      }
    }

    const sumOpenBillsPaise = openBills.reduce((acc, b) => acc + b.outstandingPaise, 0);
    if (openBills.length === 0 || sumOpenBillsPaise <= 0) {
      throw new functions.HttpsError('failed-precondition', 'Customer has no allocatable outstanding bills.');
    }
    if (sumOpenBillsPaise !== currentOutstanding) {
      throw new functions.HttpsError(
        'failed-precondition',
        `Financial integrity violation: Sum of open bill balances (₹${sumOpenBillsPaise / 100}) does not match collection state outstanding (₹${currentOutstanding / 100}).`
      );
    }

    // Calculate server-authoritative oldest-first allocation
    const allocations = calculateOldestFirstAllocations(amountPaise, openBills);
    const totalAllocated = allocations.reduce((acc, a) => acc + a.amountPaise, 0);
    if (totalAllocated !== amountPaise) {
      throw new functions.HttpsError(
        'internal',
        `Financial integrity violation: Total allocated (₹${totalAllocated / 100}) does not match payment amount (₹${amountPaise / 100}).`
      );
    }

    const now = FieldValue.serverTimestamp();
    const auditRef = db.collection(`businesses/${businessId}/auditRecords`).doc();
    const paymentStateRef = customerRef.collection('paymentStates').doc(idempotencyKey);

    // 1. Write payment
    transaction.set(paymentRef, {
      businessId,
      customerId,
      customerCode: customerData.customerCode ?? customerId,
      customerName: customerData.name ?? 'Customer',
      areaId: customerData.areaId ?? '',
      assignedEmployeeId: customerData.assignedEmployeeId ?? '',
      paymentId: idempotencyKey,
      idempotencyKey,
      amountPaise,
      method,
      status: 'confirmed',
      externalReference,
      notes,
      collectorUid: uid,
      allocations,
      allocationCount: allocations.length,
      allocatedPaise: amountPaise,
      lastAuditId: auditRef.id,
      confirmedAt: now,
      createdAt: now,
    });

    // 2. Write paymentState
    transaction.set(paymentStateRef, {
      businessId,
      customerId,
      paymentId: idempotencyKey,
      amountPaise,
      reversedPaise: 0,
      refundablePaise: amountPaise,
      status: 'confirmed',
      allocationStates: allocations.map((a) => ({
        billId: a.billId,
        billingMonth: a.billingMonth,
        amountPaise: a.amountPaise,
        reversedPaise: 0,
      })),
      revision: 0,
      lastReversalId: '',
      createdAt: now,
      updatedAt: now,
    });

    // 3. Update allocated billBalances
    const allocatedMap = new Map(allocations.map((a) => [a.billId, a.amountPaise]));
    for (const bill of openBills) {
      const allocatedAmount = allocatedMap.get(bill.billId);
      if (allocatedAmount !== undefined && allocatedAmount > 0) {
        const nextOutstanding = bill.outstandingPaise - allocatedAmount;
        transaction.update(bill.docRef, {
          allocatedPaise: bill.allocatedPaise + allocatedAmount,
          outstandingPaise: nextOutstanding,
          status: nextOutstanding === 0 ? 'settled' : 'outstanding',
          revision: bill.revision + 1,
          lastMutationType: 'paymentConfirmed',
          lastMutationId: idempotencyKey,
          updatedAt: now,
        });
      }
    }

    // 4. Determine remaining oldest month
    let remainingOldest = '';
    const sortedAllOpen = openBills.sort((a, b) => a.billingMonth.localeCompare(b.billingMonth));
    for (const bill of sortedAllOpen) {
      const deduction = allocatedMap.get(bill.billId) ?? 0;
      if (bill.outstandingPaise - deduction > 0) {
        remainingOldest = bill.billingMonth;
        break;
      }
    }

    const nextOutstanding = currentOutstanding - amountPaise;
    const nextConfirmed = (stateData.confirmedPaise ?? 0) + amountPaise;
    const reversedPaise = stateData.reversedPaise ?? 0;
    const reportingStatus =
      nextOutstanding <= 0
        ? (nextOutstanding < 0 ? 'credit' : 'fullyPaid')
        : nextConfirmed > reversedPaise
        ? 'partiallyPaid'
        : 'unpaid';

    // 5. Update collectionState
    transaction.update(accountRef, {
      outstandingPaise: nextOutstanding,
      confirmedPaise: nextConfirmed,
      reversedPaise,
      reportingStatus,
      oldestOutstandingMonth: nextOutstanding > 0 ? remainingOldest : '',
      revision: (stateData.revision ?? 0) + 1,
      lastMutationType: 'paymentConfirmed',
      lastMutationId: idempotencyKey,
      updatedBy: uid,
      updatedAt: now,
    });

    // 6. Write auditRecord
    transaction.set(auditRef, {
      businessId,
      actorId: uid,
      actorRole: memberData.role,
      action: 'paymentConfirmed',
      entityType: 'payment',
      entityId: idempotencyKey,
      customerId,
      paymentId: idempotencyKey,
      amountPaise,
      method,
      allocationCount: allocations.length,
      createdAt: now,
    });

    return {
      success: true,
      paymentId: idempotencyKey,
      amountPaise,
      allocations,
      nextOutstandingPaise: nextOutstanding,
    };
  });
});
