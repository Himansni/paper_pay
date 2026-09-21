import {spawn} from 'node:child_process';
import {createRequire} from 'node:module';

const require = createRequire(new URL('../functions/package.json', import.meta.url));
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const projectId = 'demo-paper-route';

for (const host of [process.env.FIRESTORE_EMULATOR_HOST, process.env.FIREBASE_AUTH_EMULATOR_HOST]) {
  if (!host || (!host.startsWith('127.0.0.1:') && !host.startsWith('localhost:'))) {
    throw new Error('Employee invitation workflow requires local emulators.');
  }
}

await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/emulator/v1/projects/${projectId}/accounts`, {method: 'DELETE'});
await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`, {method: 'DELETE'});

const app = initializeApp({projectId}, 'employee-invitation-smoke');
const auth = getAuth(app);
const db = getFirestore(app);
const head = await auth.createUser({
  email: 'employee-flow-head@example.test',
  password: 'Employee-Smoke-2026!',
  displayName: 'Flow Head',
  emailVerified: true,
});
const now = Timestamp.now();
await db.doc('businesses/employee-flow-business').set({
  businessId: 'employee-flow-business', ownerId: head.uid,
  name: 'Employee Flow Agency', phone: '9000000000', createdAt: now, updatedAt: now,
});
await db.doc(`businesses/employee-flow-business/members/${head.uid}`).set({
  businessId: 'employee-flow-business', uid: head.uid,
  email: 'employee-flow-head@example.test', displayName: 'Flow Head', phone: '9000000000',
  role: 'head', status: 'active', permissions: [], areaIds: [], createdAt: now, updatedAt: now,
});
await db.doc(`userProfiles/${head.uid}`).set({
  uid: head.uid, email: 'employee-flow-head@example.test', displayName: 'Flow Head',
  phone: '9000000000', businessId: 'employee-flow-business', role: 'head', status: 'active',
  permissions: [], createdAt: now, updatedAt: now,
});
await db.doc('businesses/employee-flow-business/areas/employee-area').set({
  businessId: 'employee-flow-business', name: 'Employee Area', normalizedName: 'employee area',
  status: 'active', assignedEmployeeIds: [], createdBy: head.uid, createdAt: now, updatedAt: now,
});

function runFlutter() {
  return new Promise((resolve, reject) => {
    const child = spawn('flutter', ['run', '-d', 'chrome', '--target',
      'integration_test/employee_invitation_activation_smoke_test.dart',
      '--dart-define=USE_FIREBASE_EMULATORS=true'], {env: process.env, stdio: ['pipe', 'pipe', 'pipe']});
    let output = '';
    let ending = false;
    const inspect = (chunk, stream) => {
      stream.write(chunk); output += chunk.toString();
      if (!ending && (output.includes('All tests passed!') || output.includes('Some tests failed.'))) {
        ending = true; child.stdin.write('q\n'); child.stdin.end();
      }
    };
    child.stdout.on('data', (chunk) => inspect(chunk, process.stdout));
    child.stderr.on('data', (chunk) => inspect(chunk, process.stderr));
    child.on('error', reject);
    child.on('close', (code) => {
      const clean = output.replace(/\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])/g, '');
      if (code !== 0 || !clean.includes('All tests passed!') || clean.includes('Some tests failed.')) {
        reject(new Error(`Employee Flutter workflow failed with exit code ${code}.`));
      } else resolve();
    });
  });
}

async function verifyEmployeeEmail() {
  for (let attempt = 0; attempt < 240; attempt += 1) {
    try {
      const user = await auth.getUserByEmail('invited-employee@example.test');
      // Let AuthGate render the unverified state before simulating the local
      // emulator verification link.
      await new Promise((resolve) => setTimeout(resolve, 2_000));
      await auth.updateUser(user.uid, {emailVerified: true});
      return;
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
  }
  throw new Error('Timed out waiting for the synthetic employee Auth account.');
}

try {
  await Promise.all([runFlutter(), verifyEmployeeEmail()]);
  const employees = await db.collection('businesses/employee-flow-business/members')
    .where('role', '==', 'employee').get();
  if (employees.size !== 1) {
    throw new Error(`Expected one employee membership, found ${employees.size}.`);
  }
  const member = employees.docs[0];
  const invitationId = member.get('acceptedInviteId');
  const invitation = await db.doc(
    `businesses/employee-flow-business/invitations/${invitationId}`,
  ).get();
  if (invitation.get('status') !== 'accepted' || invitation.get('acceptedBy') !== member.id) {
    throw new Error('Accepted invitation history does not match the employee membership.');
  }
  process.stdout.write('\nConnected employee invitation workflow passed locally.\n');
} finally {
  await deleteApp(app);
}
