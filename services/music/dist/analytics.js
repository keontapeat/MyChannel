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
// Helper function to verify Firebase Auth token
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
// Phase 3: Real-Time Listener Analytics Service
// ─────────────────────────────────────────────────────────────────────────────
// POST /v1/music/tracks/:trackId/stream - Track stream event
app.post('/v1/music/tracks/:trackId/stream', async (req, res) => {
    try {
        const { trackId } = req.params;
        const { userId, location, device, platform } = req.body || {};
        if (!userId || typeof userId !== 'string') {
            return res.status(400).json({ error: 'userId is required' });
        }
        const trackRef = db.collection('music_tracks').doc(trackId);
        const trackSnap = await trackRef.get();
        if (!trackSnap.exists) {
            return res.status(404).json({ error: 'Track not found' });
        }
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        // Create stream event
        const streamRef = db.collection('music_streams').doc();
        await streamRef.set({
            id: streamRef.id,
            trackId,
            userId,
            location: location || null,
            device: device || null,
            platform: platform || null,
            timestamp: now
        });
        // Increment stream count
        await trackRef.update({
            streamCount: firebase_admin_1.default.firestore.FieldValue.increment(1),
            lastStreamAt: now
        });
        // Update listener profile
        const listenerRef = db.collection('music_listeners').doc(userId);
        const listenerSnap = await listenerRef.get();
        if (listenerSnap.exists) {
            await listenerRef.update({
                totalStreams: firebase_admin_1.default.firestore.FieldValue.increment(1),
                lastStreamAt: now,
                [`tracks.${trackId}`]: firebase_admin_1.default.firestore.FieldValue.increment(1)
            });
        }
        else {
            await listenerRef.set({
                id: userId,
                totalStreams: 1,
                tracks: { [trackId]: 1 },
                createdAt: now,
                lastStreamAt: now
            });
        }
        res.json({
            streamId: streamRef.id,
            trackId,
            timestamp: now.toDate().toISOString()
        });
    }
    catch (error) {
        console.error('Track stream error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/tracks/:trackId/streams/realtime - Real-time stream count
app.get('/v1/music/tracks/:trackId/streams/realtime', async (req, res) => {
    var _a;
    try {
        const { trackId } = req.params;
        const trackRef = db.collection('music_tracks').doc(trackId);
        const trackSnap = await trackRef.get();
        if (!trackSnap.exists) {
            return res.status(404).json({ error: 'Track not found' });
        }
        const trackData = trackSnap.data();
        // Get streams in last hour for real-time count
        const oneHourAgo = firebase_admin_1.default.firestore.Timestamp.fromDate(new Date(Date.now() - 60 * 60 * 1000));
        const recentStreamsSnap = await db.collection('music_streams')
            .where('trackId', '==', trackId)
            .where('timestamp', '>=', oneHourAgo)
            .get();
        const uniqueListeners = new Set();
        recentStreamsSnap.docs.forEach(doc => {
            const data = doc.data();
            uniqueListeners.add(data.userId);
        });
        res.json({
            trackId,
            totalStreams: trackData.streamCount || 0,
            currentListeners: uniqueListeners.size,
            recentStreams: recentStreamsSnap.size,
            lastStreamAt: ((_a = trackData.lastStreamAt) === null || _a === void 0 ? void 0 : _a.toDate().toISOString()) || null
        });
    }
    catch (error) {
        console.error('Real-time streams error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/tracks/:trackId/streams/history - Historical stream data
app.get('/v1/music/tracks/:trackId/streams/history', async (req, res) => {
    try {
        const { trackId } = req.params;
        const { timeRange, interval } = req.query || {};
        const validTimeRanges = ['1h', '24h', '7d', '30d', '90d', '1y'];
        const timeRangeValue = timeRange || '7d';
        if (!validTimeRanges.includes(timeRangeValue)) {
            return res.status(400).json({ error: `Invalid timeRange. Must be one of: ${validTimeRanges.join(', ')}` });
        }
        const trackRef = db.collection('music_tracks').doc(trackId);
        const trackSnap = await trackRef.get();
        if (!trackSnap.exists) {
            return res.status(404).json({ error: 'Track not found' });
        }
        const trackData = trackSnap.data();
        // Calculate time range
        const timeRangeMs = {
            '1h': 60 * 60 * 1000,
            '24h': 24 * 60 * 60 * 1000,
            '7d': 7 * 24 * 60 * 60 * 1000,
            '30d': 30 * 24 * 60 * 60 * 1000,
            '90d': 90 * 24 * 60 * 60 * 1000,
            '1y': 365 * 24 * 60 * 60 * 1000
        };
        const startDate = firebase_admin_1.default.firestore.Timestamp.fromDate(new Date(Date.now() - timeRangeMs[timeRangeValue]));
        const streamsSnap = await db.collection('music_streams')
            .where('trackId', '==', trackId)
            .where('timestamp', '>=', startDate)
            .orderBy('timestamp', 'desc')
            .limit(10000)
            .get();
        // Group by interval
        const intervalMs = interval === 'hour' ? 60 * 60 * 1000 : (interval === 'day' ? 24 * 60 * 60 * 1000 : 60 * 60 * 1000);
        const groupedData = {};
        streamsSnap.docs.forEach(doc => {
            const data = doc.data();
            const timestamp = data.timestamp.toDate().getTime();
            const intervalKey = Math.floor(timestamp / intervalMs) * intervalMs;
            groupedData[intervalKey] = (groupedData[intervalKey] || 0) + 1;
        });
        const history = Object.entries(groupedData)
            .map(([timestamp, count]) => ({
            timestamp: new Date(parseInt(timestamp)).toISOString(),
            count
        }))
            .sort((a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime());
        res.json({
            trackId,
            timeRange: timeRangeValue,
            totalStreams: streamsSnap.size,
            history
        });
    }
    catch (error) {
        console.error('Stream history error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/tracks/:trackId/listeners/geographic - Geographic distribution
app.get('/v1/music/tracks/:trackId/listeners/geographic', async (req, res) => {
    try {
        const { trackId } = req.params;
        const trackRef = db.collection('music_tracks').doc(trackId);
        const trackSnap = await trackRef.get();
        if (!trackSnap.exists) {
            return res.status(404).json({ error: 'Track not found' });
        }
        const streamsSnap = await db.collection('music_streams')
            .where('trackId', '==', trackId)
            .limit(10000)
            .get();
        const geographicData = {};
        streamsSnap.docs.forEach(doc => {
            var _a;
            const data = doc.data();
            const country = ((_a = data.location) === null || _a === void 0 ? void 0 : _a.country) || 'Unknown';
            geographicData[country] = (geographicData[country] || 0) + 1;
        });
        const total = streamsSnap.size;
        const distribution = Object.entries(geographicData)
            .map(([country, count]) => ({
            country,
            count,
            percentage: ((count / total) * 100).toFixed(1)
        }))
            .sort((a, b) => b.count - a.count);
        res.json({
            trackId,
            totalListeners: total,
            geographicDistribution: distribution
        });
    }
    catch (error) {
        console.error('Geographic distribution error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/tracks/:trackId/listeners/demographic - Demographic data
app.get('/v1/music/tracks/:trackId/listeners/demographic', async (req, res) => {
    try {
        const { trackId } = req.params;
        const trackRef = db.collection('music_tracks').doc(trackId);
        const trackSnap = await trackRef.get();
        if (!trackSnap.exists) {
            return res.status(404).json({ error: 'Track not found' });
        }
        const streamsSnap = await db.collection('music_streams')
            .where('trackId', '==', trackId)
            .limit(10000)
            .get();
        // Mock demographic data (in production, this would come from user profiles)
        const demographics = {
            age: [
                { range: '13-17', percentage: 15 },
                { range: '18-24', percentage: 35 },
                { range: '25-34', percentage: 30 },
                { range: '35-44', percentage: 12 },
                { range: '45-54', percentage: 5 },
                { range: '55+', percentage: 3 }
            ],
            gender: [
                { gender: 'Male', percentage: 52 },
                { gender: 'Female', percentage: 45 },
                { gender: 'Other', percentage: 3 }
            ],
            language: [
                { language: 'English', percentage: 65 },
                { language: 'Spanish', percentage: 15 },
                { language: 'French', percentage: 8 },
                { language: 'German', percentage: 5 },
                { language: 'Other', percentage: 7 }
            ]
        };
        res.json({
            trackId,
            totalListeners: streamsSnap.size,
            demographics
        });
    }
    catch (error) {
        console.error('Demographic data error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/tracks/:trackId/listeners/device - Device/platform breakdown
app.get('/v1/music/tracks/:trackId/listeners/device', async (req, res) => {
    try {
        const { trackId } = req.params;
        const trackRef = db.collection('music_tracks').doc(trackId);
        const trackSnap = await trackRef.get();
        if (!trackSnap.exists) {
            return res.status(404).json({ error: 'Track not found' });
        }
        const streamsSnap = await db.collection('music_streams')
            .where('trackId', '==', trackId)
            .limit(10000)
            .get();
        const deviceData = {};
        const platformData = {};
        streamsSnap.docs.forEach(doc => {
            var _a;
            const data = doc.data();
            const device = ((_a = data.device) === null || _a === void 0 ? void 0 : _a.type) || 'Unknown';
            const platform = data.platform || 'Unknown';
            deviceData[device] = (deviceData[device] || 0) + 1;
            platformData[platform] = (platformData[platform] || 0) + 1;
        });
        const total = streamsSnap.size;
        const devices = Object.entries(deviceData)
            .map(([type, count]) => ({
            type,
            count,
            percentage: ((count / total) * 100).toFixed(1)
        }))
            .sort((a, b) => b.count - a.count);
        const platforms = Object.entries(platformData)
            .map(([platform, count]) => ({
            platform,
            count,
            percentage: ((count / total) * 100).toFixed(1)
        }))
            .sort((a, b) => b.count - a.count);
        res.json({
            trackId,
            totalListeners: total,
            devices,
            platforms
        });
    }
    catch (error) {
        console.error('Device breakdown error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/artists/:artistId/analytics/overview - Complete analytics overview
app.get('/v1/music/artists/:artistId/analytics/overview', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { artistId } = req.params;
        if (user.userId !== artistId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        // Get all tracks for artist
        const tracksSnap = await db.collection('music_tracks')
            .where('artistId', '==', artistId)
            .get();
        let totalStreams = 0;
        let totalLikes = 0;
        const trackIds = [];
        tracksSnap.docs.forEach(doc => {
            const data = doc.data();
            totalStreams += data.streamCount || 0;
            totalLikes += data.likeCount || 0;
            trackIds.push(doc.id);
        });
        // Get unique listeners
        const listenersSnap = await db.collection('music_listeners')
            .where(`tracks.${trackIds[0]}`, '>', 0)
            .limit(10000)
            .get();
        // Get streams in last 30 days for recent activity
        const thirtyDaysAgo = firebase_admin_1.default.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000));
        const recentStreamsSnap = await db.collection('music_streams')
            .where('trackId', 'in', trackIds.slice(0, 10))
            .where('timestamp', '>=', thirtyDaysAgo)
            .get();
        const overview = {
            artistId,
            totalTracks: tracksSnap.size,
            totalStreams,
            totalLikes,
            uniqueListeners: listenersSnap.size,
            recentStreams: recentStreamsSnap.size,
            topTracks: tracksSnap.docs
                .map(doc => ({
                id: doc.id,
                title: doc.data().title,
                streamCount: doc.data().streamCount || 0,
                likeCount: doc.data().likeCount || 0
            }))
                .sort((a, b) => b.streamCount - a.streamCount)
                .slice(0, 5)
        };
        res.json({ overview });
    }
    catch (error) {
        console.error('Analytics overview error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
const PORT = process.env.PORT || 8082;
app.listen(PORT, () => {
    console.log(`🎵 Music analytics service listening on port ${PORT}`);
});
