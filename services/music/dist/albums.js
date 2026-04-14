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
// Albums/EPs Grouping
// ─────────────────────────────────────────────────────────────────────────────
// POST /v1/music/albums - Create album/EP
app.post('/v1/music/albums', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { title, type, artworkURL, releaseDate, description } = req.body || {};
        if (!title || typeof title !== 'string') {
            return res.status(400).json({ error: 'title is required' });
        }
        if (!type || !['album', 'ep', 'single'].includes(type)) {
            return res.status(400).json({ error: 'type must be album, ep, or single' });
        }
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        const albumRef = db.collection('music_albums').doc();
        await albumRef.set({
            id: albumRef.id,
            artistId: user.userId,
            title: title.trim(),
            type,
            artworkURL: artworkURL || null,
            releaseDate: releaseDate || null,
            description: description || null,
            trackIds: [],
            status: 'draft',
            createdAt: now,
            updatedAt: now
        });
        res.status(201).json({
            albumId: albumRef.id,
            title,
            type,
            status: 'draft',
            message: 'Album created successfully'
        });
    }
    catch (error) {
        console.error('Create album error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// PUT /v1/music/albums/:albumId/tracks - Add tracks to album
app.put('/v1/music/albums/:albumId/tracks', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { albumId } = req.params;
        const { trackIds, trackOrder } = req.body || {};
        if (!trackIds || !Array.isArray(trackIds)) {
            return res.status(400).json({ error: 'trackIds array is required' });
        }
        const albumRef = db.collection('music_albums').doc(albumId);
        const albumSnap = await albumRef.get();
        if (!albumSnap.exists) {
            return res.status(404).json({ error: 'Album not found' });
        }
        const albumData = albumSnap.data();
        if (String(albumData.artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        // Verify all tracks belong to the artist
        const tracksSnap = await db.collection('music_tracks')
            .where('artistId', '==', user.userId)
            .where(firebase_admin_1.default.firestore.FieldPath.documentId(), 'in', trackIds.slice(0, 10))
            .get();
        if (tracksSnap.size !== trackIds.length) {
            return res.status(400).json({ error: 'Some tracks do not belong to this artist' });
        }
        await albumRef.update({
            trackIds,
            trackOrder: trackOrder || trackIds,
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
        });
        // Update tracks with album reference
        const batch = db.batch();
        for (const trackId of trackIds) {
            const trackRef = db.collection('music_tracks').doc(trackId);
            batch.update(trackRef, {
                albumId,
                albumName: albumData.title,
                updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
            });
        }
        await batch.commit();
        res.json({
            albumId,
            trackCount: trackIds.length,
            message: 'Tracks added to album successfully'
        });
    }
    catch (error) {
        console.error('Add tracks to album error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/albums - List artist's albums
app.get('/v1/music/albums', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { type } = req.query || {};
        let query = db.collection('music_albums')
            .where('artistId', '==', user.userId)
            .orderBy('createdAt', 'desc');
        if (type) {
            query = query.where('type', '==', type);
        }
        const albumsSnap = await query.get();
        const albums = albumsSnap.docs.map(doc => {
            var _a, _b;
            const data = doc.data();
            return {
                id: doc.id,
                title: data.title,
                type: data.type,
                artworkURL: data.artworkURL,
                releaseDate: data.releaseDate,
                trackCount: ((_a = data.trackIds) === null || _a === void 0 ? void 0 : _a.length) || 0,
                status: data.status,
                createdAt: (_b = data.createdAt) === null || _b === void 0 ? void 0 : _b.toDate().toISOString()
            };
        });
        res.json({
            albums,
            total: albumsSnap.size
        });
    }
    catch (error) {
        console.error('List albums error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// PUT /v1/music/albums/:albumId/publish - Publish album
app.put('/v1/music/albums/:albumId/publish', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { albumId } = req.params;
        const albumRef = db.collection('music_albums').doc(albumId);
        const albumSnap = await albumRef.get();
        if (!albumSnap.exists) {
            return res.status(404).json({ error: 'Album not found' });
        }
        const albumData = albumSnap.data();
        if (String(albumData.artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        if (!albumData.trackIds || albumData.trackIds.length === 0) {
            return res.status(400).json({ error: 'Album must have at least one track' });
        }
        await albumRef.update({
            status: 'published',
            publishedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
        });
        // Publish all tracks in the album
        const batch = db.batch();
        for (const trackId of albumData.trackIds) {
            const trackRef = db.collection('music_tracks').doc(trackId);
            batch.update(trackRef, {
                status: 'published',
                publishedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                isPublished: true
            });
        }
        await batch.commit();
        res.json({
            albumId,
            status: 'published',
            message: 'Album published successfully'
        });
    }
    catch (error) {
        console.error('Publish album error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// DELETE /v1/music/albums/:albumId - Delete album
app.delete('/v1/music/albums/:albumId', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { albumId } = req.params;
        const albumRef = db.collection('music_albums').doc(albumId);
        const albumSnap = await albumRef.get();
        if (!albumSnap.exists) {
            return res.status(404).json({ error: 'Album not found' });
        }
        const albumData = albumSnap.data();
        if (String(albumData.artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        // Remove album reference from tracks
        if (albumData.trackIds) {
            const batch = db.batch();
            for (const trackId of albumData.trackIds) {
                const trackRef = db.collection('music_tracks').doc(trackId);
                batch.update(trackRef, {
                    albumId: null,
                    albumName: null,
                    updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
                });
            }
            await batch.commit();
        }
        await albumRef.delete();
        res.json({
            albumId,
            message: 'Album deleted successfully'
        });
    }
    catch (error) {
        console.error('Delete album error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
const PORT = process.env.PORT || 8085;
app.listen(PORT, () => {
    console.log(`🎵 Music albums service listening on port ${PORT}`);
});
