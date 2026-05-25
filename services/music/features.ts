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
// Pre-release Scheduling
// ─────────────────────────────────────────────────────────────────────────────

// PUT /v1/music/tracks/:trackId/schedule - Schedule track release
app.put('/v1/music/tracks/:trackId/schedule', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { trackId } = req.params;
    const { releaseDate } = req.body || {};

    if (!releaseDate) {
      return res.status(400).json({ error: 'releaseDate is required' });
    }

    const releaseDateObj = new Date(releaseDate);
    if (releaseDateObj < new Date()) {
      return res.status(400).json({ error: 'releaseDate must be in the future' });
    }

    const trackRef = db.collection('music_tracks').doc(trackId);
    const trackSnap = await trackRef.get();

    if (!trackSnap.exists) {
      return res.status(404).json({ error: 'Track not found' });
    }

    const trackData = trackSnap.data()!;

    if (String(trackData.artistId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    await trackRef.update({
      scheduledReleaseDate: admin.firestore.Timestamp.fromDate(releaseDateObj),
      status: 'scheduled',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.json({
      trackId,
      scheduledReleaseDate: releaseDateObj.toISOString(),
      message: 'Track scheduled for release'
    });
  } catch (error) {
    console.error('Schedule track error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Track Versions (Remixes, Alternate Mixes)
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/music/tracks/:trackId/versions - Create track version
app.post('/v1/music/tracks/:trackId/versions', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { trackId } = req.params;
    const { versionType, title, audioURL } = req.body || {};

    if (!versionType || !['remix', 'alternate', 'live', 'acoustic'].includes(versionType)) {
      return res.status(400).json({ error: 'versionType must be remix, alternate, live, or acoustic' });
    }

    if (!title) {
      return res.status(400).json({ error: 'title is required' });
    }

    const trackRef = db.collection('music_tracks').doc(trackId);
    const trackSnap = await trackRef.get();

    if (!trackSnap.exists) {
      return res.status(404).json({ error: 'Track not found' });
    }

    const trackData = trackSnap.data()!;

    if (String(trackData.artistId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const versionRef = db.collection('music_track_versions').doc();

    await versionRef.set({
      id: versionRef.id,
      parentTrackId: trackId,
      artistId: user.userId,
      versionType,
      title: title.trim(),
      audioURL: audioURL || null,
      createdAt: now
    });

    res.status(201).json({
      versionId: versionRef.id,
      versionType,
      title,
      message: 'Track version created successfully'
    });
  } catch (error) {
    console.error('Create track version error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/music/tracks/:trackId/versions - List track versions
app.get('/v1/music/tracks/:trackId/versions', async (req, res) => {
  try {
    const { trackId } = req.params;

    const versionsSnap = await db.collection('music_track_versions')
      .where('parentTrackId', '==', trackId)
      .orderBy('createdAt', 'desc')
      .get();

    const versions = versionsSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        versionType: data.versionType,
        title: data.title,
        audioURL: data.audioURL,
        createdAt: data.createdAt?.toDate().toISOString()
      };
    });

    res.json({
      trackId,
      versions,
      total: versionsSnap.size
    });
  } catch (error) {
    console.error('List track versions error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Lyrics Integration
// ─────────────────────────────────────────────────────────────────────────────

// PUT /v1/music/tracks/:trackId/lyrics - Add lyrics to track
app.put('/v1/music/tracks/:trackId/lyrics', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { trackId } = req.params;
    const { lyrics, syncedLyrics } = req.body || {};

    if (!lyrics && !syncedLyrics) {
      return res.status(400).json({ error: 'lyrics or syncedLyrics is required' });
    }

    const trackRef = db.collection('music_tracks').doc(trackId);
    const trackSnap = await trackRef.get();

    if (!trackSnap.exists) {
      return res.status(404).json({ error: 'Track not found' });
    }

    const trackData = trackSnap.data()!;

    if (String(trackData.artistId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const updates: any = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    if (lyrics) updates.lyrics = lyrics;
    if (syncedLyrics) updates.syncedLyrics = syncedLyrics;

    await trackRef.update(updates);

    res.json({
      trackId,
      message: 'Lyrics added successfully'
    });
  } catch (error) {
    console.error('Add lyrics error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/music/tracks/:trackId/lyrics - Get track lyrics
app.get('/v1/music/tracks/:trackId/lyrics', async (req, res) => {
  try {
    const { trackId } = req.params;

    const trackRef = db.collection('music_tracks').doc(trackId);
    const trackSnap = await trackRef.get();

    if (!trackSnap.exists) {
      return res.status(404).json({ error: 'Track not found' });
    }

    const trackData = trackSnap.data()!;

    res.json({
      trackId,
      lyrics: trackData.lyrics || null,
      syncedLyrics: trackData.syncedLyrics || null
    });
  } catch (error) {
    console.error('Get lyrics error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Social Sharing
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/music/tracks/:trackId/share - Generate share links
app.post('/v1/music/tracks/:trackId/share', async (req, res) => {
  try {
    const { trackId } = req.params;
    const { platforms } = req.body || [];

    const trackRef = db.collection('music_tracks').doc(trackId);
    const trackSnap = await trackRef.get();

    if (!trackSnap.exists) {
      return res.status(404).json({ error: 'Track not found' });
    }

    const trackData = trackSnap.data()!;
    const trackTitle = encodeURIComponent(trackData.title || '');
    const trackURL = `https://mychannel.live/music/track/${trackId}`;

    const shareLinks: any = {};

    if (platforms.includes('instagram')) {
      shareLinks.instagram = `https://www.instagram.com/create/story?background_image=${trackURL}`;
    }
    if (platforms.includes('tiktok')) {
      shareLinks.tiktok = `https://www.tiktok.com/share/video?url=${trackURL}`;
    }
    if (platforms.includes('twitter')) {
      shareLinks.twitter = `https://twitter.com/intent/tweet?text=Check out ${trackTitle} on MyChannel Music!&url=${trackURL}`;
    }
    if (platforms.includes('facebook')) {
      shareLinks.facebook = `https://www.facebook.com/sharer/sharer.php?u=${trackURL}`;
    }

    res.json({
      trackId,
      trackURL,
      shareLinks
    });
  } catch (error) {
    console.error('Generate share links error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Artist Profile Customization
// ─────────────────────────────────────────────────────────────────────────────

// PUT /v1/music/artists/:artistId/profile - Enhanced profile update
app.put('/v1/music/artists/:artistId/profile', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { artistId } = req.params;
    const { bio, photos, bannerImage, socialLinks, website, location, genres } = req.body || {};

    if (user.userId !== artistId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const artistRef = db.collection('artists').doc(artistId);

    const updates: any = { updatedAt: now };
    if (bio !== undefined) updates.bio = bio;
    if (photos !== undefined) updates.photos = photos;
    if (bannerImage !== undefined) updates.bannerImage = bannerImage;
    if (socialLinks !== undefined) updates.socialLinks = socialLinks;
    if (website !== undefined) updates.website = website;
    if (location !== undefined) updates.location = location;
    if (genres !== undefined) updates.genres = genres;

    await artistRef.set(updates, { merge: true });

    res.json({
      artistId,
      message: 'Profile updated successfully'
    });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Analytics Export
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/music/artists/:artistId/analytics/export - Export analytics
app.post('/v1/music/artists/:artistId/analytics/export', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { artistId } = req.params;
    const { format, timeRange } = req.body || {};

    if (user.userId !== artistId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const validFormats = ['csv', 'pdf'];
    if (!format || !validFormats.includes(format)) {
      return res.status(400).json({ error: `format must be one of: ${validFormats.join(', ')}` });
    }

    // Get analytics data
    const tracksSnap = await db.collection('music_tracks')
      .where('artistId', '==', artistId)
      .get();

    let csvContent = 'Track ID,Title,Streams,Likes,Status,Created At\n';
    tracksSnap.docs.forEach(doc => {
      const data = doc.data();
      csvContent += `${doc.id},"${data.title || ''}",${data.streamCount || 0},${data.likeCount || 0},${data.status || ''},${data.createdAt?.toDate().toISOString() || ''}\n`;
    });

    const exportData = format === 'csv' ? csvContent : JSON.stringify(tracksSnap.docs.map(doc => doc.data()));

    res.json({
      artistId,
      format,
      data: exportData,
      generatedAt: new Date().toISOString()
    });
  } catch (error) {
    console.error('Export analytics error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const PORT = process.env.PORT || 8086;
app.listen(PORT, () => {
  console.log(`🎵 Music features service listening on port ${PORT}`);
});
