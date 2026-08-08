"use strict";
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
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const storage_1 = require("@google-cloud/storage");
const google_auth_library_1 = require("google-auth-library");
const child_process_1 = require("child_process");
const crypto_1 = require("crypto");
const fs = __importStar(require("fs"));
const os = __importStar(require("os"));
const path = __importStar(require("path"));
const fingerprint_1 = require("./fingerprint");
const app = (0, express_1.default)();
app.use(express_1.default.json({ limit: '10mb' }));
const PROJECT_ID = process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT || 'mychannel-ca26d';
const BUCKET_NAME = process.env.MUSIC_STORAGE_BUCKET ||
    process.env.FIREBASE_STORAGE_BUCKET ||
    process.env.MUSIC_BUCKET ||
    `${PROJECT_ID}.firebasestorage.app`;
if (!firebase_admin_1.default.apps.length) {
    firebase_admin_1.default.initializeApp({
        credential: firebase_admin_1.default.credential.applicationDefault(),
        projectId: PROJECT_ID,
        storageBucket: BUCKET_NAME,
    });
}
const db = firebase_admin_1.default.firestore();
const storage = new storage_1.Storage({ projectId: PROJECT_ID });
const bucket = storage.bucket(BUCKET_NAME);
const ENABLE_LOSSLESS = (process.env.ENABLE_LOSSLESS || 'true') === 'true';
const oidcVerifier = new google_auth_library_1.OAuth2Client();
async function requireUser(req, res) {
    try {
        const authHeader = req.headers.authorization;
        if (!(authHeader === null || authHeader === void 0 ? void 0 : authHeader.startsWith('Bearer '))) {
            res.status(401).json({ error: 'Unauthorized' });
            return null;
        }
        const token = authHeader.split('Bearer ')[1];
        const decoded = await firebase_admin_1.default.auth().verifyIdToken(token);
        return {
            userId: decoded.uid,
            email: decoded.email,
            emailVerified: decoded.email_verified === true,
            isAdmin: decoded.admin === true
        };
    }
    catch (_a) {
        res.status(401).json({ error: 'Invalid token' });
        return null;
    }
}
async function requireTranscodeActor(req, res) {
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
        const decoded = await firebase_admin_1.default.auth().verifyIdToken(token);
        return {
            userId: decoded.uid,
            email: decoded.email,
            emailVerified: decoded.email_verified === true,
            isAdmin: decoded.admin === true,
            isService: false
        };
    }
    catch (_a) {
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
        }
        catch (_b) {
            res.status(401).json({ error: 'Invalid token' });
            return null;
        }
    }
}
const ADMIN_EMAILS = new Set([
    'keontapeat@mychannel.live',
    'keontapeat@gmail.com'
]);
function userIsAdmin(user) {
    return (user === null || user === void 0 ? void 0 : user.isAdmin) === true ||
        ((user === null || user === void 0 ? void 0 : user.emailVerified) === true && ADMIN_EMAILS.has(user.email));
}
function run(cmd, args) {
    return new Promise((resolve, reject) => {
        const proc = (0, child_process_1.spawn)(cmd, args);
        let stderr = '';
        proc.stderr.on('data', (d) => (stderr += d.toString()));
        proc.on('error', reject);
        proc.on('close', (code) => {
            if (code === 0)
                resolve();
            else
                reject(new Error(`${cmd} exited ${code}: ${stderr.slice(-500)}`));
        });
    });
}
/** Download a validated in-bucket master object to a local temp file. */
async function downloadToTmp(masterPath, dest) {
    await bucket.file(masterPath).download({ destination: dest });
}
function isSafeTrackId(value) {
    return /^[A-Za-z0-9_-]{1,128}$/.test(value);
}
/** Masters are accepted only from the upload service's deterministic private path. */
function validatedMasterPath(value, ownerId, trackId) {
    if (typeof value !== 'string' || value.length > 512)
        return null;
    const segments = value.split('/');
    if (segments.length !== 4 || segments[0] !== 'music' ||
        segments[1] !== ownerId || segments[2] !== 'tracks') {
        return null;
    }
    const fileMatch = segments[3].match(/^([A-Za-z0-9_-]{1,128})\.(mp3|m4a|wav|flac|aac|ogg)$/);
    if (!fileMatch || fileMatch[1] !== trackId)
        return null;
    return value;
}
function publicRenditionURL(destination, downloadToken) {
    return `https://firebasestorage.googleapis.com/v0/b/${encodeURIComponent(bucket.name)}` +
        `/o/${encodeURIComponent(destination)}?alt=media&token=${downloadToken}`;
}
function publicRenditions(track) {
    const source = track.renditions && typeof track.renditions === 'object'
        ? track.renditions : {};
    const candidates = {
        hls: source.hls || track.hlsURL,
        mp3: source.mp3 || track.mp3URL,
        flac: source.flac || track.losslessURL
    };
    const renditions = {};
    for (const [key, value] of Object.entries(candidates)) {
        if (typeof value === 'string' && value.startsWith('https://'))
            renditions[key] = value;
    }
    return renditions;
}
async function uploadPublicRendition(localPath, destination, contentType, downloadToken) {
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
    var _a;
    const actor = await requireTranscodeActor(req, res);
    if (!actor)
        return;
    const body = req.body && typeof req.body === 'object' && !Array.isArray(req.body)
        ? req.body : {};
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
    if (!isSafeTrackId(trackId))
        return res.status(400).json({ error: 'Invalid trackId' });
    const trackRef = db.collection('music_tracks').doc(trackId);
    const processingRef = db.collection('music_track_processing').doc(trackId);
    const [trackSnap, processingSnap] = await Promise.all([trackRef.get(), processingRef.get()]);
    if (!trackSnap.exists)
        return res.status(404).json({ error: 'Track not found' });
    const track = trackSnap.data();
    if (String(track.artistId || '') !== user.userId) {
        return res.status(403).json({ error: 'Forbidden' });
    }
    if (processingSnap.exists && String(((_a = processingSnap.data()) === null || _a === void 0 ? void 0 : _a.ownerUid) || '') !== user.userId) {
        return res.status(409).json({ error: 'Private processing ownership does not match the track owner' });
    }
    const claim = await db.runTransaction(async (transaction) => {
        var _a, _b, _c, _d, _e;
        const [currentTrackSnap, currentProcessingSnap] = await Promise.all([
            transaction.get(trackRef),
            transaction.get(processingRef)
        ]);
        if (!currentTrackSnap.exists)
            return { error: 'Track not found', status: 404 };
        const currentTrack = currentTrackSnap.data();
        if (String(currentTrack.artistId || '') !== user.userId) {
            return { error: 'Forbidden', status: 403 };
        }
        const processing = currentProcessingSnap.exists ? currentProcessingSnap.data() : null;
        if (processing && String(processing.ownerUid || '') !== user.userId) {
            return { error: 'Private processing ownership does not match the track owner', status: 409 };
        }
        if (currentTrack.transcodingStatus === 'completed' || (processing === null || processing === void 0 ? void 0 : processing.processingStatus) === 'completed') {
            return { completed: true };
        }
        if (currentTrack.transcodingStatus === 'in_progress' || (processing === null || processing === void 0 ? void 0 : processing.processingStatus) === 'in_progress') {
            return { inProgress: true };
        }
        // Legacy fallback is owner-bound and is migrated out of the public track atomically.
        const masterPath = validatedMasterPath((_a = processing === null || processing === void 0 ? void 0 : processing.masterPath) !== null && _a !== void 0 ? _a : currentTrack.masterPath, user.userId, trackId);
        if (!masterPath)
            return { error: 'Track has no valid deterministic private masterPath', status: 409 };
        transaction.update(trackRef, {
            audioURL: firebase_admin_1.default.firestore.FieldValue.delete(),
            masterURL: firebase_admin_1.default.firestore.FieldValue.delete(),
            masterPath: firebase_admin_1.default.firestore.FieldValue.delete(),
            masterSizeBytes: firebase_admin_1.default.firestore.FieldValue.delete(),
            masterContentType: firebase_admin_1.default.firestore.FieldValue.delete(),
            transcodingStatus: 'in_progress',
            transcodeStartedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
        });
        transaction.set(processingRef, {
            schemaVersion: 1,
            trackId,
            ownerUid: user.userId,
            masterPath,
            masterSizeBytes: (_c = (_b = processing === null || processing === void 0 ? void 0 : processing.masterSizeBytes) !== null && _b !== void 0 ? _b : currentTrack.masterSizeBytes) !== null && _c !== void 0 ? _c : null,
            masterContentType: (_e = (_d = processing === null || processing === void 0 ? void 0 : processing.masterContentType) !== null && _d !== void 0 ? _d : currentTrack.masterContentType) !== null && _e !== void 0 ? _e : null,
            processingStatus: 'in_progress',
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            createdAt: (processing === null || processing === void 0 ? void 0 : processing.createdAt) || firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        return { started: true, masterPath };
    });
    if ('error' in claim)
        return res.status(claim.status).json({ error: claim.error });
    if ('completed' in claim) {
        return res.json({ trackId, status: 'completed', renditions: publicRenditions(track) });
    }
    if ('inProgress' in claim) {
        return res.status(202).json({ trackId, status: 'in_progress', idempotentReplay: true });
    }
    const masterPath = claim.masterPath;
    const work = fs.mkdtempSync(path.join(os.tmpdir(), `mch_${trackId}_`));
    const masterLocal = path.join(work, 'master.input');
    try {
        // masterPath was generated by the upload service and never accepts a URL.
        await downloadToTmp(masterPath, masterLocal);
        const basePath = `music/${user.userId}/renditions/${trackId}`;
        const outputs = {};
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
        const renditionToken = (0, crypto_1.randomUUID)();
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
            await uploadPublicRendition(localFile, dest, file.endsWith('.m3u8') ? 'application/vnd.apple.mpegurl' : 'audio/aac', renditionToken);
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
            const probe = await new Promise((resolve, reject) => {
                const p = (0, child_process_1.spawn)('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'default=nw=1:nk=1', masterLocal]);
                let out = '';
                p.stdout.on('data', (d) => (out += d.toString()));
                p.on('error', reject);
                p.on('close', () => resolve(out.trim()));
            });
            if (probe)
                duration = parseFloat(probe);
        }
        catch ( /* keep existing duration */_b) { /* keep existing duration */ }
        // Compute a REAL chromaprint fingerprint from the master and register it in
        // Content ID so this track is protected and can be matched against uploads.
        let fingerprintRegistered = false;
        try {
            const fp = await (0, fingerprint_1.chromaprintFile)(masterLocal);
            if (fp.frames.length > 0) {
                await db.collection('music_content_id').doc(trackId).set({
                    trackId,
                    artistId: user.userId,
                    fingerprint: fp,
                    fingerprintHash: (0, fingerprint_1.fingerprintHash)(fp),
                    fingerprintProvider: 'chromaprint',
                    registeredAt: firebase_admin_1.default.firestore.Timestamp.now(),
                    status: 'active',
                    copyrightPolicy: track.contentIdPolicy || 'strict',
                    revenueSharePercentage: null,
                    source: 'transcode_auto',
                }, { merge: true });
                fingerprintRegistered = true;
            }
        }
        catch (e) {
            console.warn(`Fingerprint skipped for ${trackId}: ${e.message}`);
        }
        const completionBatch = db.batch();
        completionBatch.update(trackRef, {
            audioURL: firebase_admin_1.default.firestore.FieldValue.delete(),
            masterURL: firebase_admin_1.default.firestore.FieldValue.delete(),
            masterPath: firebase_admin_1.default.firestore.FieldValue.delete(),
            masterSizeBytes: firebase_admin_1.default.firestore.FieldValue.delete(),
            masterContentType: firebase_admin_1.default.firestore.FieldValue.delete(),
            transcodeError: firebase_admin_1.default.firestore.FieldValue.delete(),
            transcodingStatus: 'completed',
            transcodeCompletedAt: firebase_admin_1.default.firestore.Timestamp.now(),
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
            transcodeCompletedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            transcodeError: firebase_admin_1.default.firestore.FieldValue.delete(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        await completionBatch.commit();
        res.json({ trackId, status: 'completed', renditions: outputs, duration, fingerprintRegistered });
    }
    catch (error) {
        console.error('Transcode error:', error);
        const failureBatch = db.batch();
        failureBatch.update(trackRef, {
            transcodingStatus: 'error',
            transcodeError: firebase_admin_1.default.firestore.FieldValue.delete()
        });
        failureBatch.set(processingRef, {
            processingStatus: 'error',
            transcodeError: String((error === null || error === void 0 ? void 0 : error.message) || 'Transcode failed').slice(0, 500),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        await failureBatch.commit().catch(() => { });
        res.status(500).json({ error: 'Transcode failed' });
    }
    finally {
        fs.rmSync(work, { recursive: true, force: true });
    }
});
// GET /v1/music/transcode/:trackId/status
app.get('/v1/music/transcode/:trackId/status', async (req, res) => {
    const { trackId } = req.params;
    if (!isSafeTrackId(trackId))
        return res.status(400).json({ error: 'Invalid trackId' });
    const snap = await db.collection('music_tracks').doc(trackId).get();
    if (!snap.exists)
        return res.status(404).json({ error: 'Track not found' });
    const track = snap.data();
    const isPublished = track.isPublished === true && track.status === 'published';
    if (!isPublished) {
        const user = await requireUser(req, res);
        if (!user)
            return;
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
