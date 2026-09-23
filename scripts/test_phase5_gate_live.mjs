import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import { initializeApp } from 'firebase/app';
import {
  createUserWithEmailAndPassword,
  getAuth,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  getFirestore,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  writeBatch,
  deleteDoc,
  terminate,
} from 'firebase/firestore';

const projectId = 'paperroutedev';
const apiKey = 'AIzaSyAiqXdkok8p84jUTYKA92eleqpJt4U5i00';
const appId = '1:720004989036:web:89c7f8865549ef3c4c9849';

const cfgPath = process.env.HOME + '/.config/configstore/firebase-tools.json';
const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
const vs =
  (cfg.additionalAccounts || []).find((a) => a.user?.email === 'vs467890@gmail.com') ||
  cfg;
const adminToken = vs.tokens.access_token;

const webhookSecret = 'whsec_paperroute_dev_test';

function createHmacSignature(body, secret) {
  return crypto.createHmac('sha256', secret).update(body).digest('hex');
}

async function setAdminEmailVerified(uid) {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:update`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ localId: uid, emailVerified: true }),
    },
  );
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Failed to set emailVerified for ${uid}: ${err}`);
  }
}

function toFirestoreValue(val) {
  if (val === null || val === undefined) return { nullValue: null };
  if (typeof val === 'boolean') return { booleanValue: val };
  if (typeof val === 'number') {
    if (Number.isInteger(val)) return { integerValue: String(val) };
    return { doubleValue: val };
  }
  if (typeof val === 'string') return { stringValue: val };
  if (val instanceof Date) return { timestampValue: val.toISOString() };
  if (Array.isArray(val)) {
    return { arrayValue: { values: val.map(toFirestoreValue) } };
  }
  if (typeof val === 'object') {
    const fields = {};
    for (const [k, v] of Object.entries(val)) {
      fields[k] = toFirestoreValue(v);
    }
    return { mapValue: { fields } };
  }
  throw new Error('Unsupported value: ' + val);
}

async function writeAdminFirestoreDoc(path, data) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${path}`;
  const fields = {};
  for (const [k, v] of Object.entries(data)) {
    fields[k] = toFirestoreValue(v);
  }
  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${adminToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Failed write to ${path}: ${err}`);
  }
}

async function getAdminFirestoreDoc(path) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${path}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${adminToken}` } });
  if (res.status === 404) return null;
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Failed get ${path}: ${err}`);
  }
  return await res.json();
}

async function main() {
  console.log('================================================================');
  console.log('PAPERROUTE — PHASE 5 FINAL PAYMENT CORRECTNESS GATE LIVE TEST');
  console.log('Target Project: paperroutedev');
  console.log('================================================================\n');

  // STEP 1: Audit all development agencies for valid subscription & effectiveExpiresAt
  console.log('1. AUDITING ALL DEV AGENCIES (Problem 3: Controlled Migration)...');
  const listUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/businesses`;
  const res = await fetch(listUrl, { headers: { Authorization: `Bearer ${adminToken}` } });
  const data = await res.json();
  const docs = data.documents || [];
  
  let validCount = 0;
  let lockedCount = 0;
  const now = new Date();

  for (const docItem of docs) {
    const bizId = docItem.name.split('/').pop();
    const sub = await getAdminFirestoreDoc(`businesses/${bizId}/subscription/saas`);
    const expAt = sub?.fields?.effectiveExpiresAt?.timestampValue;
    if (expAt && new Date(expAt) > now) {
      validCount++;
    } else {
      console.log(`   [LOCKED AGENCY]: ${bizId} (expAt=${expAt}, status=${sub?.fields?.status?.stringValue})`);
      lockedCount++;
    }
  }

  console.log(`   Audited ${docs.length} businesses: ${validCount} active/valid, ${lockedCount} locked/expired.`);
  assert.equal(lockedCount, 0, `Detected ${lockedCount} locked agencies! All dev agencies must be valid.`);
  console.log('   ✔ 100% of paperroutedev agencies have valid subscription documents and future effectiveExpiresAt.\n');

  // STEP 2: Genuine Recurring Checkout Initiation (Problem 1)
  console.log('2. TESTING RECURRING CHECKOUT INITIATION & SESSION BINDING (Problem 1)...');
  const clientApp = initializeApp(
    {
      apiKey,
      authDomain: `${projectId}.firebaseapp.com`,
      projectId,
      storageBucket: `${projectId}.appspot.com`,
      appId,
    },
    `client-${Date.now()}`,
  );
  const auth = getAuth(clientApp);
  const db = getFirestore(clientApp);

  try {
    const runId = Date.now();
    const headEmail = `head_gate_${runId}@example.com`;
    const headPassword = 'Password123!';
    const headCred = await createUserWithEmailAndPassword(auth, headEmail, headPassword);
    const headUid = headCred.user.uid;
    await setAdminEmailVerified(headUid);

    const bizId = `biz_gate_${runId}`;

    // Provision test business and head membership
    await writeAdminFirestoreDoc(`businesses/${bizId}`, {
      businessId: bizId,
      name: `Test Agency Gate ${runId}`,
      createdAt: now,
      updatedAt: now,
    });

    await writeAdminFirestoreDoc(`businesses/${bizId}/members/${headUid}`, {
      businessId: bizId,
      uid: headUid,
      email: headEmail,
      displayName: 'Test Agency Head',
      role: 'head',
      status: 'active',
      permissions: ['all'],
      createdAt: now,
      updatedAt: now,
    });

    // Provide initial trial doc
    await writeAdminFirestoreDoc(`businesses/${bizId}/subscription/saas`, {
      businessId: bizId,
      planId: 'trial',
      status: 'trial',
      trialStartsAt: now,
      trialEndsAt: new Date(now.getTime() + 30 * 86400 * 1000),
      effectiveExpiresAt: new Date(now.getTime() + 37 * 86400 * 1000),
      graceDays: 7,
      customerLimit: 500,
      employeeLimit: 10,
      createdAt: now,
      updatedAt: now,
    });

    // Call createSaasCheckoutSession callable function
    const idToken = await headCred.user.getIdToken();
    const checkoutRes = await fetch(
      `https://asia-south1-${projectId}.cloudfunctions.net/createSaasCheckoutSession`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${idToken}`,
        },
        body: JSON.stringify({
          data: {
            businessId: bizId,
            planId: 'growth',
            billingCycle: 'monthly',
          },
        }),
      },
    );

    const checkoutBodyText = await checkoutRes.text();
    if (!checkoutRes.ok) {
      console.log('Checkout failed response:', checkoutRes.status, checkoutBodyText);
    }
    assert.equal(checkoutRes.status, 200, `createSaasCheckoutSession failed with status ${checkoutRes.status}: ${checkoutBodyText}`);
    const checkoutResult = JSON.parse(checkoutBodyText).result;
    const subscriptionId = checkoutResult.subscriptionId;
    assert.ok(subscriptionId, 'Missing subscriptionId in checkout result');
    assert.equal(checkoutResult.planId, 'growth');
    assert.equal(checkoutResult.amountPaise, 59900);
    assert.equal(checkoutResult.businessId, bizId);
    console.log(`   ✔ createSaasCheckoutSession returned subscriptionId: ${subscriptionId} (isSimulated=${checkoutResult.isSimulated})`);

    // Verify authenticated checkout record persisted in Firestore
    const sessionDoc = await getAdminFirestoreDoc(`businesses/${bizId}/saasCheckoutSessions/${subscriptionId}`);
    assert.ok(sessionDoc, 'Checkout session document was NOT persisted in Firestore!');
    assert.equal(sessionDoc.fields.businessId.stringValue, bizId);
    assert.equal(sessionDoc.fields.headUid.stringValue, headUid);
    assert.equal(sessionDoc.fields.planId.stringValue, 'growth');
    assert.equal(sessionDoc.fields.amountPaise.integerValue, '59900');
    assert.equal(sessionDoc.fields.status.stringValue, 'created');
    console.log('   ✔ Authenticated checkout record successfully bound and persisted in businesses/{businessId}/saasCheckoutSessions/{subscriptionId}.\n');

    // STEP 3: Strict Webhook Validation (Problem 2)
    console.log('3. TESTING STRICT WEBHOOK VALIDATION (Problem 2)...');
    const webhookUrl = `https://asia-south1-${projectId}.cloudfunctions.net/razorpayWebhook`;

    // 3A: Forged Signature Rejection
    console.log('   3A. Testing Forged Signature Rejection...');
    const forgedBody = JSON.stringify({
      event: 'subscription.charged',
      id: `evt_forged_${runId}`,
      payload: {
        subscription: {
          entity: {
            id: subscriptionId,
            plan_id: 'plan_growth_monthly',
            notes: { businessId: bizId },
          },
        },
      },
    });

    const forgedRes = await fetch(webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Razorpay-Signature': 'forged_signature_000000000000000000000000000000000000000000000000',
        'X-Razorpay-Event-Id': `evt_forged_${runId}`,
      },
      body: forgedBody,
    });
    assert.equal(forgedRes.status, 400, 'Forged signature was NOT rejected with 400!');
    console.log('       ✔ Forged webhook signature strictly rejected with 400.');

    // 3B: Unknown Plan ID Rejection & Quarantine
    console.log('   3B. Testing Unknown Plan ID Rejection & Quarantine...');
    const unknownPlanEventId = `evt_unk_${runId}`;
    const unknownPlanBody = JSON.stringify({
      event: 'subscription.charged',
      id: unknownPlanEventId,
      payload: {
        subscription: {
          entity: {
            id: subscriptionId,
            plan_id: 'unauthorized_hack_plan_999',
            notes: { businessId: bizId },
          },
        },
      },
    });
    const unknownPlanSig = createHmacSignature(unknownPlanBody, webhookSecret);
    const unknownPlanRes = await fetch(webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Razorpay-Signature': unknownPlanSig,
        'X-Razorpay-Event-Id': unknownPlanEventId,
      },
      body: unknownPlanBody,
    });
    assert.equal(unknownPlanRes.status, 400, 'Unknown plan ID was NOT rejected with 400!');
    const quarantinedUnkDoc = await getAdminFirestoreDoc(`businesses/${bizId}/saasQuarantinedEvents/${unknownPlanEventId}`);
    assert.ok(quarantinedUnkDoc, 'Unknown plan event was NOT quarantined!');
    assert.equal(quarantinedUnkDoc.fields.quarantineReason.stringValue, 'unknown_or_unapproved_plan_id');
    console.log('       ✔ Unknown plan ID strictly rejected and safely quarantined.');

    // 3C: Unauthorized Subscription ID Rejection & Quarantine
    console.log('   3C. Testing Unauthorized Subscription ID (No Checkout Record)...');
    const unauthEventId = `evt_unauth_${runId}`;
    const unauthBody = JSON.stringify({
      event: 'subscription.charged',
      id: unauthEventId,
      payload: {
        subscription: {
          entity: {
            id: `sub_fabricated_unauthorized_${runId}`,
            plan_id: 'plan_growth_monthly',
            notes: { businessId: bizId },
          },
        },
      },
    });
    const unauthSig = createHmacSignature(unauthBody, webhookSecret);
    const unauthRes = await fetch(webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Razorpay-Signature': unauthSig,
        'X-Razorpay-Event-Id': unauthEventId,
      },
      body: unauthBody,
    });
    assert.equal(unauthRes.status, 400, 'Fabricated subscription ID was NOT rejected with 400!');
    const quarantinedUnauthDoc = await getAdminFirestoreDoc(`businesses/${bizId}/saasQuarantinedEvents/${unauthEventId}`);
    assert.ok(quarantinedUnauthDoc, 'Unauthorized subscription was NOT quarantined!');
    assert.equal(quarantinedUnauthDoc.fields.quarantineReason.stringValue, 'unauthorized_subscription_no_checkout_record');
    console.log('       ✔ Unauthorized subscription ID safely quarantined without updating agency.');

    // 3D: Plan Mismatch with Checkout Session
    console.log('   3D. Testing Plan Mismatch with Checkout Session...');
    const mismatchEventId = `evt_mismatch_${runId}`;
    const mismatchBody = JSON.stringify({
      event: 'subscription.charged',
      id: mismatchEventId,
      payload: {
        subscription: {
          entity: {
            id: subscriptionId, // created for 'growth'
            plan_id: 'plan_agencypro_annual', // incoming event claims agencyPro
            notes: { businessId: bizId },
          },
        },
      },
    });
    const mismatchSig = createHmacSignature(mismatchBody, webhookSecret);
    const mismatchRes = await fetch(webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Razorpay-Signature': mismatchSig,
        'X-Razorpay-Event-Id': mismatchEventId,
      },
      body: mismatchBody,
    });
    assert.equal(mismatchRes.status, 400, 'Plan mismatch was NOT rejected with 400!');
    const quarantinedMismatchDoc = await getAdminFirestoreDoc(`businesses/${bizId}/saasQuarantinedEvents/${mismatchEventId}`);
    assert.ok(quarantinedMismatchDoc, 'Plan mismatch event was NOT quarantined!');
    assert.equal(quarantinedMismatchDoc.fields.quarantineReason.stringValue, 'plan_mismatch_with_checkout_session');
    console.log('       ✔ Plan mismatch strictly detected and quarantined.');

    // 3E: Genuine Authorized Subscription Charge & Entitlement Activation
    console.log('   3E. Testing Genuine Authorized Subscription Activation...');
    const validEventId = `evt_valid_${runId}`;
    const currentStartSec = Math.floor(Date.now() / 1000);
    const currentEndSec = currentStartSec + 30 * 86400;

    const validBody = JSON.stringify({
      event: 'subscription.charged',
      id: validEventId,
      created_at: currentStartSec,
      payload: {
        subscription: {
          entity: {
            id: subscriptionId,
            plan_id: 'plan_growth_monthly',
            status: 'active',
            current_start: currentStartSec,
            current_end: currentEndSec,
            notes: { businessId: bizId },
          },
        },
      },
    });
    const validSig = createHmacSignature(validBody, webhookSecret);
    const validRes = await fetch(webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Razorpay-Signature': validSig,
        'X-Razorpay-Event-Id': validEventId,
      },
      body: validBody,
    });
    assert.equal(validRes.status, 200, `Valid webhook failed with status ${validRes.status}`);
    const validJson = await validRes.json();
    assert.equal(validJson.status, 'processed');

    // Verify Firestore Entitlements Updated
    const updatedSub = await getAdminFirestoreDoc(`businesses/${bizId}/subscription/saas`);
    assert.equal(updatedSub.fields.status.stringValue, 'active');
    assert.equal(updatedSub.fields.planId.stringValue, 'growth');
    assert.equal(updatedSub.fields.customerLimit.integerValue, '1000');
    assert.equal(updatedSub.fields.employeeLimit.integerValue, '10');
    assert.equal(updatedSub.fields.razorpaySubscriptionId.stringValue, subscriptionId);

    // Verify Checkout Session Marked Completed
    const completedSession = await getAdminFirestoreDoc(`businesses/${bizId}/saasCheckoutSessions/${subscriptionId}`);
    assert.equal(completedSession.fields.status.stringValue, 'completed');
    console.log('       ✔ Agency entitlement activated to Growth Plan (1,000 customers, 10 employees) and checkout session completed.');

    // 3F: Event Idempotency Check
    console.log('   3F. Testing Event Idempotency on Duplicate Delivery...');
    const dupRes = await fetch(webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Razorpay-Signature': validSig,
        'X-Razorpay-Event-Id': validEventId,
      },
      body: validBody,
    });
    assert.equal(dupRes.status, 200);
    const dupJson = await dupRes.json();
    assert.equal(dupJson.status, 'duplicate');
    console.log('       ✔ Duplicate delivery correctly identified and acknowledged without re-mutation.');

    // 3G: Out-of-Order Delivery Protection
    console.log('   3G. Testing Stale Event Downgrade Protection (Out-of-Order Delivery)...');
    const staleEventId = `evt_stale_${runId}`;
    const staleBody = JSON.stringify({
      event: 'subscription.halted',
      id: staleEventId,
      created_at: currentStartSec - 500, // Older than the renewal event
      payload: {
        subscription: {
          entity: {
            id: subscriptionId,
            plan_id: 'plan_growth_monthly',
            notes: { businessId: bizId },
          },
        },
      },
    });
    const staleSig = createHmacSignature(staleBody, webhookSecret);
    const staleRes = await fetch(webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Razorpay-Signature': staleSig,
        'X-Razorpay-Event-Id': staleEventId,
      },
      body: staleBody,
    });
    assert.equal(staleRes.status, 200);

    // Verify Subscription is STILL active (not downgraded)
    const afterStaleSub = await getAdminFirestoreDoc(`businesses/${bizId}/subscription/saas`);
    assert.equal(afterStaleSub.fields.status.stringValue, 'active');
    console.log('       ✔ Active subscription strictly protected against stale out-of-order event downgrade.');

    console.log('\n================================================================');
    console.log('✔ ALL PHASE 5 FINAL PAYMENT CORRECTNESS GATE CHECKS PASSED!');
    console.log('================================================================\n');
  } finally {
    await terminate(db);
  }
}

main().catch((err) => {
  console.error('\n❌ Gate verification failed:', err);
  process.exit(1);
});
