"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const crypto_1 = require("crypto");
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
// Phase 5: Artist Verification & Rights Management
// ─────────────────────────────────────────────────────────────────────────────
// POST /v1/music/artists/verify - Submit verification
app.post('/v1/music/artists/verify', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { realName, idDocumentUrl, socialMediaLinks, websiteUrl } = req.body || {};
        if (!realName || typeof realName !== 'string') {
            return res.status(400).json({ error: 'realName is required' });
        }
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        const verificationRef = db.collection('artist_verification').doc(user.userId);
        await verificationRef.set({
            artistId: user.userId,
            realName,
            idDocumentUrl: idDocumentUrl || null,
            socialMediaLinks: socialMediaLinks || [],
            websiteUrl: websiteUrl || null,
            status: 'pending',
            submittedAt: now,
            reviewedAt: null,
            approvedAt: null,
            rejectionReason: null
        }, { merge: true });
        res.json({
            artistId: user.userId,
            status: 'pending',
            message: 'Verification submitted. Our team will review your application within 3-5 business days.'
        });
    }
    catch (error) {
        console.error('Submit verification error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/artists/:artistId/verification/status - Check verification status
app.get('/v1/music/artists/:artistId/verification/status', async (req, res) => {
    var _a, _b, _c;
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { artistId } = req.params;
        if (user.userId !== artistId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        const verificationRef = db.collection('artist_verification').doc(artistId);
        const verificationSnap = await verificationRef.get();
        if (!verificationSnap.exists) {
            return res.status(404).json({ error: 'Verification not submitted' });
        }
        const data = verificationSnap.data();
        res.json({
            artistId,
            status: data.status,
            submittedAt: (_a = data.submittedAt) === null || _a === void 0 ? void 0 : _a.toDate().toISOString(),
            reviewedAt: ((_b = data.reviewedAt) === null || _b === void 0 ? void 0 : _b.toDate().toISOString()) || null,
            approvedAt: ((_c = data.approvedAt) === null || _c === void 0 ? void 0 : _c.toDate().toISOString()) || null,
            rejectionReason: data.rejectionReason || null
        });
    }
    catch (error) {
        console.error('Get verification status error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// PUT /v1/music/artists/:artistId/profile - Update artist profile
app.put('/v1/music/artists/:artistId/profile', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { artistId } = req.params;
        const { bio, photos, socialLinks, website } = req.body || {};
        if (user.userId !== artistId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        const artistRef = db.collection('artists').doc(artistId);
        await artistRef.set({
            id: artistId,
            bio: bio || null,
            photos: photos || [],
            socialLinks: socialLinks || [],
            website: website || null,
            updatedAt: now
        }, { merge: true });
        res.json({
            artistId,
            message: 'Profile updated successfully'
        });
    }
    catch (error) {
        console.error('Update profile error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/artists/:artistId/profile - Get artist profile
app.get('/v1/music/artists/:artistId/profile', async (req, res) => {
    var _a;
    try {
        const { artistId } = req.params;
        const artistRef = db.collection('artists').doc(artistId);
        const artistSnap = await artistRef.get();
        if (!artistSnap.exists) {
            return res.status(404).json({ error: 'Artist profile not found' });
        }
        const data = artistSnap.data();
        res.json({
            artistId,
            bio: data.bio || null,
            photos: data.photos || [],
            socialLinks: data.socialLinks || [],
            website: data.website || null,
            updatedAt: ((_a = data.updatedAt) === null || _a === void 0 ? void 0 : _a.toDate().toISOString()) || null
        });
    }
    catch (error) {
        console.error('Get profile error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// POST /v1/music/tracks/:trackId/rights - Declare ownership
app.post('/v1/music/tracks/:trackId/rights', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId } = req.params;
        const { ownershipPercentage, isrc, upc } = req.body || {};
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
        const rightsRef = db.collection('music_track_rights').doc(trackId);
        await rightsRef.set({
            trackId,
            artistId: user.userId,
            ownershipPercentage: ownershipPercentage || 100,
            isrc: isrc || null,
            upc: upc || null,
            declaredAt: now
        }, { merge: true });
        await trackRef.update({
            isrc: isrc || null,
            upc: upc || null
        });
        res.json({
            trackId,
            ownershipPercentage: ownershipPercentage || 100,
            message: 'Rights declared successfully'
        });
    }
    catch (error) {
        console.error('Declare rights error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/tracks/:trackId/rights - Get rights information
app.get('/v1/music/tracks/:trackId/rights', async (req, res) => {
    var _a;
    try {
        const { trackId } = req.params;
        const rightsRef = db.collection('music_track_rights').doc(trackId);
        const rightsSnap = await rightsRef.get();
        if (!rightsSnap.exists) {
            return res.status(404).json({ error: 'Rights information not found' });
        }
        const data = rightsSnap.data();
        res.json({
            trackId,
            artistId: data.artistId,
            ownershipPercentage: data.ownershipPercentage,
            isrc: data.isrc,
            upc: data.upc,
            declaredAt: (_a = data.declaredAt) === null || _a === void 0 ? void 0 : _a.toDate().toISOString()
        });
    }
    catch (error) {
        console.error('Get rights error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// POST /v1/music/tracks/:trackId/collaborators - Add collaborators
app.post('/v1/music/tracks/:trackId/collaborators', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId } = req.params;
        const { collaborators } = req.body || {};
        if (!collaborators || !Array.isArray(collaborators)) {
            return res.status(400).json({ error: 'collaborators array is required' });
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
        const collaboratorsRef = db.collection('music_track_collaborators').doc(trackId);
        const collaboratorsData = collaborators.map((collab) => ({
            id: (0, crypto_1.randomUUID)(),
            name: collab.name,
            role: collab.role || 'featured',
            revenueSharePercentage: collab.revenueSharePercentage || 0,
            addedAt: now
        }));
        await collaboratorsRef.set({
            trackId,
            collaborators: collaboratorsData,
            updatedAt: now
        }, { merge: true });
        res.json({
            trackId,
            collaborators: collaboratorsData,
            message: 'Collaborators added successfully'
        });
    }
    catch (error) {
        console.error('Add collaborators error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// PUT /v1/music/tracks/:trackId/collaborators/:collaboratorId/split - Set revenue split
app.put('/v1/music/tracks/:trackId/collaborators/:collaboratorId/split', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { trackId, collaboratorId } = req.params;
        const { revenueSharePercentage } = req.body || {};
        if (typeof revenueSharePercentage !== 'number' || revenueSharePercentage < 0 || revenueSharePercentage > 100) {
            return res.status(400).json({ error: 'revenueSharePercentage must be between 0 and 100' });
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
        const collaboratorsRef = db.collection('music_track_collaborators').doc(trackId);
        const collaboratorsSnap = await collaboratorsRef.get();
        if (!collaboratorsSnap.exists) {
            return res.status(404).json({ error: 'Collaborators not found' });
        }
        const data = collaboratorsSnap.data();
        const collaborators = data.collaborators || [];
        const collaborator = collaborators.find((c) => c.id === collaboratorId);
        if (!collaborator) {
            return res.status(404).json({ error: 'Collaborator not found' });
        }
        const updatedCollaborators = collaborators.map((c) => {
            if (c.id === collaboratorId) {
                return { ...c, revenueSharePercentage };
            }
            return c;
        });
        await collaboratorsRef.update({
            collaborators: updatedCollaborators,
            updatedAt: firebase_admin_1.default.firestore.Timestamp.now()
        });
        res.json({
            trackId,
            collaboratorId,
            revenueSharePercentage,
            message: 'Revenue split updated successfully'
        });
    }
    catch (error) {
        console.error('Set revenue split error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
const PORT = process.env.PORT || 8084;
app.listen(PORT, () => {
    console.log(`🎵 Music artists service listening on port ${PORT}`);
});
