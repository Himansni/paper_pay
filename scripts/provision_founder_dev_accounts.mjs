import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';

const projectId = 'paperroutedev';
if (
  projectId !== 'paperroutedev' ||
  process.env.GCLOUD_PROJECT?.includes('production') ||
  process.env.FIREBASE_PROJECT?.includes('production')
) {
  throw new Error('CRITICAL SAFETY FAILURE: This script is restricted strictly to paperroutedev.');
}

// Load local ignored environment file if variables are not already set in process.env
if (!process.env.FOUNDER_HEAD_PASSWORD || !process.env.FOUNDER_EMP_PASSWORD) {
  if (fs.existsSync('.env.paperroutedev')) {
    const raw = fs.readFileSync('.env.paperroutedev', 'utf8');
    for (const line of raw.split('\n')) {
      const match = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*['"]?(.*?)['"]?\s*$/);
      if (match && !process.env[match[1]]) {
        process.env[match[1]] = match[2];
      }
    }
  }
}

function getAdminToken() {
  const cfgPath = process.env.HOME + '/.config/configstore/firebase-tools.json';
  const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
  const vs = (cfg.additionalAccounts || []).find((a) => a.user?.email === 'vs467890@gmail.com') || cfg;
  return vs.tokens.access_token;
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

async function writeAdminFirestoreDoc(docPath, data) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${docPath}`;
  const fields = {};
  for (const [k, v] of Object.entries(data)) {
    fields[k] = toFirestoreValue(v);
  }
  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${getAdminToken()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Failed write to ${docPath}: ${err}`);
  }
  return await res.json();
}

async function getOrCreateAuthUser(email, password, displayName) {
  // First check if user exists
  const lookupUrl = `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:lookup`;
  const lookupRes = await fetch(lookupUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${getAdminToken()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ email: [email] }),
  });
  const lookupData = await lookupRes.json();
  let uid;
  if (lookupData.users && lookupData.users.length > 0) {
    uid = lookupData.users[0].localId;
    console.log(`   Found existing user: ${email} (UID: ${uid}). Updating password and verified status...`);
    const updateUrl = `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:update`;
    const updateRes = await fetch(updateUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${getAdminToken()}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        localId: uid,
        password,
        displayName,
        emailVerified: true,
      }),
    });
    if (!updateRes.ok) {
      throw new Error(`Failed to update auth user ${email}: ${await updateRes.text()}`);
    }
  } else {
    console.log(`   Creating new auth user: ${email}...`);
    const createUrl = `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts`;
    const createRes = await fetch(createUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${getAdminToken()}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email,
        password,
        displayName,
        emailVerified: true,
      }),
    });
    if (!createRes.ok) {
      throw new Error(`Failed to create auth user ${email}: ${await createRes.text()}`);
    }
    const createData = await createRes.json();
    uid = createData.localId;
  }
  return uid;
}

export async function provisionFounderDevAccounts() {
  console.log('================================================================');
  console.log('PROVISIONING SECURE DEVELOPMENT FOUNDER TEST ACCOUNTS');
  console.log('Target Project: paperroutedev');
  console.log('================================================================\n');

  const bizId = 'biz_founder_acceptance';
  const headEmail = 'dev-founder-head@paperroute.test';
  const headPassword = process.env.FOUNDER_HEAD_PASSWORD;
  if (!headPassword) throw new Error('FOUNDER_HEAD_PASSWORD env var is required');
  const headName = 'Founder Head (Dev)';

  const empEmail = 'dev-founder-emp@paperroute.test';
  const empPassword = process.env.FOUNDER_EMP_PASSWORD;
  if (!empPassword) throw new Error('FOUNDER_EMP_PASSWORD env var is required');
  const empName = 'Founder Employee (Dev)';

  // 1. Provision Head Auth User
  const headUid = await getOrCreateAuthUser(headEmail, headPassword, headName);
  console.log(`✔ Head Auth user provisioned (UID: ${headUid}).`);

  // 2. Provision Employee Auth User
  const empUid = await getOrCreateAuthUser(empEmail, empPassword, empName);
  console.log(`✔ Employee Auth user provisioned (UID: ${empUid}).`);

  // 3. Provision Agency Document
  const now = new Date();
  const trialEnd = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
  const effectiveExpiresAt = new Date(trialEnd.getTime() + 7 * 24 * 60 * 60 * 1000);

  await writeAdminFirestoreDoc(`businesses/${bizId}`, {
    name: 'PaperRoute Founder Acceptance Agency',
    ownerUid: headUid,
    status: 'active',
    createdAt: now,
    updatedAt: now,
    upiId: 'paperroute.agency@upi',
    upiPayeeName: 'PaperRoute Founder Agency',
  });
  console.log(`✔ Business doc provisioned: businesses/${bizId}`);

  // 4. Provision SaaS Subscription Document (active trial, allows writes)
  await writeAdminFirestoreDoc(`businesses/${bizId}/subscription/saas`, {
    businessId: bizId,
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
  console.log(`✔ SaaS Subscription doc provisioned with active trial until ${effectiveExpiresAt.toISOString()}`);

  // 5. Provision Memberships
  await writeAdminFirestoreDoc(`businesses/${bizId}/members/${headUid}`, {
    businessId: bizId,
    uid: headUid,
    email: headEmail,
    displayName: headName,
    role: 'head',
    status: 'active',
    permissions: ['all'],
    areaIds: [],
    createdAt: now,
    updatedAt: now,
  });
  console.log(`✔ Head membership doc provisioned: businesses/${bizId}/members/${headUid}`);

  await writeAdminFirestoreDoc(`businesses/${bizId}/members/${empUid}`, {
    businessId: bizId,
    uid: empUid,
    email: empEmail,
    displayName: empName,
    role: 'employee',
    status: 'active',
    permissions: ['deliveries', 'collections', 'addCustomers'],
    areaIds: ['area_founder_acceptance_01'],
    createdAt: now,
    updatedAt: now,
  });
  console.log(`✔ Employee membership doc provisioned: businesses/${bizId}/members/${empUid}`);

  // 6. Provision User Profiles
  await writeAdminFirestoreDoc(`userProfiles/${headUid}`, {
    uid: headUid,
    email: headEmail,
    displayName: headName,
    businessId: bizId,
    isEmailVerified: true,
    updatedAt: now,
  });
  console.log(`✔ Head profile provisioned: userProfiles/${headUid}`);

  await writeAdminFirestoreDoc(`userProfiles/${empUid}`, {
    uid: empUid,
    email: empEmail,
    displayName: empName,
    businessId: bizId,
    isEmailVerified: true,
    updatedAt: now,
  });
  console.log(`✔ Employee profile provisioned: userProfiles/${empUid}`);

  return {
    bizId,
    head: { email: headEmail, password: headPassword, uid: headUid },
    emp: { email: empEmail, password: empPassword, uid: empUid },
  };
}

if (process.argv[1]?.endsWith('provision_founder_dev_accounts.mjs')) {
  provisionFounderDevAccounts()
    .then((creds) => {
      console.log('\n[SUCCESS] Founder dev test accounts provisioned successfully.');
      console.log(`Agency ID: ${creds.bizId}`);
      console.log(`Head Account: ${creds.head.email} | Verified: true | Role: Head`);
      console.log(`Employee Account: ${creds.emp.email} | Verified: true | Role: Employee (Area: area_founder_acceptance_01)`);
    })
    .catch((err) => {
      console.error('[ERROR] Provisioning failed:', err);
      process.exit(1);
    });
}
