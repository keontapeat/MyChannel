// Mint a Google access token from the Firebase CLI refresh token and grant
// allUsers the run.invoker role on the musicPayouts Cloud Run service.
const fs = require('fs');
const https = require('https');

const CONFIG = process.env.HOME + '/.config/configstore/firebase-tools.json';
// Firebase CLI public OAuth client (used by firebase-tools).
const CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const PROJECT = 'mychannel-ca26d';
const REGION = 'us-east1';
const SERVICE = 'musicpayouts';

function post(host, path, bodyObj, headers) {
  return new Promise((resolve, reject) => {
    const body = typeof bodyObj === 'string' ? bodyObj : JSON.stringify(bodyObj);
    const req = https.request(
      { host, path, method: 'POST', headers: Object.assign({ 'Content-Length': Buffer.byteLength(body) }, headers) },
      (res) => {
        let d = '';
        res.on('data', (c) => (d += c));
        res.on('end', () => resolve({ status: res.statusCode, body: d }));
      }
    );
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function get(host, path, headers) {
  return new Promise((resolve, reject) => {
    const req = https.request({ host, path, method: 'GET', headers }, (res) => {
      let d = '';
      res.on('data', (c) => (d += c));
      res.on('end', () => resolve({ status: res.statusCode, body: d }));
    });
    req.on('error', reject);
    req.end();
  });
}

(async () => {
  const j = JSON.parse(fs.readFileSync(CONFIG, 'utf8'));
  const refresh = j.tokens && j.tokens.refresh_token;
  if (!refresh) {
    console.log('NO_REFRESH_TOKEN');
    return;
  }

  const tokenRes = await post(
    'oauth2.googleapis.com',
    '/token',
    `client_id=${encodeURIComponent(CLIENT_ID)}&client_secret=${encodeURIComponent(CLIENT_SECRET)}&refresh_token=${encodeURIComponent(refresh)}&grant_type=refresh_token`,
    { 'Content-Type': 'application/x-www-form-urlencoded' }
  );
  const tok = JSON.parse(tokenRes.body || '{}');
  if (!tok.access_token) {
    console.log('TOKEN_FAIL', tokenRes.status, tokenRes.body.slice(0, 300));
    return;
  }
  const auth = { Authorization: 'Bearer ' + tok.access_token, 'Content-Type': 'application/json' };
  const runHost = `${REGION}-run.googleapis.com`;
  const resPath = `/v2/projects/${PROJECT}/locations/${REGION}/services/${SERVICE}`;

  const getPol = await get(runHost, `${resPath}:getIamPolicy`, auth);
  console.log('GET_IAM', getPol.status);
  let policy = {};
  try { policy = JSON.parse(getPol.body || '{}'); } catch (e) {}
  if (getPol.status !== 200) {
    console.log('GET_IAM_BODY', getPol.body.slice(0, 400));
  }

  const bindings = policy.bindings || [];
  let inv = bindings.find((b) => b.role === 'roles/run.invoker');
  if (!inv) {
    inv = { role: 'roles/run.invoker', members: [] };
    bindings.push(inv);
  }
  if (!inv.members.includes('allUsers')) inv.members.push('allUsers');

  const setPol = await post(runHost, `${resPath}:setIamPolicy`, { policy: { bindings } }, auth);
  console.log('SET_IAM', setPol.status, setPol.body.slice(0, 400));
})();
