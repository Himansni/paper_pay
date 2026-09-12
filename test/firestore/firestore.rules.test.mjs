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
} = {}) => ({
  businessId: 'business-a',
  customerId,
  customerCode: customerId,
  customerName: 'Managed Customer',
  customerSearchName: 'managed customer',
  customerAddress: '1 Main Road, Paper Town, Near Clock Tower',
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

  test('assigned employee can append but never edit a confirmed payment', async () => {
    const db = auth('employee-a', 'employee-a@example.com');
    const payment = doc(
      db,
      'businesses/business-a/customers/assigned/payments/payment-1',
    );
    await assertSucceeds(
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
    await assertFails(updateDoc(payment, { amountPaise: 60000 }));
  });
});

describe('verified employee invitation', () => {
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

test('test environment initialized', () => {
  assert.ok(environment);
});
