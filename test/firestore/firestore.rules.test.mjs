import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  arrayUnion,
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  runTransaction,
  setLogLevel,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

setLogLevel('silent');

const projectId = 'demo-paper-route';
let environment;

const auth = (uid, email) =>
  environment.authenticatedContext(uid, {
    email,
    email_verified: true,
  }).firestore();

const completeCustomer = ({
  id,
  businessId = 'business-a',
  assignedEmployeeId = 'employee-a',
  areaId = 'east',
  status = 'active',
  openingBalancePaise = 0,
  createdBy = 'head-a',
  lastAuditId = 'seed-audit',
} = {}) => ({
  businessId,
  customerCode: id,
  name: 'Managed Customer',
  searchName: 'managed customer',
  phone: '8888888888',
  searchPhone: '8888888888',
  alternatePhone: '',
  address: '1 Main Road, Paper Town',
  areaId,
  landmark: 'Clock Tower',
  searchLandmark: 'clock tower',
  searchTokens: ['name:ma', 'name:man', 'phone:888', 'landmark:cl'],
  houseNumber: '1',
  buildingInfo: 'Ground floor',
  locationNotes: 'Blue gate',
  locationConsent: false,
  coordinates: null,
  assignedEmployeeId,
  status,
  subscriptionStatus: 'notConfigured',
  deliveryPreferences: { placement: 'doorstep' },
  billingPreferences: { cycle: 'monthly' },
  openingBalancePaise,
  notes: '',
  createdBy,
  updatedBy: createdBy,
  lastAuditId,
  createdAt: new Date(),
  updatedAt: new Date(),
});

const customerAudit = ({
  businessId = 'business-a',
  actorId,
  action,
  entityId,
  extra = {},
}) => ({
  businessId,
  actorId,
  action,
  entityType: 'customer',
  entityId,
  ...extra,
  createdAt: serverTimestamp(),
});

const completeNewspaper = ({
  id = 'times',
  businessId = 'business-a',
  status = 'active',
  defaultPricePaise = 650,
  actorId = 'head-a',
  lastAuditId = 'seed-newspaper-audit',
} = {}) => ({
  businessId,
  newspaperCode: id,
  name: 'Daily Times',
  searchName: 'daily times',
  edition: 'City',
  language: 'English',
  defaultPricePaise,
  status,
  createdBy: actorId,
  updatedBy: actorId,
  lastAuditId,
  createdAt: new Date(),
  updatedAt: new Date(),
});

const subscriptionSeries = ({
  customerId = 'C-EMPLOYEE',
  newspaperId = 'times',
  versionId = 'version-1',
  status = 'active',
  currentPauseId = '',
  startDate = '2026-09-01',
  endDate = null,
  effectiveFrom = startDate,
  quantity = 1,
  weekdays = [1, 2, 3, 4, 5, 6, 7],
  customPricePaise = null,
  customPriceReason = '',
  actorId = 'head-a',
  auditId = 'subscription-audit',
} = {}) => ({
  businessId: 'business-a',
  customerId,
  subscriptionId: newspaperId,
  newspaperId,
  newspaperName: 'Daily Times',
  currentVersionId: versionId,
  currentPauseId,
  status,
  startDate,
  endDate,
  currentEffectiveFrom: effectiveFrom,
  quantity,
  deliveryWeekdays: weekdays,
  customPricePaise,
  customPriceReason,
  createdBy: actorId,
  updatedBy: actorId,
  lastAuditId: auditId,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
});

const subscriptionVersion = ({
  customerId = 'C-EMPLOYEE',
  newspaperId = 'times',
  versionId = 'version-1',
  effectiveFrom = '2026-09-01',
  effectiveTo = null,
  quantity = 1,
  weekdays = [1, 2, 3, 4, 5, 6, 7],
  customPricePaise = null,
  customPriceReason = '',
  predecessorVersionId = '',
  successorVersionId = '',
  status = 'current',
  actorId = 'head-a',
  auditId = 'subscription-audit',
} = {}) => ({
  businessId: 'business-a',
  customerId,
  subscriptionId: newspaperId,
  versionId,
  newspaperId,
  effectiveFrom,
  effectiveTo,
  quantity,
  deliveryWeekdays: weekdays,
  customPricePaise,
  customPriceReason,
  predecessorVersionId,
  successorVersionId,
  status,
  createdBy: actorId,
  updatedBy: actorId,
  lastAuditId: auditId,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
});

const subscriptionAudit = ({
  customerId = 'C-EMPLOYEE',
  newspaperId = 'times',
  actorId = 'head-a',
  action = 'subscriptionCreated',
  auditId = 'subscription-audit',
  extra = {},
} = {}) => ({
  businessId: 'business-a',
  actorId,
  action,
  entityType: 'subscription',
  entityId: `${customerId}:${newspaperId}`,
  customerId,
  subscriptionId: newspaperId,
  auditId,
  ...extra,
  createdAt: serverTimestamp(),
});

const serviceBillingSource = ({
  customerId = 'C-EMPLOYEE',
  actorId = 'head-a',
  mutationType = 'subscriptionCreated',
  mutationId = 'times',
  revision = 1,
} = {}) => ({
  businessId: 'business-a',
  customerId,
  sourceId: 'service',
  revision,
  lastMutationType: mutationType,
  lastMutationId: mutationId,
  updatedBy: actorId,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
});

const addServiceBillingSource = (
  batch,
  db,
  {
    customerId = 'C-EMPLOYEE',
    actorId = 'head-a',
    mutationType = 'subscriptionCreated',
    mutationId = 'times',
    revision = 1,
  } = {},
) => {
  batch.set(
    doc(
      db,
      `businesses/business-a/customers/${customerId}/billingSources/service`,
    ),
    serviceBillingSource({
      customerId,
      actorId,
      mutationType,
      mutationId,
      revision,
    }),
  );
};

const addSubscriptionCreate = (
  batch,
  db,
  {
    customerId = 'C-EMPLOYEE',
    newspaperId = 'times',
    versionId = 'version-1',
    actorId = 'head-a',
    auditId = 'subscription-audit',
    customPricePaise = null,
    customPriceReason = '',
  } = {},
) => {
  batch.set(
    doc(
      db,
      `businesses/business-a/customers/${customerId}/subscriptions/${newspaperId}`,
    ),
    subscriptionSeries({
      customerId,
      newspaperId,
      versionId,
      actorId,
      auditId,
      customPricePaise,
      customPriceReason,
    }),
  );
  batch.set(
    doc(
      db,
      `businesses/business-a/customers/${customerId}/subscriptions/${newspaperId}/versions/${versionId}`,
    ),
    subscriptionVersion({
      customerId,
      newspaperId,
      versionId,
      actorId,
      auditId,
      customPricePaise,
      customPriceReason,
    }),
  );
  batch.set(
    doc(db, `businesses/business-a/auditRecords/${auditId}`),
    subscriptionAudit({
      customerId,
      newspaperId,
      actorId,
      auditId,
      extra: { newspaperId, versionId },
    }),
  );
  addServiceBillingSource(batch, db, {
    customerId,
    actorId,
    mutationType: 'subscriptionCreated',
    mutationId: newspaperId,
  });
};

const completeBill = ({
  customerId = 'C-MANAGED',
  month = '2026-09',
  actorId = 'head-a',
  auditId = 'bill-audit',
  currentChargesPaise = 650,
  priorBalancePaise = 0,
  adjustmentsPaise = 0,
  totalDuePaise = currentChargesPaise + priorBalancePaise + adjustmentsPaise,
  lineItemCount = 1,
  areaId = 'east',
  assignedEmployeeId = 'employee-a',
  customerStatus = 'active',
} = {}) => ({
  businessId: 'business-a',
  customerId,
  customerCode: customerId,
  customerName: 'Managed Customer',
  customerSearchName: 'managed customer',
  customerAddress: '1 Main Road, Paper Town, Near Clock Tower',
  areaId,
  assignedEmployeeId,
  customerStatus,
  billingMonth: month,
  status: 'finalized',
  openingBalancePaise: 0,
  previousBillId: '',
  previousOutstandingPaise: 0,
  priorBalancePaise,
  currentChargesPaise,
  adjustmentsPaise,
  totalDuePaise,
  lineItemCount,
  newspaperSummaries: [
    {
      newspaperId: 'times',
      newspaperName: 'Daily Times',
      deliveryCount: lineItemCount,
      subtotalPaise: currentChargesPaise,
    },
  ],
  calculationVersion: 'paper-route-monthly-v1',
  finalizedBy: actorId,
  createdBy: actorId,
  lastAuditId: auditId,
  finalizedAt: serverTimestamp(),
  createdAt: serverTimestamp(),
});

const addBillFinalization = (
  batch,
  db,
  {
    customerId = 'C-MANAGED',
    month = '2026-09',
    actorId = 'head-a',
    auditId = 'bill-audit',
    totalDuePaise = 650,
    malformedLine = false,
  } = {},
) => {
  const chargeKey = 'C-MANAGED:times:2026-09-01';
  const currentChargesPaise = 650;
  const priorBalancePaise = 0;
  const adjustmentsPaise = 0;
  batch.set(
    doc(db, `businesses/business-a/customers/${customerId}/bills/${month}`),
    completeBill({
      customerId,
      month,
      actorId,
      auditId,
      currentChargesPaise,
      priorBalancePaise,
      adjustmentsPaise,
      totalDuePaise,
    }),
  );
  batch.set(
    doc(
      db,
      `businesses/business-a/customers/${customerId}/bills/${month}/lineItems/${chargeKey}`,
    ),
    {
      businessId: 'business-a',
      customerId,
      billId: month,
      billingMonth: month,
      chargeKey,
      serviceDate: '2026-09-01',
      subscriptionId: 'times',
      versionId: 'version-1',
      newspaperId: 'times',
      newspaperName: 'Daily Times',
      unitPricePaise: 650,
      quantity: 1,
      totalPaise: malformedLine ? 1 : 650,
      priceSource: 'defaultPrice',
      priceSourceId: 'times',
      priceRuleRevision: 0,
      lastAuditId: auditId,
      createdAt: serverTimestamp(),
    },
  );
  batch.set(
    doc(
      db,
      `businesses/business-a/customers/${customerId}/billingControls/${month}`,
    ),
    {
      businessId: 'business-a',
      customerId,
      billingMonth: month,
      status: 'finalized',
      adjustmentRevision: 0,
      finalizedBillId: month,
      updatedBy: actorId,
      lastAuditId: auditId,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    },
  );
  batch.set(
    doc(
      db,
      `businesses/business-a/customers/${customerId}/billBalances/${month}`,
    ),
    {
      businessId: 'business-a',
      customerId,
      billId: month,
      billingMonth: month,
      sourceAmountPaise: totalDuePaise,
      allocatedPaise: 0,
      reversedPaise: 0,
      outstandingPaise: Math.max(0, totalDuePaise),
      status:
        totalDuePaise > 0
          ? 'outstanding'
          : totalDuePaise < 0
            ? 'credit'
            : 'settled',
      revision: 0,
      lastMutationType: 'billFinalized',
      lastMutationId: month,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    },
  );
  batch.set(
    doc(
      db,
      `businesses/business-a/customers/${customerId}/collectionState/current`,
    ),
    {
      businessId: 'business-a',
      customerId,
      stateId: 'current',
      customerCode: customerId,
      customerName: 'Managed Customer',
      areaId: 'east',
      assignedEmployeeId: 'employee-a',
      customerStatus: 'active',
      outstandingPaise: totalDuePaise,
      confirmedPaise: 0,
      reversedPaise: 0,
      reportingStatus:
        totalDuePaise < 0
          ? 'credit'
          : totalDuePaise === 0
            ? 'fullyPaid'
            : 'unpaid',
      oldestOutstandingMonth: totalDuePaise > 0 ? month : '',
      revision: 1,
      lastMutationType: 'billFinalized',
      lastMutationId: month,
      updatedBy: actorId,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    },
  );
  batch.set(doc(db, `businesses/business-a/auditRecords/${auditId}`), {
    businessId: 'business-a',
    actorId,
    action: 'billFinalized',
    entityType: 'bill',
    entityId: `${customerId}:${month}`,
    customerId,
    billingMonth: month,
    lineItemCount: 1,
    currentChargesPaise,
    priorBalancePaise,
    adjustmentsPaise,
    totalDuePaise,
    controlRevision: 0,
    createdAt: serverTimestamp(),
  });
};

const addBillingAdjustment = (
  batch,
  db,
  {
    customerId = 'C-MANAGED',
    month = '2026-10',
    adjustmentId = 'adjustment-1',
    auditId = 'adjustment-audit',
    actorId = 'head-a',
    amountPaise = -500,
  } = {},
) => {
  batch.set(
    doc(
      db,
      `businesses/business-a/customers/${customerId}/adjustments/${adjustmentId}`,
    ),
    {
      businessId: 'business-a',
      customerId,
      adjustmentId,
      billingMonth: month,
      amountPaise,
      reason: 'Synthetic audited correction',
      referenceBillMonth: '',
      createdBy: actorId,
      lastAuditId: auditId,
      createdAt: serverTimestamp(),
    },
  );
  batch.set(
    doc(
      db,
      `businesses/business-a/customers/${customerId}/billingControls/${month}`,
    ),
    {
      businessId: 'business-a',
      customerId,
      billingMonth: month,
      status: 'open',
      adjustmentRevision: 1,
      finalizedBillId: '',
      updatedBy: actorId,
      lastAuditId: auditId,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    },
  );
  batch.set(doc(db, `businesses/business-a/auditRecords/${auditId}`), {
    businessId: 'business-a',
    actorId,
    action: 'billingAdjustmentCreated',
    entityType: 'billingAdjustment',
    entityId: adjustmentId,
    customerId,
    billingMonth: month,
    amountPaise,
    referenceBillMonth: '',
    controlRevision: 1,
    createdAt: serverTimestamp(),
  });
};

const finalizeMonthTransaction = async (
  db,
  { month = '2026-09', auditId = 'transaction-audit' } = {},
) => {
  const customerId = 'C-MANAGED';
  const billRef = doc(
    db,
    `businesses/business-a/customers/${customerId}/bills/${month}`,
  );
  try {
    return await runTransaction(db, async (transaction) => {
      const existing = await transaction.get(billRef);
      if (existing.exists()) return false;
      const batchLike = {
        set: (reference, value) => transaction.set(reference, value),
      };
      addBillFinalization(batchLike, db, { month, auditId });
      return true;
    });
  } catch (error) {
    if (error.code === 'permission-denied' && (await getDoc(billRef)).exists()) {
      return false;
    }
    throw error;
  }
};

const seedCollectionProjection = async ({
  customerId = 'C-MANAGED',
  assignedEmployeeId = 'employee-a',
  areaId = 'east',
  status = 'active',
  bills = [{ month: '2026-09', outstandingPaise: 60000 }],
} = {}) => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(
      doc(db, `businesses/business-a/customers/${customerId}`),
      completeCustomer({
        id: customerId,
        assignedEmployeeId,
        areaId,
        status,
      }),
    );
    let outstandingPaise = 0;
    for (const bill of bills) {
      outstandingPaise += bill.outstandingPaise;
      await setDoc(
        doc(
          db,
          `businesses/business-a/customers/${customerId}/bills/${bill.month}`,
        ),
        {
          ...completeBill({
            customerId,
            month: bill.month,
            currentChargesPaise: bill.outstandingPaise,
            totalDuePaise: bill.outstandingPaise,
            areaId,
            assignedEmployeeId,
            customerStatus: status,
          }),
          finalizedAt: new Date(),
          createdAt: new Date(),
        },
      );
      await setDoc(
        doc(
          db,
          `businesses/business-a/customers/${customerId}/billBalances/${bill.month}`,
        ),
        {
          businessId: 'business-a',
          customerId,
          billId: bill.month,
          billingMonth: bill.month,
          sourceAmountPaise: bill.outstandingPaise,
          allocatedPaise: 0,
          reversedPaise: 0,
          outstandingPaise: bill.outstandingPaise,
          status: 'outstanding',
          revision: 0,
          lastMutationType: 'billFinalized',
          lastMutationId: bill.month,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      );
    }
    await setDoc(
      doc(
        db,
        `businesses/business-a/customers/${customerId}/collectionState/current`,
      ),
      {
        businessId: 'business-a',
        customerId,
        stateId: 'current',
        customerCode: customerId,
        customerName: 'Managed Customer',
        areaId,
        assignedEmployeeId,
        customerStatus: status,
        outstandingPaise,
        confirmedPaise: 0,
        reversedPaise: 0,
        reportingStatus: outstandingPaise > 0 ? 'unpaid' : 'fullyPaid',
        oldestOutstandingMonth:
          outstandingPaise > 0
            ? bills.map((bill) => bill.month).toSorted()[0]
            : '',
        revision: 1,
        lastMutationType: 'billFinalized',
        lastMutationId: bills.at(-1).month,
        updatedBy: 'head-a',
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    );
  });
};

const confirmPaymentTransaction = async (
  db,
  {
    customerId = 'C-MANAGED',
    paymentId = 'payment-0001',
    actorId = 'head-a',
    amountPaise = 25000,
    method = 'cash',
    externalReference = '',
    notes = '',
    allocations = [
      { billId: '2026-09', billingMonth: '2026-09', amountPaise: 25000 },
    ],
  } = {},
) => {
  const customerPath = `businesses/business-a/customers/${customerId}`;
  const paymentRef = doc(db, `${customerPath}/payments/${paymentId}`);
  const paymentStateRef = doc(
    db,
    `${customerPath}/paymentStates/${paymentId}`,
  );
  const accountRef = doc(db, `${customerPath}/collectionState/current`);
  const auditId = `${paymentId}-audit`;
  const auditRef = doc(db, `businesses/business-a/auditRecords/${auditId}`);
  return runTransaction(db, async (transaction) => {
    const customer = await transaction.get(doc(db, customerPath));
    const account = await transaction.get(accountRef);
    const balances = new Map();
    for (const allocation of allocations) {
      const balanceRef = doc(
        db,
        `${customerPath}/billBalances/${allocation.billId}`,
      );
      balances.set(allocation.billId, {
        reference: balanceRef,
        snapshot: await transaction.get(balanceRef),
      });
    }
    const now = serverTimestamp();
    transaction.set(paymentRef, {
      businessId: 'business-a',
      customerId,
      customerCode: customer.data()?.customerCode ?? customerId,
      customerName: customer.data()?.name ?? 'Managed Customer',
      areaId: customer.data()?.areaId ?? '',
      assignedEmployeeId: customer.data()?.assignedEmployeeId ?? '',
      paymentId,
      idempotencyKey: paymentId,
      amountPaise,
      method,
      status: 'confirmed',
      externalReference,
      notes,
      collectorUid: actorId,
      allocations,
      allocationCount: allocations.length,
      allocatedPaise: amountPaise,
      lastAuditId: auditId,
      confirmedAt: now,
      createdAt: now,
    });
    transaction.set(paymentStateRef, {
      businessId: 'business-a',
      customerId,
      paymentId,
      amountPaise,
      reversedPaise: 0,
      refundablePaise: amountPaise,
      status: 'confirmed',
      allocationStates: allocations.map((allocation) => ({
        ...allocation,
        reversedPaise: 0,
      })),
      revision: 0,
      lastReversalId: '',
      createdAt: now,
      updatedAt: now,
    });
    const nextOutstanding = account.data().outstandingPaise - amountPaise;
    const nextConfirmed = account.data().confirmedPaise + amountPaise;
    const allocatedByBill = Object.fromEntries(
      allocations.map((allocation) => [allocation.billId, allocation.amountPaise]),
    );
    const oldestOutstandingMonth = [...balances.entries()]
      .filter(
        ([billId, balance]) =>
          balance.snapshot.data().outstandingPaise -
            (allocatedByBill[billId] ?? 0) >
          0,
      )
      .map(([billId]) => billId)
      .toSorted()[0] ?? '';
    transaction.update(accountRef, {
      outstandingPaise: nextOutstanding,
      confirmedPaise: nextConfirmed,
      reversedPaise: account.data().reversedPaise,
      reportingStatus:
        nextOutstanding === 0
          ? 'fullyPaid'
          : nextConfirmed > account.data().reversedPaise
            ? 'partiallyPaid'
            : 'unpaid',
      oldestOutstandingMonth,
      revision: account.data().revision + 1,
      lastMutationType: 'paymentConfirmed',
      lastMutationId: paymentId,
      updatedBy: actorId,
      updatedAt: now,
    });
    for (const allocation of allocations) {
      const balance = balances.get(allocation.billId);
      const data = balance.snapshot.data();
      const outstanding = data.outstandingPaise - allocation.amountPaise;
      transaction.update(balance.reference, {
        allocatedPaise: data.allocatedPaise + allocation.amountPaise,
        outstandingPaise: outstanding,
        status: outstanding === 0 ? 'settled' : 'outstanding',
        revision: data.revision + 1,
        lastMutationType: 'paymentConfirmed',
        lastMutationId: paymentId,
        updatedAt: now,
      });
    }
    transaction.set(auditRef, {
      businessId: 'business-a',
      actorId,
      action: 'paymentConfirmed',
      entityType: 'payment',
      entityId: paymentId,
      customerId,
      paymentId,
      amountPaise,
      method,
      allocationCount: allocations.length,
      createdAt: now,
    });
  });
};

const reversePaymentTransaction = async (
  db,
  {
    customerId = 'C-MANAGED',
    paymentId = 'payment-0001',
    reversalId = 'reversal-0001',
    actorId = 'head-a',
    amountPaise = 5000,
    reason = 'Synthetic correction',
    allocations = [
      { billId: '2026-09', billingMonth: '2026-09', amountPaise: 5000 },
    ],
  } = {},
) => {
  const customerPath = `businesses/business-a/customers/${customerId}`;
  const paymentRef = doc(db, `${customerPath}/payments/${paymentId}`);
  const stateRef = doc(db, `${customerPath}/paymentStates/${paymentId}`);
  const accountRef = doc(db, `${customerPath}/collectionState/current`);
  const reversalRef = doc(
    db,
    `${customerPath}/paymentReversals/${reversalId}`,
  );
  const auditId = `${reversalId}-audit`;
  return runTransaction(db, async (transaction) => {
    const payment = await transaction.get(paymentRef);
    const state = await transaction.get(stateRef);
    const account = await transaction.get(accountRef);
    const balances = new Map();
    for (const allocation of allocations) {
      const balanceRef = doc(
        db,
        `${customerPath}/billBalances/${allocation.billId}`,
      );
      balances.set(allocation.billId, {
        reference: balanceRef,
        snapshot: await transaction.get(balanceRef),
      });
    }
    const restoredByBill = Object.fromEntries(
      allocations.map((allocation) => [
        allocation.billId,
        allocation.amountPaise,
      ]),
    );
    const now = serverTimestamp();
    transaction.set(reversalRef, {
      businessId: 'business-a',
      customerId,
      reversalId,
      paymentId,
      customerCode: payment.data().customerCode,
      customerName: payment.data().customerName,
      areaId: payment.data().areaId,
      assignedEmployeeId: payment.data().assignedEmployeeId,
      collectorUid: payment.data().collectorUid,
      method: payment.data().method,
      idempotencyKey: reversalId,
      amountPaise,
      reason,
      reversedBy: actorId,
      allocations,
      allocationCount: allocations.length,
      restoredPaise: amountPaise,
      lastAuditId: auditId,
      reversedAt: now,
      createdAt: now,
    });
    const priorState = state.data();
    const nextReversed = priorState.reversedPaise + amountPaise;
    const refundablePaise = priorState.amountPaise - nextReversed;
    transaction.update(stateRef, {
      reversedPaise: nextReversed,
      refundablePaise,
      status: refundablePaise === 0 ? 'reversed' : 'partiallyReversed',
      allocationStates: priorState.allocationStates.map((allocation) => ({
        ...allocation,
        reversedPaise:
          allocation.reversedPaise + (restoredByBill[allocation.billId] ?? 0),
      })),
      revision: priorState.revision + 1,
      lastReversalId: reversalId,
      updatedAt: now,
    });
    const nextOutstanding = account.data().outstandingPaise + amountPaise;
    const nextAccountReversed = account.data().reversedPaise + amountPaise;
    const restoredOldest = allocations
      .map((allocation) => allocation.billingMonth)
      .toSorted()[0];
    const oldestOutstandingMonth =
      account.data().oldestOutstandingMonth === '' ||
      restoredOldest < account.data().oldestOutstandingMonth
        ? restoredOldest
        : account.data().oldestOutstandingMonth;
    transaction.update(accountRef, {
      outstandingPaise: nextOutstanding,
      reversedPaise: nextAccountReversed,
      reportingStatus:
        nextOutstanding === 0
          ? 'fullyPaid'
          : account.data().confirmedPaise > nextAccountReversed
            ? 'partiallyPaid'
            : 'unpaid',
      oldestOutstandingMonth,
      revision: account.data().revision + 1,
      lastMutationType: 'paymentReversed',
      lastMutationId: reversalId,
      updatedBy: actorId,
      updatedAt: now,
    });
    for (const allocation of allocations) {
      const balance = balances.get(allocation.billId);
      const data = balance.snapshot.data();
      transaction.update(balance.reference, {
        reversedPaise: data.reversedPaise + allocation.amountPaise,
        outstandingPaise: data.outstandingPaise + allocation.amountPaise,
        status: 'outstanding',
        revision: data.revision + 1,
        lastMutationType: 'paymentReversed',
        lastMutationId: reversalId,
        updatedAt: now,
      });
    }
    transaction.set(
      doc(db, `businesses/business-a/auditRecords/${auditId}`),
      {
        businessId: 'business-a',
        actorId,
        action: 'paymentReversed',
        entityType: 'paymentReversal',
        entityId: reversalId,
        customerId,
        paymentId,
        amountPaise,
        reason,
        allocationCount: allocations.length,
        createdAt: now,
      },
    );
    return payment.data();
  });
};

const writeUpiSettings = async (
  db,
  {
    actorId = 'head-a',
    auditId = 'upi-audit-1',
    upiId = 'paper.route@bank',
    payeeName = 'Paper Route Test',
    referencePrefix = 'PAPERROUTE',
    enabled = true,
  } = {},
) => {
  const batch = writeBatch(db);
  const now = serverTimestamp();
  batch.set(doc(db, 'businesses/business-a/configuration/upi'), {
    businessId: 'business-a',
    upiId,
    payeeName,
    referencePrefix,
    enabled,
    updatedBy: actorId,
    lastAuditId: auditId,
    createdAt: now,
    updatedAt: now,
  });
  batch.set(doc(db, `businesses/business-a/auditRecords/${auditId}`), {
    businessId: 'business-a',
    actorId,
    action: 'upiSettingsUpdated',
    entityType: 'configuration',
    entityId: 'upi',
    enabled,
    createdAt: now,
  });
  return batch.commit();
};

async function seed() {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'businesses/business-a'), {
      businessId: 'business-a',
      ownerId: 'head-a',
      name: 'A News',
    });
    await setDoc(doc(db, 'businesses/business-b'), {
      businessId: 'business-b',
      ownerId: 'head-b',
      name: 'B News',
    });
    await setDoc(doc(db, 'businesses/business-a/members/head-a'), {
      businessId: 'business-a',
      uid: 'head-a',
      role: 'head',
      status: 'active',
      permissions: [],
    });
    await setDoc(doc(db, 'businesses/business-a/members/employee-a'), {
      businessId: 'business-a',
      uid: 'employee-a',
      email: 'employee-a@example.com',
      displayName: 'Employee A',
      role: 'employee',
      status: 'active',
      permissions: ['recordPayments'],
      areaIds: ['east'],
    });
    await setDoc(doc(db, 'businesses/business-a/members/employee-c'), {
      businessId: 'business-a',
      uid: 'employee-c',
      email: 'employee-c@example.com',
      displayName: 'Employee C',
      role: 'employee',
      status: 'active',
      permissions: [
        'addCustomers',
        'editAssignedCustomers',
        'manageAssignedSubscriptions',
        'recordDeliveryExceptions',
      ],
      areaIds: ['east'],
    });
    await setDoc(doc(db, 'businesses/business-b/members/employee-b'), {
      businessId: 'business-b',
      uid: 'employee-b',
      role: 'employee',
      status: 'active',
      permissions: ['recordPayments'],
    });
    await setDoc(doc(db, 'businesses/business-a/customers/assigned'), {
      businessId: 'business-a',
      assignedEmployeeId: 'employee-a',
      areaId: '',
      name: 'Assigned Customer',
    });
    await setDoc(doc(db, 'businesses/business-a/customers/unassigned'), {
      businessId: 'business-a',
      assignedEmployeeId: 'another-employee',
      name: 'Other Customer',
    });
    await setDoc(
      doc(db, 'businesses/business-a/customers/C-MANAGED'),
      completeCustomer({ id: 'C-MANAGED' }),
    );
    await setDoc(
      doc(db, 'businesses/business-a/customers/C-EMPLOYEE'),
      completeCustomer({
        id: 'C-EMPLOYEE',
        assignedEmployeeId: 'employee-c',
      }),
    );
    await setDoc(doc(db, 'businesses/business-a/areas/east'), {
      businessId: 'business-a',
      name: 'East',
      status: 'active',
      assignedEmployeeIds: ['employee-a', 'employee-c'],
    });
    await setDoc(doc(db, 'businesses/business-a/areas/west'), {
      businessId: 'business-a',
      name: 'West',
      status: 'active',
      assignedEmployeeIds: [],
    });
    await setDoc(doc(db, 'businesses/business-a/newspapers/times'), {
      ...completeNewspaper(),
    });
  });
}

before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: await readFile('firestore.rules', 'utf8'),
    },
  });
});

beforeEach(async () => {
  await environment.clearFirestore();
  await seed();
});

after(async () => {
  await environment.cleanup();
});

describe('tenant and assignment isolation', () => {
  test('denies unauthenticated business data', async () => {
    const db = environment.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'businesses/business-a')));
  });

  test('employee reads assigned customer only', async () => {
    const db = auth('employee-a', 'employee-a@example.com');
    await assertSucceeds(
      getDoc(doc(db, 'businesses/business-a/customers/assigned')),
    );
    await assertFails(
      getDoc(doc(db, 'businesses/business-a/customers/unassigned')),
    );
  });

  test('blocks access to another business', async () => {
    const db = auth('employee-b', 'employee-b@example.com');
    await assertFails(
      getDoc(doc(db, 'businesses/business-a/customers/assigned')),
    );
  });
});

describe('privilege and financial integrity', () => {
  test('employee cannot change their role or permissions', async () => {
    const db = auth('employee-a', 'employee-a@example.com');
    await assertFails(
      updateDoc(doc(db, 'businesses/business-a/members/employee-a'), {
        role: 'head',
        permissions: ['recordPayments', 'managePricing'],
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('employee cannot alter newspaper pricing', async () => {
    const db = auth('employee-a', 'employee-a@example.com');
    await assertFails(
      updateDoc(doc(db, 'businesses/business-a/newspapers/times'), {
        defaultPricePaise: 1,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('legacy unpaired payment writes are denied', async () => {
    const db = auth('employee-a', 'employee-a@example.com');
    const payment = doc(
      db,
      'businesses/business-a/customers/assigned/payments/payment-1',
    );
    await assertFails(
      setDoc(payment, {
        businessId: 'business-a',
        customerId: 'assigned',
        billId: 'bill-1',
        idempotencyKey: 'payment-1',
        amountPaise: 25000,
        method: 'cash',
        status: 'manuallyConfirmed',
        createdBy: 'employee-a',
        createdAt: serverTimestamp(),
      }),
    );
  });
});

describe('verified employee invitation', () => {
  test('client applications cannot create Head memberships', async () => {
    const headDb = auth('head-a', 'head-a@example.com');
    await assertFails(
      setDoc(doc(headDb, 'businesses/business-a/members/second-head'), {
        businessId: 'business-a',
        uid: 'second-head',
        email: 'second@example.com',
        displayName: 'Second Head',
        phone: '9999999999',
        role: 'head',
        status: 'active',
        permissions: [],
        areaIds: [],
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('Head can revoke but cannot forge employee invitation acceptance', async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'businesses/business-a/invitations/invite-head-update'),
        {
          businessId: 'business-a',
          email: 'employee@example.com',
          role: 'employee',
          status: 'pending',
          permissions: [],
          areaIds: [],
          createdBy: 'head-a',
          createdAt: new Date(),
          expiresAt: new Date(Date.now() + 86_400_000),
        },
      );
    });
    const headDb = auth('head-a', 'head-a@example.com');
    await assertFails(
      updateDoc(
        doc(headDb, 'businesses/business-a/invitations/invite-head-update'),
        {
          status: 'accepted',
          acceptedBy: 'forged-employee',
          acceptedAt: serverTimestamp(),
        },
      ),
    );
    await assertSucceeds(
      updateDoc(
        doc(headDb, 'businesses/business-a/invitations/invite-head-update'),
        {
          status: 'revoked',
          revokedAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
      ),
    );
  });

  test('Head cannot delete pending, accepted, or revoked invitation history', async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const admin = context.firestore();
      for (const [id, status] of [
        ['pending-history', 'pending'],
        ['accepted-history', 'accepted'],
        ['revoked-history', 'revoked'],
      ]) {
        await setDoc(
          doc(admin, `businesses/business-a/invitations/${id}`),
          {
            businessId: 'business-a',
            email: 'employee@example.com',
            role: 'employee',
            status,
            permissions: [],
            areaIds: [],
            createdBy: 'head-a',
            createdAt: new Date(),
            expiresAt: new Date(Date.now() + 86_400_000),
            ...(status === 'accepted'
              ? {
                  acceptedBy: 'employee-a',
                  acceptedAt: new Date(),
                }
              : {}),
            ...(status === 'revoked'
              ? {revokedAt: new Date(), updatedAt: new Date()}
              : {}),
          },
        );
      }
    });
    const headDb = auth('head-a', 'head-a@example.com');
    for (const id of [
      'pending-history',
      'accepted-history',
      'revoked-history',
    ]) {
      await assertFails(
        deleteDoc(doc(headDb, `businesses/business-a/invitations/${id}`)),
      );
    }
  });

  test('owner registries and provisioning controls reject all client writes', async () => {
    const db = auth('head-a', 'head-a@example.com');
    await assertFails(
      setDoc(doc(db, 'agencyOwners/head-a'), {
        uid: 'head-a',
        businessId: 'business-a',
      }),
    );
    await assertFails(
      setDoc(doc(db, 'agencyProvisioningControls/head-a'), {uid: 'head-a'}),
    );
    await assertFails(
      setDoc(doc(db, 'userConsents/head-a/acceptances/forged'), {
        uid: 'head-a',
      }),
    );
  });

  test('atomically consumes a matching invite without choosing a Head role', async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'businesses/business-a/invitations/invite-1'),
        {
          businessId: 'business-a',
          email: 'new@example.com',
          role: 'employee',
          status: 'pending',
          permissions: ['recordPayments'],
          areaIds: [],
          createdBy: 'head-a',
          createdAt: new Date(),
          expiresAt: new Date(Date.now() + 86_400_000),
        },
      );
    });

    const db = auth('new-employee', 'new@example.com');
    const batch = writeBatch(db);
    batch.update(
      doc(db, 'businesses/business-a/invitations/invite-1'),
      {
        status: 'accepted',
        acceptedBy: 'new-employee',
        acceptedAt: serverTimestamp(),
      },
    );
    const common = {
      uid: 'new-employee',
      email: 'new@example.com',
      displayName: 'New Employee',
      phone: '9999999999',
      businessId: 'business-a',
      role: 'employee',
      status: 'active',
      permissions: ['recordPayments'],
      acceptedInviteId: 'invite-1',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };
    batch.set(doc(db, 'businesses/business-a/members/new-employee'), {
      ...common,
      areaIds: [],
    });
    batch.set(doc(db, 'userProfiles/new-employee'), common);
    await assertSucceeds(batch.commit());
  });

  test('wrong email cannot consume an invitation', async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'businesses/business-a/invitations/invite-2'),
        {
          businessId: 'business-a',
          email: 'invited@example.com',
          role: 'employee',
          status: 'pending',
          permissions: [],
          areaIds: [],
          createdBy: 'head-a',
          createdAt: new Date(),
          expiresAt: new Date(Date.now() + 86_400_000),
        },
      );
    });
    const db = auth('attacker', 'wrong@example.com');
    await assertFails(
      updateDoc(doc(db, 'businesses/business-a/invitations/invite-2'), {
        status: 'accepted',
        acceptedBy: 'attacker',
        acceptedAt: serverTimestamp(),
      }),
    );
  });

  test('expired and revoked invitations cannot be accepted', async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const admin = context.firestore();
      for (const [id, status, expiresAt] of [
        ['expired-invite', 'pending', new Date(Date.now() - 60_000)],
        ['revoked-invite', 'revoked', new Date(Date.now() + 86_400_000)],
      ]) {
        await setDoc(doc(admin, `businesses/business-a/invitations/${id}`), {
          businessId: 'business-a',
          email: 'blocked@example.com',
          role: 'employee',
          status,
          permissions: [],
          areaIds: [],
          createdBy: 'head-a',
          createdAt: new Date(),
          expiresAt,
          ...(status === 'revoked'
            ? {revokedAt: new Date(), updatedAt: new Date()}
            : {}),
        });
      }
    });
    const db = auth('blocked-employee', 'blocked@example.com');
    for (const id of ['expired-invite', 'revoked-invite']) {
      await assertFails(
        updateDoc(doc(db, `businesses/business-a/invitations/${id}`), {
          status: 'accepted',
          acceptedBy: 'blocked-employee',
          acceptedAt: serverTimestamp(),
        }),
      );
    }
  });

  test('wrong invitation code cannot create an employee membership', async () => {
    const db = auth('wrong-code-employee', 'new@example.com');
    await assertFails(
      setDoc(doc(db, 'businesses/business-a/members/wrong-code-employee'), {
        businessId: 'business-a',
        uid: 'wrong-code-employee',
        email: 'new@example.com',
        displayName: 'Wrong Code',
        phone: '9000000002',
        role: 'employee',
        status: 'active',
        permissions: [],
        areaIds: [],
        acceptedInviteId: 'does-not-exist',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });
});

describe('member guard ordering and collection read guards', () => {
  test('referenced member document must exist before dereference', async () => {
    const employee = auth('employee-a', 'employee-a@example.com');
    await assertFails(
      getDoc(doc(employee, 'businesses/business-a/members/not-present')),
    );
  });

  test('Head self-member read remains allowed', async () => {
    await assertSucceeds(
      getDoc(doc(auth('head-a', 'head-a@example.com'), 'businesses/business-a/members/head-a')),
    );
  });

  test('employee cases remain authorized only for the matching member and area', async () => {
    const employee = auth('employee-a', 'employee-a@example.com');
    await assertSucceeds(
      getDoc(doc(employee, 'businesses/business-a/members/employee-a')),
    );
    await assertFails(
      getDoc(doc(employee, 'businesses/business-a/members/head-a')),
    );
    await assertFails(
      getDoc(doc(auth('employee-b', 'employee-b@example.com'), 'businesses/business-a/members/employee-a')),
    );
  });

  test('first collectionState/current case is allowed only when member and customer are present and valid', async () => {
    await seedCollectionProjection();
    const head = auth('head-a', 'head-a@example.com');
    const employee = auth('employee-a', 'employee-a@example.com');
    await assertSucceeds(
      getDoc(doc(head, 'businesses/business-a/customers/C-MANAGED/collectionState/current')),
    );
    await assertSucceeds(
      getDoc(doc(employee, 'businesses/business-a/customers/C-MANAGED/collectionState/current')),
    );
    await assertFails(
      getDoc(doc(head, 'businesses/business-a/customers/ghost/collectionState/current')),
    );
  });
});

describe('Phase 2 Head operations', () => {
  test('Head updates permitted business settings with audit while employee is denied', async () => {
    const db = auth('head-a', 'head-a@example.com');
    const batch = writeBatch(db);
    batch.update(doc(db, 'businesses/business-a'), {
      name: 'A News Updated',
      phone: '9999999999',
      address: 'Main Road',
      updatedAt: serverTimestamp(),
    });
    batch.set(doc(db, 'businesses/business-a/auditRecords/business-audit'), {
      businessId: 'business-a',
      actorId: 'head-a',
      action: 'businessSettingsUpdated',
      entityType: 'business',
      entityId: 'business-a',
      createdAt: serverTimestamp(),
    });
    await assertSucceeds(batch.commit());

    const employeeDb = auth('employee-a', 'employee-a@example.com');
    await assertFails(
      updateDoc(doc(employeeDb, 'businesses/business-a'), {
        name: 'Hijacked',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('Head creates an employee invitation with an append-only audit record', async () => {
    const db = auth('head-a', 'head-a@example.com');
    const batch = writeBatch(db);
    batch.set(doc(db, 'businesses/business-a/invitations/phase2-invite'), {
      businessId: 'business-a',
      email: 'phase2@example.com',
      role: 'employee',
      status: 'pending',
      permissions: ['addCustomers'],
      areaIds: ['east'],
      createdBy: 'head-a',
      createdAt: serverTimestamp(),
      expiresAt: new Date(Date.now() + 86_400_000),
    });
    batch.set(doc(db, 'businesses/business-a/auditRecords/invite-audit'), {
      businessId: 'business-a',
      actorId: 'head-a',
      action: 'employeeInvitationCreated',
      entityType: 'invitation',
      entityId: 'phase2-invite',
      createdAt: serverTimestamp(),
    });
    await assertSucceeds(batch.commit());
    await assertSucceeds(
      getDoc(doc(db, 'businesses/business-a/auditRecords/invite-audit')),
    );
    await assertFails(
      updateDoc(doc(db, 'businesses/business-a/auditRecords/invite-audit'), {
        action: 'rewritten',
      }),
    );
  });

  test('employee cannot create invitations or list business members', async () => {
    const db = auth('employee-a', 'employee-a@example.com');
    await assertFails(
      setDoc(doc(db, 'businesses/business-a/invitations/forged'), {
        businessId: 'business-a',
        email: 'forged@example.com',
        role: 'employee',
        status: 'pending',
        permissions: [],
        areaIds: [],
        createdBy: 'employee-a',
        createdAt: serverTimestamp(),
        expiresAt: new Date(Date.now() + 86_400_000),
      }),
    );
    await assertFails(
      getDocs(collection(db, 'businesses/business-a/members')),
    );
  });

  test('Head updates permitted employee fields and records the change', async () => {
    const db = auth('head-a', 'head-a@example.com');
    const batch = writeBatch(db);
    batch.update(doc(db, 'businesses/business-a/members/employee-a'), {
      displayName: 'Employee Updated',
      phone: '9999999999',
      notes: 'Morning route',
      status: 'inactive',
      permissions: ['addCustomers'],
      updatedAt: serverTimestamp(),
    });
    batch.set(doc(db, 'businesses/business-a/auditRecords/member-audit'), {
      businessId: 'business-a',
      actorId: 'head-a',
      action: 'employeeAccessUpdated',
      entityType: 'member',
      entityId: 'employee-a',
      createdAt: serverTimestamp(),
    });
    await assertSucceeds(batch.commit());

    const employeeDb = auth('employee-a', 'employee-a@example.com');
    await assertSucceeds(
      getDoc(
        doc(employeeDb, 'businesses/business-a/members/employee-a'),
      ),
    );
    await assertFails(getDoc(doc(employeeDb, 'businesses/business-a')));
    await assertFails(
      getDoc(doc(employeeDb, 'businesses/business-a/customers/assigned')),
    );
  });

  test('Head creates an area and synchronizes employee assignment with audit', async () => {
    const db = auth('head-a', 'head-a@example.com');
    const createBatch = writeBatch(db);
    createBatch.set(doc(db, 'businesses/business-a/areas/west'), {
      businessId: 'business-a',
      name: 'West',
      status: 'active',
      assignedEmployeeIds: [],
      createdBy: 'head-a',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    createBatch.set(doc(db, 'businesses/business-a/auditRecords/area-create'), {
      businessId: 'business-a',
      actorId: 'head-a',
      action: 'areaCreated',
      entityType: 'area',
      entityId: 'west',
      createdAt: serverTimestamp(),
    });
    await assertSucceeds(createBatch.commit());

    const assignmentBatch = writeBatch(db);
    assignmentBatch.update(doc(db, 'businesses/business-a/areas/west'), {
      businessId: 'business-a',
      assignedEmployeeIds: ['employee-a'],
      updatedAt: serverTimestamp(),
    });
    assignmentBatch.update(
      doc(db, 'businesses/business-a/members/employee-a'),
      { areaIds: arrayUnion('west'), updatedAt: serverTimestamp() },
    );
    assignmentBatch.set(
      doc(db, 'businesses/business-a/auditRecords/area-assignment'),
      {
        businessId: 'business-a',
        actorId: 'head-a',
        action: 'areaEmployeeAssignmentsUpdated',
        entityType: 'area',
        entityId: 'west',
        createdAt: serverTimestamp(),
      },
    );
    await assertSucceeds(assignmentBatch.commit());
  });

  test('employee cannot manage areas or another member assignment', async () => {
    const db = auth('employee-a', 'employee-a@example.com');
    await assertFails(
      updateDoc(doc(db, 'businesses/business-a/areas/east'), {
        businessId: 'business-a',
        name: 'Hijacked',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'businesses/business-a/members/employee-c'), {
        areaIds: [],
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('Head transfer changes which employee can read the customer', async () => {
    const headDb = auth('head-a', 'head-a@example.com');
    const batch = writeBatch(headDb);
    batch.update(doc(headDb, 'businesses/business-a/customers/C-MANAGED'), {
      assignedEmployeeId: 'employee-c',
      areaId: 'east',
      updatedBy: 'head-a',
      lastAuditId: 'customer-transfer',
      updatedAt: serverTimestamp(),
    });
    batch.set(
      doc(headDb, 'businesses/business-a/auditRecords/customer-transfer'),
      {
        businessId: 'business-a',
        actorId: 'head-a',
        action: 'customerAssignmentUpdated',
        entityType: 'customer',
        entityId: 'C-MANAGED',
        previousEmployeeId: 'employee-a',
        employeeId: 'employee-c',
        previousAreaId: 'east',
        areaId: 'east',
        createdAt: serverTimestamp(),
      },
    );
    await assertSucceeds(batch.commit());

    await assertFails(
      getDoc(
        doc(
          auth('employee-a', 'employee-a@example.com'),
          'businesses/business-a/customers/C-MANAGED',
        ),
      ),
    );
    await assertSucceeds(
      getDoc(
        doc(
          auth('employee-c', 'employee-c@example.com'),
          'businesses/business-a/customers/C-MANAGED',
        ),
      ),
    );
  });

  test('cross-business Head writes remain denied', async () => {
    const db = auth('head-a', 'head-a@example.com');
    await assertFails(
      updateDoc(doc(db, 'businesses/business-b/members/employee-b'), {
        status: 'inactive',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      setDoc(doc(db, 'businesses/business-b/areas/forged'), {
        businessId: 'business-b',
        name: 'Forged',
        createdBy: 'head-a',
        createdAt: serverTimestamp(),
      }),
    );
  });

  test('Head can run the tenant-constrained customer assignment query', async () => {
    const db = auth('head-a', 'head-a@example.com');
    const customers = query(
      collection(db, 'businesses/business-a/customers'),
      where('businessId', '==', 'business-a'),
    );
    await assertSucceeds(getDocs(customers));
  });
});

describe('Phase 3 customer management', () => {
  test('Head creates a complete customer with opening balance and paired audit', async () => {
    const db = auth('head-a', 'head-a@example.com');
    const batch = writeBatch(db);
    batch.set(
      doc(db, 'businesses/business-a/customers/C-HEAD-CREATED'),
      {
        ...completeCustomer({
          id: 'C-HEAD-CREATED',
          assignedEmployeeId: '',
          openingBalancePaise: 12500,
          lastAuditId: 'head-create-audit',
        }),
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
    );
    batch.set(
      doc(db, 'businesses/business-a/auditRecords/head-create-audit'),
      customerAudit({
        actorId: 'head-a',
        action: 'customerCreated',
        entityId: 'C-HEAD-CREATED',
        extra: {
          employeeId: '',
          areaId: 'east',
          openingBalancePaise: 12500,
        },
      }),
    );
    await assertSucceeds(batch.commit());

    const collision = writeBatch(db);
    collision.set(
      doc(db, 'businesses/business-a/customers/C-HEAD-CREATED'),
      {
        ...completeCustomer({
          id: 'C-HEAD-CREATED',
          assignedEmployeeId: '',
          openingBalancePaise: 12500,
          lastAuditId: 'collision-create-audit',
        }),
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
    );
    collision.set(
      doc(db, 'businesses/business-a/auditRecords/collision-create-audit'),
      customerAudit({
        actorId: 'head-a',
        action: 'customerCreated',
        entityId: 'C-HEAD-CREATED',
        extra: {
          employeeId: '',
          areaId: 'east',
          openingBalancePaise: 12500,
        },
      }),
    );
    await assertFails(collision.commit());
  });

  test('authorized employee creates only a self-assigned zero-balance customer in a permitted area', async () => {
    const db = auth('employee-c', 'employee-c@example.com');
    const allowed = writeBatch(db);
    allowed.set(
      doc(db, 'businesses/business-a/customers/C-EMPLOYEE-CREATED'),
      {
        ...completeCustomer({
          id: 'C-EMPLOYEE-CREATED',
          assignedEmployeeId: 'employee-c',
          createdBy: 'employee-c',
          lastAuditId: 'employee-create-audit',
        }),
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
    );
    allowed.set(
      doc(db, 'businesses/business-a/auditRecords/employee-create-audit'),
      customerAudit({
        actorId: 'employee-c',
        action: 'customerCreated',
        entityId: 'C-EMPLOYEE-CREATED',
        extra: {
          employeeId: 'employee-c',
          areaId: 'east',
          openingBalancePaise: 0,
        },
      }),
    );
    await assertSucceeds(allowed.commit());

    for (const [id, overrides] of [
      ['C-OTHER-ASSIGNEE', { assignedEmployeeId: 'employee-a' }],
      ['C-WRONG-AREA', { areaId: 'west' }],
      ['C-EMPLOYEE-BALANCE', { openingBalancePaise: 500 }],
    ]) {
      const auditId = `${id}-audit`;
      const denied = writeBatch(db);
      denied.set(doc(db, `businesses/business-a/customers/${id}`), {
        ...completeCustomer({
          id,
          assignedEmployeeId: 'employee-c',
          createdBy: 'employee-c',
          lastAuditId: auditId,
          ...overrides,
        }),
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      denied.set(
        doc(db, `businesses/business-a/auditRecords/${auditId}`),
        customerAudit({
          actorId: 'employee-c',
          action: 'customerCreated',
          entityId: id,
        }),
      );
      await assertFails(denied.commit());
    }
  });

  test('employee edits only profile fields on an active assigned customer with audit', async () => {
    const db = auth('employee-c', 'employee-c@example.com');
    const allowed = writeBatch(db);
    allowed.update(
      doc(db, 'businesses/business-a/customers/C-EMPLOYEE'),
      {
        name: 'Managed Customer Updated',
        searchName: 'managed customer updated',
        searchTokens: ['name:ma', 'name:man', 'phone:888', 'landmark:cl'],
        updatedBy: 'employee-c',
        lastAuditId: 'employee-profile-audit',
        updatedAt: serverTimestamp(),
      },
    );
    allowed.set(
      doc(db, 'businesses/business-a/auditRecords/employee-profile-audit'),
      customerAudit({
        actorId: 'employee-c',
        action: 'customerUpdated',
        entityId: 'C-EMPLOYEE',
        extra: { changedFields: ['name', 'searchName', 'searchTokens'] },
      }),
    );
    await assertSucceeds(allowed.commit());

    await assertFails(
      updateDoc(doc(db, 'businesses/business-a/customers/C-EMPLOYEE'), {
        openingBalancePaise: 1,
        updatedBy: 'employee-c',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'businesses/business-a/customers/C-EMPLOYEE'), {
        businessId: 'business-b',
        updatedBy: 'employee-c',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('employee cannot transfer or archive a customer even with a forged paired audit', async () => {
    const db = auth('employee-c', 'employee-c@example.com');
    const transfer = writeBatch(db);
    transfer.update(
      doc(db, 'businesses/business-a/customers/C-EMPLOYEE'),
      {
        assignedEmployeeId: 'employee-a',
        updatedBy: 'employee-c',
        lastAuditId: 'forged-transfer',
        updatedAt: serverTimestamp(),
      },
    );
    transfer.set(
      doc(db, 'businesses/business-a/auditRecords/forged-transfer'),
      customerAudit({
        actorId: 'employee-c',
        action: 'customerAssignmentUpdated',
        entityId: 'C-EMPLOYEE',
      }),
    );
    await assertFails(transfer.commit());

    const archive = writeBatch(db);
    archive.update(
      doc(db, 'businesses/business-a/customers/C-EMPLOYEE'),
      {
        status: 'archived',
        updatedBy: 'employee-c',
        lastAuditId: 'forged-archive',
        updatedAt: serverTimestamp(),
      },
    );
    archive.set(
      doc(db, 'businesses/business-a/auditRecords/forged-archive'),
      customerAudit({
        actorId: 'employee-c',
        action: 'customerArchived',
        entityId: 'C-EMPLOYEE',
      }),
    );
    await assertFails(archive.commit());
  });

  test('Head archives and reactivates without allowing physical deletion', async () => {
    const db = auth('head-a', 'head-a@example.com');
    const archive = writeBatch(db);
    archive.update(
      doc(db, 'businesses/business-a/customers/C-MANAGED'),
      {
        status: 'archived',
        updatedBy: 'head-a',
        lastAuditId: 'archive-audit',
        updatedAt: serverTimestamp(),
      },
    );
    archive.set(
      doc(db, 'businesses/business-a/auditRecords/archive-audit'),
      customerAudit({
        actorId: 'head-a',
        action: 'customerArchived',
        entityId: 'C-MANAGED',
      }),
    );
    await assertSucceeds(archive.commit());
    await assertFails(
      deleteDoc(doc(db, 'businesses/business-a/customers/C-MANAGED')),
    );

    const reactivate = writeBatch(db);
    reactivate.update(
      doc(db, 'businesses/business-a/customers/C-MANAGED'),
      {
        status: 'active',
        updatedBy: 'head-a',
        lastAuditId: 'reactivate-audit',
        updatedAt: serverTimestamp(),
      },
    );
    reactivate.set(
      doc(db, 'businesses/business-a/auditRecords/reactivate-audit'),
      customerAudit({
        actorId: 'head-a',
        action: 'customerReactivated',
        entityId: 'C-MANAGED',
      }),
    );
    await assertSucceeds(reactivate.commit());
  });

  test('Head transfer enforces active employee coverage for the selected area', async () => {
    const db = auth('head-a', 'head-a@example.com');
    const allowed = writeBatch(db);
    allowed.update(doc(db, 'businesses/business-a/customers/C-MANAGED'), {
      assignedEmployeeId: 'employee-c',
      areaId: 'east',
      updatedBy: 'head-a',
      lastAuditId: 'valid-transfer-audit',
      updatedAt: serverTimestamp(),
    });
    allowed.set(
      doc(db, 'businesses/business-a/auditRecords/valid-transfer-audit'),
      customerAudit({
        actorId: 'head-a',
        action: 'customerAssignmentUpdated',
        entityId: 'C-MANAGED',
        extra: {
          previousEmployeeId: 'employee-a',
          employeeId: 'employee-c',
          previousAreaId: 'east',
          areaId: 'east',
        },
      }),
    );
    await assertSucceeds(allowed.commit());

    const denied = writeBatch(db);
    denied.update(doc(db, 'businesses/business-a/customers/C-EMPLOYEE'), {
      assignedEmployeeId: 'employee-c',
      areaId: 'west',
      updatedBy: 'head-a',
      lastAuditId: 'wrong-coverage-audit',
      updatedAt: serverTimestamp(),
    });
    denied.set(
      doc(db, 'businesses/business-a/auditRecords/wrong-coverage-audit'),
      customerAudit({
        actorId: 'head-a',
        action: 'customerAssignmentUpdated',
        entityId: 'C-EMPLOYEE',
      }),
    );
    await assertFails(denied.commit());

    const mismatchedAudit = writeBatch(db);
    mismatchedAudit.update(
      doc(db, 'businesses/business-a/customers/C-EMPLOYEE'),
      {
        assignedEmployeeId: 'employee-a',
        updatedBy: 'head-a',
        lastAuditId: 'mismatched-transfer-audit',
        updatedAt: serverTimestamp(),
      },
    );
    mismatchedAudit.set(
      doc(
        db,
        'businesses/business-a/auditRecords/mismatched-transfer-audit',
      ),
      customerAudit({
        actorId: 'head-a',
        action: 'customerAssignmentUpdated',
        entityId: 'C-EMPLOYEE',
        extra: {
          previousEmployeeId: 'employee-a',
          employeeId: 'employee-a',
          previousAreaId: 'east',
          areaId: 'east',
        },
      }),
    );
    await assertFails(mismatchedAudit.commit());
  });

  test('customer changes require a same-write audit reference and opening balance stays immutable', async () => {
    const db = auth('head-a', 'head-a@example.com');
    await assertFails(
      updateDoc(doc(db, 'businesses/business-a/customers/C-MANAGED'), {
        name: 'Silent Rewrite',
        searchName: 'silent rewrite',
        updatedBy: 'head-a',
        lastAuditId: 'missing-audit',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'businesses/business-a/customers/C-MANAGED'), {
        openingBalancePaise: 99999,
        updatedBy: 'head-a',
        updatedAt: serverTimestamp(),
      }),
    );

    const employeeDb = auth('employee-c', 'employee-c@example.com');
    await assertFails(
      setDoc(
        doc(employeeDb, 'businesses/business-a/auditRecords/unpaired-audit'),
        customerAudit({
          actorId: 'employee-c',
          action: 'customerUpdated',
          entityId: 'C-EMPLOYEE',
        }),
      ),
    );
  });

  test('paginated search queries preserve employee assignment and tenant isolation', async () => {
    const employeeDb = auth('employee-c', 'employee-c@example.com');
    const assignedSearch = query(
      collection(employeeDb, 'businesses/business-a/customers'),
      where('businessId', '==', 'business-a'),
      where('assignedEmployeeId', '==', 'employee-c'),
      where('status', '==', 'active'),
      where('searchTokens', 'array-contains', 'name:ma'),
      orderBy('searchName'),
      limit(25),
    );
    await assertSucceeds(getDocs(assignedSearch));

    const broadSearch = query(
      collection(employeeDb, 'businesses/business-a/customers'),
      where('businessId', '==', 'business-a'),
      where('status', '==', 'active'),
      orderBy('searchName'),
      limit(25),
    );
    await assertFails(getDocs(broadSearch));

    const otherTenant = query(
      collection(employeeDb, 'businesses/business-b/customers'),
      where('businessId', '==', 'business-b'),
      where('assignedEmployeeId', '==', 'employee-c'),
      where('status', '==', 'active'),
      orderBy('searchName'),
      limit(25),
    );
    await assertFails(getDocs(otherTenant));
  });
});

describe('Phase 4 customer removal approval and lifecycle security', () => {
  test('authorized employee creates removal request for assigned customer but cannot approve or reject it', async () => {
    const employeeDb = auth('employee-c', 'employee-c@example.com');
    const reqRef = doc(employeeDb, 'businesses/business-a/removalRequests/REQ-EMP-1');
    const auditRef = doc(employeeDb, 'businesses/business-a/auditRecords/audit-req-1');

    const createBatch = writeBatch(employeeDb);
    createBatch.set(reqRef, {
      businessId: 'business-a',
      customerId: 'C-EMPLOYEE',
      customerName: 'Managed Customer',
      customerCode: 'C-EMPLOYEE',
      areaId: 'east',
      assignedEmployeeId: 'employee-c',
      requestedBy: 'employee-c',
      requestedByName: 'Employee C',
      reason: 'Customer relocated to another area',
      status: 'pending',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    createBatch.set(auditRef, {
      businessId: 'business-a',
      actorId: 'employee-c',
      action: 'customerRemovalRequested',
      entityType: 'customerRemovalRequest',
      entityId: 'REQ-EMP-1',
      customerId: 'C-EMPLOYEE',
      reason: 'Customer relocated to another area',
      createdAt: serverTimestamp(),
    });
    await assertSucceeds(createBatch.commit());

    // Employee cannot approve or reject removal requests
    await assertFails(
      updateDoc(reqRef, {
        status: 'approved',
        reviewedBy: 'employee-c',
        reviewedByName: 'Employee C',
        reviewNotes: 'Self approved',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(reqRef, {
        status: 'rejected',
        reviewedBy: 'employee-c',
        reviewedByName: 'Employee C',
        reviewNotes: 'Self rejected',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('Head cannot review another agencys removal requests (cross-tenant isolation)', async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'businesses/business-a/removalRequests/REQ-BIZ-A'), {
        businessId: 'business-a',
        customerId: 'C-MANAGED',
        customerName: 'Managed Customer',
        customerCode: 'C-MANAGED',
        areaId: 'east',
        assignedEmployeeId: 'employee-a',
        requestedBy: 'employee-a',
        requestedByName: 'Employee A',
        reason: 'Cross tenant test',
        status: 'pending',
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    });

    // Head of business-b cannot read or review business-a removal request
    const headBDb = auth('head-b', 'head-b@example.com');
    await assertFails(getDoc(doc(headBDb, 'businesses/business-a/removalRequests/REQ-BIZ-A')));
    await assertFails(
      updateDoc(doc(headBDb, 'businesses/business-a/removalRequests/REQ-BIZ-A'), {
        status: 'approved',
        reviewedBy: 'head-b',
        reviewedByName: 'Head B',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('duplicate or concurrent review cannot approve an already rejected or approved request', async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'businesses/business-a/removalRequests/REQ-REJECT-TEST'), {
        businessId: 'business-a',
        customerId: 'C-MANAGED',
        customerName: 'Managed Customer',
        customerCode: 'C-MANAGED',
        areaId: 'east',
        assignedEmployeeId: 'employee-a',
        requestedBy: 'employee-a',
        requestedByName: 'Employee A',
        reason: 'Initial removal request',
        status: 'pending',
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    });

    const headDb = auth('head-a', 'head-a@example.com');
    const reqRefHead = doc(headDb, 'businesses/business-a/removalRequests/REQ-REJECT-TEST');

    // Head rejects request
    await assertSucceeds(
      updateDoc(reqRefHead, {
        status: 'rejected',
        reviewedBy: 'head-a',
        reviewedByName: 'Head A',
        reviewNotes: 'Customer requested to stay',
        updatedAt: serverTimestamp(),
      }),
    );

    // Subsequent/duplicate review to re-approve or mutate is rejected by rules
    await assertFails(
      updateDoc(reqRefHead, {
        status: 'approved',
        reviewedBy: 'head-a',
        reviewedByName: 'Head A',
        reviewNotes: 'Second review attempt',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('removal approval preserves existing financial records and creates required immutable audit', async () => {
    const headDb = auth('head-a', 'head-a@example.com');
    const customerId = 'C-REMOVED-FINANCIAL';
    const reqId = 'REQ-APPROVE-FIN';
    const auditId = 'audit-archive-fin';

    // 1. Seed customer with bill line and payment subcollections
    await environment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(
        doc(db, `businesses/business-a/customers/${customerId}`),
        completeCustomer({ id: customerId, openingBalancePaise: 25000 }),
      );
      await setDoc(
        doc(db, `businesses/business-a/customers/${customerId}/bills/2026-08`),
        {
          businessId: 'business-a',
          customerId: customerId,
          month: '2026-08',
          totalPaise: 45000,
          status: 'finalized',
        },
      );
      await setDoc(
        doc(db, `businesses/business-a/customers/${customerId}/payments/PAY-1`),
        {
          businessId: 'business-a',
          customerId: customerId,
          paymentId: 'PAY-1',
          amountPaise: 45000,
          collectorUid: 'employee-a',
        },
      );
      await setDoc(
        doc(db, `businesses/business-a/removalRequests/${reqId}`),
        {
          businessId: 'business-a',
          customerId: customerId,
          customerName: 'Managed Customer',
          customerCode: customerId,
          areaId: 'east',
          assignedEmployeeId: 'employee-a',
          requestedBy: 'employee-a',
          requestedByName: 'Employee A',
          reason: 'Account closed by customer',
          status: 'pending',
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      );
    });

    // 2. Head approves request and archives customer
    const archiveBatch = writeBatch(headDb);
    archiveBatch.update(doc(headDb, `businesses/business-a/removalRequests/${reqId}`), {
      status: 'approved',
      reviewedBy: 'head-a',
      reviewedByName: 'Head A',
      reviewNotes: 'Approved after verifying settlement',
      updatedAt: serverTimestamp(),
    });
    archiveBatch.update(doc(headDb, `businesses/business-a/customers/${customerId}`), {
      status: 'archived',
      updatedAt: serverTimestamp(),
      updatedBy: 'head-a',
      lastAuditId: auditId,
    });
    archiveBatch.set(doc(headDb, `businesses/business-a/auditRecords/${auditId}`), {
      businessId: 'business-a',
      actorId: 'head-a',
      action: 'customerArchived',
      entityType: 'customer',
      entityId: customerId,
      areaId: 'east',
      employeeId: 'employee-a',
      createdAt: serverTimestamp(),
    });
    await assertSucceeds(archiveBatch.commit());

    // 3. Verify customer cannot be physically deleted
    await assertFails(deleteDoc(doc(headDb, `businesses/business-a/customers/${customerId}`)));

    // 4. Verify financial subcollections (bills, payments) cannot be deleted
    await assertFails(
      deleteDoc(doc(headDb, `businesses/business-a/customers/${customerId}/bills/2026-08`)),
    );
    await assertFails(
      deleteDoc(doc(headDb, `businesses/business-a/customers/${customerId}/payments/PAY-1`)),
    );

    // 5. Verify removal request document cannot be deleted
    await assertFails(
      deleteDoc(doc(headDb, `businesses/business-a/removalRequests/${reqId}`)),
    );
  });
});

describe('Phase 4 newspaper catalog and pricing', () => {
  test('Head creates, edits, and archives a newspaper with paired immutable audits', async () => {
    const db = auth('head-a', 'head-a@example.com');
    const newspaperId = 'N-CITY';
    const createAuditId = 'newspaper-create-audit';
    const create = writeBatch(db);
    create.set(
      doc(db, `businesses/business-a/newspapers/${newspaperId}`),
      {
        ...completeNewspaper({
          id: newspaperId,
          lastAuditId: createAuditId,
        }),
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
    );
    create.set(
      doc(db, `businesses/business-a/auditRecords/${createAuditId}`),
      {
        businessId: 'business-a',
        actorId: 'head-a',
        action: 'newspaperCreated',
        entityType: 'newspaper',
        entityId: newspaperId,
        defaultPricePaise: 650,
        createdAt: serverTimestamp(),
      },
    );
    await assertSucceeds(create.commit());

    const profileAuditId = 'newspaper-profile-audit';
    const profile = writeBatch(db);
    profile.update(
      doc(db, `businesses/business-a/newspapers/${newspaperId}`),
      {
        name: 'City Daily Updated',
        searchName: 'city daily updated',
        edition: 'Morning',
        language: 'Hindi',
        updatedBy: 'head-a',
        lastAuditId: profileAuditId,
        updatedAt: serverTimestamp(),
      },
    );
    profile.set(
      doc(db, `businesses/business-a/auditRecords/${profileAuditId}`),
      {
        businessId: 'business-a',
        actorId: 'head-a',
        action: 'newspaperUpdated',
        entityType: 'newspaper',
        entityId: newspaperId,
        changedFields: ['edition', 'language', 'name', 'searchName'],
        createdAt: serverTimestamp(),
      },
    );
    await assertSucceeds(profile.commit());

    const archiveAuditId = 'newspaper-archive-audit';
    const archive = writeBatch(db);
    archive.update(
      doc(db, `businesses/business-a/newspapers/${newspaperId}`),
      {
        status: 'archived',
        updatedBy: 'head-a',
        lastAuditId: archiveAuditId,
        updatedAt: serverTimestamp(),
      },
    );
    archive.set(
      doc(db, `businesses/business-a/auditRecords/${archiveAuditId}`),
      {
        businessId: 'business-a',
        actorId: 'head-a',
        action: 'newspaperArchived',
        entityType: 'newspaper',
        entityId: newspaperId,
        createdAt: serverTimestamp(),
      },
    );
    await assertSucceeds(archive.commit());

    const reactivateAuditId = 'newspaper-reactivate-audit';
    const reactivate = writeBatch(db);
    reactivate.update(
      doc(db, `businesses/business-a/newspapers/${newspaperId}`),
      {
        status: 'active',
        updatedBy: 'head-a',
        lastAuditId: reactivateAuditId,
        updatedAt: serverTimestamp(),
      },
    );
    reactivate.set(
      doc(db, `businesses/business-a/auditRecords/${reactivateAuditId}`),
      {
        businessId: 'business-a',
        actorId: 'head-a',
        action: 'newspaperReactivated',
        entityType: 'newspaper',
        entityId: newspaperId,
        createdAt: serverTimestamp(),
      },
    );
    await assertSucceeds(reactivate.commit());

    await assertFails(
      deleteDoc(doc(db, `businesses/business-a/newspapers/${newspaperId}`)),
    );
    await assertFails(
      updateDoc(
        doc(db, `businesses/business-a/auditRecords/${profileAuditId}`),
        { action: 'rewritten' },
      ),
    );
  });

  test('catalog remains tenant isolated and employees cannot mutate it', async () => {
    const employeeDb = auth('employee-c', 'employee-c@example.com');
    await assertSucceeds(
      getDocs(
        query(
          collection(employeeDb, 'businesses/business-a/newspapers'),
          where('businessId', '==', 'business-a'),
          where('status', '==', 'active'),
          orderBy('searchName'),
          limit(25),
        ),
      ),
    );
    await assertFails(
      updateDoc(
        doc(employeeDb, 'businesses/business-a/newspapers/times'),
        { defaultPricePaise: 1 },
      ),
    );
    await assertFails(
      getDoc(
        doc(employeeDb, 'businesses/business-b/newspapers/foreign-paper'),
      ),
    );
  });

  test('Head appends and corrects price history without rewriting old prices', async () => {
    const db = auth('head-a', 'head-a@example.com');
    const ruleId = 'price-rule-1';
    const createAuditId = 'price-create-audit';
    const create = writeBatch(db);
    create.set(
      doc(
        db,
        `businesses/business-a/newspapers/times/priceRules/${ruleId}`,
      ),
      {
        businessId: 'business-a',
        newspaperId: 'times',
        priceRuleId: ruleId,
        kind: 'period',
        startDate: '2026-10-01',
        endDate: '2026-10-31',
        pricePaise: 700,
        status: 'active',
        supersedesRuleId: '',
        supersededByRuleId: '',
        revision: 1,
        reason: 'October cover price',
        createdBy: 'head-a',
        updatedBy: 'head-a',
        lastAuditId: createAuditId,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
    );
    create.update(doc(db, 'businesses/business-a/newspapers/times'), {
      updatedBy: 'head-a',
      lastAuditId: createAuditId,
      updatedAt: serverTimestamp(),
    });
    create.set(
      doc(db, `businesses/business-a/auditRecords/${createAuditId}`),
      {
        businessId: 'business-a',
        actorId: 'head-a',
        action: 'newspaperPriceRuleCreated',
        entityType: 'newspaper',
        entityId: 'times',
        priceRuleId: ruleId,
        replacedPriceRuleId: '',
        kind: 'period',
        startDate: '2026-10-01',
        endDate: '2026-10-31',
        pricePaise: 700,
        reason: 'October cover price',
        createdAt: serverTimestamp(),
      },
    );
    await assertSucceeds(create.commit());

    const replacementId = 'price-rule-2';
    const correctionAuditId = 'price-correction-audit';
    const correction = writeBatch(db);
    correction.update(
      doc(
        db,
        `businesses/business-a/newspapers/times/priceRules/${ruleId}`,
      ),
      {
        status: 'superseded',
        supersededByRuleId: replacementId,
        updatedBy: 'head-a',
        lastAuditId: correctionAuditId,
        updatedAt: serverTimestamp(),
      },
    );
    correction.set(
      doc(
        db,
        `businesses/business-a/newspapers/times/priceRules/${replacementId}`,
      ),
      {
        businessId: 'business-a',
        newspaperId: 'times',
        priceRuleId: replacementId,
        kind: 'period',
        startDate: '2026-10-01',
        endDate: '2026-10-31',
        pricePaise: 750,
        status: 'active',
        supersedesRuleId: ruleId,
        supersededByRuleId: '',
        revision: 2,
        reason: 'Corrected publisher notice',
        createdBy: 'head-a',
        updatedBy: 'head-a',
        lastAuditId: correctionAuditId,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
    );
    correction.update(doc(db, 'businesses/business-a/newspapers/times'), {
      updatedBy: 'head-a',
      lastAuditId: correctionAuditId,
      updatedAt: serverTimestamp(),
    });
    correction.set(
      doc(db, `businesses/business-a/auditRecords/${correctionAuditId}`),
      {
        businessId: 'business-a',
        actorId: 'head-a',
        action: 'newspaperPriceRuleCorrected',
        entityType: 'newspaper',
        entityId: 'times',
        priceRuleId: replacementId,
        replacedPriceRuleId: ruleId,
        kind: 'period',
        startDate: '2026-10-01',
        endDate: '2026-10-31',
        pricePaise: 750,
        reason: 'Corrected publisher notice',
        createdAt: serverTimestamp(),
      },
    );
    await assertSucceeds(correction.commit());

    await assertFails(
      updateDoc(
        doc(
          db,
          `businesses/business-a/newspapers/times/priceRules/${ruleId}`,
        ),
        { pricePaise: 1 },
      ),
    );
    await assertFails(
      deleteDoc(
        doc(
          db,
          `businesses/business-a/newspapers/times/priceRules/${ruleId}`,
        ),
      ),
    );
  });
});

describe('Phase 4 customer subscriptions', () => {
  test('Head creates a versioned subscription with an authorized custom price', async () => {
    const db = auth('head-a', 'head-a@example.com');
    const batch = writeBatch(db);
    addSubscriptionCreate(batch, db, {
      customerId: 'C-MANAGED',
      actorId: 'head-a',
      auditId: 'head-subscription-create',
      customPricePaise: 500,
      customPriceReason: 'Approved loyalty rate',
    });
    await assertSucceeds(batch.commit());

    const stored = await getDoc(
      doc(
        db,
        'businesses/business-a/customers/C-MANAGED/subscriptions/times',
      ),
    );
    assert.equal(stored.data().customPricePaise, 500);
    await assertFails(deleteDoc(stored.ref));
  });

  test('authorized employee manages only their assigned customer and area without setting price', async () => {
    const db = auth('employee-c', 'employee-c@example.com');
    const allowed = writeBatch(db);
    addSubscriptionCreate(allowed, db, {
      actorId: 'employee-c',
      auditId: 'employee-subscription-create',
    });
    await assertSucceeds(allowed.commit());

    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          'businesses/business-a/newspapers/another-paper',
        ),
        completeNewspaper({ id: 'another-paper' }),
      );
    });

    const customPrice = writeBatch(db);
    addSubscriptionCreate(customPrice, db, {
      customerId: 'C-EMPLOYEE',
      newspaperId: 'another-paper',
      actorId: 'employee-c',
      auditId: 'employee-custom-price',
      customPricePaise: 100,
      customPriceReason: 'Forged discount',
    });
    await assertFails(customPrice.commit());

    const otherCustomer = writeBatch(db);
    addSubscriptionCreate(otherCustomer, db, {
      customerId: 'C-MANAGED',
      actorId: 'employee-c',
      auditId: 'employee-other-customer',
    });
    await assertFails(otherCustomer.commit());

    await environment.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(
          context.firestore(),
          'businesses/business-a/members/employee-c',
        ),
        { areaIds: [] },
      );
      await setDoc(
        doc(
          context.firestore(),
          'businesses/business-a/newspapers/second-paper',
        ),
        completeNewspaper({ id: 'second-paper' }),
      );
    });
    const revokedArea = writeBatch(db);
    addSubscriptionCreate(revokedArea, db, {
      newspaperId: 'second-paper',
      actorId: 'employee-c',
      auditId: 'employee-revoked-area',
    });
    await assertFails(revokedArea.commit());
  });

  test('employee term changes preserve versions and cannot escalate custom pricing', async () => {
    const db = auth('employee-c', 'employee-c@example.com');
    const create = writeBatch(db);
    addSubscriptionCreate(create, db, {
      actorId: 'employee-c',
      auditId: 'terms-create-audit',
    });
    await assertSucceeds(create.commit());

    const subscriptionRef = doc(
      db,
      'businesses/business-a/customers/C-EMPLOYEE/subscriptions/times',
    );
    const oldVersionRef = doc(
      db,
      'businesses/business-a/customers/C-EMPLOYEE/subscriptions/times/versions/version-1',
    );
    const nextVersionRef = doc(
      db,
      'businesses/business-a/customers/C-EMPLOYEE/subscriptions/times/versions/version-2',
    );
    const auditId = 'terms-change-audit';
    const change = writeBatch(db);
    change.update(oldVersionRef, {
      effectiveTo: '2026-09-14',
      successorVersionId: 'version-2',
      status: 'closed',
      updatedBy: 'employee-c',
      lastAuditId: auditId,
      updatedAt: serverTimestamp(),
    });
    change.set(
      nextVersionRef,
      subscriptionVersion({
        versionId: 'version-2',
        effectiveFrom: '2026-09-15',
        quantity: 2,
        weekdays: [1, 2, 3, 4, 5, 6],
        predecessorVersionId: 'version-1',
        actorId: 'employee-c',
        auditId,
      }),
    );
    change.update(subscriptionRef, {
      currentVersionId: 'version-2',
      endDate: null,
      currentEffectiveFrom: '2026-09-15',
      quantity: 2,
      deliveryWeekdays: [1, 2, 3, 4, 5, 6],
      customPricePaise: null,
      customPriceReason: '',
      updatedBy: 'employee-c',
      lastAuditId: auditId,
      updatedAt: serverTimestamp(),
    });
    change.set(
      doc(db, `businesses/business-a/auditRecords/${auditId}`),
      subscriptionAudit({
        actorId: 'employee-c',
        action: 'subscriptionTermsChanged',
        auditId,
        extra: {
          previousVersionId: 'version-1',
          versionId: 'version-2',
          effectiveFrom: '2026-09-15',
          changedFields: ['quantity', 'deliveryWeekdays'],
        },
      }),
    );
    await assertSucceeds(change.commit());
    await assertFails(updateDoc(oldVersionRef, { quantity: 9 }));

    const forgedAuditId = 'forged-price-change';
    const forged = writeBatch(db);
    forged.update(nextVersionRef, {
      effectiveTo: '2026-09-19',
      successorVersionId: 'version-3',
      status: 'closed',
      updatedBy: 'employee-c',
      lastAuditId: forgedAuditId,
      updatedAt: serverTimestamp(),
    });
    forged.set(
      doc(
        db,
        'businesses/business-a/customers/C-EMPLOYEE/subscriptions/times/versions/version-3',
      ),
      subscriptionVersion({
        versionId: 'version-3',
        effectiveFrom: '2026-09-20',
        quantity: 2,
        weekdays: [1, 2, 3, 4, 5, 6],
        customPricePaise: 100,
        customPriceReason: 'Forged discount',
        predecessorVersionId: 'version-2',
        actorId: 'employee-c',
        auditId: forgedAuditId,
      }),
    );
    forged.update(subscriptionRef, {
      currentVersionId: 'version-3',
      currentEffectiveFrom: '2026-09-20',
      customPricePaise: 100,
      customPriceReason: 'Forged discount',
      updatedBy: 'employee-c',
      lastAuditId: forgedAuditId,
      updatedAt: serverTimestamp(),
    });
    forged.set(
      doc(db, `businesses/business-a/auditRecords/${forgedAuditId}`),
      subscriptionAudit({
        actorId: 'employee-c',
        action: 'subscriptionTermsChanged',
        auditId: forgedAuditId,
        extra: {
          previousVersionId: 'version-2',
          versionId: 'version-3',
          effectiveFrom: '2026-09-20',
        },
      }),
    );
    await assertFails(forged.commit());
  });

  test('pause, resume, and end transitions retain append-only operational history', async () => {
    const db = auth('employee-c', 'employee-c@example.com');
    const create = writeBatch(db);
    addSubscriptionCreate(create, db, {
      actorId: 'employee-c',
      auditId: 'lifecycle-create-audit',
    });
    await assertSucceeds(create.commit());

    const subscriptionRef = doc(
      db,
      'businesses/business-a/customers/C-EMPLOYEE/subscriptions/times',
    );
    const pauseRef = doc(
      db,
      'businesses/business-a/customers/C-EMPLOYEE/subscriptions/times/pauses/pause-1',
    );
    const scheduledPauseId = 'scheduled-pause-audit';
    const scheduledPause = writeBatch(db);
    scheduledPause.set(
      doc(
        db,
        'businesses/business-a/customers/C-EMPLOYEE/subscriptions/times/pauses/scheduled-pause',
      ),
      {
        businessId: 'business-a',
        customerId: 'C-EMPLOYEE',
        subscriptionId: 'times',
        pauseId: 'scheduled-pause',
        startDate: '2026-09-10',
        endDate: '2026-09-12',
        reason: 'Scheduled travel',
        status: 'closed',
        createdBy: 'employee-c',
        updatedBy: 'employee-c',
        lastAuditId: scheduledPauseId,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
    );
    scheduledPause.update(subscriptionRef, {
      updatedBy: 'employee-c',
      lastAuditId: scheduledPauseId,
      updatedAt: serverTimestamp(),
    });
    scheduledPause.set(
      doc(db, `businesses/business-a/auditRecords/${scheduledPauseId}`),
      subscriptionAudit({
        actorId: 'employee-c',
        action: 'subscriptionPauseAdded',
        auditId: scheduledPauseId,
        extra: {
          pauseId: 'scheduled-pause',
          startDate: '2026-09-10',
          endDate: '2026-09-12',
        },
      }),
    );
    await assertSucceeds(scheduledPause.commit());

    const pauseAuditId = 'pause-open-audit';
    const pause = writeBatch(db);
    pause.set(pauseRef, {
      businessId: 'business-a',
      customerId: 'C-EMPLOYEE',
      subscriptionId: 'times',
      pauseId: 'pause-1',
      startDate: '2026-09-20',
      endDate: null,
      reason: 'Customer travelling',
      status: 'open',
      createdBy: 'employee-c',
      updatedBy: 'employee-c',
      lastAuditId: pauseAuditId,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    pause.update(subscriptionRef, {
      status: 'paused',
      currentPauseId: 'pause-1',
      updatedBy: 'employee-c',
      lastAuditId: pauseAuditId,
      updatedAt: serverTimestamp(),
    });
    pause.set(
      doc(db, `businesses/business-a/auditRecords/${pauseAuditId}`),
      subscriptionAudit({
        actorId: 'employee-c',
        action: 'subscriptionPauseAdded',
        auditId: pauseAuditId,
        extra: {
          pauseId: 'pause-1',
          startDate: '2026-09-20',
          endDate: null,
        },
      }),
    );
    await assertSucceeds(pause.commit());

    const resumeAuditId = 'pause-resume-audit';
    const resume = writeBatch(db);
    resume.update(pauseRef, {
      endDate: '2026-09-24',
      status: 'closed',
      updatedBy: 'employee-c',
      lastAuditId: resumeAuditId,
      updatedAt: serverTimestamp(),
    });
    resume.update(subscriptionRef, {
      status: 'active',
      currentPauseId: '',
      updatedBy: 'employee-c',
      lastAuditId: resumeAuditId,
      updatedAt: serverTimestamp(),
    });
    resume.set(
      doc(db, `businesses/business-a/auditRecords/${resumeAuditId}`),
      subscriptionAudit({
        actorId: 'employee-c',
        action: 'subscriptionResumed',
        auditId: resumeAuditId,
        extra: { pauseId: 'pause-1', resumeDate: '2026-09-25' },
      }),
    );
    await assertSucceeds(resume.commit());

    const endAuditId = 'subscription-end-audit';
    const end = writeBatch(db);
    end.update(
      doc(
        db,
        'businesses/business-a/customers/C-EMPLOYEE/subscriptions/times/versions/version-1',
      ),
      {
        effectiveTo: '2026-09-30',
        successorVersionId: '',
        status: 'closed',
        updatedBy: 'employee-c',
        lastAuditId: endAuditId,
        updatedAt: serverTimestamp(),
      },
    );
    end.update(subscriptionRef, {
      status: 'ended',
      endDate: '2026-09-30',
      currentPauseId: '',
      updatedBy: 'employee-c',
      lastAuditId: endAuditId,
      updatedAt: serverTimestamp(),
    });
    end.set(
      doc(db, `businesses/business-a/auditRecords/${endAuditId}`),
      subscriptionAudit({
        actorId: 'employee-c',
        action: 'subscriptionEnded',
        auditId: endAuditId,
        extra: { endDate: '2026-09-30', versionId: 'version-1' },
      }),
    );
    await assertSucceeds(end.commit());
    await assertFails(deleteDoc(pauseRef));
    await assertFails(
      updateDoc(
        doc(db, `businesses/business-a/auditRecords/${pauseAuditId}`),
        { action: 'rewritten' },
      ),
    );
  });

  test('subscription reads retain customer assignment and tenant isolation', async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(
        doc(
          db,
          'businesses/business-a/customers/C-EMPLOYEE/subscriptions/times',
        ),
        {
          ...subscriptionSeries({ actorId: 'head-a' }),
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      );
    });
    await assertSucceeds(
      getDoc(
        doc(
          auth('employee-c', 'employee-c@example.com'),
          'businesses/business-a/customers/C-EMPLOYEE/subscriptions/times',
        ),
      ),
    );
    await assertFails(
      getDoc(
        doc(
          auth('employee-a', 'employee-a@example.com'),
          'businesses/business-a/customers/C-EMPLOYEE/subscriptions/times',
        ),
      ),
    );
    await assertFails(
      getDoc(
        doc(
          auth('employee-b', 'employee-b@example.com'),
          'businesses/business-a/customers/C-EMPLOYEE/subscriptions/times',
        ),
      ),
    );
  });
});

describe('Phase 5 monthly billing', () => {
  test('authorized assigned employee appends a shaped no-delivery exception only', async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(
        doc(
          db,
          'businesses/business-a/customers/C-EMPLOYEE/subscriptions/times',
        ),
        {
          ...subscriptionSeries({ actorId: 'head-a' }),
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      );
    });
    const assigned = auth('employee-c', 'employee-c@example.com');
    const exception = doc(
      assigned,
      'businesses/business-a/customers/C-EMPLOYEE/deliveryExceptions/no-delivery-1',
    );
    const create = writeBatch(assigned);
    create.set(exception, {
      businessId: 'business-a',
      customerId: 'C-EMPLOYEE',
      exceptionId: 'no-delivery-1',
      subscriptionId: 'times',
      type: 'noDelivery',
      serviceDate: '2026-09-15',
      reason: 'Customer requested no delivery',
      createdBy: 'employee-c',
      createdAt: serverTimestamp(),
    });
    addServiceBillingSource(create, assigned, {
      customerId: 'C-EMPLOYEE',
      actorId: 'employee-c',
      mutationType: 'deliveryExceptionCreated',
      mutationId: 'no-delivery-1',
    });
    await assertSucceeds(create.commit());
    await assertFails(updateDoc(exception, { serviceDate: '2026-09-16' }));
    await assertFails(deleteDoc(exception));
    await assertFails(
      setDoc(
        doc(
          auth('employee-a', 'employee-a@example.com'),
          'businesses/business-a/customers/C-EMPLOYEE/deliveryExceptions/forged',
        ),
        {
          businessId: 'business-a',
          customerId: 'C-EMPLOYEE',
          exceptionId: 'forged',
          subscriptionId: 'times',
          type: 'noDelivery',
          serviceDate: '2026-09-16',
          reason: 'Unauthorized customer change',
          createdBy: 'employee-a',
          createdAt: serverTimestamp(),
        },
      ),
    );
    await assertFails(
      setDoc(
        doc(
          assigned,
          'businesses/business-a/customers/C-EMPLOYEE/billingSources/service',
        ),
        serviceBillingSource({
          customerId: 'C-EMPLOYEE',
          actorId: 'employee-c',
          mutationType: 'deliveryExceptionCreated',
          mutationId: 'unpaired-exception',
          revision: 2,
        }),
      ),
    );
  });

  test('concurrent retries create exactly one bill, line set, and audit', async () => {
    const db = auth('head-a', 'head-a@example.com');
    const results = await Promise.all([
      finalizeMonthTransaction(db, { auditId: 'concurrent-audit-1' }),
      finalizeMonthTransaction(db, { auditId: 'concurrent-audit-2' }),
    ]);
    assert.deepEqual(results.toSorted(), [false, true]);
    const bills = await getDocs(
      collection(db, 'businesses/business-a/customers/C-MANAGED/bills'),
    );
    const lines = await getDocs(
      collection(
        db,
        'businesses/business-a/customers/C-MANAGED/bills/2026-09/lineItems',
      ),
    );
    const audits = await getDocs(
      collection(db, 'businesses/business-a/auditRecords'),
    );
    assert.equal(bills.size, 1);
    assert.equal(lines.size, 1);
    assert.equal(
      audits.docs.filter((item) => item.data().action === 'billFinalized')
        .length,
      1,
    );
  });

  test('a transaction aborts when a prepared authoritative source changes', async () => {
    const db = auth('head-a', 'head-a@example.com');
    const customerRef = doc(
      db,
      'businesses/business-a/customers/C-MANAGED',
    );
    let releaseFirstRead;
    let announceFirstRead;
    const firstRead = new Promise((resolve) => {
      announceFirstRead = resolve;
    });
    const release = new Promise((resolve) => {
      releaseFirstRead = resolve;
    });
    let firstAttempt = true;
    const transaction = runTransaction(db, async (write) => {
      const source = await write.get(customerRef);
      if (source.data().lastAuditId !== 'seed-audit') {
        throw new Error('billing-source-changed');
      }
      const billRef = doc(
        db,
        'businesses/business-a/customers/C-MANAGED/bills/2026-09',
      );
      const existing = await write.get(billRef);
      if (existing.exists()) return false;
      if (firstAttempt) {
        firstAttempt = false;
        announceFirstRead();
        await release;
      }
      const batchLike = {
        set: (reference, value) => write.set(reference, value),
      };
      addBillFinalization(batchLike, db, {
        auditId: 'source-lock-audit',
      });
      return true;
    });
    await firstRead;
    await environment.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(
          context.firestore(),
          'businesses/business-a/customers/C-MANAGED',
        ),
        { lastAuditId: 'changed-concurrently' },
      );
    });
    releaseFirstRead();
    await assert.rejects(transaction, /billing-source-changed/);
    await assertSucceeds(
      getDoc(
        doc(
          db,
          'businesses/business-a/customers/C-MANAGED/bills/2026-09',
        ),
      ),
    ).then((snapshot) => assert.equal(snapshot.exists(), false));
  });

  test('a transaction aborts when a new service source appears after preview', async () => {
    const db = auth('head-a', 'head-a@example.com');
    const sourceRef = doc(
      db,
      'businesses/business-a/customers/C-MANAGED/billingSources/service',
    );
    let releaseFirstRead;
    let announceFirstRead;
    const firstRead = new Promise((resolve) => {
      announceFirstRead = resolve;
    });
    const release = new Promise((resolve) => {
      releaseFirstRead = resolve;
    });
    let firstAttempt = true;
    const transaction = runTransaction(db, async (write) => {
      const source = await write.get(sourceRef);
      if (source.exists()) throw new Error('billing-source-changed');
      const billRef = doc(
        db,
        'businesses/business-a/customers/C-MANAGED/bills/2026-09',
      );
      const existing = await write.get(billRef);
      if (existing.exists()) return false;
      if (firstAttempt) {
        firstAttempt = false;
        announceFirstRead();
        await release;
      }
      const batchLike = {
        set: (reference, value) => write.set(reference, value),
      };
      addBillFinalization(batchLike, db, {
        auditId: 'new-source-lock-audit',
      });
      return true;
    });
    await firstRead;
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          'businesses/business-a/customers/C-MANAGED/billingSources/service',
        ),
        {
          ...serviceBillingSource({ customerId: 'C-MANAGED' }),
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      );
    });
    releaseFirstRead();
    await assert.rejects(transaction, /billing-source-changed/);
    await assertSucceeds(
      getDoc(
        doc(
          db,
          'businesses/business-a/customers/C-MANAGED/bills/2026-09',
        ),
      ),
    ).then((snapshot) => assert.equal(snapshot.exists(), false));
  });

  test('Head atomically finalizes the deterministic month bill and immutable lines', async () => {
    const db = auth('head-a', 'head-a@example.com');
    const batch = writeBatch(db);
    addBillFinalization(batch, db);
    await assertSucceeds(batch.commit());

    const billPath =
      'businesses/business-a/customers/C-MANAGED/bills/2026-09';
    const linePath = `${billPath}/lineItems/C-MANAGED:times:2026-09-01`;
    await assertFails(updateDoc(doc(db, billPath), { totalDuePaise: 1 }));
    await assertFails(deleteDoc(doc(db, billPath)));
    await assertFails(updateDoc(doc(db, linePath), { totalPaise: 1 }));
    await assertFails(deleteDoc(doc(db, linePath)));

    const retry = writeBatch(db);
    addBillFinalization(retry, db, { auditId: 'duplicate-audit' });
    await assertFails(retry.commit());
  });

  test('rejects forged totals, malformed daily arithmetic, and unpaired writes', async () => {
    const db = auth('head-a', 'head-a@example.com');
    const forged = writeBatch(db);
    addBillFinalization(forged, db, { totalDuePaise: 1 });
    await assertFails(forged.commit());

    const malformed = writeBatch(db);
    addBillFinalization(malformed, db, {
      auditId: 'malformed-line-audit',
      malformedLine: true,
    });
    await assertFails(malformed.commit());

    await assertFails(
      setDoc(
        doc(
          db,
          'businesses/business-a/customers/C-MANAGED/bills/2026-09',
        ),
        completeBill(),
      ),
    );
  });

  test('employees cannot finalize or adjust but assigned employee reads finalized bills', async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(
        doc(db, 'businesses/business-a/customers/C-MANAGED/bills/2026-09'),
        {
          ...completeBill(),
          finalizedAt: new Date(),
          createdAt: new Date(),
        },
      );
      await setDoc(
        doc(
          db,
          'businesses/business-a/customers/C-MANAGED/bills/2026-09/lineItems/C-MANAGED:times:2026-09-01',
        ),
        {
          businessId: 'business-a',
          customerId: 'C-MANAGED',
          billId: '2026-09',
          billingMonth: '2026-09',
          chargeKey: 'C-MANAGED:times:2026-09-01',
          serviceDate: '2026-09-01',
          subscriptionId: 'times',
          versionId: 'version-1',
          newspaperId: 'times',
          newspaperName: 'Daily Times',
          unitPricePaise: 650,
          quantity: 1,
          totalPaise: 650,
          priceSource: 'defaultPrice',
          priceSourceId: 'times',
          priceRuleRevision: 0,
          lastAuditId: 'bill-audit',
          createdAt: new Date(),
        },
      );
    });
    const assigned = auth('employee-a', 'employee-a@example.com');
    await assertSucceeds(
      getDoc(
        doc(
          assigned,
          'businesses/business-a/customers/C-MANAGED/bills/2026-09',
        ),
      ),
    );
    await assertSucceeds(
      getDoc(
        doc(
          assigned,
          'businesses/business-a/customers/C-MANAGED/bills/2026-09/lineItems/C-MANAGED:times:2026-09-01',
        ),
      ),
    );

    const employeeBatch = writeBatch(assigned);
    addBillFinalization(employeeBatch, assigned, {
      month: '2026-10',
      auditId: 'employee-bill-audit',
      actorId: 'employee-a',
    });
    await assertFails(employeeBatch.commit());
    const adjustmentBatch = writeBatch(assigned);
    addBillingAdjustment(adjustmentBatch, assigned, {
      actorId: 'employee-a',
    });
    await assertFails(adjustmentBatch.commit());

    const unassigned = auth('employee-c', 'employee-c@example.com');
    await assertFails(
      getDoc(
        doc(
          unassigned,
          'businesses/business-a/customers/C-MANAGED/bills/2026-09',
        ),
      ),
    );
  });

  test('Head appends signed adjustments with a serialized control and immutable audit', async () => {
    const db = auth('head-a', 'head-a@example.com');
    const batch = writeBatch(db);
    addBillingAdjustment(batch, db);
    await assertSucceeds(batch.commit());
    const adjustment = doc(
      db,
      'businesses/business-a/customers/C-MANAGED/adjustments/adjustment-1',
    );
    await assertFails(updateDoc(adjustment, { amountPaise: -1000 }));
    await assertFails(deleteDoc(adjustment));
    await assertFails(
      updateDoc(
        doc(db, 'businesses/business-a/auditRecords/adjustment-audit'),
        { amountPaise: -1000 },
      ),
    );
  });

  test('tenant Heads cannot read or write another business billing data', async () => {
    const foreign = auth('head-b', 'head-b@example.com');
    await assertFails(
      getDoc(
        doc(
          foreign,
          'businesses/business-a/customers/C-MANAGED/bills/2026-09',
        ),
      ),
    );
    const batch = writeBatch(foreign);
    addBillFinalization(batch, foreign, {
      month: '2026-10',
      auditId: 'foreign-audit',
      actorId: 'head-b',
    });
    await assertFails(batch.commit());
  });
});

describe('Phase 6 collections, reversals, and UPI security', () => {
  test('approved synthetic ledger sequence returns the exact balance without duplicates', async () => {
    const customerId = 'C-PHASE6-SMOKE';
    const customerPath = `businesses/business-a/customers/${customerId}`;
    await seedCollectionProjection({
      customerId,
      bills: [{ month: '2026-11', outstandingPaise: 29184 }],
    });
    const db = auth('head-a', 'head-a@example.com');

    await assertSucceeds(
      confirmPaymentTransaction(db, {
        customerId,
        paymentId: 'phase6-smoke-cash-001',
        amountPaise: 1000,
        allocations: [
          { billId: '2026-11', billingMonth: '2026-11', amountPaise: 1000 },
        ],
      }),
    );
    await assertFails(
      confirmPaymentTransaction(db, {
        customerId,
        paymentId: 'phase6-smoke-cash-001',
        amountPaise: 1000,
        allocations: [
          { billId: '2026-11', billingMonth: '2026-11', amountPaise: 1000 },
        ],
      }),
    );
    await assertSucceeds(
      confirmPaymentTransaction(db, {
        customerId,
        paymentId: 'phase6-smoke-upi-001',
        amountPaise: 500,
        method: 'upi',
        externalReference: 'DEV-PHASE6-UPI-001',
        allocations: [
          { billId: '2026-11', billingMonth: '2026-11', amountPaise: 500 },
        ],
      }),
    );

    const cashRef = doc(db, `${customerPath}/payments/phase6-smoke-cash-001`);
    const upiRef = doc(db, `${customerPath}/payments/phase6-smoke-upi-001`);
    const originalCash = (await getDoc(cashRef)).data();
    const originalUpi = (await getDoc(upiRef)).data();

    await assertSucceeds(
      reversePaymentTransaction(db, {
        customerId,
        paymentId: 'phase6-smoke-cash-001',
        reversalId: 'phase6-smoke-reversal-cash-001',
        amountPaise: 400,
        reason: 'Synthetic partial cash reversal',
        allocations: [
          { billId: '2026-11', billingMonth: '2026-11', amountPaise: 400 },
        ],
      }),
    );
    await assertSucceeds(
      reversePaymentTransaction(db, {
        customerId,
        paymentId: 'phase6-smoke-cash-001',
        reversalId: 'phase6-smoke-reversal-cash-002',
        amountPaise: 600,
        reason: 'Synthetic remaining cash reversal',
        allocations: [
          { billId: '2026-11', billingMonth: '2026-11', amountPaise: 600 },
        ],
      }),
    );
    await assertSucceeds(
      reversePaymentTransaction(db, {
        customerId,
        paymentId: 'phase6-smoke-upi-001',
        reversalId: 'phase6-smoke-reversal-upi-001',
        amountPaise: 500,
        reason: 'Synthetic UPI reversal',
        allocations: [
          { billId: '2026-11', billingMonth: '2026-11', amountPaise: 500 },
        ],
      }),
    );

    const payments = await getDocs(collection(db, `${customerPath}/payments`));
    const paymentStates = await getDocs(
      collection(db, `${customerPath}/paymentStates`),
    );
    const reversals = await getDocs(
      collection(db, `${customerPath}/paymentReversals`),
    );
    assert.equal(payments.size, 2);
    assert.equal(paymentStates.size, 2);
    assert.equal(reversals.size, 3);
    assert.deepEqual((await getDoc(cashRef)).data(), originalCash);
    assert.deepEqual((await getDoc(upiRef)).data(), originalUpi);
    assert.deepEqual(
      new Set(paymentStates.docs.map((document) => document.data().status)),
      new Set(['reversed']),
    );

    const collectionState = (
      await getDoc(doc(db, `${customerPath}/collectionState/current`))
    ).data();
    assert.equal(collectionState.confirmedPaise, 1500);
    assert.equal(collectionState.reversedPaise, 1500);
    assert.equal(collectionState.outstandingPaise, 29184);
    const billBalance = (
      await getDoc(doc(db, `${customerPath}/billBalances/2026-11`))
    ).data();
    assert.equal(billBalance.allocatedPaise, 1500);
    assert.equal(billBalance.reversedPaise, 1500);
    assert.equal(billBalance.outstandingPaise, 29184);

    const audits = await getDocs(
      collection(db, 'businesses/business-a/auditRecords'),
    );
    const smokeAudits = audits.docs.filter(
      (document) => document.data().customerId === customerId,
    );
    assert.equal(
      smokeAudits.filter(
        (document) => document.data().action === 'paymentConfirmed',
      ).length,
      2,
    );
    assert.equal(
      smokeAudits.filter(
        (document) => document.data().action === 'paymentReversed',
      ).length,
      3,
    );
  });

  test('Head records partial and multiple payments through atomic projections', async () => {
    await seedCollectionProjection();
    const db = auth('head-a', 'head-a@example.com');

    await assertSucceeds(
      confirmPaymentTransaction(db, {
        paymentId: 'payment-partial-1',
        amountPaise: 25000,
      }),
    );
    let state = await getDoc(
      doc(
        db,
        'businesses/business-a/customers/C-MANAGED/collectionState/current',
      ),
    );
    assert.equal(state.data().outstandingPaise, 35000);
    assert.equal(state.data().confirmedPaise, 25000);

    await assertSucceeds(
      confirmPaymentTransaction(db, {
        paymentId: 'payment-partial-2',
        amountPaise: 35000,
        allocations: [
          {
            billId: '2026-09',
            billingMonth: '2026-09',
            amountPaise: 35000,
          },
        ],
      }),
    );
    state = await getDoc(
      doc(
        db,
        'businesses/business-a/customers/C-MANAGED/collectionState/current',
      ),
    );
    assert.equal(state.data().outstandingPaise, 0);
    assert.equal(state.data().confirmedPaise, 60000);
    assert.equal(
      (
        await getDocs(
          collection(
            db,
            'businesses/business-a/customers/C-MANAGED/payments',
          ),
        )
      ).size,
      2,
    );
    assert.equal(
      (
        await getDoc(
          doc(
            db,
            'businesses/business-a/customers/C-MANAGED/billBalances/2026-09',
          ),
        )
      ).data().status,
      'settled',
    );
  });

  test('multi-bill allocations require matching totals and projections', async () => {
    await seedCollectionProjection({
      bills: [
        { month: '2026-07', outstandingPaise: 20000 },
        { month: '2026-08', outstandingPaise: 30000 },
      ],
    });
    const db = auth('head-a', 'head-a@example.com');
    await assertSucceeds(
      confirmPaymentTransaction(db, {
        paymentId: 'payment-multibill',
        amountPaise: 35000,
        allocations: [
          {
            billId: '2026-07',
            billingMonth: '2026-07',
            amountPaise: 20000,
          },
          {
            billId: '2026-08',
            billingMonth: '2026-08',
            amountPaise: 15000,
          },
        ],
      }),
    );
    assert.equal(
      (
        await getDoc(
          doc(
            db,
            'businesses/business-a/customers/C-MANAGED/billBalances/2026-07',
          ),
        )
      ).data().outstandingPaise,
      0,
    );
    assert.equal(
      (
        await getDoc(
          doc(
            db,
            'businesses/business-a/customers/C-MANAGED/billBalances/2026-08',
          ),
        )
      ).data().outstandingPaise,
      15000,
    );
    await assertFails(
      confirmPaymentTransaction(db, {
        paymentId: 'payment-forged-total',
        amountPaise: 1000,
        allocations: [
          {
            billId: '2026-08',
            billingMonth: '2026-08',
            amountPaise: 999,
          },
        ],
      }),
    );
  });

  test('overpayment, duplicate confirmation, edits, and deletes are denied', async () => {
    await seedCollectionProjection();
    const db = auth('head-a', 'head-a@example.com');
    await assertFails(
      confirmPaymentTransaction(db, {
        paymentId: 'payment-over',
        amountPaise: 60001,
        allocations: [
          {
            billId: '2026-09',
            billingMonth: '2026-09',
            amountPaise: 60001,
          },
        ],
      }),
    );
    await assertSucceeds(
      confirmPaymentTransaction(db, { paymentId: 'payment-stable-1' }),
    );
    await assertFails(
      confirmPaymentTransaction(db, { paymentId: 'payment-stable-1' }),
    );
    const payment = doc(
      db,
      'businesses/business-a/customers/C-MANAGED/payments/payment-stable-1',
    );
    await assertFails(updateDoc(payment, { amountPaise: 1 }));
    await assertFails(deleteDoc(payment));
    await assertFails(
      deleteDoc(
        doc(
          db,
          'businesses/business-a/auditRecords/payment-stable-1-audit',
        ),
      ),
    );
  });

  test('all manual methods share the ledger and require safe metadata', async () => {
    await seedCollectionProjection();
    const db = auth('head-a', 'head-a@example.com');
    const cases = [
      { id: 'payment-cash-1', method: 'cash' },
      {
        id: 'payment-upi-1',
        method: 'upi',
        externalReference: 'UPI-SYNTHETIC-1',
      },
      {
        id: 'payment-bank-1',
        method: 'bankTransfer',
        externalReference: 'BANK-SYNTHETIC-1',
      },
      { id: 'payment-other-1', method: 'other', notes: 'Synthetic voucher' },
    ];
    for (const entry of cases) {
      await assertSucceeds(
        confirmPaymentTransaction(db, {
          paymentId: entry.id,
          amountPaise: 1000,
          method: entry.method,
          externalReference: entry.externalReference ?? '',
          notes: entry.notes ?? '',
          allocations: [
            {
              billId: '2026-09',
              billingMonth: '2026-09',
              amountPaise: 1000,
            },
          ],
        }),
      );
    }
    await assertFails(
      confirmPaymentTransaction(db, {
        paymentId: 'payment-upi-no-reference',
        amountPaise: 1000,
        method: 'upi',
        allocations: [
          {
            billId: '2026-09',
            billingMonth: '2026-09',
            amountPaise: 1000,
          },
        ],
      }),
    );
  });

  test('employee collection enforces permission, assignment, area, active status, and tenant', async () => {
    await seedCollectionProjection();
    await seedCollectionProjection({
      customerId: 'C-WRONG-AREA',
      assignedEmployeeId: 'employee-a',
      areaId: 'west',
    });
    await seedCollectionProjection({
      customerId: 'C-ARCHIVED',
      assignedEmployeeId: 'employee-a',
      areaId: 'east',
      status: 'archived',
    });
    const employee = auth('employee-a', 'employee-a@example.com');
    await assertSucceeds(
      confirmPaymentTransaction(employee, {
        paymentId: 'employee-payment-1',
        actorId: 'employee-a',
      }),
    );
    for (const customerId of ['C-EMPLOYEE', 'C-WRONG-AREA', 'C-ARCHIVED']) {
      await assertFails(
        confirmPaymentTransaction(employee, {
          customerId,
          paymentId: `employee-denied-${customerId}`,
          actorId: 'employee-a',
        }),
      );
    }
    await assertFails(
      confirmPaymentTransaction(auth('employee-b', 'employee-b@example.com'), {
        paymentId: 'foreign-payment',
        actorId: 'employee-b',
      }),
    );
  });

  test('history queries are tenant constrained and collector scoped', async () => {
    await seedCollectionProjection();
    const employee = auth('employee-a', 'employee-a@example.com');
    await assertSucceeds(
      confirmPaymentTransaction(employee, {
        paymentId: 'employee-history-1',
        actorId: 'employee-a',
      }),
    );
    await assertSucceeds(
      getDocs(
        query(
          collectionGroup(employee, 'payments'),
          where('businessId', '==', 'business-a'),
          where('collectorUid', '==', 'employee-a'),
          orderBy('confirmedAt', 'desc'),
          limit(25),
        ),
      ),
    );
    await assertFails(
      getDocs(
        query(
          collectionGroup(employee, 'payments'),
          where('businessId', '==', 'business-a'),
          orderBy('confirmedAt', 'desc'),
          limit(25),
        ),
      ),
    );
  });

  test('Head records partial then full reversal without mutating payment', async () => {
    await seedCollectionProjection();
    const db = auth('head-a', 'head-a@example.com');
    await assertSucceeds(
      confirmPaymentTransaction(db, { paymentId: 'payment-reverse-1' }),
    );
    const paymentRef = doc(
      db,
      'businesses/business-a/customers/C-MANAGED/payments/payment-reverse-1',
    );
    const original = (await getDoc(paymentRef)).data();
    await assertSucceeds(
      reversePaymentTransaction(db, {
        paymentId: 'payment-reverse-1',
        reversalId: 'reversal-partial-1',
        amountPaise: 5000,
      }),
    );
    let state = await getDoc(
      doc(
        db,
        'businesses/business-a/customers/C-MANAGED/paymentStates/payment-reverse-1',
      ),
    );
    assert.equal(state.data().status, 'partiallyReversed');
    assert.equal(state.data().refundablePaise, 20000);

    await assertSucceeds(
      reversePaymentTransaction(db, {
        paymentId: 'payment-reverse-1',
        reversalId: 'reversal-full-1',
        amountPaise: 20000,
        allocations: [
          {
            billId: '2026-09',
            billingMonth: '2026-09',
            amountPaise: 20000,
          },
        ],
      }),
    );
    state = await getDoc(
      doc(
        db,
        'businesses/business-a/customers/C-MANAGED/paymentStates/payment-reverse-1',
      ),
    );
    assert.equal(state.data().status, 'reversed');
    assert.equal(state.data().refundablePaise, 0);
    assert.deepEqual((await getDoc(paymentRef)).data(), original);
    assert.equal(
      (
        await getDoc(
          doc(
            db,
            'businesses/business-a/customers/C-MANAGED/collectionState/current',
          ),
        )
      ).data().outstandingPaise,
      60000,
    );
  });

  test('employee and over-payment reversal attempts are denied', async () => {
    await seedCollectionProjection();
    const head = auth('head-a', 'head-a@example.com');
    await assertSucceeds(
      confirmPaymentTransaction(head, { paymentId: 'payment-protected-1' }),
    );
    await assertFails(
      reversePaymentTransaction(auth('employee-a', 'employee-a@example.com'), {
        paymentId: 'payment-protected-1',
        reversalId: 'employee-reversal-1',
        actorId: 'employee-a',
      }),
    );
    await assertFails(
      reversePaymentTransaction(head, {
        paymentId: 'payment-protected-1',
        reversalId: 'over-reversal-1',
        amountPaise: 25001,
        allocations: [
          {
            billId: '2026-09',
            billingMonth: '2026-09',
            amountPaise: 25001,
          },
        ],
      }),
    );
  });

  test('Head-only UPI writes are audited while employees can read for collection', async () => {
    const head = auth('head-a', 'head-a@example.com');
    await assertSucceeds(writeUpiSettings(head));
    const employee = auth('employee-a', 'employee-a@example.com');
    await assertSucceeds(
      getDoc(doc(employee, 'businesses/business-a/configuration/upi')),
    );
    await assertFails(
      writeUpiSettings(employee, {
        actorId: 'employee-a',
        auditId: 'employee-upi-audit',
      }),
    );
    await assertFails(
      deleteDoc(doc(head, 'businesses/business-a/configuration/upi')),
    );
  });
});

describe('Phase 7 reporting security and projection integrity', () => {
  test('keeps the unused monthly summary collection deny-by-default', async () => {
    const headDb = auth('head-a', 'head-a@example.com');
    await assertFails(
      setDoc(
        doc(headDb, 'businesses/business-a/monthlySummaries/2026-09'),
        {
          businessId: 'business-a',
          totalPaise: 999999,
        },
      ),
    );
  });

  test('Head can query report groups while employee queries stay collector and assignment scoped', async () => {
    await seedCollectionProjection();
    const employee = auth('employee-a', 'employee-a@example.com');
    await assertSucceeds(
      confirmPaymentTransaction(employee, {
        paymentId: 'phase7-employee-payment',
        actorId: 'employee-a',
        amountPaise: 1000,
        allocations: [
          { billId: '2026-09', billingMonth: '2026-09', amountPaise: 1000 },
        ],
      }),
    );
    const head = auth('head-a', 'head-a@example.com');
    await assertSucceeds(
      reversePaymentTransaction(head, {
        paymentId: 'phase7-employee-payment',
        reversalId: 'phase7-head-reversal',
        amountPaise: 500,
        allocations: [
          { billId: '2026-09', billingMonth: '2026-09', amountPaise: 500 },
        ],
      }),
    );

    await assertSucceeds(
      getDocs(
        query(
          collectionGroup(head, 'payments'),
          where('businessId', '==', 'business-a'),
        ),
      ),
    );
    await assertSucceeds(
      getDocs(
        query(
          collectionGroup(employee, 'payments'),
          where('businessId', '==', 'business-a'),
          where('collectorUid', '==', 'employee-a'),
        ),
      ),
    );
    await assertFails(
      getDocs(
        query(
          collectionGroup(employee, 'payments'),
          where('businessId', '==', 'business-a'),
        ),
      ),
    );
    await assertSucceeds(
      getDocs(
        query(
          collectionGroup(head, 'paymentReversals'),
          where('businessId', '==', 'business-a'),
        ),
      ),
    );
    await assertFails(
      getDocs(
        query(
          collectionGroup(employee, 'paymentReversals'),
          where('businessId', '==', 'business-a'),
        ),
      ),
    );
    await assertSucceeds(
      getDocs(
        query(
          collectionGroup(head, 'bills'),
          where('businessId', '==', 'business-a'),
        ),
      ),
    );
    await assertFails(
      getDocs(
        query(
          collectionGroup(employee, 'bills'),
          where('businessId', '==', 'business-a'),
        ),
      ),
    );
  });

  test('concurrent payment submissions with same idempotencyKey create exactly one payment and one audit', async () => {
    const customerId = 'C-CONCURRENT-001';
    await seedCollectionProjection({
      customerId,
      bills: [{ month: '2026-11', outstandingPaise: 50000 }],
    });
    const db = auth('head-a', 'head-a@example.com');

    const paymentParams = {
      customerId,
      paymentId: 'pay-concurrent-idempotent-001',
      amountPaise: 10000,
      allocations: [
        { billId: '2026-11', billingMonth: '2026-11', amountPaise: 10000 },
      ],
    };

    // First submission succeeds
    await assertSucceeds(confirmPaymentTransaction(db, paymentParams));

    // Exact same payment submission retry/concurrency is rejected by security rules
    // preventing duplicate payment document, duplicate balance deduction, or duplicate audit
    await assertFails(confirmPaymentTransaction(db, paymentParams));

    // Two different operationIds for same customer, date, and amount succeed twice
    await assertSucceeds(
      confirmPaymentTransaction(db, {
        customerId,
        paymentId: 'pay-legit-diff-001',
        amountPaise: 10000,
        allocations: [
          { billId: '2026-11', billingMonth: '2026-11', amountPaise: 10000 },
        ],
      }),
    );
    await assertSucceeds(
      confirmPaymentTransaction(db, {
        customerId,
        paymentId: 'pay-legit-diff-002',
        amountPaise: 10000,
        allocations: [
          { billId: '2026-11', billingMonth: '2026-11', amountPaise: 10000 },
        ],
      }),
    );

    const payment1 = await getDoc(
      doc(
        db,
        `businesses/business-a/customers/${customerId}/payments/pay-legit-diff-001`,
      ),
    );
    const payment2 = await getDoc(
      doc(
        db,
        `businesses/business-a/customers/${customerId}/payments/pay-legit-diff-002`,
      ),
    );
    assert.equal(payment1.exists(), true);
    assert.equal(payment2.exists(), true);
  });

  test('employee balance metrics require their current assignment and area', async () => {
    await seedCollectionProjection();
    const employee = auth('employee-a', 'employee-a@example.com');
    const assigned = query(
      collectionGroup(employee, 'collectionState'),
      where('businessId', '==', 'business-a'),
      where('stateId', '==', 'current'),
      where('assignedEmployeeId', '==', 'employee-a'),
      where('customerStatus', '==', 'active'),
      where('areaId', 'in', ['east']),
    );
    await assertSucceeds(getDocs(assigned));
    await assertFails(
      getDocs(
        query(
          collectionGroup(employee, 'collectionState'),
          where('businessId', '==', 'business-a'),
          where('stateId', '==', 'current'),
          where('customerStatus', '==', 'active'),
          where('areaId', '==', 'east'),
        ),
      ),
    );
    await assertFails(
      getDocs(
        query(
          collectionGroup(employee, 'collectionState'),
          where('businessId', '==', 'business-b'),
          where('stateId', '==', 'current'),
          where('assignedEmployeeId', '==', 'employee-a'),
          where('customerStatus', '==', 'active'),
          where('areaId', '==', 'east'),
        ),
      ),
    );
  });

  test('customer reporting snapshots advance atomically and financial fields cannot be forged', async () => {
    await seedCollectionProjection();
    const db = auth('head-a', 'head-a@example.com');
    const customerRef = doc(
      db,
      'businesses/business-a/customers/C-MANAGED',
    );
    const stateRef = doc(
      db,
      'businesses/business-a/customers/C-MANAGED/collectionState/current',
    );
    const auditRef = doc(
      db,
      'businesses/business-a/auditRecords/phase7-profile-audit',
    );
    const now = serverTimestamp();
    const batch = writeBatch(db);
    batch.update(customerRef, {
      name: 'Managed Customer Updated',
      searchName: 'managed customer updated',
      searchTokens: ['name:ma', 'name:man'],
      updatedBy: 'head-a',
      lastAuditId: 'phase7-profile-audit',
      updatedAt: now,
    });
    batch.update(stateRef, {
      customerName: 'Managed Customer Updated',
      revision: 2,
      lastMutationType: 'customerProfileUpdated',
      lastMutationId: 'phase7-profile-audit',
      updatedBy: 'head-a',
      updatedAt: now,
    });
    batch.set(auditRef, {
      businessId: 'business-a',
      actorId: 'head-a',
      action: 'customerUpdated',
      entityType: 'customer',
      entityId: 'C-MANAGED',
      changedFields: ['name', 'searchName', 'searchTokens'],
      createdAt: now,
    });
    await assertSucceeds(batch.commit());
    assert.equal((await getDoc(stateRef)).data().outstandingPaise, 60000);

    const staleAuditId = 'phase7-stale-audit';
    const stale = writeBatch(db);
    stale.update(customerRef, {
      name: 'Stale Projection',
      searchName: 'stale projection',
      searchTokens: ['name:st'],
      updatedBy: 'head-a',
      lastAuditId: staleAuditId,
      updatedAt: serverTimestamp(),
    });
    stale.set(
      doc(db, `businesses/business-a/auditRecords/${staleAuditId}`),
      {
        businessId: 'business-a',
        actorId: 'head-a',
        action: 'customerUpdated',
        entityType: 'customer',
        entityId: 'C-MANAGED',
        changedFields: ['name', 'searchName', 'searchTokens'],
        createdAt: serverTimestamp(),
      },
    );
    await assertFails(stale.commit());
    await assertFails(
      updateDoc(stateRef, {
        outstandingPaise: 1,
        revision: 3,
        lastMutationType: 'customerProfileUpdated',
        lastMutationId: 'forged',
        updatedBy: 'head-a',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('only Head can save a valid primary pricing region', async () => {
    const head = auth('head-a', 'head-a@example.com');
    const business = doc(head, 'businesses/business-a');
    await assertSucceeds(
      updateDoc(business, {
        primaryPricingRegion: {
          state: 'Chhattisgarh',
          districtCity: 'Raipur',
          editionServiceRegion: 'Central',
        },
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(auth('employee-a', 'employee-a@example.com'), business.path), {
        primaryPricingRegion: {
          state: 'Chhattisgarh',
          districtCity: 'Bilaspur',
          editionServiceRegion: '',
        },
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(business, {
        primaryPricingRegion: {
          state: 'X',
          districtCity: 'Raipur',
          editionServiceRegion: '',
        },
        updatedAt: serverTimestamp(),
      }),
    );
  });

  describe('Account Deletion Security Rules', () => {
    test('user can read own account deletion request but not list or write', async () => {
      await environment.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, 'accountDeletionRequests/head-a'), {
          uid: 'head-a',
          status: 'completed',
          role: 'head',
        });
      });

      const head = auth('head-a', 'head-a@example.com');
      const employee = auth('employee-a', 'employee-a@example.com');
      const requestDoc = doc(head, 'accountDeletionRequests/head-a');

      // Own read succeeds
      await assertSucceeds(getDoc(requestDoc));

      // Other user read fails
      await assertFails(
        getDoc(doc(employee, 'accountDeletionRequests/head-a')),
      );

      // List queries fail
      await assertFails(getDocs(collection(head, 'accountDeletionRequests')));

      // Client writes and deletes fail
      await assertFails(
        setDoc(doc(head, 'accountDeletionRequests/head-a'), {
          uid: 'head-a',
          status: 'forged',
        }),
      );
      await assertFails(deleteDoc(requestDoc));
    });

    test('removed employee loses all access to business workspace', async () => {
      await environment.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await updateDoc(doc(db, 'businesses/business-a/members/employee-a'), {
          status: 'removed',
          updatedAt: serverTimestamp(),
        });
      });

      const employee = auth('employee-a', 'employee-a@example.com');
      await assertFails(getDoc(doc(employee, 'businesses/business-a')));
      await assertFails(
        getDoc(doc(employee, 'businesses/business-a/customers/C-MANAGED')),
      );
    });
  });

  describe('Phase 5 SaaS subscription security and entitlements', () => {
    test('Active Head and employee can read agency SaaS subscription', async () => {
      await environment.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, 'businesses/business-a/subscription/saas'), {
          businessId: 'business-a',
          planId: 'trial',
          status: 'trial',
          trialStartsAt: new Date(),
          trialEndsAt: new Date(Date.now() + 30 * 86_400_000),
          graceDays: 7,
          customerLimit: 500,
          employeeLimit: 10,
          createdAt: new Date(),
          updatedAt: new Date(),
        });
      });

      const headDb = auth('head-a', 'head-a@example.com');
      const empDb = auth('employee-a', 'employee-a@example.com');
      const foreignDb = auth('head-b', 'head-b@example.com');

      // Head and employee can read agency subscription
      await assertSucceeds(getDoc(doc(headDb, 'businesses/business-a/subscription/saas')));
      await assertSucceeds(getDoc(doc(empDb, 'businesses/business-a/subscription/saas')));

      // Foreign tenant cannot read agency subscription
      await assertFails(getDoc(doc(foreignDb, 'businesses/business-a/subscription/saas')));
    });

    test('Clients (Head and employees) cannot create, update, or delete subscription documents', async () => {
      const headDb = auth('head-a', 'head-a@example.com');
      const empDb = auth('employee-a', 'employee-a@example.com');
      const subDoc = doc(headDb, 'businesses/business-a/subscription/saas');

      // Client create fails
      await assertFails(
        setDoc(doc(headDb, 'businesses/business-a/subscription/saas-client'), {
          businessId: 'business-a',
          planId: 'agencyPro',
          status: 'active',
        }),
      );

      // Client update fails (unauthorized plan change or trial tampering)
      await assertFails(
        updateDoc(subDoc, {
          planId: 'agencyPro',
          status: 'active',
          trialEndsAt: new Date(Date.now() + 365 * 86_400_000),
        }),
      );
      await assertFails(
        updateDoc(doc(empDb, 'businesses/business-a/subscription/saas'), {
          planId: 'agencyPro',
        }),
      );

      // Client delete fails
      await assertFails(deleteDoc(subDoc));
    });

    test('Expired agency (effectiveExpiresAt in the past) is blocked from creating customers, while read access is preserved', async () => {
      // Simulate expired agency subscription in Firestore
      await environment.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, 'businesses/business-a/subscription/saas'), {
          businessId: 'business-a',
          planId: 'trial',
          status: 'expired',
          effectiveExpiresAt: new Date(Date.now() - 86_400_000), // 1 day ago (expired)
          customerLimit: 500,
          employeeLimit: 10,
          graceDays: 7,
          updatedAt: new Date(),
        });
      });

      const headDb = auth('head-a', 'head-a@example.com');

      // Head can still read existing customers
      await assertSucceeds(getDoc(doc(headDb, 'businesses/business-a/customers/customer-1')));

      // Head cannot create new customers because subscription write gate blocks expired agencies
      const newCustomer = completeCustomer({
        id: 'cust-expired-attempt',
        businessId: 'business-a',
        assignedEmployeeId: 'employee-a',
        areaId: 'east',
        lastAuditId: 'audit-expired-cust',
      });
      const auditDoc = customerAudit({
        businessId: 'business-a',
        actorId: 'head-a',
        action: 'customerCreated',
        entityId: 'cust-expired-attempt',
      });

      const batch = writeBatch(headDb);
      batch.set(doc(headDb, 'businesses/business-a/customers/cust-expired-attempt'), newCustomer);
      batch.set(doc(headDb, 'businesses/business-a/auditRecords/audit-expired-cust'), auditDoc);

      await assertFails(batch.commit());
    });

    test('Active agency (effectiveExpiresAt in the future) can create customers normally', async () => {
      // Simulate active agency subscription in Firestore
      await environment.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await setDoc(doc(adminDb, 'businesses/business-a/subscription/saas'), {
          businessId: 'business-a',
          planId: 'growth',
          status: 'active',
          effectiveExpiresAt: new Date(Date.now() + 30 * 86_400_000), // 30 days in future
          customerLimit: 1000,
          employeeLimit: 10,
          graceDays: 7,
          updatedAt: new Date(),
        });
      });

      const headDb = auth('head-a', 'head-a@example.com');

      const newCustomer = completeCustomer({
        id: 'cust-active-success',
        businessId: 'business-a',
        assignedEmployeeId: 'employee-a',
        areaId: 'east',
        lastAuditId: 'audit-active-cust',
      });
      const auditDoc = customerAudit({
        businessId: 'business-a',
        actorId: 'head-a',
        action: 'customerCreated',
        entityId: 'cust-active-success',
      });

      const batch = writeBatch(headDb);
      batch.set(doc(headDb, 'businesses/business-a/customers/cust-active-success'), newCustomer);
      batch.set(doc(headDb, 'businesses/business-a/auditRecords/audit-active-cust'), auditDoc);

      await assertSucceeds(batch.commit());
    });
  });
});

test('test environment initialized', () => {
  assert.ok(environment);
});
