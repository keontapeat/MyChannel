"use strict";
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
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.chromaprintFile = chromaprintFile;
exports.compareFingerprints = compareFingerprints;
exports.fingerprintHash = fingerprintHash;
exports.recognizeSample = recognizeSample;
exports.activeFingerprintProvider = activeFingerprintProvider;
const child_process_1 = require("child_process");
const crypto = __importStar(require("crypto"));
const PROVIDER = (process.env.FINGERPRINT_PROVIDER || 'chromaprint').toLowerCase();
/** Run fpcalc (Chromaprint) on a local audio file and parse raw fingerprint. */
function chromaprintFile(localPath) {
    return new Promise((resolve, reject) => {
        // -raw emits comma-separated 32-bit integers; -json gives duration too.
        const proc = (0, child_process_1.spawn)('fpcalc', ['-raw', '-json', localPath]);
        let out = '';
        let err = '';
        proc.stdout.on('data', (d) => (out += d.toString()));
        proc.stderr.on('data', (d) => (err += d.toString()));
        proc.on('error', reject);
        proc.on('close', (code) => {
            if (code !== 0)
                return reject(new Error(`fpcalc failed: ${err.slice(-300)}`));
            try {
                const parsed = JSON.parse(out);
                const frames = (parsed.fingerprint || '')
                    .toString()
                    .split(',')
                    .filter((s) => s.length > 0)
                    .map((s) => parseInt(s, 10) >>> 0);
                resolve({ algorithm: 'chromaprint', frames, duration: Number(parsed.duration) || 0 });
            }
            catch (e) {
                reject(e);
            }
        });
    });
}
/** Popcount of a 32-bit integer. */
function popcount32(x) {
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
function compareFingerprints(a, b) {
    if (!a.frames.length || !b.frames.length)
        return 0;
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
        if (similarity > best)
            best = similarity;
    }
    return best;
}
/** Stable short hash of a fingerprint for indexing/dedupe. */
function fingerprintHash(fp) {
    const h = crypto.createHash('sha256');
    h.update(fp.algorithm);
    h.update(Buffer.from(Int32Array.from(fp.frames).buffer));
    return h.digest('hex').slice(0, 32);
}
/** ACRCloud identify-by-sample. Expects a short audio sample buffer. */
async function recognizeACRCloud(sample) {
    var _a, _b, _c;
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
    const res = await fetch(`https://${host}${httpUri}`, { method: 'POST', body: form });
    const json = await res.json().catch(() => ({}));
    const music = (_b = (_a = json === null || json === void 0 ? void 0 : json.metadata) === null || _a === void 0 ? void 0 : _a.music) === null || _b === void 0 ? void 0 : _b[0];
    if (!music)
        return { matched: false, score: 0, provider: 'acrcloud' };
    return {
        matched: true,
        externalId: music.acrid,
        isrc: (_c = music.external_ids) === null || _c === void 0 ? void 0 : _c.isrc,
        title: music.title,
        artist: (music.artists || []).map((a) => a.name).join(', '),
        score: (music.score || 0) / 100,
        provider: 'acrcloud',
    };
}
/** Pex (PDS) recognition adapter. */
async function recognizePex(sample) {
    var _a;
    const base = process.env.PEX_API_BASE;
    const key = process.env.PEX_API_KEY;
    if (!base || !key)
        return { matched: false, score: 0, provider: 'pex' };
    const res = await fetch(`${base.replace(/\/$/, '')}/v1/identify`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/octet-stream' },
        body: sample,
    });
    const json = await res.json().catch(() => ({}));
    const m = (_a = json === null || json === void 0 ? void 0 : json.matches) === null || _a === void 0 ? void 0 : _a[0];
    if (!m)
        return { matched: false, score: 0, provider: 'pex' };
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
async function recognizeSample(sample) {
    if (PROVIDER === 'acrcloud')
        return recognizeACRCloud(sample);
    if (PROVIDER === 'pex')
        return recognizePex(sample);
    // chromaprint mode does local fingerprint matching, handled by the caller.
    return { matched: false, score: 0, provider: 'chromaprint' };
}
function activeFingerprintProvider() {
    return PROVIDER;
}
