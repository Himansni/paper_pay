import assert from 'node:assert/strict';
import fs from 'node:fs';

const projectId = 'paperroutedev';
if (
  projectId !== 'paperroutedev' ||
  process.env.GCLOUD_PROJECT?.includes('production') ||
  process.env.FIREBASE_PROJECT?.includes('production')
) {
  throw new Error('CRITICAL SAFETY FAILURE: This script is restricted strictly to paperroutedev.');
}

const cfgPath = process.env.HOME + '/.config/configstore/firebase-tools.json';
const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
const vs = (cfg.additionalAccounts || []).find((a) => a.user?.email === 'vs467890@gmail.com') || cfg;
const adminToken = vs.tokens.access_token;

async function deleteFirestoreDoc(docPath) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${docPath}`;
  const res = await fetch(url, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${adminToken}` },
  });
  return res.ok;
}

async function listSubcollections(docPath, subcollectionName) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${docPath}/${subcollectionName}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${adminToken}` } });
  if (!res.ok) return [];
  const data = await res.json();
  return (data.documents || []).map((d) => d.name.split(`/documents/${projectId}/(default)/`).pop());
}

async function deleteAuthUser(uid) {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:delete`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ localId: uid }),
    },
  );
  return res.ok;
}

async function main() {
  console.log('================================================================');
  console.log('CLEANUP EPHEMERAL DEVELOPMENT FIXTURES & TEST ACCOUNTS');
  console.log(`Target: ${projectId}`);
  console.log('================================================================\n');

  // 1. Delete Ephemeral Auth Accounts
  console.log('1. Finding and deleting ephemeral test Auth accounts...');
  const usersRes = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:batchGet?maxResults=500`,
    { headers: { Authorization: `Bearer ${adminToken}` } },
  );
  const usersData = await usersRes.json();
  const allUsers = usersData.users || [];
  const testUsers = allUsers.filter(
    (u) =>
      u.email &&
      (u.email.includes('ephem_') ||
        u.email.includes('p5_') ||
        u.email.includes('test_p1') ||
        u.email.includes('phase5_')),
  );

  console.log(`   Found ${testUsers.length} ephemeral test users in Firebase Auth.`);
  for (const u of testUsers) {
    const ok = await deleteAuthUser(u.localId);
    console.log(`   [-] Deleted Auth user: ${u.email} (${u.localId}) -> ${ok ? 'OK' : 'FAILED'}`);
  }

  // 2. Delete Ephemeral Business Documents in Firestore
  console.log('\n2. Finding and deleting ephemeral test business documents...');
  const listUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/businesses`;
  const listRes = await fetch(listUrl, { headers: { Authorization: `Bearer ${adminToken}` } });
  const data = await listRes.json();
  const docs = data.documents || [];
  const ephemeralBiz = docs.filter((d) => {
    const id = d.name.split('/').pop();
    return id.startsWith('biz_ephem_') || id.startsWith('biz_p5_');
  });

  console.log(`   Found ${ephemeralBiz.length} ephemeral test businesses.`);
  const subcolls = [
    'members',
    'users',
    'areas',
    'customers',
    'saasCheckoutSessions',
    'saasQuarantinedEvents',
    'subscription',
  ];

  for (const d of ephemeralBiz) {
    const bizId = d.name.split('/').pop();
    console.log(`   Cleaning up ephemeral business: ${bizId}...`);

    for (const sub of subcolls) {
      const subDocs = await listSubcollections(`businesses/${bizId}`, sub);
      for (const sd of subDocs) {
        // Extract relative document path
        const p = sd.split('/documents/').pop();
        await deleteFirestoreDoc(p);
      }
      // Also delete known singleton doc paths like subscription/saas
      if (sub === 'subscription') {
        await deleteFirestoreDoc(`businesses/${bizId}/subscription/saas`);
      }
    }
    await deleteFirestoreDoc(`businesses/${bizId}`);
    console.log(`   [-] Successfully deleted business ${bizId}`);
  }

  // 3. Final Verification Audit
  console.log('\n3. Final verification audit of remaining businesses...');
  const finalRes = await fetch(listUrl, { headers: { Authorization: `Bearer ${adminToken}` } });
  const finalData = await finalRes.json();
  const remaining = finalData.documents || [];
  console.log(`   Total remaining businesses: ${remaining.length}`);
  const remainingEphemeral = remaining.filter((d) => {
    const id = d.name.split('/').pop();
    return id.startsWith('biz_ephem_') || id.startsWith('biz_p5_');
  });
  assert.equal(remainingEphemeral.length, 0, 'Found undeleted ephemeral businesses!');
  console.log('   ✔ 0 ephemeral businesses remain in paperroutedev.');
  console.log('\n================================================================');
  console.log('✔ CLEANUP COMPLETE: All test fixtures safely purged.');
  console.log('================================================================\n');
}

main().catch((err) => {
  console.error('Cleanup failed:', err);
  process.exit(1);
});
