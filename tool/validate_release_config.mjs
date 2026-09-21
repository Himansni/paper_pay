import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';

const developmentProject = 'paperroutedev';
const developmentPackage = 'in.paperroute.paper_route';
const productionPackage = 'in.paperroute.paper_route.prod';
const production = process.argv.includes('--production');

const firebase = JSON.parse(readFileSync('firebase.json', 'utf8'));
assert.equal(firebase.functions?.source, 'functions');
assert.equal(firebase.emulators?.functions?.port, 5001);
const devPath =
  firebase.flutter?.platforms?.android?.development?.fileOutput;
assert.equal(
  firebase.flutter?.platforms?.android?.development?.projectId,
  developmentProject,
  'firebase.json development target must remain paperroutedev',
);
assert.equal(
  devPath,
  'android/app/src/development/google-services.json',
  'development google-services.json must remain flavor scoped',
);

const readGoogleServices = (path) => {
  assert.ok(existsSync(path), `missing ${path}`);
  const config = JSON.parse(readFileSync(path, 'utf8'));
  const packages = config.client.map(
    (client) => client.client_info?.android_client_info?.package_name,
  );
  return { projectId: config.project_info?.project_id, packages };
};

const development = readGoogleServices(devPath);
assert.equal(development.projectId, developmentProject);
assert.ok(development.packages.includes(developmentPackage));

const source = readFileSync('lib/core/config/app_environment.dart', 'utf8');
for (const guard of [
  "developmentProjectId = 'paperroutedev'",
  "emulatorProjectId = 'demo-paper-route'",
  "'PROD_FIREBASE_PROJECT_ID'",
  'projectId == developmentProjectId',
  'projectId == emulatorProjectId',
  "'PAPERROUTE_ENABLE_AGENCY_REGISTRATION'",
  'defaultValue: false',
]) {
  assert.ok(source.includes(guard), `environment guard missing: ${guard}`);
}

const functionsEnvironment = readFileSync(
  'functions/src/environment.ts',
  'utf8',
);
for (const guard of [
  'functionRegion = "asia-south1"',
  'minInstances: 0',
  'maxInstances: 2',
  'enforceAppCheck: false',
]) {
  assert.ok(
    functionsEnvironment.includes(guard),
    `owner provisioning runtime guard missing: ${guard}`,
  );
}

if (production) {
  const path = 'android/app/src/production/google-services.json';
  const config = readGoogleServices(path);
  assert.ok(
    config.projectId &&
      config.projectId !== developmentProject &&
      config.projectId !== 'demo-paper-route',
    'production must use a distinct non-demo Firebase project',
  );
  assert.ok(
    config.packages.includes(productionPackage),
    `production Firebase must register ${productionPackage}`,
  );
}

process.stdout.write(
  `Release configuration valid for ${production ? 'production' : 'development'}\n`,
);
