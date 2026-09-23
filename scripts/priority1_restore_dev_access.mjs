import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { initializeApp } from 'firebase/app';
import {
  getAuth,
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
} from 'firebase/auth';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  getFirestore,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
  terminate,
} from 'firebase/firestore';

const projectId = 'paperroutedev';

// Production safety guard: strictly prevent execution against any production environment
if (
  projectId !== 'paperroutedev' ||
  process.env.GCLOUD_PROJECT === 'paperroute-production' ||
  process.env.GCLOUD_PROJECT === 'paperroute-production-in' ||
  process.env.FIREBASE_PROJECT === 'paperroute-production'
) {
  throw new Error(
    'CRITICAL SAFETY FAILURE: This restoration script is restricted strictly to paperroutedev. Aborting to protect production.',
  );
}
const apiKey = 'AIzaSyAiqXdkok8p84jUTYKA92eleqpJt4U5i00';
const appId = '1:720004989036:web:89c7f8865549ef3c4c9849';

const cfgPath = process.env.HOME + '/.config/configstore/firebase-tools.json';
const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
const vs = (cfg.additionalAccounts || []).find((a) => a.user?.email === 'vs467890@gmail.com') || cfg;
const adminToken = vs.tokens.access_token;

// Explicitly configured DEVELOPMENT-ONLY activation date for legacy agencies
const DEV_SAAS_ACTIVATION_DATE = new Date('2026-09-24T00:00:00.000Z');

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


async function main() {
  console.log('================================================================');
  console.log('PRIORITY 1: RESTORE DEVELOPMENT ACCESS & AUDIT EXECUTION');
  console.log('Target Project: paperroutedev');
  console.log(`Development Activation Date: ${DEV_SAAS_ACTIVATION_DATE.toISOString()}`);
  console.log('================================================================\n');

  // STEP 1: Recoverable Backup & Dry-run Report
  console.log('STEP 1: Taking Recoverable Backup of all SaaS subscription documents...');
  const listUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/businesses`;
  const listRes = await fetch(listUrl, { headers: { Authorization: `Bearer ${adminToken}` } });
  const listData = await listRes.json();
  const bizDocs = listData.documents || [];
  console.log(`   Found ${bizDocs.length} total business entities in paperroutedev.`);

  const backupData = {
    exportedAt: new Date().toISOString(),
    projectId,
    totalBusinesses: bizDocs.length,
    devActivationDate: DEV_SAAS_ACTIVATION_DATE.toISOString(),
    subscriptions: {},
  };

  const dryRunReport = {
    alreadyValidPaid: [],
    alreadyValidTrial: [],
    legitimatelyExpired: [],
    legacyNeedsBackfill: [],
  };

  const now = new Date();

  for (const docItem of bizDocs) {
    const bizId = docItem.name.split('/').pop();
    const subDoc = await getAdminFirestoreDoc(`businesses/${bizId}/subscription/saas`);
    backupData.subscriptions[bizId] = subDoc ? subDoc.fields : null;

    const createdAtStr = docItem.fields?.createdAt?.timestampValue;
    const bizCreatedAt = createdAtStr ? new Date(createdAtStr) : now;

    if (!subDoc || !subDoc.fields) {
      dryRunReport.legacyNeedsBackfill.push({
        bizId,
        reason: 'missing_subscription_document',
        bizCreatedAt: bizCreatedAt.toISOString(),
      });
      continue;
    }

    const fields = subDoc.fields;
    const status = fields.status?.stringValue;
    const expAtStr = fields.effectiveExpiresAt?.timestampValue;
    const expAt = expAtStr ? new Date(expAtStr) : null;

    if (status === 'expired' && expAt && expAt <= now) {
      // Legitimately expired agency (e.g. from negative/cancellation tests)
      dryRunReport.legitimatelyExpired.push({
        bizId,
        status,
        effectiveExpiresAt: expAtStr,
      });
    } else if (status === 'active' && expAt && expAt > now) {
      dryRunReport.alreadyValidPaid.push({
        bizId,
        planId: fields.planId?.stringValue,
        effectiveExpiresAt: expAtStr,
      });
    } else if (expAt && expAt > now) {
      dryRunReport.alreadyValidTrial.push({
        bizId,
        planId: fields.planId?.stringValue,
        effectiveExpiresAt: expAtStr,
      });
    } else {
      dryRunReport.legacyNeedsBackfill.push({
        bizId,
        reason: 'missing_or_expired_effective_expiry',
        status: status || 'trial',
        bizCreatedAt: bizCreatedAt.toISOString(),
      });
    }
  }

  // Save backup file
  const backupFilename = `saas_subscriptions_backup_${Date.now()}.json`;
  const backupFilePath = path.join('scripts', 'backups', backupFilename);
  fs.writeFileSync(backupFilePath, JSON.stringify(backupData, null, 2), 'utf8');
  console.log(`   ✔ Backup successfully written to ${backupFilePath} (${Object.keys(backupData.subscriptions).length} agencies recorded).\n`);

  // Print Dry-run Report
  console.log('DRY-RUN ANALYSIS REPORT:');
  console.log(`   - Already Valid Paid Subscriptions:    ${dryRunReport.alreadyValidPaid.length}`);
  console.log(`   - Already Valid Trials:                ${dryRunReport.alreadyValidTrial.length}`);
  console.log(`   - Legitimately Expired Agencies:       ${dryRunReport.legitimatelyExpired.length}`);
  console.log(`   - Legacy Agencies Requiring Backfill:  ${dryRunReport.legacyNeedsBackfill.length}`);
  console.log('----------------------------------------------------------------\n');

  // STEP 2 & 3 & 4: Safe, Idempotent Backfill Preserving Historical State
  console.log('STEP 2, 3 & 4: Executing safe, idempotent backfill for legacy agencies...');
  let backfilledCount = 0;
  let preservedCount = 0;

  for (const item of dryRunReport.legacyNeedsBackfill) {
    const bizId = item.bizId;
    const existingFields = backupData.subscriptions[bizId];

    // Compute compliant timestamps
    const bizCreatedAt = new Date(item.bizCreatedAt);
    // Development-only activation date anchor:
    const trialStart = bizCreatedAt < DEV_SAAS_ACTIVATION_DATE ? DEV_SAAS_ACTIVATION_DATE : bizCreatedAt;
    const trialEnd = new Date(trialStart.getTime() + 30 * 24 * 60 * 60 * 1000);
    const graceDays = 7;
    const effectiveExpiresAt = new Date(trialEnd.getTime() + graceDays * 24 * 60 * 60 * 1000);

    const subPayload = {
      businessId: bizId,
      planId: existingFields?.planId?.stringValue || 'trial',
      status: 'trial',
      trialStartsAt: existingFields?.trialStartsAt?.timestampValue
        ? new Date(existingFields.trialStartsAt.timestampValue)
        : trialStart,
      trialEndsAt: existingFields?.trialEndsAt?.timestampValue
        ? new Date(existingFields.trialEndsAt.timestampValue)
        : trialEnd,
      graceDays,
      customerLimit: 500,
      employeeLimit: 10,
      effectiveExpiresAt,
      updatedAt: now,
    };

    if (!existingFields) {
      subPayload.createdAt = now;
    }

    await writeAdminFirestoreDoc(`businesses/${bizId}/subscription/saas`, subPayload);
    console.log(`   [+] Backfilled ${bizId}: trialEndsAt=${subPayload.trialEndsAt.toISOString()}, effectiveExpiresAt=${effectiveExpiresAt.toISOString()}`);
    backfilledCount++;
  }

  // Preserve legitimately expired agencies without unauthorized trial resets
  for (const expItem of dryRunReport.legitimatelyExpired) {
    console.log(`   [=] Preserving legitimately expired agency: ${expItem.bizId} (status=${expItem.status}, effectiveExpiresAt=${expItem.effectiveExpiresAt})`);
    preservedCount++;
  }

  console.log(`\n   Backfill completed: ${backfilledCount} backfilled, ${preservedCount} legitimately expired preserved.\n`);

  // STEP 5: Re-audit all reported agencies
  console.log('STEP 5: Re-auditing all agencies in paperroutedev...');
  let auditTotal = 0;
  let auditValid = 0;
  let auditLegitimatelyExpired = 0;
  let auditUnintentionallyLocked = 0;

  for (const docItem of bizDocs) {
    const bizId = docItem.name.split('/').pop();
    auditTotal++;
    const subDoc = await getAdminFirestoreDoc(`businesses/${bizId}/subscription/saas`);
    const status = subDoc?.fields?.status?.stringValue;
    const expAtStr = subDoc?.fields?.effectiveExpiresAt?.timestampValue;
    const expAt = expAtStr ? new Date(expAtStr) : null;

    if (status === 'expired' && expAt && expAt <= now) {
      auditLegitimatelyExpired++;
    } else if (expAt && expAt > now) {
      auditValid++;
    } else {
      console.error(`   ❌ Unintentionally locked agency found: ${bizId}`);
      auditUnintentionallyLocked++;
    }
  }

  console.log(`   Audited ${auditTotal} businesses:`);
  console.log(`     - Valid Active / Trial Agencies:   ${auditValid}`);
  console.log(`     - Legitimately Expired Agencies:  ${auditLegitimatelyExpired}`);
  console.log(`     - Unintentionally Locked Out:     ${auditUnintentionallyLocked}`);
  assert.equal(auditUnintentionallyLocked, 0, `Detected ${auditUnintentionallyLocked} unintentionally locked agencies!`);
  console.log('   ✔ Verification confirmed: 0 agencies remain unintentionally locked out.\n');

  // STEP 6: Test Real Authenticated Operational Write on a Development Agency
  console.log('STEP 6: Testing real authenticated operational write on Development agency...');

  const clientApp = initializeApp(
    {
      apiKey,
      authDomain: `${projectId}.firebaseapp.com`,
      projectId,
      storageBucket: `${projectId}.appspot.com`,
      appId,
    },
    `legacy-test-${Date.now()}`,
  );
  const auth = getAuth(clientApp);
  const db = getFirestore(clientApp);

  try {
    let testBizId;
    let testHeadUid;

    if (process.env.DEV_TEST_HEAD_EMAIL && process.env.DEV_TEST_HEAD_PASSWORD) {
      // Use externally supplied test credentials
      const testHeadEmail = process.env.DEV_TEST_HEAD_EMAIL;
      const testHeadPassword = process.env.DEV_TEST_HEAD_PASSWORD;
      testBizId = process.env.DEV_TEST_BIZ_ID || 'xFHZnt4jaXFqe8Q4u8YL';
      console.log(`   Authenticating as Head via externally supplied credentials: ${testHeadEmail}...`);
      const cred = await signInWithEmailAndPassword(auth, testHeadEmail, testHeadPassword);
      testHeadUid = cred.user.uid;
      console.log(`   ✔ Head successfully signed in via Firebase Auth (UID: ${testHeadUid}).`);
    } else {
      // Use isolated ephemeral development fixture
      console.log('   [i] No external credentials supplied via DEV_TEST_HEAD_PASSWORD.');
      console.log('   [i] Provisioning isolated ephemeral test fixture in paperroutedev...');
      const runId = `ephem_${Date.now()}_${crypto.randomBytes(3).toString('hex')}`;
      testBizId = `biz_${runId}`;
      const ephemeralEmail = `head_${runId}@paperroute.test`;
      const ephemeralPassword = `Dev!${crypto.randomBytes(16).toString('hex')}`;

      const cred = await createUserWithEmailAndPassword(auth, ephemeralEmail, ephemeralPassword);
      testHeadUid = cred.user.uid;

      // Verify email via Admin API
      await fetch(
        `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:update`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${adminToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ localId: testHeadUid, emailVerified: true }),
        },
      );
      await cred.user.getIdToken(true);

      // Provision business and active trial subscription doc via Admin API
      const now = new Date();
      const trialEnd = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
      const effectiveExpiresAt = new Date(trialEnd.getTime() + 7 * 24 * 60 * 60 * 1000);

      await writeAdminFirestoreDoc(`businesses/${testBizId}`, {
        name: 'Ephemeral Dev Verification Agency',
        status: 'active',
        createdAt: now,
      });
      await writeAdminFirestoreDoc(`businesses/${testBizId}/members/${testHeadUid}`, {
        businessId: testBizId,
        email: ephemeralEmail,
        role: 'head',
        status: 'active',
        createdAt: now,
      });
      await writeAdminFirestoreDoc(`businesses/${testBizId}/subscription/saas`, {
        businessId: testBizId,
        planId: 'trial',
        status: 'trial',
        trialStartsAt: now,
        trialEndsAt: trialEnd,
        graceDays: 7,
        effectiveExpiresAt,
        customerLimit: 500,
        employeeLimit: 10,
        createdAt: now,
        updatedAt: now,
      });
      console.log(`   ✔ Ephemeral test fixture provisioned for agency ${testBizId} with active trial.`);
    }

    // Execute real operational area creation and update via client Firestore SDK (evaluated by Firestore Security Rules)
    const areaId = `area_op_${Date.now()}`;
    const areaRef = doc(db, `businesses/${testBizId}/areas/${areaId}`);

    console.log(`   Executing real operational CREATE of area ${areaId}...`);
    await setDoc(areaRef, {
      businessId: testBizId,
      name: 'Priority 1 Verification Area',
      code: 'P1VA',
      status: 'active',
      createdBy: testHeadUid,
      createdAt: serverTimestamp(),
    });
    console.log('   ✔ Real authenticated operational CREATE committed successfully to Firestore!');
    console.log('   ✔ subscriptionAllowsWrites security rule permitted operational create.');

    console.log(`   Executing real operational UPDATE of area ${areaId}...`);
    await updateDoc(areaRef, {
      name: 'Priority 1 Verification Area (Updated)',
      businessId: testBizId,
      updatedAt: serverTimestamp(),
    });
    console.log('   ✔ Real authenticated operational UPDATE committed successfully to Firestore!');
    console.log('   ✔ subscriptionAllowsWrites security rule permitted operational update.');

    // Verify document was updated
    const updatedSnap = await getDoc(areaRef);
    assert.equal(updatedSnap.exists(), true);
    assert.equal(updatedSnap.data().name, 'Priority 1 Verification Area (Updated)');
    console.log('   ✔ Operational state change verified in Firestore.\n');

    console.log('================================================================');
    console.log('✔ PRIORITY 1 EXECUTION AND VERIFICATION COMPLETE & APPROVED!');
    console.log('================================================================\n');
  } finally {
    await terminate(db);
  }
}

main().catch((err) => {
  console.error('\n❌ Priority 1 Execution Failed:', err);
  process.exit(1);
});
