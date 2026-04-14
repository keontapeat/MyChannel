import express from 'express';
import cors from 'cors';
import admin from 'firebase-admin';
import jwt from 'jsonwebtoken';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const JWT_SECRET = process.env.JWT_SECRET || '';

async function verifyUser(authHeader) {
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;
  const token = authHeader.slice(7).trim();
  if (!token) return null;

  try {
    const decoded = await admin.auth().verifyIdToken(token);
    return {
      userId: decoded.uid,
      email: decoded.email || null,
      username: decoded.name || (decoded.email ? decoded.email.split('@')[0] : null)
    };
  } catch {}

  if (!JWT_SECRET) return null;

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const userId = String(decoded.userId || decoded.uid || '').trim();
    if (!userId) return null;
    return {
      userId,
      email: decoded.email || null,
      username: decoded.username || null
    };
  } catch {
    return null;
  }
}

async function requireUser(req, res) {
  const user = await verifyUser(req.headers.authorization);
  if (!user) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }
  return user;
}

const app = express();
app.use(cors());
app.use(express.json());

app.get('/healthz', (req, res) => res.json({ ok: true }));

app.post('/live/start', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const id = `live_${Date.now()}`;
    const streamKey = `sk_${Math.random().toString(36).slice(2, 10)}`;
    const rtmpUrl = `rtmp://rtmp.mychannel.live/live/${streamKey}`;
    const hlsUrl = `https://cdn.mychannel.live/hls/${id}/master.m3u8`;
    const now = admin.firestore.Timestamp.now();

    const streamData = {
      id,
      streamKey,
      rtmpUrl,
      hlsUrl,
      status: 'live',
      userId: user.userId,
      startedAt: now,
      endedAt: null
    };

    await db.collection('live_streams').doc(id).set(streamData);

    res.json({
      id,
      streamKey,
      rtmpUrl,
      hlsUrl,
      status: 'live',
      startedAt: now.toDate().toISOString()
    });
  } catch (error) {
    console.error('Start live error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/live/end', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.body || {};
    if (!id) return res.status(400).json({ error: 'id is required' });

    const streamRef = db.collection('live_streams').doc(id);
    const snap = await streamRef.get();

    if (!snap.exists) {
      return res.status(404).json({ error: 'Stream not found' });
    }

    const streamData = snap.data();
    if (String(streamData.userId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    await streamRef.update({
      status: 'ended',
      endedAt: now
    });

    res.json({ ok: true });
  } catch (error) {
    console.error('End live error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/live/status/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const snap = await db.collection('live_streams').doc(id).get();

    if (!snap.exists) {
      return res.status(404).json({ error: 'Stream not found' });
    }

    const data = snap.data();
    res.json({
      id: data.id,
      streamKey: data.streamKey,
      rtmpUrl: data.rtmpUrl,
      hlsUrl: data.hlsUrl,
      status: data.status,
      startedAt: data.startedAt ? data.startedAt.toDate().toISOString() : null,
      endedAt: data.endedAt ? data.endedAt.toDate().toISOString() : null
    });
  } catch (error) {
    console.error('Get live status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`live-control listening on ${port}`));




