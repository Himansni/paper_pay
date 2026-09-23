import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import {
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  getAuth,
  signInWithEmailAndPassword,
  signOut,
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
  appId: '1:123:web:account-deletion-test',
});
const clientAuth = getAuth(clientApp);
connectAuthEmulator(clientAuth, 'http://127.0.0.1:9099', {
  disableWarnings: true,
});
const functions = getFunctions(clientApp, 'asia-south1');
connectFunctionsEmulator(functions, '127.0.0.1', 5001);

const adminApp = initializeAdminApp({projectId}, 'account-deletion-integration');
const adminAuth = getAdminAuth(adminApp);
const firestore = getFirestore(adminApp);
firestore.settings({host: '127.0.0.1:8080', ssl: false});

const requestAccountDeletion = httpsCallable(functions, 'requestAccountDeletion');

async function verifiedIdentity(email, password = 'password-123') {
  const credential = await createUserWithEmailAndPassword(
    clientAuth,
    email,
    password,
  );
  await adminAuth.updateUser(credential.user.uid, {emailVerified: true});
  await credential.user.reload();
  await credential.user.getIdToken(true);
  return credential.user;
}

process.stdout.write('\n--- 1. Testing Unassigned User Account Deletion & Confirmation Validation ---\n');
const unassigned = await verifiedIdentity('unassigned-del@example.com');

// 1.1 Strict confirmation checks
await assert.rejects(
  requestAccountDeletion({}),
  (err) => err.message.includes('Account deletion requires exact confirmation') || err.code === 'functions/invalid-argument',
);
await assert.rejects(
  requestAccountDeletion({confirmation: 'delete'}),
  (err) => err.message.includes('Account deletion requires exact confirmation') || err.code === 'functions/invalid-argument',
);
await assert.rejects(
  requestAccountDeletion({confirmation: 'CONFIRMED'}),
  (err) => err.message.includes('Account deletion requires exact confirmation') || err.code === 'functions/invalid-argument',
);

// Reset rate limit controls after validation checks so execution is not throttled
await firestore.doc(`agencyProvisioningControls/${unassigned.uid}`).delete();

// 1.2 Exact confirmation succeeds
const unassignedResult = (await requestAccountDeletion({confirmation: 'DELETE'})).data;
assert.equal(unassignedResult.success, true);
assert.equal(unassignedResult.status, 'deleted');
assert.equal(unassignedResult.role, 'unassigned');

// Verify Firebase Auth user is deleted
await assert.rejects(
  () => adminAuth.getUser(unassigned.uid),
  (err) => err.code === 'auth/user-not-found',
);

// Verify accountDeletionRequests record
const unassignedRequestDoc = await firestore
  .doc(`accountDeletionRequests/${unassigned.uid}`)
  .get();
assert.equal(unassignedRequestDoc.exists, true);
assert.equal(unassignedRequestDoc.get('status'), 'completed');
assert.equal(unassignedRequestDoc.get('role'), 'unassigned');
process.stdout.write('✔ Unassigned user account deleted and recorded.\n');

process.stdout.write('\n--- 2. Testing Employee Account Deletion, Payment Preservation, & Post-Deletion Sign-in Lockout ---\n');
const agency1 = firestore.doc('businesses/del-agency-1');
await agency1.set({
  businessId: 'del-agency-1',
  name: 'Test Agency 1',
  ownerId: 'some-owner-1',
  status: 'active',
});

const emp = await verifiedIdentity('employee-del@example.com');
await agency1.collection('members').doc(emp.uid).set({
  businessId: 'del-agency-1',
  uid: emp.uid,
  displayName: 'Active Collector',
  email: emp.email,
  phone: '9876543210',
  role: 'employee',
  status: 'active',
  permissions: ['collectPayments'],
  areaIds: ['area-north'],
});
await firestore.doc(`userProfiles/${emp.uid}`).set({
  uid: emp.uid,
  displayName: 'Active Collector',
  email: emp.email,
  phone: '9876543210',
  businessId: 'del-agency-1',
  role: 'employee',
  status: 'active',
});

// Seed historical invitation for this employee
const empInviteDoc = agency1.collection('invitations').doc('invite-emp-001');
await empInviteDoc.set({
  businessId: 'del-agency-1',
  email: emp.email,
  status: 'accepted',
  acceptedBy: emp.uid,
  role: 'employee',
  createdAt: Timestamp.now(),
});

// Seed an unrelated business with an invitation for the EXACT SAME email to test cross-tenant isolation
const unrelatedAgency = firestore.doc('businesses/del-agency-unrelated');
await unrelatedAgency.set({
  businessId: 'del-agency-unrelated',
  name: 'Unrelated Cross-Tenant Agency',
  ownerId: 'unrelated-owner',
  status: 'active',
});

const unrelatedInviteCreatedAt = Timestamp.fromMillis(Date.now() - 3600000);
const unrelatedEmpInviteDoc = unrelatedAgency.collection('invitations').doc('invite-unrelated-emp');
await unrelatedEmpInviteDoc.set({
  businessId: 'del-agency-unrelated',
  email: emp.email,
  status: 'pending',
  role: 'employee',
  permissions: ['collectPayments'],
  areaIds: ['area-unrelated'],
  createdAt: unrelatedInviteCreatedAt,
  updatedAt: unrelatedInviteCreatedAt,
});

const unrelatedAuditDoc = unrelatedAgency.collection('auditRecords').doc('audit-unrelated-001');
await unrelatedAuditDoc.set({
  businessId: 'del-agency-unrelated',
  actorId: 'unrelated-owner',
  action: 'employeeInvited',
  entityType: 'invitation',
  entityId: 'invite-unrelated-emp',
  createdAt: unrelatedInviteCreatedAt,
});

// Seed historical payment collected by this employee
const paymentDoc = agency1
  .collection('customers')
  .doc('cust-101')
  .collection('payments')
  .doc('pay-hist-001');
await paymentDoc.set({
  paymentId: 'pay-hist-001',
  businessId: 'del-agency-1',
  customerId: 'cust-101',
  collectorUid: emp.uid,
  amountPaise: 25000,
  method: 'cash',
  status: 'confirmed',
  confirmedAt: Timestamp.now(),
});

// Request deletion with exact confirmation
const empResult = (await requestAccountDeletion({confirmation: 'DELETE', reason: 'Leaving agency'})).data;
assert.equal(empResult.success, true);
assert.equal(empResult.status, 'deleted');
assert.equal(empResult.role, 'employee');

// Verify membership is set to 'removed' and PII is stripped/anonymized
const updatedMember = await agency1.collection('members').doc(emp.uid).get();
assert.equal(updatedMember.get('status'), 'removed');
assert.equal(updatedMember.get('displayName'), 'Former Employee');
assert.match(updatedMember.get('email'), /^deleted-[a-f0-9]+@deleted\.paperroute\.local$/);
assert.equal(updatedMember.get('phone'), '');
assert.deepEqual(updatedMember.get('permissions'), []);
assert.deepEqual(updatedMember.get('areaIds'), []);

// Verify profile is anonymized
const updatedProfile = await firestore.doc(`userProfiles/${emp.uid}`).get();
assert.equal(updatedProfile.get('displayName'), 'Former Employee');
assert.equal(updatedProfile.get('phone'), '');

// Verify invitation email was anonymized for Business A
const updatedEmpInvite = await empInviteDoc.get();
assert.match(updatedEmpInvite.get('email'), /^deleted-[a-f0-9]+@deleted\.paperroute\.local$/);

// Cross-tenant verification: Verify unrelated business invitation with EXACT SAME email is COMPLETELY UNCHANGED
const checkUnrelatedEmpInvite = await unrelatedEmpInviteDoc.get();
assert.equal(checkUnrelatedEmpInvite.exists, true);
assert.equal(checkUnrelatedEmpInvite.get('email'), emp.email, 'Unrelated business invitation email must NOT be modified');
assert.equal(checkUnrelatedEmpInvite.get('status'), 'pending', 'Unrelated business invitation status must remain pending');
assert.equal(checkUnrelatedEmpInvite.get('businessId'), 'del-agency-unrelated');
assert.deepEqual(checkUnrelatedEmpInvite.get('createdAt'), unrelatedInviteCreatedAt);
assert.deepEqual(checkUnrelatedEmpInvite.get('updatedAt'), unrelatedInviteCreatedAt);

// Verify unrelated business audit records were completely unmodified
const unrelatedAudits = await unrelatedAgency.collection('auditRecords').get();
assert.equal(unrelatedAudits.size, 1);
assert.equal(unrelatedAudits.docs[0].id, 'audit-unrelated-001');

// Verify payment is STILL PRESENT and collectorUid is PRESERVED (audit integrity)
const preservedPayment = await paymentDoc.get();
assert.equal(preservedPayment.exists, true);
assert.equal(preservedPayment.get('collectorUid'), emp.uid);
assert.equal(preservedPayment.get('amountPaise'), 25000);

// Verify employee audit record was appended
const employeeAuditQuery = await agency1
  .collection('auditRecords')
  .where('action', '==', 'employeeAccountDeleted')
  .where('actorId', '==', emp.uid)
  .get();
assert.equal(employeeAuditQuery.empty, false);

// Verify employee cannot sign in again
await assert.rejects(
  () => signInWithEmailAndPassword(clientAuth, 'employee-del@example.com', 'password-123'),
  (err) => err.code === 'auth/invalid-credential' || err.code === 'auth/user-not-found',
);
process.stdout.write('✔ Employee account deleted, profile anonymized, payment history preserved, unrelated business invitation unchanged.\n');

process.stdout.write('\n--- 3. Testing Head Account Deletion Blocked by Active Operations ---\n');
const agency2 = firestore.doc('businesses/del-agency-2');
await agency2.set({
  businessId: 'del-agency-2',
  name: 'Head Agency 2',
  ownerId: 'placeholder-owner',
  status: 'active',
});

const head = await verifiedIdentity('head-del@example.com');
await agency2.update({ownerId: head.uid});
await agency2.collection('members').doc(head.uid).set({
  businessId: 'del-agency-2',
  uid: head.uid,
  displayName: 'Agency Owner',
  email: head.email,
  phone: '9988776655',
  role: 'head',
  status: 'active',
});
await firestore.doc(`userProfiles/${head.uid}`).set({
  uid: head.uid,
  displayName: 'Agency Owner',
  email: head.email,
  phone: '9988776655',
  businessId: 'del-agency-2',
  role: 'head',
  status: 'active',
});
await firestore.doc(`agencyOwners/${head.uid}`).set({
  uid: head.uid,
  businessId: 'del-agency-2',
  email: head.email,
  status: 'active',
  createdAt: Timestamp.now(),
});

// Case 3A: Active employee exists
const activeEmpDoc = agency2.collection('members').doc('active-emp-1');
await activeEmpDoc.set({
  businessId: 'del-agency-2',
  uid: 'active-emp-1',
  role: 'employee',
  status: 'active',
});

await assert.rejects(
  requestAccountDeletion({confirmation: 'DELETE'}),
  (err) => err.message.includes('Cannot delete agency account while 1 active employee(s) remain'),
);

// Verify blocked status recorded
const blockedEmpReq = await firestore.doc(`accountDeletionRequests/${head.uid}`).get();
assert.equal(blockedEmpReq.get('status'), 'blocked_active_employees');

// Remove employee
await activeEmpDoc.update({status: 'removed'});

// Case 3B: Active customer exists
const activeCustDoc = agency2.collection('customers').doc('active-cust-1');
await activeCustDoc.set({
  businessId: 'del-agency-2',
  customerId: 'active-cust-1',
  status: 'active',
  archived: false,
});

await assert.rejects(
  requestAccountDeletion({confirmation: 'DELETE'}),
  (err) => err.message.includes('active customer routes exist'),
);

const blockedCustReq = await firestore.doc(`accountDeletionRequests/${head.uid}`).get();
assert.equal(blockedCustReq.get('status'), 'blocked_active_customers');

// Archive customer
await activeCustDoc.update({status: 'archived', archived: true});
process.stdout.write('✔ Head deletion safely blocked when active employees or customers exist.\n');

process.stdout.write('\n--- 4. Testing Head Deletion with Offboarded Agency, Ledger Preservation, & Cascade Disabling ---\n');
// Seed pending invitation and active area to test automatic revoking/archiving
const inviteDoc = agency2.collection('invitations').doc('invite-del-001');
await inviteDoc.set({
  businessId: 'del-agency-2',
  email: 'pending-invitee@example.com',
  status: 'pending',
  role: 'employee',
  createdAt: Timestamp.now(),
});

// Seed an owner invitation in agency 2 to test owner invitation anonymization
const headOwnerInviteDoc = agency2.collection('invitations').doc('invite-head-owner-001');
await headOwnerInviteDoc.set({
  businessId: 'del-agency-2',
  email: head.email,
  status: 'accepted',
  role: 'head',
  createdAt: Timestamp.now(),
});

// Seed an invitation in the unrelated agency with the Head's email to verify cross-tenant isolation
const unrelatedHeadInviteCreatedAt = Timestamp.fromMillis(Date.now() - 1800000);
const unrelatedHeadInviteDoc = unrelatedAgency.collection('invitations').doc('invite-unrelated-head');
await unrelatedHeadInviteDoc.set({
  businessId: 'del-agency-unrelated',
  email: head.email,
  status: 'pending',
  role: 'employee',
  createdAt: unrelatedHeadInviteCreatedAt,
  updatedAt: unrelatedHeadInviteCreatedAt,
});

const areaDoc = agency2.collection('areas').doc('area-route-del');
await areaDoc.set({
  businessId: 'del-agency-2',
  name: 'Route 10',
  status: 'active',
});

// Seed historical bills and payments
const histBill = agency2.collection('customers').doc('active-cust-1').collection('bills').doc('bill-2026-08');
await histBill.set({
  billId: 'bill-2026-08',
  businessId: 'del-agency-2',
  customerId: 'active-cust-1',
  billingMonth: '2026-08',
  totalDuePaise: 45000,
  status: 'finalized',
});
const histPayment = agency2.collection('customers').doc('active-cust-1').collection('payments').doc('pay-head-001');
await histPayment.set({
  paymentId: 'pay-head-001',
  businessId: 'del-agency-2',
  customerId: 'active-cust-1',
  amountPaise: 45000,
  status: 'confirmed',
  confirmedAt: Timestamp.now(),
});

// Execute head deletion
const headResult = (await requestAccountDeletion({confirmation: 'DELETE', reason: 'Agency closing down'})).data;
assert.equal(headResult.success, true);
assert.equal(headResult.status, 'deleted');
assert.equal(headResult.role, 'head');

// Verify agency document is closed
const closedAgency = await agency2.get();
assert.equal(closedAgency.get('status'), 'closed');
assert.equal(closedAgency.get('phone'), '');

// Verify pending invitation was automatically revoked
const closedInvite = await inviteDoc.get();
assert.equal(closedInvite.get('status'), 'revoked');

// Verify owner invitation was anonymized
const closedHeadOwnerInvite = await headOwnerInviteDoc.get();
assert.match(closedHeadOwnerInvite.get('email'), /^deleted-[a-f0-9]+@deleted\.paperroute\.local$/);

// Cross-tenant verification: Verify unrelated business invitation with Head's email is COMPLETELY UNCHANGED
const checkUnrelatedHeadInvite = await unrelatedHeadInviteDoc.get();
assert.equal(checkUnrelatedHeadInvite.exists, true);
assert.equal(checkUnrelatedHeadInvite.get('email'), head.email, 'Unrelated business invitation for Head email must NOT be modified');
assert.equal(checkUnrelatedHeadInvite.get('status'), 'pending', 'Unrelated business invitation status must remain pending');
assert.equal(checkUnrelatedHeadInvite.get('businessId'), 'del-agency-unrelated');
assert.deepEqual(checkUnrelatedHeadInvite.get('createdAt'), unrelatedHeadInviteCreatedAt);
assert.deepEqual(checkUnrelatedHeadInvite.get('updatedAt'), unrelatedHeadInviteCreatedAt);

// Verify active delivery area was automatically archived
const closedArea = await areaDoc.get();
assert.equal(closedArea.get('status'), 'archived');

// Verify owner membership is closed and anonymized
const closedHeadMember = await agency2.collection('members').doc(head.uid).get();
assert.equal(closedHeadMember.get('status'), 'closed');
assert.equal(closedHeadMember.get('displayName'), 'Former Owner');
assert.equal(closedHeadMember.get('phone'), '');
assert.match(closedHeadMember.get('email'), /^deleted-[a-f0-9]+@deleted\.paperroute\.local$/);

// Verify agencyOwners record is closed and email anonymized
const closedOwnerDoc = await firestore.doc(`agencyOwners/${head.uid}`).get();
assert.equal(closedOwnerDoc.get('status'), 'closed');
assert.match(closedOwnerDoc.get('email'), /^deleted-[a-f0-9]+@deleted\.paperroute\.local$/);

// Verify historical financial bills and payments are PRESERVED
const preservedBill = await histBill.get();
assert.equal(preservedBill.exists, true);
assert.equal(preservedBill.get('totalDuePaise'), 45000);

const preservedHistPayment = await histPayment.get();
assert.equal(preservedHistPayment.exists, true);
assert.equal(preservedHistPayment.get('amountPaise'), 45000);

// Verify audit record was created
const headAuditQuery = await agency2
  .collection('auditRecords')
  .where('action', '==', 'agencyClosedAndOwnerDeleted')
  .where('actorId', '==', head.uid)
  .get();
assert.equal(headAuditQuery.empty, false);

// Verify Head is deleted from Firebase Auth
await assert.rejects(
  () => adminAuth.getUser(head.uid),
  (err) => err.code === 'auth/user-not-found',
);
process.stdout.write('✔ Head deletion closed agency, revoked pending invites, archived areas, and preserved financial records.\n');

process.stdout.write('\n--- 5. Testing Fresh Auth Verification & Security Guards ---\n');
// 5.1 Unverified email is rejected
const unverifiedUser = await createUserWithEmailAndPassword(
  clientAuth,
  'unverified-del@example.com',
  'password-123',
);
await assert.rejects(
  requestAccountDeletion({confirmation: 'DELETE'}),
  (err) => err.message.includes('Verify the account email before requesting account deletion') || err.code === 'functions/failed-precondition',
);

// 5.2 Unauthenticated call is rejected
await signOut(clientAuth);
await assert.rejects(
  requestAccountDeletion({confirmation: 'DELETE'}),
  (err) => err.code === 'functions/unauthenticated',
);

// 5.3 Fresh reauthentication succeeds
const freshUser = await verifiedIdentity('fresh-reauth-del@example.com');
// Force-refresh token to guarantee updated auth_time claim
await freshUser.getIdToken(true);
const freshResult = (await requestAccountDeletion({confirmation: 'DELETE'})).data;
assert.equal(freshResult.success, true);
assert.equal(freshResult.status, 'deleted');

// 5.4 Rejection of unknown / client authority fields
const probeUser = await verifiedIdentity('probe-user@example.com');
await assert.rejects(
  requestAccountDeletion({confirmation: 'DELETE', role: 'head', businessId: 'foreign-biz'}),
  (err) => err.message.includes('Unsupported request field') || err.code === 'functions/invalid-argument',
);
process.stdout.write('✔ Fresh auth and unauthenticated/unverified security guards verified.\n');

process.stdout.write('\nALL ACCOUNT DELETION INTEGRATION TESTS PASSED!\n');
