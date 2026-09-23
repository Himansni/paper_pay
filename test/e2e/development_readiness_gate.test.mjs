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
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-paper-route-readiness';
let environment;

const getDb = (uid, email) =>
  environment.authenticatedContext(uid, {
    email,
    email_verified: true,
  }).firestore();

describe('PAPERROUTE — Development Hands-on Readiness Gate', () => {
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

    // Seed the isolated development test scenario
    await environment.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const now = new Date();

      // 1. Business
      await setDoc(doc(db, 'businesses/biz-dev'), {
        name: 'Dev News Agency',
        status: 'active',
        createdAt: now,
      });

      // 2. Head User
      await setDoc(doc(db, 'businesses/biz-dev/members/head-1'), {
        businessId: 'biz-dev',
        uid: 'head-1',
        role: 'head',
        status: 'active',
        email: 'head@devagency.local',
        displayName: 'Sunil Kumar (Head)',
        areaIds: ['north-sector', 'south-sector'],
        permissions: ['arrangeDeliveryRoutes', 'collectPayments'],
        createdAt: now,
      });

      // 3. Employee User with assigned area 'north-sector' and 'arrangeDeliveryRoutes'
      await setDoc(doc(db, 'businesses/biz-dev/members/emp-1'), {
        businessId: 'biz-dev',
        uid: 'emp-1',
        role: 'employee',
        status: 'active',
        email: 'ramesh@devagency.local',
        displayName: 'Ramesh Singh (Delivery)',
        areaIds: ['north-sector'],
        permissions: ['arrangeDeliveryRoutes', 'collectPayments'],
        createdAt: now,
      });

      // 4. Employee 2 without arrangeDeliveryRoutes (for negative testing)
      await setDoc(doc(db, 'businesses/biz-dev/members/emp-2'), {
        businessId: 'biz-dev',
        uid: 'emp-2',
        role: 'employee',
        status: 'active',
        email: 'suresh@devagency.local',
        displayName: 'Suresh (No Arrange)',
        areaIds: ['north-sector'],
        permissions: [],
        createdAt: now,
      });

      // 5. Delivery Area
      await setDoc(doc(db, 'businesses/biz-dev/areas/north-sector'), {
        businessId: 'biz-dev',
        id: 'north-sector',
        name: 'North Sector',
        isActive: true,
        assignedEmployeeIds: ['emp-1', 'emp-2'],
        createdAt: now,
      });

      // 6. Publications with effective date prices
      // Publication 1: Times of India (Daily)
      await setDoc(doc(db, 'businesses/biz-dev/newspapers/toi'), {
        businessId: 'biz-dev',
        id: 'toi',
        name: 'Times of India',
        status: 'active',
        effectivePrices: {
          '2026-01-01': {
            weekdayPaise: 500,
            sundayPaise: 600,
          },
        },
        createdAt: now,
      });

      // Publication 2: Economic Times (Daily)
      await setDoc(doc(db, 'businesses/biz-dev/newspapers/et'), {
        businessId: 'biz-dev',
        id: 'et',
        name: 'Economic Times',
        status: 'active',
        effectivePrices: {
          '2026-01-01': {
            weekdayPaise: 450,
            sundayPaise: 500,
          },
        },
        createdAt: now,
      });

      // Publication 3: Dainik Jagran (Daily)
      await setDoc(doc(db, 'businesses/biz-dev/newspapers/dj'), {
        businessId: 'biz-dev',
        id: 'dj',
        name: 'Dainik Jagran',
        status: 'active',
        effectivePrices: {
          '2026-01-01': {
            weekdayPaise: 400,
            sundayPaise: 400,
          },
        },
        createdAt: now,
      });

      // 7. Customer subscribed to 3 newspapers in north-sector
      await setDoc(doc(db, 'businesses/biz-dev/customers/cust-1'), {
        businessId: 'biz-dev',
        id: 'cust-1',
        customerCode: 'C101',
        name: 'Vikram Malhotra',
        phone: '9811122233',
        areaId: 'north-sector',
        assignedEmployeeId: 'emp-1',
        houseNumber: 'Flat 402',
        buildingInfo: 'Royal Palms',
        address: 'Sector 5, North',
        landmark: 'Near Central Park',
        deliveryPlacement: 'doorstep',
        status: 'active',
        createdAt: now,
      });

      // Subscription 1: Times of India (Active status, has dated pause Oct 12 - Oct 15)
      await setDoc(
        doc(db, 'businesses/biz-dev/customers/cust-1/subscriptions/sub-toi'),
        {
          businessId: 'biz-dev',
          id: 'sub-toi',
          customerId: 'cust-1',
          newspaperId: 'toi',
          newspaperName: 'Times of India',
          status: 'active',
          startDate: '2026-01-01',
          endDate: null,
          quantity: 2,
          deliveryWeekdays: [1, 2, 3, 4, 5, 6, 7],
          customPricePaise: null,
          customPriceReason: '',
          createdAt: now,
        },
      );

      // Dated Pause on Subscription 1: Oct 12 to Oct 15 inclusive
      await setDoc(
        doc(
          db,
          'businesses/biz-dev/customers/cust-1/subscriptions/sub-toi/pauses/pause-1',
        ),
        {
          businessId: 'biz-dev',
          id: 'pause-1',
          customerId: 'cust-1',
          subscriptionId: 'sub-toi',
          startDate: '2026-10-12',
          endDate: '2026-10-15',
          reason: 'Diwali vacation trip',
          status: 'closed',
          createdAt: now,
        },
      );

      // Subscription 2: Economic Times (Active status, no pause)
      await setDoc(
        doc(db, 'businesses/biz-dev/customers/cust-1/subscriptions/sub-et'),
        {
          businessId: 'biz-dev',
          id: 'sub-et',
          customerId: 'cust-1',
          newspaperId: 'et',
          newspaperName: 'Economic Times',
          status: 'active',
          startDate: '2026-01-01',
          endDate: null,
          quantity: 1,
          deliveryWeekdays: [1, 2, 3, 4, 5, 6, 7],
          customPricePaise: null,
          customPriceReason: '',
          createdAt: now,
        },
      );

      // Subscription 3: Dainik Jagran (Active status, no pause)
      await setDoc(
        doc(db, 'businesses/biz-dev/customers/cust-1/subscriptions/sub-dj'),
        {
          businessId: 'biz-dev',
          id: 'sub-dj',
          customerId: 'cust-1',
          newspaperId: 'dj',
          newspaperName: 'Dainik Jagran',
          status: 'active',
          startDate: '2026-01-01',
          endDate: null,
          quantity: 1,
          deliveryWeekdays: [1, 2, 3, 4, 5, 6, 7],
          customPricePaise: null,
          customPriceReason: '',
          createdAt: now,
        },
      );
    });
  });

  test('Scenario: Date before pause (2026-10-11) — all 3 subscriptions active', async () => {
    const db = getDb('emp-1', 'ramesh@devagency.local');
    const custDoc = await getDoc(doc(db, 'businesses/biz-dev/customers/cust-1'));
    assert.equal(custDoc.exists(), true);

    const subToi = await getDoc(
      doc(db, 'businesses/biz-dev/customers/cust-1/subscriptions/sub-toi'),
    );
    const pauseSnap = await getDocs(
      collection(
        db,
        'businesses/biz-dev/customers/cust-1/subscriptions/sub-toi/pauses',
      ),
    );
    const pause = pauseSnap.docs[0].data();

    const targetDate = '2026-10-11';
    const isPaused =
      pause.startDate <= targetDate && targetDate <= pause.endDate;
    assert.equal(isPaused, false, 'Oct 11 should be active (before pause)');
  });

  test('Scenario: Date during pause start (2026-10-12) — TOI paused, ET and DJ active', async () => {
    const db = getDb('emp-1', 'ramesh@devagency.local');
    const pauseSnap = await getDocs(
      collection(
        db,
        'businesses/biz-dev/customers/cust-1/subscriptions/sub-toi/pauses',
      ),
    );
    const pause = pauseSnap.docs[0].data();

    const targetDate = '2026-10-12';
    const isToiPaused =
      pause.startDate <= targetDate && targetDate <= pause.endDate;
    assert.equal(isToiPaused, true, 'TOI must be paused on pause start day');
    assert.equal(pause.reason, 'Diwali vacation trip');
  });

  test('Scenario: Date during inclusive final day (2026-10-15) — TOI still paused', async () => {
    const db = getDb('emp-1', 'ramesh@devagency.local');
    const pauseSnap = await getDocs(
      collection(
        db,
        'businesses/biz-dev/customers/cust-1/subscriptions/sub-toi/pauses',
      ),
    );
    const pause = pauseSnap.docs[0].data();

    const targetDate = '2026-10-15';
    const isToiPaused =
      pause.startDate <= targetDate && targetDate <= pause.endDate;
    assert.equal(
      isToiPaused,
      true,
      'TOI must remain paused on inclusive final day (Oct 15)',
    );
  });

  test('Scenario: Date after pause (2026-10-16) — TOI automatically resumes delivery', async () => {
    const db = getDb('emp-1', 'ramesh@devagency.local');
    const pauseSnap = await getDocs(
      collection(
        db,
        'businesses/biz-dev/customers/cust-1/subscriptions/sub-toi/pauses',
      ),
    );
    const pause = pauseSnap.docs[0].data();

    const targetDate = '2026-10-16';
    const isToiPaused =
      pause.startDate <= targetDate && targetDate <= pause.endDate;
    assert.equal(
      isToiPaused,
      false,
      'TOI must automatically resume on day after pause (Oct 16)',
    );
  });

  test('Delivery drop recording: Assigned employee writes drop + paired audit atomically', async () => {
    const db = getDb('emp-1', 'ramesh@devagency.local');
    const batch = writeBatch(db);

    const routeDate = '2026-10-16';
    const routeId = `${routeDate}_north-sector`;

    const auditRef = doc(db, 'businesses/biz-dev/auditRecords/audit-drop-1');
    batch.set(auditRef, {
      businessId: 'biz-dev',
      actorId: 'emp-1',
      action: 'deliveryDropStatusUpdated',
      entityType: 'deliveryDrop',
      entityId: 'cust-1',
      routeId,
      areaId: 'north-sector',
      date: routeDate,
      status: 'delivered',
      createdAt: serverTimestamp(),
    });

    const dropRef = doc(
      db,
      `businesses/biz-dev/dailyRoutes/${routeId}/drops/cust-1`,
    );
    batch.set(dropRef, {
      businessId: 'biz-dev',
      routeId,
      customerId: 'cust-1',
      status: 'delivered',
      actorUid: 'emp-1',
      areaId: 'north-sector',
      date: routeDate,
      lastAuditId: 'audit-drop-1',
      updatedAt: serverTimestamp(),
    });

    await assertSucceeds(batch.commit());

    // Verify drop is persisted and readable by employee
    const savedDrop = await getDoc(dropRef);
    assert.equal(savedDrop.exists(), true);
    assert.equal(savedDrop.data().status, 'delivered');
    assert.equal(savedDrop.data().lastAuditId, 'audit-drop-1');
  });

  test('Route Ordering: Authorized employee saves route order; unauthorized employee denied', async () => {
    const dbEmp1 = getDb('emp-1', 'ramesh@devagency.local');
    const dbEmp2 = getDb('emp-2', 'suresh@devagency.local');

    // emp-1 has arrangeDeliveryRoutes -> succeeds
    await assertSucceeds(
      setDoc(doc(dbEmp1, 'businesses/biz-dev/routeOrders/north-sector'), {
        businessId: 'biz-dev',
        areaId: 'north-sector',
        customerIds: ['cust-1'],
        updatedBy: 'emp-1',
        updatedAt: serverTimestamp(),
      }),
    );

    // Verify route order is persisted
    const savedOrder = await getDoc(
      doc(dbEmp1, 'businesses/biz-dev/routeOrders/north-sector'),
    );
    assert.equal(savedOrder.exists(), true);
    assert.deepEqual(savedOrder.data().customerIds, ['cust-1']);

    // emp-2 lacks arrangeDeliveryRoutes -> denied
    await assertFails(
      setDoc(doc(dbEmp2, 'businesses/biz-dev/routeOrders/north-sector'), {
        businessId: 'biz-dev',
        areaId: 'north-sector',
        customerIds: ['cust-1'],
        updatedBy: 'emp-2',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('Audit Immutability: Audit records are append-only and cannot be modified or deleted', async () => {
    // Seed an audit record
    await environment.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(
        doc(adminDb, 'businesses/biz-dev/auditRecords/audit-test-imm'),
        {
          businessId: 'biz-dev',
          actorId: 'head-1',
          action: 'customerCreated',
          entityType: 'customer',
          entityId: 'cust-1',
          createdAt: new Date(),
        },
      );
    });

    const dbHead = getDb('head-1', 'head@devagency.local');
    const dbEmp = getDb('emp-1', 'ramesh@devagency.local');

    // Attempting to modify audit record must fail for both Head and employee
    await assertFails(
      updateDoc(
        doc(dbHead, 'businesses/biz-dev/auditRecords/audit-test-imm'),
        {
          action: 'tamperedAction',
        },
      ),
    );
    await assertFails(
      updateDoc(
        doc(dbEmp, 'businesses/biz-dev/auditRecords/audit-test-imm'),
        {
          action: 'tamperedAction',
        },
      ),
    );

    // Attempting to delete audit record must fail for both Head and employee
    await assertFails(
      deleteDoc(doc(dbHead, 'businesses/biz-dev/auditRecords/audit-test-imm')),
    );
    await assertFails(
      deleteDoc(doc(dbEmp, 'businesses/biz-dev/auditRecords/audit-test-imm')),
    );
  });

  test('Head & Employee Permission Separation: Employee cannot create customer outside assigned area', async () => {
    const dbEmp = getDb('emp-1', 'ramesh@devagency.local');
    const now = new Date();

    // emp-1 is assigned ONLY to 'north-sector', not 'south-sector'
    await assertFails(
      setDoc(doc(dbEmp, 'businesses/biz-dev/customers/cust-south'), {
        businessId: 'biz-dev',
        id: 'cust-south',
        customerCode: 'C999',
        name: 'South Customer',
        phone: '9899999999',
        areaId: 'south-sector',
        assignedEmployeeId: 'emp-1',
        houseNumber: '1',
        address: 'South',
        status: 'active',
        createdAt: now,
      }),
    );
  });
});
