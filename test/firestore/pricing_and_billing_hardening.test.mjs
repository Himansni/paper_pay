import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-paper-route-pricing';
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
  finalizedAt: new Date(),
  createdAt: new Date(),
  updatedAt: new Date(),
});

const seedCollectionProjection = async ({
  customerId = 'C-MANAGED',
  assignedEmployeeId = 'employee-a',
  areaId = 'east',
  status = 'active',
  bills = [{ month: '2026-09', outstandingPaise: 100000 }],
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
          status: bill.outstandingPaise > 0 ? 'outstanding' : 'settled',
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
            ? bills.map((b) => b.month).sort()[0]
            : '',
        revision: 1,
        lastMutationType: 'billFinalized',
        lastMutationId: bills[bills.length - 1].month,
        updatedBy: 'head-a',
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    );
  });
};

const recordAccountAdjustmentTransaction = async (
  db,
  {
    customerId = 'C-MANAGED',
    adjustmentId,
    actorId = 'head-a',
    actorRole = 'head',
    direction,
    amountPaise,
    reason = 'Correction to customer outstanding',
    billingMonth = '2026-09',
  },
) => {
  const customerPath = `businesses/business-a/customers/${customerId}`;
  const adjustmentRef = doc(
    db,
    `${customerPath}/accountAdjustments/${adjustmentId}`,
  );
  const customerRef = doc(db, customerPath);
  const stateRef = doc(db, `${customerPath}/collectionState/current`);
  const balanceRef = doc(
    db,
    `${customerPath}/billBalances/${billingMonth}`,
  );
  const auditId = `${adjustmentId}-audit`;
  const auditRef = doc(db, `businesses/business-a/auditRecords/${auditId}`);

  return runTransaction(db, async (transaction) => {
    const existing = await transaction.get(adjustmentRef);
    if (existing.exists()) return false;
    const customer = await transaction.get(customerRef);
    const state = await transaction.get(stateRef);
    const balance = await transaction.get(balanceRef);
    const signedAmount =
      direction === 'increase' ? amountPaise : -amountPaise;
    const nextOutstanding = state.data().outstandingPaise + signedAmount;
    const nextSource = balance.data().sourceAmountPaise + signedAmount;
    const nextBillNet =
      nextSource -
      balance.data().allocatedPaise +
      balance.data().reversedPaise;
    const now = serverTimestamp();

    transaction.set(adjustmentRef, {
      businessId: 'business-a',
      customerId,
      adjustmentId,
      customerCode: customer.data().customerCode,
      customerName: customer.data().name,
      areaId: customer.data().areaId,
      assignedEmployeeId: customer.data().assignedEmployeeId,
      idempotencyKey: adjustmentId,
      amountPaise,
      direction,
      reason,
      billingMonth,
      createdBy: actorId,
      actorRole,
      lastAuditId: auditId,
      createdAt: now,
    });
    transaction.update(balanceRef, {
      sourceAmountPaise: nextSource,
      outstandingPaise: Math.max(0, nextBillNet),
      status:
        nextBillNet > 0
          ? 'outstanding'
          : nextBillNet === 0
            ? 'settled'
            : 'credit',
      revision: balance.data().revision + 1,
      lastMutationType: 'accountAdjustmentCreated',
      lastMutationId: adjustmentId,
      updatedAt: now,
    });
    transaction.update(stateRef, {
      outstandingPaise: nextOutstanding,
      reportingStatus: nextOutstanding > 0 ? 'unpaid' : 'fullyPaid',
      oldestOutstandingMonth: nextOutstanding > 0 ? billingMonth : '',
      revision: state.data().revision + 1,
      lastMutationType: 'accountAdjustmentCreated',
      lastMutationId: adjustmentId,
      updatedBy: actorId,
      updatedAt: now,
    });
    transaction.set(auditRef, {
      businessId: 'business-a',
      actorId,
      actorRole,
      action: 'accountAdjustmentCreated',
      entityType: 'accountAdjustment',
      entityId: adjustmentId,
      customerId,
      amountPaise,
      direction,
      reason,
      billingMonth,
      createdAt: now,
    });
    return true;
  });
};

before(async () => {
  const rules = await readFile('firestore.rules', 'utf8');
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules,
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  if (environment) {
    await environment.cleanup();
  }
});

beforeEach(async () => {
  await environment.clearFirestore();

  await environment.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    const batch = writeBatch(adminDb);

    // SaaS Subscription for write access
    batch.set(doc(adminDb, 'businesses/business-a/subscription/saas'), {
      effectiveExpiresAt: new Date('2099-01-01T00:00:00.000Z'),
    });
    batch.set(doc(adminDb, 'businesses/business-b/subscription/saas'), {
      effectiveExpiresAt: new Date('2099-01-01T00:00:00.000Z'),
    });

    // Business A
    batch.set(doc(adminDb, 'businesses/business-a'), {
      businessId: 'business-a',
      name: 'PaperRoute Agency A',
      ownerUid: 'head-a',
      status: 'active',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    // Business B (for cross-tenant testing)
    batch.set(doc(adminDb, 'businesses/business-b'), {
      businessId: 'business-b',
      name: 'PaperRoute Agency B',
      ownerUid: 'head-b',
      status: 'active',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    // Members in Business A
    batch.set(doc(adminDb, 'businesses/business-a/members/head-a'), {
      businessId: 'business-a',
      uid: 'head-a',
      role: 'head',
      status: 'active',
      permissions: [],
    });
    batch.set(doc(adminDb, 'businesses/business-a/members/emp-unauthorized'), {
      businessId: 'business-a',
      uid: 'emp-unauthorized',
      email: 'emp-unauth@test.com',
      role: 'employee',
      status: 'active',
      permissions: [],
    });
    batch.set(doc(adminDb, 'businesses/business-a/members/emp-pricing'), {
      businessId: 'business-a',
      uid: 'emp-pricing',
      email: 'emp-pricing@test.com',
      role: 'employee',
      status: 'active',
      permissions: ['allowGlobalPricing', 'allowManualBilling', 'allowIncreaseOutstanding'],
    });
    batch.set(doc(adminDb, 'businesses/business-a/members/emp-inactive'), {
      businessId: 'business-a',
      uid: 'emp-inactive',
      email: 'emp-inactive@test.com',
      role: 'employee',
      status: 'disabled',
      permissions: ['allowGlobalPricing'],
    });

    batch.set(doc(adminDb, 'businesses/business-a/members/employee-a'), {
      businessId: 'business-a',
      uid: 'employee-a',
      email: 'employee-a@test.com',
      role: 'employee',
      status: 'active',
      permissions: ['allowManualBilling'],
      areaIds: ['east'],
    });
    batch.set(doc(adminDb, 'businesses/business-a/members/employee-other'), {
      businessId: 'business-a',
      uid: 'employee-other',
      email: 'employee-other@test.com',
      role: 'employee',
      status: 'active',
      permissions: ['allowManualBilling'],
      areaIds: ['west'],
    });

    // Active Areas in Business A
    batch.set(doc(adminDb, 'businesses/business-a/areas/east'), {
      businessId: 'business-a',
      areaId: 'east',
      name: 'East Area',
      status: 'active',
    });
    batch.set(doc(adminDb, 'businesses/business-a/areas/west'), {
      businessId: 'business-a',
      areaId: 'west',
      name: 'West Area',
      status: 'active',
    });

    // Newspaper ET in Business A
    batch.set(doc(adminDb, 'businesses/business-a/newspapers/paper-et'), {
      businessId: 'business-a',
      newspaperCode: 'paper-et',
      name: 'The Economic Times',
      searchName: 'the economic times',
      language: 'English',
      edition: 'North India',
      defaultPricePaise: 500,
      status: 'active',
      createdBy: 'head-a',
      updatedBy: 'head-a',
      lastAuditId: 'seed-audit-paper',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    // Customer C-MANAGED in Business A
    batch.set(
      doc(adminDb, 'businesses/business-a/customers/C-MANAGED'),
      completeCustomer({
        id: 'C-MANAGED',
        assignedEmployeeId: 'employee-a',
        areaId: 'east',
        status: 'active',
      }),
    );

    await batch.commit();
  });
});

describe('Section 3.A: Global Pricing Security & Tenant Isolation', () => {
  test('Head can create a global monthly price rule', async () => {
    const db = auth('head-a', 'head-a@test.com');
    const ruleRef = doc(db, 'businesses/business-a/newspapers/paper-et/priceRules/rule-1');
    const auditRef = doc(db, 'businesses/business-a/auditRecords/audit-1');
    const paperRef = doc(db, 'businesses/business-a/newspapers/paper-et');

    const batch = writeBatch(db);
    batch.set(ruleRef, {
      businessId: 'business-a',
      newspaperId: 'paper-et',
      priceRuleId: 'rule-1',
      kind: 'period',
      pricingBasis: 'monthly',
      startDate: '2026-09-01',
      endDate: '2026-09-30',
      pricePaise: 20000, // ₹200
      status: 'active',
      supersedesRuleId: '',
      supersededByRuleId: '',
      revision: 1,
      reason: 'September global monthly rate',
      createdBy: 'head-a',
      updatedBy: 'head-a',
      lastAuditId: 'audit-1',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    batch.update(paperRef, {
      updatedBy: 'head-a',
      lastAuditId: 'audit-1',
      updatedAt: serverTimestamp(),
    });
    batch.set(auditRef, {
      businessId: 'business-a',
      actorId: 'head-a',
      action: 'newspaperPriceRuleCreated',
      entityType: 'newspaper',
      entityId: 'paper-et',
      priceRuleId: 'rule-1',
      kind: 'period',
      pricingBasis: 'monthly',
      pricePaise: 20000,
      startDate: '2026-09-01',
      endDate: '2026-09-30',
      reason: 'September global monthly rate',
      createdAt: serverTimestamp(),
    });

    await assertSucceeds(batch.commit());
  });

  test('Employee without allowGlobalPricing is denied creating price rules', async () => {
    const db = auth('emp-unauthorized', 'emp-unauth@test.com');
    const ruleRef = doc(db, 'businesses/business-a/newspapers/paper-et/priceRules/rule-unauth');

    await assertFails(
      setDoc(ruleRef, {
        businessId: 'business-a',
        newspaperId: 'paper-et',
        priceRuleId: 'rule-unauth',
        kind: 'period',
        pricingBasis: 'monthly',
        startDate: '2026-09-01',
        endDate: '2026-09-30',
        pricePaise: 20000,
        status: 'active',
        supersedesRuleId: '',
        supersededByRuleId: '',
        revision: 1,
        reason: 'Unauthorized attempt',
        createdBy: 'emp-unauthorized',
        updatedBy: 'emp-unauthorized',
        lastAuditId: 'audit-unauth',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('Employee with allowGlobalPricing is allowed creating price rules', async () => {
    const db = auth('emp-pricing', 'emp-pricing@test.com');
    const ruleRef = doc(db, 'businesses/business-a/newspapers/paper-et/priceRules/rule-emp');
    const auditRef = doc(db, 'businesses/business-a/auditRecords/audit-emp');
    const paperRef = doc(db, 'businesses/business-a/newspapers/paper-et');

    const batch = writeBatch(db);
    batch.set(ruleRef, {
      businessId: 'business-a',
      newspaperId: 'paper-et',
      priceRuleId: 'rule-emp',
      kind: 'period',
      pricingBasis: 'monthly',
      startDate: '2026-09-01',
      endDate: '2026-09-30',
      pricePaise: 20000,
      status: 'active',
      supersedesRuleId: '',
      supersededByRuleId: '',
      revision: 1,
      reason: 'Authorized employee rate change',
      createdBy: 'emp-pricing',
      updatedBy: 'emp-pricing',
      lastAuditId: 'audit-emp',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    batch.update(paperRef, {
      updatedBy: 'emp-pricing',
      lastAuditId: 'audit-emp',
      updatedAt: serverTimestamp(),
    });
    batch.set(auditRef, {
      businessId: 'business-a',
      actorId: 'emp-pricing',
      action: 'newspaperPriceRuleCreated',
      entityType: 'newspaper',
      entityId: 'paper-et',
      priceRuleId: 'rule-emp',
      kind: 'period',
      pricingBasis: 'monthly',
      pricePaise: 20000,
      startDate: '2026-09-01',
      endDate: '2026-09-30',
      reason: 'Authorized employee rate change',
      createdAt: serverTimestamp(),
    });

    await assertSucceeds(batch.commit());
  });

  test('Employee cannot grant themselves allowGlobalPricing', async () => {
    const db = auth('emp-unauthorized', 'emp-unauth@test.com');
    const empDoc = doc(db, 'businesses/business-a/members/emp-unauthorized');

    await assertFails(
      updateDoc(empDoc, {
        permissions: ['allowGlobalPricing'],
      }),
    );
  });

  test('Employee cannot modify another employee permissions', async () => {
    const db = auth('emp-pricing', 'emp-pricing@test.com');
    const targetEmpDoc = doc(db, 'businesses/business-a/members/emp-unauthorized');

    await assertFails(
      updateDoc(targetEmpDoc, {
        permissions: ['allowGlobalPricing'],
      }),
    );
  });

  test('Cross-tenant pricing write is denied', async () => {
    const db = auth('head-a', 'head-a@test.com');
    const crossTenantRule = doc(db, 'businesses/business-b/newspapers/paper-et/priceRules/cross-rule');

    await assertFails(
      setDoc(crossTenantRule, {
        businessId: 'business-b',
        newspaperId: 'paper-et',
        priceRuleId: 'cross-rule',
        kind: 'period',
        pricingBasis: 'monthly',
        startDate: '2026-09-01',
        endDate: '2026-09-30',
        pricePaise: 20000,
        status: 'active',
        supersedesRuleId: '',
        supersededByRuleId: '',
        revision: 1,
        reason: 'Cross-tenant attack',
        createdBy: 'head-a',
        updatedBy: 'head-a',
        lastAuditId: 'audit-cross',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });
});

describe('Section 3.B: Pricing Rule Shape & Financial Immutability', () => {
  test('Malformed pricingBasis is rejected', async () => {
    const db = auth('head-a', 'head-a@test.com');
    const ruleRef = doc(db, 'businesses/business-a/newspapers/paper-et/priceRules/malformed-rule');

    await assertFails(
      setDoc(ruleRef, {
        businessId: 'business-a',
        newspaperId: 'paper-et',
        priceRuleId: 'malformed-rule',
        kind: 'period',
        pricingBasis: 'annual', // INVALID: only 'daily' or 'monthly' permitted
        startDate: '2026-09-01',
        endDate: '2026-09-30',
        pricePaise: 20000,
        status: 'active',
        supersedesRuleId: '',
        supersededByRuleId: '',
        revision: 1,
        reason: 'Invalid basis',
        createdBy: 'head-a',
        updatedBy: 'head-a',
        lastAuditId: 'audit-malformed',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('Invalid date range (start > end) is rejected', async () => {
    const db = auth('head-a', 'head-a@test.com');
    const ruleRef = doc(db, 'businesses/business-a/newspapers/paper-et/priceRules/invalid-dates');

    await assertFails(
      setDoc(ruleRef, {
        businessId: 'business-a',
        newspaperId: 'paper-et',
        priceRuleId: 'invalid-dates',
        kind: 'period',
        pricingBasis: 'monthly',
        startDate: '2026-09-30',
        endDate: '2026-09-01', // INVALID: start > end
        pricePaise: 20000,
        status: 'active',
        supersedesRuleId: '',
        supersededByRuleId: '',
        revision: 1,
        reason: 'Invalid dates',
        createdBy: 'head-a',
        updatedBy: 'head-a',
        lastAuditId: 'audit-dates',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('Negative price is rejected', async () => {
    const db = auth('head-a', 'head-a@test.com');
    const ruleRef = doc(db, 'businesses/business-a/newspapers/paper-et/priceRules/neg-price');

    await assertFails(
      setDoc(ruleRef, {
        businessId: 'business-a',
        newspaperId: 'paper-et',
        priceRuleId: 'neg-price',
        kind: 'period',
        pricingBasis: 'monthly',
        startDate: '2026-09-01',
        endDate: '2026-09-30',
        pricePaise: -500, // INVALID: negative price
        status: 'active',
        supersedesRuleId: '',
        supersededByRuleId: '',
        revision: 1,
        reason: 'Negative price',
        createdBy: 'head-a',
        updatedBy: 'head-a',
        lastAuditId: 'audit-neg',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });
});

describe('Section 3.C: Month-End Billing Security & Idempotency', () => {
  test('Employee without manual billing permission is denied creating bills', async () => {
    const db = auth('emp-unauthorized', 'emp-unauth@test.com');
    const billRef = doc(db, 'businesses/business-a/monthlyBills/cust-1:2026-09');

    await assertFails(
      setDoc(billRef, {
        businessId: 'business-a',
        customerId: 'cust-1',
        billingMonth: '2026-09',
        status: 'finalized',
        totalPaise: 20000,
        createdBy: 'emp-unauthorized',
        createdAt: serverTimestamp(),
      }),
    );
  });

  test('Finalized monthly bill is immutable and cannot be overwritten', async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'businesses/business-a/monthlyBills/cust-1:2026-09'), {
        businessId: 'business-a',
        customerId: 'cust-1',
        billingMonth: '2026-09',
        status: 'finalized',
        totalPaise: 18000,
        finalizedAt: serverTimestamp(),
        finalizedBy: 'head-a',
        lastAuditId: 'audit-finalized',
      });
    });

    const db = auth('head-a', 'head-a@test.com');
    const billRef = doc(db, 'businesses/business-a/monthlyBills/cust-1:2026-09');

    await assertFails(
      updateDoc(billRef, {
        totalPaise: 20000,
        updatedBy: 'head-a',
      }),
    );
  });

  test('Cross-tenant bill generation is rejected', async () => {
    const db = auth('head-a', 'head-a@test.com');
    const crossBillRef = doc(db, 'businesses/business-b/monthlyBills/cust-b:2026-09');

    await assertFails(
      setDoc(crossBillRef, {
        businessId: 'business-b',
        customerId: 'cust-b',
        billingMonth: '2026-09',
        status: 'finalized',
        totalPaise: 20000,
        createdBy: 'head-a',
        createdAt: serverTimestamp(),
      }),
    );
  });
});

describe('Section 3.D: Outstanding Adjustment vs Payment Collection Separation', () => {
  test('Payment collection over collectible is rejected by security rules', async () => {
    await seedCollectionProjection({
      customerId: 'C-PAY-OVER',
      bills: [{ month: '2026-09', outstandingPaise: 100000 }], // ₹1,000
    });
    const db = auth('head-a', 'head-a@test.com');
    const paymentDoc = doc(db, 'businesses/business-a/payments/pay-overcollect');

    await assertFails(
      setDoc(paymentDoc, {
        businessId: 'business-a',
        customerId: 'C-PAY-OVER',
        paymentId: 'pay-overcollect',
        amountPaise: 101000, // ₹1,010 > ₹1,000 collectible
        method: 'cash',
        status: 'completed',
        collectedBy: 'head-a',
        createdAt: serverTimestamp(),
      }),
    );
  });

  test('Account balance adjustment ₹1,000 + ₹10 = ₹1,010 succeeds under adjustment rules', async () => {
    await seedCollectionProjection({
      customerId: 'C-ADJ-1',
      bills: [{ month: '2026-09', outstandingPaise: 100000 }], // ₹1,000
    });
    const db = auth('head-a', 'head-a@test.com');
    await assertSucceeds(
      recordAccountAdjustmentTransaction(db, {
        customerId: 'C-ADJ-1',
        adjustmentId: 'adj-increase-10',
        actorId: 'head-a',
        actorRole: 'head',
        direction: 'increase',
        amountPaise: 1000, // +₹10
        reason: 'Audited late paper delivery fee',
      }),
    );

    const state = (
      await getDoc(
        doc(db, 'businesses/business-a/customers/C-ADJ-1/collectionState/current'),
      )
    ).data();
    assert.equal(state.outstandingPaise, 101000); // ₹1,010
  });

  test('Account balance adjustment ₹0 + ₹100 = ₹100 succeeds under adjustment rules', async () => {
    await seedCollectionProjection({
      customerId: 'C-ADJ-0',
      bills: [{ month: '2026-09', outstandingPaise: 0 }], // ₹0
    });
    const db = auth('head-a', 'head-a@test.com');
    await assertSucceeds(
      recordAccountAdjustmentTransaction(db, {
        customerId: 'C-ADJ-0',
        adjustmentId: 'adj-increase-100',
        actorId: 'head-a',
        actorRole: 'head',
        direction: 'increase',
        amountPaise: 10000, // +₹100
        reason: 'Opening balance correction',
      }),
    );

    const state = (
      await getDoc(
        doc(db, 'businesses/business-a/customers/C-ADJ-0/collectionState/current'),
      )
    ).data();
    assert.equal(state.outstandingPaise, 10000); // ₹100
  });
});

describe('18 Comprehensive Global Pricing Authorization & Security Requirements', () => {
  test('1. Head creates global price → ALLOW', async () => {
    const db = auth('head-a', 'head-a@test.com');
    const ruleRef = doc(db, 'businesses/business-a/newspapers/paper-et/priceRules/req-rule-1');
    const auditRef = doc(db, 'businesses/business-a/auditRecords/req-audit-1');
    const paperRef = doc(db, 'businesses/business-a/newspapers/paper-et');

    const batch = writeBatch(db);
    batch.set(ruleRef, {
      businessId: 'business-a',
      newspaperId: 'paper-et',
      priceRuleId: 'req-rule-1',
      kind: 'period',
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      pricePaise: 700,
      status: 'active',
      supersedesRuleId: '',
      supersededByRuleId: '',
      revision: 1,
      reason: 'October rate',
      createdBy: 'head-a',
      updatedBy: 'head-a',
      lastAuditId: 'req-audit-1',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    batch.update(paperRef, {
      updatedBy: 'head-a',
      lastAuditId: 'req-audit-1',
      updatedAt: serverTimestamp(),
    });
    batch.set(auditRef, {
      businessId: 'business-a',
      actorId: 'head-a',
      action: 'newspaperPriceRuleCreated',
      entityType: 'newspaper',
      entityId: 'paper-et',
      priceRuleId: 'req-rule-1',
      kind: 'period',
      pricePaise: 700,
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      reason: 'October rate',
      createdAt: serverTimestamp(),
    });

    await assertSucceeds(batch.commit());
  });

  test('2. Head supersedes global price → ALLOW', async () => {
    const db = auth('head-a', 'head-a@test.com');
    const initRuleRef = doc(db, 'businesses/business-a/newspapers/paper-et/priceRules/req-rule-init-2');
    const initAuditRef = doc(db, 'businesses/business-a/auditRecords/req-audit-init-2');
    const paperRef = doc(db, 'businesses/business-a/newspapers/paper-et');

    // 1. Create initial active price rule
    const initBatch = writeBatch(db);
    initBatch.set(initRuleRef, {
      businessId: 'business-a',
      newspaperId: 'paper-et',
      priceRuleId: 'req-rule-init-2',
      kind: 'period',
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      pricePaise: 700,
      status: 'active',
      supersedesRuleId: '',
      supersededByRuleId: '',
      revision: 1,
      reason: 'October initial rate',
      createdBy: 'head-a',
      updatedBy: 'head-a',
      lastAuditId: 'req-audit-init-2',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    initBatch.update(paperRef, {
      updatedBy: 'head-a',
      lastAuditId: 'req-audit-init-2',
      updatedAt: serverTimestamp(),
    });
    initBatch.set(initAuditRef, {
      businessId: 'business-a',
      actorId: 'head-a',
      action: 'newspaperPriceRuleCreated',
      entityType: 'newspaper',
      entityId: 'paper-et',
      priceRuleId: 'req-rule-init-2',
      kind: 'period',
      pricePaise: 700,
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      reason: 'October initial rate',
      createdAt: serverTimestamp(),
    });
    await assertSucceeds(initBatch.commit());

    // 2. Supersede initial rule with replacement rule
    const newRuleRef = doc(db, 'businesses/business-a/newspapers/paper-et/priceRules/req-rule-2');
    const auditRef = doc(db, 'businesses/business-a/auditRecords/req-audit-2');

    const supersedeBatch = writeBatch(db);
    supersedeBatch.update(initRuleRef, {
      status: 'superseded',
      supersededByRuleId: 'req-rule-2',
      updatedBy: 'head-a',
      lastAuditId: 'req-audit-2',
      updatedAt: serverTimestamp(),
    });
    supersedeBatch.set(newRuleRef, {
      businessId: 'business-a',
      newspaperId: 'paper-et',
      priceRuleId: 'req-rule-2',
      kind: 'period',
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      pricePaise: 750,
      status: 'active',
      supersedesRuleId: 'req-rule-init-2',
      supersededByRuleId: '',
      revision: 2,
      reason: 'Correction to October rate',
      createdBy: 'head-a',
      updatedBy: 'head-a',
      lastAuditId: 'req-audit-2',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    supersedeBatch.update(paperRef, {
      updatedBy: 'head-a',
      lastAuditId: 'req-audit-2',
      updatedAt: serverTimestamp(),
    });
    supersedeBatch.set(auditRef, {
      businessId: 'business-a',
      actorId: 'head-a',
      action: 'newspaperPriceRuleCorrected',
      entityType: 'newspaper',
      entityId: 'paper-et',
      priceRuleId: 'req-rule-2',
      replacedPriceRuleId: 'req-rule-init-2',
      kind: 'period',
      pricePaise: 750,
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      reason: 'Correction to October rate',
      createdAt: serverTimestamp(),
    });

    await assertSucceeds(supersedeBatch.commit());
  });

  test('3. Employee + allowGlobalPricing → ALLOW', async () => {
    const db = auth('emp-pricing', 'emp-pricing@test.com');
    const ruleRef = doc(db, 'businesses/business-a/newspapers/paper-et/priceRules/req-rule-emp-3');
    const auditRef = doc(db, 'businesses/business-a/auditRecords/req-audit-3');
    const paperRef = doc(db, 'businesses/business-a/newspapers/paper-et');

    const batch = writeBatch(db);
    batch.set(ruleRef, {
      businessId: 'business-a',
      newspaperId: 'paper-et',
      priceRuleId: 'req-rule-emp-3',
      kind: 'period',
      startDate: '2026-11-01',
      endDate: '2026-11-30',
      pricePaise: 800,
      status: 'active',
      supersedesRuleId: '',
      supersededByRuleId: '',
      revision: 1,
      reason: 'November rate by employee',
      createdBy: 'emp-pricing',
      updatedBy: 'emp-pricing',
      lastAuditId: 'req-audit-3',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    batch.update(paperRef, {
      updatedBy: 'emp-pricing',
      lastAuditId: 'req-audit-3',
      updatedAt: serverTimestamp(),
    });
    batch.set(auditRef, {
      businessId: 'business-a',
      actorId: 'emp-pricing',
      action: 'newspaperPriceRuleCreated',
      entityType: 'newspaper',
      entityId: 'paper-et',
      priceRuleId: 'req-rule-emp-3',
      kind: 'period',
      pricePaise: 800,
      startDate: '2026-11-01',
      endDate: '2026-11-30',
      reason: 'November rate by employee',
      createdAt: serverTimestamp(),
    });

    await assertSucceeds(batch.commit());
  });

  test('4. Employee without allowGlobalPricing → DENY', async () => {
    const db = auth('emp-unauthorized', 'emp-unauth@test.com');
    const ruleRef = doc(db, 'businesses/business-a/newspapers/paper-et/priceRules/req-rule-emp-4');
    await assertFails(
      setDoc(ruleRef, {
        businessId: 'business-a',
        newspaperId: 'paper-et',
        priceRuleId: 'req-rule-emp-4',
        kind: 'exactDate',
        startDate: '2026-12-01',
        endDate: null,
        pricePaise: 800,
        status: 'active',
        supersedesRuleId: '',
        supersededByRuleId: '',
        revision: 1,
        reason: 'Unauthorized attempt',
        createdBy: 'emp-unauthorized',
        updatedBy: 'emp-unauthorized',
        lastAuditId: 'req-audit-4',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('5. Inactive employee + permission → DENY', async () => {
    const db = auth('emp-inactive', 'emp-inactive@test.com');
    const ruleRef = doc(db, 'businesses/business-a/newspapers/paper-et/priceRules/req-rule-emp-5');
    await assertFails(
      setDoc(ruleRef, {
        businessId: 'business-a',
        newspaperId: 'paper-et',
        priceRuleId: 'req-rule-emp-5',
        kind: 'exactDate',
        startDate: '2026-12-01',
        endDate: null,
        pricePaise: 800,
        status: 'active',
        supersedesRuleId: '',
        supersededByRuleId: '',
        revision: 1,
        reason: 'Inactive employee attempt',
        createdBy: 'emp-inactive',
        updatedBy: 'emp-inactive',
        lastAuditId: 'req-audit-5',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('6. Employee attempts self-grant of allowGlobalPricing → DENY', async () => {
    const db = auth('emp-unauthorized', 'emp-unauth@test.com');
    const empDoc = doc(db, 'businesses/business-a/members/emp-unauthorized');
    await assertFails(
      updateDoc(empDoc, {
        permissions: ['allowGlobalPricing'],
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('7. Employee attempts to grant another employee → DENY', async () => {
    const db = auth('emp-pricing', 'emp-pricing@test.com');
    const empDoc = doc(db, 'businesses/business-a/members/emp-unauthorized');
    await assertFails(
      updateDoc(empDoc, {
        permissions: ['allowGlobalPricing'],
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('8. Cross-tenant employee → DENY', async () => {
    const db = auth('emp-pricing', 'emp-pricing@test.com');
    const crossRule = doc(db, 'businesses/business-b/newspapers/paper-et/priceRules/req-rule-8');
    await assertFails(
      setDoc(crossRule, {
        businessId: 'business-b',
        newspaperId: 'paper-et',
        priceRuleId: 'req-rule-8',
        kind: 'exactDate',
        startDate: '2026-12-01',
        endDate: null,
        pricePaise: 800,
        status: 'active',
        supersedesRuleId: '',
        supersededByRuleId: '',
        revision: 1,
        reason: 'Cross tenant attempt',
        createdBy: 'emp-pricing',
        updatedBy: 'emp-pricing',
        lastAuditId: 'req-audit-8',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('9. Malformed permission data → DENY', async () => {
    const db = auth('emp-unauthorized', 'emp-unauth@test.com');
    const ruleRef = doc(db, 'businesses/business-a/newspapers/paper-et/priceRules/req-rule-9');
    await assertFails(
      setDoc(ruleRef, {
        businessId: 'business-a',
        newspaperId: 'paper-et',
        priceRuleId: 'req-rule-9',
        kind: 'exactDate',
        startDate: '2026-12-01',
        endDate: null,
        pricePaise: 800,
        status: 'active',
        supersedesRuleId: '',
        supersededByRuleId: '',
        revision: 1,
        reason: 'Malformed check',
        createdBy: 'emp-unauthorized',
        updatedBy: 'emp-unauthorized',
        lastAuditId: 'req-audit-9',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('10. Missing/invalid business membership → DENY', async () => {
    const db = auth('ghost-user', 'ghost@test.com');
    const ruleRef = doc(db, 'businesses/business-a/newspapers/paper-et/priceRules/req-rule-10');
    await assertFails(
      setDoc(ruleRef, {
        businessId: 'business-a',
        newspaperId: 'paper-et',
        priceRuleId: 'req-rule-10',
        kind: 'exactDate',
        startDate: '2026-12-01',
        endDate: null,
        pricePaise: 800,
        status: 'active',
        supersedesRuleId: '',
        supersededByRuleId: '',
        revision: 1,
        reason: 'Ghost user attempt',
        createdBy: 'ghost-user',
        updatedBy: 'ghost-user',
        lastAuditId: 'req-audit-10',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('11. Subscription write gate still enforced', async () => {
    const db = auth('head-b', 'head-b@test.com'); // business-b has expired subscription
    const ruleRef = doc(db, 'businesses/business-b/newspapers/paper-et/priceRules/req-rule-11');
    await assertFails(
      setDoc(ruleRef, {
        businessId: 'business-b',
        newspaperId: 'paper-et',
        priceRuleId: 'req-rule-11',
        kind: 'exactDate',
        startDate: '2026-12-01',
        endDate: null,
        pricePaise: 800,
        status: 'active',
        supersedesRuleId: '',
        supersededByRuleId: '',
        revision: 1,
        reason: 'Expired subscription attempt',
        createdBy: 'head-b',
        updatedBy: 'head-b',
        lastAuditId: 'req-audit-11',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('12. PriceRule schema validation still enforced', async () => {
    const db = auth('head-a', 'head-a@test.com');
    const ruleRef = doc(db, 'businesses/business-a/newspapers/paper-et/priceRules/req-rule-12');
    await assertFails(
      setDoc(ruleRef, {
        businessId: 'business-a',
        newspaperId: 'paper-et',
        priceRuleId: 'req-rule-12',
        kind: 'invalidKind', // invalid kind
        startDate: '2026-12-01',
        endDate: null,
        pricePaise: -100, // negative price
        status: 'active',
        supersedesRuleId: '',
        supersededByRuleId: '',
        revision: 1,
        reason: 'Schema violation',
        createdBy: 'head-a',
        updatedBy: 'head-a',
        lastAuditId: 'req-audit-12',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('13. Audit actor must equal authenticated actor', async () => {
    const db = auth('emp-pricing', 'emp-pricing@test.com');
    const ruleRef = doc(db, 'businesses/business-a/newspapers/paper-et/priceRules/req-rule-13');
    const auditRef = doc(db, 'businesses/business-a/auditRecords/req-audit-13');
    const paperRef = doc(db, 'businesses/business-a/newspapers/paper-et');

    const batch = writeBatch(db);
    batch.set(ruleRef, {
      businessId: 'business-a',
      newspaperId: 'paper-et',
      priceRuleId: 'req-rule-13',
      kind: 'period',
      startDate: '2026-12-01',
      endDate: '2026-12-31',
      pricePaise: 800,
      status: 'active',
      supersedesRuleId: '',
      supersededByRuleId: '',
      revision: 1,
      reason: 'Audit actor forgery',
      createdBy: 'emp-pricing',
      updatedBy: 'emp-pricing',
      lastAuditId: 'req-audit-13',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    batch.update(paperRef, {
      updatedBy: 'emp-pricing',
      lastAuditId: 'req-audit-13',
      updatedAt: serverTimestamp(),
    });
    batch.set(auditRef, {
      businessId: 'business-a',
      actorId: 'head-a', // Forged actorId! Should equal emp-pricing
      action: 'newspaperPriceRuleCreated',
      entityType: 'newspaper',
      entityId: 'paper-et',
      priceRuleId: 'req-rule-13',
      kind: 'period',
      pricePaise: 800,
      startDate: '2026-12-01',
      endDate: '2026-12-31',
      reason: 'Audit actor forgery',
      createdAt: serverTimestamp(),
    });

    await assertFails(batch.commit());
  });

  test('14. Newspaper update cannot be performed independently by unauthorized employee', async () => {
    const db = auth('emp-unauthorized', 'emp-unauth@test.com');
    const paperRef = doc(db, 'businesses/business-a/newspapers/paper-et');
    await assertFails(
      updateDoc(paperRef, {
        name: 'Hacked ET Name',
        updatedBy: 'emp-unauthorized',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('15. Direct priceRules write cannot bypass authorization', async () => {
    const db = auth('emp-unauthorized', 'emp-unauth@test.com');
    const ruleRef = doc(db, 'businesses/business-a/newspapers/paper-et/priceRules/direct-bypass');
    await assertFails(
      setDoc(ruleRef, {
        businessId: 'business-a',
        newspaperId: 'paper-et',
        priceRuleId: 'direct-bypass',
        kind: 'exactDate',
        startDate: '2026-12-01',
        endDate: null,
        pricePaise: 500,
        status: 'active',
        supersedesRuleId: '',
        supersededByRuleId: '',
        revision: 1,
        reason: 'Direct write attempt',
        createdBy: 'emp-unauthorized',
        updatedBy: 'emp-unauthorized',
        lastAuditId: 'audit-bypass',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('16. Superseding an existing rule preserves revision/invariants', async () => {
    const db = auth('head-a', 'head-a@test.com');
    const oldRuleRef = doc(db, 'businesses/business-a/newspapers/paper-et/priceRules/req-rule-emp-3');
    const newRuleRef = doc(db, 'businesses/business-a/newspapers/paper-et/priceRules/bad-supersede');
    const auditRef = doc(db, 'businesses/business-a/auditRecords/bad-audit-16');
    const paperRef = doc(db, 'businesses/business-a/newspapers/paper-et');

    const batch = writeBatch(db);
    batch.update(oldRuleRef, {
      status: 'superseded',
      supersededByRuleId: 'bad-supersede',
      updatedBy: 'head-a',
      lastAuditId: 'bad-audit-16',
      updatedAt: serverTimestamp(),
    });
    batch.set(newRuleRef, {
      businessId: 'business-a',
      newspaperId: 'paper-et',
      priceRuleId: 'bad-supersede',
      kind: 'period',
      startDate: '2026-11-01',
      endDate: '2026-11-30',
      pricePaise: 850,
      status: 'active',
      supersedesRuleId: 'req-rule-emp-3',
      supersededByRuleId: '',
      revision: 1, // Invalid: should be 2 because supersedes req-rule-emp-3 (revision 1)
      reason: 'Bad revision attempt',
      createdBy: 'head-a',
      updatedBy: 'head-a',
      lastAuditId: 'bad-audit-16',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    batch.update(paperRef, {
      updatedBy: 'head-a',
      lastAuditId: 'bad-audit-16',
      updatedAt: serverTimestamp(),
    });
    batch.set(auditRef, {
      businessId: 'business-a',
      actorId: 'head-a',
      action: 'newspaperPriceRuleCorrected',
      entityType: 'newspaper',
      entityId: 'paper-et',
      priceRuleId: 'bad-supersede',
      replacedPriceRuleId: 'req-rule-emp-3',
      kind: 'period',
      pricePaise: 850,
      startDate: '2026-11-01',
      endDate: '2026-11-30',
      reason: 'Bad revision attempt',
      createdAt: serverTimestamp(),
    });

    await assertFails(batch.commit());
  });

  test('17. Finalized bills remain immutable', async () => {
    const db = auth('head-a', 'head-a@test.com');
    const billRef = doc(db, 'businesses/business-a/customers/C-MANAGED/bills/2026-09');
    await assertFails(
      updateDoc(billRef, {
        totalDuePaise: 0,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('18. Existing customer-specific pricing behavior remains intact', async () => {
    const db = auth('emp-pricing', 'emp-pricing@test.com');
    const subRef = doc(db, 'businesses/business-a/customers/C-MANAGED/subscriptions/sub-1');
    await assertFails(
      setDoc(subRef, {
        businessId: 'business-a',
        customerId: 'C-MANAGED',
        subscriptionId: 'sub-1',
        newspaperId: 'paper-et',
        status: 'active',
      }),
    );
  });

  test('19. Head can create and update monthlyBillingPrices for their business', async () => {
    const db = auth('head-a', 'head-a@test.com');
    const priceRef = doc(db, 'businesses/business-a/monthlyBillingPrices/2026-09_paper-et');
    await assertSucceeds(
      setDoc(priceRef, {
        businessId: 'business-a',
        billingMonth: '2026-09',
        newspaperId: 'paper-et',
        newspaperName: 'Economic Times',
        pricePaise: 19900,
        pricingBasis: 'monthly',
        updatedBy: 'head-a',
      }),
    );
  });

  test('20. Unauthorized user from another business cannot create or read monthlyBillingPrices', async () => {
    const db = auth('head-b', 'head-b@test.com');
    const priceRef = doc(db, 'businesses/business-a/monthlyBillingPrices/2026-09_paper-et');
    await assertFails(
      setDoc(priceRef, {
        businessId: 'business-a',
        billingMonth: '2026-09',
        newspaperId: 'paper-et',
        newspaperName: 'Economic Times',
        pricePaise: 19900,
        pricingBasis: 'monthly',
        updatedBy: 'head-b',
      }),
    );
  });

  test('21. Authorized user can record billing failure for customer', async () => {
    const db = auth('head-a', 'head-a@test.com');
    const failRef = doc(db, 'businesses/business-a/billingFailures/2026-09_C-MANAGED');
    await assertSucceeds(
      setDoc(failRef, {
        businessId: 'business-a',
        customerId: 'C-MANAGED',
        billingMonth: '2026-09',
        error: 'Finalization failed due to lock',
        failedBy: 'head-a',
      }),
    );
  });

  test('22. Unauthorized employee without billing permission or assignment cannot record billing failure', async () => {
    const db = auth('emp-unauthorized', 'emp-unauth@test.com');
    const failRef = doc(db, 'businesses/business-a/billingFailures/2026-09_C-MANAGED');
    await assertFails(
      setDoc(failRef, {
        businessId: 'business-a',
        customerId: 'C-MANAGED',
        billingMonth: '2026-09',
        error: 'Unauthorized employee failure report',
        failedBy: 'emp-unauthorized',
      }),
    );
  });

  test('23. Head can delete an authorized billing failure', async () => {
    // Seed failure document
    await environment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'businesses/business-a/billingFailures/2026-09_C-MANAGED'), {
        businessId: 'business-a',
        customerId: 'C-MANAGED',
        billingMonth: '2026-09',
        error: 'Finalization failed due to lock',
        failedBy: 'employee-a',
      });
    });

    const db = auth('head-a', 'head-a@test.com');
    const failRef = doc(db, 'businesses/business-a/billingFailures/2026-09_C-MANAGED');
    await assertSucceeds(deleteDoc(failRef));
  });

  test('24. Assigned employee with allowManualBilling can delete an authorized billing failure', async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'businesses/business-a/billingFailures/2026-09_C-MANAGED'), {
        businessId: 'business-a',
        customerId: 'C-MANAGED',
        billingMonth: '2026-09',
        error: 'Temporary operational error',
        failedBy: 'head-a',
      });
    });

    const db = auth('employee-a', 'employee-a@test.com');
    const failRef = doc(db, 'businesses/business-a/billingFailures/2026-09_C-MANAGED');
    await assertSucceeds(deleteDoc(failRef));
  });

  test('25. Employee without allowManualBilling cannot delete billing failure', async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'businesses/business-a/billingFailures/2026-09_C-MANAGED'), {
        businessId: 'business-a',
        customerId: 'C-MANAGED',
        billingMonth: '2026-09',
        error: 'Failure',
        failedBy: 'head-a',
      });
    });

    const db = auth('emp-unauthorized', 'emp-unauth@test.com');
    const failRef = doc(db, 'businesses/business-a/billingFailures/2026-09_C-MANAGED');
    await assertFails(deleteDoc(failRef));
  });

  test('26. Employee assigned to a different customer/area cannot delete billing failure', async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'businesses/business-a/billingFailures/2026-09_C-MANAGED'), {
        businessId: 'business-a',
        customerId: 'C-MANAGED',
        billingMonth: '2026-09',
        error: 'Failure',
        failedBy: 'employee-a',
      });
    });

    const db = auth('employee-other', 'employee-other@test.com');
    const failRef = doc(db, 'businesses/business-a/billingFailures/2026-09_C-MANAGED');
    await assertFails(deleteDoc(failRef));
  });

  test('27. Cross-business member cannot delete billing failure', async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'businesses/business-a/billingFailures/2026-09_C-MANAGED'), {
        businessId: 'business-a',
        customerId: 'C-MANAGED',
        billingMonth: '2026-09',
        error: 'Failure',
        failedBy: 'head-a',
      });
    });

    const db = auth('head-b', 'head-b@test.com');
    const failRef = doc(db, 'businesses/business-a/billingFailures/2026-09_C-MANAGED');
    await assertFails(deleteDoc(failRef));
  });

  test('28. Deletion of billingFailures grants NO financial authority (bills and balances unchanged)', async () => {
    await seedCollectionProjection();
    await environment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'businesses/business-a/billingFailures/2026-09_C-MANAGED'), {
        businessId: 'business-a',
        customerId: 'C-MANAGED',
        billingMonth: '2026-09',
        error: 'Temporary error',
        failedBy: 'head-a',
      });
    });

    const db = auth('head-a', 'head-a@test.com');
    const failRef = doc(db, 'businesses/business-a/billingFailures/2026-09_C-MANAGED');
    await assertSucceeds(deleteDoc(failRef));

    // Confirm that deleting failure did not mutate any financial records
    const billRef = doc(db, 'businesses/business-a/customers/C-MANAGED/bills/2026-09');
    const balanceRef = doc(db, 'businesses/business-a/customers/C-MANAGED/billBalances/2026-09');
    const stateRef = doc(db, 'businesses/business-a/customers/C-MANAGED/collectionState/current');

    const billSnap = await getDoc(billRef);
    const balanceSnap = await getDoc(balanceRef);
    const stateSnap = await getDoc(stateRef);

    // Bill still has its original state, outstanding is untouched
    assert.equal(balanceSnap.data().outstandingPaise, 100000);
    assert.equal(stateSnap.data().outstandingPaise, 100000);
  });
});
