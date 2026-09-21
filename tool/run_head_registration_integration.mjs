import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import {
  connectAuthEmulator,
  createUserWithEmailAndPassword,
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
  appId: '1:123:web:registration-test',
});
const clientAuth = getAuth(clientApp);
connectAuthEmulator(clientAuth, 'http://127.0.0.1:9099', {
  disableWarnings: true,
});
const functions = getFunctions(clientApp, 'asia-south1');
connectFunctionsEmulator(functions, '127.0.0.1', 5001);

const adminApp = initializeAdminApp({projectId}, 'registration-integration');
const adminAuth = getAdminAuth(adminApp);
const firestore = getFirestore(adminApp);
firestore.settings({host: '127.0.0.1:8080', ssl: false});

const options = httpsCallable(functions, 'getAgencyRegistrationOptions');
const provision = httpsCallable(functions, 'provisionAgencyOwner');
const request = {
  ownerDisplayName: 'Synthetic Owner',
  ownerPhone: '9999999999',
  agencyName: 'Synthetic News Agency',
  agencyPhone: '8888888888',
  agencyAddress: '10 Synthetic Road, Test City',
  termsVersion: 'terms-v1',
  privacyVersion: 'privacy-v1',
  locale: 'en-IN',
  clientPlatform: 'web',
  requestId: '123e4567-e89b-42d3-a456-426614174000',
};

async function verifiedIdentity(email) {
  const credential = await createUserWithEmailAndPassword(
    clientAuth,
    email,
    'password-123',
  );
  await adminAuth.updateUser(credential.user.uid, {emailVerified: true});
  await credential.user.reload();
  await credential.user.getIdToken(true);
  return credential.user;
}

const owner = await verifiedIdentity('owner-registration@example.com');
const firstOptions = (await options()).data;
assert.equal(firstOptions.eligibility, 'eligible');
assert.equal(firstOptions.hasPendingEmployeeInvitation, false);

const invitingBusiness = firestore.doc('businesses/inviting-business');
await invitingBusiness.set({
  businessId: 'inviting-business',
  ownerId: 'different-owner',
  name: 'Inviting Business',
});
const invitation = invitingBusiness.collection('invitations').doc('pending-owner');
await invitation.set({
  businessId: 'inviting-business',
  email: owner.email,
  role: 'employee',
  status: 'pending',
  permissions: [],
  areaIds: [],
  createdBy: 'different-owner',
  createdAt: Timestamp.now(),
  expiresAt: Timestamp.fromMillis(Date.now() + 86_400_000),
});
const invitationOptions = (await options()).data;
assert.equal(invitationOptions.eligibility, 'eligible');
assert.equal(invitationOptions.hasPendingEmployeeInvitation, true);
assert.equal(invitationOptions.pendingInvitationCount, 1);

await assert.rejects(
  provision({...request, role: 'head'}),
  (error) => error.code === 'functions/invalid-argument',
);

const created = (await provision(request)).data;
assert.equal(created.alreadyProvisioned, false);
assert.equal(typeof created.businessId, 'string');
assert.ok(created.businessId.length >= 20);

const businessId = created.businessId;
const paths = {
  business: `businesses/${businessId}`,
  member: `businesses/${businessId}/members/${owner.uid}`,
  profile: `userProfiles/${owner.uid}`,
  registry: `agencyOwners/${owner.uid}`,
  consent: `userConsents/${owner.uid}/acceptances/terms-v1__privacy-v1`,
  audit: `businesses/${businessId}/auditRecords/agencyProvisioned-${owner.uid}`,
};
const snapshots = Object.fromEntries(
  await Promise.all(
    Object.entries(paths).map(async ([key, path]) => [
      key,
      await firestore.doc(path).get(),
    ]),
  ),
);
for (const snapshot of Object.values(snapshots)) assert.equal(snapshot.exists, true);
assert.equal(snapshots.business.get('ownerId'), owner.uid);
assert.equal(snapshots.member.get('role'), 'head');
assert.equal(snapshots.member.get('status'), 'active');
assert.deepEqual(snapshots.member.get('permissions'), []);
assert.deepEqual(snapshots.member.get('areaIds'), []);
assert.equal(snapshots.profile.get('businessId'), businessId);
assert.equal(snapshots.registry.get('provisioningRequestId'), request.requestId);
assert.equal(snapshots.consent.get('termsVersion'), 'terms-v1');
assert.equal(snapshots.consent.get('privacyVersion'), 'privacy-v1');
assert.equal(snapshots.audit.get('action'), 'agencyOwnerProvisioned');
assert.equal((await invitation.get()).get('status'), 'pending');

const retried = (await provision({...request, requestId: '223e4567-e89b-42d3-a456-426614174000'})).data;
assert.equal(retried.businessId, businessId);
assert.equal(retried.alreadyProvisioned, true);
assert.equal((await firestore.collection('agencyOwners').where('uid', '==', owner.uid).get()).size, 1);
assert.equal((await firestore.collection('businesses').where('ownerId', '==', owner.uid).get()).size, 1);
assert.equal(
  (await firestore.collection(`businesses/${businessId}/auditRecords`).where('action', '==', 'agencyOwnerProvisioned').get()).size,
  1,
);

// Completed-owner retries are idempotent, but they are still bounded so an
// authenticated account cannot turn recovery reads into an unmetered flood.
for (let attempt = 0; attempt < 2; attempt += 1) {
  const boundedRetry = (await provision({...request, requestId: `${attempt + 3}23e4567-e89b-42d3-a456-426614174000`})).data;
  assert.equal(boundedRetry.businessId, businessId);
  assert.equal(boundedRetry.alreadyProvisioned, true);
}
await assert.rejects(
  provision({...request, requestId: '623e4567-e89b-42d3-a456-426614174000'}),
  (error) => error.code === 'functions/resource-exhausted',
);
assert.equal((await firestore.collection('agencyOwners').where('uid', '==', owner.uid).get()).size, 1);
assert.equal((await firestore.collection('businesses').where('ownerId', '==', owner.uid).get()).size, 1);
assert.equal(
  (await firestore.collection(`businesses/${businessId}/auditRecords`).where('action', '==', 'agencyOwnerProvisioned').get()).size,
  1,
);

await clientAuth.signOut();
const unverified = await createUserWithEmailAndPassword(
  clientAuth,
  'unverified-owner@example.com',
  'password-123',
);
await assert.rejects(
  provision({...request, requestId: '323e4567-e89b-42d3-a456-426614174000'}),
  (error) => error.code === 'functions/failed-precondition',
);
await clientAuth.signOut();

const employee = await verifiedIdentity('accepted-employee@example.com');
await firestore.doc('businesses/inviting-business/invitations/accepted-employee').set({
  businessId: 'inviting-business',
  email: employee.email,
  role: 'employee',
  status: 'accepted',
  acceptedBy: employee.uid,
  acceptedAt: Timestamp.now(),
  createdBy: 'different-owner',
  createdAt: Timestamp.now(),
  expiresAt: Timestamp.fromMillis(Date.now() + 86_400_000),
});
const employeeOptions = (await options()).data;
assert.equal(employeeOptions.eligibility, 'blocked');
assert.equal(employeeOptions.conflictReason, 'accepted-employee-invitation');
await assert.rejects(
  provision({...request, requestId: '423e4567-e89b-42d3-a456-426614174000'}),
  (error) => error.code === 'functions/failed-precondition',
);

await clientAuth.signOut();
const legacyOwner = await verifiedIdentity('legacy-owner@example.com');
await firestore.doc('businesses/orphaned-legacy-business').set({
  businessId: 'orphaned-legacy-business',
  ownerId: legacyOwner.uid,
  name: 'Orphaned legacy state',
});
const legacyOptions = (await options()).data;
assert.equal(legacyOptions.eligibility, 'blocked');
assert.equal(legacyOptions.conflictReason, 'existing-business-ownership');
await assert.rejects(
  provision({...request, requestId: '523e4567-e89b-42d3-a456-426614174000'}),
  (error) => error.code === 'functions/failed-precondition',
);

await clientAuth.signOut();
const partialOwner = await verifiedIdentity('partial-owner@example.com');
const partialBusinessId = 'partial-owner-business';
await firestore.doc(`businesses/${partialBusinessId}`).set({
  businessId: partialBusinessId,
  ownerId: partialOwner.uid,
  name: 'Incomplete trusted state',
});
await firestore.doc(`businesses/${partialBusinessId}/members/${partialOwner.uid}`).set({
  businessId: partialBusinessId,
  uid: partialOwner.uid,
  email: partialOwner.email,
  role: 'head',
  status: 'active',
  permissions: [],
  areaIds: [],
});
await firestore.doc(`userProfiles/${partialOwner.uid}`).set({
  uid: partialOwner.uid,
  email: partialOwner.email,
  businessId: partialBusinessId,
  role: 'head',
  status: 'active',
});
await firestore.doc(`agencyOwners/${partialOwner.uid}`).set({
  uid: partialOwner.uid,
  email: partialOwner.email,
  businessId: partialBusinessId,
  consentAcceptanceId: 'terms-v1__privacy-v1',
  provisioningRequestId: '723e4567-e89b-42d3-a456-426614174000',
  provisioningVersion: 1,
});
const partialOptions = (await options()).data;
assert.equal(partialOptions.eligibility, 'blocked');
assert.equal(partialOptions.conflictReason, 'inconsistent-owner-registry');
await assert.rejects(
  provision({...request, requestId: '723e4567-e89b-42d3-a456-426614174000'}),
  (error) => error.code === 'functions/failed-precondition',
);

await clientAuth.signOut();
const throttled = await verifiedIdentity('throttled-owner@example.com');
for (let attempt = 0; attempt < 10; attempt += 1) {
  assert.equal((await options()).data.eligibility, 'eligible');
}
await assert.rejects(
  options(),
  (error) => error.code === 'functions/resource-exhausted',
);
const controlReference = firestore.doc(
  `agencyProvisioningControls/${throttled.uid}`,
);
const firstCooldown = (await controlReference.get()).get('optionsCooldownUntil');
assert.ok(firstCooldown instanceof Timestamp);
await assert.rejects(
  options(),
  (error) => error.code === 'functions/resource-exhausted',
);
const repeatedCooldown = (await controlReference.get()).get(
  'optionsCooldownUntil',
);
assert.equal(repeatedCooldown.toMillis(), firstCooldown.toMillis());

console.log('Head registration emulator integration passed: atomic provisioning, pending-invite choice, idempotent retry, fail-closed conflicts, and bounded per-UID throttling.');
