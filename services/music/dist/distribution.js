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
// Phase 2: Music Distribution Service
// ─────────────────────────────────────────────────────────────────────────────
// POST /v1/music/distribution/submit - Distribute track to external platforms
app.post('/v1/music/distribution/submit', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId, platforms } = req.body || {};
        if (!trackId || typeof trackId !== 'string') {
            return res.status(400).json({ error: 'trackId is required' });
        }
        if (!platforms || !Array.isArray(platforms)) {
            return res.status(400).json({ error: 'platforms array is required' });
        }
        const validPlatforms = ['spotify', 'apple_music', 'youtube_music', 'amazon_music', 'tidal', 'deezer'];
        const invalidPlatforms = platforms.filter(p => !validPlatforms.includes(p));
        if (invalidPlatforms.length > 0) {
            return res.status(400).json({ error: `Invalid platforms: ${invalidPlatforms.join(', ')}` });
        }
        const trackRef = db.collection('music_tracks').doc(trackId);
        const trackSnap = await trackRef.get();
        if (!trackSnap.exists) {
            return res.status(404).json({ error: 'Track not found' });
        }
        const trackData = trackSnap.data();
        if (String(trackData.artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        if (trackData.status !== 'published') {
            return res.status(400).json({ error: 'Track must be published before distribution' });
        }
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        const distributionRef = db.collection('music_distribution').doc();
        // Create distribution record
        const platformStatuses = {};
        platforms.forEach(platform => {
            platformStatuses[platform] = {
                status: 'pending',
                submittedAt: now,
                approvedAt: null,
                rejectedAt: null,
                rejectionReason: null
            };
        });
        await distributionRef.set({
            id: distributionRef.id,
            trackId,
            artistId: user.userId,
            platforms,
            platformStatuses,
            overallStatus: 'pending',
            submittedAt: now,
            updatedAt: now
        });
        // Update track distribution status
        await trackRef.update({
            distributionStatus: 'submitted',
            distributionId: distributionRef.id,
            distributionSubmittedAt: now
        });
        res.status(201).json({
            distributionId: distributionRef.id,
            trackId,
            platforms,
            status: 'pending',
            message: 'Distribution submitted. Track will be reviewed by platforms.'
        });
    }
    catch (error) {
        console.error('Submit distribution error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/distribution/:trackId/status - Check distribution status per platform
app.get('/v1/music/distribution/:trackId/status', async (req, res) => {
    var _a, _b;
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
        if (!trackData.distributionId) {
            return res.status(404).json({ error: 'No distribution found for this track' });
        }
        const distributionRef = db.collection('music_distribution').doc(trackData.distributionId);
        const distributionSnap = await distributionRef.get();
        if (!distributionSnap.exists) {
            return res.status(404).json({ error: 'Distribution record not found' });
        }
        const distributionData = distributionSnap.data();
        res.json({
            distributionId: distributionData.id,
            trackId,
            overallStatus: distributionData.overallStatus,
            platforms: distributionData.platformStatuses,
            submittedAt: (_a = distributionData.submittedAt) === null || _a === void 0 ? void 0 : _a.toDate().toISOString(),
            updatedAt: (_b = distributionData.updatedAt) === null || _b === void 0 ? void 0 : _b.toDate().toISOString()
        });
    }
    catch (error) {
        console.error('Get distribution status error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// PUT /v1/music/distribution/:trackId/platforms/:platform/takedown - Remove from specific platform
app.put('/v1/music/distribution/:trackId/platforms/:platform/takedown', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId, platform } = req.params;
        const validPlatforms = ['spotify', 'apple_music', 'youtube_music', 'amazon_music', 'tidal', 'deezer'];
        if (!validPlatforms.includes(platform)) {
            return res.status(400).json({ error: `Invalid platform: ${platform}` });
        }
        const trackRef = db.collection('music_tracks').doc(trackId);
        const trackSnap = await trackRef.get();
        if (!trackSnap.exists) {
            return res.status(404).json({ error: 'Track not found' });
        }
        const trackData = trackSnap.data();
        if (String(trackData.artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        if (!trackData.distributionId) {
            return res.status(404).json({ error: 'No distribution found for this track' });
        }
        const distributionRef = db.collection('music_distribution').doc(trackData.distributionId);
        const distributionSnap = await distributionRef.get();
        if (!distributionSnap.exists) {
            return res.status(404).json({ error: 'Distribution record not found' });
        }
        const distributionData = distributionSnap.data();
        const platformStatus = distributionData.platformStatuses[platform];
        if (!platformStatus || platformStatus.status !== 'approved') {
            return res.status(400).json({ error: `Track is not currently distributed to ${platform}` });
        }
        // Update platform status to takedown
        await distributionRef.update({
            [`platformStatuses.${platform}.status`]: 'takedown_requested',
            [`platformStatuses.${platform}.takedownRequestedAt`]: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp()
        });
        res.json({
            message: `Takedown requested for ${platform}`,
            platform,
            status: 'takedown_requested'
        });
    }
    catch (error) {
        console.error('Platform takedown error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/distribution/available-platforms - List supported platforms with requirements
app.get('/v1/music/distribution/available-platforms', async (req, res) => {
    try {
        const platforms = [
            {
                id: 'spotify',
                name: 'Spotify',
                requirements: {
                    audioFormat: 'WAV (24-bit/44.1kHz) or FLAC',
                    artwork: '3000x3000px JPG',
                    metadata: 'Title, Artist, Album, Genre, ISRC (optional)'
                },
                estimatedApprovalTime: '3-5 business days',
                perStreamRate: '$0.003 - $0.005'
            },
            {
                id: 'apple_music',
                name: 'Apple Music',
                requirements: {
                    audioFormat: 'ALAC or AAC (256kbps)',
                    artwork: '3000x3000px PNG/JPG',
                    metadata: 'Title, Artist, Album, Genre, ISRC, UPC'
                },
                estimatedApprovalTime: '2-4 business days',
                perStreamRate: '$0.007 - $0.010'
            },
            {
                id: 'youtube_music',
                name: 'YouTube Music',
                requirements: {
                    audioFormat: 'FLAC or high-quality MP3 (320kbps)',
                    artwork: 'Minimum 1200x1200px',
                    metadata: 'Title, Artist, Album, Genre'
                },
                estimatedApprovalTime: '1-3 business days',
                perStreamRate: '$0.002 - $0.003'
            },
            {
                id: 'amazon_music',
                name: 'Amazon Music',
                requirements: {
                    audioFormat: 'WAV or FLAC (16-bit/44.1kHz)',
                    artwork: '3000x3000px JPG',
                    metadata: 'Title, Artist, Album, Genre, UPC'
                },
                estimatedApprovalTime: '3-5 business days',
                perStreamRate: '$0.004 - $0.006'
            },
            {
                id: 'tidal',
                name: 'Tidal',
                requirements: {
                    audioFormat: 'FLAC (24-bit/96kHz preferred)',
                    artwork: '3000x3000px PNG',
                    metadata: 'Title, Artist, Album, Genre, ISRC'
                },
                estimatedApprovalTime: '5-7 business days',
                perStreamRate: '$0.012 - $0.018'
            },
            {
                id: 'deezer',
                name: 'Deezer',
                requirements: {
                    audioFormat: 'FLAC or MP3 (320kbps)',
                    artwork: '1500x1500px JPG',
                    metadata: 'Title, Artist, Album, Genre, ISRC'
                },
                estimatedApprovalTime: '3-5 business days',
                perStreamRate: '$0.004 - $0.006'
            }
        ];
        res.json({
            platforms,
            total: platforms.length
        });
    }
    catch (error) {
        console.error('Get available platforms error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
const PORT = process.env.PORT || 8081;
app.listen(PORT, () => {
    console.log(`🎵 Music distribution service listening on port ${PORT}`);
});
