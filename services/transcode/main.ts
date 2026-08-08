import express from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import {Storage} from '@google-cloud/storage';
import {PubSub} from '@google-cloud/pubsub';
import {createClient} from '@supabase/supabase-js';
import ffmpeg from 'fluent-ffmpeg';
import path from 'node:path';
import os from 'node:os';
import fs from 'node:fs/promises';
import admin from 'firebase-admin';
import jwt from 'jsonwebtoken';
import {OAuth2Client} from 'google-auth-library';
import {createHash, randomUUID} from 'node:crypto';

if (!admin.apps.length) {
  admin.initializeApp();
}

const JWT_SECRET = process.env.JWT_SECRET || '';
const TRANSCODE_SERVICE_AUDIENCE = (process.env.TRANSCODE_SERVICE_AUDIENCE || '').replace(/\/$/, '');
const TRUSTED_INVOKER_EMAILS = new Set(
  (process.env.TRANSCODE_INVOKER_EMAILS || '')
    .split(',')
    .map(value => value.trim())
    .filter(Boolean),
);
const oidcClient = new OAuth2Client();

type AuthenticatedUser = {
  userId: string;
  email: string | null;
  isService: boolean;
};

// End users authenticate with Firebase. Trusted workers use a Google-issued
// OIDC token whose audience and service-account email are explicitly bound to
// this service. Internal JWTs are never service-authorized without that claim.
async function verifyUser(authHeader: string | undefined): Promise<AuthenticatedUser | null> {
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;
  const token = authHeader.slice(7).trim();
  if (!token) return null;

  try {
    const decoded = await admin.auth().verifyIdToken(token);
    return {userId: decoded.uid, email: decoded.email || null, isService: false};
  } catch {}

  if (TRANSCODE_SERVICE_AUDIENCE && TRUSTED_INVOKER_EMAILS.size > 0) {
    try {
      const ticket = await oidcClient.verifyIdToken({
        idToken: token,
        audience: TRANSCODE_SERVICE_AUDIENCE,
      });
      const payload = ticket.getPayload();
      const email = String(payload?.email || '');
      if (payload?.email_verified === true && TRUSTED_INVOKER_EMAILS.has(email)) {
        return {userId: email, email, isService: true};
      }
    } catch {}
  }

  if (!JWT_SECRET) return null;
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as any;
    const userId = String(decoded.userId || decoded.uid || '').trim();
    if (!userId) return null;
    return {
      userId,
      email: decoded.email || null,
      isService: decoded.service === true,
    };
  } catch {
    return null;
  }
}

async function requireUser(req: any, res: any): Promise<AuthenticatedUser | null> {
  const user = await verifyUser(req.headers.authorization);
  if (!user) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }
  return user;
}

const app = express();
const storage = new Storage();
const pubsub = new PubSub();
const supabase = process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_KEY
  ? createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY)
  : null;

const INGEST_BUCKET = process.env.INGEST_BUCKET || 'mychannel-ca26d.firebasestorage.app';
const OUTPUT_BUCKET = process.env.OUTPUT_BUCKET || 'mychannel-videos';
const THUMBNAIL_BUCKET = process.env.THUMBNAIL_BUCKET || 'mychannel-thumbnails';
const TRANSCODE_TOPIC = process.env.TRANSCODE_TOPIC || 'transcode-jobs';
const CDN_BASE_URL = (process.env.CDN_BASE_URL || '').replace(/\/$/, '');
const DEFAULT_QUALITIES = ['360p', '720p', '1080p'];
const JOB_LEASE_MS = 30 * 60 * 1000;
const JOB_LEASE_RENEW_MS = 5 * 60 * 1000;

function cleanId(value: unknown, field: string): string {
  const id = String(value || '').trim();
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(id)) throw new Error(`Invalid ${field}`);
  return id;
}

function cleanJobId(value: unknown): string {
  const id = String(value || '').trim();
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(id)) throw new Error('Invalid idempotency key');
  return id;
}

function cleanInputPath(value: unknown, ownerId: string, videoId: string): string {
  const inputPath = String(value || '').trim();
  const expected = `gs://${INGEST_BUCKET}/temp_uploads/${ownerId}/${videoId}/source.mp4`;
  if (inputPath !== expected || inputPath.includes('..') || inputPath.length > 1024) {
    throw new Error('Input must be the canonical owned ingest object');
  }
  return inputPath;
}

function parseQualities(value: unknown): string[] {
  const requested = value === undefined ? DEFAULT_QUALITIES : value;
  if (!Array.isArray(requested) || requested.length === 0 || requested.length > 8) {
    throw new Error('qualities must be a non-empty array');
  }
  const qualities = [...new Set(requested.map(item => String(item)))];
  if (qualities.some(quality =>
    !Object.prototype.hasOwnProperty.call(QUALITY_PRESETS, quality)
  )) {
    throw new Error('Unsupported quality');
  }
  return qualities;
}

function parsePubSubPayload(body: unknown): Record<string, unknown> {
  const envelope = body as {message?: {data?: string}};
  if (envelope?.message?.data) {
    try {
      return JSON.parse(Buffer.from(envelope.message.data, 'base64').toString('utf8')) as Record<string, unknown>;
    } catch {
      throw new Error('Invalid Pub/Sub payload');
    }
  }
  return (body && typeof body === 'object' ? body : {}) as Record<string, unknown>;
}

function jobDocumentId(ownerId: string, jobId: string): string {
  return createHash('sha256').update(`${ownerId}\u001f${jobId}`).digest('hex');
}

function stableMediaUrl(bucket: string, objectName: string): string {
  const encodedPath = objectName.split('/').map(encodeURIComponent).join('/');
  return CDN_BASE_URL
    ? `${CDN_BASE_URL}/${encodedPath}`
    : `https://storage.googleapis.com/${bucket}/${encodedPath}`;
}

function startJobLeaseHeartbeat(
  jobRef: FirebaseFirestore.DocumentReference,
  leaseToken: string,
): () => Promise<void> {
  let stopped = false;
  let renewal = Promise.resolve();
  const timer = setInterval(() => {
    if (stopped) return;
    renewal = admin.firestore().runTransaction(async transaction => {
      const snapshot = await transaction.get(jobRef);
      const data = snapshot.data() ?? {};
      if (data.status !== 'processing' || data.leaseToken !== leaseToken) {
        stopped = true;
        clearInterval(timer);
        return;
      }
      transaction.update(jobRef, {
        leaseUntil: admin.firestore.Timestamp.fromMillis(Date.now() + JOB_LEASE_MS),
        heartbeatAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }).catch(error => {
      console.error('Transcode lease renewal failed:', error instanceof Error ? error.message : error);
    });
  }, JOB_LEASE_RENEW_MS);
  timer.unref();

  return async () => {
    stopped = true;
    clearInterval(timer);
    await renewal;
  };
}

async function settleJobAttempt(
  jobRef: FirebaseFirestore.DocumentReference,
  leaseToken: string,
  status: 'completed' | 'failed',
  error?: string,
): Promise<boolean> {
  return admin.firestore().runTransaction(async transaction => {
    const snapshot = await transaction.get(jobRef);
    const data = snapshot.data() ?? {};
    if (data.status !== 'processing' || data.leaseToken !== leaseToken) return false;

    transaction.set(jobRef, {
      status,
      leaseToken: admin.firestore.FieldValue.delete(),
      leaseUntil: admin.firestore.FieldValue.delete(),
      error: status === 'failed'
        ? String(error || 'Transcoding failed').slice(0, 500)
        : admin.firestore.FieldValue.delete(),
      ...(status === 'completed' && {
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
      ...(status === 'failed' && {
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return true;
  });
}

async function getVideoForCaller(videoId: string, user: AuthenticatedUser) {
  const snapshot = await admin.firestore().collection('videos').doc(videoId).get();
  if (!snapshot.exists) return null;
  const video = snapshot.data() ?? {};
  const ownerId = String(video.creatorId || video.userId || '');
  if (!ownerId || (!user.isService && ownerId !== user.userId)) return null;
  return {
    id: snapshot.id,
    user_id: ownerId,
    status: video.processingStatus || 'uploaded',
    quality_variants: video.qualityVariants || [],
    duration: video.duration || 0,
    file_size: video.fileSize || 0,
  };
}

async function updateOwnedVideo(videoId: string, ownerId: string, values: Record<string, unknown>) {
  const videoRef = admin.firestore().collection('videos').doc(videoId);
  const canonical: Record<string, unknown> = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  const rawStatus = typeof values.status === 'string' ? values.status : '';
  const processingStatus = rawStatus === 'failed' ? 'transcode_failed' : rawStatus;
  if (processingStatus) canonical.processingStatus = processingStatus;
  if (typeof values.duration === 'number') canonical.duration = values.duration;
  if (typeof values.file_size === 'number') canonical.fileSize = values.file_size;
  if (typeof values.thumbnail_url === 'string') canonical.thumbnailURL = values.thumbnail_url;
  if (Array.isArray(values.quality_variants)) canonical.qualityVariants = values.quality_variants;
  if (typeof values.videoURL === 'string') canonical.videoURL = values.videoURL;
  if (rawStatus === 'ready') {
    canonical.transcodeCompletedAt = admin.firestore.FieldValue.serverTimestamp();
    canonical.transcodeError = admin.firestore.FieldValue.delete();
  }

  let sourceVideo: FirebaseFirestore.DocumentData = {};
  await admin.firestore().runTransaction(async transaction => {
    const snapshot = await transaction.get(videoRef);
    const video = snapshot.data() ?? {};
    const canonicalOwner = String(video.creatorId || video.userId || '');
    if (!snapshot.exists || canonicalOwner !== ownerId) {
      throw new Error('Video not found or ownership changed');
    }
    sourceVideo = video;
    transaction.update(videoRef, canonical);
  });

  const timestampIso = (value: unknown): string | null =>
    value instanceof admin.firestore.Timestamp ? value.toDate().toISOString() : null;
  const mirrorValues = {
    id: videoId,
    user_id: ownerId,
    title: String(sourceVideo.title || ''),
    description: String(sourceVideo.description || ''),
    thumbnail_url: String(values.thumbnail_url || sourceVideo.thumbnailURL || ''),
    duration: Number(values.duration ?? sourceVideo.duration ?? 0),
    file_size: Number(values.file_size ?? sourceVideo.fileSize ?? 0),
    view_count: Math.max(0, Number(sourceVideo.viewCount || 0)),
    like_count: Math.max(0, Number(sourceVideo.likeCount || 0)),
    comment_count: Math.max(0, Number(sourceVideo.commentCount || 0)),
    created_at: timestampIso(sourceVideo.createdAt) || new Date().toISOString(),
    published_at: typeof values.published_at === 'string'
      ? values.published_at
      : timestampIso(sourceVideo.publishedAt),
    updated_at: new Date().toISOString(),
    category: String(sourceVideo.category || ''),
    tags: Array.isArray(sourceVideo.tags) ? sourceVideo.tags : [],
    status: processingStatus || String(sourceVideo.processingStatus || 'uploaded'),
    visibility: String(sourceVideo.visibility || sourceVideo.status || 'private'),
    quality_variants: Array.isArray(values.quality_variants)
      ? values.quality_variants
      : (Array.isArray(sourceVideo.qualityVariants) ? sourceVideo.qualityVariants : []),
  };

  // Supabase is a replicated serving index, not the source of truth. Upsert so
  // native Firebase uploads become discoverable after readiness, but never fail
  // canonical processing when the mirror is unavailable.
  if (!supabase) return;
  try {
    const {error} = await supabase
      .from('videos')
      .upsert(mirrorValues, {onConflict: 'id'});
    if (error) console.warn('Supabase video mirror upsert failed:', error.message);
  } catch (error) {
    console.warn('Supabase video mirror unavailable:', error instanceof Error ? error.message : error);
  }
}

app.use(cors({
  origin: process.env.CORS_ORIGIN || 'https://mychannel.live',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Idempotency-Key']
}));
app.use(express.json({limit: '32kb'}));
app.use('/v1/transcode', rateLimit({
  windowMs: 60_000,
  limit: 60,
  standardHeaders: true,
  legacyHeaders: false
}));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'transcode', timestamp: new Date().toISOString() });
});

// Video quality configurations
const QUALITY_PRESETS = {
  '144p': { width: 256, height: 144, bitrate: '100k', audioBitrate: '64k' },
  '240p': { width: 426, height: 240, bitrate: '300k', audioBitrate: '64k' },
  '360p': { width: 640, height: 360, bitrate: '600k', audioBitrate: '96k' },
  '480p': { width: 854, height: 480, bitrate: '1000k', audioBitrate: '128k' },
  '720p': { width: 1280, height: 720, bitrate: '2500k', audioBitrate: '192k' },
  '1080p': { width: 1920, height: 1080, bitrate: '5000k', audioBitrate: '256k' },
  '1440p': { width: 2560, height: 1440, bitrate: '10000k', audioBitrate: '320k' },
  '2160p': { width: 3840, height: 2160, bitrate: '20000k', audioBitrate: '320k' }
};

// Trusted worker endpoint. It must await processing so Pub/Sub/Cloud Tasks can
// retry failed deliveries instead of losing work when a request container stops.
app.post('/v1/transcode/ingest', async (req, res) => {
  let jobRef: FirebaseFirestore.DocumentReference | null = null;
  let videoId = '';
  let ownerId = '';
  let leaseToken = '';
  let didClaim = false;
  let stopLeaseHeartbeat: (() => Promise<void>) | null = null;
  try {
    const user = await requireUser(req, res);
    if (!user) return;
    if (!user.isService) return res.status(403).json({error: 'Service authorization required'});

    const payload = parsePubSubPayload(req.body);
    videoId = cleanId(payload.videoId, 'videoId');
    ownerId = cleanId(payload.ownerId, 'ownerId');
    const jobId = cleanJobId(payload.jobId);
    const inputPath = cleanInputPath(payload.inputPath, ownerId, videoId);
    const qualities = parseQualities(payload.qualities);
    jobRef = admin.firestore().collection('_serviceJobs').doc(jobDocumentId(ownerId, jobId));
    leaseToken = randomUUID();

    const claim = await admin.firestore().runTransaction(async transaction => {
      const snapshot = await transaction.get(jobRef!);
      const data = snapshot.data() ?? {};
      if (data.videoId && (data.videoId !== videoId || data.ownerId !== ownerId)) {
        throw new Error('Idempotency key belongs to another job');
      }
      if (data.status === 'completed') return 'completed';
      const leaseUntil = data.leaseUntil instanceof admin.firestore.Timestamp
        ? data.leaseUntil.toMillis()
        : 0;
      if (data.status === 'processing' && leaseUntil > Date.now()) return 'leased';

      transaction.set(jobRef!, {
        jobId,
        videoId,
        ownerId,
        inputPath,
        qualities,
        status: 'processing',
        attempts: Number(data.attempts ?? 0) + 1,
        leaseToken,
        leaseUntil: admin.firestore.Timestamp.fromMillis(Date.now() + JOB_LEASE_MS),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: data.createdAt ?? admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      return 'claimed';
    });

    if (claim === 'completed') return res.status(200).json({ok: true, videoId, status: 'ready'});
    if (claim === 'leased') return res.status(202).json({ok: true, videoId, status: 'processing'});

    didClaim = true;
    stopLeaseHeartbeat = startJobLeaseHeartbeat(jobRef, leaseToken);
    await updateOwnedVideo(videoId, ownerId, {
      status: 'processing',
      updated_at: new Date().toISOString(),
    });
    await processVideo(videoId, ownerId, inputPath, qualities);
    await stopLeaseHeartbeat();
    stopLeaseHeartbeat = null;
    const completed = await settleJobAttempt(jobRef, leaseToken, 'completed');
    return res.status(completed ? 200 : 202).json({
      ok: true,
      videoId,
      status: 'ready',
      leaseOwnership: completed ? 'completed' : 'superseded',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Transcoding failed';
    console.error('Transcode worker error:', message);
    if (stopLeaseHeartbeat) {
      await stopLeaseHeartbeat();
      stopLeaseHeartbeat = null;
    }
    const failedCurrentAttempt = jobRef && didClaim
      ? await settleJobAttempt(jobRef, leaseToken, 'failed', message).catch(() => false)
      : false;
    if (failedCurrentAttempt && videoId && ownerId) {
      await updateOwnedVideo(videoId, ownerId, {
        status: 'failed',
        updated_at: new Date().toISOString(),
      }).catch(() => {});
      await pubsub.topic('video-events').publishMessage({
        json: {type: 'transcode_failed', videoId, timestamp: new Date().toISOString()},
      }).catch(() => {});
    }
    return res.status(500).json({error: 'Transcoding failed'});
  }
});

// Validate ownership, reserve an idempotent job, and enqueue durable work.
app.post('/v1/transcode/start', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;
    if (!user.isService) return res.status(403).json({error: 'Service authorization required'});

    const videoId = cleanId(req.body?.videoId, 'videoId');
    const video = await getVideoForCaller(videoId, user);
    if (!video) return res.status(404).json({error: 'Video not found'});
    const ownerId = cleanId(video.user_id, 'ownerId');
    const inputPath = cleanInputPath(req.body?.inputPath, ownerId, videoId);
    const qualities = parseQualities(req.body?.qualities);
    const requestedKey = req.header('x-idempotency-key');
    const jobId = cleanJobId(requestedKey || randomUUID());
    const jobRef = admin.firestore().collection('_serviceJobs').doc(jobDocumentId(ownerId, jobId));

    const reservation = await admin.firestore().runTransaction(async transaction => {
      const snapshot = await transaction.get(jobRef);
      const existing = snapshot.data();
      if (existing) {
        if (
          existing.videoId !== videoId ||
          existing.ownerId !== ownerId ||
          existing.inputPath !== inputPath ||
          JSON.stringify(existing.qualities || []) !== JSON.stringify(qualities)
        ) {
          throw new Error('Idempotency key belongs to another job');
        }

        const status = String(existing.status || 'queued');
        if (status === 'failed') {
          transaction.set(jobRef, {
            status: 'queued',
            error: admin.firestore.FieldValue.delete(),
            failedAt: admin.firestore.FieldValue.delete(),
            messageId: admin.firestore.FieldValue.delete(),
            publishedAt: admin.firestore.FieldValue.delete(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
          return {status: 'queued', duplicate: true, shouldPublish: true};
        }
        return {
          status,
          duplicate: true,
          shouldPublish: status === 'queued' && !existing.messageId,
        };
      }
      transaction.create(jobRef, {
        jobId,
        videoId,
        ownerId,
        inputPath,
        qualities,
        status: 'queued',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return {status: 'queued', duplicate: false, shouldPublish: true};
    });

    if (reservation.shouldPublish) {
      await updateOwnedVideo(videoId, ownerId, {
        status: 'queued',
        updated_at: new Date().toISOString(),
      });
      const messageId = await pubsub.topic(TRANSCODE_TOPIC).publishMessage({
        json: {jobId, videoId, ownerId, inputPath, qualities},
        attributes: {jobId, videoId, ownerId},
      });
      await jobRef.set({
        messageId,
        publishedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    return res.status(202).json({
      ok: true,
      jobId,
      videoId,
      qualities,
      status: reservation.status === 'completed' ? 'ready' : reservation.status,
      duplicate: reservation.duplicate,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Invalid transcode request';
    const status = message.startsWith('Invalid') || message.includes('qualities') || message.includes('Input')
      ? 400
      : 500;
    console.error('Transcode enqueue error:', message);
    return res.status(status).json({error: status === 400 ? message : 'Failed to enqueue transcoding'});
  }
});

app.get('/v1/transcode/status/:videoId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;
    const videoId = cleanId(req.params.videoId, 'videoId');
    const video = await getVideoForCaller(videoId, user);
    if (!video) return res.status(404).json({error: 'Video not found'});

    return res.json({
      videoId: video.id,
      status: video.status,
      qualityVariants: video.quality_variants || [],
      duration: video.duration,
      fileSize: video.file_size,
    });
  } catch (error) {
    console.error('Status check error:', error instanceof Error ? error.message : error);
    return res.status(500).json({error: 'Failed to get status'});
  }
});

type VideoMetadata = {
  duration: number;
  size: number;
  bitrate: number;
  video: {codec?: string; width: number; height: number; fps: number};
  audio: {codec?: string; channels?: number; sampleRate?: number} | null;
};

type QualityPreset = {width: number; height: number; bitrate: string; audioBitrate: string};

async function processVideo(
  videoId: string,
  ownerId: string,
  inputPath: string,
  qualities: string[],
) {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'mychannel-transcode-'));

  try {
    const inputFile = path.join(tempDir, 'input');
    await downloadFile(inputPath, inputFile);
    const metadata = await getVideoMetadata(inputFile);

    await updateOwnedVideo(videoId, ownerId, {
      duration: Math.round(metadata.duration),
      file_size: metadata.size,
      updated_at: new Date().toISOString(),
    });

    const thumbnailPath = await generateThumbnail(inputFile, tempDir, metadata.duration);
    const thumbnailUrl = await uploadThumbnail(videoId, thumbnailPath);

    const eligibleQualities = qualities.filter(quality => {
      const preset = QUALITY_PRESETS[quality as keyof typeof QUALITY_PRESETS];
      return preset.width <= metadata.video.width && preset.height <= metadata.video.height;
    });
    const selectedQualities = eligibleQualities.length > 0
      ? eligibleQualities
      : [qualities.reduce((lowest, quality) =>
        QUALITY_PRESETS[quality as keyof typeof QUALITY_PRESETS].height <
        QUALITY_PRESETS[lowest as keyof typeof QUALITY_PRESETS].height ? quality : lowest
      )];

    const qualityVariants: Array<Record<string, unknown>> = [];
    for (const quality of selectedQualities) {
      const configured = QUALITY_PRESETS[quality as keyof typeof QUALITY_PRESETS];
      const preset: QualityPreset = {
        ...configured,
        width: Math.max(2, Math.floor(Math.min(configured.width, metadata.video.width) / 2) * 2),
        height: Math.max(2, Math.floor(Math.min(configured.height, metadata.video.height) / 2) * 2),
      };
      const outputPath = await transcodeVideo(inputFile, tempDir, quality, preset);
      const videoUrl = await uploadVideo(videoId, outputPath, quality);
      qualityVariants.push({quality, url: videoUrl, ...preset});
    }

    const playbackVariant = qualityVariants.reduce((best, candidate) =>
      Number(candidate.height || 0) > Number(best.height || 0) ? candidate : best,
    );
    const playbackUrl = String(playbackVariant.url || '');
    if (!playbackUrl) throw new Error('Transcode produced no playback URL');

    await updateOwnedVideo(videoId, ownerId, {
      status: 'ready',
      thumbnail_url: thumbnailUrl,
      quality_variants: qualityVariants,
      videoURL: playbackUrl,
      updated_at: new Date().toISOString(),
      published_at: new Date().toISOString(),
    });

    await pubsub.topic('video-events').publishMessage({
      json: {
        type: 'transcode_completed',
        videoId,
        qualityVariants,
        thumbnailUrl,
        duration: metadata.duration,
        timestamp: new Date().toISOString(),
      },
    });
  } finally {
    await fs.rm(tempDir, {recursive: true, force: true}).catch(error => {
      console.error('Transcode cleanup error:', error instanceof Error ? error.message : error);
    });
  }
}

async function downloadFile(gsPath: string, localPath: string): Promise<void> {
  const withoutScheme = gsPath.slice('gs://'.length);
  const slash = withoutScheme.indexOf('/');
  if (slash <= 0) throw new Error('Invalid ingest object');
  const bucket = withoutScheme.slice(0, slash);
  const objectPath = withoutScheme.slice(slash + 1);
  if (bucket !== INGEST_BUCKET || !objectPath) throw new Error('Invalid ingest object');
  await storage.bucket(bucket).file(objectPath).download({destination: localPath});
}

async function uploadVideo(videoId: string, localPath: string, quality: string): Promise<string> {
  const objectName = `${videoId}/${quality}.mp4`;
  await storage.bucket(OUTPUT_BUCKET).upload(localPath, {
    destination: objectName,
    resumable: true,
    validation: 'crc32c',
    metadata: {
      contentType: 'video/mp4',
      cacheControl: 'public, max-age=31536000, immutable',
    },
  });
  return stableMediaUrl(OUTPUT_BUCKET, objectName);
}

async function uploadThumbnail(videoId: string, localPath: string): Promise<string> {
  const objectName = `${videoId}/thumbnail.jpg`;
  await storage.bucket(THUMBNAIL_BUCKET).upload(localPath, {
    destination: objectName,
    resumable: false,
    validation: 'crc32c',
    metadata: {
      contentType: 'image/jpeg',
      cacheControl: 'public, max-age=86400',
    },
  });
  return stableMediaUrl(THUMBNAIL_BUCKET, objectName);
}

function parseFrameRate(value: unknown): number {
  const text = String(value || '0');
  const [numeratorText, denominatorText] = text.split('/');
  const numerator = Number(numeratorText);
  const denominator = denominatorText === undefined ? 1 : Number(denominatorText);
  if (!Number.isFinite(numerator) || !Number.isFinite(denominator) || denominator <= 0) return 0;
  return numerator / denominator;
}

function getVideoMetadata(inputPath: string): Promise<VideoMetadata> {
  return new Promise((resolve, reject) => {
    ffmpeg.ffprobe(inputPath, (error, metadata) => {
      if (error) return reject(error);
      const videoStream = metadata.streams.find(stream => stream.codec_type === 'video');
      const audioStream = metadata.streams.find(stream => stream.codec_type === 'audio');
      const duration = Number(metadata.format.duration);
      const size = Number(metadata.format.size);
      const width = Number(videoStream?.width);
      const height = Number(videoStream?.height);
      if (!videoStream || !Number.isFinite(duration) || duration <= 0 ||
          !Number.isFinite(size) || size <= 0 || !Number.isFinite(width) || width <= 0 ||
          !Number.isFinite(height) || height <= 0) {
        return reject(new Error('Input has invalid or missing video metadata'));
      }

      resolve({
        duration,
        size,
        bitrate: Number(metadata.format.bit_rate) || 0,
        video: {
          codec: videoStream.codec_name,
          width,
          height,
          fps: parseFrameRate(videoStream.r_frame_rate),
        },
        audio: audioStream ? {
          codec: audioStream.codec_name,
          channels: audioStream.channels,
          sampleRate: Number(audioStream.sample_rate) || undefined,
        } : null,
      });
    });
  });
}

function generateThumbnail(inputPath: string, outputDir: string, duration: number): Promise<string> {
  return new Promise((resolve, reject) => {
    const outputPath = path.join(outputDir, 'thumbnail.jpg');
    const seekSeconds = Math.max(0, Math.min(10, duration * 0.1));
    ffmpeg(inputPath)
      .seekInput(seekSeconds)
      .frames(1)
      .videoFilters('scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2')
      .output(outputPath)
      .on('end', () => resolve(outputPath))
      .on('error', reject)
      .run();
  });
}

function transcodeVideo(
  inputPath: string,
  outputDir: string,
  quality: string,
  preset: QualityPreset,
): Promise<string> {
  return new Promise((resolve, reject) => {
    const outputPath = path.join(outputDir, `${quality}.mp4`);
    ffmpeg(inputPath)
      .videoCodec('libx264')
      .audioCodec('aac')
      .videoFilters(
        `scale=${preset.width}:${preset.height}:force_original_aspect_ratio=decrease,` +
        `pad=${preset.width}:${preset.height}:(ow-iw)/2:(oh-ih)/2`,
      )
      .videoBitrate(preset.bitrate)
      .audioBitrate(preset.audioBitrate)
      .outputOptions([
        '-preset medium',
        '-crf 23',
        '-movflags +faststart',
        '-pix_fmt yuv420p',
      ])
      .output(outputPath)
      .on('end', () => resolve(outputPath))
      .on('error', reject)
      .run();
  });
}

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`🎬 Transcode service listening on port ${port}`);
});


