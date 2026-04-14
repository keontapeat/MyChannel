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
// Fan Engagement - Messaging, Comments, Fan Analytics
// ─────────────────────────────────────────────────────────────────────────────
// POST /v1/music/artists/:artistId/messages - Send fan message
app.post('/v1/music/artists/:artistId/messages', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { artistId } = req.params;
        const { message, trackId } = req.body || {};
        if (!message || typeof message !== 'string') {
            return res.status(400).json({ error: 'message is required' });
        }
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        const messageRef = db.collection('artist_fan_messages').doc();
        await messageRef.set({
            id: messageRef.id,
            artistId,
            fanId: user.userId,
            message: message.trim(),
            trackId: trackId || null,
            status: 'unread',
            createdAt: now
        });
        res.status(201).json({
            messageId: messageRef.id,
            status: 'sent',
            message: 'Message sent successfully'
        });
    }
    catch (error) {
        console.error('Send fan message error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/artists/:artistId/messages - Get fan messages (artist only)
app.get('/v1/music/artists/:artistId/messages', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { artistId } = req.params;
        if (user.userId !== artistId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        const { status, limit } = req.query || {};
        let query = db.collection('artist_fan_messages')
            .where('artistId', '==', artistId)
            .orderBy('createdAt', 'desc')
            .limit(parseInt(limit) || 50);
        if (status) {
            query = query.where('status', '==', status);
        }
        const messagesSnap = await query.get();
        const messages = messagesSnap.docs.map(doc => {
            var _a;
            const data = doc.data();
            return {
                id: doc.id,
                fanId: data.fanId,
                message: data.message,
                trackId: data.trackId,
                status: data.status,
                createdAt: (_a = data.createdAt) === null || _a === void 0 ? void 0 : _a.toDate().toISOString()
            };
        });
        res.json({
            artistId,
            messages,
            total: messagesSnap.size
        });
    }
    catch (error) {
        console.error('Get fan messages error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// PUT /v1/music/messages/:messageId/reply - Reply to fan message
app.put('/v1/music/messages/:messageId/reply', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { messageId } = req.params;
        const { reply } = req.body || {};
        if (!reply || typeof reply !== 'string') {
            return res.status(400).json({ error: 'reply is required' });
        }
        const messageRef = db.collection('artist_fan_messages').doc(messageId);
        const messageSnap = await messageRef.get();
        if (!messageSnap.exists) {
            return res.status(404).json({ error: 'Message not found' });
        }
        const messageData = messageSnap.data();
        if (String(messageData.artistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        await messageRef.update({
            reply: reply.trim(),
            replyAt: firebase_admin_1.default.firestore.Timestamp.now(),
            status: 'replied'
        });
        res.json({
            messageId,
            message: 'Reply sent successfully'
        });
    }
    catch (error) {
        console.error('Reply to message error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/artists/:artistId/fan-analytics - Fan analytics
app.get('/v1/music/artists/:artistId/fan-analytics', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { artistId } = req.params;
        if (user.userId !== artistId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        // Get total streams
        const tracksSnap = await db.collection('music_tracks')
            .where('artistId', '==', artistId)
            .get();
        let totalStreams = 0;
        tracksSnap.docs.forEach(doc => {
            totalStreams += doc.data().streamCount || 0;
        });
        // Get unique listeners
        const listenersSnap = await db.collection('music_streams')
            .where('trackId', 'in', tracksSnap.docs.map(doc => doc.id).slice(0, 10))
            .limit(10000)
            .get();
        const uniqueListeners = new Set();
        listenersSnap.docs.forEach(doc => {
            uniqueListeners.add(doc.data().userId);
        });
        // Get fan messages
        const messagesSnap = await db.collection('artist_fan_messages')
            .where('artistId', '==', artistId)
            .get();
        const analytics = {
            artistId,
            totalTracks: tracksSnap.size,
            totalStreams,
            uniqueListeners: uniqueListeners.size,
            totalFanMessages: messagesSnap.size,
            unreadMessages: messagesSnap.docs.filter(doc => doc.data().status === 'unread').length,
            engagementRate: uniqueListeners.size > 0 ? ((messagesSnap.size / uniqueListeners.size) * 100).toFixed(1) : '0'
        };
        res.json({ analytics });
    }
    catch (error) {
        console.error('Fan analytics error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// ─────────────────────────────────────────────────────────────────────────────
// Fan Subscriptions
// ─────────────────────────────────────────────────────────────────────────────
// POST /v1/music/artists/:artistId/subscriptions/tiers - Create subscription tier
app.post('/v1/music/artists/:artistId/subscriptions/tiers', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { artistId } = req.params;
        const { name, price, benefits } = req.body || {};
        if (!name || typeof name !== 'string') {
            return res.status(400).json({ error: 'name is required' });
        }
        if (typeof price !== 'number' || price < 0) {
            return res.status(400).json({ error: 'price must be a non-negative number' });
        }
        if (user.userId !== artistId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        const tierRef = db.collection('artist_subscription_tiers').doc();
        await tierRef.set({
            id: tierRef.id,
            artistId,
            name: name.trim(),
            price,
            benefits: benefits || [],
            createdAt: now
        });
        res.status(201).json({
            tierId: tierRef.id,
            name,
            price,
            message: 'Subscription tier created successfully'
        });
    }
    catch (error) {
        console.error('Create subscription tier error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// POST /v1/music/artists/:artistId/subscribe - Subscribe to artist
app.post('/v1/music/artists/:artistId/subscribe', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { artistId } = req.params;
        const { tierId } = req.body || {};
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        const subscriptionRef = db.collection('artist_subscriptions').doc();
        await subscriptionRef.set({
            id: subscriptionRef.id,
            artistId,
            fanId: user.userId,
            tierId: tierId || null,
            status: 'active',
            subscribedAt: now,
            expiresAt: null
        });
        res.status(201).json({
            subscriptionId: subscriptionRef.id,
            status: 'active',
            message: 'Subscribed successfully'
        });
    }
    catch (error) {
        console.error('Subscribe error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/artists/:artistId/subscribers - Get subscribers count
app.get('/v1/music/artists/:artistId/subscribers', async (req, res) => {
    try {
        const { artistId } = req.params;
        const subscribersSnap = await db.collection('artist_subscriptions')
            .where('artistId', '==', artistId)
            .where('status', '==', 'active')
            .get();
        res.json({
            artistId,
            totalSubscribers: subscribersSnap.size
        });
    }
    catch (error) {
        console.error('Get subscribers error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// ─────────────────────────────────────────────────────────────────────────────
// Collaboration Requests
// ─────────────────────────────────────────────────────────────────────────────
// POST /v1/music/collaborations/request - Send collaboration request
app.post('/v1/music/collaborations/request', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { targetArtistId, trackId, role, message } = req.body || {};
        if (!targetArtistId) {
            return res.status(400).json({ error: 'targetArtistId is required' });
        }
        if (!role) {
            return res.status(400).json({ error: 'role is required (e.g., featured, producer, writer)' });
        }
        const now = firebase_admin_1.default.firestore.Timestamp.now();
        const collabRef = db.collection('music_collaborations').doc();
        await collabRef.set({
            id: collabRef.id,
            requestingArtistId: user.userId,
            targetArtistId,
            trackId: trackId || null,
            role,
            message: message || null,
            status: 'pending',
            createdAt: now
        });
        res.status(201).json({
            collaborationId: collabRef.id,
            status: 'pending',
            message: 'Collaboration request sent successfully'
        });
    }
    catch (error) {
        console.error('Send collaboration request error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// GET /v1/music/collaborations - Get collaboration requests
app.get('/v1/music/collaborations', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { type } = req.query || {};
        let query;
        if (type === 'incoming') {
            query = db.collection('music_collaborations')
                .where('targetArtistId', '==', user.userId)
                .orderBy('createdAt', 'desc');
        }
        else if (type === 'outgoing') {
            query = db.collection('music_collaborations')
                .where('requestingArtistId', '==', user.userId)
                .orderBy('createdAt', 'desc');
        }
        else {
            return res.status(400).json({ error: 'type must be incoming or outgoing' });
        }
        const collabsSnap = await query.limit(50).get();
        const collabs = collabsSnap.docs.map(doc => {
            var _a;
            const data = doc.data();
            return {
                id: doc.id,
                requestingArtistId: data.requestingArtistId,
                targetArtistId: data.targetArtistId,
                trackId: data.trackId,
                role: data.role,
                message: data.message,
                status: data.status,
                createdAt: (_a = data.createdAt) === null || _a === void 0 ? void 0 : _a.toDate().toISOString()
            };
        });
        res.json({
            type,
            collaborations: collabs,
            total: collabsSnap.size
        });
    }
    catch (error) {
        console.error('Get collaborations error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
// PUT /v1/music/collaborations/:collabId/respond - Respond to collaboration request
app.put('/v1/music/collaborations/:collabId/respond', async (req, res) => {
    try {
        const user = await requireUser(req, res);
        if (!user)
            return;
        const { collabId } = req.params;
        const { response } = req.body || {};
        if (!response || !['accepted', 'declined'].includes(response)) {
            return res.status(400).json({ error: 'response must be accepted or declined' });
        }
        const collabRef = db.collection('music_collaborations').doc(collabId);
        const collabSnap = await collabRef.get();
        if (!collabSnap.exists) {
            return res.status(404).json({ error: 'Collaboration not found' });
        }
        const collabData = collabSnap.data();
        if (String(collabData.targetArtistId || '') !== user.userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        await collabRef.update({
            status: response,
            respondedAt: firebase_admin_1.default.firestore.Timestamp.now()
        });
        res.json({
            collaborationId: collabId,
            status: response,
            message: `Collaboration ${response} successfully`
        });
    }
    catch (error) {
        console.error('Respond to collaboration error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});
const PORT = process.env.PORT || 8087;
app.listen(PORT, () => {
    console.log(`🎵 Music fan engagement service listening on port ${PORT}`);
});
