// Unit tests for the perceptual video fingerprinting math (fingerprint.ts).
// These test the pure functions only (computeDHash, hammingDistance64,
// compareVideoFingerprints, serialize/deserialize) — no ffmpeg required, so
// they run anywhere Node runs, same philosophy as services/ads/test/*.test.mjs.
//
// Run with: node --loader tsx video-content-id/test/fingerprint.test.mjs
// (or via tsx directly: npx tsx video-content-id/test/fingerprint.test.mjs)

import assert from 'assert';
import {
  computeDHash,
  hammingDistance64,
  compareVideoFingerprints,
  videoFingerprintHash,
  serializeFingerprint,
  deserializeFingerprint,
} from '../fingerprint.ts';

let pass = 0;
function ok(name, condition) {
  assert.ok(condition, name);
  console.log('  ✓ ' + name);
  pass++;
}

// ── computeDHash ────────────────────────────────────────────────────────────

// 9x8 buffer, all identical pixel values → every gradient comparison is
// "not greater", so the hash should be all zero bits.
const flatFrame = Buffer.alloc(9 * 8, 128);
ok('flat/uniform frame hashes to all-zero bits', computeDHash(flatFrame) === '0000000000000000');

// A frame with a clean left-to-right descending gradient in every row should
// set every comparison bit (each pixel is greater than its right neighbor).
const descendingFrame = Buffer.alloc(9 * 8);
for (let row = 0; row < 8; row++) {
  for (let col = 0; col < 9; col++) {
    descendingFrame[row * 9 + col] = 255 - col * 20; // strictly decreasing across the row
  }
}
ok('strictly descending gradient sets all 64 bits', computeDHash(descendingFrame) === 'ffffffffffffffff');

// Wrong buffer size should throw rather than silently producing a bad hash.
let threw = false;
try {
  computeDHash(Buffer.alloc(10));
} catch {
  threw = true;
}
ok('computeDHash rejects a wrong-size buffer', threw);

// ── hammingDistance64 ───────────────────────────────────────────────────────

ok('identical hashes have zero distance', hammingDistance64('0000000000000000', '0000000000000000') === 0);
ok('fully opposite hashes have max distance', hammingDistance64('0000000000000000', 'ffffffffffffffff') === 64);
ok('single-bit difference has distance 1', hammingDistance64('0000000000000000', '0000000000000001') === 1);

// ── compareVideoFingerprints ────────────────────────────────────────────────

const identicalFp = { algorithm: 'dhash64', frameHashes: ['0000000000000000', 'ffffffffffffffff', '00000000ffffffff'], intervalSeconds: 1, duration: 3 };
ok('identical fingerprints score a perfect 1.0', compareVideoFingerprints(identicalFp, identicalFp) === 1);

const oppositeFp = { algorithm: 'dhash64', frameHashes: ['ffffffffffffffff', '0000000000000000', 'ffffffff00000000'], intervalSeconds: 1, duration: 3 };
ok('fully opposite fingerprints score 0.0', compareVideoFingerprints(identicalFp, oppositeFp) === 0);

// A short clip that is an exact sub-sequence of a longer reference should
// still score 1.0 at the correctly-aligned offset (this is the "trimmed
// excerpt of a longer video" case the sliding-window alignment exists for).
const longFp = {
  algorithm: 'dhash64',
  frameHashes: ['1111111111111111', '2222222222222222', '3333333333333333', '4444444444444444', '5555555555555555'],
  intervalSeconds: 1,
  duration: 5,
};
const clipFp = {
  algorithm: 'dhash64',
  frameHashes: ['3333333333333333', '4444444444444444'],
  intervalSeconds: 1,
  duration: 2,
};
ok('a trimmed sub-clip aligns and scores a perfect match against its source', compareVideoFingerprints(longFp, clipFp) === 1);

ok('empty fingerprints score 0 rather than throwing', compareVideoFingerprints({ algorithm: 'dhash64', frameHashes: [], intervalSeconds: 1, duration: 0 }, identicalFp) === 0);

// ── videoFingerprintHash ────────────────────────────────────────────────────

ok('fingerprint hash is deterministic for the same input', videoFingerprintHash(identicalFp) === videoFingerprintHash(identicalFp));
ok('fingerprint hash differs for different frame sequences', videoFingerprintHash(identicalFp) !== videoFingerprintHash(longFp));

// ── serialize / deserialize round-trip ──────────────────────────────────────

const roundTripped = deserializeFingerprint(serializeFingerprint(longFp));
ok('serialize→deserialize round-trips frameHashes exactly', JSON.stringify(roundTripped.frameHashes) === JSON.stringify(longFp.frameHashes));
ok('serialize→deserialize preserves duration', roundTripped.duration === longFp.duration);
ok('deserializeFingerprint rejects malformed data instead of throwing', deserializeFingerprint({ nonsense: true }) === null);
ok('deserializeFingerprint rejects null', deserializeFingerprint(null) === null);

console.log('\nALL VIDEO CONTENT-ID FINGERPRINT TESTS PASSED (' + pass + ')');
