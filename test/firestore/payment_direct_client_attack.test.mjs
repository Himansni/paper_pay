import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-paper-route-payment-attack';
let environment;

const auth = (uid, email) =>
  environment.authenticatedContext(uid, {
    email,
    email_verified: true,
  }).firestore();

const seed = async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    // Business A
    await setDoc(doc(db, 'businesses/business-a'), {
      name: 'Agency A',
      status: 'active',
      createdAt: new Date(),
    });

    await setDoc(doc(db, 'businesses/business-a/subscription/saas'), {
      businessId: 'business-a',
      status: 'active',
      effectiveExpiresAt: new Date('2099-01-01T00:00:00.000Z'),
    });

    // Head A
    await setDoc(doc(db, 'businesses/business-a/members/head-a'), {
      businessId: 'business-a',
      uid: 'head-a',
      role: 'head',
      status: 'active',
      email: 'head-a@test.local',
      displayName: 'Head A',
    });

    // Employee A
    await setDoc(doc(db, 'businesses/business-a/members/employee-a'), {
      businessId: 'business-a',
      uid: 'employee-a',
      role: 'employee',
      status: 'active',
      email: 'employee-a@test.local',
      displayName: 'Employee A',
      permissions: ['recordPayments', 'allowCollectPayment'],
      areaIds: ['area-east'],
    });

    // Area East
    await setDoc(doc(db, 'businesses/business-a/areas/area-east'), {
      businessId: 'business-a',
      name: 'East Area',
      status: 'active',
      assignedEmployeeIds: ['employee-a'],
    });

    // Customer 1
    await setDoc(doc(db, 'businesses/business-a/customers/cust-1'), {
      businessId: 'business-a',
      customerCode: 'cust-1',
      name: 'Customer One',
      searchName: 'customer one',
      phone: '9999999999',
      searchPhone: '9999999999',
      alternatePhone: '',
      address: '10 Main Road',
      areaId: 'area-east',
      landmark: 'Gate 1',
      searchLandmark: 'gate 1',
      searchTokens: ['customer', 'one'],
      houseNumber: '10',
      buildingInfo: 'Building A',
      locationNotes: 'Call before delivery',
      locationConsent: false,
      coordinates: null,
      assignedEmployeeId: 'employee-a',
      status: 'active',
      subscriptionStatus: 'notConfigured',
      deliveryPreferences: { placement: 'doorstep' },
      billingPreferences: { cycle: 'monthly' },
      openingBalancePaise: 0,
      notes: '',
      createdBy: 'head-a',
      updatedBy: 'head-a',
      lastAuditId: 'audit-seed-1',
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    // Existing Payment in DB
    await setDoc(
      doc(db, 'businesses/business-a/customers/cust-1/payments/existing-pay'),
      {
        businessId: 'business-a',
        customerId: 'cust-1',
        paymentId: 'existing-pay',
        collectorUid: 'employee-a',
        amountPaise: 5000,
        status: 'confirmed',
        createdAt: new Date(),
      },
    );

    // Existing PaymentState in DB
    await setDoc(
      doc(db, 'businesses/business-a/customers/cust-1/paymentStates/existing-pay'),
      {
        businessId: 'business-a',
        customerId: 'cust-1',
        paymentId: 'existing-pay',
        amountPaise: 5000,
        refundablePaise: 5000,
        status: 'confirmed',
        createdAt: new Date(),
      },
    );

    // Bill balance
    await setDoc(
      doc(db, 'businesses/business-a/customers/cust-1/billBalances/2026-07'),
      {
        businessId: 'business-a',
        customerId: 'cust-1',
        billingMonth: '2026-07',
        sourceAmountPaise: 10000,
        allocatedPaise: 0,
        reversedPaise: 0,
        outstandingPaise: 10000,
        status: 'outstanding',
        revision: 1,
      },
    );

    // Collection state
    await setDoc(
      doc(db, 'businesses/business-a/customers/cust-1/collectionState/current'),
      {
        businessId: 'business-a',
        customerId: 'cust-1',
        stateId: 'current',
        customerCode: 'cust-1',
        customerName: 'Customer One',
        areaId: 'area-east',
        assignedEmployeeId: 'employee-a',
        customerStatus: 'active',
        outstandingPaise: 10000,
        confirmedPaise: 0,
        reversedPaise: 0,
        reportingStatus: 'unpaid',
        oldestOutstandingMonth: '2026-07',
        revision: 1,
        lastMutationType: 'billFinalized',
        lastMutationId: '2026-07',
        updatedBy: 'head-a',
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    );
  });
};

describe('Phase 8: Direct Client Payment & Financial Attack Denial Suite', () => {
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

  test('1. Malicious client attempts direct CREATE on /payments -> STRICTLY DENIED', async () => {
    const empDb = auth('employee-a', 'employee-a@test.local');
    const headDb = auth('head-a', 'head-a@test.local');

    const paymentDoc = {
      businessId: 'business-a',
      customerId: 'cust-1',
      paymentId: 'forged-pay-1',
      amountPaise: 5000,
      method: 'cash',
      status: 'confirmed',
      collectorUid: 'employee-a',
    };

    // Employee direct create -> DENIED
    await assertFails(
      setDoc(
        doc(empDb, 'businesses/business-a/customers/cust-1/payments/forged-pay-1'),
        paymentDoc,
      ),
    );

    // Head direct create -> DENIED
    await assertFails(
      setDoc(
        doc(headDb, 'businesses/business-a/customers/cust-1/payments/forged-pay-1'),
        paymentDoc,
      ),
    );
  });

  test('2. Malicious client attempts direct UPDATE on /payments -> STRICTLY DENIED', async () => {
    const empDb = auth('employee-a', 'employee-a@test.local');
    const headDb = auth('head-a', 'head-a@test.local');

    const payRefEmp = doc(
      empDb,
      'businesses/business-a/customers/cust-1/payments/existing-pay',
    );
    const payRefHead = doc(
      headDb,
      'businesses/business-a/customers/cust-1/payments/existing-pay',
    );

    await assertFails(updateDoc(payRefEmp, { amountPaise: 100 }));
    await assertFails(updateDoc(payRefHead, { amountPaise: 100 }));
  });

  test('3. Malicious client attempts direct DELETE on /payments -> STRICTLY DENIED', async () => {
    const empDb = auth('employee-a', 'employee-a@test.local');
    const headDb = auth('head-a', 'head-a@test.local');

    const payRefEmp = doc(
      empDb,
      'businesses/business-a/customers/cust-1/payments/existing-pay',
    );
    const payRefHead = doc(
      headDb,
      'businesses/business-a/customers/cust-1/payments/existing-pay',
    );

    await assertFails(deleteDoc(payRefEmp));
    await assertFails(deleteDoc(payRefHead));
  });

  test('4. Malicious client attempts direct CREATE on /paymentStates -> STRICTLY DENIED', async () => {
    const empDb = auth('employee-a', 'employee-a@test.local');
    const headDb = auth('head-a', 'head-a@test.local');

    const psDoc = {
      businessId: 'business-a',
      customerId: 'cust-1',
      paymentId: 'forged-ps-1',
      amountPaise: 5000,
      refundablePaise: 5000,
      status: 'confirmed',
    };

    await assertFails(
      setDoc(
        doc(empDb, 'businesses/business-a/customers/cust-1/paymentStates/forged-ps-1'),
        psDoc,
      ),
    );
    await assertFails(
      setDoc(
        doc(headDb, 'businesses/business-a/customers/cust-1/paymentStates/forged-ps-1'),
        psDoc,
      ),
    );
  });

  test('5. Malicious client attempts direct UPDATE or DELETE on /paymentStates -> STRICTLY DENIED', async () => {
    const empDb = auth('employee-a', 'employee-a@test.local');
    const headDb = auth('head-a', 'head-a@test.local');

    const psRef = doc(
      empDb,
      'businesses/business-a/customers/cust-1/paymentStates/existing-pay',
    );
    const psRefHead = doc(
      headDb,
      'businesses/business-a/customers/cust-1/paymentStates/existing-pay',
    );

    await assertFails(updateDoc(psRef, { refundablePaise: 0 }));
    await assertFails(updateDoc(psRefHead, { refundablePaise: 0 }));
    await assertFails(deleteDoc(psRef));
    await assertFails(deleteDoc(psRefHead));
  });

  test('6. Malicious client attempts forged mutation on /billBalances -> STRICTLY DENIED', async () => {
    const empDb = auth('employee-a', 'employee-a@test.local');
    const balRef = doc(
      empDb,
      'businesses/business-a/customers/cust-1/billBalances/2026-07',
    );

    await assertFails(
      updateDoc(balRef, {
        outstandingPaise: 0,
        allocatedPaise: 10000,
        status: 'settled',
        revision: 2,
        lastMutationType: 'paymentConfirmed',
        lastMutationId: 'fake-pay-1',
      }),
    );
  });

  test('7. Malicious client attempts forged mutation on /collectionState/current -> STRICTLY DENIED', async () => {
    const empDb = auth('employee-a', 'employee-a@test.local');
    const stateRef = doc(
      empDb,
      'businesses/business-a/customers/cust-1/collectionState/current',
    );

    await assertFails(
      updateDoc(stateRef, {
        outstandingPaise: 0,
        confirmedPaise: 10000,
        reportingStatus: 'fullyPaid',
        revision: 2,
        lastMutationType: 'paymentConfirmed',
        lastMutationId: 'fake-pay-1',
      }),
    );
  });

  test('8. Malicious client attempts direct CREATE on /auditRecords with forged paymentConfirmed audit -> STRICTLY DENIED', async () => {
    const empDb = auth('employee-a', 'employee-a@test.local');
    const headDb = auth('head-a', 'head-a@test.local');

    const forgedAudit = {
      businessId: 'business-a',
      actorId: 'employee-a',
      actorRole: 'employee',
      action: 'paymentConfirmed',
      entityType: 'payment',
      entityId: 'fake-payment-999',
      customerId: 'cust-1',
      paymentId: 'fake-payment-999',
      amountPaise: 10000,
      createdAt: serverTimestamp(),
    };

    await assertFails(
      setDoc(
        doc(empDb, 'businesses/business-a/auditRecords/forged-audit-1'),
        forgedAudit,
      ),
    );
    await assertFails(
      setDoc(
        doc(headDb, 'businesses/business-a/auditRecords/forged-audit-1'),
        forgedAudit,
      ),
    );
  });

  test('9. Malicious client attempts forged businessId / actorId on /auditRecords -> STRICTLY DENIED', async () => {
    const empDb = auth('employee-a', 'employee-a@test.local');

    // Forged businessId
    await assertFails(
      setDoc(
        doc(empDb, 'businesses/business-a/auditRecords/forged-biz-audit'),
        {
          businessId: 'business-b', // Foreign business
          actorId: 'employee-a',
          action: 'paymentConfirmed',
          createdAt: serverTimestamp(),
        },
      ),
    );

    // Forged actorId
    await assertFails(
      setDoc(
        doc(empDb, 'businesses/business-a/auditRecords/forged-actor-audit'),
        {
          businessId: 'business-a',
          actorId: 'head-a', // Forged actor
          action: 'paymentConfirmed',
          createdAt: serverTimestamp(),
        },
      ),
    );
  });

  test('10. Malicious client attempts direct UPDATE or DELETE on /auditRecords -> STRICTLY DENIED', async () => {
    const empDb = auth('employee-a', 'employee-a@test.local');
    const headDb = auth('head-a', 'head-a@test.local');

    // Seed an audit doc admin-side
    await environment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'businesses/business-a/auditRecords/existing-audit'), {
        businessId: 'business-a',
        actorId: 'head-a',
        action: 'customerCreated',
        createdAt: new Date(),
      });
    });

    const auditRefEmp = doc(empDb, 'businesses/business-a/auditRecords/existing-audit');
    const auditRefHead = doc(headDb, 'businesses/business-a/auditRecords/existing-audit');

    await assertFails(updateDoc(auditRefEmp, { action: 'tampered' }));
    await assertFails(updateDoc(auditRefHead, { action: 'tampered' }));

    await assertFails(deleteDoc(auditRefEmp));
    await assertFails(deleteDoc(auditRefHead));
  });

  test('11. Legitimate READ access to /payments and /paymentStates is PRESERVED', async () => {
    const empDb = auth('employee-a', 'employee-a@test.local');
    const headDb = auth('head-a', 'head-a@test.local');

    const payRefEmp = doc(
      empDb,
      'businesses/business-a/customers/cust-1/payments/existing-pay',
    );
    const psRefEmp = doc(
      empDb,
      'businesses/business-a/customers/cust-1/paymentStates/existing-pay',
    );

    const payRefHead = doc(
      headDb,
      'businesses/business-a/customers/cust-1/payments/existing-pay',
    );
    const psRefHead = doc(
      headDb,
      'businesses/business-a/customers/cust-1/paymentStates/existing-pay',
    );

    // Read payment
    await assertSucceeds(getDoc(payRefEmp));
    await assertSucceeds(getDoc(payRefHead));

    // Read paymentState
    await assertSucceeds(getDoc(psRefEmp));
    await assertSucceeds(getDoc(psRefHead));
  });

  test('12. Malicious client creation of paymentConfirmed audit referencing REAL payment doc -> ALL 7 FORGERY ATTACKS DENIED', async () => {
    const empDb = auth('employee-a', 'employee-a@test.local');
    const headDb = auth('head-a', 'head-a@test.local');

    // Real payment doc "existing-pay" already seeded in Firestore
    const basePayload = {
      businessId: 'business-a',
      actorId: 'employee-a',
      actorRole: 'employee',
      action: 'paymentConfirmed',
      entityType: 'payment',
      entityId: 'existing-pay',
      customerId: 'cust-1',
      paymentId: 'existing-pay',
      amountPaise: 5000,
      createdAt: serverTimestamp(),
    };

    // 1. Forged amount
    await assertFails(
      setDoc(doc(empDb, 'businesses/business-a/auditRecords/audit-forge-amt'), {
        ...basePayload,
        amountPaise: 999999,
      }),
    );

    // 2. Forged actorId
    await assertFails(
      setDoc(doc(empDb, 'businesses/business-a/auditRecords/audit-forge-actor'), {
        ...basePayload,
        actorId: 'head-a',
      }),
    );

    // 3. Forged customerId
    await assertFails(
      setDoc(doc(empDb, 'businesses/business-a/auditRecords/audit-forge-cust'), {
        ...basePayload,
        customerId: 'cust-wrong',
      }),
    );

    // 4. Forged businessId
    await assertFails(
      setDoc(doc(empDb, 'businesses/business-a/auditRecords/audit-forge-biz'), {
        ...basePayload,
        businessId: 'business-b',
      }),
    );

    // 5. Forged allocationStates
    await assertFails(
      setDoc(doc(empDb, 'businesses/business-a/auditRecords/audit-forge-alloc'), {
        ...basePayload,
        allocationStates: [{ billId: '2026-07', amountPaise: 9999 }],
      }),
    );

    // 6. Attacker-chosen custom timestamp
    await assertFails(
      setDoc(doc(empDb, 'businesses/business-a/auditRecords/audit-forge-time'), {
        ...basePayload,
        createdAt: new Date('2020-01-01'),
      }),
    );

    // 7. Attacker-chosen auditId even with matching fields (server-only rule)
    await assertFails(
      setDoc(doc(headDb, 'businesses/business-a/auditRecords/audit-forge-real-pay'), basePayload),
    );
  });

  test('13. Legitimate client customer profile audit record creation is PERMITTED for Head', async () => {
    const headDb = auth('head-a', 'head-a@test.local');
    const auditId = 'profile-audit-001';
    const batch = writeBatch(headDb);

    batch.update(doc(headDb, 'businesses/business-a/customers/cust-1'), {
      name: 'Updated Name',
      searchName: 'updated name',
      searchTokens: ['updated', 'name'],
      updatedBy: 'head-a',
      lastAuditId: auditId,
      updatedAt: serverTimestamp(),
    });

    batch.update(doc(headDb, 'businesses/business-a/customers/cust-1/collectionState/current'), {
      customerName: 'Updated Name',
      revision: 2,
      lastMutationType: 'customerProfileUpdated',
      lastMutationId: auditId,
      updatedBy: 'head-a',
      updatedAt: serverTimestamp(),
    });

    batch.set(doc(headDb, `businesses/business-a/auditRecords/${auditId}`), {
      businessId: 'business-a',
      actorId: 'head-a',
      action: 'customerUpdated',
      entityType: 'customer',
      entityId: 'cust-1',
      changedFields: ['name', 'searchName', 'searchTokens'],
      createdAt: serverTimestamp(),
    });

    await assertSucceeds(batch.commit());
  });
});
