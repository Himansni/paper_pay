import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const data = JSON.parse(readFileSync('firestore.indexes.json', 'utf8'));

test('production index manifest is stable, unique, and complete', () => {
  assert.equal(data.indexes.length, 86);
  const keys = data.indexes.map((index) => JSON.stringify(index));
  assert.equal(new Set(keys).size, keys.length, 'duplicate composite index');
  assert.ok(Array.isArray(data.fieldOverrides));
  assert.equal(data.fieldOverrides.length, 2);
  const overrides = new Set(
    data.fieldOverrides.map(
      (override) =>
        `${override.collectionGroup}.${override.fieldPath}:${JSON.stringify(override.indexes)}`,
    ),
  );
  assert.ok(
    overrides.has(
      'members.uid:[{"order":"ASCENDING","queryScope":"COLLECTION_GROUP"}]',
    ),
  );
  assert.ok(
    overrides.has(
      'invitations.email:[{"order":"ASCENDING","queryScope":"COLLECTION_GROUP"}]',
    ),
  );
});

test('collections report has required collectionGroup payment indexes with __name__ DESC', () => {
  const expectedPaymentIndexes = [
    // Base collections report
    [
      ['businessId', 'ASCENDING'],
      ['confirmedAt', 'DESCENDING'],
      ['__name__', 'DESCENDING'],
    ],
    // Employee + date range
    [
      ['businessId', 'ASCENDING'],
      ['collectorUid', 'ASCENDING'],
      ['confirmedAt', 'DESCENDING'],
      ['__name__', 'DESCENDING'],
    ],
    // Area + date range
    [
      ['businessId', 'ASCENDING'],
      ['areaId', 'ASCENDING'],
      ['confirmedAt', 'DESCENDING'],
      ['__name__', 'DESCENDING'],
    ],
    // Customer + date range
    [
      ['businessId', 'ASCENDING'],
      ['customerId', 'ASCENDING'],
      ['confirmedAt', 'DESCENDING'],
      ['__name__', 'DESCENDING'],
    ],
    // Method + date range
    [
      ['businessId', 'ASCENDING'],
      ['method', 'ASCENDING'],
      ['confirmedAt', 'DESCENDING'],
      ['__name__', 'DESCENDING'],
    ],
    // Employee + method + date range
    [
      ['businessId', 'ASCENDING'],
      ['collectorUid', 'ASCENDING'],
      ['method', 'ASCENDING'],
      ['confirmedAt', 'DESCENDING'],
      ['__name__', 'DESCENDING'],
    ],
    // Area + method + date range
    [
      ['businessId', 'ASCENDING'],
      ['areaId', 'ASCENDING'],
      ['method', 'ASCENDING'],
      ['confirmedAt', 'DESCENDING'],
      ['__name__', 'DESCENDING'],
    ],
    // Customer + method + date range
    [
      ['businessId', 'ASCENDING'],
      ['customerId', 'ASCENDING'],
      ['method', 'ASCENDING'],
      ['confirmedAt', 'DESCENDING'],
      ['__name__', 'DESCENDING'],
    ],
  ];

  for (const expectedFields of expectedPaymentIndexes) {
    const matches = data.indexes.filter(
      (index) =>
        index.collectionGroup === 'payments' &&
        index.queryScope === 'COLLECTION_GROUP' &&
        JSON.stringify(
          index.fields.map((f) => [f.fieldPath, f.order]),
        ) === JSON.stringify(expectedFields),
    );
    assert.equal(
      matches.length,
      1,
      `Missing required collectionGroup payments index: ${JSON.stringify(expectedFields)}`,
    );
  }
});

test('employee outstanding aggregate keeps the six-field index', () => {
  const fields = [
    ['areaId', 'ASCENDING'],
    ['assignedEmployeeId', 'ASCENDING'],
    ['businessId', 'ASCENDING'],
    ['customerStatus', 'ASCENDING'],
    ['stateId', 'ASCENDING'],
    ['outstandingPaise', 'ASCENDING'],
  ];
  const matches = data.indexes.filter(
    (index) =>
      index.collectionGroup === 'collectionState' &&
      index.queryScope === 'COLLECTION_GROUP' &&
      JSON.stringify(
        index.fields.map((field) => [field.fieldPath, field.order]),
      ) === JSON.stringify(fields),
  );
  assert.equal(matches.length, 1);
});
