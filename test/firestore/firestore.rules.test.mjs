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

const projectId = 'demo-paper-route';
let environment;

const auth = (uid, email) =>
  environment.authenticatedContext(uid, {
    email,
    email_verified: true,
  }).firestore();

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
      areaIds: [],
    });
    await setDoc(doc(db, 'businesses/business-a/members/employee-c'), {
      businessId: 'business-a',
      uid: 'employee-c',
      email: 'employee-c@example.com',
      displayName: 'Employee C',
      role: 'employee',
      status: 'active',
      permissions: [],
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
    await setDoc(doc(db, 'businesses/business-a/areas/east'), {
      businessId: 'business-a',
      name: 'East',
      status: 'active',
      assignedEmployeeIds: ['employee-c'],
    });
    await setDoc(doc(db, 'businesses/business-a/newspapers/times'), {
      businessId: 'business-a',
      name: 'Times',
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
    batch.update(doc(headDb, 'businesses/business-a/customers/assigned'), {
      assignedEmployeeId: 'employee-c',
      areaId: 'east',
      updatedAt: serverTimestamp(),
    });
    batch.set(
      doc(headDb, 'businesses/business-a/auditRecords/customer-transfer'),
      {
        businessId: 'business-a',
        actorId: 'head-a',
        action: 'customerAssignmentUpdated',
        entityType: 'customer',
        entityId: 'assigned',
        previousEmployeeId: 'employee-a',
        employeeId: 'employee-c',
        previousAreaId: '',
        areaId: 'east',
        createdAt: serverTimestamp(),
      },
    );
    await assertSucceeds(batch.commit());

    await assertFails(
      getDoc(
        doc(
          auth('employee-a', 'employee-a@example.com'),
          'businesses/business-a/customers/assigned',
        ),
      ),
    );
    await assertSucceeds(
      getDoc(
        doc(
          auth('employee-c', 'employee-c@example.com'),
          'businesses/business-a/customers/assigned',
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

test('test environment initialized', () => {
  assert.ok(environment);
});
