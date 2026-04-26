import express from 'express';
import cors from 'cors';
import admin from 'firebase-admin';
import jwt from 'jsonwebtoken';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const JWT_SECRET = process.env.JWT_SECRET || '';

function toIsoString(value) {
  if (!value) return null;
  if (typeof value === 'string') return value;
  if (value instanceof Date) return value.toISOString();
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  if (typeof value._seconds === 'number') return new Date(value._seconds * 1000).toISOString();
  return null;
}

function randomKey(prefix) {
  return `${prefix}_${Math.random().toString(36).slice(2, 10)}`;
}

function classifyHealth({ bitrate, fps, droppedFrames, bandwidth }) {
  if ((typeof droppedFrames === 'number' && droppedFrames > 200) || (typeof fps === 'number' && fps < 15)) {
    return 'critical';
  }
  if ((typeof droppedFrames === 'number' && droppedFrames > 60) || (typeof fps === 'number' && fps < 24) || (typeof bitrate === 'number' && bitrate < 1200)) {
    return 'degraded';
  }
  if ((typeof bandwidth === 'number' && bandwidth > 0) || (typeof bitrate === 'number' && bitrate > 0)) {
    return 'healthy';
  }
  return 'unknown';
}

function serializeStream(data) {
  return {
    id: data.id,
    streamKey: data.streamKey,
    rtmpUrl: data.rtmpUrl,
    hlsUrl: data.hlsUrl,
    status: data.status,
    lifecycleState: data.lifecycleState || data.status,
    title: data.title || null,
    description: data.description || null,
    latencyMode: data.latencyMode || 'normal',
    viewerCount: Number(data.viewerCount || 0),
    peakViewerCount: Number(data.peakViewerCount || 0),
    sessionDurationSec: Number(data.sessionDurationSec || 0),
    totalViewerEvents: Number(data.totalViewerEvents || 0),
    healthStatus: data.healthStatus || 'unknown',
    ingestStatus: data.ingestStatus || 'ready',
    startedAt: toIsoString(data.startedAt),
    endedAt: toIsoString(data.endedAt),
    lastHealthAt: toIsoString(data.lastHealthAt),
    lastViewerUpdateAt: toIsoString(data.lastViewerUpdateAt),
    scheduledStartAt: toIsoString(data.scheduledStartAt),
    createdAt: toIsoString(data.createdAt),
    updatedAt: toIsoString(data.updatedAt)
  };
}

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

    const { title, description, latencyMode, scheduledStartAt } = req.body || {};
    const id = `live_${Date.now()}`;
    const streamKey = randomKey('sk');
    const rtmpUrl = `rtmp://rtmp.mychannel.live/live/${streamKey}`;
    const hlsUrl = `https://cdn.mychannel.live/hls/${id}/master.m3u8`;
    const now = admin.firestore.Timestamp.now();

    const streamData = {
      id,
      streamKey,
      rtmpUrl,
      hlsUrl,
      status: 'live',
      lifecycleState: 'live',
      userId: user.userId,
      title: String(title || '').trim() || 'Untitled Live Stream',
      description: String(description || '').trim() || null,
      latencyMode: String(latencyMode || 'normal').trim().toLowerCase() || 'normal',
      ingestStatus: 'ready',
      viewerCount: 0,
      peakViewerCount: 0,
      totalViewerEvents: 0,
      healthStatus: 'unknown',
      sessionDurationSec: 0,
      scheduledStartAt: scheduledStartAt ? admin.firestore.Timestamp.fromDate(new Date(String(scheduledStartAt))) : null,
      startedAt: now,
      endedAt: null,
      createdAt: now,
      updatedAt: now
    };

    await db.collection('live_streams').doc(id).set(streamData);

    res.json(serializeStream(streamData));
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
    if (String(streamData.status || '') === 'ended') {
      return res.status(409).json({ error: 'Stream already ended' });
    }

    const now = admin.firestore.Timestamp.now();
    const startedAtMs = streamData.startedAt?.toDate ? streamData.startedAt.toDate().getTime() : Date.now();
    await streamRef.update({
      status: 'ended',
      lifecycleState: 'ended',
      endedAt: now,
      sessionDurationSec: Math.max(0, Math.round((Date.now() - startedAtMs) / 1000)),
      updatedAt: now
    });

    const updated = await streamRef.get();
    res.json({ ok: true, stream: serializeStream(updated.data() || {}) });
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
    res.json(serializeStream(data));
  } catch (error) {
    console.error('Get live status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /live/:id/health - report stream health metrics
app.post('/live/:id/health', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const { bitrate, fps, droppedFrames, bandwidth } = req.body || {};

    const streamRef = db.collection('live_streams').doc(id);
    const snap = await streamRef.get();

    if (!snap.exists) {
      return res.status(404).json({ error: 'Stream not found' });
    }

    const streamData = snap.data();
    if (String(streamData.userId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    if (String(streamData.status || '') !== 'live') {
      return res.status(409).json({ error: 'Stream is not live' });
    }

    const now = admin.firestore.Timestamp.now();
    const healthStatus = classifyHealth({ bitrate, fps, droppedFrames, bandwidth });
    const healthRef = streamRef.collection('health').doc(now.toDate().toISOString());

    await healthRef.set({
      bitrate: typeof bitrate === 'number' ? bitrate : null,
      fps: typeof fps === 'number' ? fps : null,
      droppedFrames: typeof droppedFrames === 'number' ? droppedFrames : null,
      bandwidth: typeof bandwidth === 'number' ? bandwidth : null,
      status: healthStatus,
      timestamp: now
    });

    await streamRef.update({
      lastHealthAt: now,
      healthStatus,
      updatedAt: now
    });

    res.json({ ok: true, healthStatus, recordedAt: toIsoString(now) });
  } catch (error) {
    console.error('Report health error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /live/:id/viewers - update viewer count
app.post('/live/:id/viewers', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { id } = req.params;
    const { count, delta } = req.body || {};

    const streamRef = db.collection('live_streams').doc(id);
    const snap = await streamRef.get();

    if (!snap.exists) {
      return res.status(404).json({ error: 'Stream not found' });
    }

    const streamData = snap.data();
    if (String(streamData.userId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    if (String(streamData.status || '') !== 'live') {
      return res.status(409).json({ error: 'Stream is not live' });
    }

    const now = admin.firestore.Timestamp.now();
    const currentCount = Number(streamData.viewerCount || 0);
    const nextCount = typeof count === 'number'
      ? Math.max(0, count)
      : typeof delta === 'number'
        ? Math.max(0, currentCount + delta)
        : currentCount;
    const update = {
      lastViewerUpdateAt: now,
      viewerCount: nextCount,
      peakViewerCount: Math.max(Number(streamData.peakViewerCount || 0), nextCount),
      totalViewerEvents: Number(streamData.totalViewerEvents || 0) + 1,
      updatedAt: now
    };

    await streamRef.update(update);

    const viewerHistoryRef = streamRef.collection('viewerHistory').doc(now.toDate().toISOString());
    await viewerHistoryRef.set({
      count: nextCount,
      delta: typeof delta === 'number' ? delta : null,
      timestamp: now
    });

    res.json({ ok: true, viewerCount: nextCount, peakViewerCount: update.peakViewerCount });
  } catch (error) {
    console.error('Update viewers error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /live/:id/metrics - get stream metrics
app.get('/live/:id/metrics', async (req, res) => {
  try {
    const { id } = req.params;
    const hours = parseInt(req.query.hours) || 1;

    const streamRef = db.collection('live_streams').doc(id);
    const snap = await streamRef.get();

    if (!snap.exists) {
      return res.status(404).json({ error: 'Stream not found' });
    }

    const streamData = snap.data();
    const since = admin.firestore.Timestamp.fromDate(new Date(Date.now() - hours * 60 * 60 * 1000));

    const healthSnap = await streamRef.collection('health')
      .where('timestamp', '>=', since)
      .orderBy('timestamp', 'desc')
      .limit(60)
      .get();

    const viewerSnap = await streamRef.collection('viewerHistory')
      .where('timestamp', '>=', since)
      .orderBy('timestamp', 'desc')
      .limit(60)
      .get();

    const healthMetrics = healthSnap.docs.map(doc => doc.data());
    const viewerMetrics = viewerSnap.docs.map(doc => doc.data());

    const avgBitrate = healthMetrics.length > 0 
      ? healthMetrics.reduce((sum, m) => sum + (m.bitrate || 0), 0) / healthMetrics.length 
      : 0;

    const avgFps = healthMetrics.length > 0 
      ? healthMetrics.reduce((sum, m) => sum + (m.fps || 0), 0) / healthMetrics.length 
      : 0;

    const totalDroppedFrames = healthMetrics.reduce((sum, m) => sum + (m.droppedFrames || 0), 0);

    const peakViewers = viewerMetrics.length > 0 
      ? Math.max(...viewerMetrics.map(m => m.count || 0)) 
      : 0;

    const avgViewers = viewerMetrics.length > 0
      ? viewerMetrics.reduce((sum, m) => sum + (m.count || 0), 0) / viewerMetrics.length
      : Number(streamData.viewerCount || 0);

    const healthBreakdown = healthMetrics.reduce((acc, metric) => {
      const key = metric.status || 'unknown';
      acc[key] = (acc[key] || 0) + 1;
      return acc;
    }, {});

    res.json({
      streamId: id,
      status: streamData.status,
      lifecycleState: streamData.lifecycleState || streamData.status,
      currentViewers: streamData.viewerCount || 0,
      peakViewers: Math.max(peakViewers, Number(streamData.peakViewerCount || 0)),
      avgViewers: Math.round(avgViewers),
      avgBitrate: Math.round(avgBitrate),
      avgFps: Math.round(avgFps),
      totalDroppedFrames,
      healthStatus: streamData.healthStatus || 'unknown',
      healthBreakdown,
      sessionDurationSec: Number(streamData.sessionDurationSec || 0),
      healthMetrics: healthMetrics.slice(0, 20),
      viewerMetrics: viewerMetrics.slice(0, 20),
      period: `${hours} hours`
    });
  } catch (error) {
    console.error('Get metrics error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`live-control listening on ${port}`));




