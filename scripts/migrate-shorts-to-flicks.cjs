#!/usr/bin/env node
/**
 * migrate-shorts-to-flicks.js
 *
 * One-time data migration that copies every document from the legacy
 * `shorts` Firestore collection into the new `flicks` collection
 * (including each doc's `events` subcollection).
 *
 * The collection was renamed from "shorts" to "flicks". App code, Cloud
 * Functions, security rules and indexes already point at `flicks`; this
 * script moves the existing data so nothing is stranded.
 *
 * AUTH
 *   Uses the access token already stored by the Firebase CLI
 *   (~/.config/configstore/firebase-tools.json). No service account or
 *   gcloud required. Run `firebase projects:list` first if the token is
 *   stale — this script also nudges a refresh automatically.
 *
 * SAFETY
 *   - Idempotent: copies using the same document IDs (overwrite, no dupes).
 *   - Non-destructive by default: source `shorts` docs are left intact.
 *     Pass --delete-source to remove them after a successful copy.
 *   - Dry run by default: pass --commit to actually write.
 *
 * USAGE
 *   node scripts/migrate-shorts-to-flicks.js                 # dry run
 *   node scripts/migrate-shorts-to-flicks.js --commit        # perform copy
 *   node scripts/migrate-shorts-to-flicks.js --commit --delete-source
 */

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const https = require('https');
const { execSync } = require('child_process');

const COMMIT = process.argv.includes('--commit');
const DELETE_SOURCE = process.argv.includes('--delete-source');
const PROJECT_ID =
  process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'mychannel-ca26d';

const CONFIG_PATH = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const FIRESTORE_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// ── Auth ─────────────────────────────────────────────────────────────────────

function getAccessToken() {
  // Nudge the Firebase CLI to refresh its token if it's close to expiry.
  try {
    const raw = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
    const expiresAt = raw.tokens && raw.tokens.expires_at ? raw.tokens.expires_at : 0;
    const secondsLeft = Math.floor(expiresAt / 1000 - Date.now() / 1000);
    if (secondsLeft < 120) {
      console.log('🔑 Access token stale — refreshing via Firebase CLI…');
      execSync('firebase projects:list --json', { stdio: 'ignore' });
    }
  } catch (_) {
    // If reading fails we'll fail clearly below.
  }

  const raw = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  const token = raw.tokens && raw.tokens.access_token;
  if (!token) {
    throw new Error(
      'No access token found. Run `firebase login` then `firebase projects:list` and retry.'
    );
  }
  return token;
}

// ── REST helpers ─────────────────────────────────────────────────────────────

function request(method, url, token, body) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const payload = body ? JSON.stringify(body) : null;
    const req = https.request(
      {
        method,
        hostname: u.hostname,
        path: u.pathname + u.search,
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
          ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(data ? JSON.parse(data) : {});
          } else {
            reject(new Error(`${method} ${url} → ${res.statusCode}: ${data}`));
          }
        });
      }
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

// List all documents in a collection (handles pagination).
async function listDocuments(token, collectionPath) {
  const docs = [];
  let pageToken = '';
  do {
    const url = `${FIRESTORE_BASE}/${collectionPath}?pageSize=300${
      pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''
    }`;
    const res = await request('GET', url, token);
    if (res.documents) docs.push(...res.documents);
    pageToken = res.nextPageToken || '';
  } while (pageToken);
  return docs;
}

// Extract the doc ID from a full Firestore document name.
function docId(name) {
  return name.split('/').pop();
}

// Write a document (PATCH = create or overwrite at a known path).
async function writeDocument(token, collectionPath, id, fields) {
  const url = `${FIRESTORE_BASE}/${collectionPath}/${encodeURIComponent(id)}`;
  return request('PATCH', url, token, { fields });
}

async function deleteDocument(token, collectionPath, id) {
  const url = `${FIRESTORE_BASE}/${collectionPath}/${encodeURIComponent(id)}`;
  return request('DELETE', url, token);
}

// ── Migration ────────────────────────────────────────────────────────────────

async function migrate() {
  console.log(`\n🔁 Migrating "shorts" → "flicks" on project: ${PROJECT_ID}`);
  console.log(`   mode: ${COMMIT ? 'COMMIT (writing)' : 'DRY RUN (no writes)'}`);
  console.log(`   delete source after copy: ${DELETE_SOURCE ? 'YES' : 'no'}\n`);

  const token = getAccessToken();
  const stats = { docs: 0, events: 0, deleted: 0 };

  const shorts = await listDocuments(token, 'shorts');
  if (shorts.length === 0) {
    console.log('✅ No documents in "shorts". Nothing to migrate.');
    return stats;
  }
  console.log(`Found ${shorts.length} document(s) in "shorts".\n`);

  for (const doc of shorts) {
    const id = docId(doc.name);
    if (COMMIT) {
      await writeDocument(token, 'flicks', id, doc.fields || {});
    }
    stats.docs++;

    // Copy the events subcollection (engagement counters).
    let events = [];
    try {
      events = await listDocuments(token, `shorts/${id}/events`);
    } catch (_) {
      events = [];
    }
    for (const ev of events) {
      const evId = docId(ev.name);
      if (COMMIT) {
        await writeDocument(token, `flicks/${id}/events`, evId, ev.fields || {});
      }
      stats.events++;
    }

    if (stats.docs % 25 === 0) console.log(`  …processed ${stats.docs} docs`);
  }

  if (COMMIT && DELETE_SOURCE) {
    console.log('\n🗑  Deleting source documents from "shorts"…');
    for (const doc of shorts) {
      const id = docId(doc.name);
      try {
        const events = await listDocuments(token, `shorts/${id}/events`);
        for (const ev of events) {
          await deleteDocument(token, `shorts/${id}/events`, docId(ev.name));
        }
      } catch (_) {
        /* no events */
      }
      await deleteDocument(token, 'shorts', id);
      stats.deleted++;
    }
  }

  return stats;
}

migrate()
  .then((stats) => {
    console.log('\n──────────────────────────────');
    console.log(`Docs processed:     ${stats.docs}`);
    console.log(`Event docs:         ${stats.events}`);
    console.log(`Source deleted:     ${stats.deleted}`);
    console.log('──────────────────────────────');
    if (!COMMIT) {
      console.log('\nℹ️  This was a DRY RUN. Re-run with --commit to apply.');
    } else {
      console.log('\n✅ Migration complete.');
    }
    process.exit(0);
  })
  .catch((err) => {
    console.error('\n❌ Migration failed:', err.message);
    process.exit(1);
  });
