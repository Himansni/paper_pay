import assert from 'node:assert/strict';
import { performance } from 'node:perf_hooks';

const projectId = process.env.GCLOUD_PROJECT || 'demo-paper-route';
const host = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
assert.equal(projectId, 'demo-paper-route', 'scale profile is emulator-only');
assert.match(host, /^(127\.0\.0\.1|localhost):\d+$/);

const root = `http://${host}/v1/projects/${projectId}/databases/(default)`;
const documentRoot = `${root}/documents`;
const resourceRoot = `projects/${projectId}/databases/(default)/documents`;
const headers = {
  authorization: 'Bearer owner',
  'content-type': 'application/json',
};

const value = (input) => {
  if (input === null) return { nullValue: null };
  if (typeof input === 'boolean') return { booleanValue: input };
  if (typeof input === 'number') return { integerValue: String(input) };
  if (input instanceof Date) return { timestampValue: input.toISOString() };
  return { stringValue: String(input) };
};
const fields = (data) =>
  Object.fromEntries(Object.entries(data).map(([key, item]) => [key, value(item)]));
const write = (path, data) => ({
  update: { name: `${resourceRoot}/${path}`, fields: fields(data) },
});

async function request(url, body) {
  assert.ok(url.startsWith(`http://${host}/`));
  const response = await fetch(url, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });
  const payload = await response.json();
  if (!response.ok) throw new Error(`${response.status}: ${JSON.stringify(payload)}`);
  return payload;
}

const now = new Date('2026-09-14T06:00:00.000Z');
const writes = [];
writes.push(
  write('businesses/business-scale', {
    businessId: 'business-scale',
    ownerId: 'head-scale',
    name: 'Phase 8 Scale Emulator',
    status: 'active',
    createdAt: now,
    updatedAt: now,
  }),
);
for (let area = 0; area < 40; area += 1) {
  const id = `A-${String(area).padStart(2, '0')}`;
  writes.push(
    write(`businesses/business-scale/areas/${id}`, {
      businessId: 'business-scale',
      name: `Scale Area ${area}`,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    }),
  );
}
for (let employee = 0; employee < 24; employee += 1) {
  const id = `E-${String(employee).padStart(2, '0')}`;
  writes.push(
    write(`businesses/business-scale/members/${id}`, {
      uid: id,
      businessId: 'business-scale',
      role: 'employee',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    }),
  );
}
for (let index = 0; index < 1200; index += 1) {
  const id = `C-${String(index).padStart(5, '0')}`;
  const areaId = `A-${String(index % 40).padStart(2, '0')}`;
  const employeeId = `E-${String(index % 24).padStart(2, '0')}`;
  const status = index < 1100 ? 'active' : 'archived';
  writes.push(
    write(`businesses/business-scale/customers/${id}`, {
      businessId: 'business-scale',
      customerCode: id,
      name: `Synthetic Scale Customer ${String(index).padStart(5, '0')}`,
      searchName: `synthetic scale customer ${String(index).padStart(5, '0')}`,
      status,
      areaId,
      assignedEmployeeId: employeeId,
      openingBalancePaise: 0,
      createdAt: now,
      updatedAt: now,
    }),
    write(`businesses/business-scale/customers/${id}/subscriptions/S-1`, {
      businessId: 'business-scale',
      customerId: id,
      newspaperId: 'N-SCALE',
      status: 'active',
      currentVersion: 1,
      startDate: '2026-01-01',
      createdAt: now,
      updatedAt: now,
    }),
    write(`businesses/business-scale/customers/${id}/bills/2026-09`, {
      businessId: 'business-scale',
      customerId: id,
      customerStatus: status,
      billingMonth: '2026-09',
      status: 'finalized',
      currentChargesPaise: 30000 + index,
      totalDuePaise: 30000 + index,
      lineCount: 30,
      finalizedAt: now,
    }),
    write(`businesses/business-scale/customers/${id}/collectionState/current`, {
      businessId: 'business-scale',
      stateId: 'current',
      customerId: id,
      customerStatus: status,
      areaId,
      assignedEmployeeId: employeeId,
      reportingStatus: index % 3 === 0 ? 'partiallyPaid' : 'unpaid',
      outstandingPaise: 30000 + index,
      revision: 1,
      updatedAt: now,
    }),
  );
  if (index < 600) {
    writes.push(
      write(`businesses/business-scale/customers/${id}/payments/P-1`, {
        businessId: 'business-scale',
        customerId: id,
        amountPaise: 500,
        status: 'confirmed',
        method: 'cash',
        confirmedAt: now,
      }),
    );
  }
  if (index < 60) {
    writes.push(
      write(`businesses/business-scale/customers/${id}/reversals/R-1`, {
        businessId: 'business-scale',
        customerId: id,
        paymentId: 'P-1',
        amountPaise: 100,
        createdAt: now,
      }),
    );
  }
}

const seedStart = performance.now();
for (let offset = 0; offset < writes.length; offset += 400) {
  await request(`${root}/documents:commit`, { writes: writes.slice(offset, offset + 400) });
}
const seedMs = performance.now() - seedStart;

const field = (fieldPath) => ({ fieldPath });
const equals = (fieldPath, stringValue) => ({
  fieldFilter: { field: field(fieldPath), op: 'EQUAL', value: { stringValue } },
});
const and = (...filters) => ({ compositeFilter: { op: 'AND', filters } });
const collection = (collectionId, allDescendants = false) => ({
  from: [{ collectionId, allDescendants }],
});

async function timed(name, action, maximumMs = 5000) {
  const started = performance.now();
  const result = await action();
  const elapsed = performance.now() - started;
  assert.ok(elapsed < maximumMs, `${name} exceeded ${maximumMs}ms: ${elapsed.toFixed(1)}ms`);
  return { name, elapsed, result };
}

const parent = `${resourceRoot}/businesses/business-scale`;
const customersQuery = {
  ...collection('customers'),
  where: and(equals('businessId', 'business-scale'), equals('status', 'active')),
  orderBy: [
    { field: field('searchName'), direction: 'ASCENDING' },
    { field: field('__name__'), direction: 'ASCENDING' },
  ],
  limit: 51,
};
const firstPage = await timed('customer page 1', () =>
  request(`${root}/documents/businesses/business-scale:runQuery`, {
    structuredQuery: customersQuery,
  }),
);
const firstDocuments = firstPage.result.filter((row) => row.document);
assert.equal(firstDocuments.length, 51);
const last = firstDocuments[49].document;
const secondPage = await timed('customer page 2', () =>
  request(`${root}/documents/businesses/business-scale:runQuery`, {
    structuredQuery: {
      ...customersQuery,
      startAt: {
        before: false,
        values: [last.fields.searchName, { referenceValue: last.name }],
      },
    },
  }),
);
assert.equal(secondPage.result.filter((row) => row.document).length, 51);

async function aggregate(name, query, aggregations) {
  return timed(name, () =>
    request(`${documentRoot}:runAggregationQuery`, {
      structuredAggregationQuery: { structuredQuery: query, aggregations },
    }),
  );
}
const count = { alias: 'count', count: {} };
const sum = (fieldPath) => ({ alias: 'sum', sum: { field: field(fieldPath) } });

const activeCustomers = await aggregate(
  'dashboard active customer count',
  {
    ...collection('customers', true),
    where: and(equals('businessId', 'business-scale'), equals('status', 'active')),
  },
  [count],
);
const outstanding = await aggregate(
  'outstanding aggregate',
  {
    ...collection('collectionState', true),
    where: and(
      equals('businessId', 'business-scale'),
      equals('stateId', 'current'),
    ),
  },
  [count, sum('outstandingPaise')],
);
const employeeOutstanding = await aggregate(
  'employee outstanding aggregate',
  {
    ...collection('collectionState', true),
    where: and(
      equals('businessId', 'business-scale'),
      equals('stateId', 'current'),
      equals('customerStatus', 'active'),
      equals('assignedEmployeeId', 'E-00'),
      equals('areaId', 'A-00'),
    ),
  },
  [sum('outstandingPaise')],
);

const aggregateFields = (profile) =>
  profile.result.find((row) => row.result)?.result.aggregateFields ?? {};
assert.equal(aggregateFields(activeCustomers).count.integerValue, '1100');
assert.equal(aggregateFields(outstanding).count.integerValue, '1200');
assert.ok(BigInt(aggregateFields(outstanding).sum.integerValue) > 0n);
assert.ok(BigInt(aggregateFields(employeeOutstanding).sum.integerValue) > 0n);

const results = [firstPage, secondPage, activeCustomers, outstanding, employeeOutstanding];
process.stdout.write(
  `${JSON.stringify({
    documents: writes.length,
    customers: 1200,
    activeCustomers: 1100,
    subscriptions: 1200,
    bills: 1200,
    payments: 600,
    reversals: 60,
    seedMs: Number(seedMs.toFixed(1)),
    queries: Object.fromEntries(
      results.map((item) => [item.name, Number(item.elapsed.toFixed(1))]),
    ),
  }, null, 2)}\n`,
);
