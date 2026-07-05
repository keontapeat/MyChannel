/**
 * fingerprint.ts — Real perceptual video fingerprinting for Content ID.
 *
 * Closes the gap where general-video Content ID was simulated (random hashes,
 * character-set-overlap "similarity" — see the removed logic in
 * MyChannel/Core/Services/ContentIDService.swift). Music already has real
 * Content ID via Chromaprint audio fingerprinting (services/music/fingerprint.ts);
 * this does the equivalent for video frames using perceptual hashing (dHash),
 * which is the same family of technique YouTube's Content ID and Facebook's
 * PDQ hash use for visual matching — robust to re-encoding, minor cropping,
 * and bitrate changes, unlike a byte-level or character-overlap comparison.
 *
 * Pipeline:
 *   1. ffmpeg extracts N evenly-spaced frames from the video, downscaled to
 *      9×8 grayscale raw pixels (the standard dHash working size).
 *   2. Each frame becomes a 64-bit difference hash (dHash): compare each
 *      pixel to its right neighbor; 1 bit per comparison, 8 comparisons ×
 *      8 rows = 64 bits. Robust to scaling/compression artifacts because it
 *      encodes gradient direction, not absolute pixel values.
 *   3. A video fingerprint is the ordered sequence of per-frame hashes.
 *   4. Matching slides the shorter sequence across the longer one (same
 *      approach as the audio Chromaprint comparator) and scores by average
 *      normalized Hamming similarity across aligned frames — this finds a
 *      matching sub-clip even if the candidate is a trimmed excerpt of a
 *      longer reference video (or vice versa).
 *
 * No external service dependency — only the ffmpeg binary already required
 * by services/transcode and services/streaming.
 */

import { spawn } from 'child_process';
import * as crypto from 'crypto';

export interface VideoFingerprint {
  algorithm: 'dhash64';
  /** One 64-bit hash per sampled frame, ordered by timestamp. */
  frameHashes: string[]; // each entry is a 16-char hex string (64 bits)
  /** Seconds between sampled frames. */
  intervalSeconds: number;
  /** Total source duration in seconds (0 if unknown). */
  duration: number;
}

const DHASH_WIDTH = 9; // 9 columns → 8 horizontal gradient comparisons per row
const DHASH_HEIGHT = 8;
const DEFAULT_FRAME_COUNT = 32; // ~1 frame every few seconds for a typical upload

/**
 * Extracts [frameCount] evenly-spaced grayscale frames from a local video
 * file and computes a dHash for each. Requires ffmpeg on PATH.
 */
export function extractVideoFingerprint(
  localPath: string,
  durationSeconds: number,
  frameCount: number = DEFAULT_FRAME_COUNT
): Promise<VideoFingerprint> {
  return new Promise((resolve, reject) => {
    if (!durationSeconds || durationSeconds <= 0) {
      reject(new Error('extractVideoFingerprint requires a known positive duration'));
      return;
    }

    const intervalSeconds = durationSeconds / frameCount;
    // fps=1/intervalSeconds samples one frame every intervalSeconds; scale to
    // the dHash working resolution and force 8-bit grayscale raw output so we
    // can read fixed-size frames straight off stdout with no image decoding.
    const args = [
      '-i', localPath,
      '-vf', `fps=1/${intervalSeconds},scale=${DHASH_WIDTH}:${DHASH_HEIGHT}:flags=lanczos,format=gray`,
      '-f', 'rawvideo',
      '-pix_fmt', 'gray',
      '-vsync', '0',
      'pipe:1',
    ];

    const proc = spawn('ffmpeg', args);
    const chunks: Buffer[] = [];
    let stderr = '';
    proc.stdout.on('data', (d) => chunks.push(d));
    proc.stderr.on('data', (d) => (stderr += d.toString()));
    proc.on('error', reject);
    proc.on('close', (code) => {
      if (code !== 0 && chunks.length === 0) {
        reject(new Error(`ffmpeg failed: ${stderr.slice(-400)}`));
        return;
      }
      const raw = Buffer.concat(chunks);
      const frameSize = DHASH_WIDTH * DHASH_HEIGHT;
      const frameHashes: string[] = [];
      for (let offset = 0; offset + frameSize <= raw.length; offset += frameSize) {
        frameHashes.push(computeDHash(raw.subarray(offset, offset + frameSize)));
      }
      if (frameHashes.length === 0) {
        reject(new Error('No frames could be extracted from video'));
        return;
      }
      resolve({
        algorithm: 'dhash64',
        frameHashes,
        intervalSeconds,
        duration: durationSeconds,
      });
    });
  });
}

/**
 * Computes a 64-bit difference hash from a 9×8 grayscale pixel buffer.
 * Pure function — no I/O — so it's directly unit-testable without ffmpeg.
 */
export function computeDHash(pixels: Buffer): string {
  if (pixels.length !== DHASH_WIDTH * DHASH_HEIGHT) {
    throw new Error(`computeDHash expects a ${DHASH_WIDTH * DHASH_HEIGHT}-byte buffer, got ${pixels.length}`);
  }
  let bits = 0n;
  let bitIndex = 0n;
  for (let row = 0; row < DHASH_HEIGHT; row++) {
    for (let col = 0; col < DHASH_WIDTH - 1; col++) {
      const left = pixels[row * DHASH_WIDTH + col];
      const right = pixels[row * DHASH_WIDTH + col + 1];
      if (left > right) {
        bits |= (1n << bitIndex);
      }
      bitIndex += 1n;
    }
  }
  return bits.toString(16).padStart(16, '0');
}

/** Popcount for a hex-encoded 64-bit hash pair (used by hammingDistance64). */
function popcount64(x: bigint): number {
  let count = 0;
  let v = x;
  while (v > 0n) {
    v &= v - 1n;
    count++;
  }
  return count;
}

/** Hamming distance between two 64-bit dHash hex strings (0–64). */
export function hammingDistance64(hashA: string, hashB: string): number {
  const a = BigInt('0x' + hashA);
  const b = BigInt('0x' + hashB);
  return popcount64(a ^ b);
}

/**
 * Compares two video fingerprints and returns a similarity score 0..1.
 * Slides the shorter frame sequence across the longer one (same alignment
 * strategy as the audio Chromaprint comparator) to find the best-matching
 * sub-sequence, so a short clip lifted from a longer reference video still
 * scores highly. Scored by average normalized Hamming similarity (1 -
 * hammingDistance/64) across aligned frames at the best offset.
 */
export function compareVideoFingerprints(a: VideoFingerprint, b: VideoFingerprint): number {
  if (!a.frameHashes.length || !b.frameHashes.length) return 0;
  const [shortSeq, longSeq] = a.frameHashes.length <= b.frameHashes.length
    ? [a.frameHashes, b.frameHashes]
    : [b.frameHashes, a.frameHashes];

  const maxOffset = longSeq.length - shortSeq.length;
  let best = 0;
  for (let offset = 0; offset <= maxOffset; offset++) {
    let totalSimilarity = 0;
    for (let i = 0; i < shortSeq.length; i++) {
      const distance = hammingDistance64(shortSeq[i], longSeq[offset + i]);
      totalSimilarity += 1 - distance / 64;
    }
    const avg = totalSimilarity / shortSeq.length;
    if (avg > best) best = avg;
  }
  return best;
}

/** Stable hash of a fingerprint for indexing/dedupe. */
export function videoFingerprintHash(fp: VideoFingerprint): string {
  const h = crypto.createHash('sha256');
  h.update(fp.algorithm);
  h.update(fp.frameHashes.join(','));
  return h.digest('hex').slice(0, 32);
}

/** Serializes a fingerprint for Firestore storage (frame hashes as a single string). */
export function serializeFingerprint(fp: VideoFingerprint): Record<string, unknown> {
  return {
    algorithm: fp.algorithm,
    frameHashes: fp.frameHashes,
    intervalSeconds: fp.intervalSeconds,
    duration: fp.duration,
  };
}

/** Deserializes a fingerprint read back from Firestore. Returns null if malformed. */
export function deserializeFingerprint(data: unknown): VideoFingerprint | null {
  if (!data || typeof data !== 'object') return null;
  const d = data as Record<string, unknown>;
  if (!Array.isArray(d.frameHashes) || d.frameHashes.length === 0) return null;
  return {
    algorithm: 'dhash64',
    frameHashes: d.frameHashes.map((h) => String(h)),
    intervalSeconds: Number(d.intervalSeconds) || 0,
    duration: Number(d.duration) || 0,
  };
}
