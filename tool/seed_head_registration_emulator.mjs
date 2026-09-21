const projectId = 'demo-paper-route';
const authBase = 'http://127.0.0.1:9099';
const firestoreBase =
  `http://127.0.0.1:8080/emulator/v1/projects/${projectId}/databases/(default)/documents`;

for (const target of [authBase, firestoreBase]) {
  if (!target.startsWith('http://127.0.0.1:')) {
    throw new Error('Registration seed must target local emulators.');
  }
}

await fetch(`${authBase}/emulator/v1/projects/${projectId}/accounts`, {
  method: 'DELETE',
});
await fetch(firestoreBase, {method: 'DELETE'});

const signUp = await fetch(
  `${authBase}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-api-key`,
  {
    method: 'POST',
    headers: {'content-type': 'application/json'},
    body: JSON.stringify({
      email: 'flutter-owner@example.test',
      password: 'Owner-Smoke-2026!',
      displayName: 'Flutter Owner',
      returnSecureToken: true,
    }),
  },
);
if (!signUp.ok) throw new Error(await signUp.text());
const account = await signUp.json();
const verify = await fetch(
  `${authBase}/identitytoolkit.googleapis.com/v1/accounts:update?key=demo-api-key`,
  {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: 'Bearer owner',
    },
    body: JSON.stringify({localId: account.localId, emailVerified: true}),
  },
);
if (!verify.ok) throw new Error(await verify.text());
process.stdout.write('Verified synthetic owner seeded in local Auth emulator.\n');
