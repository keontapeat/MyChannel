import express from 'express';
import admin from 'firebase-admin';

const app = express();
app.use(express.json());

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'mychannel-ca26d'
  });
}

const db = admin.firestore();

// Helper function to verify Firebase Auth token
async function requireUser(req: any, res: any) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Unauthorized' });
      return null;
    }

    const token = authHeader.split('Bearer ')[1];
    const decoded = await admin.auth().verifyIdToken(token);
    return { userId: decoded.uid, email: decoded.email };
  } catch (error) {
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

    const now = admin.firestore.Timestamp.now();

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
      streamCount: admin.firestore.FieldValue.increment(1),
      lastStreamAt: now
    });

    // Update listener profile
    const listenerRef = db.collection('music_listeners').doc(userId);
    const listenerSnap = await listenerRef.get();

    if (listenerSnap.exists) {
      await listenerRef.update({
        totalStreams: admin.firestore.FieldValue.increment(1),
        lastStreamAt: now,
        [`tracks.${trackId}`]: admin.firestore.FieldValue.increment(1)
      });
    } else {
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
  } catch (error) {
    console.error('Track stream error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/music/tracks/:trackId/streams/realtime - Real-time stream count
app.get('/v1/music/tracks/:trackId/streams/realtime', async (req, res) => {
  try {
    const { trackId } = req.params;

    const trackRef = db.collection('music_tracks').doc(trackId);
    const trackSnap = await trackRef.get();

    if (!trackSnap.exists) {
      return res.status(404).json({ error: 'Track not found' });
    }

    const trackData = trackSnap.data()!;

    // Get streams in last hour for real-time count
    const oneHourAgo = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 60 * 60 * 1000));
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
      lastStreamAt: trackData.lastStreamAt?.toDate().toISOString() || null
    });
  } catch (error) {
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
    if (!validTimeRanges.includes(timeRangeValue as string)) {
      return res.status(400).json({ error: `Invalid timeRange. Must be one of: ${validTimeRanges.join(', ')}` });
    }

    const trackRef = db.collection('music_tracks').doc(trackId);
    const trackSnap = await trackRef.get();

    if (!trackSnap.exists) {
      return res.status(404).json({ error: 'Track not found' });
    }

    const trackData = trackSnap.data()!;

    // Calculate time range
    const timeRangeMs = {
      '1h': 60 * 60 * 1000,
      '24h': 24 * 60 * 60 * 1000,
      '7d': 7 * 24 * 60 * 60 * 1000,
      '30d': 30 * 24 * 60 * 60 * 1000,
      '90d': 90 * 24 * 60 * 60 * 1000,
      '1y': 365 * 24 * 60 * 60 * 1000
    };

    const startDate = admin.firestore.Timestamp.fromDate(new Date(Date.now() - timeRangeMs[timeRangeValue as keyof typeof timeRangeMs]));

    const streamsSnap = await db.collection('music_streams')
      .where('trackId', '==', trackId)
      .where('timestamp', '>=', startDate)
      .orderBy('timestamp', 'desc')
      .limit(10000)
      .get();

    // Group by interval
    const intervalMs = interval === 'hour' ? 60 * 60 * 1000 : (interval === 'day' ? 24 * 60 * 60 * 1000 : 60 * 60 * 1000);
    const groupedData: Record<string, number> = {};

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
  } catch (error) {
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

    const geographicData: Record<string, number> = {};
    streamsSnap.docs.forEach(doc => {
      const data = doc.data();
      const country = data.location?.country || 'Unknown';
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
  } catch (error) {
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

    // Aggregate real demographics from listener profiles. Stream events carry
    // userId; we resolve each unique listener's profile (age/gender/language)
    // from the `users` collection and bucket them.
    const uniqueUserIds = new Set<string>();
    streamsSnap.docs.forEach(doc => {
      const uid = doc.data().userId;
      if (uid) uniqueUserIds.add(uid);
    });

    const ageBuckets: Record<string, number> = { '13-17': 0, '18-24': 0, '25-34': 0, '35-44': 0, '45-54': 0, '55+': 0 };
    const genderBuckets: Record<string, number> = {};
    const languageBuckets: Record<string, number> = {};
    let profilesResolved = 0;

    // Batch-get profiles (Firestore getAll supports up to 500 refs per call).
    const ids = Array.from(uniqueUserIds).slice(0, 5000);
    for (let i = 0; i < ids.length; i += 300) {
      const chunk = ids.slice(i, i + 300);
      const refs = chunk.map(id => db.collection('users').doc(id));
      const snaps = await db.getAll(...refs);
      snaps.forEach(snap => {
        if (!snap.exists) return;
        const u = snap.data()!;
        profilesResolved++;
        const age = Number(u.age) || 0;
        if (age >= 13 && age <= 17) ageBuckets['13-17']++;
        else if (age <= 24) ageBuckets['18-24']++;
        else if (age <= 34) ageBuckets['25-34']++;
        else if (age <= 44) ageBuckets['35-44']++;
        else if (age <= 54) ageBuckets['45-54']++;
        else if (age >= 55) ageBuckets['55+']++;
        const gender = (u.gender || 'Unknown').toString();
        genderBuckets[gender] = (genderBuckets[gender] || 0) + 1;
        const lang = (u.language || u.locale || 'Unknown').toString();
        languageBuckets[lang] = (languageBuckets[lang] || 0) + 1;
      });
    }

    const toPct = (buckets: Record<string, number>, total: number, keyName: string) =>
      Object.entries(buckets)
        .filter(([, c]) => c > 0)
        .map(([k, c]) => ({ [keyName]: k, percentage: total > 0 ? Math.round((c / total) * 100) : 0 }))
        .sort((a: any, b: any) => b.percentage - a.percentage);

    const demographics = {
      age: Object.entries(ageBuckets).map(([range, c]) => ({
        range,
        percentage: profilesResolved > 0 ? Math.round((c / profilesResolved) * 100) : 0,
      })),
      gender: toPct(genderBuckets, profilesResolved, 'gender'),
      language: toPct(languageBuckets, profilesResolved, 'language'),
    };

    res.json({
      trackId,
      totalListeners: streamsSnap.size,
      profilesResolved,
      demographics
    });
  } catch (error) {
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

    const deviceData: Record<string, number> = {};
    const platformData: Record<string, number> = {};

    streamsSnap.docs.forEach(doc => {
      const data = doc.data();
      const device = data.device?.type || 'Unknown';
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
  } catch (error) {
    console.error('Device breakdown error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/music/artists/:artistId/analytics/overview - Complete analytics overview
app.get('/v1/music/artists/:artistId/analytics/overview', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

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
    const trackIds: string[] = [];

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
    const thirtyDaysAgo = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000));
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
  } catch (error) {
    console.error('Analytics overview error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const PORT = process.env.PORT || 8082;
app.listen(PORT, () => {
  console.log(`🎵 Music analytics service listening on port ${PORT}`);
});
