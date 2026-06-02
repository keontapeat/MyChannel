/**
 * transcode.ts — Audio transcoding + HLS packaging for MyChannel Music.
 *
 * Turns an uploaded master (WAV/FLAC/MP3/M4A) into:
 *   • An adaptive HLS ladder (AAC 64/128/256 kbps) for smooth streaming.
 *   • A normalized MP3 320 fallback.
 *   • (Optional) a lossless FLAC for hi-res/lossless tiers (Apple/Tidal parity).
 *   • Loudness-normalized output (EBU R128 / -14 LUFS, streaming standard).
 *
 * Requires ffmpeg on the runtime. On Cloud Run use a Docker image that installs
 * ffmpeg (see Dockerfile.transcode). The function downloads the master from
 * Storage, runs ffmpeg, uploads renditions, and writes URLs back to the track.
 *
 * Env:
 *   MUSIC_BUCKET   GCS bucket (default mychannel-ca26d.appspot.com)
 *   ENABLE_LOSSLESS  "true" to also produce FLAC (default "true")
 */

import express from 'express';
import admin from 'firebase-admin';
import { Storage } from '@google-cloud/storage';
import { spawn } from 'child_process';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { chromaprintFile, fingerprintHash } from './fingerprint';

const app = express();
app.use(express.json({ limit: '10mb' }));

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'mychannel-ca26d',
  });
}

const db = admin.firestore();
const storage = new Storage();
const BUCKET = process.env.MUSIC_BUCKET || 'mychannel-ca26d.appspot.com';
const bucket = storage.bucket(BUCKET);
const ENABLE_LOSSLESS = (process.env.ENABLE_LOSSLESS || 'true') === 'true';

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

function run(cmd: string, args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    const proc = spawn(cmd, args);
    let stderr = '';
    proc.stderr.on('data', (d) => (stderr += d.toString()));
    proc.on('error', reject);
    proc.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${cmd} exited ${code}: ${stderr.slice(-500)}`));
    });
  });
}

/** Download a gs:// or https storage URL to a local temp file. */
async function downloadToTmp(storagePath: string, dest: string): Promise<void> {
  await bucket.file(storagePath).download({ destination: dest });
}

/** Convert a public/https storage URL into an in-bucket object path. */
function objectPathFromURL(url: string): string {
  // https://storage.googleapis.com/<bucket>/<path>  OR  firebase download URL
  const marker = `${BUCKET}/`;
  const idx = url.indexOf(marker);
  if (idx >= 0) return decodeURIComponent(url.slice(idx + marker.length).split('?')[0]);
  // /o/<path>?... style (Firebase)
  const oIdx = url.indexOf('/o/');
  if (oIdx >= 0) return decodeURIComponent(url.slice(oIdx + 3).split('?')[0]);
  return url;
}

// POST /v1/music/transcode/:trackId — produce HLS + fallbacks for a track
app.post('/v1/music/transcode/:trackId', async (req, res) => {
  const user = await requireUser(req, res);
  if (!user) return;

  const { trackId } = req.params;
  const trackRef = db.collection('music_tracks').doc(trackId);
  const trackSnap = await trackRef.get();
  if (!trackSnap.exists) return res.status(404).json({ error: 'Track not found' });

  const track = trackSnap.data()!;
  if (String(track.artistId || '') !== user.userId) {
    return res.status(403).json({ error: 'Forbidden' });
  }
  if (!track.audioURL) return res.status(400).json({ error: 'Track has no master audio' });

  const work = fs.mkdtempSync(path.join(os.tmpdir(), `mch_${trackId}_`));
  const masterLocal = path.join(work, 'master.input');

  try {
    await trackRef.update({ transcodingStatus: 'in_progress', transcodeStartedAt: admin.firestore.Timestamp.now() });

    const srcObject = objectPathFromURL(track.audioURL);
    await downloadToTmp(srcObject, masterLocal);

    const basePath = `music/${user.userId}/renditions/${trackId}`;
    const outputs: Record<string, string> = {};

    // Loudness normalization filter (streaming standard ~ -14 LUFS).
    const loudnorm = 'loudnorm=I=-14:TP=-1.0:LRA=11';

    // 1) HLS adaptive ladder: 3 AAC variants + master playlist.
    const hlsDir = path.join(work, 'hls');
    fs.mkdirSync(hlsDir, { recursive: true });
    const ladder = [
      { name: 'low', bitrate: '64k' },
      { name: 'mid', bitrate: '128k' },
      { name: 'high', bitrate: '256k' },
    ];
    for (const v of ladder) {
      await run('ffmpeg', [
        '-y', '-i', masterLocal,
        '-vn', '-af', loudnorm,
        '-c:a', 'aac', '-b:a', v.bitrate,
        '-hls_time', '6', '-hls_playlist_type', 'vod',
        '-hls_segment_filename', path.join(hlsDir, `${v.name}_%03d.aac`),
        path.join(hlsDir, `${v.name}.m3u8`),
      ]);
    }
    // Master playlist referencing the three variants.
    const masterM3U8 = [
      '#EXTM3U',
      '#EXT-X-VERSION:3',
      '#EXT-X-STREAM-INF:BANDWIDTH=72000,CODECS="mp4a.40.2"',
      'low.m3u8',
      '#EXT-X-STREAM-INF:BANDWIDTH=140000,CODECS="mp4a.40.2"',
      'mid.m3u8',
      '#EXT-X-STREAM-INF:BANDWIDTH=272000,CODECS="mp4a.40.2"',
      'high.m3u8',
    ].join('\n');
    fs.writeFileSync(path.join(hlsDir, 'master.m3u8'), masterM3U8);

    // Upload the whole HLS directory.
    for (const file of fs.readdirSync(hlsDir)) {
      const dest = `${basePath}/hls/${file}`;
      await bucket.upload(path.join(hlsDir, file), {
        destination: dest,
        contentType: file.endsWith('.m3u8') ? 'application/vnd.apple.mpegurl' : 'audio/aac',
      });
    }
    outputs.hls = `https://storage.googleapis.com/${BUCKET}/${basePath}/hls/master.m3u8`;

    // 2) MP3 320 fallback (normalized).
    const mp3Local = path.join(work, 'fallback.mp3');
    await run('ffmpeg', ['-y', '-i', masterLocal, '-vn', '-af', loudnorm, '-c:a', 'libmp3lame', '-b:a', '320k', mp3Local]);
    await bucket.upload(mp3Local, { destination: `${basePath}/audio_320.mp3`, contentType: 'audio/mpeg' });
    outputs.mp3 = `https://storage.googleapis.com/${BUCKET}/${basePath}/audio_320.mp3`;

    // 3) Optional lossless FLAC (hi-res / lossless tier).
    if (ENABLE_LOSSLESS) {
      const flacLocal = path.join(work, 'lossless.flac');
      await run('ffmpeg', ['-y', '-i', masterLocal, '-vn', '-c:a', 'flac', flacLocal]);
      await bucket.upload(flacLocal, { destination: `${basePath}/lossless.flac`, contentType: 'audio/flac' });
      outputs.flac = `https://storage.googleapis.com/${BUCKET}/${basePath}/lossless.flac`;
    }

    // Probe duration so the catalog has accurate length.
    let duration = track.duration || 0;
    try {
      const probe = await new Promise<string>((resolve, reject) => {
        const p = spawn('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'default=nw=1:nk=1', masterLocal]);
        let out = '';
        p.stdout.on('data', (d) => (out += d.toString()));
        p.on('error', reject);
        p.on('close', () => resolve(out.trim()));
      });
      if (probe) duration = parseFloat(probe);
    } catch { /* keep existing duration */ }

    // Compute a REAL chromaprint fingerprint from the master and register it in
    // Content ID so this track is protected and can be matched against uploads.
    let fingerprintRegistered = false;
    try {
      const fp = await chromaprintFile(masterLocal);
      if (fp.frames.length > 0) {
        await db.collection('music_content_id').doc(trackId).set({
          trackId,
          artistId: user.userId,
          fingerprint: fp,
          fingerprintHash: fingerprintHash(fp),
          fingerprintProvider: 'chromaprint',
          registeredAt: admin.firestore.Timestamp.now(),
          status: 'active',
          copyrightPolicy: track.contentIdPolicy || 'strict',
          revenueSharePercentage: null,
          source: 'transcode_auto',
        }, { merge: true });
        fingerprintRegistered = true;
      }
    } catch (e: any) {
      console.warn(`Fingerprint skipped for ${trackId}: ${e.message}`);
    }

    await trackRef.update({
      transcodingStatus: 'completed',
      transcodeCompletedAt: admin.firestore.Timestamp.now(),
      hlsURL: outputs.hls,
      streamURL: outputs.hls, // app plays HLS by default
      mp3URL: outputs.mp3,
      losslessURL: outputs.flac || null,
      hasLossless: !!outputs.flac,
      contentIdRegistered: fingerprintRegistered,
      duration,
      renditions: outputs,
    });

    res.json({ trackId, status: 'completed', renditions: outputs, duration, fingerprintRegistered });
  } catch (error: any) {
    console.error('Transcode error:', error);
    await trackRef.update({ transcodingStatus: 'error', transcodeError: error.message }).catch(() => {});
    res.status(500).json({ error: error.message || 'Transcode failed' });
  } finally {
    fs.rmSync(work, { recursive: true, force: true });
  }
});

// GET /v1/music/transcode/:trackId/status
app.get('/v1/music/transcode/:trackId/status', async (req, res) => {
  const { trackId } = req.params;
  const snap = await db.collection('music_tracks').doc(trackId).get();
  if (!snap.exists) return res.status(404).json({ error: 'Track not found' });
  const t = snap.data()!;
  res.json({
    trackId,
    transcodingStatus: t.transcodingStatus || 'pending',
    hlsURL: t.hlsURL || null,
    mp3URL: t.mp3URL || null,
    losslessURL: t.losslessURL || null,
    hasLossless: !!t.hasLossless,
  });
});

const PORT = process.env.PORT || 8090;
app.listen(PORT, () => {
  console.log(`🎵 Music transcode service listening on port ${PORT} (lossless=${ENABLE_LOSSLESS})`);
});
