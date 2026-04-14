"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const app = (0, express_1.default)();
app.use(express_1.default.json());
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
// ─────────────────────────────────────────────────────────────────────────────
// Live Streaming Integration
// ─────────────────────────────────────────────────────────────────────────────
// POST /v1/music/artists/:artistId/live-streams - Create live stream
app.post('/v1/music/artists/:artistId/live-streams', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { artistId } = req.params;
        const { title, description, scheduledTime } = req.body || {};
        if (!title) {
            return res.status(400).json({ error: 'title is required' });
        }
        if (user.userId !== artistId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        const liveStreamRef = db.collection('artist_live_streams').doc();
        await liveStreamRef.set({
            id: liveStreamRef.id,
            artistId,
            title: title.trim(),
            description: description || null,
            scheduledTime: scheduledTime ? firebase_admin_1.default.firestore.Timestamp.fromDate(new Date(scheduledTime)) : null,
            status: 'scheduled',
            createdAt: now
        });
        res.status(201).json({
            liveStreamId: liveStreamRef.id,
            title,
            status: 'scheduled',
            message: 'Live stream created successfully'
        });
    }
    catch (error) {
        console.error('Create live stream error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// PUT /v1/music/live-streams/:streamId/start - Start live stream
app.put('/v1/music/live-streams/:streamId/start', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { streamId } = req.params;
        const streamRef = db.collection('artist_live_streams').doc(streamId);
        const streamSnap = await streamRef.get();
        if (!streamSnap.exists) {
            return res.status(404).json({ error: 'Live stream not found' });
        }
        const streamData = streamSnap.data();
        if (String(streamData.artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        await streamRef.update({
            status: 'live',
            startedAt: firebase_admin_1.default.firestore.Timestamp.now()
        });
        res.json({
            streamId,
            status: 'live',
            message: 'Live stream started'
        });
    }
    catch (error) {
        console.error('Start live stream error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/artists/:artistId/live-streams - List artist live streams
app.get('/v1/music/artists/:artistId/live-streams', async (req, res) => {
    try {
        const { artistId } = req.params;
        const streamsSnap = await db.collection('artist_live_streams')
            .where('artistId', '==', artistId)
            .orderBy('createdAt', 'desc')
            .limit(50)
            .get();
        const streams = streamsSnap.docs.map(doc => {
            var _a, _b;
            const data = doc.data();
            return {
                id: doc.id,
                title: data.title,
                description: data.description,
                status: data.status,
                scheduledTime: (_a = data.scheduledTime) === null || _a === void 0 ? void 0 : _a.toDate().toISOString(),
                createdAt: (_b = data.createdAt) === null || _b === void 0 ? void 0 : _b.toDate().toISOString()
            };
        });
        res.json({
            artistId,
            streams,
            total: streamsSnap.size
        });
    }
    catch (error) {
        console.error('List live streams error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// ─────────────────────────────────────────────────────────────────────────────
// Artist Playlists
// ─────────────────────────────────────────────────────────────────────────────
// POST /v1/music/artists/:artistId/playlists - Create playlist
app.post('/v1/music/artists/:artistId/playlists', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { artistId } = req.params;
        const { name, description, isPublic } = req.body || {};
        if (!name) {
            return res.status(400).json({ error: 'name is required' });
        }
        if (user.userId !== artistId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        const playlistRef = db.collection('artist_playlists').doc();
        await playlistRef.set({
            id: playlistRef.id,
            artistId,
            name: name.trim(),
            description: description || null,
            isPublic: isPublic !== undefined ? isPublic : false,
            trackIds: [],
            createdAt: now,
            updatedAt: now
        });
        res.status(201).json({
            playlistId: playlistRef.id,
            name,
            isPublic: isPublic !== undefined ? isPublic : false,
            message: 'Playlist created successfully'
        });
    }
    catch (error) {
        console.error('Create playlist error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// PUT /v1/music/playlists/:playlistId/tracks - Add tracks to playlist
app.put('/v1/music/playlists/:playlistId/tracks', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { playlistId } = req.params;
        const { trackIds } = req.body || {};
        if (!trackIds || !Array.isArray(trackIds)) {
            return res.status(400).json({ error: 'trackIds array is required' });
        }
        const playlistRef = db.collection('artist_playlists').doc(playlistId);
        const playlistSnap = await playlistRef.get();
        if (!playlistSnap.exists) {
            return res.status(404).json({ error: 'Playlist not found' });
        }
        const playlistData = playlistSnap.data();
        if (String(playlistData.artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        await playlistRef.update({
            trackIds: firebase_admin_1.default.firestore.FieldValue.arrayUnion(...trackIds),
            updatedAt: firebase_admin_1.default.firestore.Timestamp.now()
        });
        res.json({
            playlistId,
            message: 'Tracks added to playlist successfully'
        });
    }
    catch (error) {
        console.error('Add tracks to playlist error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/artists/:artistId/playlists - List artist playlists
app.get('/v1/music/artists/:artistId/playlists', async (req, res) => {
    try {
        const { artistId } = req.params;
        const playlistsSnap = await db.collection('artist_playlists')
            .where('artistId', '==', artistId)
            .orderBy('createdAt', 'desc')
            .get();
        const playlists = playlistsSnap.docs.map(doc => {
            var _a;
            const data = doc.data();
            return {
                id: doc.id,
                name: data.name,
                description: data.description,
                isPublic: data.isPublic,
                trackCount: ((_a = data.trackIds) === null || _a === void 0 ? void 0 : _a.length) || 0
            };
        });
        res.json({
            artistId,
            playlists,
            total: playlistsSnap.size
        });
    }
    catch (error) {
        console.error('List playlists error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// ─────────────────────────────────────────────────────────────────────────────
// Track Promotion
// ─────────────────────────────────────────────────────────────────────────────
// POST /v1/music/tracks/:trackId/promote - Create promotion campaign
app.post('/v1/music/tracks/:trackId/promote', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId } = req.params;
        const { budget, duration, targetAudience } = req.body || {};
        const trackRef = db.collection('music_tracks').doc(trackId);
        const trackSnap = await trackRef.get();
        if (!trackSnap.exists) {
            return res.status(404).json({ error: 'Track not found' });
        }
        const trackData = trackSnap.data();
        if (String(trackData.artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        const promotionRef = db.collection('track_promotions').doc();
        await promotionRef.set({
            id: promotionRef.id,
            trackId,
            artistId: user.userId,
            budget: budget || 0,
            duration: duration || 7,
            targetAudience: targetAudience || null,
            status: 'active',
            createdAt: now,
            expiresAt: firebase_admin_1.default.firestore.Timestamp.fromDate(new Date(Date.now() + (duration || 7) * 24 * 60 * 60 * 1000))
        });
        res.status(201).json({
            promotionId: promotionRef.id,
            status: 'active',
            message: 'Promotion campaign created successfully'
        });
    }
    catch (error) {
        console.error('Create promotion error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/tracks/:trackId/promotions - Get track promotions
app.get('/v1/music/tracks/:trackId/promotions', async (req, res) => {
    try {
        const { trackId } = req.params;
        const promotionsSnap = await db.collection('track_promotions')
            .where('trackId', '==', trackId)
            .orderBy('createdAt', 'desc')
            .limit(10)
            .get();
        const promotions = promotionsSnap.docs.map(doc => {
            var _a;
            const data = doc.data();
            return {
                id: doc.id,
                budget: data.budget,
                duration: data.duration,
                status: data.status,
                createdAt: (_a = data.createdAt) === null || _a === void 0 ? void 0 : _a.toDate().toISOString()
            };
        });
        res.json({
            trackId,
            promotions,
            total: promotionsSnap.size
        });
    }
    catch (error) {
        console.error('Get promotions error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// ─────────────────────────────────────────────────────────────────────────────
// Sync Licensing (TV/Film/Commercials)
// ─────────────────────────────────────────────────────────────────────────────
// POST /v1/music/tracks/:trackId/sync-licensing - Submit for sync licensing
app.post('/v1/music/tracks/:trackId/sync-licensing', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId } = req.params;
        const { licensingType, price, exclusivity } = req.body || {};
        const trackRef = db.collection('music_tracks').doc(trackId);
        const trackSnap = await trackRef.get();
        if (!trackSnap.exists) {
            return res.status(404).json({ error: 'Track not found' });
        }
        const trackData = trackSnap.data();
        if (String(trackData.artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        const licenseRef = db.collection('sync_licenses').doc();
        await licenseRef.set({
            id: licenseRef.id,
            trackId,
            artistId: user.userId,
            licensingType: licensingType || 'all',
            price: price || null,
            exclusivity: exclusivity || 'non-exclusive',
            status: 'available',
            createdAt: now
        });
        res.status(201).json({
            licenseId: licenseRef.id,
            status: 'available',
            message: 'Track submitted for sync licensing'
        });
    }
    catch (error) {
        console.error('Submit sync licensing error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/artists/:artistId/sync-licenses - Get sync licenses
app.get('/v1/music/artists/:artistId/sync-licenses', async (req, res) => {
    try {
        const { artistId } = req.params;
        const licensesSnap = await db.collection('sync_licenses')
            .where('artistId', '==', artistId)
            .orderBy('createdAt', 'desc')
            .limit(50)
            .get();
        const licenses = licensesSnap.docs.map(doc => {
            const data = doc.data();
            return {
                id: doc.id,
                trackId: data.trackId,
                licensingType: data.licensingType,
                price: data.price,
                exclusivity: data.exclusivity,
                status: data.status
            };
        });
        res.json({
            artistId,
            licenses,
            total: licensesSnap.size
        });
    }
    catch (error) {
        console.error('Get sync licenses error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
const PORT = process.env.PORT || 8089;
app.listen(PORT, () => {
    console.log(`🎵 Music advanced service listening on port ${PORT}`);
});
