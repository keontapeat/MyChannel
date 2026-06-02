/**
 * fingerprint.ts — Real audio fingerprinting for Content ID.
 *
 * Two modes (set FINGERPRINT_PROVIDER):
 *   • "acrcloud" / "pex" — production-grade external recognition. The provider
 *     identifies a track from a sample and returns the matched ISRC/ID. Best
 *     accuracy; requires an account + keys.
 *   • "chromaprint" (default) — self-hosted. Uses fpcalc (Chromaprint) to compute
 *     an acoustic fingerprint, stored as a compact sub-fingerprint array. Matching
 *     compares candidate fingerprints by normalized Hamming similarity over the
 *     32-bit sub-fingerprint frames. No external dependency beyond the fpcalc
 *     binary (install: apt-get install -y libchromaprint-tools).
 *
 * This replaces the previous Math.random() simulation with deterministic,
 * explainable matching.
 *
 * Env:
 *   FINGERPRINT_PROVIDER   "chromaprint" | "acrcloud" | "pex"
 *   ACRCLOUD_HOST / ACRCLOUD_ACCESS_KEY / ACRCLOUD_ACCESS_SECRET
 *   PEX_API_BASE / PEX_API_KEY
 */

import { spawn } from 'child_process';
import * as crypto from 'crypto';

const PROVIDER = (process.env.FINGERPRINT_PROVIDER || 'chromaprint').toLowerCase();

export interface Fingerprint {
  algorithm: string;
  // For chromaprint: array of 32-bit integers (sub-fingerprint frames).
  frames: number[];
  // Duration in seconds (used to weight matches).
  duration: number;
  // Provider-native id (e.g. ACRCloud track id) when available.
  externalId?: string;
}

/** Run fpcalc (Chromaprint) on a local audio file and parse raw fingerprint. */
export function chromaprintFile(localPath: string): Promise<Fingerprint> {
  return new Promise((resolve, reject) => {
    // -raw emits comma-separated 32-bit integers; -json gives duration too.
    const proc = spawn('fpcalc', ['-raw', '-json', localPath]);
    let out = '';
    let err = '';
    proc.stdout.on('data', (d) => (out += d.toString()));
    proc.stderr.on('data', (d) => (err += d.toString()));
    proc.on('error', reject);
    proc.on('close', (code) => {
      if (code !== 0) return reject(new Error(`fpcalc failed: ${err.slice(-300)}`));
      try {
        const parsed = JSON.parse(out);
        const frames: number[] = (parsed.fingerprint || '')
          .toString()
          .split(',')
          .filter((s: string) => s.length > 0)
          .map((s: string) => parseInt(s, 10) >>> 0);
        resolve({ algorithm: 'chromaprint', frames, duration: Number(parsed.duration) || 0 });
      } catch (e) {
        reject(e);
      }
    });
  });
}

/** Popcount of a 32-bit integer. */
function popcount32(x: number): number {
  x = x - ((x >>> 1) & 0x55555555);
  x = (x & 0x33333333) + ((x >>> 2) & 0x33333333);
  x = (x + (x >>> 4)) & 0x0f0f0f0f;
  return (x * 0x01010101) >>> 24;
}

/**
 * Compare two chromaprint fingerprints. Returns a similarity score 0..1.
 * Slides the shorter fingerprint across the longer to find the best alignment,
 * scoring 1 - (normalized Hamming distance over aligned frames).
 */
export function compareFingerprints(a: Fingerprint, b: Fingerprint): number {
  if (!a.frames.length || !b.frames.length) return 0;
  const [shortFp, longFp] = a.frames.length <= b.frames.length ? [a.frames, b.frames] : [b.frames, a.frames];
  const maxOffset = longFp.length - shortFp.length;
  // Limit offsets scanned for performance on long tracks.
  const step = Math.max(1, Math.floor(maxOffset / 200) || 1);
  let best = 0;

  for (let offset = 0; offset <= maxOffset; offset += step) {
    let bitErrors = 0;
    const bitsCompared = shortFp.length * 32;
    for (let i = 0; i < shortFp.length; i++) {
      bitErrors += popcount32((shortFp[i] ^ longFp[offset + i]) >>> 0);
    }
    const similarity = 1 - bitErrors / bitsCompared;
    if (similarity > best) best = similarity;
  }
  return best;
}

/** Stable short hash of a fingerprint for indexing/dedupe. */
export function fingerprintHash(fp: Fingerprint): string {
  const h = crypto.createHash('sha256');
  h.update(fp.algorithm);
  h.update(Buffer.from(Int32Array.from(fp.frames).buffer));
  return h.digest('hex').slice(0, 32);
}

// ─────────────────────────────────────────────────────────────────────────────
// External provider recognition (ACRCloud / Pex)
// ─────────────────────────────────────────────────────────────────────────────

export interface RecognitionResult {
  matched: boolean;
  externalId?: string;
  isrc?: string;
  title?: string;
  artist?: string;
  score: number; // 0..1
  provider: string;
}

/** ACRCloud identify-by-sample. Expects a short audio sample buffer. */
async function recognizeACRCloud(sample: Buffer): Promise<RecognitionResult> {
  const host = process.env.ACRCLOUD_HOST;
  const accessKey = process.env.ACRCLOUD_ACCESS_KEY;
  const accessSecret = process.env.ACRCLOUD_ACCESS_SECRET;
  if (!host || !accessKey || !accessSecret) {
    return { matched: false, score: 0, provider: 'acrcloud' };
  }

  const httpMethod = 'POST';
  const httpUri = '/v1/identify';
  const dataType = 'audio';
  const signatureVersion = '1';
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const stringToSign = [httpMethod, httpUri, accessKey, dataType, signatureVersion, timestamp].join('\n');
  const signature = crypto.createHmac('sha1', accessSecret).update(Buffer.from(stringToSign, 'utf-8')).digest('base64');

  const form = new FormData();
  form.append('access_key', accessKey);
  form.append('data_type', dataType);
  form.append('signature_version', signatureVersion);
  form.append('signature', signature);
  form.append('timestamp', timestamp);
  form.append('sample_bytes', String(sample.length));
  form.append('sample', new Blob([sample]), 'sample');

  const res = await fetch(`https://${host}${httpUri}`, { method: 'POST', body: form as any });
  const json: any = await res.json().catch(() => ({}));
  const music = json?.metadata?.music?.[0];
  if (!music) return { matched: false, score: 0, provider: 'acrcloud' };

  return {
    matched: true,
    externalId: music.acrid,
    isrc: music.external_ids?.isrc,
    title: music.title,
    artist: (music.artists || []).map((a: any) => a.name).join(', '),
    score: (music.score || 0) / 100,
    provider: 'acrcloud',
  };
}

/** Pex (PDS) recognition adapter. */
async function recognizePex(sample: Buffer): Promise<RecognitionResult> {
  const base = process.env.PEX_API_BASE;
  const key = process.env.PEX_API_KEY;
  if (!base || !key) return { matched: false, score: 0, provider: 'pex' };

  const res = await fetch(`${base.replace(/\/$/, '')}/v1/identify`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/octet-stream' },
    body: sample,
  });
  const json: any = await res.json().catch(() => ({}));
  const m = json?.matches?.[0];
  if (!m) return { matched: false, score: 0, provider: 'pex' };
  return {
    matched: true,
    externalId: m.assetId,
    isrc: m.isrc,
    title: m.title,
    artist: m.artist,
    score: m.confidence || 0,
    provider: 'pex',
  };
}

export async function recognizeSample(sample: Buffer): Promise<RecognitionResult> {
  if (PROVIDER === 'acrcloud') return recognizeACRCloud(sample);
  if (PROVIDER === 'pex') return recognizePex(sample);
  // chromaprint mode does local fingerprint matching, handled by the caller.
  return { matched: false, score: 0, provider: 'chromaprint' };
}

export function activeFingerprintProvider(): string {
  return PROVIDER;
}
