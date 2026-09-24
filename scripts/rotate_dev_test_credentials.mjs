import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

function generateSecurePassword() {
  const bytes = crypto.randomBytes(24).toString('base64url');
  return `PR_${bytes}_!9Aa`;
}

const headPassword = generateSecurePassword();
const empPassword = generateSecurePassword();

const envContent = [
  `# Secure Gitignored Local Dev Credentials for paperroutedev`,
  `FOUNDER_HEAD_PASSWORD='${headPassword}'`,
  `FOUNDER_EMP_PASSWORD='${empPassword}'`,
  ``
].join('\n');

const jsonContent = JSON.stringify({
  FOUNDER_HEAD_PASSWORD: headPassword,
  FOUNDER_EMP_PASSWORD: empPassword,
}, null, 2);

fs.writeFileSync('.env.paperroutedev', envContent, { mode: 0o600 });
fs.writeFileSync('.env.paperroutedev.json', jsonContent, { mode: 0o600 });

console.log('[SUCCESS] Generated new cryptographically secure random passwords in gitignored local configuration files (.env.paperroutedev, .env.paperroutedev.json).');
