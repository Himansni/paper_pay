import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const data = JSON.parse(readFileSync('firestore.indexes.json', 'utf8'));

test('production index manifest is stable, unique, and complete', () => {
  assert.equal(data.indexes.length, 69);
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
