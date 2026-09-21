// BEGINNER NOTE:
// [Query-to-Index Static Alignment Test]
// Proves that the actual Dart query code in `firebase_reporting_repository.dart`
// stays strictly in sync with the index declarations in `firestore.indexes.json`.
// If an engineer modifies or refactors a Firestore query without updating the
// composite index manifest, this test fails immediately before deployment.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const indexes = JSON.parse(readFileSync('firestore.indexes.json', 'utf8'));
const repository = readFileSync(
  'lib/features/reports/data/firebase_reporting_repository.dart',
  'utf8',
);

const requiredFields = [
  { fieldPath: 'areaId', order: 'ASCENDING' },
  { fieldPath: 'assignedEmployeeId', order: 'ASCENDING' },
  { fieldPath: 'businessId', order: 'ASCENDING' },
  { fieldPath: 'customerStatus', order: 'ASCENDING' },
  { fieldPath: 'stateId', order: 'ASCENDING' },
  { fieldPath: 'outstandingPaise', order: 'ASCENDING' },
];

test('employee base outstanding query has its production composite index', () => {
  const methodStart = repository.indexOf(
    'Future<List<int>> _employeeBalanceValuesForAreas(',
  );
  const methodEnd = repository.indexOf(
    '\n  @override\n  Future<ReportPage> fetchReport(',
    methodStart,
  );
  assert.notEqual(methodStart, -1, 'employee balance query method is missing');
  assert.notEqual(methodEnd, -1, 'employee balance query boundary is missing');

  const method = repository.slice(methodStart, methodEnd);
  for (const fragment of [
    ".collectionGroup('collectionState')",
    ".where('businessId', isEqualTo: businessId)",
    ".where('stateId', isEqualTo: 'current')",
    ".where('assignedEmployeeId', isEqualTo: actor.uid)",
    ".where('customerStatus', isEqualTo: 'active')",
    ".where('areaId', whereIn: areaIds)",
  ]) {
    assert.ok(method.includes(fragment), `query no longer contains ${fragment}`);
  }

  const unfilteredSum = method.indexOf("_sum(balances, 'outstandingPaise')");
  const statusFilteredCount = method.indexOf(
    "balances.where('reportingStatus', isEqualTo: 'unpaid')",
  );
  assert.ok(unfilteredSum >= 0, 'base outstanding sum path is missing');
  assert.equal(
    requiredFields.at(-1)?.fieldPath,
    'outstandingPaise',
    'aggregate field must be part of the production composite index',
  );
  assert.ok(statusFilteredCount >= 0, 'status-filtered count path is missing');
  assert.ok(
    unfilteredSum < statusFilteredCount,
    'base outstanding sum must remain independently queryable before status filters',
  );

  const matches = indexes.indexes.filter(
    (index) =>
      index.collectionGroup === 'collectionState' &&
      index.queryScope === 'COLLECTION_GROUP' &&
      JSON.stringify(index.fields) === JSON.stringify(requiredFields),
  );
  assert.equal(matches.length, 1, 'expected exactly one matching composite index');
});
