"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const codes_1 = require("./codes");
const ddex_1 = require("./ddex");
const aggregator_1 = require("./aggregator");
const app = (0, express_1.default)();
app.use(express_1.default.json({ limit: '10mb' }));
if (!firebase_admin_1.default.apps.length) {
    firebase_admin_1.default.initializeApp({
        credential: firebase_admin_1.default.credential.applicationDefault(),
        projectId: 'mychannel-ca26d'
    });
}
const db = firebase_admin_1.default.firestore();
async function requireUser(req, res) {
    try {
        const authHeader = req.headers.authorization;
        if (!(authHeader === null || authHeader === void 0 ? void 0 : authHeader.startsWith('Bearer '))) {
            res.status(401).json({ error: 'Unauthorized' });
            return null;
        }
        const token = authHeader.split('Bearer ')[1];
        const decoded = await firebase_admin_1.default.auth().verifyIdToken(token);
        return { userId: decoded.uid, email: decoded.email };
    }
    catch (error) {
        res.status(401).json({ error: 'Invalid token' });
        return null;
    }
}
const VALID_PLATFORMS = ['spotify', 'apple_music', 'youtube_music', 'amazon_music', 'tidal', 'deezer'];
// ─────────────────────────────────────────────────────────────────────────────
// Code allocation — real ISRC / UPC
// ─────────────────────────────────────────────────────────────────────────────
// POST /v1/music/codes/isrc — allocate a registered ISRC for a track
app.post('/v1/music/codes/isrc', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId } = req.body || {};
        if (!trackId)
            return res.status(400).json({ error: 'trackId is required' });
        const trackRef = db.collection('music_tracks').doc(trackId);
        const trackSnap = await trackRef.get();
        if (!trackSnap.exists)
            return res.status(404).json({ error: 'Track not found' });
        if (String(trackSnap.data().artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        const existing = trackSnap.data().isrc;
        if (existing && (0, codes_1.isValidISRC)(existing)) {
            return res.json({ trackId, isrc: existing, reused: true });
        }
        const isrc = await (0, codes_1.allocateISRC)();
        await trackRef.update({ isrc, isrcAllocatedAt: firebase_admin_1.default.firestore.Timestamp.now() });
        res.json({ trackId, isrc, reused: false });
    }
    catch (error) {
        console.error('Allocate ISRC error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});
// POST /v1/music/codes/upc — allocate a UPC/EAN for a release (album/single)
app.post('/v1/music/codes/upc', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { albumId } = req.body || {};
        if (!albumId)
            return res.status(400).json({ error: 'albumId is required' });
        const albumRef = db.collection('music_albums').doc(albumId);
        const albumSnap = await albumRef.get();
        if (!albumSnap.exists)
            return res.status(404).json({ error: 'Album not found' });
        if (String(albumSnap.data().artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        const existing = albumSnap.data().upc;
        if (existing && (0, codes_1.isValidUPC)(existing)) {
            return res.json({ albumId, upc: existing, reused: true });
        }
        const upc = await (0, codes_1.allocateUPC)();
        await albumRef.update({ upc, upcAllocatedAt: firebase_admin_1.default.firestore.Timestamp.now() });
        res.json({ albumId, upc, reused: false });
    }
    catch (error) {
        console.error('Allocate UPC error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});
// ─────────────────────────────────────────────────────────────────────────────
// Distribution — real DDEX ERN generation + aggregator delivery
// ─────────────────────────────────────────────────────────────────────────────
/** Assemble a DDEXRelease from a single track (single release) or album. */
async function buildReleaseFromTrack(trackId, ownerId) {
    var _a, _b;
    const trackRef = db.collection('music_tracks').doc(trackId);
    const trackSnap = await trackRef.get();
    if (!trackSnap.exists)
        return { error: 'Track not found' };
    const t = trackSnap.data();
    if (String(t.artistId || '') !== ownerId)
        return { error: 'Forbidden' };
    if (!t.audioURL)
        return { error: 'Track has no audio file' };
    // Ensure a real ISRC.
    let isrc = t.isrc;
    if (!isrc || !(0, codes_1.isValidISRC)(isrc)) {
        isrc = await (0, codes_1.allocateISRC)();
        await trackRef.update({ isrc });
    }
    // Ensure a real UPC at the release level (single uses its own UPC).
    let upc = t.upc;
    if (!upc || !(0, codes_1.isValidUPC)(upc)) {
        upc = await (0, codes_1.allocateUPC)();
        await trackRef.update({ upc });
    }
    const contributors = [];
    if (t.producer)
        contributors.push({ name: t.producer, role: 'Producer' });
    if (t.songwriter)
        contributors.push({ name: t.songwriter, role: 'Composer' });
    const ddexTrack = {
        trackId,
        isrc,
        title: t.title || 'Untitled',
        durationSeconds: t.duration || 0,
        artistName: t.artistName || '',
        contributors,
        genre: t.genre,
        isExplicit: !!t.isExplicit,
        audioURL: t.audioURL,
        trackNumber: 1,
        pLineYear: String(t.copyrightYear || new Date().getFullYear()),
        pLineText: t.copyrightOwner || t.artistName,
    };
    const release = {
        releaseId: trackId,
        upc,
        title: t.title || 'Untitled',
        displayArtist: t.artistName || '',
        releaseType: 'Single',
        genre: t.genre,
        label: t.recordLabel || undefined,
        cLineYear: String(t.copyrightYear || new Date().getFullYear()),
        cLineText: t.copyrightOwner || t.artistName,
        pLineYear: String(t.copyrightYear || new Date().getFullYear()),
        pLineText: t.copyrightOwner || t.artistName,
        releaseDate: (((_b = (_a = t.releaseDate) === null || _a === void 0 ? void 0 : _a.toDate) === null || _b === void 0 ? void 0 : _b.call(_a)) || new Date()).toISOString().slice(0, 10),
        artworkURL: t.artworkURL || '',
        tracks: [ddexTrack],
    };
    return { release, audioURLs: [t.audioURL] };
}
// POST /v1/music/distribution/submit — generate DDEX + deliver to platforms
app.post('/v1/music/distribution/submit', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId, platforms } = req.body || {};
        if (!trackId || typeof trackId !== 'string') {
            return res.status(400).json({ error: 'trackId is required' });
        }
        if (!platforms || !Array.isArray(platforms) || platforms.length === 0) {
            return res.status(400).json({ error: 'platforms array is required' });
        }
        const invalid = platforms.filter((p) => !VALID_PLATFORMS.includes(p));
        if (invalid.length > 0) {
            return res.status(400).json({ error: `Invalid platforms: ${invalid.join(', ')}` });
        }
        const built = await buildReleaseFromTrack(trackId, user.userId);
        if ('error' in built) {
            const code = built.error === 'Forbidden' ? 403 : (built.error === 'Track not found' ? 404 : 400);
            return res.status(code).json({ error: built.error });
        }
        const trackRef = db.collection('music_tracks').doc(trackId);
        const trackData = (await trackRef.get()).data();
        if (trackData.status !== 'published') {
            return res.status(400).json({ error: 'Track must be published before distribution' });
        }
        // Generate the real DDEX ERN feed.
        const ernXml = (0, ddex_1.buildERNMessage)(built.release);
        // Deliver via the configured provider/aggregator.
        const delivery = await (0, aggregator_1.deliverRelease)({
            ernXml,
            audioURLs: built.audioURLs,
            artworkURL: built.release.artworkURL,
            upc: built.release.upc,
            releaseId: built.release.releaseId,
        });
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        const distributionRef = db.collection('music_distribution').doc();
        const platformStatuses = {};
        platforms.forEach((platform) => {
            platformStatuses[platform] = {
                status: delivery.status === 'error' ? 'error' : 'delivered',
                submittedAt: now,
                deliveredAt: delivery.status !== 'error' ? now : null,
                liveAt: null,
                rejectionReason: delivery.status === 'error' ? delivery.message : null,
            };
        });
        await distributionRef.set({
            id: distributionRef.id,
            trackId,
            artistId: user.userId,
            isrc: built.release.tracks[0].isrc,
            upc: built.release.upc,
            platforms,
            platformStatuses,
            provider: delivery.provider,
            providerDeliveryId: delivery.deliveryId,
            overallStatus: delivery.status === 'error' ? 'error' : 'delivered',
            ernMessageStored: true,
            submittedAt: now,
            updatedAt: now,
        });
        // Store the ERN XML for audit/retry.
        await db.collection('music_distribution_ern').doc(distributionRef.id).set({
            distributionId: distributionRef.id,
            trackId,
            ernXml,
            createdAt: now,
        });
        await trackRef.update({
            distributionStatus: delivery.status === 'error' ? 'error' : 'submitted',
            distributionId: distributionRef.id,
            distributionSubmittedAt: now,
            isrc: built.release.tracks[0].isrc,
            upc: built.release.upc,
        });
        res.status(delivery.status === 'error' ? 502 : 201).json({
            distributionId: distributionRef.id,
            trackId,
            isrc: built.release.tracks[0].isrc,
            upc: built.release.upc,
            provider: delivery.provider,
            providerDeliveryId: delivery.deliveryId,
            platforms,
            status: delivery.status,
            message: delivery.message,
        });
    }
    catch (error) {
        console.error('Submit distribution error:', error);
        res.status(500).json({ error: error.message || 'Internal server error' });
    }
});
// GET /v1/music/distribution/:trackId/status — per-platform status
app.get('/v1/music/distribution/:trackId/status', async (req, res) => {
    var _a, _b;
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId } = req.params;
        const trackRef = db.collection('music_tracks').doc(trackId);
        const trackSnap = await trackRef.get();
        if (!trackSnap.exists)
            return res.status(404).json({ error: 'Track not found' });
        const trackData = trackSnap.data();
        if (String(trackData.artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        if (!trackData.distributionId) {
            return res.status(404).json({ error: 'No distribution found for this track' });
        }
        const distSnap = await db.collection('music_distribution').doc(trackData.distributionId).get();
        if (!distSnap.exists)
            return res.status(404).json({ error: 'Distribution record not found' });
        const d = distSnap.data();
        res.json({
            distributionId: d.id,
            trackId,
            isrc: d.isrc,
            upc: d.upc,
            provider: d.provider,
            providerDeliveryId: d.providerDeliveryId,
            overallStatus: d.overallStatus,
            platforms: d.platformStatuses,
            submittedAt: (_a = d.submittedAt) === null || _a === void 0 ? void 0 : _a.toDate().toISOString(),
            updatedAt: (_b = d.updatedAt) === null || _b === void 0 ? void 0 : _b.toDate().toISOString(),
        });
    }
    catch (error) {
        console.error('Get distribution status error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// PUT /v1/music/distribution/:trackId/platforms/:platform/takedown
app.put('/v1/music/distribution/:trackId/platforms/:platform/takedown', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId, platform } = req.params;
        if (!VALID_PLATFORMS.includes(platform)) {
            return res.status(400).json({ error: `Invalid platform: ${platform}` });
        }
        const trackRef = db.collection('music_tracks').doc(trackId);
        const trackSnap = await trackRef.get();
        if (!trackSnap.exists)
            return res.status(404).json({ error: 'Track not found' });
        const trackData = trackSnap.data();
        if (String(trackData.artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        if (!trackData.distributionId) {
            return res.status(404).json({ error: 'No distribution found for this track' });
        }
        const distRef = db.collection('music_distribution').doc(trackData.distributionId);
        const distSnap = await distRef.get();
        if (!distSnap.exists)
            return res.status(404).json({ error: 'Distribution record not found' });
        const platformStatus = distSnap.data().platformStatuses[platform];
        if (!platformStatus || !['delivered', 'live', 'approved'].includes(platformStatus.status)) {
            return res.status(400).json({ error: `Track is not currently distributed to ${platform}` });
        }
        await distRef.update({
            [`platformStatuses.${platform}.status`]: 'takedown_requested',
            [`platformStatuses.${platform}.takedownRequestedAt`]: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        });
        res.json({ message: `Takedown requested for ${platform}`, platform, status: 'takedown_requested' });
    }
    catch (error) {
        console.error('Platform takedown error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// POST /v1/music/distribution/webhook — provider callback to update live status
app.post('/v1/music/distribution/webhook', async (req, res) => {
    try {
        const { providerDeliveryId, platform, status, liveUrl } = req.body || {};
        if (!providerDeliveryId || !platform || !status) {
            return res.status(400).json({ error: 'providerDeliveryId, platform, status required' });
        }
        const snap = await db.collection('music_distribution')
            .where('providerDeliveryId', '==', providerDeliveryId)
            .limit(1)
            .get();
        if (snap.empty)
            return res.status(404).json({ error: 'Distribution not found' });
        const ref = snap.docs[0].ref;
        const now = firebase_admin_1.default.firestore.FieldValue.serverTimestamp();
        const update = {
            [`platformStatuses.${platform}.status`]: status,
            updatedAt: now,
        };
        if (status === 'live') {
            update[`platformStatuses.${platform}.liveAt`] = now;
            if (liveUrl)
                update[`platformStatuses.${platform}.liveUrl`] = liveUrl;
        }
        await ref.update(update);
        res.json({ received: true });
    }
    catch (error) {
        console.error('Distribution webhook error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/distribution/available-platforms
app.get('/v1/music/distribution/available-platforms', async (_req, res) => {
    res.json({
        provider: (0, aggregator_1.activeProvider)(),
        platforms: [
            { id: 'spotify', name: 'Spotify', audioFormat: 'WAV/FLAC 16-24bit', artwork: '3000x3000 JPG', estimatedApprovalTime: '1-5 business days', perStreamRate: '$0.003-$0.005' },
            { id: 'apple_music', name: 'Apple Music', audioFormat: 'ALAC/AAC 256kbps', artwork: '3000x3000 PNG/JPG', estimatedApprovalTime: '1-4 business days', perStreamRate: '$0.007-$0.010' },
            { id: 'youtube_music', name: 'YouTube Music', audioFormat: 'FLAC/MP3 320', artwork: '1200x1200+', estimatedApprovalTime: '1-3 business days', perStreamRate: '$0.002-$0.003' },
            { id: 'amazon_music', name: 'Amazon Music', audioFormat: 'WAV/FLAC', artwork: '3000x3000 JPG', estimatedApprovalTime: '2-5 business days', perStreamRate: '$0.004-$0.006' },
            { id: 'tidal', name: 'TIDAL', audioFormat: 'FLAC 24-bit', artwork: '3000x3000 PNG', estimatedApprovalTime: '3-7 business days', perStreamRate: '$0.012-$0.018' },
            { id: 'deezer', name: 'Deezer', audioFormat: 'FLAC/MP3 320', artwork: '1500x1500 JPG', estimatedApprovalTime: '2-5 business days', perStreamRate: '$0.004-$0.006' },
        ],
        total: VALID_PLATFORMS.length,
    });
});
const PORT = process.env.PORT || 8081;
app.listen(PORT, () => {
    console.log(`🎵 Music distribution service (DDEX + ${(0, aggregator_1.activeProvider)()}) listening on port ${PORT}`);
});
