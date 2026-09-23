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
      permissions: [],
      createdAt: new Date(),
    });

    // Employee East (assigned to east, has arrangeDeliveryRoutes permission)
    await setDoc(doc(db, 'businesses/business-a/members/emp-east'), {
      businessId: 'business-a',
      uid: 'emp-east',
      role: 'employee',
      status: 'active',
      email: 'emp-east@test.local',
      displayName: 'Employee East',
      areaIds: ['east'],
      permissions: ['arrangeDeliveryRoutes'],
      createdAt: new Date(),
    });

    // Employee West (assigned to west, NO arrangeDeliveryRoutes permission)
    await setDoc(doc(db, 'businesses/business-a/members/emp-west'), {
      businessId: 'business-a',
      uid: 'emp-west',
      role: 'employee',
      status: 'active',
      email: 'emp-west@test.local',
      displayName: 'Employee West',
      areaIds: ['west'],
      permissions: [],
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
      permissions: ['arrangeDeliveryRoutes'],
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

describe('Phase 2A & 2D: Delivery Persistence, Transition Audit & Route Ordering', () => {
  const routeDate = '2026-09-23';
  const routeIdEast = `${routeDate}_east`;
  const routeIdWest = `${routeDate}_west`;
  const dropPathEast = (customerId) =>
    `businesses/business-a/dailyRoutes/${routeIdEast}/drops/${customerId}`;
  const dropPathWest = (customerId) =>
    `businesses/business-a/dailyRoutes/${routeIdWest}/drops/${customerId}`;
  const auditPath = (auditId) =>
    `businesses/business-a/auditRecords/${auditId}`;
  const routeOrderPath = (areaId) =>
    `businesses/business-a/routeOrders/${areaId}`;

  test('1. Authorized employee writes and updates delivery drop with paired audit preserving transition history', async () => {
    const db = auth('emp-east', 'emp-east@test.local');

    // Transition 1: Mark Delivered with paired audit
    const batch1 = writeBatch(db);
    batch1.set(doc(db, auditPath('audit-del-1')), {
      businessId: 'business-a',
      actorId: 'emp-east',
      action: 'deliveryDropStatusUpdated',
      entityType: 'deliveryDrop',
      entityId: 'cust-101',
      routeId: routeIdEast,
      areaId: 'east',
      date: routeDate,
      status: 'delivered',
      createdAt: serverTimestamp(),
    });
    batch1.set(doc(db, dropPathEast('cust-101')), {
      businessId: 'business-a',
      routeId: routeIdEast,
      date: routeDate,
      areaId: 'east',
      customerId: 'cust-101',
      status: 'delivered',
      actorUid: 'emp-east',
      updatedAt: serverTimestamp(),
      lastAuditId: 'audit-del-1',
    });
    await assertSucceeds(batch1.commit());

    // Transition 2: Controlled Undo -> status: 'pending' with new paired audit
    const batch2 = writeBatch(db);
    batch2.set(doc(db, auditPath('audit-del-2')), {
      businessId: 'business-a',
      actorId: 'emp-east',
      action: 'deliveryDropStatusUpdated',
      entityType: 'deliveryDrop',
      entityId: 'cust-101',
      routeId: routeIdEast,
      areaId: 'east',
      date: routeDate,
      status: 'pending',
      createdAt: serverTimestamp(),
    });
    batch2.set(doc(db, dropPathEast('cust-101')), {
      businessId: 'business-a',
      routeId: routeIdEast,
      date: routeDate,
      areaId: 'east',
      customerId: 'cust-101',
      status: 'pending',
      actorUid: 'emp-east',
      updatedAt: serverTimestamp(),
      lastAuditId: 'audit-del-2',
    });
    await assertSucceeds(batch2.commit());

    // Transition 3: Report Exception -> status: 'exception' with new paired audit
    const batch3 = writeBatch(db);
    batch3.set(doc(db, auditPath('audit-del-3')), {
      businessId: 'business-a',
      actorId: 'emp-east',
      action: 'deliveryDropStatusUpdated',
      entityType: 'deliveryDrop',
      entityId: 'cust-101',
      routeId: routeIdEast,
      areaId: 'east',
      date: routeDate,
      status: 'exception',
      exceptionReason: 'House Locked / Gate Closed',
      createdAt: serverTimestamp(),
    });
    batch3.set(doc(db, dropPathEast('cust-101')), {
      businessId: 'business-a',
      routeId: routeIdEast,
      date: routeDate,
      areaId: 'east',
      customerId: 'cust-101',
      status: 'exception',
      exceptionReason: 'House Locked / Gate Closed',
      actorUid: 'emp-east',
      updatedAt: serverTimestamp(),
      lastAuditId: 'audit-del-3',
    });
    await assertSucceeds(batch3.commit());

    // Verify Head can read all 3 append-only audit records, confirming complete transition history
    const headDb = auth('head-a', 'head-a@test.local');
    const a1 = await getDoc(doc(headDb, auditPath('audit-del-1')));
    const a2 = await getDoc(doc(headDb, auditPath('audit-del-2')));
    const a3 = await getDoc(doc(headDb, auditPath('audit-del-3')));
    assert.equal(a1.exists(), true);
    assert.equal(a1.data().status, 'delivered');
    assert.equal(a2.exists(), true);
    assert.equal(a2.data().status, 'pending');
    assert.equal(a3.exists(), true);
    assert.equal(a3.data().status, 'exception');
  });

  test('2. Unpaired drop audit without matching drop update fails', async () => {
    const db = auth('emp-east', 'emp-east@test.local');

    // Standalone audit write without drop update must fail
    await assertFails(
      setDoc(doc(db, auditPath('audit-unpaired')), {
        businessId: 'business-a',
        actorId: 'emp-east',
        action: 'deliveryDropStatusUpdated',
        entityType: 'deliveryDrop',
        entityId: 'cust-101',
        routeId: routeIdEast,
        areaId: 'east',
        date: routeDate,
        status: 'delivered',
        createdAt: serverTimestamp(),
      }),
    );
  });

  test('3. Unauthorized employee cannot write or update drops or audits in another area', async () => {
    // emp-west is assigned to west, NOT east
    const db = auth('emp-west', 'emp-west@test.local');

    const batch = writeBatch(db);
    batch.set(doc(db, auditPath('audit-cross-area')), {
      businessId: 'business-a',
      actorId: 'emp-west',
      action: 'deliveryDropStatusUpdated',
      entityType: 'deliveryDrop',
      entityId: 'cust-101',
      routeId: routeIdEast,
      areaId: 'east',
      date: routeDate,
      status: 'delivered',
      createdAt: serverTimestamp(),
    });
    batch.set(doc(db, dropPathEast('cust-101')), {
      businessId: 'business-a',
      routeId: routeIdEast,
      date: routeDate,
      areaId: 'east',
      customerId: 'cust-101',
      status: 'delivered',
      actorUid: 'emp-west',
      updatedAt: serverTimestamp(),
      lastAuditId: 'audit-cross-area',
    });

    await assertFails(batch.commit());
  });

  test('4. Cross-tenant access is strictly denied for drops and audits', async () => {
    // Member of Business B attempts to write in Business A
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
    await assertFails(getDoc(doc(db, auditPath('audit-del-1'))));
  });

  test('5. Employee cannot forge another actor UID in drop or audit', async () => {
    const db = auth('emp-east', 'emp-east@test.local');

    const batch = writeBatch(db);
    batch.set(doc(db, auditPath('audit-forged')), {
      businessId: 'business-a',
      actorId: 'head-a', // Forged!
      action: 'deliveryDropStatusUpdated',
      entityType: 'deliveryDrop',
      entityId: 'cust-101',
      routeId: routeIdEast,
      areaId: 'east',
      date: routeDate,
      status: 'delivered',
      createdAt: serverTimestamp(),
    });
    batch.set(doc(db, dropPathEast('cust-101')), {
      businessId: 'business-a',
      routeId: routeIdEast,
      date: routeDate,
      areaId: 'east',
      customerId: 'cust-101',
      status: 'delivered',
      actorUid: 'head-a', // Forged!
      updatedAt: serverTimestamp(),
      lastAuditId: 'audit-forged',
    });

    await assertFails(batch.commit());
  });

  test('6. Delivery audit records cannot be modified or deleted (append-only)', async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, auditPath('audit-immutable')), {
        businessId: 'business-a',
        actorId: 'emp-east',
        action: 'deliveryDropStatusUpdated',
        entityType: 'deliveryDrop',
        entityId: 'cust-101',
        routeId: routeIdEast,
        areaId: 'east',
        date: routeDate,
        status: 'delivered',
        createdAt: new Date(),
      });
    });

    const empDb = auth('emp-east', 'emp-east@test.local');
    const headDb = auth('head-a', 'head-a@test.local');

    // Both employee and Head are forbidden from updating audit records
    await assertFails(
      updateDoc(doc(empDb, auditPath('audit-immutable')), {
        status: 'pending',
      }),
    );
    await assertFails(
      updateDoc(doc(headDb, auditPath('audit-immutable')), {
        status: 'pending',
      }),
    );

    // Both employee and Head are forbidden from deleting audit records
    await assertFails(deleteDoc(doc(empDb, auditPath('audit-immutable'))));
    await assertFails(deleteDoc(doc(headDb, auditPath('audit-immutable'))));
  });

  test('7. Head can read agency delivery operations and audits across all routes', async () => {
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

  test('8. Anonymous and unauthenticated access is denied', async () => {
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

  test('9. Delivery rules do not grant access to financial records', async () => {
    const db = auth('emp-east', 'emp-east@test.local');

    // Attempt to access unassigned customer financial bills/adjustments
    await assertFails(
      getDoc(doc(db, 'businesses/business-a/customers/unassigned/bills/2026-09')),
    );
  });

  // ==========================================
  // Phase 2D: Route Ordering Security Rules
  // ==========================================

  test('10. Head can create and update route order for any agency area', async () => {
    const headDb = auth('head-a', 'head-a@test.local');

    await assertSucceeds(
      setDoc(doc(headDb, routeOrderPath('east')), {
        businessId: 'business-a',
        areaId: 'east',
        customerIds: ['cust-1', 'cust-2', 'cust-3'],
        updatedBy: 'head-a',
        updatedAt: serverTimestamp(),
      }),
    );

    await assertSucceeds(
      setDoc(doc(headDb, routeOrderPath('west')), {
        businessId: 'business-a',
        areaId: 'west',
        customerIds: ['cust-10', 'cust-20'],
        updatedBy: 'head-a',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('11. Employee with arrangeDeliveryRoutes permission can update assigned area route order', async () => {
    const empDb = auth('emp-east', 'emp-east@test.local');

    // emp-east is assigned to 'east' and has 'arrangeDeliveryRoutes'
    await assertSucceeds(
      setDoc(doc(empDb, routeOrderPath('east')), {
        businessId: 'business-a',
        areaId: 'east',
        customerIds: ['cust-2', 'cust-1', 'cust-3'],
        updatedBy: 'emp-east',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('12. Employee without arrangeDeliveryRoutes permission cannot update route order', async () => {
    const empDb = auth('emp-west', 'emp-west@test.local');

    // emp-west is assigned to 'west' but DOES NOT have 'arrangeDeliveryRoutes'
    await assertFails(
      setDoc(doc(empDb, routeOrderPath('west')), {
        businessId: 'business-a',
        areaId: 'west',
        customerIds: ['cust-20', 'cust-10'],
        updatedBy: 'emp-west',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('13. Employee cannot update route order for unassigned area even with permission', async () => {
    const empDb = auth('emp-east', 'emp-east@test.local');

    // emp-east has 'arrangeDeliveryRoutes' but is NOT assigned to 'west'
    await assertFails(
      setDoc(doc(empDb, routeOrderPath('west')), {
        businessId: 'business-a',
        areaId: 'west',
        customerIds: ['cust-20', 'cust-10'],
        updatedBy: 'emp-east',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('14. Cross-tenant employee cannot read or write route order', async () => {
    const empDb = auth('emp-b', 'emp-b@test.local');

    await assertFails(
      setDoc(doc(empDb, routeOrderPath('east')), {
        businessId: 'business-a',
        areaId: 'east',
        customerIds: ['cust-1'],
        updatedBy: 'emp-b',
        updatedAt: serverTimestamp(),
      }),
    );

    await assertFails(getDoc(doc(empDb, routeOrderPath('east'))));
  });

  test('15. Route order documents cannot be deleted', async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, routeOrderPath('east')), {
        businessId: 'business-a',
        areaId: 'east',
        customerIds: ['cust-1', 'cust-2'],
        updatedBy: 'head-a',
        updatedAt: new Date(),
      });
    });

    const headDb = auth('head-a', 'head-a@test.local');
    const empDb = auth('emp-east', 'emp-east@test.local');

    await assertFails(deleteDoc(doc(empDb, routeOrderPath('east'))));
    await assertFails(deleteDoc(doc(headDb, routeOrderPath('east'))));
  });
});
