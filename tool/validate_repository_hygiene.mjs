// BEGINNER NOTE:
// [Repository Hygiene & Sensitive File Protection]
// This script acts as a security gate in CI to prevent accidental credential leaks.
// Sensitive assets must NEVER be checked into Git:
// - Android signing keystores (*.jks, *.keystore) and `key.properties`
// - Environment variable files containing secrets (.env)
// - Google Cloud Service Account JSON credentials
// - Private encryption/signing keys (RSA, EC, OPENSSH)
// - Build artifacts (node_modules, build/, .dart_tool)
// Once a secret is committed to Git history, it must be considered compromised.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

// Include both committed files and the complete proposed commit, while letting
// .gitignore exclude caches/build products. This prevents a new untracked secret
// from escaping the release gate before it is staged.
const tracked = execFileSync('git', [
  'ls-files',
  '--cached',
  '--others',
  '--exclude-standard',
  '-z',
])
  .toString()
  .split('\0')
  .filter(Boolean);

const forbiddenPaths = [
  /(^|\/)\.env($|\.)/,
  /(^|\/)key\.properties$/,
  /(^|\/).*\.(?:jks|keystore|p12|pfx|pem|key)$/i,
  /service[-_]?account/i,
  /application_default_credentials\.json$/,
  /(^|\/)firebase-export\//,
  /(^|\/)build\//,
  /(^|\/)\.dart_tool\//,
  /(^|\/)node_modules\//,
];
for (const path of tracked) {
  assert.ok(
    !forbiddenPaths.some((pattern) => pattern.test(path)),
    `sensitive or generated path is tracked: ${path}`,
  );
}

for (const path of tracked.filter((item) => !item.endsWith('.lock'))) {
  let content;
  try {
    content = readFileSync(path, 'utf8');
  } catch {
    continue;
  }
  assert.ok(
    !/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/.test(content),
    `private key material found in ${path}`,
  );
}

process.stdout.write(
  `Repository hygiene valid (${tracked.length} versionable files)\n`,
);
