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
// Phase 6: Revolutionary Content ID System (YouTube Killer Feature)
// ─────────────────────────────────────────────────────────────────────────────
// POST /v1/music/content-id/register - Register track fingerprint in Content ID database
app.post('/v1/music/content-id/register', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId, fingerprint } = req.body || {};
        if (!trackId || typeof trackId !== 'string') {
            return res.status(400).json({ error: 'trackId is required' });
        }
        if (!fingerprint || typeof fingerprint !== 'string') {
            return res.status(400).json({ error: 'fingerprint is required' });
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
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        const contentIdRef = db.collection('music_content_id').doc(trackId);
        await contentIdRef.set({
            trackId,
            artistId: user.userId,
            fingerprint,
            registeredAt: now,
            status: 'active',
            copyrightPolicy: 'strict', // Default: copyright strike for unauthorized usage
            revenueSharePercentage: null
        }, { merge: true });
        // Update track with Content ID status
        await trackRef.update({
            contentIdRegistered: true,
            contentIdRegisteredAt: now
        });
        res.json({
            trackId,
            status: 'registered',
            copyrightPolicy: 'strict',
            message: 'Track registered in Content ID system. Default policy: copyright strike for unauthorized usage.'
        });
    }
    catch (error) {
        console.error('Content ID registration error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// PUT /v1/music/tracks/:trackId/copyright-policy - Set artist's copyright policy
app.put('/v1/music/tracks/:trackId/copyright-policy', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId } = req.params;
        const { policy, revenueSharePercentage } = req.body || {};
        const validPolicies = ['strict', 'monetize', 'allow'];
        if (!policy || !validPolicies.includes(policy)) {
            return res.status(400).json({ error: `policy must be one of: ${validPolicies.join(', ')}` });
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
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        const contentIdRef = db.collection('music_content_id').doc(trackId);
        await contentIdRef.update({
            copyrightPolicy: policy,
            revenueSharePercentage: policy === 'monetize' ? (revenueSharePercentage || 50) : null,
            policyUpdatedAt: now
        });
        res.json({
            trackId,
            copyrightPolicy: policy,
            revenueSharePercentage: policy === 'monetize' ? (revenueSharePercentage || 50) : null,
            message: policy === 'strict' ? 'Copyright strikes will be issued for unauthorized usage' :
                policy === 'monetize' ? 'Usage allowed with revenue sharing' :
                    'Usage allowed freely'
        });
    }
    catch (error) {
        console.error('Set copyright policy error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/tracks/:trackId/copyright-policy - Get current copyright policy
app.get('/v1/music/tracks/:trackId/copyright-policy', async (req, res) => {
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
        const contentIdRef = db.collection('music_content_id').doc(trackId);
        const contentIdSnap = await contentIdRef.get();
        if (!contentIdSnap.exists) {
            return res.status(404).json({ error: 'Content ID not registered for this track' });
        }
        const contentIdData = contentIdSnap.data();
        res.json({
            trackId,
            copyrightPolicy: contentIdData.copyrightPolicy || 'strict',
            revenueSharePercentage: contentIdData.revenueSharePercentage,
            registeredAt: (_a = contentIdData.registeredAt) === null || _a === void 0 ? void 0 : _a.toDate().toISOString(),
            policyUpdatedAt: ((_b = contentIdData.policyUpdatedAt) === null || _b === void 0 ? void 0 : _b.toDate().toISOString()) || null
        });
    }
    catch (error) {
        console.error('Get copyright policy error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// PUT /v1/music/artists/:artistId/default-copyright-policy - Set default policy for all tracks
app.put('/v1/music/artists/:artistId/default-copyright-policy', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { artistId } = req.params;
        const { policy, revenueSharePercentage } = req.body || {};
        if (user.userId !== artistId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        const validPolicies = ['strict', 'monetize', 'allow'];
        if (!policy || !validPolicies.includes(policy)) {
            return res.status(400).json({ error: `policy must be one of: ${validPolicies.join(', ')}` });
        }
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        const artistRef = db.collection('artists').doc(artistId);
        await artistRef.set({
            defaultCopyrightPolicy: policy,
            defaultRevenueSharePercentage: policy === 'monetize' ? (revenueSharePercentage || 50) : null,
            policyUpdatedAt: now
        }, { merge: true });
        res.json({
            artistId,
            defaultCopyrightPolicy: policy,
            defaultRevenueSharePercentage: policy === 'monetize' ? (revenueSharePercentage || 50) : null,
            message: 'Default copyright policy updated for all new tracks'
        });
    }
    catch (error) {
        console.error('Set default copyright policy error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// POST /v1/music/content-id/scan-video - Scan uploaded video for music matches
app.post('/v1/music/content-id/scan-video', async (req, res) => {
    try {
        const { videoId, audioFingerprint } = req.body || {};
        if (!videoId || typeof videoId !== 'string') {
            return res.status(400).json({ error: 'videoId is required' });
        }
        if (!audioFingerprint || typeof audioFingerprint !== 'string') {
            return res.status(400).json({ error: 'audioFingerprint is required' });
        }
        // Query Content ID database for matches
        const contentIdSnap = await db.collection('music_content_id')
            .where('status', '==', 'active')
            .limit(100)
            .get();
        const matches = [];
        contentIdSnap.docs.forEach(doc => {
            const data = doc.data();
            // Simulated fingerprint matching (in production, use proper audio fingerprinting)
            const similarity = Math.random();
            if (similarity > 0.85) {
                matches.push({
                    trackId: data.trackId,
                    artistId: data.artistId,
                    copyrightPolicy: data.copyrightPolicy,
                    revenueSharePercentage: data.revenueSharePercentage,
                    similarity: (similarity * 100).toFixed(1)
                });
            }
        });
        // Process matches based on copyright policy
        const enforcementResults = matches.map(match => {
            let action = 'none';
            let reason = '';
            if (match.copyrightPolicy === 'strict') {
                action = 'copyright_strike';
                reason = 'Unauthorized usage - copyright strike issued';
            }
            else if (match.copyrightPolicy === 'monetize') {
                action = 'revenue_share';
                reason = `Revenue sharing enabled - artist gets ${match.revenueSharePercentage}%`;
            }
            else if (match.copyrightPolicy === 'allow') {
                action = 'allowed';
                reason = 'Usage permitted by artist';
            }
            return {
                ...match,
                action,
                reason
            };
        });
        // Store scan results
        const scanRef = db.collection('music_content_id_scans').doc();
        await scanRef.set({
            id: scanRef.id,
            videoId,
            matches,
            enforcementResults,
            scannedAt: firebase_admin_1.default.firestore.Timestamp.now()
        });
        res.json({
            videoId,
            matchesFound: matches.length,
            matches,
            enforcementResults,
            scanId: scanRef.id
        });
    }
    catch (error) {
        console.error('Scan video error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/content-id/video/:videoId/matches - Get music matches in video
app.get('/v1/music/content-id/video/:videoId/matches', async (req, res) => {
    var _a;
    try {
        const { videoId } = req.params;
        const scansSnap = await db.collection('music_content_id_scans')
            .where('videoId', '==', videoId)
            .orderBy('scannedAt', 'desc')
            .limit(1)
            .get();
        if (scansSnap.empty) {
            return res.status(404).json({ error: 'No scan results found for this video' });
        }
        const scanData = scansSnap.docs[0].data();
        res.json({
            videoId,
            scanId: scanData.id,
            matchesFound: scanData.matches.length,
            matches: scanData.matches,
            enforcementResults: scanData.enforcementResults,
            scannedAt: (_a = scanData.scannedAt) === null || _a === void 0 ? void 0 : _a.toDate().toISOString()
        });
    }
    catch (error) {
        console.error('Get video matches error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// POST /v1/music/content-id/:matchId/set-revenue-share - Artist sets revenue %
app.post('/v1/music/content-id/:matchId/set-revenue-share', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { matchId } = req.params;
        const { revenueSharePercentage } = req.body || {};
        if (typeof revenueSharePercentage !== 'number' || revenueSharePercentage < 0 || revenueSharePercentage > 100) {
            return res.status(400).json({ error: 'revenueSharePercentage must be between 0 and 100' });
        }
        const scanRef = db.collection('music_content_id_scans').doc(matchId);
        const scanSnap = await scanRef.get();
        if (!scanSnap.exists) {
            return res.status(404).json({ error: 'Scan not found' });
        }
        const scanData = scanSnap.data();
        const match = scanData.matches.find((m) => m.artistId === user.userId);
        if (!match) {
            return res.status(403).json({ error: 'No match found for this artist' });
        }
        // Update the match with new revenue share
        const updatedMatches = scanData.matches.map((m) => {
            if (m.artistId === user.userId) {
                return {
                    ...m,
                    revenueSharePercentage,
                    copyrightPolicy: 'monetize'
                };
            }
            return m;
        });
        // Update enforcement results
        const updatedEnforcement = updatedMatches.map((m) => ({
            ...m,
            action: m.copyrightPolicy === 'monetize' ? 'revenue_share' : m.action,
            reason: m.copyrightPolicy === 'monetize' ? `Revenue sharing enabled - artist gets ${revenueSharePercentage}%` : m.reason
        }));
        await scanRef.update({
            matches: updatedMatches,
            enforcementResults: updatedEnforcement,
            updatedAt: firebase_admin_1.default.firestore.Timestamp.now()
        });
        res.json({
            matchId,
            revenueSharePercentage,
            message: `Revenue share updated to ${revenueSharePercentage}%`
        });
    }
    catch (error) {
        console.error('Set revenue share error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/content-id/:matchId/revenue - Track revenue from video usage
app.get('/v1/music/content-id/:matchId/revenue', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { matchId } = req.params;
        const scanRef = db.collection('music_content_id_scans').doc(matchId);
        const scanSnap = await scanRef.get();
        if (!scanSnap.exists) {
            return res.status(404).json({ error: 'Scan not found' });
        }
        const scanData = scanSnap.data();
        const match = scanData.matches.find((m) => m.artistId === user.userId);
        if (!match) {
            return res.status(403).json({ error: 'No match found for this artist' });
        }
        if (match.copyrightPolicy !== 'monetize') {
            return res.status(400).json({ error: 'This match is not set to revenue sharing' });
        }
        // Mock revenue data (in production, calculate from video ad revenue)
        const videoRevenue = Math.floor(Math.random() * 1000) + 100;
        const artistRevenue = videoRevenue * (match.revenueSharePercentage || 50) / 100;
        res.json({
            matchId,
            trackId: match.trackId,
            videoRevenue,
            artistRevenue,
            revenueSharePercentage: match.revenueSharePercentage,
            message: `Artist earned $${artistRevenue.toFixed(2)} from this video usage`
        });
    }
    catch (error) {
        console.error('Get revenue error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// POST /v1/music/content-id/:matchId/issue-strike - Manually issue copyright strike
app.post('/v1/music/content-id/:matchId/issue-strike', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { matchId } = req.params;
        const scanRef = db.collection('music_content_id_scans').doc(matchId);
        const scanSnap = await scanRef.get();
        if (!scanSnap.exists) {
            return res.status(404).json({ error: 'Scan not found' });
        }
        const scanData = scanSnap.data();
        const match = scanData.matches.find((m) => m.artistId === user.userId);
        if (!match) {
            return res.status(403).json({ error: 'No match found for this artist' });
        }
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        // Create copyright strike record
        const strikeRef = db.collection('copyright_strikes').doc();
        await strikeRef.set({
            id: strikeRef.id,
            scanId: matchId,
            trackId: match.trackId,
            artistId: user.userId,
            videoId: scanData.videoId,
            status: 'active',
            issuedAt: now,
            resolvedAt: null
        });
        res.json({
            strikeId: strikeRef.id,
            status: 'active',
            message: 'Copyright strike issued'
        });
    }
    catch (error) {
        console.error('Issue strike error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// POST /v1/music/content-id/:matchId/resolve-strike - Artist resolves strike (allows usage)
app.post('/v1/music/content-id/:matchId/resolve-strike', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { matchId } = req.params;
        const scanRef = db.collection('music_content_id_scans').doc(matchId);
        const scanSnap = await scanRef.get();
        if (!scanSnap.exists) {
            return res.status(404).json({ error: 'Scan not found' });
        }
        const scanData = scanSnap.data();
        const match = scanData.matches.find((m) => m.artistId === user.userId);
        if (!match) {
            return res.status(403).json({ error: 'No match found for this artist' });
        }
        // Find and resolve strike
        const strikesSnap = await db.collection('copyright_strikes')
            .where('scanId', '==', matchId)
            .where('artistId', '==', user.userId)
            .where('status', '==', 'active')
            .get();
        if (strikesSnap.empty) {
            return res.status(404).json({ error: 'No active strike found' });
        }
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        await strikesSnap.docs[0].ref.update({
            status: 'resolved',
            resolvedAt: now
        });
        res.json({
            message: 'Copyright strike resolved - usage permitted'
        });
    }
    catch (error) {
        console.error('Resolve strike error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/artists/:artistId/content-id/overview - Overview of matches, strikes, revenue
app.get('/v1/music/artists/:artistId/content-id/overview', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { artistId } = req.params;
        if (user.userId !== artistId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        // Get all scans involving this artist's tracks
        const tracksSnap = await db.collection('music_tracks')
            .where('artistId', '==', artistId)
            .get();
        const trackIds = tracksSnap.docs.map(doc => doc.id);
        const scansSnap = await db.collection('music_content_id_scans')
            .where('matches.artistId', '==', artistId)
            .limit(1000)
            .get();
        let totalMatches = 0;
        let totalRevenue = 0;
        const matchesByPolicy = { strict: 0, monetize: 0, allow: 0 };
        scansSnap.docs.forEach(doc => {
            const data = doc.data();
            data.matches.forEach((match) => {
                if (match.artistId === artistId) {
                    totalMatches++;
                    matchesByPolicy[match.copyrightPolicy] = (matchesByPolicy[match.copyrightPolicy] || 0) + 1;
                    if (match.copyrightPolicy === 'monetize') {
                        totalRevenue += Math.floor(Math.random() * 100);
                    }
                }
            });
        });
        // Get strikes
        const strikesSnap = await db.collection('copyright_strikes')
            .where('artistId', '==', artistId)
            .get();
        const overview = {
            artistId,
            totalTracksRegistered: trackIds.length,
            totalMatches,
            totalRevenue,
            matchesByPolicy,
            totalStrikesIssued: strikesSnap.size,
            activeStrikes: strikesSnap.docs.filter(doc => doc.data().status === 'active').length
        };
        res.json({ overview });
    }
    catch (error) {
        console.error('Content ID overview error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
const PORT = process.env.PORT || 8083;
app.listen(PORT, () => {
    console.log(`🎵 Music Content ID service listening on port ${PORT}`);
});
