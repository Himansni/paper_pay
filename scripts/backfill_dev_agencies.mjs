import fs from 'node:fs';

const projectId = 'paperroutedev';
const cfgPath = process.env.HOME + '/.config/configstore/firebase-tools.json';
const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
const vs = (cfg.additionalAccounts || []).find((a) => a.user?.email === 'vs467890@gmail.com') || cfg;
const token = vs.tokens.access_token;

const explicitActivationDate = new Date('2026-09-24T00:00:00.000Z');

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

async function writeDoc(path, data) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${path}`;
  const fields = {};
  for (const [k, v] of Object.entries(data)) {
    fields[k] = toFirestoreValue(v);
  }
  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Failed write to ${path}: ${err}`);
  }
}

async function runBackfill() {
  console.log(`Starting backfill on ${projectId} with activation date ${explicitActivationDate.toISOString()}...`);
  const listUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/businesses`;
  const res = await fetch(listUrl, { headers: { Authorization: `Bearer ${token}` } });
  const data = await res.json();
  const docs = data.documents || [];
  console.log(`Auditing ${docs.length} businesses...`);

  let updated = 0;
  let skipped = 0;

  const now = new Date();

  for (const docItem of docs) {
    const bizId = docItem.name.split('/').pop();
    const createdAtStr = docItem.fields?.createdAt?.timestampValue;
    const bizCreatedAt = createdAtStr ? new Date(createdAtStr) : now;

    const subUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/businesses/${bizId}/subscription/saas`;
    const subRes = await fetch(subUrl, { headers: { Authorization: `Bearer ${token}` } });
    
    let needsBackfill = false;
    let existingSub = null;

    if (subRes.ok) {
      existingSub = await subRes.json();
      const fields = existingSub.fields || {};
      const expAt = fields.effectiveExpiresAt?.timestampValue;
      if (!expAt || new Date(expAt) <= now) {
        needsBackfill = true;
      }
    } else {
      needsBackfill = true;
    }

    if (!needsBackfill) {
      skipped++;
      continue;
    }

    // Compute compliant timestamps
    // For legacy agencies created before activation date: anchor trial to activation date (30 days from launch)
    const trialStart = bizCreatedAt < explicitActivationDate ? explicitActivationDate : bizCreatedAt;
    const trialEnd = new Date(trialStart.getTime() + 30 * 24 * 60 * 60 * 1000);
    const graceDays = 7;
    const effectiveExpiresAt = new Date(trialEnd.getTime() + graceDays * 24 * 60 * 60 * 1000);

    const subPayload = {
      businessId: bizId,
      planId: existingSub?.fields?.planId?.stringValue || 'trial',
      status: (existingSub?.fields?.status?.stringValue && existingSub?.fields?.status?.stringValue !== 'expired')
        ? existingSub.fields.status.stringValue
        : 'trial',
      trialStartsAt: trialStart,
      trialEndsAt: trialEnd,
      graceDays,
      customerLimit: 500,
      employeeLimit: 10,
      effectiveExpiresAt,
      updatedAt: now,
    };

    if (!existingSub) {
      subPayload.createdAt = now;
    }

    await writeDoc(`businesses/${bizId}/subscription/saas`, subPayload);
    console.log(`  [+] Backfilled ${bizId}: status=${subPayload.status}, effectiveExpiresAt=${effectiveExpiresAt.toISOString()}`);
    updated++;
  }

  console.log(`\nBackfill Complete: ${updated} updated, ${skipped} skipped.`);
}

runBackfill().catch((err) => {
  console.error('Backfill failed:', err);
  process.exit(1);
});
