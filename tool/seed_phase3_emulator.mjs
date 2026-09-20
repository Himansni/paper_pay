const projectId = 'demo-paper-route';
const authBase = 'http://127.0.0.1:9099';
const firestoreBase =
  `http://127.0.0.1:8080/v1/projects/${projectId}/databases/(default)/documents`;

async function request(url, options = {}) {
  if (!url.startsWith('http://127.0.0.1:')) {
    throw new Error('Phase 3 seed requests must target a local emulator.');
  }
  const response = await fetch(url, options);
  if (!response.ok) {
    throw new Error(`${response.status} ${await response.text()}`);
  }
  return response.status === 204 ? null : response.json();
}

const jsonHeaders = { 'content-type': 'application/json' };
const ownerHeaders = {
  ...jsonHeaders,
  authorization: 'Bearer owner',
};

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
  email: 'phase3-head@example.test',
  password: 'Phase3-Smoke-2026!',
  displayName: 'Phase 3 Head',
});
const employee = await createVerifiedUser({
  email: 'phase3-employee@example.test',
  password: 'Phase3-Employee-2026!',
  displayName: 'Smoke Employee',
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
await writeDocument('businesses/business-smoke', {
  businessId: 'business-smoke',
  ownerId: head.localId,
  name: 'Phase 3 Smoke News Agency',
  phone: '9000000000',
  address: 'Emulator only',
  status: 'active',
  createdAt: timestamp,
  updatedAt: timestamp,
});
await writeDocument(`userProfiles/${head.localId}`, {
  uid: head.localId,
  email: 'phase3-head@example.test',
  displayName: 'Phase 3 Head',
  phone: '',
  businessId: 'business-smoke',
  role: 'head',
  status: 'active',
  permissions: [],
  acceptedInviteId: '',
  createdAt: timestamp,
  updatedAt: timestamp,
});
await writeDocument(`businesses/business-smoke/members/${head.localId}`, {
  businessId: 'business-smoke',
  uid: head.localId,
  email: 'phase3-head@example.test',
  displayName: 'Phase 3 Head',
  phone: '',
  role: 'head',
  status: 'active',
  permissions: [],
  areaIds: [],
  notes: '',
  createdAt: timestamp,
  updatedAt: timestamp,
});
await writeDocument(`userProfiles/${employee.localId}`, {
  uid: employee.localId,
  email: 'phase3-employee@example.test',
  displayName: 'Smoke Employee',
  phone: '9111111111',
  businessId: 'business-smoke',
  role: 'employee',
  status: 'active',
  permissions: ['addCustomers', 'editAssignedCustomers'],
  acceptedInviteId: 'emulator-seed',
  createdAt: timestamp,
  updatedAt: timestamp,
});
await writeDocument(
  `businesses/business-smoke/members/${employee.localId}`,
  {
    businessId: 'business-smoke',
    uid: employee.localId,
    email: 'phase3-employee@example.test',
    displayName: 'Smoke Employee',
    phone: '9111111111',
    role: 'employee',
    status: 'active',
    permissions: ['addCustomers', 'editAssignedCustomers'],
    areaIds: ['central'],
    notes: 'Synthetic emulator member',
    createdAt: timestamp,
    updatedAt: timestamp,
  },
);
await writeDocument('businesses/business-smoke/areas/central', {
  businessId: 'business-smoke',
  name: 'Central Route',
  status: 'active',
  assignedEmployeeIds: [employee.localId],
  createdBy: head.localId,
  updatedBy: head.localId,
  createdAt: timestamp,
  updatedAt: timestamp,
});

process.stdout.write(
  `Seeded synthetic Head ${head.localId} and employee ${employee.localId}\n`,
);
