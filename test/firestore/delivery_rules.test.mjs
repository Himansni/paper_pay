import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
} from 'firebase/firestore';

const projectId = 'demo-paper-route-delivery';
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

    // Business B (for cross-tenant tests)
    await setDoc(doc(db, 'businesses/business-b'), {
      name: 'Agency B',
      status: 'active',
      createdAt: new Date(),
    });

    // Members in Business A
    // Head A
    await setDoc(doc(db, 'businesses/business-a/members/head-a'), {
      businessId: 'business-a',
      uid: 'head-a',
      role: 'head',
      status: 'active',
      email: 'head-a@test.local',
      displayName: 'Head A',
      areaIds: ['east', 'west'],
      createdAt: new Date(),
    });

    // Employee East (assigned to east)
    await setDoc(doc(db, 'businesses/business-a/members/emp-east'), {
      businessId: 'business-a',
      uid: 'emp-east',
      role: 'employee',
      status: 'active',
      email: 'emp-east@test.local',
      displayName: 'Employee East',
      areaIds: ['east'],
      createdAt: new Date(),
    });

    // Employee West (assigned to west)
    await setDoc(doc(db, 'businesses/business-a/members/emp-west'), {
      businessId: 'business-a',
      uid: 'emp-west',
      role: 'employee',
      status: 'active',
      email: 'emp-west@test.local',
      displayName: 'Employee West',
      areaIds: ['west'],
      createdAt: new Date(),
    });

    // Member in Business B
    await setDoc(doc(db, 'businesses/business-b/members/emp-b'), {
      businessId: 'business-b',
      uid: 'emp-b',
      role: 'employee',
      status: 'active',
      email: 'emp-b@test.local',
      displayName: 'Employee B',
      areaIds: ['east'],
      createdAt: new Date(),
    });

    // Areas in Business A
    await setDoc(doc(db, 'businesses/business-a/areas/east'), {
      businessId: 'business-a',
      name: 'East Zone',
      status: 'active',
    });
    await setDoc(doc(db, 'businesses/business-a/areas/west'), {
      businessId: 'business-a',
      name: 'West Zone',
      status: 'active',
    });
  });
};

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

describe('Phase 2A: Daily Route Delivery Persistence Security Rules', () => {
  const routeDate = '2026-09-23';
  const routeIdEast = `${routeDate}_east`;
  const routeIdWest = `${routeDate}_west`;
  const dropPathEast = (customerId) =>
    `businesses/business-a/dailyRoutes/${routeIdEast}/drops/${customerId}`;
  const dropPathWest = (customerId) =>
    `businesses/business-a/dailyRoutes/${routeIdWest}/drops/${customerId}`;

  test('1. Authorized employee writes and updates delivery drop in assigned area', async () => {
    const db = auth('emp-east', 'emp-east@test.local');

    // Mark Delivered
    await assertSucceeds(
      setDoc(doc(db, dropPathEast('cust-101')), {
        businessId: 'business-a',
        routeId: routeIdEast,
        date: routeDate,
        areaId: 'east',
        customerId: 'cust-101',
        status: 'delivered',
        actorUid: 'emp-east',
        updatedAt: serverTimestamp(),
      }),
    );

    // Controlled Undo -> status: 'pending'
    await assertSucceeds(
      setDoc(doc(db, dropPathEast('cust-101')), {
        businessId: 'business-a',
        routeId: routeIdEast,
        date: routeDate,
        areaId: 'east',
        customerId: 'cust-101',
        status: 'pending',
        actorUid: 'emp-east',
        updatedAt: serverTimestamp(),
      }),
    );

    // Report Exception -> status: 'exception' with reason
    await assertSucceeds(
      setDoc(doc(db, dropPathEast('cust-101')), {
        businessId: 'business-a',
        routeId: routeIdEast,
        date: routeDate,
        areaId: 'east',
        customerId: 'cust-101',
        status: 'exception',
        exceptionReason: 'House Locked / Gate Closed',
        actorUid: 'emp-east',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('2. Unauthorized employee cannot write or update drops in another area', async () => {
    // emp-west is NOT assigned to east
    const db = auth('emp-west', 'emp-west@test.local');

    await assertFails(
      setDoc(doc(db, dropPathEast('cust-101')), {
        businessId: 'business-a',
        routeId: routeIdEast,
        date: routeDate,
        areaId: 'east',
        customerId: 'cust-101',
        status: 'delivered',
        actorUid: 'emp-west',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('3. Cross-tenant access is strictly denied', async () => {
    // Member of Business B attempts to write or read in Business A
    const db = auth('emp-b', 'emp-b@test.local');

    await assertFails(
      setDoc(doc(db, dropPathEast('cust-101')), {
        businessId: 'business-a',
        routeId: routeIdEast,
        date: routeDate,
        areaId: 'east',
        customerId: 'cust-101',
        status: 'delivered',
        actorUid: 'emp-b',
        updatedAt: serverTimestamp(),
      }),
    );

    await assertFails(getDoc(doc(db, dropPathEast('cust-101'))));
  });

  test('4. Employee cannot forge another actor UID', async () => {
    const db = auth('emp-east', 'emp-east@test.local');

    // emp-east tries to set actorUid to head-a or emp-west
    await assertFails(
      setDoc(doc(db, dropPathEast('cust-101')), {
        businessId: 'business-a',
        routeId: routeIdEast,
        date: routeDate,
        areaId: 'east',
        customerId: 'cust-101',
        status: 'delivered',
        actorUid: 'head-a', // Forged!
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('5. Head can read agency delivery operations across all routes', async () => {
    // First, seed a drop with admin privileges
    await environment.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, dropPathEast('cust-101')), {
        businessId: 'business-a',
        routeId: routeIdEast,
        date: routeDate,
        areaId: 'east',
        customerId: 'cust-101',
        status: 'delivered',
        actorUid: 'emp-east',
        updatedAt: new Date(),
      });
      await setDoc(doc(adminDb, dropPathWest('cust-201')), {
        businessId: 'business-a',
        routeId: routeIdWest,
        date: routeDate,
        areaId: 'west',
        customerId: 'cust-201',
        status: 'exception',
        exceptionReason: 'Rain',
        actorUid: 'emp-west',
        updatedAt: new Date(),
      });
    });

    const headDb = auth('head-a', 'head-a@test.local');
    await assertSucceeds(getDoc(doc(headDb, dropPathEast('cust-101'))));
    await assertSucceeds(getDoc(doc(headDb, dropPathWest('cust-201'))));
  });

  test('6. Anonymous and unauthenticated access is denied', async () => {
    const unauthDb = environment.unauthenticatedContext().firestore();

    await assertFails(getDoc(doc(unauthDb, dropPathEast('cust-101'))));
    await assertFails(
      setDoc(doc(unauthDb, dropPathEast('cust-101')), {
        businessId: 'business-a',
        routeId: routeIdEast,
        date: routeDate,
        areaId: 'east',
        customerId: 'cust-101',
        status: 'delivered',
        actorUid: 'anon',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('7. Delivery rules do not grant access to financial records', async () => {
    const db = auth('emp-east', 'emp-east@test.local');

    // Attempt to access unassigned customer financial bills/adjustments
    await assertFails(
      getDoc(doc(db, 'businesses/business-a/customers/unassigned/bills/2026-09')),
    );
  });
});
