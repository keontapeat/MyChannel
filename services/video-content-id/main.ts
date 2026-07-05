import express from 'express';
import cors from 'cors';
import admin from 'firebase-admin';
import jwt from 'jsonwebtoken';
import { Storage } from '@google-cloud/storage';
import fs from 'fs/promises';
import os from 'os';
import path from 'path';
import {
  extractVideoFingerprint,
  compareVideoFingerprints,
  videoFingerprintHash,
  serializeFingerprint,
  deserializeFingerprint,
} from './fingerprint.js';

// Real general-video Content ID. Closes the gap where
// MyChannel/Core/Services/ContentIDService.swift simulated fingerprinting
// with `Task.sleep` + a naive character-set-overlap "similarity" score, and
// where only music had real matching (services/music/content-id.ts +
// fingerprint.ts, Chromaprint audio). This service does the video-frame
// equivalent using perceptual dHash (see fingerprint.ts) and writes to the
// SAME Firestore collections the iOS Content ID UI already reads:
//   content_id_references  — reference videos registered for protection
//   content_matches        — matches found when scanning an uploaded video
// (see firestore.rules for the existing schema/security rules on both).

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const storage = new Storage();
const JWT_SECRET = process.env.JWT_SECRET || '';
const MATCH_THRESHOLD = parseFloat(process.env.VIDEO_CONTENT_ID_MATCH_THRESHOLD || '0.90');
const REFERENCE_SCAN_LIMIT = parseInt(process.env.VIDEO_CONTENT_ID_SCAN_LIMIT || '500', 10);

type AuthenticatedUser = { userId: string; email: string | null };

async function verifyUser(authHeader: string | undefined): Promise<AuthenticatedUser | null> {
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;
  const token = authHeader.slice(7).trim();
  if (!token) return null;

  try {
    const decoded = await admin.auth().verifyIdToken(token);
    return { userId: decoded.uid, email: decoded.email || null };
  } catch {}

  if (!JWT_SECRET) return null;
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as any;
    const userId = String(decoded.userId || decoded.uid || '').trim();
    if (!userId) return null;
    return { userId, email: decoded.email || null };
  } catch {
    return null;
  }
}

async function requireUser(req: express.Request, res: express.Response): Promise<AuthenticatedUser | null> {
  const user = await verifyUser(req.headers.authorization);
  if (!user) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }
  return user;
}

/** Downloads a gs:// or https://storage.googleapis.com/... URL to a local temp file. */
async function downloadToTemp(sourceUri: string): Promise<string> {
  let bucketName: string;
  let objectPath: string;

  if (sourceUri.startsWith('gs://')) {
    const withoutScheme = sourceUri.slice('gs://'.length);
    const slashIndex = withoutScheme.indexOf('/');
    bucketName = withoutScheme.slice(0, slashIndex);
    objectPath = withoutScheme.slice(slashIndex + 1);
  } else {
    const match = sourceUri.match(/storage\.googleapis\.com\/([^/]+)\/(.+)$/);
    if (!match) throw new Error(`Unsupported source URI: ${sourceUri}`);
    bucketName = match[1];
    objectPath = decodeURIComponent(match[2]);
  }

  const tempPath = path.join(os.tmpdir(), `content-id-${Date.now()}-${Math.random().toString(36).slice(2)}.mp4`);
  await storage.bucket(bucketName).file(objectPath).download({ destination: tempPath });
  return tempPath;
}

/** ffprobe-free duration lookup via Firestore video doc (already populated by transcode). */
async function getVideoDurationSeconds(videoId: string): Promise<number> {
  const snap = await db.collection('videos').doc(videoId).get();
  const duration = Number(snap.data()?.duration || 0);
  return duration > 0 ? duration : 0;
}

const app = express();
app.use(cors());
app.use(express.json({ limit: '2mb' }));

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// POST /v1/video/content-id/register
// Registers a video as a Content ID reference the owner wants protected.
// Body: { videoId, sourceUri (gs:// or storage.googleapis.com URL), policy }
app.post('/v1/video/content-id/register', async (req, res) => {
  let tempPath: string | null = null;
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { videoId, sourceUri, policy, title, rightsholder } = req.body || {};
    if (!videoId || typeof videoId !== 'string') {
      return res.status(400).json({ error: 'videoId is required' });
    }
    if (!sourceUri || typeof sourceUri !== 'string') {
      return res.status(400).json({ error: 'sourceUri is required (gs:// or storage.googleapis.com URL)' });
    }
    const validPolicies = ['block', 'monetize', 'track', 'mute'];
    const resolvedPolicy = validPolicies.includes(policy) ? policy : 'track';

    const videoSnap = await db.collection('videos').doc(videoId).get();
    if (!videoSnap.exists) {
      return res.status(404).json({ error: 'Video not found' });
    }
    const videoData = videoSnap.data()!;
    if (String(videoData.creatorId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const duration = Number(videoData.duration || 0);
    if (duration <= 0) {
      return res.status(409).json({ error: 'Video duration is not yet known; try again after transcoding completes' });
    }

    tempPath = await downloadToTemp(sourceUri);
    const fingerprint = await extractVideoFingerprint(tempPath, duration);

    const referenceId = videoId; // one reference per source video
    const now = admin.firestore.Timestamp.now();

    await db.collection('content_id_references').doc(referenceId).set({
      title: title || videoData.title || 'Untitled',
      rightsholder: rightsholder || user.email || user.userId,
      ownerId: user.userId,
      sourceVideoId: videoId,
      fingerprints: {
        videoFingerprint: serializeFingerprint(fingerprint),
      },
      fingerprintHash: videoFingerprintHash(fingerprint),
      policy: resolvedPolicy,
      isActive: true,
      uploadedAt: now,
    }, { merge: true });

    res.json({
      referenceId,
      videoId,
      policy: resolvedPolicy,
      frameCount: fingerprint.frameHashes.length,
      status: 'registered',
    });
  } catch (error: any) {
    console.error('Video Content ID registration error:', error);
    res.status(500).json({ error: error?.message || 'Internal server error' });
  } finally {
    if (tempPath) await fs.rm(tempPath, { force: true }).catch(() => {});
  }
});

// POST /v1/video/content-id/scan
// Scans a candidate video against all active references. Called after
// transcoding completes (has a known duration + playable source).
// Body: { videoId, sourceUri }
app.post('/v1/video/content-id/scan', async (req, res) => {
  let tempPath: string | null = null;
  try {
    const { videoId, sourceUri } = req.body || {};
    if (!videoId || typeof videoId !== 'string') {
      return res.status(400).json({ error: 'videoId is required' });
    }
    if (!sourceUri || typeof sourceUri !== 'string') {
      return res.status(400).json({ error: 'sourceUri is required' });
    }

    const duration = await getVideoDurationSeconds(videoId);
    if (duration <= 0) {
      return res.status(409).json({ error: 'Video duration is not yet known; try again after transcoding completes' });
    }

    tempPath = await downloadToTemp(sourceUri);
    const candidate = await extractVideoFingerprint(tempPath, duration);

    const refsSnap = await db.collection('content_id_references')
      .where('isActive', '==', true)
      .limit(REFERENCE_SCAN_LIMIT)
      .get();

    const matches: Array<{
      referenceId: string;
      sourceVideoId: string;
      rightsholder: string;
      ownerId: string | null;
      policy: string;
      similarity: number;
    }> = [];

    for (const doc of refsSnap.docs) {
      // Never match a video against its own reference.
      if (doc.id === videoId) continue;

      const data = doc.data();
      const refFingerprint = deserializeFingerprint(data.fingerprints?.videoFingerprint);
      if (!refFingerprint) continue;

      const similarity = compareVideoFingerprints(candidate, refFingerprint);
      if (similarity >= MATCH_THRESHOLD) {
        matches.push({
          referenceId: doc.id,
          sourceVideoId: data.sourceVideoId || doc.id,
          rightsholder: data.rightsholder || '',
          ownerId: data.ownerId || null,
          policy: data.policy || 'track',
          similarity,
        });
      }
    }

    matches.sort((a, b) => b.similarity - a.similarity);

    const now = admin.firestore.Timestamp.now();
    const writtenMatches: string[] = [];

    for (const match of matches) {
      const matchRef = db.collection('content_matches').doc();
      await matchRef.set({
        sourceVideoId: match.sourceVideoId,
        matchedVideoId: videoId,
        matchType: 'video',
        confidence: match.similarity,
        timeRange: { start: 0, duration, sourceStart: 0 },
        rightsholder: match.rightsholder,
        ownerId: match.ownerId,
        policy: match.policy,
        claimId: null,
        status: 'active',
        createdAt: now,
      });
      writtenMatches.push(matchRef.id);

      // Apply policy immediately, same enforcement model as the music
      // Content ID scan (services/music/content-id.ts scan-video route).
      await applyMatchPolicy(videoId, match.policy, match.rightsholder, match.ownerId);
    }

    res.json({
      videoId,
      matchesFound: matches.length,
      matches: matches.map((m, i) => ({ ...m, matchId: writtenMatches[i] })),
    });
  } catch (error: any) {
    console.error('Video Content ID scan error:', error);
    res.status(500).json({ error: error?.message || 'Internal server error' });
  } finally {
    if (tempPath) await fs.rm(tempPath, { force: true }).catch(() => {});
  }
});

async function applyMatchPolicy(
  videoId: string,
  policy: string,
  rightsholder: string,
  ownerId: string | null
): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  switch (policy) {
    case 'block':
      await db.collection('videos').doc(videoId).set({
        visibility: 'blocked',
        blockReason: `Copyright match: ${rightsholder}`,
        blockedAt: now,
      }, { merge: true });
      break;
    case 'monetize':
      await db.collection('revenue_sharing').doc(`${videoId}_${rightsholder}`).set({
        videoId,
        rightsholder,
        ownerId,
        percentage: 0.5,
        startedAt: now,
        isActive: true,
      }, { merge: true });
      break;
    case 'track':
      await db.collection('content_usage_tracking').add({
        videoId,
        rightsholder,
        ownerId,
        trackedAt: now,
        views: 0,
        revenue: 0,
      });
      break;
    case 'mute':
      // Muting a time range requires a transcode re-mux pass — out of scope
      // for this service. Recorded so the studio UI can surface a manual
      // action item instead of silently doing nothing.
      await db.collection('content_usage_tracking').add({
        videoId,
        rightsholder,
        ownerId,
        trackedAt: now,
        views: 0,
        revenue: 0,
        pendingManualMute: true,
      });
      break;
  }
}

// GET /v1/video/content-id/video/:videoId/matches
app.get('/v1/video/content-id/video/:videoId/matches', async (req, res) => {
  try {
    const { videoId } = req.params;
    const snap = await db.collection('content_matches')
      .where('matchedVideoId', '==', videoId)
      .where('status', '==', 'active')
      .orderBy('createdAt', 'desc')
      .limit(50)
      .get();

    res.json({
      videoId,
      matchesFound: snap.size,
      matches: snap.docs.map((d) => ({ id: d.id, ...d.data() })),
    });
  } catch (error: any) {
    console.error('Get video matches error:', error);
    res.status(500).json({ error: error?.message || 'Internal server error' });
  }
});

// POST /v1/video/content-id/:matchId/dispute
app.post('/v1/video/content-id/:matchId/dispute', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { matchId } = req.params;
    const { reason, evidence } = req.body || {};
    if (!reason || typeof reason !== 'string') {
      return res.status(400).json({ error: 'reason is required' });
    }

    const matchRef = db.collection('content_matches').doc(matchId);
    const matchSnap = await matchRef.get();
    if (!matchSnap.exists) {
      return res.status(404).json({ error: 'Match not found' });
    }

    const now = admin.firestore.Timestamp.now();
    const disputeRef = db.collection('content_disputes').doc();
    await disputeRef.set({
      matchId,
      disputerId: user.userId,
      reason,
      evidence: Array.isArray(evidence) ? evidence : [],
      status: 'submitted',
      submittedAt: now,
    });

    await matchRef.set({ status: 'disputed', disputedAt: now }, { merge: true });

    // Restore the video to public pending review, same as the iOS flow.
    const matchData = matchSnap.data()!;
    if (matchData.matchedVideoId) {
      await db.collection('videos').doc(matchData.matchedVideoId).set({
        visibility: 'public',
        disputePending: true,
        restoredAt: now,
      }, { merge: true });
    }

    res.json({ disputeId: disputeRef.id, status: 'submitted' });
  } catch (error: any) {
    console.error('Dispute match error:', error);
    res.status(500).json({ error: error?.message || 'Internal server error' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`video content-id service (threshold=${MATCH_THRESHOLD}) listening on ${port}`));
