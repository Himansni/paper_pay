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
      permissions: ['addCustomers', 'editAssignedCustomers'],
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

test('test environment initialized', () => {
  assert.ok(environment);
});
