"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.music = void 0;
const express_1 = __importDefault(require("express"));
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const storage_1 = require("@google-cloud/storage");
const tasks_1 = require("@google-cloud/tasks");
const crypto_1 = require("crypto");
const https_1 = require("https");
const app = (0, express_1.default)();
const PROJECT_ID = process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT || 'mychannel-ca26d';
const BUCKET_NAME = process.env.MUSIC_STORAGE_BUCKET ||
    process.env.FIREBASE_STORAGE_BUCKET || `${PROJECT_ID}.firebasestorage.app`;
const JSON_BODY_LIMIT = process.env.MUSIC_JSON_BODY_LIMIT || '12mb';
const MAX_REQUESTS_PER_MINUTE = Math.min(Math.max(Number.parseInt(process.env.MUSIC_RATE_LIMIT_PER_MINUTE || '120', 10) || 120, 10), 1000);
const MAX_CHUNK_BYTES = 8 * 1024 * 1024;
const MAX_MASTER_BYTES = 500 * 1024 * 1024;
const MAX_CHUNKS = 128;
const MAX_ARTWORK_BYTES = 10 * 1024 * 1024;
const MAX_TRACKS_PER_PAGE = 100;
const MAX_TRACK_COLLABORATORS = 20;
const TRANSCODE_HANDOFF_TIMEOUT_MS = Math.min(Math.max(Number.parseInt(process.env.MUSIC_TRANSCODE_HANDOFF_TIMEOUT_MS || '600000', 10) || 600000, 5000), 900000);
const TOTAL_SPLIT_BASIS_POINTS = 10000;
const COLLABORATOR_ROLES = new Set([
    'primary_artist', 'featured_artist', 'producer', 'songwriter',
    'composer', 'performer', 'label', 'publisher'
]);
const MIN_QUALIFIED_PLAY_SECONDS = 30;
const MAX_QUALIFIED_PLAY_SECONDS = 86400;
const MAX_QUALIFIED_PLAYS_PER_TRACK_DAY = Math.min(Math.max(Number.parseInt(process.env.MUSIC_MAX_QUALIFIED_PLAYS_PER_TRACK_DAY || '50', 10) || 50, 1), 500);
const SESSION_ID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const AUDIO_EXTENSIONS = {
    'audio/mpeg': 'mp3',
    'audio/mp4': 'm4a',
    'audio/x-m4a': 'm4a',
    'audio/wav': 'wav',
    'audio/x-wav': 'wav',
    'audio/flac': 'flac',
    'audio/aac': 'aac',
    'audio/ogg': 'ogg'
};
const ARTWORK_EXTENSIONS = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp'
};
app.disable('x-powered-by');
app.set('trust proxy', 1);
const rateWindows = new Map();
app.use((req, res, next) => {
    const now = Date.now();
    const key = `${req.ip || req.socket.remoteAddress || 'unknown'}:${req.path}`;
    const current = rateWindows.get(key);
    if (!current || current.resetAt <= now) {
        rateWindows.set(key, { count: 1, resetAt: now + 60000 });
        if (rateWindows.size > 10000) {
            for (const [windowKey, value] of rateWindows) {
                if (value.resetAt <= now)
                    rateWindows.delete(windowKey);
            }
        }
        return next();
    }
    if (current.count >= MAX_REQUESTS_PER_MINUTE) {
        res.setHeader('Retry-After', String(Math.max(1, Math.ceil((current.resetAt - now) / 1000))));
        return res.status(429).json({ error: 'Too many requests' });
    }
    current.count += 1;
    next();
});
app.use(express_1.default.json({ limit: JSON_BODY_LIMIT, strict: true }));
if (!firebase_admin_1.default.apps.length) {
    firebase_admin_1.default.initializeApp({
        credential: firebase_admin_1.default.credential.applicationDefault(),
        projectId: PROJECT_ID,
        storageBucket: BUCKET_NAME
    });
}
const db = firebase_admin_1.default.firestore();
const storage = new storage_1.Storage({ projectId: PROJECT_ID });
const bucket = storage.bucket(BUCKET_NAME);
const tasks = new tasks_1.CloudTasksClient();
async function requireUser(req, res) {
    try {
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
        const decoded = await firebase_admin_1.default.auth().verifyIdToken(token);
        return {
            userId: decoded.uid,
            email: decoded.email,
            isAdmin: decoded.admin === true
        };
    }
    catch (_a) {
        res.status(401).json({ error: 'Invalid token' });
        return null;
    }
}
function generateTrackId() {
    return (0, crypto_1.randomUUID)();
}
function hasOnlyKeys(value, allowed) {
    return !!value && typeof value === 'object' && !Array.isArray(value) &&
        Object.keys(value).every((key) => allowed.includes(key));
}
function boundedString(value, field, min, max) {
    if (typeof value !== 'string')
        throw new Error(`${field} must be a string`);
    const normalized = value.trim();
    if (normalized.length < min || normalized.length > max) {
        throw new Error(`${field} must be between ${min} and ${max} characters`);
    }
    return normalized;
}
function optionalBoundedString(value, field, max) {
    if (value === undefined || value === null || value === '')
        return null;
    return boundedString(value, field, 1, max);
}
function decodeBase64(value, field, maxBytes) {
    if (typeof value !== 'string' || value.length === 0 ||
        value.length > Math.ceil(maxBytes / 3) * 4 + 4 ||
        !/^[A-Za-z0-9+/]+={0,2}$/.test(value) || value.length % 4 !== 0) {
        throw new Error(`${field} must be valid base64`);
    }
    const buffer = Buffer.from(value, 'base64');
    if (buffer.length === 0 || buffer.length > maxBytes) {
        throw new Error(`${field} exceeds the allowed size`);
    }
    return buffer;
}
function parseBoundedInteger(value, field, min, max) {
    if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < min || value > max) {
        throw new Error(`${field} must be an integer between ${min} and ${max}`);
    }
    return value;
}
function safeAudioType(value) {
    if (typeof value !== 'string' || !AUDIO_EXTENSIONS[value]) {
        throw new Error('Unsupported audio content type');
    }
    return value;
}
function safeArtworkType(value) {
    if (typeof value !== 'string' || !ARTWORK_EXTENSIONS[value]) {
        throw new Error('Unsupported artwork content type');
    }
    return value;
}
function isSafeTrackId(value) {
    return /^[A-Za-z0-9_-]{1,128}$/.test(value);
}
function isSafeArtistId(value) {
    return typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
}
function publicRenditions(track) {
    const source = track.renditions && typeof track.renditions === 'object'
        ? track.renditions : {};
    const renditions = {};
    const candidates = {
        hls: source.hls || track.hlsURL,
        mp3: source.mp3 || track.mp3URL,
        flac: source.flac || track.losslessURL
    };
    for (const [key, value] of Object.entries(candidates)) {
        if (typeof value === 'string' && value.startsWith('https://'))
            renditions[key] = value;
    }
    return renditions;
}
async function composeFiles(sources, target) {
    const sourceNames = sources.map((file) => file.name);
    await bucket.combine(sourceNames, target);
}
function configuredTranscodeEndpoint(trackId) {
    const configured = (process.env.MUSIC_TRANSCODE_URL || '').trim();
    if (!configured)
        return null;
    const endpoint = new URL(configured);
    if (endpoint.protocol !== 'https:' || endpoint.username || endpoint.password || endpoint.search || endpoint.hash) {
        throw new Error('MUSIC_TRANSCODE_URL must be a credential-free HTTPS URL');
    }
    const encodedTrackId = encodeURIComponent(trackId);
    if (endpoint.pathname.includes('{trackId}')) {
        endpoint.pathname = endpoint.pathname.replace('{trackId}', encodedTrackId);
    }
    else {
        const basePath = endpoint.pathname.replace(/\/$/, '');
        if (basePath === '') {
            endpoint.pathname = `/v1/music/transcode/${encodedTrackId}`;
        }
        else if (basePath === '/v1/music/transcode') {
            endpoint.pathname = `${basePath}/${encodedTrackId}`;
        }
        else {
            throw new Error('MUSIC_TRANSCODE_URL path must be empty, /v1/music/transcode, or contain {trackId}');
        }
    }
    return endpoint;
}
async function enqueueConfiguredTranscode(trackId, ownerUid) {
    const endpoint = configuredTranscodeEndpoint(trackId);
    const location = (process.env.MUSIC_TRANSCODE_TASK_LOCATION || '').trim();
    const queue = (process.env.MUSIC_TRANSCODE_TASK_QUEUE || '').trim();
    const serviceAccountEmail = (process.env.MUSIC_TRANSCODE_TASK_SERVICE_ACCOUNT || '').trim();
    if (!endpoint || !location || !queue || !serviceAccountEmail) {
        return { configured: false, accepted: false };
    }
    if (!/^[a-z][a-z0-9-]{0,62}$/.test(location) ||
        !/^[A-Za-z][A-Za-z0-9_-]{0,99}$/.test(queue) ||
        !/^[^@\s]+@[^@\s]+\.iam\.gserviceaccount\.com$/.test(serviceAccountEmail)) {
        throw new Error('Music transcode task configuration is invalid');
    }
    const parent = tasks.queuePath(PROJECT_ID, location, queue);
    const taskId = `music-transcode-${(0, crypto_1.createHash)('sha256').update(trackId).digest('hex')}`;
    const body = Buffer.from(JSON.stringify({ ownerUid })).toString('base64');
    const audience = (process.env.MUSIC_TRANSCODE_OIDC_AUDIENCE || endpoint.origin).trim();
    const task = {
        name: tasks.taskPath(PROJECT_ID, location, queue, taskId),
        httpRequest: {
            httpMethod: tasks_1.protos.google.cloud.tasks.v2.HttpMethod.POST,
            url: endpoint.toString(),
            headers: { 'Content-Type': 'application/json' },
            body,
            oidcToken: { serviceAccountEmail, audience }
        }
    };
    try {
        await tasks.createTask({ parent, task });
    }
    catch (error) {
        // ALREADY_EXISTS makes retries idempotent for one immutable track master.
        if ((error === null || error === void 0 ? void 0 : error.code) !== 6)
            throw error;
    }
    return { configured: true, accepted: true, statusCode: 202 };
}
async function invokeConfiguredTranscode(trackId, authorization) {
    const endpoint = configuredTranscodeEndpoint(trackId);
    if (!endpoint)
        return { configured: false, accepted: false };
    const body = Buffer.from('{}');
    return new Promise((resolve, reject) => {
        const request = (0, https_1.request)(endpoint, {
            method: 'POST',
            headers: {
                Authorization: authorization,
                'Content-Type': 'application/json',
                'Content-Length': String(body.length),
                'X-MyChannel-Idempotency-Key': (0, crypto_1.createHash)('sha256')
                    .update(`music-transcode\u0000${trackId}`)
                    .digest('hex')
            }
        }, (response) => {
            let responseBytes = 0;
            response.on('data', (chunk) => {
                responseBytes += chunk.length;
                if (responseBytes > 64 * 1024)
                    request.destroy(new Error('Transcode response exceeded limit'));
            });
            response.on('end', () => {
                const statusCode = response.statusCode || 0;
                resolve({ configured: true, accepted: statusCode >= 200 && statusCode < 300, statusCode });
            });
        });
        request.setTimeout(TRANSCODE_HANDOFF_TIMEOUT_MS, () => {
            request.destroy(new Error('Transcode handoff timed out'));
        });
        request.on('error', reject);
        request.end(body);
    });
}
async function handoffCompletedUpload(trackId, ownerUid, trackRef, processingRef, authorization) {
    try {
        const queued = await enqueueConfiguredTranscode(trackId, ownerUid);
        const allowSynchronousFallback = (process.env.MUSIC_ALLOW_SYNCHRONOUS_TRANSCODE || 'false') === 'true';
        const handoff = queued.configured
            ? queued
            : allowSynchronousFallback
                ? await invokeConfiguredTranscode(trackId, authorization)
                : { configured: false, accepted: false };
        if (!handoff.configured) {
            await Promise.all([
                trackRef.update({ transcodingStatus: 'awaiting_handoff' }),
                processingRef.set({
                    handoffStatus: 'not_configured',
                    updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
                }, { merge: true })
            ]);
            return {
                httpStatus: 202,
                status: 'processing',
                transcodingStatus: 'awaiting_handoff',
                message: 'Upload complete. Transcoding is awaiting configured handoff.'
            };
        }
        if (!handoff.accepted) {
            await Promise.all([
                trackRef.update({ transcodingStatus: 'awaiting_handoff' }),
                processingRef.set({
                    handoffStatus: 'rejected',
                    handoffStatusCode: handoff.statusCode || null,
                    updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
                }, { merge: true })
            ]);
            return {
                httpStatus: 202,
                status: 'processing',
                transcodingStatus: 'awaiting_handoff',
                message: 'Upload complete. Transcode handoff was not accepted and must be retried.'
            };
        }
        await processingRef.set({
            handoffStatus: 'accepted',
            handoffStatusCode: handoff.statusCode || null,
            handoffAcceptedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        const completed = handoff.statusCode === 200;
        return {
            httpStatus: completed ? 200 : 202,
            status: completed ? 'processing_complete' : 'processing',
            transcodingStatus: completed ? 'completed' : 'in_progress',
            message: completed
                ? 'Upload and transcoding completed.'
                : 'Upload complete. Transcode handoff accepted.'
        };
    }
    catch (error) {
        console.error('Transcode handoff error:', error instanceof Error ? error.message : 'unknown error');
        await Promise.all([
            trackRef.update({ transcodingStatus: 'awaiting_handoff' }),
            processingRef.set({
                handoffStatus: 'failed',
                updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
            }, { merge: true })
        ]);
        return {
            httpStatus: 202,
            status: 'processing',
            transcodingStatus: 'awaiting_handoff',
            message: 'Upload complete. Transcode handoff failed and must be retried.'
        };
    }
}
// ─────────────────────────────────────────────────────────────────────────────
// Phase 1: Enhanced Music Upload & Processing Service
// ─────────────────────────────────────────────────────────────────────────────
// POST /v1/music/tracks/upload - Initiate upload with metadata
app.post('/v1/music/tracks/upload', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        if (!hasOnlyKeys(req.body, [
            'title', 'artistName', 'albumName', 'genre', 'isExplicit', 'duration'
        ])) {
            return res.status(400).json({ error: 'Unexpected metadata field' });
        }
        const title = boundedString(req.body.title, 'title', 1, 200);
        const artistName = boundedString(req.body.artistName, 'artistName', 1, 120);
        const albumName = optionalBoundedString(req.body.albumName, 'albumName', 200);
        const genre = boundedString(req.body.genre, 'genre', 1, 64);
        const isExplicit = req.body.isExplicit === undefined ? false : req.body.isExplicit;
        if (typeof isExplicit !== 'boolean') {
            return res.status(400).json({ error: 'isExplicit must be a boolean' });
        }
        const duration = req.body.duration === undefined || req.body.duration === null
            ? null : req.body.duration;
        if (duration !== null &&
            (typeof duration !== 'number' || !Number.isFinite(duration) || duration <= 0 || duration > 86400)) {
            return res.status(400).json({ error: 'duration must be between 0 and 86400 seconds' });
        }
        const trackId = generateTrackId();
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        const trackRef = db.collection('music_tracks').doc(trackId);
        await trackRef.set({
            id: trackId,
            title,
            artistId: user.userId,
            artistName,
            albumName,
            genre,
            isExplicit,
            duration,
            status: 'uploading',
            moderationStatus: 'pending_review',
            isPublished: false,
            uploadStartedAt: now,
            createdAt: now,
            totalPlayCount: 0,
            streamCount: 0,
            payableStreamCount: 0,
            likeCount: 0,
            artworkURL: null,
            transcodingStatus: 'pending',
            distributionStatus: 'not_submitted',
            uploadedChunks: 0,
            uploadedChunkIndexes: []
        });
        res.status(201).json({
            trackId,
            status: 'uploading',
            message: 'Upload initiated. Use chunked upload endpoint for large files.'
        });
    }
    catch (error) {
        if (error instanceof Error && /must be|Unexpected|Unsupported|exceeds/.test(error.message)) {
            return res.status(400).json({ error: error.message });
        }
        console.error('Initiate upload error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// POST /v1/music/tracks/:trackId/chunk - Chunked audio upload
app.post('/v1/music/tracks/:trackId/chunk', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId } = req.params;
        if (!isSafeTrackId(trackId) ||
            !hasOnlyKeys(req.body, ['chunkIndex', 'totalChunks', 'chunkData', 'mimeType'])) {
            return res.status(400).json({ error: 'Invalid chunk request' });
        }
        const chunkIndex = parseBoundedInteger(req.body.chunkIndex, 'chunkIndex', 0, MAX_CHUNKS - 1);
        const totalChunks = parseBoundedInteger(req.body.totalChunks, 'totalChunks', 1, MAX_CHUNKS);
        if (chunkIndex >= totalChunks) {
            return res.status(400).json({ error: 'chunkIndex must be less than totalChunks' });
        }
        const mimeType = safeAudioType(req.body.mimeType);
        const buffer = decodeBase64(req.body.chunkData, 'chunkData', MAX_CHUNK_BYTES);
        const trackRef = db.collection('music_tracks').doc(trackId);
        const trackSnap = await trackRef.get();
        if (!trackSnap.exists)
            return res.status(404).json({ error: 'Track not found' });
        const trackData = trackSnap.data();
        if (String(trackData.artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        if (trackData.status !== 'uploading') {
            return res.status(409).json({ error: 'Track is not accepting chunks' });
        }
        if ((trackData.totalChunks !== undefined && trackData.totalChunks !== totalChunks) ||
            (trackData.uploadMimeType && trackData.uploadMimeType !== mimeType)) {
            return res.status(409).json({ error: 'Chunk metadata does not match this upload' });
        }
        const chunkRef = bucket.file(`music/temp/${user.userId}/${trackId}/chunk_${chunkIndex}`);
        await chunkRef.save(buffer, {
            resumable: false,
            contentType: mimeType,
            metadata: {
                metadata: {
                    trackId,
                    ownerUid: user.userId,
                    chunkIndex: String(chunkIndex),
                    totalChunks: String(totalChunks)
                }
            }
        });
        let uploadedChunks = 0;
        try {
            uploadedChunks = await db.runTransaction(async (transaction) => {
                const current = await transaction.get(trackRef);
                if (!current.exists)
                    throw new Error('Track not found');
                const data = current.data();
                if (String(data.artistId || '') !== user.userId || data.status !== 'uploading') {
                    throw new Error('Track is not accepting chunks');
                }
                if ((data.totalChunks !== undefined && data.totalChunks !== totalChunks) ||
                    (data.uploadMimeType && data.uploadMimeType !== mimeType)) {
                    throw new Error('Chunk metadata does not match this upload');
                }
                const indexes = Array.isArray(data.uploadedChunkIndexes)
                    ? data.uploadedChunkIndexes.filter((value) => Number.isSafeInteger(value))
                    : [];
                if (!indexes.includes(chunkIndex))
                    indexes.push(chunkIndex);
                indexes.sort((a, b) => a - b);
                transaction.update(trackRef, {
                    totalChunks,
                    uploadMimeType: mimeType,
                    uploadedChunkIndexes: indexes,
                    uploadedChunks: indexes.length,
                    lastChunkUploadedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
                });
                return indexes.length;
            });
        }
        catch (error) {
            await chunkRef.delete().catch(() => { });
            throw error;
        }
        res.json({
            trackId,
            chunkIndex,
            uploadedChunks,
            totalChunks,
            status: 'chunk_uploaded',
            message: `Chunk ${chunkIndex + 1} of ${totalChunks} uploaded`
        });
    }
    catch (error) {
        if (error instanceof Error &&
            /must be|Invalid chunk|Unsupported|exceeds|does not match|not accepting/.test(error.message)) {
            const status = /does not match|not accepting/.test(error.message) ? 409 : 400;
            return res.status(status).json({ error: error.message });
        }
        console.error('Chunk upload error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// POST /v1/music/tracks/:trackId/complete - Finalize upload and trigger processing
app.post('/v1/music/tracks/:trackId/complete', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId } = req.params;
        if (!isSafeTrackId(trackId) || !hasOnlyKeys(req.body, ['fileName', 'mimeType'])) {
            return res.status(400).json({ error: 'Invalid completion request' });
        }
        const fileName = boundedString(req.body.fileName, 'fileName', 1, 255);
        if (!/^[A-Za-z0-9][A-Za-z0-9._ -]{0,254}$/.test(fileName)) {
            return res.status(400).json({ error: 'fileName contains unsupported characters' });
        }
        const mimeType = safeAudioType(req.body.mimeType);
        const expectedExtension = AUDIO_EXTENSIONS[mimeType];
        const suppliedExtension = fileName.includes('.') ? fileName.split('.').pop().toLowerCase() : '';
        if (suppliedExtension && suppliedExtension !== expectedExtension) {
            return res.status(400).json({ error: 'fileName extension does not match mimeType' });
        }
        const trackRef = db.collection('music_tracks').doc(trackId);
        const processingRef = db.collection('music_track_processing').doc(trackId);
        const trackSnap = await trackRef.get();
        if (!trackSnap.exists)
            return res.status(404).json({ error: 'Track not found' });
        const trackData = trackSnap.data();
        if (String(trackData.artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        if (trackData.status === 'processing') {
            const processingSnap = await processingRef.get();
            const processing = processingSnap.exists ? processingSnap.data() : null;
            if (!processing || String(processing.ownerUid || '') !== user.userId ||
                typeof processing.masterPath !== 'string') {
                return res.status(409).json({ error: 'Completed upload processing metadata is unavailable' });
            }
            if (processing.masterContentType !== mimeType) {
                return res.status(409).json({ error: 'Completion metadata does not match the private master' });
            }
            await trackRef.update({
                audioURL: firebase_admin_1.default.firestore.FieldValue.delete(),
                masterURL: firebase_admin_1.default.firestore.FieldValue.delete(),
                masterPath: firebase_admin_1.default.firestore.FieldValue.delete(),
                masterSizeBytes: firebase_admin_1.default.firestore.FieldValue.delete(),
                masterContentType: firebase_admin_1.default.firestore.FieldValue.delete()
            });
            const handoff = await handoffCompletedUpload(trackId, user.userId, trackRef, processingRef, req.headers.authorization);
            return res.status(handoff.httpStatus).json({
                trackId,
                status: handoff.status,
                transcodingStatus: handoff.transcodingStatus,
                idempotentReplay: true,
                message: handoff.message
            });
        }
        if (trackData.status !== 'uploading') {
            return res.status(409).json({ error: 'Track upload cannot be completed in its current state' });
        }
        if (trackData.uploadMimeType !== mimeType ||
            !Number.isSafeInteger(trackData.totalChunks) ||
            trackData.totalChunks < 1 || trackData.totalChunks > MAX_CHUNKS) {
            return res.status(409).json({ error: 'Completion metadata does not match uploaded chunks' });
        }
        const tempDir = `music/temp/${user.userId}/${trackId}/`;
        const [listedFiles] = await bucket.getFiles({
            prefix: tempDir,
            autoPaginate: false,
            maxResults: MAX_CHUNKS + 1
        });
        const chunks = listedFiles.filter((file) => /\/chunk_\d+$/.test(file.name));
        if (chunks.length !== trackData.totalChunks || chunks.length > MAX_CHUNKS) {
            return res.status(400).json({ error: 'Upload is missing one or more chunks' });
        }
        const chunkDetails = await Promise.all(chunks.map(async (file) => {
            var _a, _b, _c;
            const [metadata] = await file.getMetadata();
            const match = file.name.match(/\/chunk_(\d+)$/);
            return {
                file,
                index: match ? Number.parseInt(match[1], 10) : -1,
                size: Number(metadata.size || 0),
                contentType: metadata.contentType,
                ownerUid: (_a = metadata.metadata) === null || _a === void 0 ? void 0 : _a.ownerUid,
                trackId: (_b = metadata.metadata) === null || _b === void 0 ? void 0 : _b.trackId,
                totalChunks: Number((_c = metadata.metadata) === null || _c === void 0 ? void 0 : _c.totalChunks)
            };
        }));
        chunkDetails.sort((a, b) => a.index - b.index);
        let totalBytes = 0;
        for (let index = 0; index < chunkDetails.length; index++) {
            const chunk = chunkDetails[index];
            if (chunk.index !== index || chunk.size < 1 || chunk.size > MAX_CHUNK_BYTES ||
                chunk.contentType !== mimeType || chunk.ownerUid !== user.userId ||
                chunk.trackId !== trackId || chunk.totalChunks !== trackData.totalChunks) {
                return res.status(400).json({ error: 'Uploaded chunk validation failed' });
            }
            totalBytes += chunk.size;
            if (totalBytes > MAX_MASTER_BYTES) {
                return res.status(413).json({ error: 'Combined audio exceeds the maximum size' });
            }
        }
        const finalAudioPath = `music/${user.userId}/tracks/${trackId}.${expectedExtension}`;
        const finalAudioRef = bucket.file(finalAudioPath);
        const generatedIntermediates = [];
        if (chunkDetails.length === 1) {
            await chunkDetails[0].file.copy(finalAudioRef);
        }
        else {
            let intermediates = chunkDetails.map((chunk) => chunk.file);
            let wave = 0;
            while (intermediates.length > 1) {
                const next = [];
                for (let index = 0; index < intermediates.length; index += 32) {
                    const group = intermediates.slice(index, index + 32);
                    const target = intermediates.length <= 32
                        ? finalAudioRef
                        : bucket.file(`${tempDir}_compose_${wave}_${index}`);
                    await composeFiles(group, target);
                    if (target.name !== finalAudioPath)
                        generatedIntermediates.push(target);
                    next.push(target);
                }
                intermediates = next;
                wave += 1;
            }
        }
        await finalAudioRef.setMetadata({ contentType: mimeType });
        const completionBatch = db.batch();
        completionBatch.update(trackRef, {
            audioURL: firebase_admin_1.default.firestore.FieldValue.delete(),
            masterURL: firebase_admin_1.default.firestore.FieldValue.delete(),
            masterPath: firebase_admin_1.default.firestore.FieldValue.delete(),
            masterSizeBytes: firebase_admin_1.default.firestore.FieldValue.delete(),
            masterContentType: firebase_admin_1.default.firestore.FieldValue.delete(),
            status: 'processing',
            uploadedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            processingStartedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            transcodingStatus: 'pending_handoff',
            isPublished: false
        });
        completionBatch.set(processingRef, {
            schemaVersion: 1,
            trackId,
            ownerUid: user.userId,
            masterPath: finalAudioPath,
            masterSizeBytes: totalBytes,
            masterContentType: mimeType,
            processingStatus: 'pending_handoff',
            handoffStatus: 'pending',
            createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
        });
        await completionBatch.commit();
        await Promise.all([
            ...chunkDetails.map((chunk) => chunk.file.delete().catch(() => undefined)),
            ...generatedIntermediates.map((file) => file.delete().catch(() => undefined))
        ]);
        const handoff = await handoffCompletedUpload(trackId, user.userId, trackRef, processingRef, req.headers.authorization);
        return res.status(handoff.httpStatus).json({
            trackId,
            status: handoff.status,
            transcodingStatus: handoff.transcodingStatus,
            idempotentReplay: false,
            message: handoff.message
        });
    }
    catch (error) {
        if (error instanceof Error &&
            /must be|Invalid completion|Unsupported|contains unsupported|does not match|cannot be completed/.test(error.message)) {
            const status = /does not match|cannot be completed/.test(error.message) ? 409 : 400;
            return res.status(status).json({ error: error.message });
        }
        console.error('Complete upload error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// POST /v1/music/tracks/:trackId/artwork - Upload artwork
app.post('/v1/music/tracks/:trackId/artwork', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId } = req.params;
        if (!isSafeTrackId(trackId) || !hasOnlyKeys(req.body, ['artworkData', 'mimeType'])) {
            return res.status(400).json({ error: 'Invalid artwork request' });
        }
        const mimeType = safeArtworkType(req.body.mimeType);
        const buffer = decodeBase64(req.body.artworkData, 'artworkData', MAX_ARTWORK_BYTES);
        const trackRef = db.collection('music_tracks').doc(trackId);
        const trackSnap = await trackRef.get();
        if (!trackSnap.exists)
            return res.status(404).json({ error: 'Track not found' });
        const trackData = trackSnap.data();
        if (String(trackData.artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        const artworkPath = `music/${user.userId}/artwork/${trackId}.${ARTWORK_EXTENSIONS[mimeType]}`;
        await bucket.deleteFiles({ prefix: `music/${user.userId}/artwork/${trackId}.` })
            .catch(() => undefined);
        const artworkRef = bucket.file(artworkPath);
        const downloadToken = (0, crypto_1.randomUUID)();
        await artworkRef.save(buffer, {
            resumable: false,
            contentType: mimeType,
            metadata: {
                cacheControl: 'public, max-age=31536000, immutable',
                metadata: { firebaseStorageDownloadTokens: downloadToken }
            }
        });
        const artworkURL = `https://firebasestorage.googleapis.com/v0/b/${encodeURIComponent(bucket.name)}` +
            `/o/${encodeURIComponent(artworkPath)}?alt=media&token=${downloadToken}`;
        await trackRef.update({
            artworkURL,
            artworkUploadedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
        });
        res.json({ trackId, artworkURL, message: 'Artwork uploaded successfully' });
    }
    catch (error) {
        if (error instanceof Error && /Invalid artwork|Unsupported|valid base64|exceeds/.test(error.message)) {
            return res.status(400).json({ error: error.message });
        }
        console.error('Artwork upload error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/tracks/:trackId/status - Check upload/processing status
app.get('/v1/music/tracks/:trackId/status', async (req, res) => {
    var _a;
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId } = req.params;
        const trackRef = db.collection('music_tracks').doc(trackId);
        const trackSnap = await trackRef.get();
        if (!trackSnap.exists) {
            return res.status(404).json({ error: 'Track not found' });
        }
        const trackData = trackSnap.data();
        if (String(trackData.artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        res.json({
            trackId,
            status: trackData.status,
            transcodingStatus: trackData.transcodingStatus,
            renditions: publicRenditions(trackData),
            artworkURL: trackData.artworkURL,
            totalPlayCount: trackData.totalPlayCount || 0,
            streamCount: trackData.streamCount || 0,
            payableStreamCount: trackData.payableStreamCount || 0,
            likeCount: trackData.likeCount || 0,
            createdAt: (_a = trackData.createdAt) === null || _a === void 0 ? void 0 : _a.toDate().toISOString()
        });
    }
    catch (error) {
        console.error('Get status error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/tracks - List artist's tracks
app.get('/v1/music/tracks', async (req, res) => {
    var _a;
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const rawLimit = typeof req.query.limit === 'string' ? req.query.limit : '50';
        if (!/^\d{1,3}$/.test(rawLimit)) {
            return res.status(400).json({ error: 'limit must be an integer' });
        }
        const pageLimit = Math.min(Math.max(Number.parseInt(rawLimit, 10), 1), MAX_TRACKS_PER_PAGE);
        const status = typeof req.query.status === 'string' ? req.query.status : undefined;
        const allowedStatuses = ['uploading', 'processing', 'pending_review', 'published', 'rejected', 'failed'];
        if (status && !allowedStatuses.includes(status)) {
            return res.status(400).json({ error: 'Invalid status filter' });
        }
        const pageToken = typeof req.query.pageToken === 'string' ? req.query.pageToken : undefined;
        if (pageToken && !isSafeTrackId(pageToken)) {
            return res.status(400).json({ error: 'Invalid pageToken' });
        }
        let query = db.collection('music_tracks')
            .where('artistId', '==', user.userId);
        if (status)
            query = query.where('status', '==', status);
        query = query.orderBy('createdAt', 'desc').limit(pageLimit + 1);
        if (pageToken) {
            const cursor = await db.collection('music_tracks').doc(pageToken).get();
            if (!cursor.exists || String(((_a = cursor.data()) === null || _a === void 0 ? void 0 : _a.artistId) || '') !== user.userId) {
                return res.status(400).json({ error: 'Invalid pageToken' });
            }
            query = query.startAfter(cursor);
        }
        const tracksSnap = await query.get();
        const hasMore = tracksSnap.docs.length > pageLimit;
        const pageDocs = tracksSnap.docs.slice(0, pageLimit);
        const tracks = pageDocs.map((doc) => {
            var _a;
            const data = doc.data();
            return {
                id: doc.id,
                title: data.title,
                artistName: data.artistName,
                albumName: data.albumName,
                genre: data.genre,
                isExplicit: data.isExplicit,
                artworkURL: data.artworkURL,
                renditions: publicRenditions(data),
                status: data.status,
                transcodingStatus: data.transcodingStatus,
                totalPlayCount: data.totalPlayCount || 0,
                streamCount: data.streamCount || 0,
                payableStreamCount: data.payableStreamCount || 0,
                likeCount: data.likeCount || 0,
                createdAt: (_a = data.createdAt) === null || _a === void 0 ? void 0 : _a.toDate().toISOString()
            };
        });
        res.json({
            tracks,
            total: tracks.length,
            nextPageToken: hasMore && pageDocs.length > 0 ? pageDocs[pageDocs.length - 1].id : null
        });
    }
    catch (error) {
        console.error('List tracks error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// PUT /v1/music/tracks/:trackId/moderation - Admin review and atomic publication decision
app.put('/v1/music/tracks/:trackId/moderation', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        if (!user.isAdmin)
            return res.status(403).json({ error: 'Admin authorization required' });
        const { trackId } = req.params;
        if (!isSafeTrackId(trackId) ||
            !hasOnlyKeys(req.body, ['decision', 'reason']) ||
            (req.body.decision !== 'approved' && req.body.decision !== 'rejected')) {
            return res.status(400).json({ error: 'decision must be approved or rejected' });
        }
        const reason = optionalBoundedString(req.body.reason, 'reason', 500);
        if (req.body.decision === 'rejected' && !reason) {
            return res.status(400).json({ error: 'A rejection reason is required' });
        }
        const trackRef = db.collection('music_tracks').doc(trackId);
        const decision = req.body.decision;
        const result = await db.runTransaction(async (transaction) => {
            const trackSnap = await transaction.get(trackRef);
            if (!trackSnap.exists)
                return { error: 'Track not found', statusCode: 404 };
            const track = trackSnap.data();
            if (track.moderationStatus === decision) {
                const alreadyPublished = decision === 'approved' &&
                    track.isPublished === true && track.status === 'published';
                return { idempotentReplay: true, published: alreadyPublished };
            }
            if (track.isPublished === true || track.status === 'published') {
                return { error: 'Published tracks require the takedown workflow', statusCode: 409 };
            }
            if (decision === 'approved' &&
                (track.transcodingStatus !== 'completed' ||
                    typeof track.hlsURL !== 'string' || !track.hlsURL.startsWith('https://'))) {
                return { error: 'Transcoding and a valid HLS rendition are required before approval', statusCode: 409 };
            }
            const now = firebase_admin_1.default.firestore.FieldValue.serverTimestamp();
            const update = {
                moderationStatus: decision,
                moderationReviewedAt: now,
                moderationReviewedBy: user.userId,
                moderationReason: reason,
                isPublished: decision === 'approved',
                status: decision === 'approved' ? 'published' : 'rejected'
            };
            if (decision === 'approved')
                update.publishedAt = now;
            transaction.update(trackRef, update);
            return { idempotentReplay: false, published: decision === 'approved' };
        });
        if ('error' in result)
            return res.status(result.statusCode).json({ error: result.error });
        return res.json({
            trackId,
            moderationStatus: decision,
            status: result.published ? 'published' : 'rejected',
            isPublished: result.published,
            idempotentReplay: result.idempotentReplay
        });
    }
    catch (error) {
        if (error instanceof Error && /reason must be/.test(error.message)) {
            return res.status(400).json({ error: error.message });
        }
        console.error('Moderate track error:', error);
        return res.status(500).json({ error: 'Internal server error' });
    }
});
// PUT /v1/music/tracks/:trackId/publish - Publish track (make it live)
app.put('/v1/music/tracks/:trackId/publish', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId } = req.params;
        if (!isSafeTrackId(trackId))
            return res.status(400).json({ error: 'Invalid trackId' });
        const trackRef = db.collection('music_tracks').doc(trackId);
        const result = await db.runTransaction(async (transaction) => {
            const trackSnap = await transaction.get(trackRef);
            if (!trackSnap.exists)
                return { error: 'Track not found', status: 404 };
            const trackData = trackSnap.data();
            if (String(trackData.artistId || '') !== user.userId) {
                return { error: 'Forbidden', status: 403 };
            }
            if (trackData.isPublished === true && trackData.status === 'published') {
                return { alreadyPublished: true };
            }
            if (trackData.transcodingStatus !== 'completed' ||
                typeof trackData.hlsURL !== 'string' || trackData.hlsURL.length === 0) {
                return { error: 'Transcoding must complete before publishing', status: 409 };
            }
            if (trackData.moderationStatus !== 'approved') {
                return { error: 'Moderation approval is required before publishing', status: 409 };
            }
            transaction.update(trackRef, {
                status: 'published',
                publishedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                isPublished: true
            });
            return { alreadyPublished: false };
        });
        if ('error' in result)
            return res.status(result.status).json({ error: result.error });
        res.json({
            trackId,
            status: 'published',
            message: result.alreadyPublished ? 'Track was already published' : 'Track published successfully'
        });
    }
    catch (error) {
        console.error('Publish track error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// POST /v1/music/tracks/:trackId/plays - Record one qualified play per playback session
app.post('/v1/music/tracks/:trackId/plays', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId } = req.params;
        if (!isSafeTrackId(trackId) ||
            !hasOnlyKeys(req.body, ['sessionId', 'qualifiedSeconds']) ||
            typeof req.body.sessionId !== 'string' ||
            !SESSION_ID_PATTERN.test(req.body.sessionId)) {
            return res.status(400).json({
                error: 'sessionId must be a canonical lowercase UUID and no unexpected fields are allowed'
            });
        }
        const qualifiedSeconds = parseBoundedInteger(req.body.qualifiedSeconds, 'qualifiedSeconds', MIN_QUALIFIED_PLAY_SECONDS, MAX_QUALIFIED_PLAY_SECONDS);
        const sessionId = req.body.sessionId;
        const utcDay = new Date().toISOString().slice(0, 10);
        const playId = (0, crypto_1.createHash)('sha256')
            .update(`${user.userId}\u0000${trackId}\u0000${sessionId}`)
            .digest('hex');
        const dailyLimitId = (0, crypto_1.createHash)('sha256')
            .update(`${utcDay}\u0000${user.userId}\u0000${trackId}`)
            .digest('hex');
        const trackRef = db.collection('music_tracks').doc(trackId);
        const playRef = db.collection('music_plays').doc(playId);
        const dailyLimitRef = db.collection('music_play_daily_limits').doc(dailyLimitId);
        const result = await db.runTransaction(async (transaction) => {
            const trackSnap = await transaction.get(trackRef);
            if (!trackSnap.exists)
                return { error: 'Track not found', status: 404 };
            const track = trackSnap.data();
            if (track.isPublished !== true || track.status !== 'published') {
                return { error: 'Track is not published', status: 409 };
            }
            const playSnap = await transaction.get(playRef);
            if (playSnap.exists) {
                const existing = playSnap.data();
                if (existing.qualifiedSeconds !== qualifiedSeconds || existing.sessionId !== sessionId) {
                    return { error: 'sessionId was already used with different play data', status: 409 };
                }
                return {
                    created: false,
                    payable: existing.payable === true,
                    nonPayableReason: existing.nonPayableReason || null
                };
            }
            const dailyLimitSnap = await transaction.get(dailyLimitRef);
            const currentPlayCount = dailyLimitSnap.exists ? dailyLimitSnap.data().playCount : 0;
            if (!Number.isSafeInteger(currentPlayCount) || currentPlayCount < 0) {
                throw new Error('Invalid qualified-play daily counter');
            }
            if (currentPlayCount >= MAX_QUALIFIED_PLAYS_PER_TRACK_DAY) {
                return { error: 'Daily qualified-play limit reached for this track', status: 429 };
            }
            const artistId = String(track.artistId || '');
            if (!artistId)
                throw new Error('Published track has no artist owner');
            const isSelfStream = artistId === user.userId;
            const payable = !isSelfStream;
            const nonPayableReason = isSelfStream ? 'self_stream' : null;
            transaction.create(playRef, {
                schemaVersion: 1,
                playId,
                trackId,
                listenerId: user.userId,
                artistId,
                sessionId,
                qualifiedSeconds,
                qualifiedDay: utcDay,
                payable,
                nonPayableReason,
                monetizationStatus: payable ? 'eligible' : 'ineligible',
                immutable: true,
                createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
            });
            transaction.set(dailyLimitRef, {
                userId: user.userId,
                trackId,
                day: utcDay,
                playCount: currentPlayCount + 1,
                updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
            });
            const legacyStreamCount = Number(track.streamCount || 0);
            const currentTotalPlayCount = track.totalPlayCount !== undefined
                ? Number(track.totalPlayCount)
                : legacyStreamCount;
            if (!Number.isSafeInteger(currentTotalPlayCount) || currentTotalPlayCount < 0) {
                throw new Error('Invalid total play counter');
            }
            const counterUpdates = {
                totalPlayCount: currentTotalPlayCount + 1
            };
            if (payable) {
                // Legacy streamCount remains a payable-display compatibility counter. Self
                // and all other nonpayable qualified plays are represented only in totalPlayCount.
                if (!Number.isSafeInteger(legacyStreamCount) || legacyStreamCount < 0) {
                    throw new Error('Invalid legacy payable stream counter');
                }
                // Ambiguous legacy streamCount values may include self-streams, so a missing
                // payable counter starts at zero and only newly verified non-self plays accrue.
                const currentPayableStreamCount = track.payableStreamCount !== undefined
                    ? Number(track.payableStreamCount)
                    : 0;
                if (!Number.isSafeInteger(currentPayableStreamCount) || currentPayableStreamCount < 0) {
                    throw new Error('Invalid payable stream counter');
                }
                counterUpdates.streamCount = legacyStreamCount + 1;
                counterUpdates.payableStreamCount = currentPayableStreamCount + 1;
            }
            transaction.update(trackRef, counterUpdates);
            return { created: true, payable, nonPayableReason };
        });
        if ('error' in result)
            return res.status(result.status).json({ error: result.error });
        return res.status(result.created ? 201 : 200).json({
            playId,
            trackId,
            sessionId,
            qualifiedSeconds,
            payable: result.payable,
            nonPayableReason: result.nonPayableReason,
            idempotentReplay: !result.created
        });
    }
    catch (error) {
        if (error instanceof Error && /qualifiedSeconds must be/.test(error.message)) {
            return res.status(400).json({ error: error.message });
        }
        console.error('Record qualified play error:', error);
        return res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/tracks/:trackId/collaborators - Read the owner-authorized integer split
app.get('/v1/music/tracks/:trackId/collaborators', async (req, res) => {
    var _a;
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId } = req.params;
        if (!isSafeTrackId(trackId))
            return res.status(400).json({ error: 'Invalid trackId' });
        const trackRef = db.collection('music_tracks').doc(trackId);
        const splitRef = db.collection('music_track_collaborators').doc(trackId);
        const [trackSnap, splitSnap] = await Promise.all([trackRef.get(), splitRef.get()]);
        if (!trackSnap.exists)
            return res.status(404).json({ error: 'Track not found' });
        if (String(((_a = trackSnap.data()) === null || _a === void 0 ? void 0 : _a.artistId) || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        const split = splitSnap.exists ? splitSnap.data() : null;
        if (!split) {
            return res.json({ trackId, totalBasisPoints: 0, collaborators: [], revision: 0 });
        }
        if (String(split.ownerArtistId || '') !== user.userId || !Array.isArray(split.collaborators)) {
            return res.status(409).json({ error: 'Collaborator split metadata is invalid' });
        }
        const collaborators = split.collaborators.map((collaborator) => ({
            artistId: collaborator.artistId,
            name: collaborator.name,
            role: collaborator.role,
            basisPoints: collaborator.revenueShareBasisPoints
        }));
        return res.json({
            trackId,
            totalBasisPoints: split.totalBasisPoints,
            collaborators,
            revision: split.revision || 0
        });
    }
    catch (error) {
        console.error('Get collaborator splits error:', error);
        return res.status(500).json({ error: 'Internal server error' });
    }
});
// PUT /v1/music/tracks/:trackId/collaborators - Replace the complete owner-authorized split
app.put('/v1/music/tracks/:trackId/collaborators', async (req, res) => {
    var _a;
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId } = req.params;
        if (!isSafeTrackId(trackId) || !hasOnlyKeys(req.body, ['collaborators']) ||
            !Array.isArray(req.body.collaborators) || req.body.collaborators.length < 1 ||
            req.body.collaborators.length > MAX_TRACK_COLLABORATORS) {
            return res.status(400).json({
                error: `collaborators must contain between 1 and ${MAX_TRACK_COLLABORATORS} entries`
            });
        }
        const seenArtistIds = new Set();
        const collaborators = req.body.collaborators.map((value, index) => {
            if (!hasOnlyKeys(value, ['artistId', 'name', 'role', 'basisPoints']) ||
                !isSafeArtistId(value.artistId)) {
                throw new Error(`collaborators[${index}] has an invalid artistId or unexpected field`);
            }
            if (seenArtistIds.has(value.artistId)) {
                throw new Error(`collaborators[${index}].artistId must be unique`);
            }
            seenArtistIds.add(value.artistId);
            const name = boundedString(value.name, `collaborators[${index}].name`, 1, 120);
            const role = boundedString(value.role, `collaborators[${index}].role`, 1, 40);
            if (!COLLABORATOR_ROLES.has(role)) {
                throw new Error(`collaborators[${index}].role is not supported`);
            }
            const basisPoints = parseBoundedInteger(value.basisPoints, `collaborators[${index}].basisPoints`, 1, TOTAL_SPLIT_BASIS_POINTS);
            return {
                id: value.artistId,
                artistId: value.artistId,
                name,
                role,
                revenueShareBasisPoints: basisPoints
            };
        });
        const totalBasisPoints = collaborators.reduce((sum, collaborator) => sum + collaborator.revenueShareBasisPoints, 0);
        if (totalBasisPoints !== TOTAL_SPLIT_BASIS_POINTS) {
            return res.status(400).json({ error: 'Collaborator basisPoints must total exactly 10000' });
        }
        const trackRef = db.collection('music_tracks').doc(trackId);
        const authorizationSnap = await trackRef.get();
        if (!authorizationSnap.exists)
            return res.status(404).json({ error: 'Track not found' });
        if (String(((_a = authorizationSnap.data()) === null || _a === void 0 ? void 0 : _a.artistId) || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        const artistLookup = await firebase_admin_1.default.auth().getUsers(collaborators.map((collaborator) => ({ uid: collaborator.artistId })));
        if (artistLookup.notFound.length > 0) {
            return res.status(400).json({ error: 'Every collaborator artistId must identify an existing user' });
        }
        const splitRef = db.collection('music_track_collaborators').doc(trackId);
        const payoutLockRef = db.collection('music_payout_locks').doc(user.userId);
        const result = await db.runTransaction(async (transaction) => {
            var _a, _b, _c;
            const [trackSnap, splitSnap, payoutLockSnap] = await Promise.all([
                transaction.get(trackRef),
                transaction.get(splitRef),
                transaction.get(payoutLockRef)
            ]);
            if (!trackSnap.exists)
                return { error: 'Track not found', status: 404 };
            const track = trackSnap.data();
            const ownerArtistId = String(track.artistId || '');
            if (ownerArtistId !== user.userId)
                return { error: 'Forbidden', status: 403 };
            if (!collaborators.some((collaborator) => collaborator.artistId === ownerArtistId && collaborator.role === 'primary_artist')) {
                return { error: 'The track owner must be included as primary_artist', status: 400 };
            }
            if (payoutLockSnap.exists && ((_a = payoutLockSnap.data()) === null || _a === void 0 ? void 0 : _a.status) === 'pending') {
                return { error: 'Collaborator splits cannot change during a pending payout', status: 409 };
            }
            const previousRevision = splitSnap.exists ? (_b = splitSnap.data()) === null || _b === void 0 ? void 0 : _b.revision : 0;
            const revision = Number.isSafeInteger(previousRevision) && previousRevision >= 0
                ? previousRevision + 1 : 1;
            transaction.set(splitRef, {
                schemaVersion: 2,
                trackId,
                ownerArtistId,
                splitUnit: 'basis_points',
                totalBasisPoints,
                collaborators,
                revision,
                createdAt: splitSnap.exists
                    ? ((_c = splitSnap.data()) === null || _c === void 0 ? void 0 : _c.createdAt) || firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
                    : firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                updatedBy: user.userId
            });
            return { revision };
        });
        if ('error' in result)
            return res.status(result.status).json({ error: result.error });
        return res.json({
            trackId,
            totalBasisPoints,
            collaborators: collaborators.map((collaborator) => ({
                artistId: collaborator.artistId,
                name: collaborator.name,
                role: collaborator.role,
                basisPoints: collaborator.revenueShareBasisPoints
            })),
            revision: result.revision
        });
    }
    catch (error) {
        if (error instanceof Error && /collaborators\[|basisPoints|must be|not supported/.test(error.message)) {
            return res.status(400).json({ error: error.message });
        }
        console.error('Update collaborator splits error:', error);
        return res.status(500).json({ error: 'Internal server error' });
    }
});
// POST /v1/music/tracks/:trackId/likes - Idempotently like a published track
app.post('/v1/music/tracks/:trackId/likes', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId } = req.params;
        const body = req.body || {};
        if (!isSafeTrackId(trackId) || !hasOnlyKeys(body, [])) {
            return res.status(400).json({ error: 'Invalid like request' });
        }
        const likeId = (0, crypto_1.createHash)('sha256')
            .update(`${user.userId}\u0000${trackId}`)
            .digest('hex');
        const trackRef = db.collection('music_tracks').doc(trackId);
        const likeRef = db.collection('music_track_likes').doc(likeId);
        const result = await db.runTransaction(async (transaction) => {
            const trackSnap = await transaction.get(trackRef);
            if (!trackSnap.exists)
                return { error: 'Track not found', status: 404 };
            const track = trackSnap.data();
            if (track.isPublished !== true || track.status !== 'published') {
                return { error: 'Track is not published', status: 409 };
            }
            const likeSnap = await transaction.get(likeRef);
            const currentLikeCount = Number(track.likeCount || 0);
            if (!Number.isSafeInteger(currentLikeCount) || currentLikeCount < 0) {
                throw new Error('Invalid track like counter');
            }
            if (likeSnap.exists)
                return { created: false, likeCount: currentLikeCount };
            transaction.create(likeRef, {
                schemaVersion: 1,
                likeId,
                trackId,
                userId: user.userId,
                immutable: true,
                createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
            });
            transaction.update(trackRef, {
                likeCount: firebase_admin_1.default.firestore.FieldValue.increment(1)
            });
            return { created: true, likeCount: currentLikeCount + 1 };
        });
        if ('error' in result)
            return res.status(result.status).json({ error: result.error });
        return res.status(result.created ? 201 : 200).json({
            trackId,
            liked: true,
            likeCount: result.likeCount,
            idempotentReplay: !result.created
        });
    }
    catch (error) {
        console.error('Like track error:', error);
        return res.status(500).json({ error: 'Internal server error' });
    }
});
// PUT /v1/music/tracks/:trackId - Edit track metadata
app.put('/v1/music/tracks/:trackId', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId } = req.params;
        if (!isSafeTrackId(trackId) ||
            !hasOnlyKeys(req.body, ['title', 'albumName', 'genre', 'isExplicit']) ||
            Object.keys(req.body).length === 0) {
            return res.status(400).json({ error: 'Invalid metadata update' });
        }
        const trackRef = db.collection('music_tracks').doc(trackId);
        const trackSnap = await trackRef.get();
        if (!trackSnap.exists)
            return res.status(404).json({ error: 'Track not found' });
        const trackData = trackSnap.data();
        if (String(trackData.artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        const updates = {};
        if (req.body.title !== undefined) {
            updates.title = boundedString(req.body.title, 'title', 1, 200);
        }
        if (req.body.albumName !== undefined) {
            updates.albumName = optionalBoundedString(req.body.albumName, 'albumName', 200);
        }
        if (req.body.genre !== undefined) {
            updates.genre = boundedString(req.body.genre, 'genre', 1, 64);
        }
        if (req.body.isExplicit !== undefined) {
            if (typeof req.body.isExplicit !== 'boolean') {
                return res.status(400).json({ error: 'isExplicit must be a boolean' });
            }
            updates.isExplicit = req.body.isExplicit;
        }
        updates.updatedAt = firebase_admin_1.default.firestore.FieldValue.serverTimestamp();
        await trackRef.update(updates);
        res.json({ trackId, message: 'Track updated successfully' });
    }
    catch (error) {
        if (error instanceof Error && /must be|Invalid metadata/.test(error.message)) {
            return res.status(400).json({ error: error.message });
        }
        console.error('Edit track error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// DELETE /v1/music/tracks/:trackId - Delete track
app.delete('/v1/music/tracks/:trackId', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId } = req.params;
        if (!isSafeTrackId(trackId))
            return res.status(400).json({ error: 'Invalid trackId' });
        const trackRef = db.collection('music_tracks').doc(trackId);
        const trackSnap = await trackRef.get();
        if (!trackSnap.exists) {
            return res.status(404).json({ error: 'Track not found' });
        }
        const trackData = trackSnap.data();
        if (String(trackData.artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        // Delete the private master by its deterministic storage path, never by a URL.
        const processingRef = db.collection('music_track_processing').doc(trackId);
        const processingSnap = await processingRef.get();
        const processingData = processingSnap.exists ? processingSnap.data() : null;
        const privateMasterPath = processingData && String(processingData.ownerUid || '') === user.userId
            ? processingData.masterPath : null;
        // The track fallback is cleanup-only for documents created before private metadata migration.
        const masterPath = typeof privateMasterPath === 'string'
            ? privateMasterPath
            : (typeof trackData.masterPath === 'string' ? trackData.masterPath : '');
        const expectedMasterPrefix = `music/${user.userId}/tracks/${trackId}.`;
        if (masterPath.startsWith(expectedMasterPrefix) &&
            /\.(mp3|m4a|wav|flac|aac|ogg)$/.test(masterPath)) {
            await bucket.file(masterPath).delete().catch(() => { });
        }
        // Delete all owner-bound upload artifacts. Prefixes are deterministic and
        // cannot target another artist's objects.
        await Promise.all([
            bucket.deleteFiles({ prefix: `music/${user.userId}/artwork/${trackId}.` }).catch(() => undefined),
            bucket.deleteFiles({ prefix: `music/${user.userId}/renditions/${trackId}/` }).catch(() => undefined),
            bucket.deleteFiles({ prefix: `music/temp/${user.userId}/${trackId}/` }).catch(() => undefined)
        ]);
        // Delete Firestore documents together so private processing metadata is not orphaned.
        const deleteBatch = db.batch();
        deleteBatch.delete(trackRef);
        deleteBatch.delete(processingRef);
        await deleteBatch.commit();
        res.json({
            trackId,
            message: 'Track deleted successfully'
        });
    }
    catch (error) {
        console.error('Delete track error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
app.use((error, _req, res, next) => {
    if ((error === null || error === void 0 ? void 0 : error.type) === 'entity.too.large') {
        return res.status(413).json({ error: 'Request body exceeds the allowed size' });
    }
    if (error instanceof SyntaxError) {
        return res.status(400).json({ error: 'Invalid JSON body' });
    }
    next(error);
});
exports.music = app;
if (require.main === module) {
    const PORT = process.env.PORT || 8080;
    app.listen(PORT, () => {
        console.log(`🎵 Music service listening on port ${PORT}`);
    });
}
