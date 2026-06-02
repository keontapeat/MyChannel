// Diagnostic: read IAM policy of existing Cloud Run services to see whether
// allUsers invoker is already present (i.e. whether public functions exist here).
const fs = require('fs');
const https = require('https');

const CONFIG = process.env.HOME + '/.config/configstore/firebase-tools.json';
const CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const PROJECT = 'mychannel-ca26d';

function post(host, path, body, headers) {
  return new Promise((resolve, reject) => {
    const b = typeof body === 'string' ? body : JSON.stringify(body);
    const req = https.request({ host, path, method: 'POST', headers: Object.assign({ 'Content-Length': Buffer.byteLength(b) }, headers) }, (res) => {
      let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => resolve({ status: res.statusCode, body: d }));
    });
    req.on('error', reject); req.write(b); req.end();
  });
}
function get(host, path, headers) {
  return new Promise((resolve, reject) => {
    const req = https.request({ host, path, method: 'GET', headers }, (res) => {
      let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => resolve({ status: res.statusCode, body: d }));
    });
    req.on('error', reject); req.end();
  });
}

(async () => {
  const j = JSON.parse(fs.readFileSync(CONFIG, 'utf8'));
  const refresh = j.tokens && j.tokens.refresh_token;
  const t = await post('oauth2.googleapis.com', '/token',
    `client_id=${encodeURIComponent(CLIENT_ID)}&client_secret=${encodeURIComponent(CLIENT_SECRET)}&refresh_token=${encodeURIComponent(refresh)}&grant_type=refresh_token`,
    { 'Content-Type': 'application/x-www-form-urlencoded' });
  const tok = JSON.parse(t.body || '{}');
  if (!tok.access_token) { console.log('TOKEN_FAIL', t.body.slice(0, 200)); return; }
  const auth = { Authorization: 'Bearer ' + tok.access_token, 'Content-Type': 'application/json' };

  // List us-central1 run services and inspect a couple known ones.
  const targets = [
    ['us-central1', 'ai-music'],
    ['us-central1', 'agentproxy'],
    ['us-east1', 'musicpayouts'],
  ];
  for (const [region, svc] of targets) {
    const host = `${region}-run.googleapis.com`;
    const p = `/v2/projects/${PROJECT}/locations/${region}/services/${svc}:getIamPolicy`;
    const r = await get(host, p, auth);
    let hasAllUsers = false;
    try {
      const pol = JSON.parse(r.body || '{}');
      hasAllUsers = (pol.bindings || []).some((b) => b.role === 'roles/run.invoker' && (b.members || []).includes('allUsers'));
    } catch (e) {}
    console.log(`${region}/${svc}: status=${r.status} allUsers=${hasAllUsers}`);
  }

  // Check the active org policy for allowedPolicyMemberDomains at project level.
  const orgHost = 'cloudresourcemanager.googleapis.com';
  const orgPath = `/v1/projects/${PROJECT}:getIamPolicy`;
  const op = await post(orgHost, orgPath, {}, auth);
  console.log('project getIamPolicy status=', op.status);
})();
