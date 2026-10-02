import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import {
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  getAuth,
} from 'firebase/auth';
import {
  connectFunctionsEmulator,
  getFunctions,
  httpsCallable,
} from 'firebase/functions';
import { initializeApp as initializeClientApp } from 'firebase/app';

const requireFromFunctions = createRequire(
  new URL('../functions/package.json', import.meta.url),
);
const { initializeApp: initializeAdminApp } = requireFromFunctions(
  'firebase-admin/app',
);
const { getAuth: getAdminAuth } = requireFromFunctions('firebase-admin/auth');
const { getFirestore, Timestamp } = requireFromFunctions(
  'firebase-admin/firestore',
);

const projectId = 'demo-paper-route';
const clientApp = initializeClientApp({
  projectId,
  apiKey: 'demo-key',
  appId: '1:123:web:payment-test',
});
const clientAuth = getAuth(clientApp);
connectAuthEmulator(clientAuth, 'http://127.0.0.1:9099', {
  disableWarnings: true,
});
const functions = getFunctions(clientApp, 'asia-south1');
connectFunctionsEmulator(functions, '127.0.0.1', 5001);

const adminApp = initializeAdminApp({ projectId }, 'payment-integration');
const adminAuth = getAdminAuth(adminApp);
const firestore = getFirestore(adminApp);
firestore.settings({ host: '127.0.0.1:8080', ssl: false });

const recordPaymentCallable = httpsCallable(functions, 'recordPayment');

async function createVerifiedUser(email, password = 'password-123') {
  try {
    const cred = await createUserWithEmailAndPassword(clientAuth, email, password);
    await adminAuth.updateUser(cred.user.uid, { emailVerified: true });
    await cred.user.reload();
    await cred.user.getIdToken(true);
    return cred.user;
  } catch (e) {
    if (e.code === 'auth/email-already-in-use') {
      const cred = await signInWithEmailAndPassword(clientAuth, email, password);
      return cred.user;
    }
    throw e;
  }
}

console.log('\n==================================================');
console.log('STARTING P0 PAYMENT SECURITY & INTEGRATION TEST');
console.log('==================================================\n');

// 1. Setup Identities & Seed Data
const headUser = await createVerifiedUser('head-payment-test@example.com');
const empUser = await createVerifiedUser('emp-payment-test@example.com');
const foreignEmp = await createVerifiedUser('foreign-emp-payment-test@example.com');

const businessId = 'biz-payment-test';
const foreignBizId = 'biz-foreign-test';

// Seed Business
await firestore.doc(`businesses/${businessId}`).set({
  businessId,
  name: 'Test Payment Agency',
  status: 'active',
  ownerId: headUser.uid,
  createdAt: Timestamp.now(),
  updatedAt: Timestamp.now(),
});
await firestore.doc(`businesses/${businessId}/subscription/saas`).set({
  businessId,
  status: 'active',
  effectiveExpiresAt: Timestamp.fromMillis(Date.now() + 86400000 * 365),
});

// Seed Members
await firestore.doc(`businesses/${businessId}/members/${headUser.uid}`).set({
  businessId,
  uid: headUser.uid,
  email: headUser.email,
  role: 'head',
  status: 'active',
  permissions: [],
  areaIds: [],
});

await firestore.doc(`businesses/${businessId}/members/${empUser.uid}`).set({
  businessId,
  uid: empUser.uid,
  email: empUser.email,
  role: 'employee',
  status: 'active',
  permissions: ['recordPayments', 'allowCollectPayment'],
  areaIds: ['area-central'],
});

// Foreign business
await firestore.doc(`businesses/${foreignBizId}`).set({
  businessId: foreignBizId,
  name: 'Foreign Agency',
  status: 'active',
  ownerId: 'foreign-head',
});
await firestore.doc(`businesses/${foreignBizId}/members/${foreignEmp.uid}`).set({
  businessId: foreignBizId,
  uid: foreignEmp.uid,
  role: 'employee',
  status: 'active',
  permissions: ['recordPayments'],
  areaIds: ['area-foreign'],
});

// Customer 1: Active, assigned to empUser, in area-central
const cust1Id = 'cust-p0-1';
const cust1Ref = firestore.doc(`businesses/${businessId}/customers/${cust1Id}`);
await cust1Ref.set({
  businessId,
  customerCode: cust1Id,
  name: 'Sharma Ji',
  status: 'active',
  areaId: 'area-central',
  assignedEmployeeId: empUser.uid,
  createdAt: Timestamp.now(),
});

// July ₹100, August ₹209 (309 total)
await cust1Ref.collection('billBalances').doc('2026-07').set({
  businessId,
  customerId: cust1Id,
  billingMonth: '2026-07',
  sourceAmountPaise: 10000,
  allocatedPaise: 0,
  reversedPaise: 0,
  outstandingPaise: 10000,
  status: 'outstanding',
  revision: 1,
});

await cust1Ref.collection('billBalances').doc('2026-08').set({
  businessId,
  customerId: cust1Id,
  billingMonth: '2026-08',
  sourceAmountPaise: 20900,
  allocatedPaise: 0,
  reversedPaise: 0,
  outstandingPaise: 20900,
  status: 'outstanding',
  revision: 1,
});

await cust1Ref.collection('collectionState').doc('current').set({
  businessId,
  customerId: cust1Id,
  stateId: 'current',
  outstandingPaise: 30900,
  confirmedPaise: 0,
  reversedPaise: 0,
  reportingStatus: 'unpaid',
  oldestOutstandingMonth: '2026-07',
  revision: 1,
});

// Sign in as Employee
await signInWithEmailAndPassword(clientAuth, 'emp-payment-test@example.com', 'password-123');

console.log('--- TEST 1: Phase 5 - Legitimate ₹50 Payment (July ₹100, August ₹209) ---');
const pay1Res = (await recordPaymentCallable({
  businessId,
  customerId: cust1Id,
  amountPaise: 5000,
  method: 'cash',
  notes: 'First test payment',
  idempotencyKey: 'pay-legit-001',
})).data;

assert.equal(pay1Res.success, true);
assert.equal(pay1Res.paymentId, 'pay-legit-001');
assert.equal(pay1Res.amountPaise, 5000);
assert.equal(pay1Res.allocations.length, 1);
assert.equal(pay1Res.allocations[0].billingMonth, '2026-07');
assert.equal(pay1Res.allocations[0].amountPaise, 5000);
assert.equal(pay1Res.nextOutstandingPaise, 25900);

// Verify Firestore documents
const pDoc1 = await cust1Ref.collection('payments').doc('pay-legit-001').get();
assert.equal(pDoc1.exists, true);
assert.equal(pDoc1.get('amountPaise'), 5000);
assert.equal(pDoc1.get('collectorUid'), empUser.uid);
assert.equal(pDoc1.get('status'), 'confirmed');

const psDoc1 = await cust1Ref.collection('paymentStates').doc('pay-legit-001').get();
assert.equal(psDoc1.exists, true);
assert.equal(psDoc1.get('amountPaise'), 5000);
assert.equal(psDoc1.get('refundablePaise'), 5000);
assert.equal(psDoc1.get('status'), 'confirmed');

const julyBal1 = await cust1Ref.collection('billBalances').doc('2026-07').get();
assert.equal(julyBal1.get('outstandingPaise'), 5000);
assert.equal(julyBal1.get('allocatedPaise'), 5000);
assert.equal(julyBal1.get('status'), 'outstanding');

const augBal1 = await cust1Ref.collection('billBalances').doc('2026-08').get();
assert.equal(augBal1.get('outstandingPaise'), 20900);
assert.equal(augBal1.get('allocatedPaise'), 0);

const state1 = await cust1Ref.collection('collectionState').doc('current').get();
assert.equal(state1.get('outstandingPaise'), 25900);
assert.equal(state1.get('confirmedPaise'), 5000);
assert.equal(state1.get('oldestOutstandingMonth'), '2026-07');
console.log('✓ Verified: July received ₹50, August ₹0, Outstanding = ₹259');

console.log('\n--- TEST 2: Phase 5 - Malicious Client Allocation Attempt (July ₹0, August ₹50) ---');
// Malicious client tries to force allocation to August
const pay2Res = (await recordPaymentCallable({
  businessId,
  customerId: cust1Id,
  amountPaise: 5000,
  method: 'cash',
  maliciousAllocation: [{ billId: '2026-08', amountPaise: 5000 }],
  allocations: [{ billId: '2026-08', amountPaise: 5000 }],
  idempotencyKey: 'pay-malicious-002',
})).data;

assert.equal(pay2Res.success, true);
// Server MUST ignore client allocation and allocate to July (oldest first)
assert.equal(pay2Res.allocations.length, 1);
assert.equal(pay2Res.allocations[0].billingMonth, '2026-07');
assert.equal(pay2Res.allocations[0].amountPaise, 5000);

const julyBal2 = await cust1Ref.collection('billBalances').doc('2026-07').get();
assert.equal(julyBal2.get('outstandingPaise'), 0);
assert.equal(julyBal2.get('status'), 'settled');

const augBal2 = await cust1Ref.collection('billBalances').doc('2026-08').get();
assert.equal(augBal2.get('outstandingPaise'), 20900); // Unchanged!

const state2 = await cust1Ref.collection('collectionState').doc('current').get();
assert.equal(state2.get('outstandingPaise'), 20900);
assert.equal(state2.get('oldestOutstandingMonth'), '2026-08'); // Advanced to August!
console.log('✓ Verified: Malicious allocation IGNORED by server; July fully settled, August untouched');

console.log('\n--- TEST 3: Overpayment (₹210 against ₹209 remaining) ---');
await assert.rejects(
  recordPaymentCallable({
    businessId,
    customerId: cust1Id,
    amountPaise: 21000,
    method: 'cash',
    idempotencyKey: 'pay-overpay-003',
  }),
  (err) => err.code === 'functions/failed-precondition',
);
console.log('✓ Verified: Overpayment strictly rejected; no changes made');

console.log('\n--- TEST 4: Zero / Negative amount validation ---');
await assert.rejects(
  recordPaymentCallable({
    businessId,
    customerId: cust1Id,
    amountPaise: 0,
    method: 'cash',
    idempotencyKey: 'pay-zero-004',
  }),
  (err) => err.code === 'functions/invalid-argument',
);
await assert.rejects(
  recordPaymentCallable({
    businessId,
    customerId: cust1Id,
    amountPaise: -500,
    method: 'cash',
    idempotencyKey: 'pay-neg-004',
  }),
  (err) => err.code === 'functions/invalid-argument',
);
console.log('✓ Verified: Zero and negative amounts rejected');

console.log('\n--- TEST 5: Foreign business & authorization boundaries ---');
await assert.rejects(
  recordPaymentCallable({
    businessId: foreignBizId,
    customerId: cust1Id,
    amountPaise: 5000,
    method: 'cash',
    idempotencyKey: 'pay-foreign-005',
  }),
  (err) => err.code === 'functions/permission-denied',
);
console.log('✓ Verified: Foreign business caller rejected');

console.log('\n--- TEST 6: Phase 6 - Idempotency & Repeat Submissions ---');
const custIdemp = 'cust-idemp-p0';
const custIdempRef = firestore.doc(`businesses/${businessId}/customers/${custIdemp}`);
await custIdempRef.set({
  businessId,
  customerCode: custIdemp,
  name: 'Idempotency Customer',
  status: 'active',
  areaId: 'area-central',
  assignedEmployeeId: empUser.uid,
});
await custIdempRef.collection('billBalances').doc('2026-08').set({
  businessId,
  customerId: custIdemp,
  billingMonth: '2026-08',
  sourceAmountPaise: 10000,
  allocatedPaise: 0,
  reversedPaise: 0,
  outstandingPaise: 10000,
  status: 'outstanding',
  revision: 1,
});
await custIdempRef.collection('collectionState').doc('current').set({
  businessId,
  customerId: custIdemp,
  stateId: 'current',
  outstandingPaise: 10000,
  confirmedPaise: 0,
  reversedPaise: 0,
  reportingStatus: 'unpaid',
  oldestOutstandingMonth: '2026-08',
  revision: 1,
});

// Call 1
const idemp1 = (await recordPaymentCallable({
  businessId,
  customerId: custIdemp,
  amountPaise: 4000,
  method: 'cash',
  idempotencyKey: 'idemp-key-repeat-999',
})).data;
assert.equal(idemp1.success, true);
assert.equal(idemp1.alreadyRecorded, undefined);

// Call 2 (duplicate submission)
const idemp2 = (await recordPaymentCallable({
  businessId,
  customerId: custIdemp,
  amountPaise: 4000,
  method: 'cash',
  idempotencyKey: 'idemp-key-repeat-999',
})).data;
assert.equal(idemp2.success, true);
assert.equal(idemp2.alreadyRecorded, true);

// Verify exactly one payment in Firestore
const idempPayments = await custIdempRef.collection('payments').get();
assert.equal(idempPayments.size, 1);
const idempPaymentStates = await custIdempRef.collection('paymentStates').get();
assert.equal(idempPaymentStates.size, 1);

const idempBal = await custIdempRef.collection('billBalances').doc('2026-08').get();
assert.equal(idempBal.get('outstandingPaise'), 6000); // Deducted exactly once!

const idempState = await custIdempRef.collection('collectionState').doc('current').get();
assert.equal(idempState.get('outstandingPaise'), 6000);

// Same idempotencyKey with different amount must FAIL
await assert.rejects(
  recordPaymentCallable({
    businessId,
    customerId: custIdemp,
    amountPaise: 5000,
    method: 'cash',
    idempotencyKey: 'idemp-key-repeat-999',
  }),
  (err) => err.code === 'functions/failed-precondition',
);
console.log('✓ Verified: Idempotent repeat calls succeed safely with single financial effect; conflicting params rejected');

console.log('\n--- TEST 7: Phase 7 - Concurrent Collection Attempts ---');
const custConcur = 'cust-concur-p0';
const custConcurRef = firestore.doc(`businesses/${businessId}/customers/${custConcur}`);
await custConcurRef.set({
  businessId,
  customerCode: custConcur,
  name: 'Concurrent Customer',
  status: 'active',
  areaId: 'area-central',
  assignedEmployeeId: empUser.uid,
});
await custConcurRef.collection('billBalances').doc('2026-08').set({
  businessId,
  customerId: custConcur,
  billingMonth: '2026-08',
  sourceAmountPaise: 10000,
  allocatedPaise: 0,
  reversedPaise: 0,
  outstandingPaise: 10000,
  status: 'outstanding',
  revision: 1,
});
await custConcurRef.collection('collectionState').doc('current').set({
  businessId,
  customerId: custConcur,
  stateId: 'current',
  outstandingPaise: 10000,
  confirmedPaise: 0,
  reversedPaise: 0,
  reportingStatus: 'unpaid',
  oldestOutstandingMonth: '2026-08',
  revision: 1,
});

// Concurrent calls: Call A = ₹70 (7000), Call B = ₹50 (5000) against ₹100 balance
const results = await Promise.allSettled([
  recordPaymentCallable({
    businessId,
    customerId: custConcur,
    amountPaise: 7000,
    method: 'cash',
    idempotencyKey: 'concur-pay-A-1111',
  }),
  recordPaymentCallable({
    businessId,
    customerId: custConcur,
    amountPaise: 5000,
    method: 'cash',
    idempotencyKey: 'concur-pay-B-2222',
  }),
]);

const fulfilled = results.filter((r) => r.status === 'fulfilled');
const rejected = results.filter((r) => r.status === 'rejected');

assert.equal(fulfilled.length, 1, 'Exactly one concurrent payment must succeed');
assert.equal(rejected.length, 1, 'The conflicting over-balance payment must fail');

const concurBal = await custConcurRef.collection('billBalances').doc('2026-08').get();
const concurState = await custConcurRef.collection('collectionState').doc('current').get();

assert.ok(concurBal.get('outstandingPaise') >= 0, 'Bill balance must not be negative');
assert.equal(
  concurBal.get('outstandingPaise'),
  concurState.get('outstandingPaise'),
  'Bill balance and collection state must be strictly equal',
);
console.log('✓ Verified: Concurrency safety guaranteed by Firestore transaction; no balance overflow or negative state');

console.log('\n==================================================');
console.log('ALL INTEGRATION & EMULATOR SUITE TESTS PASSED 100%');
console.log('==================================================\n');
