// MyChannel Content ID — acoustic fingerprinting service.
//
// Real audio fingerprinting using Chromaprint (fpcalc) + ffmpeg.
// Pipeline:
//   1. Reference registration: rights holder uploads a track → we extract
//      a Chromaprint fingerprint and store it in Postgres (pgvector-free,
//      we use a compact integer-array compare for the MVP).
//   2. Scan: when a video is uploaded, extract its audio fingerprint and
//      compare against all reference fingerprints. If similarity exceeds a
//      threshold, write a Content ID claim back to Firestore and apply policy.
//
// Endpoints:
//   GET  /health
//   POST /protect/register      { referenceId, audioUrl, ownerId, policy, title }
//   POST /protect/scan          { videoId, audioUrl, creatorId }
//   POST /protect/compare       { fpA, fpB }  (debug)
//
// Auth: internal — called by Cloud Functions via Google ID token, or by the
// gateway. Firestore writes use the Admin SDK.

import Fastify from 'fastify'
import cors from '@fastify/cors'
import helmet from '@fastify/helmet'
import rate from '@fastify/rate-limit'
import pkg from 'pg'
import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
import { promises as fs } from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import crypto from 'node:crypto'
import admin from 'firebase-admin'

const { Pool } = pkg
const execFileAsync = promisify(execFile)

const app = Fastify({ logger: true, bodyLimit: 5 * 1024 * 1024 })
await app.register(cors)
await app.register(helmet)
await app.register(rate, { max: 120, timeWindow: '1 minute' })

const pool = new Pool({ connectionString: process.env.DATABASE_URL })

// Firebase Admin (uses Application Default Credentials on Cloud Run)
if (!admin.apps.length) {
  admin.initializeApp()
}
const db = admin.firestore()

// Similarity threshold — Chromaprint fingerprints matched by Hamming distance
// over the 32-bit sub-fingerprint frames. 0.85 = strong match (low false positive).
const MATCH_THRESHOLD = 0.85
const MIN_MATCH_FRAMES = 50  // require at least 50 overlapping frames

// ─── Helpers ─────────────────────────────────────────────────────────────────

async function downloadToTmp(url) {
  const res = await fetch(url)
  if (!res.ok) throw new Error(`download failed: ${res.status}`)
  const buf = Buffer.from(await res.arrayBuffer())
  const tmp = path.join(os.tmpdir(), `cid_${crypto.randomBytes(8).toString('hex')}`)
  await fs.writeFile(tmp, buf)
  return tmp
}

// Extract a Chromaprint fingerprint (array of 32-bit integers) using fpcalc.
// fpcalc handles ffmpeg-based decoding internally for most container formats.
async function extractFingerprint(filePath) {
  // -raw outputs comma-separated integer fingerprint frames
  // -length 120 caps analysis at first 120 seconds (cost control)
  const { stdout } = await execFileAsync('fpcalc', ['-raw', '-length', '120', filePath], {
    maxBuffer: 16 * 1024 * 1024,
  })
  const m = stdout.match(/FINGERPRINT=([\d,]+)/)
  if (!m) throw new Error('fpcalc produced no fingerprint')
  const frames = m[1].split(',').map((n) => parseInt(n, 10) >>> 0)
  return frames
}

// Popcount for 32-bit int (number of set bits).
function popcount32(x) {
  x = x - ((x >>> 1) & 0x55555555)
  x = (x & 0x33333333) + ((x >>> 2) & 0x33333333)
  x = (x + (x >>> 4)) & 0x0f0f0f0f
  return (x * 0x01010101) >>> 24
}

// Best-offset similarity between two fingerprint frame arrays.
// Slides one fingerprint over the other and finds the alignment with the
// lowest average bit-error rate (BER). Returns { score, frames }.
function compareFingerprints(a, b) {
  if (!a.length || !b.length) return { score: 0, frames: 0 }
  // Make `a` the shorter one for the sliding window.
  let short = a, long = b
  if (a.length > b.length) { short = b; long = a }

  const maxOffset = long.length - short.length
  let best = { score: 0, frames: 0 }

  // Limit offsets scanned to keep it O(n) — step through reasonable alignments.
  const offsetStep = Math.max(1, Math.floor(maxOffset / 200) || 1)

  for (let off = 0; off <= maxOffset; off += offsetStep) {
    let bitErrors = 0
    const frames = short.length
    for (let i = 0; i < frames; i++) {
      bitErrors += popcount32((short[i] ^ long[i + off]) >>> 0)
    }
    const ber = bitErrors / (frames * 32)        // 0 = identical, 0.5 = random
    const score = 1 - ber * 2                     // map 0.5 BER → 0 score
    if (score > best.score) best = { score, frames }
  }
  return best
}

// ─── Routes ──────────────────────────────────────────────────────────────────

app.get('/health', async () => ({ status: 'ok', service: 'content-id', ts: Date.now() }))

// Register a reference fingerprint (rights holder track).
app.post('/protect/register', async (req, reply) => {
  const { referenceId, audioUrl, ownerId, policy = 'track', title = '' } = req.body || {}
  if (!referenceId || !audioUrl) {
    return reply.code(400).send({ error: 'missing referenceId or audioUrl' })
  }

  let tmp
  try {
    tmp = await downloadToTmp(audioUrl)
    const fp = await extractFingerprint(tmp)

    await pool.query(
      `insert into reference_fingerprint(reference_id, owner_id, policy, title, fingerprint, frame_count, created_at)
       values($1,$2,$3,$4,$5,$6, now())
       on conflict (reference_id) do update set
         fingerprint = excluded.fingerprint,
         frame_count = excluded.frame_count,
         policy      = excluded.policy`,
      [referenceId, ownerId || null, policy, title, JSON.stringify(fp), fp.length]
    )

    // Mark the reference active in Firestore
    await db.collection('content_id_references').doc(referenceId).set({
      status: 'active',
      frameCount: fp.length,
      fingerprintedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true })

    return { ok: true, referenceId, frames: fp.length }
  } catch (err) {
    req.log.error({ err }, 'register failed')
    return reply.code(500).send({ error: String(err.message || err) })
  } finally {
    if (tmp) await fs.unlink(tmp).catch(() => {})
  }
})

// Scan a video's audio against all reference fingerprints.
app.post('/protect/scan', async (req, reply) => {
  const { videoId, audioUrl, creatorId } = req.body || {}
  if (!videoId || !audioUrl) {
    return reply.code(400).send({ error: 'missing videoId or audioUrl' })
  }

  let tmp
  try {
    tmp = await downloadToTmp(audioUrl)
    const videoFp = await extractFingerprint(tmp)

    // Load reference fingerprints (cap 1000 for the MVP; production uses an
    // approximate-nearest-neighbour index / partitioned scan).
    const { rows } = await pool.query(
      `select reference_id, owner_id, policy, title, fingerprint, frame_count
       from reference_fingerprint
       order by created_at desc
       limit 1000`
    )

    let bestMatch = null
    for (const row of rows) {
      const refFp = typeof row.fingerprint === 'string'
        ? JSON.parse(row.fingerprint)
        : row.fingerprint
      const { score, frames } = compareFingerprints(videoFp, refFp)
      if (score >= MATCH_THRESHOLD && frames >= MIN_MATCH_FRAMES) {
        if (!bestMatch || score > bestMatch.score) {
          bestMatch = { ...row, score, frames }
        }
      }
    }

    if (!bestMatch) {
      await db.collection('videos').doc(videoId).set({
        contentIdScanned: true,
        contentIdStatus: 'clear',
        contentIdMethod: 'acoustic',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true })
      return { ok: true, matched: false }
    }

    // Write a Content ID claim — same shape as the metadata-match path so the
    // dispute / policy flow is identical.
    const claimRef = db.collection('content_id_claims').doc()
    const now = admin.firestore.FieldValue.serverTimestamp()
    await claimRef.set({
      id: claimRef.id,
      videoId,
      videoCreatorId: creatorId || '',
      referenceId: bestMatch.reference_id,
      rightsHolderId: bestMatch.owner_id || '',
      referenceTitle: bestMatch.title || '',
      policy: bestMatch.policy || 'track',
      matchMethod: 'acoustic',
      matchScore: Number(bestMatch.score.toFixed(4)),
      status: 'active',
      createdAt: now,
    })

    const policy = bestMatch.policy || 'track'
    const videoUpdate = {
      contentIdScanned: true,
      contentIdStatus: 'claimed',
      contentIdClaimId: claimRef.id,
      contentIdPolicy: policy,
      contentIdMethod: 'acoustic',
      updatedAt: now,
    }
    if (policy === 'block') {
      videoUpdate.isPublic = false
      videoUpdate.status = 'blocked_content_id'
      videoUpdate.blockedReason = `Content ID match: ${bestMatch.title || ''}`
    } else if (policy === 'monetize') {
      videoUpdate.adRevenueBeneficiary = bestMatch.owner_id || ''
      videoUpdate.monetizedByClaim = true
    }
    await db.collection('videos').doc(videoId).set(videoUpdate, { merge: true })

    // Notify the uploader.
    if (creatorId) {
      const msg = {
        block: 'Your video has been blocked due to a copyright match.',
        monetize: 'A copyright claim was applied. Ad revenue goes to the rights holder. You can dispute this.',
        track: 'A copyright match was detected on your video (tracking only).',
      }[policy] || 'A Content ID match was detected.'
      await db.collection('notifications').add({
        userId: creatorId,
        type: 'content_id_claim',
        title: 'Content ID claim on your video',
        message: msg,
        videoId,
        claimId: claimRef.id,
        read: false,
        createdAt: now,
      })
    }

    return {
      ok: true,
      matched: true,
      referenceId: bestMatch.reference_id,
      score: Number(bestMatch.score.toFixed(4)),
      policy,
      claimId: claimRef.id,
    }
  } catch (err) {
    req.log.error({ err }, 'scan failed')
    // Don't block publishing on a scan failure — mark as scan_error.
    await db.collection('videos').doc(videoId).set({
      contentIdScanned: true,
      contentIdStatus: 'scan_error',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true }).catch(() => {})
    return reply.code(500).send({ error: String(err.message || err) })
  } finally {
    if (tmp) await fs.unlink(tmp).catch(() => {})
  }
})

// Debug: compare two raw fingerprint arrays.
app.post('/protect/compare', async (req, reply) => {
  const { fpA, fpB } = req.body || {}
  if (!Array.isArray(fpA) || !Array.isArray(fpB)) {
    return reply.code(400).send({ error: 'fpA and fpB must be integer arrays' })
  }
  return compareFingerprints(fpA.map((n) => n >>> 0), fpB.map((n) => n >>> 0))
})

const port = process.env.PORT || 9091
app.listen({ port, host: '0.0.0.0' })
