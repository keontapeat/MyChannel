import express from 'express';
import admin from 'firebase-admin';
import crypto from 'crypto';
import { Storage } from '@google-cloud/storage';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import {
  Fingerprint,
  compareFingerprints,
  fingerprintHash,
  activeFingerprintProvider,
  chromaprintFile,
} from './fingerprint';

const app = express();
app.use(express.json({ limit: '10mb' }));

// Match threshold: normalized Hamming similarity above this counts as a match.
const MATCH_THRESHOLD = parseFloat(process.env.CONTENT_ID_MATCH_THRESHOLD || '0.92');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'mychannel-ca26d'
  });
}

const db = admin.firestore();
const storage = new Storage();
const BUCKET = process.env.MUSIC_BUCKET || 'mychannel-ca26d.appspot.com';
const bucket = storage.bucket(BUCKET);

/** Convert a public/https storage URL into an in-bucket object path (mirrors transcode.ts). */
function objectPathFromURL(url: string): string {
  const marker = `${BUCKET}/`;
  const idx = url.indexOf(marker);
  if (idx >= 0) return decodeURIComponent(url.slice(idx + marker.length).split('?')[0]);
  const oIdx = url.indexOf('/o/');
  if (oIdx >= 0) return decodeURIComponent(url.slice(oIdx + 3).split('?')[0]);
  return url;
}

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
// Phase 6: Revolutionary Content ID System (YouTube Killer Feature)
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/music/content-id/register - Register track fingerprint in Content ID database
app.post('/v1/music/content-id/register', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { trackId, fingerprint } = req.body || {};

    if (!trackId || typeof trackId !== 'string') {
      return res.status(400).json({ error: 'trackId is required' });
    }

    // Accept a structured chromaprint fingerprint { algorithm, frames, duration }
    // or a provider externalId. Reject the old opaque-string format.
    if (!fingerprint || typeof fingerprint !== 'object' || !Array.isArray(fingerprint.frames)) {
      return res.status(400).json({
        error: 'fingerprint must be an object: { algorithm, frames:number[], duration }',
      });
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

    const fp: Fingerprint = {
      algorithm: fingerprint.algorithm || 'chromaprint',
      frames: fingerprint.frames.map((n: any) => (Number(n) >>> 0)),
      duration: Number(fingerprint.duration) || trackData.duration || 0,
      externalId: fingerprint.externalId,
    };

    const now = admin.firestore.Timestamp.now();
    const contentIdRef = db.collection('music_content_id').doc(trackId);

    await contentIdRef.set({
      trackId,
      artistId: user.userId,
      fingerprint: fp,
      fingerprintHash: fingerprintHash(fp),
      fingerprintProvider: activeFingerprintProvider(),
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
  } catch (error) {
    console.error('Content ID registration error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/music/content-id/register-from-url - Register a track's fingerprint
// by downloading its already-uploaded audio and running Chromaprint server-side.
// This is the endpoint iOS calls (it has no client-side fingerprinting) —
// /v1/music/content-id/register above is for callers that already computed
// a structured fingerprint themselves.
app.post('/v1/music/content-id/register-from-url', async (req, res) => {
  let tempPath: string | null = null;
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { trackId, audioURL } = req.body || {};
    if (!trackId || typeof trackId !== 'string') {
      return res.status(400).json({ error: 'trackId is required' });
    }
    if (!audioURL || typeof audioURL !== 'string') {
      return res.status(400).json({ error: 'audioURL is required' });
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

    const objectPath = objectPathFromURL(audioURL);
    const ext = path.extname(objectPath) || '.m4a';
    tempPath = path.join(os.tmpdir(), `contentid-${trackId}-${Date.now()}${ext}`);
    await bucket.file(objectPath).download({ destination: tempPath });

    const fp = await chromaprintFile(tempPath);
    if (!fp.duration) fp.duration = trackData.duration || 0;

    const now = admin.firestore.Timestamp.now();
    await db.collection('music_content_id').doc(trackId).set({
      trackId,
      artistId: user.userId,
      fingerprint: fp,
      fingerprintHash: fingerprintHash(fp),
      fingerprintProvider: activeFingerprintProvider(),
      registeredAt: now,
      status: 'active',
      copyrightPolicy: 'strict',
      revenueSharePercentage: null,
    }, { merge: true });

    await trackRef.update({ contentIdRegistered: true, contentIdRegisteredAt: now });

    res.json({
      referenceId: trackId,
      trackId,
      status: 'registered',
      copyrightPolicy: 'strict',
      frameCount: fp.frames.length,
    });
  } catch (error: any) {
    console.error('Content ID register-from-url error:', error);
    res.status(500).json({ error: error?.message || 'Internal server error' });
  } finally {
    if (tempPath) await fs.promises.rm(tempPath, { force: true }).catch(() => {});
  }
});

// PUT /v1/music/tracks/:trackId/copyright-policy - Set artist's copyright policy
app.put('/v1/music/tracks/:trackId/copyright-policy', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

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

    const trackData = trackSnap.data()!;

    if (String(trackData.artistId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
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
  } catch (error) {
    console.error('Set copyright policy error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/music/tracks/:trackId/copyright-policy - Get current copyright policy
app.get('/v1/music/tracks/:trackId/copyright-policy', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { trackId } = req.params;

    const trackRef = db.collection('music_tracks').doc(trackId);
    const trackSnap = await trackRef.get();

    if (!trackSnap.exists) {
      return res.status(404).json({ error: 'Track not found' });
    }

    const trackData = trackSnap.data()!;

    if (String(trackData.artistId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const contentIdRef = db.collection('music_content_id').doc(trackId);
    const contentIdSnap = await contentIdRef.get();

    if (!contentIdSnap.exists) {
      return res.status(404).json({ error: 'Content ID not registered for this track' });
    }

    const contentIdData = contentIdSnap.data()!;

    res.json({
      trackId,
      copyrightPolicy: contentIdData.copyrightPolicy || 'strict',
      revenueSharePercentage: contentIdData.revenueSharePercentage,
      registeredAt: contentIdData.registeredAt?.toDate().toISOString(),
      policyUpdatedAt: contentIdData.policyUpdatedAt?.toDate().toISOString() || null
    });
  } catch (error) {
    console.error('Get copyright policy error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/music/artists/:artistId/default-copyright-policy - Set default policy for all tracks
app.put('/v1/music/artists/:artistId/default-copyright-policy', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { artistId } = req.params;
    const { policy, revenueSharePercentage } = req.body || {};

    if (user.userId !== artistId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const validPolicies = ['strict', 'monetize', 'allow'];
    if (!policy || !validPolicies.includes(policy)) {
      return res.status(400).json({ error: `policy must be one of: ${validPolicies.join(', ')}` });
    }

    const now = admin.firestore.Timestamp.now();
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
  } catch (error) {
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

    // audioFingerprint must be a structured chromaprint fingerprint.
    if (!audioFingerprint || typeof audioFingerprint !== 'object' || !Array.isArray(audioFingerprint.frames)) {
      return res.status(400).json({
        error: 'audioFingerprint must be { algorithm, frames:number[], duration }',
      });
    }

    const candidate: Fingerprint = {
      algorithm: audioFingerprint.algorithm || 'chromaprint',
      frames: audioFingerprint.frames.map((n: any) => (Number(n) >>> 0)),
      duration: Number(audioFingerprint.duration) || 0,
    };

    // Compare against the active Content ID reference database using real
    // normalized Hamming similarity over chromaprint sub-fingerprints.
    const contentIdSnap = await db.collection('music_content_id')
      .where('status', '==', 'active')
      .limit(2000)
      .get();

    const matches: any[] = [];
    contentIdSnap.docs.forEach(doc => {
      const data = doc.data();
      const refFp = data.fingerprint as Fingerprint | undefined;
      if (!refFp || !Array.isArray(refFp.frames) || refFp.frames.length === 0) return;

      const similarity = compareFingerprints(candidate, refFp);
      if (similarity >= MATCH_THRESHOLD) {
        matches.push({
          trackId: data.trackId,
          artistId: data.artistId,
          copyrightPolicy: data.copyrightPolicy,
          revenueSharePercentage: data.revenueSharePercentage,
          similarity: (similarity * 100).toFixed(1),
        });
      }
    });

    // Keep the strongest matches first.
    matches.sort((a, b) => parseFloat(b.similarity) - parseFloat(a.similarity));

    // Process matches based on copyright policy
    const enforcementResults = matches.map(match => {
      let action = 'none';
      let reason = '';

      if (match.copyrightPolicy === 'strict') {
        action = 'copyright_strike';
        reason = 'Unauthorized usage - copyright strike issued';
      } else if (match.copyrightPolicy === 'monetize') {
        action = 'revenue_share';
        reason = `Revenue sharing enabled - artist gets ${match.revenueSharePercentage}%`;
      } else if (match.copyrightPolicy === 'allow') {
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
      scannedAt: admin.firestore.Timestamp.now()
    });

    res.json({
      videoId,
      matchesFound: matches.length,
      matches,
      enforcementResults,
      scanId: scanRef.id
    });
  } catch (error) {
    console.error('Scan video error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/music/content-id/video/:videoId/matches - Get music matches in video
app.get('/v1/music/content-id/video/:videoId/matches', async (req, res) => {
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

    const scanData = scansSnap.docs[0].data()!;

    res.json({
      videoId,
      scanId: scanData.id,
      matchesFound: scanData.matches.length,
      matches: scanData.matches,
      enforcementResults: scanData.enforcementResults,
      scannedAt: scanData.scannedAt?.toDate().toISOString()
    });
  } catch (error) {
    console.error('Get video matches error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/music/content-id/:matchId/set-revenue-share - Artist sets revenue %
app.post('/v1/music/content-id/:matchId/set-revenue-share', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

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

    const scanData = scanSnap.data()!;
    const match = scanData.matches.find((m: any) => m.artistId === user.userId);

    if (!match) {
      return res.status(403).json({ error: 'No match found for this artist' });
    }

    // Update the match with new revenue share
    const updatedMatches = scanData.matches.map((m: any) => {
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
    const updatedEnforcement = updatedMatches.map((m: any) => ({
      ...m,
      action: m.copyrightPolicy === 'monetize' ? 'revenue_share' : m.action,
      reason: m.copyrightPolicy === 'monetize' ? `Revenue sharing enabled - artist gets ${revenueSharePercentage}%` : m.reason
    }));

    await scanRef.update({
      matches: updatedMatches,
      enforcementResults: updatedEnforcement,
      updatedAt: admin.firestore.Timestamp.now()
    });

    res.json({
      matchId,
      revenueSharePercentage,
      message: `Revenue share updated to ${revenueSharePercentage}%`
    });
  } catch (error) {
    console.error('Set revenue share error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/music/content-id/:matchId/revenue - Track revenue from video usage
app.get('/v1/music/content-id/:matchId/revenue', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { matchId } = req.params;

    const scanRef = db.collection('music_content_id_scans').doc(matchId);
    const scanSnap = await scanRef.get();

    if (!scanSnap.exists) {
      return res.status(404).json({ error: 'Scan not found' });
    }

    const scanData = scanSnap.data()!;
    const match = scanData.matches.find((m: any) => m.artistId === user.userId);

    if (!match) {
      return res.status(403).json({ error: 'No match found for this artist' });
    }

    if (match.copyrightPolicy !== 'monetize') {
      return res.status(400).json({ error: 'This match is not set to revenue sharing' });
    }

    // Real revenue: sum ad revenue actually attributed to this video, then apply
    // the artist's agreed share. Revenue is written by the ads pipeline into
    // `video_ad_revenue/{videoId}` as { totalRevenue }.
    const adRevSnap = await db.collection('video_ad_revenue').doc(scanData.videoId).get();
    const videoRevenue = adRevSnap.exists ? (adRevSnap.data()!.totalRevenue || 0) : 0;
    const sharePct = match.revenueSharePercentage || 50;
    const artistRevenue = videoRevenue * sharePct / 100;

    res.json({
      matchId,
      trackId: match.trackId,
      videoRevenue,
      artistRevenue,
      revenueSharePercentage: sharePct,
      message: `Artist earned $${artistRevenue.toFixed(2)} from this video usage`
    });
  } catch (error) {
    console.error('Get revenue error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/music/content-id/:matchId/issue-strike - Manually issue copyright strike
app.post('/v1/music/content-id/:matchId/issue-strike', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { matchId } = req.params;

    const scanRef = db.collection('music_content_id_scans').doc(matchId);
    const scanSnap = await scanRef.get();

    if (!scanSnap.exists) {
      return res.status(404).json({ error: 'Scan not found' });
    }

    const scanData = scanSnap.data()!;
    const match = scanData.matches.find((m: any) => m.artistId === user.userId);

    if (!match) {
      return res.status(403).json({ error: 'No match found for this artist' });
    }

    const now = admin.firestore.Timestamp.now();

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
  } catch (error) {
    console.error('Issue strike error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/music/content-id/:matchId/resolve-strike - Artist resolves strike (allows usage)
app.post('/v1/music/content-id/:matchId/resolve-strike', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { matchId } = req.params;

    const scanRef = db.collection('music_content_id_scans').doc(matchId);
    const scanSnap = await scanRef.get();

    if (!scanSnap.exists) {
      return res.status(404).json({ error: 'Scan not found' });
    }

    const scanData = scanSnap.data()!;
    const match = scanData.matches.find((m: any) => m.artistId === user.userId);

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

    const now = admin.firestore.Timestamp.now();
    await strikesSnap.docs[0].ref.update({
      status: 'resolved',
      resolvedAt: now
    });

    res.json({
      message: 'Copyright strike resolved - usage permitted'
    });
  } catch (error) {
    console.error('Resolve strike error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/music/artists/:artistId/content-id/overview - Overview of matches, strikes, revenue
app.get('/v1/music/artists/:artistId/content-id/overview', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

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
    const matchesByPolicy: Record<string, number> = { strict: 0, monetize: 0, allow: 0 };
    const monetizedVideoIds = new Set<string>();

    scansSnap.docs.forEach(doc => {
      const data = doc.data();
      data.matches.forEach((match: any) => {
        if (match.artistId === artistId) {
          totalMatches++;
          matchesByPolicy[match.copyrightPolicy] = (matchesByPolicy[match.copyrightPolicy] || 0) + 1;
          if (match.copyrightPolicy === 'monetize' && data.videoId) {
            monetizedVideoIds.add(JSON.stringify({ v: data.videoId, p: match.revenueSharePercentage || 50 }));
          }
        }
      });
    });

    // Real revenue: sum attributed ad revenue for each monetized video × share.
    for (const entry of monetizedVideoIds) {
      const { v, p } = JSON.parse(entry);
      const adRevSnap = await db.collection('video_ad_revenue').doc(v).get();
      const videoRevenue = adRevSnap.exists ? (adRevSnap.data()!.totalRevenue || 0) : 0;
      totalRevenue += videoRevenue * (p / 100);
    }

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
  } catch (error) {
    console.error('Content ID overview error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const PORT = process.env.PORT || 8083;
app.listen(PORT, () => {
  console.log(`🎵 Music Content ID service (${activeFingerprintProvider()}, threshold=${MATCH_THRESHOLD}) listening on port ${PORT}`);
});
