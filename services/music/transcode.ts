/**
 * transcode.ts — Audio transcoding + HLS packaging for MyChannel Music.
 *
 * Turns an uploaded master (WAV/FLAC/MP3/M4A) into:
 *   • An adaptive HLS ladder (AAC 64/128/256 kbps) for smooth streaming.
 *   • A normalized MP3 320 fallback.
 *   • (Optional) a lossless FLAC for hi-res/lossless tiers (Apple/Tidal parity).
 *   • Loudness-normalized output (EBU R128 / -14 LUFS, streaming standard).
 *
 * Requires ffmpeg on the runtime. On Cloud Run use a Docker image that installs
 * ffmpeg (see Dockerfile.transcode). The function downloads the master from
 * Storage, runs ffmpeg, uploads renditions, and writes URLs back to the track.
 *
 * Env:
 *   MUSIC_STORAGE_BUCKET  canonical Firebase Storage bucket (default <project>.firebasestorage.app)
 *   ENABLE_LOSSLESS       "true" to also produce FLAC (default "true")
 */

import express from 'express';
import admin from 'firebase-admin';
import { Storage } from '@google-cloud/storage';
import { OAuth2Client } from 'google-auth-library';
import { spawn } from 'child_process';
import { randomUUID } from 'crypto';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { chromaprintFile, fingerprintHash } from './fingerprint';

const app = express();
app.use(express.json({ limit: '10mb' }));

const PROJECT_ID = process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT || 'mychannel-ca26d';
const BUCKET_NAME = process.env.MUSIC_STORAGE_BUCKET ||
  process.env.FIREBASE_STORAGE_BUCKET ||
  process.env.MUSIC_BUCKET ||
  `${PROJECT_ID}.firebasestorage.app`;

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: PROJECT_ID,
    storageBucket: BUCKET_NAME,
  });
}

const db = admin.firestore();
const storage = new Storage({ projectId: PROJECT_ID });
const bucket = storage.bucket(BUCKET_NAME);
const ENABLE_LOSSLESS = (process.env.ENABLE_LOSSLESS || 'true') === 'true';
const oidcVerifier = new OAuth2Client();

async function requireUser(req: any, res: any) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Unauthorized' });
      return null;
    }
    const token = authHeader.split('Bearer ')[1];
    const decoded = await admin.auth().verifyIdToken(token);
    return {
      userId: decoded.uid,
      email: decoded.email,
      emailVerified: decoded.email_verified === true,
      isAdmin: decoded.admin === true
    };
  } catch {
    res.status(401).json({ error: 'Invalid token' });
    return null;
  }
}

async function requireTranscodeActor(req: any, res: any) {
  const authHeader = req.headers.authorization;
  if (typeof authHeader !== 'string' || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }
  const token = authHeader.slice('Bearer '.length).trim();
  if (!token) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }

  try {
    const decoded = await admin.auth().verifyIdToken(token);
    return {
      userId: decoded.uid,
      email: decoded.email,
      emailVerified: decoded.email_verified === true,
      isAdmin: decoded.admin === true,
      isService: false
    };
  } catch {
    const expectedEmail = (process.env.MUSIC_TRANSCODE_TASK_SERVICE_ACCOUNT || '').trim();
    const audience = (process.env.MUSIC_TRANSCODE_OIDC_AUDIENCE || '').trim();
    if (!expectedEmail || !audience) {
      res.status(401).json({ error: 'Invalid token' });
      return null;
    }
    try {
      const ticket = await oidcVerifier.verifyIdToken({ idToken: token, audience });
      const payload = ticket.getPayload();
      if (!payload || payload.email !== expectedEmail || payload.email_verified !== true) {
        res.status(403).json({ error: 'Untrusted transcode service identity' });
        return null;
      }
      return {
        userId: null,
        email: payload.email,
        emailVerified: true,
        isAdmin: false,
        isService: true
      };
    } catch {
      res.status(401).json({ error: 'Invalid token' });
      return null;
    }
  }
}

const ADMIN_EMAILS = new Set([
  'keontapeat@mychannel.live',
  'keontapeat@gmail.com'
]);

function userIsAdmin(user: any): boolean {
  return user?.isAdmin === true ||
    (user?.emailVerified === true && ADMIN_EMAILS.has(user.email));
}

function run(cmd: string, args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    const proc = spawn(cmd, args);
    let stderr = '';
    proc.stderr.on('data', (d) => (stderr += d.toString()));
    proc.on('error', reject);
    proc.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${cmd} exited ${code}: ${stderr.slice(-500)}`));
    });
  });
}

/** Download a validated in-bucket master object to a local temp file. */
async function downloadToTmp(masterPath: string, dest: string): Promise<void> {
  await bucket.file(masterPath).download({ destination: dest });
}

function isSafeTrackId(value: string): boolean {
  return /^[A-Za-z0-9_-]{1,128}$/.test(value);
}

/** Masters are accepted only from the upload service's deterministic private path. */
function validatedMasterPath(value: unknown, ownerId: string, trackId: string): string | null {
  if (typeof value !== 'string' || value.length > 512) return null;
  const segments = value.split('/');
  if (segments.length !== 4 || segments[0] !== 'music' ||
      segments[1] !== ownerId || segments[2] !== 'tracks') {
    return null;
  }
  const fileMatch = segments[3].match(/^([A-Za-z0-9_-]{1,128})\.(mp3|m4a|wav|flac|aac|ogg)$/);
  if (!fileMatch || fileMatch[1] !== trackId) return null;
  return value;
}

function publicRenditionURL(destination: string, downloadToken: string): string {
  return `https://firebasestorage.googleapis.com/v0/b/${encodeURIComponent(bucket.name)}` +
    `/o/${encodeURIComponent(destination)}?alt=media&token=${downloadToken}`;
}

function publicRenditions(track: Record<string, any>): Record<string, string> {
  const source = track.renditions && typeof track.renditions === 'object'
    ? track.renditions : {};
  const candidates: Record<string, unknown> = {
    hls: source.hls || track.hlsURL,
    mp3: source.mp3 || track.mp3URL,
    flac: source.flac || track.losslessURL
  };
  const renditions: Record<string, string> = {};
  for (const [key, value] of Object.entries(candidates)) {
    if (typeof value === 'string' && value.startsWith('https://')) renditions[key] = value;
  }
  return renditions;
}

async function uploadPublicRendition(
  localPath: string,
  destination: string,
  contentType: string,
  downloadToken: string
): Promise<void> {
  await bucket.upload(localPath, {
    destination,
    metadata: {
      contentType,
      cacheControl: 'public, max-age=31536000, immutable',
      metadata: { firebaseStorageDownloadTokens: downloadToken },
    },
  });
}

// POST /v1/music/transcode/:trackId — produce HLS + fallbacks for a track
app.post('/v1/music/transcode/:trackId', async (req, res) => {
  const actor = await requireTranscodeActor(req, res);
  if (!actor) return;

  const body = req.body && typeof req.body === 'object' && !Array.isArray(req.body)
    ? req.body as Record<string, unknown> : {};
  const bodyKeys = Object.keys(body);
  const ownerUid = actor.isService ? body.ownerUid : actor.userId;
  if (typeof ownerUid !== 'string' || !isSafeTrackId(ownerUid) ||
      (actor.isService
        ? bodyKeys.length !== 1 || bodyKeys[0] !== 'ownerUid'
        : bodyKeys.length !== 0)) {
    return res.status(400).json({ error: 'Invalid owner-bound transcode request' });
  }
  const user = { ...actor, userId: ownerUid };

  const { trackId } = req.params;
  if (!isSafeTrackId(trackId)) return res.status(400).json({ error: 'Invalid trackId' });

  const trackRef = db.collection('music_tracks').doc(trackId);
  const processingRef = db.collection('music_track_processing').doc(trackId);
  const [trackSnap, processingSnap] = await Promise.all([trackRef.get(), processingRef.get()]);
  if (!trackSnap.exists) return res.status(404).json({ error: 'Track not found' });

  const track = trackSnap.data()!;
  if (String(track.artistId || '') !== user.userId) {
    return res.status(403).json({ error: 'Forbidden' });
  }
  if (processingSnap.exists && String(processingSnap.data()?.ownerUid || '') !== user.userId) {
    return res.status(409).json({ error: 'Private processing ownership does not match the track owner' });
  }

  const claim = await db.runTransaction(async (transaction) => {
    const [currentTrackSnap, currentProcessingSnap] = await Promise.all([
      transaction.get(trackRef),
      transaction.get(processingRef)
    ]);
    if (!currentTrackSnap.exists) return { error: 'Track not found', status: 404 };
    const currentTrack = currentTrackSnap.data()!;
    if (String(currentTrack.artistId || '') !== user.userId) {
      return { error: 'Forbidden', status: 403 };
    }
    const processing = currentProcessingSnap.exists ? currentProcessingSnap.data()! : null;
    if (processing && String(processing.ownerUid || '') !== user.userId) {
      return { error: 'Private processing ownership does not match the track owner', status: 409 };
    }
    if (currentTrack.transcodingStatus === 'completed' || processing?.processingStatus === 'completed') {
      return { completed: true };
    }
    if (currentTrack.transcodingStatus === 'in_progress' || processing?.processingStatus === 'in_progress') {
      return { inProgress: true };
    }

    // Legacy fallback is owner-bound and is migrated out of the public track atomically.
    const masterPath = validatedMasterPath(
      processing?.masterPath ?? currentTrack.masterPath,
      user.userId,
      trackId
    );
    if (!masterPath) return { error: 'Track has no valid deterministic private masterPath', status: 409 };

    transaction.update(trackRef, {
      audioURL: admin.firestore.FieldValue.delete(),
      masterURL: admin.firestore.FieldValue.delete(),
      masterPath: admin.firestore.FieldValue.delete(),
      masterSizeBytes: admin.firestore.FieldValue.delete(),
      masterContentType: admin.firestore.FieldValue.delete(),
      transcodingStatus: 'in_progress',
      transcodeStartedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    transaction.set(processingRef, {
      schemaVersion: 1,
      trackId,
      ownerUid: user.userId,
      masterPath,
      masterSizeBytes: processing?.masterSizeBytes ?? currentTrack.masterSizeBytes ?? null,
      masterContentType: processing?.masterContentType ?? currentTrack.masterContentType ?? null,
      processingStatus: 'in_progress',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: processing?.createdAt || admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    return { started: true, masterPath };
  });

  if ('error' in claim) return res.status(claim.status).json({ error: claim.error });
  if ('completed' in claim) {
    return res.json({ trackId, status: 'completed', renditions: publicRenditions(track) });
  }
  if ('inProgress' in claim) {
    return res.status(202).json({ trackId, status: 'in_progress', idempotentReplay: true });
  }
  const masterPath = claim.masterPath!;
  const work = fs.mkdtempSync(path.join(os.tmpdir(), `mch_${trackId}_`));
  const masterLocal = path.join(work, 'master.input');

  try {
    // masterPath was generated by the upload service and never accepts a URL.
    await downloadToTmp(masterPath, masterLocal);

    const basePath = `music/${user.userId}/renditions/${trackId}`;
    const outputs: Record<string, string> = {};

    // Loudness normalization filter (streaming standard ~ -14 LUFS).
    const loudnorm = 'loudnorm=I=-14:TP=-1.0:LRA=11';

    // 1) HLS adaptive ladder: 3 AAC variants + master playlist.
    const hlsDir = path.join(work, 'hls');
    fs.mkdirSync(hlsDir, { recursive: true });
    const ladder = [
      { name: 'low', bitrate: '64k' },
      { name: 'mid', bitrate: '128k' },
      { name: 'high', bitrate: '256k' },
    ];
    for (const v of ladder) {
      await run('ffmpeg', [
        '-y', '-i', masterLocal,
        '-vn', '-af', loudnorm,
        '-c:a', 'aac', '-b:a', v.bitrate,
        '-hls_time', '6', '-hls_playlist_type', 'vod',
        '-hls_segment_filename', path.join(hlsDir, `${v.name}_%03d.aac`),
        path.join(hlsDir, `${v.name}.m3u8`),
      ]);
    }
    // Master playlist referencing the three variants.
    const masterM3U8 = [
      '#EXTM3U',
      '#EXT-X-VERSION:3',
      '#EXT-X-STREAM-INF:BANDWIDTH=72000,CODECS="mp4a.40.2"',
      'low.m3u8',
      '#EXT-X-STREAM-INF:BANDWIDTH=140000,CODECS="mp4a.40.2"',
      'mid.m3u8',
      '#EXT-X-STREAM-INF:BANDWIDTH=272000,CODECS="mp4a.40.2"',
      'high.m3u8',
    ].join('\n');
    fs.writeFileSync(path.join(hlsDir, 'master.m3u8'), masterM3U8);

    // Renditions use Firebase download tokens; the source master gets no token and remains private.
    const renditionToken = randomUUID();
    for (const file of fs.readdirSync(hlsDir)) {
      const localFile = path.join(hlsDir, file);
      const dest = `${basePath}/hls/${file}`;
      if (file.endsWith('.m3u8')) {
        const playlist = fs.readFileSync(localFile, 'utf8')
          .split('\n')
          .map((line) => line && !line.startsWith('#')
            ? publicRenditionURL(`${basePath}/hls/${line}`, renditionToken)
            : line)
          .join('\n');
        fs.writeFileSync(localFile, playlist);
      }
      await uploadPublicRendition(
        localFile,
        dest,
        file.endsWith('.m3u8') ? 'application/vnd.apple.mpegurl' : 'audio/aac',
        renditionToken
      );
    }
    outputs.hls = publicRenditionURL(`${basePath}/hls/master.m3u8`, renditionToken);

    // 2) MP3 320 fallback (normalized).
    const mp3Local = path.join(work, 'fallback.mp3');
    await run('ffmpeg', ['-y', '-i', masterLocal, '-vn', '-af', loudnorm, '-c:a', 'libmp3lame', '-b:a', '320k', mp3Local]);
    await uploadPublicRendition(mp3Local, `${basePath}/audio_320.mp3`, 'audio/mpeg', renditionToken);
    outputs.mp3 = publicRenditionURL(`${basePath}/audio_320.mp3`, renditionToken);

    // 3) Optional lossless FLAC (hi-res / lossless tier).
    if (ENABLE_LOSSLESS) {
      const flacLocal = path.join(work, 'lossless.flac');
      await run('ffmpeg', ['-y', '-i', masterLocal, '-vn', '-c:a', 'flac', flacLocal]);
      await uploadPublicRendition(flacLocal, `${basePath}/lossless.flac`, 'audio/flac', renditionToken);
      outputs.flac = publicRenditionURL(`${basePath}/lossless.flac`, renditionToken);
    }

    // Probe duration so the catalog has accurate length.
    let duration = track.duration || 0;
    try {
      const probe = await new Promise<string>((resolve, reject) => {
        const p = spawn('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'default=nw=1:nk=1', masterLocal]);
        let out = '';
        p.stdout.on('data', (d) => (out += d.toString()));
        p.on('error', reject);
        p.on('close', () => resolve(out.trim()));
      });
      if (probe) duration = parseFloat(probe);
    } catch { /* keep existing duration */ }

    // Compute a REAL chromaprint fingerprint from the master and register it in
    // Content ID so this track is protected and can be matched against uploads.
    let fingerprintRegistered = false;
    try {
      const fp = await chromaprintFile(masterLocal);
      if (fp.frames.length > 0) {
        await db.collection('music_content_id').doc(trackId).set({
          trackId,
          artistId: user.userId,
          fingerprint: fp,
          fingerprintHash: fingerprintHash(fp),
          fingerprintProvider: 'chromaprint',
          registeredAt: admin.firestore.Timestamp.now(),
          status: 'active',
          copyrightPolicy: track.contentIdPolicy || 'strict',
          revenueSharePercentage: null,
          source: 'transcode_auto',
        }, { merge: true });
        fingerprintRegistered = true;
      }
    } catch (e: any) {
      console.warn(`Fingerprint skipped for ${trackId}: ${e.message}`);
    }

    const completionBatch = db.batch();
    completionBatch.update(trackRef, {
      audioURL: admin.firestore.FieldValue.delete(),
      masterURL: admin.firestore.FieldValue.delete(),
      masterPath: admin.firestore.FieldValue.delete(),
      masterSizeBytes: admin.firestore.FieldValue.delete(),
      masterContentType: admin.firestore.FieldValue.delete(),
      transcodeError: admin.firestore.FieldValue.delete(),
      transcodingStatus: 'completed',
      transcodeCompletedAt: admin.firestore.Timestamp.now(),
      hlsURL: outputs.hls,
      streamURL: outputs.hls, // app plays HLS by default
      mp3URL: outputs.mp3,
      losslessURL: outputs.flac || null,
      hasLossless: !!outputs.flac,
      contentIdRegistered: fingerprintRegistered,
      duration,
      renditions: outputs,
    });
    completionBatch.set(processingRef, {
      processingStatus: 'completed',
      transcodeCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
      transcodeError: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    await completionBatch.commit();

    res.json({ trackId, status: 'completed', renditions: outputs, duration, fingerprintRegistered });
  } catch (error: any) {
    console.error('Transcode error:', error);
    const failureBatch = db.batch();
    failureBatch.update(trackRef, {
      transcodingStatus: 'error',
      transcodeError: admin.firestore.FieldValue.delete()
    });
    failureBatch.set(processingRef, {
      processingStatus: 'error',
      transcodeError: String(error?.message || 'Transcode failed').slice(0, 500),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    await failureBatch.commit().catch(() => {});
    res.status(500).json({ error: 'Transcode failed' });
  } finally {
    fs.rmSync(work, { recursive: true, force: true });
  }
});

// GET /v1/music/transcode/:trackId/status
app.get('/v1/music/transcode/:trackId/status', async (req, res) => {
  const { trackId } = req.params;
  if (!isSafeTrackId(trackId)) return res.status(400).json({ error: 'Invalid trackId' });

  const snap = await db.collection('music_tracks').doc(trackId).get();
  if (!snap.exists) return res.status(404).json({ error: 'Track not found' });
  const track = snap.data()!;
  const isPublished = track.isPublished === true && track.status === 'published';
  if (!isPublished) {
    const user = await requireUser(req, res);
    if (!user) return;
    if (String(track.artistId || '') !== user.userId && !userIsAdmin(user)) {
      return res.status(403).json({ error: 'Forbidden' });
    }
  }

  return res.json({
    trackId,
    transcodingStatus: track.transcodingStatus || 'pending',
    renditions: publicRenditions(track)
  });
});

const PORT = process.env.PORT || 8090;
app.listen(PORT, () => {
  console.log(`🎵 Music transcode service listening on port ${PORT} (lossless=${ENABLE_LOSSLESS})`);
});
