const projectId = 'demo-paper-route';
const authBase = 'http://127.0.0.1:9099';
const firestoreBase =
  `http://127.0.0.1:8080/v1/projects/${projectId}/databases/(default)/documents`;

async function request(url, options = {}) {
  if (!url.startsWith('http://127.0.0.1:')) {
    throw new Error('Phase 4 seed requests must target a local emulator.');
  }
  const response = await fetch(url, options);
  if (!response.ok) {
    throw new Error(`${response.status} ${await response.text()}`);
  }
  return response.status === 204 ? null : response.json();
}

const jsonHeaders = { 'content-type': 'application/json' };
const ownerHeaders = { ...jsonHeaders, authorization: 'Bearer owner' };

await request(`${authBase}/emulator/v1/projects/${projectId}/accounts`, {
  method: 'DELETE',
});
await request(
  `http://127.0.0.1:8080/emulator/v1/projects/${projectId}/databases/(default)/documents`,
  { method: 'DELETE' },
);

async function createVerifiedUser({ email, password, displayName }) {
  const account = await request(
    `${authBase}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-api-key`,
    {
      method: 'POST',
      headers: jsonHeaders,
      body: JSON.stringify({ email, password, displayName, returnSecureToken: true }),
    },
  );
  await request(
    `${authBase}/identitytoolkit.googleapis.com/v1/accounts:update?key=demo-api-key`,
    {
      method: 'POST',
      headers: ownerHeaders,
      body: JSON.stringify({ localId: account.localId, emailVerified: true }),
    },
  );
  return account;
}

const head = await createVerifiedUser({
  email: 'phase4-head@example.test',
  password: 'Phase4-Smoke-2026!',
  displayName: 'Phase 4 Head',
});
const employee = await createVerifiedUser({
  email: 'phase4-employee@example.test',
  password: 'Phase4-Employee-2026!',
  displayName: 'Phase 4 Employee',
});

const value = (input) => {
  if (input === null) return { nullValue: null };
  if (typeof input === 'string') return { stringValue: input };
  if (typeof input === 'boolean') return { booleanValue: input };
  if (Number.isInteger(input)) return { integerValue: String(input) };
  if (input instanceof Date) return { timestampValue: input.toISOString() };
  if (Array.isArray(input)) {
    return { arrayValue: { values: input.map(value) } };
  }
  return {
    mapValue: {
      fields: Object.fromEntries(
        Object.entries(input).map(([key, item]) => [key, value(item)]),
      ),
    },
  };
};

async function writeDocument(path, data) {
  await request(`${firestoreBase}/${path}`, {
    method: 'PATCH',
    headers: ownerHeaders,
    body: JSON.stringify({
      fields: Object.fromEntries(
        Object.entries(data).map(([key, item]) => [key, value(item)]),
      ),
    }),
  });
}

const timestamp = new Date();
await writeDocument('businesses/business-phase4', {
  businessId: 'business-phase4',
  ownerId: head.localId,
  name: 'Phase 4 Emulator News Agency',
  phone: '9000000000',
  address: 'Emulator only',
  status: 'active',
  createdAt: timestamp,
  updatedAt: timestamp,
});

async function writeIdentity({ account, email, displayName, role, permissions, areaIds }) {
  const profile = {
    uid: account.localId,
    email,
    displayName,
    phone: '',
    businessId: 'business-phase4',
    role,
    status: 'active',
    permissions,
    acceptedInviteId: role === 'employee' ? 'emulator-seed' : '',
    createdAt: timestamp,
    updatedAt: timestamp,
  };
  await writeDocument(`userProfiles/${account.localId}`, profile);
  await writeDocument(
    `businesses/business-phase4/members/${account.localId}`,
    { ...profile, areaIds, notes: 'Synthetic Phase 4 emulator member' },
  );
}

await writeIdentity({
  account: head,
  email: 'phase4-head@example.test',
  displayName: 'Phase 4 Head',
  role: 'head',
  permissions: [],
  areaIds: [],
});
await writeIdentity({
  account: employee,
  email: 'phase4-employee@example.test',
  displayName: 'Phase 4 Employee',
  role: 'employee',
  permissions: ['manageAssignedSubscriptions', 'recordPayments'],
  areaIds: ['central'],
});

await writeDocument('businesses/business-phase4/areas/central', {
  businessId: 'business-phase4',
  name: 'Central Route',
  status: 'active',
  assignedEmployeeIds: [employee.localId],
  createdBy: head.localId,
  updatedBy: head.localId,
  createdAt: timestamp,
  updatedAt: timestamp,
});

const customer = ({ id, assignedEmployeeId }) => ({
  businessId: 'business-phase4',
  customerCode: id,
  name: `Synthetic ${id}`,
  searchName: `synthetic ${id.toLowerCase()}`,
  phone: '9999999999',
  searchPhone: '9999999999',
  alternatePhone: '',
  address: '1 Emulator Road',
  areaId: 'central',
  landmark: 'Local emulator',
  searchLandmark: 'local emulator',
  searchTokens: ['name:sy', 'phone:999', 'landmark:lo'],
  houseNumber: '1',
  buildingInfo: '',
  locationNotes: 'Synthetic test record',
  locationConsent: false,
  coordinates: null,
  assignedEmployeeId,
  status: 'active',
  subscriptionStatus: 'notConfigured',
  deliveryPreferences: { placement: 'doorstep' },
  billingPreferences: { cycle: 'monthly' },
  openingBalancePaise: 0,
  notes: 'Local Phase 4 emulator only',
  createdBy: head.localId,
  updatedBy: head.localId,
  lastAuditId: `seed-${id}`,
  createdAt: timestamp,
  updatedAt: timestamp,
});

await writeDocument(
  'businesses/business-phase4/customers/C-HEAD',
  customer({ id: 'C-HEAD', assignedEmployeeId: '' }),
);
await writeDocument(
  'businesses/business-phase4/customers/C-EMPLOYEE',
  customer({ id: 'C-EMPLOYEE', assignedEmployeeId: employee.localId }),
);

process.stdout.write(
  `Seeded Phase 4 synthetic Head ${head.localId} and employee ${employee.localId}\n`,
);
