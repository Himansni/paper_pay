import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { initializeApp } from 'firebase/app';
import { getAuth, connectAuthEmulator, signInWithEmailAndPassword, createUserWithEmailAndPassword } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator, collection, doc, setDoc, serverTimestamp } from 'firebase/firestore';
import { getFunctions, connectFunctionsEmulator, httpsCallable } from 'firebase/functions';

const requireFromFunctions = createRequire(
  new URL('../functions/package.json', import.meta.url),
);
const { initializeApp: initializeAdminApp } = requireFromFunctions(
  'firebase-admin/app',
);
const { getAuth: getAdminAuth } = requireFromFunctions('firebase-admin/auth');
const { getFirestore: getAdminFirestore, Timestamp } = requireFromFunctions(
  'firebase-admin/firestore',
);

const projectId = 'demo-paper-route';

// Initialize Admin SDK
const adminApp = initializeAdminApp({ projectId }, 'forgery-test-app');
const adminAuth = getAdminAuth(adminApp);
const adminDb = getAdminFirestore(adminApp);
adminDb.settings({ host: '127.0.0.1:8080', ssl: false });

// Initialize Client SDK
const clientApp = initializeApp({ projectId, apiKey: 'demo-key', appId: '1:123:web:app' });
const clientAuth = getAuth(clientApp);
connectAuthEmulator(clientAuth, 'http://127.0.0.1:9099', { disableWarnings: true });
const clientFirestore = getFirestore(clientApp);
connectFirestoreEmulator(clientFirestore, '127.0.0.1', 8080);
const clientFunctions = getFunctions(clientApp, 'asia-south1');
connectFunctionsEmulator(clientFunctions, '127.0.0.1', 5001);

async function run() {
  console.log('--- Step 1: Seeding test environment ---');
  const businessId = 'biz-forgery-test';
  const customerId = 'cust-forgery-1';
  const empEmail = 'attacker@forgery.test';
  const empPassword = 'password-123';

  let empUser;
  try {
    const cred = await createUserWithEmailAndPassword(clientAuth, empEmail, empPassword);
    await adminAuth.updateUser(cred.user.uid, { emailVerified: true });
    await cred.user.reload();
    empUser = cred.user;
  } catch (e) {
    if (e.code === 'auth/email-already-in-use') {
      const cred = await signInWithEmailAndPassword(clientAuth, empEmail, empPassword);
      empUser = cred.user;
    } else {
      throw e;
    }
  }
  const empUid = empUser.uid;

  const now = Timestamp.now();
  const future = new Date(Date.now() + 365 * 86400000);

  await adminDb.doc(`businesses/${businessId}`).set({
    name: 'Forgery Test Agency',
    status: 'active',
    createdAt: now,
  });

  await adminDb.doc(`businesses/${businessId}/subscription/saas`).set({
    status: 'active',
    effectiveExpiresAt: Timestamp.fromDate(future),
    plan: 'agency_pro',
  });

  await adminDb.doc(`businesses/${businessId}/members/${empUid}`).set({
    uid: empUid,
    email: empEmail,
    role: 'employee',
    status: 'active',
    permissions: ['recordPayments'],
    areaIds: ['area-north'],
  });

  await adminDb.doc(`businesses/${businessId}/customers/${customerId}`).set({
    businessId,
    name: 'Victim Customer',
    customerCode: 'C-FORGE-1',
    areaId: 'area-north',
    assignedEmployeeId: empUid,
    status: 'active',
    openingBalancePaise: 0,
  });

  await adminDb.doc(`businesses/${businessId}/customers/${customerId}/collectionState/current`).set({
    businessId,
    customerId,
    stateId: 'current',
    outstandingPaise: 10000,
    confirmedPaise: 0,
    reversedPaise: 0,
    reportingStatus: 'unpaid',
    oldestOutstandingMonth: '2026-09',
    revision: 1,
  });

  await adminDb.doc(`businesses/${businessId}/customers/${customerId}/billBalances/2026-09`).set({
    businessId,
    customerId,
    billingMonth: '2026-09',
    sourceAmountPaise: 10000,
    allocatedPaise: 0,
    reversedPaise: 0,
    outstandingPaise: 10000,
    status: 'outstanding',
    revision: 1,
  });

  console.log('--- Step 2: Sign in untrusted employee client ---');
  await signInWithEmailAndPassword(clientAuth, empEmail, empPassword);

  console.log('--- Step 3: Record legitimate payment via Cloud Function ---');
  const recordPaymentFn = httpsCallable(clientFunctions, 'recordPayment');
  const paymentResult = await recordPaymentFn({
    businessId,
    customerId,
    amountPaise: 5000,
    method: 'cash',
    idempotencyKey: 'idemp-forge-test-1',
  });
  console.log('✓ Legitimate payment created:', paymentResult.data);
  const paymentId = paymentResult.data.paymentId;

  console.log('--- Step 4: Verify server generated legitimate paymentConfirmed audit record ---');
  const auditQuery = await adminDb
    .collection(`businesses/${businessId}/auditRecords`)
    .where('action', '==', 'paymentConfirmed')
    .where('entityId', '==', paymentId)
    .get();

  assert.equal(auditQuery.empty, false, 'Server-side paymentConfirmed audit must exist');
  console.log('✓ Verified: Legitimate server audit record exists with ID:', auditQuery.docs[0].id);

  console.log('--- Step 5: Untrusted client attempts to FORGE a paymentConfirmed audit record ---');
  const fakeAuditRef = doc(collection(clientFirestore, `businesses/${businessId}/auditRecords`));

  let forgeryBlocked = false;
  try {
    await setDoc(fakeAuditRef, {
      businessId,
      actorId: empUid,
      actorRole: 'employee',
      action: 'paymentConfirmed',
      entityType: 'payment',
      entityId: paymentId,
      customerId,
      amountPaise: 5000,
      createdAt: serverTimestamp(),
    });
  } catch (err) {
    if (err.code === 'permission-denied') {
      forgeryBlocked = true;
      console.log('✓ SUCCESS: Untrusted client direct audit write was BLOCKED by Firestore Security Rules with permission-denied!');
    } else {
      console.error('Unexpected error:', err);
    }
  }

  assert.equal(forgeryBlocked, true, 'Direct client paymentConfirmed audit creation MUST be blocked');

  console.log('\n==================================================');
  console.log('ALL FORGERY ATTACK VERIFICATION TESTS PASSED 100%');
  console.log('==================================================\n');
}

run().catch((err) => {
  console.error('Test execution failed:', err);
  process.exit(1);
});
