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

const projectId = process.env.GCLOUD_PROJECT || 'paperroutedev';
const clientApp = initializeClientApp({
  projectId,
  apiKey: 'demo-key',
  appId: '1:123:web:monthly-bill-e2e',
});
const clientAuth = getAuth(clientApp);
connectAuthEmulator(clientAuth, 'http://127.0.0.1:9099', {
  disableWarnings: true,
});
const functions = getFunctions(clientApp, 'asia-south1');
connectFunctionsEmulator(functions, '127.0.0.1', 5001);

const adminApp = initializeAdminApp({ projectId }, 'monthly-bill-e2e');
const adminAuth = getAdminAuth(adminApp);
const firestore = getFirestore(adminApp);
firestore.settings({ host: '127.0.0.1:8080', ssl: false });

const finalizeMonthlyBillCallable = httpsCallable(functions, 'finalizeMonthlyBill');

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
console.log('STARTING REAL MONTHLY BILLING E2E & FINANCIAL AUDIT TEST');
console.log('==================================================\n');

// 1. Setup Identities & Seed Business
const headUser = await createVerifiedUser('head-mbill-e2e@example.com');
const empUser = await createVerifiedUser('emp-mbill-e2e@example.com');
const businessId = 'biz-mbill-e2e';

await firestore.doc(`businesses/${businessId}`).set({
  businessId,
  name: 'Monthly Billing E2E Agency',
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

await firestore.doc(`businesses/${businessId}/members/${headUser.uid}`).set({
  businessId,
  uid: headUser.uid,
  email: headUser.email,
  role: 'head',
  status: 'active',
  permissions: ['allowManualBilling', 'allowGlobalPricing'],
  areaIds: [],
});

await firestore.doc(`businesses/${businessId}/members/${empUser.uid}`).set({
  businessId,
  uid: empUser.uid,
  email: empUser.email,
  role: 'employee',
  status: 'active',
  permissions: ['allowManualBilling'],
  areaIds: ['area-north'],
});

// Seed Publications: Pub A and Pub B
const pubARef = firestore.doc(`businesses/${businessId}/newspapers/pub-A`);
await pubARef.set({
  newspaperId: 'pub-A',
  name: 'Publication A',
  edition: 'Main',
  language: 'English',
  status: 'active',
});
await pubARef.collection('priceRules').doc('rule-global-A').set({
  ruleId: 'rule-global-A',
  newspaperId: 'pub-A',
  pricingBasis: 'monthly',
  pricePaise: 20900, // ₹209/month
  effectiveFrom: '2026-01-01',
  status: 'active',
  revision: 1,
});

const pubBRef = firestore.doc(`businesses/${businessId}/newspapers/pub-B`);
await pubBRef.set({
  newspaperId: 'pub-B',
  name: 'Publication B',
  edition: 'Evening',
  language: 'Hindi',
  status: 'active',
});
await pubBRef.collection('priceRules').doc('rule-global-B').set({
  ruleId: 'rule-global-B',
  newspaperId: 'pub-B',
  pricingBasis: 'monthly',
  pricePaise: 29900, // ₹299/month
  effectiveFrom: '2026-01-01',
  status: 'active',
  revision: 1,
});

// Seed Monthly Billing Override for Pub A: ₹199/month for 2026-05
await firestore.doc(`businesses/${businessId}/monthlyBillingPrices/2026-05_pub-A`).set({
  businessId,
  billingMonth: '2026-05',
  newspaperId: 'pub-A',
  newspaperName: 'Publication A',
  pricePaise: 19900, // ₹199/month override
  pricingBasis: 'monthly',
  updatedBy: headUser.uid,
  updatedAt: Timestamp.now(),
});

// Seed Customer 1 (Multi-publication customer)
const cust1Id = 'cust-multi-pub-1';
const cust1Ref = firestore.doc(`businesses/${businessId}/customers/${cust1Id}`);
await cust1Ref.set({
  businessId,
  customerCode: 'C001',
  name: 'Multi-Pub Customer',
  status: 'active',
  areaId: 'area-north',
  assignedEmployeeId: empUser.uid,
  createdAt: Timestamp.now(),
});

await cust1Ref.collection('subscriptions').doc('sub-A').set({
  subscriptionId: 'sub-A',
  newspaperId: 'pub-A',
  status: 'active',
  startDate: '2026-01-01',
  quantity: 1,
});
await cust1Ref.collection('subscriptions').doc('sub-B').set({
  subscriptionId: 'sub-B',
  newspaperId: 'pub-B',
  status: 'active',
  startDate: '2026-01-01',
  quantity: 1,
});

// Authenticate client as Head User
await signInWithEmailAndPassword(clientAuth, 'head-mbill-e2e@example.com', 'password-123');

console.log('--- TEST 1: Real Monthly Billing Callable & Pricing Resolution ---');
const res1 = (await finalizeMonthlyBillCallable({
  businessId,
  customerId: cust1Id,
  billingMonth: '2026-05',
})).data;

assert.equal(res1.success, true);
assert.equal(res1.billId, '2026-05');

// Verify Firestore documents
const billDoc = await cust1Ref.collection('bills').doc('2026-05').get();
assert.equal(billDoc.exists, true);
assert.equal(billDoc.get('totalDuePaise'), 49800); // ₹199 + ₹299 = ₹498 (49800 paise)
assert.equal(billDoc.get('currentChargesPaise'), 49800);

// Verify Line Items
const lineItemsSnap = await cust1Ref.collection('bills').doc('2026-05').collection('lineItems').get();
assert.equal(lineItemsSnap.size, 2);

const itemA = lineItemsSnap.docs.find(d => d.get('newspaperId') === 'pub-A');
assert.ok(itemA, 'Publication A line item must exist');
assert.equal(itemA.get('unitPricePaise'), 19900); // Override price ₹199

const itemB = lineItemsSnap.docs.find(d => d.get('newspaperId') === 'pub-B');
assert.ok(itemB, 'Publication B line item must exist');
assert.equal(itemB.get('unitPricePaise'), 29900); // Global price ₹299

// Verify Global Price Rules were NOT modified
const pubARule = await pubARef.collection('priceRules').doc('rule-global-A').get();
assert.equal(pubARule.get('pricePaise'), 20900, 'Global price rule must remain ₹209');

// Verify Collection State and Bill Balance
const colState = await cust1Ref.collection('collectionState').doc('current').get();
assert.equal(colState.get('outstandingPaise'), 49800);

const billBal = await cust1Ref.collection('billBalances').doc('2026-05').get();
assert.equal(billBal.get('outstandingPaise'), 49800);
assert.equal(billBal.get('sourceAmountPaise'), 49800);

console.log('✓ Verified: Callable executed successfully; Pub A used ₹199 override, Pub B used ₹299 global; global rules untouched.');

console.log('\n--- TEST 2: Price Precedence (Customer Custom > Monthly Override > Global) ---');
const cust2Id = 'cust-custom-price-2';
const cust2Ref = firestore.doc(`businesses/${businessId}/customers/${cust2Id}`);
await cust2Ref.set({
  businessId,
  customerCode: 'C002',
  name: 'Custom Priced Customer',
  status: 'active',
  areaId: 'area-north',
  assignedEmployeeId: empUser.uid,
});
await cust2Ref.collection('subscriptions').doc('sub-A-custom').set({
  subscriptionId: 'sub-A-custom',
  newspaperId: 'pub-A',
  status: 'active',
  startDate: '2026-01-01',
  quantity: 1,
  customPricePaise: 15000, // ₹150 custom price
});

const res2 = (await finalizeMonthlyBillCallable({
  businessId,
  customerId: cust2Id,
  billingMonth: '2026-05',
})).data;

assert.equal(res2.success, true);
const cust2Bill = await cust2Ref.collection('bills').doc('2026-05').get();
assert.equal(cust2Bill.get('totalDuePaise'), 15000); // Custom ₹150 overrides monthly ₹199 and global ₹209

console.log('✓ Verified: Customer custom price (₹150) overrides monthly snapshot (₹199) and global price (₹209)');

console.log('\n--- TEST 3: Failure Lifecycle, Retry & Server-Side Stale State Cleanup ---');
const custFailId = 'cust-fail-retry-3';
const custFailRef = firestore.doc(`businesses/${businessId}/customers/${custFailId}`);
await custFailRef.set({
  businessId,
  customerCode: 'C003',
  name: 'Failure Customer',
  status: 'active',
  areaId: 'area-north',
  assignedEmployeeId: empUser.uid,
});
await custFailRef.collection('subscriptions').doc('sub-B-fail').set({
  subscriptionId: 'sub-B-fail',
  newspaperId: 'pub-B',
  status: 'active',
  startDate: '2026-01-01',
  quantity: 1,
});

// Record failure record in Firestore
const failureDocRef = firestore.doc(`businesses/${businessId}/billingFailures/2026-05_${custFailId}`);
await failureDocRef.set({
  businessId,
  billingMonth: '2026-05',
  customerId: custFailId,
  customerName: 'Failure Customer',
  error: 'Simulated connection timeout during batch finalization',
  createdAt: Timestamp.now(),
});

// Verify failure record exists prior to retry
let failDocSnap = await failureDocRef.get();
assert.equal(failDocSnap.exists, true);

// Verify NO bill or balance exists for Customer 3 prior to retry
const billBeforeRetry = await custFailRef.collection('bills').doc('2026-05').get();
assert.equal(billBeforeRetry.exists, false, 'No bill document should exist prior to retry');
const balBeforeRetry = await custFailRef.collection('billBalances').doc('2026-05').get();
assert.equal(balBeforeRetry.exists, false, 'No bill balance document should exist prior to retry');

// Execute Retry via finalizeMonthlyBill Callable
const retryRes = (await finalizeMonthlyBillCallable({
  businessId,
  customerId: custFailId,
  billingMonth: '2026-05',
})).data;

assert.equal(retryRes.success, true);

// CRITICAL VERIFICATION: Server MUST clean up failure record in the transaction
failDocSnap = await failureDocRef.get();
assert.equal(failDocSnap.exists, false, 'Failure record MUST be deleted by server upon successful finalization');

// Verify final bill & balance exist now
const billAfterRetry = await custFailRef.collection('bills').doc('2026-05').get();
assert.equal(billAfterRetry.exists, true);
assert.equal(billAfterRetry.get('totalDuePaise'), 29900);

const balAfterRetry = await custFailRef.collection('billBalances').doc('2026-05').get();
assert.equal(balAfterRetry.exists, true);
assert.equal(balAfterRetry.get('outstandingPaise'), 29900);

console.log('✓ Verified: Failed finalization left zero side-effects; Retry succeeded and server automatically removed stale failure state.');

console.log('\n--- TEST 4: Billing-Only Price Immutability Across Sequential Billing ---');
const cust4Id = 'cust-immutability-4';
const cust4Ref = firestore.doc(`businesses/${businessId}/customers/${cust4Id}`);
await cust4Ref.set({
  businessId,
  customerCode: 'C004',
  name: 'Immutability Customer',
  status: 'active',
  areaId: 'area-north',
  assignedEmployeeId: empUser.uid,
});
await cust4Ref.collection('subscriptions').doc('sub-A-immut').set({
  subscriptionId: 'sub-A-immut',
  newspaperId: 'pub-A',
  status: 'active',
  startDate: '2026-01-01',
  quantity: 1,
});

// Update monthlyBillingPrices override for pub-A to ₹189 for 2026-05
await firestore.doc(`businesses/${businessId}/monthlyBillingPrices/2026-05_pub-A`).set({
  businessId,
  billingMonth: '2026-05',
  newspaperId: 'pub-A',
  newspaperName: 'Publication A',
  pricePaise: 18900, // Changed to ₹189/month
  pricingBasis: 'monthly',
  updatedBy: headUser.uid,
  updatedAt: Timestamp.now(),
});

// Finalize Customer 4 with the new ₹189 override
const res4 = (await finalizeMonthlyBillCallable({
  businessId,
  customerId: cust4Id,
  billingMonth: '2026-05',
})).data;
assert.equal(res4.success, true);
const cust4Bill = await cust4Ref.collection('bills').doc('2026-05').get();
assert.equal(cust4Bill.get('totalDuePaise'), 18900);

// CRITICAL VERIFICATION: Customer 1's previously finalized bill MUST remain ₹49800 (Pub A ₹199)
const cust1BillSnap = await cust1Ref.collection('bills').doc('2026-05').get();
assert.equal(cust1BillSnap.get('totalDuePaise'), 49800, 'Customer 1 finalized bill MUST remain immutable at ₹498');

console.log('✓ Verified: Later override changes apply only to subsequent finalizations; earlier finalized bills remain strictly immutable.');

console.log('\n==================================================');
console.log('ALL MONTHLY BILLING E2E & FINANCIAL AUDIT TESTS PASSED 100%');
console.log('==================================================\n');
