/**
 * presave.ts — Pre-save / HyperFollow smart links + synced lyrics + cover licensing.
 *
 * Parity features:
 *   • Pre-save smart links (like DistroKid HyperFollow / Linkfire): a landing
 *     page slug that collects pre-saves and fan emails before release, then
 *     auto-adds the release to fans' libraries on release day.
 *   • Synced lyrics: parse/serve LRC-format timestamped lyrics for a karaoke
 *     scrubbing UI (Apple/Spotify parity).
 *   • Cover-song mechanical licensing intake (US: required for covers).
 */

import express from 'express';
import admin from 'firebase-admin';

const app = express();
app.use(express.json({ limit: '2mb' }));

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'mychannel-ca26d',
  });
}

const db = admin.firestore();
const SMART_LINK_BASE = process.env.SMART_LINK_BASE || 'https://mychannel.live/m';

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
  } catch {
    res.status(401).json({ error: 'Invalid token' });
    return null;
  }
}

function slugify(input: string): string {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60);
}

// ─────────────────────────────────────────────────────────────────────────────
// Pre-save smart links
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/music/presave/links — create a smart link for an upcoming release
app.post('/v1/music/presave/links', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { trackId, albumId, title, artistName, artworkURL, releaseDate, platforms } = req.body || {};
    if (!title || (!trackId && !albumId)) {
      return res.status(400).json({ error: 'title and trackId or albumId are required' });
    }

    // Build a unique slug.
    let base = slugify(`${artistName || ''}-${title}`) || `release-${Date.now()}`;
    let slug = base;
    let n = 1;
    while ((await db.collection('music_smart_links').doc(slug).get()).exists) {
      slug = `${base}-${n++}`;
    }

    const now = admin.firestore.Timestamp.now();
    await db.collection('music_smart_links').doc(slug).set({
      slug,
      artistId: user.userId,
      trackId: trackId || null,
      albumId: albumId || null,
      title,
      artistName: artistName || null,
      artworkURL: artworkURL || null,
      releaseDate: releaseDate ? admin.firestore.Timestamp.fromDate(new Date(releaseDate)) : null,
      platforms: platforms || ['spotify', 'apple_music', 'youtube_music', 'amazon_music', 'tidal'],
      preSaveCount: 0,
      isReleased: false,
      createdAt: now,
    });

    res.status(201).json({
      slug,
      url: `${SMART_LINK_BASE}/${slug}`,
      message: 'Smart link created. Share it to collect pre-saves before release.',
    });
  } catch (error) {
    console.error('Create smart link error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/music/presave/links/:slug — public landing data
app.get('/v1/music/presave/links/:slug', async (req, res) => {
  try {
    const snap = await db.collection('music_smart_links').doc(req.params.slug).get();
    if (!snap.exists) return res.status(404).json({ error: 'Link not found' });
    const d = snap.data()!;
    res.json({
      slug: d.slug,
      title: d.title,
      artistName: d.artistName,
      artworkURL: d.artworkURL,
      releaseDate: d.releaseDate?.toDate().toISOString() || null,
      platforms: d.platforms,
      preSaveCount: d.preSaveCount || 0,
      isReleased: d.isReleased,
      url: `${SMART_LINK_BASE}/${d.slug}`,
    });
  } catch (error) {
    console.error('Get smart link error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/music/presave/links/:slug/presave — fan pre-saves (auth optional)
app.post('/v1/music/presave/links/:slug/presave', async (req, res) => {
  try {
    const { slug } = req.params;
    const { email, fanId } = req.body || {};
    if (!email && !fanId) {
      return res.status(400).json({ error: 'email or fanId is required' });
    }

    const linkRef = db.collection('music_smart_links').doc(slug);
    const linkSnap = await linkRef.get();
    if (!linkSnap.exists) return res.status(404).json({ error: 'Link not found' });

    const presaveId = fanId || Buffer.from(email).toString('base64url');
    const presaveRef = linkRef.collection('presaves').doc(presaveId);
    if ((await presaveRef.get()).exists) {
      return res.json({ slug, alreadyPresaved: true });
    }

    await presaveRef.set({
      fanId: fanId || null,
      email: email || null,
      presavedAt: admin.firestore.Timestamp.now(),
      fulfilled: false,
    });
    await linkRef.update({ preSaveCount: admin.firestore.FieldValue.increment(1) });

    res.status(201).json({ slug, presaved: true });
  } catch (error) {
    console.error('Pre-save error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/music/presave/links/:slug/release — flip to released, fulfill pre-saves
app.post('/v1/music/presave/links/:slug/release', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const linkRef = db.collection('music_smart_links').doc(req.params.slug);
    const linkSnap = await linkRef.get();
    if (!linkSnap.exists) return res.status(404).json({ error: 'Link not found' });
    if (String(linkSnap.data()!.artistId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const d = linkSnap.data()!;
    // Add the released track to each pre-saver's library.
    const presaves = await linkRef.collection('presaves').where('fulfilled', '==', false).get();
    const batch = db.batch();
    let fulfilled = 0;
    presaves.forEach((p) => {
      const fanId = p.data().fanId;
      if (fanId && d.trackId) {
        const libRef = db.collection('user_library').doc(fanId).collection('tracks').doc(d.trackId);
        batch.set(libRef, { trackId: d.trackId, addedAt: admin.firestore.Timestamp.now(), source: 'presave' });
        fulfilled++;
      }
      batch.update(p.ref, { fulfilled: true, fulfilledAt: admin.firestore.Timestamp.now() });
    });
    batch.update(linkRef, { isReleased: true, releasedAt: admin.firestore.Timestamp.now() });
    await batch.commit();

    res.json({ slug: req.params.slug, released: true, libraryAdds: fulfilled });
  } catch (error) {
    console.error('Release smart link error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Synced lyrics (LRC)
// ─────────────────────────────────────────────────────────────────────────────

/** Parse LRC text into [{ timeMs, text }] sorted by time. */
function parseLRC(lrc: string): { timeMs: number; text: string }[] {
  const lines = lrc.split(/\r?\n/);
  const out: { timeMs: number; text: string }[] = [];
  const tag = /\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]/g;
  for (const line of lines) {
    let m: RegExpExecArray | null;
    const text = line.replace(tag, '').trim();
    tag.lastIndex = 0;
    while ((m = tag.exec(line)) !== null) {
      const min = parseInt(m[1], 10);
      const sec = parseInt(m[2], 10);
      const frac = m[3] ? parseInt(m[3].padEnd(3, '0'), 10) : 0;
      out.push({ timeMs: (min * 60 + sec) * 1000 + frac, text });
    }
  }
  return out.sort((a, b) => a.timeMs - b.timeMs);
}

// PUT /v1/music/tracks/:trackId/synced-lyrics — store LRC + parsed timeline
app.put('/v1/music/tracks/:trackId/synced-lyrics', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { trackId } = req.params;
    const { lrc } = req.body || {};
    if (!lrc || typeof lrc !== 'string') {
      return res.status(400).json({ error: 'lrc (LRC-format text) is required' });
    }

    const trackRef = db.collection('music_tracks').doc(trackId);
    const trackSnap = await trackRef.get();
    if (!trackSnap.exists) return res.status(404).json({ error: 'Track not found' });
    if (String(trackSnap.data()!.artistId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const timeline = parseLRC(lrc);
    if (timeline.length === 0) {
      return res.status(400).json({ error: 'No timestamped lines found in LRC' });
    }

    await trackRef.update({
      lrc,
      syncedLyrics: timeline,
      hasSyncedLyrics: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({ trackId, lines: timeline.length, message: 'Synced lyrics saved' });
  } catch (error) {
    console.error('Save synced lyrics error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/music/tracks/:trackId/synced-lyrics — serve timeline for the player
app.get('/v1/music/tracks/:trackId/synced-lyrics', async (req, res) => {
  try {
    const snap = await db.collection('music_tracks').doc(req.params.trackId).get();
    if (!snap.exists) return res.status(404).json({ error: 'Track not found' });
    const d = snap.data()!;
    res.json({
      trackId: req.params.trackId,
      hasSyncedLyrics: !!d.hasSyncedLyrics,
      syncedLyrics: d.syncedLyrics || [],
      plainLyrics: d.lyrics || null,
    });
  } catch (error) {
    console.error('Get synced lyrics error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Cover-song mechanical licensing intake
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/music/tracks/:trackId/cover-license — declare a cover + original work
app.post('/v1/music/tracks/:trackId/cover-license', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { trackId } = req.params;
    const { originalTitle, originalArtist, originalWriters, originalISRC } = req.body || {};
    if (!originalTitle || !originalArtist) {
      return res.status(400).json({ error: 'originalTitle and originalArtist are required' });
    }

    const trackRef = db.collection('music_tracks').doc(trackId);
    const trackSnap = await trackRef.get();
    if (!trackSnap.exists) return res.status(404).json({ error: 'Track not found' });
    if (String(trackSnap.data()!.artistId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    await db.collection('music_cover_licenses').doc(trackId).set({
      trackId,
      artistId: user.userId,
      isCover: true,
      originalTitle,
      originalArtist,
      originalWriters: originalWriters || null,
      originalISRC: originalISRC || null,
      // Mechanical license status: artists must secure a mechanical license
      // (e.g. via MLC/HFA in the US) for covers. We track the request state.
      licenseStatus: 'pending',
      requestedAt: now,
    }, { merge: true });

    await trackRef.update({ isCover: true });

    res.status(201).json({
      trackId,
      licenseStatus: 'pending',
      message: 'Cover declared. A mechanical license is required before distribution to DSPs.',
    });
  } catch (error) {
    console.error('Cover license error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const PORT = process.env.PORT || 8091;
app.listen(PORT, () => {
  console.log(`🎵 Music presave/lyrics/licensing service listening on port ${PORT}`);
});
