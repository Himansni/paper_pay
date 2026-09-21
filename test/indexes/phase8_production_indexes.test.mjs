// BEGINNER NOTE:
// [Cloud Firestore Composite Indexes & Manifest Validation]
// Cloud Firestore automatically maintains single-field indexes for basic queries.
// However, queries that combine:
// 1. Multiple equality/range filters across distinct fields,
// 2. CollectionGroup queries (e.g. `collectionGroup('payments')`), or
// 3. Range filters combined with `orderBy` sorting,
// require pre-computed Composite Indexes defined in `firestore.indexes.json`.
// If a Flutter query executes without a matching composite index deployed in Firestore,
// the server rejects the request with a `failed-precondition` exception.
// This test validates that `firestore.indexes.json` contains all required production
// indexes without duplicates or missing field definitions.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const data = JSON.parse(readFileSync('firestore.indexes.json', 'utf8'));

test('production index manifest is stable, unique, and complete', () => {
  assert.equal(data.indexes.length, 69);
  const keys = data.indexes.map((index) => JSON.stringify(index));
  assert.equal(new Set(keys).size, keys.length, 'duplicate composite index');
  assert.ok(Array.isArray(data.fieldOverrides));
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
