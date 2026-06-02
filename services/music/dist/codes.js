"use strict";
/**
 * codes.ts — Real ISRC and UPC/EAN allocation for MyChannel Music.
 *
 * ISRC format: CC-XXX-YY-NNNNN
 *   CC    = ISO country code of the registrant (e.g. "US")
 *   XXX   = registrant code assigned by your national ISRC agency / IFPI
 *   YY    = year of reference (2 digits)
 *   NNNNN = 5-digit designation, unique per registrant per year
 *
 * UPC/EAN: 13-digit GS1 barcode with check digit. Requires a GS1 company prefix.
 *
 * IMPORTANT: You must obtain a real ISRC registrant code (from usisrc.org in the
 * US, or your national IFPI agency) and a GS1 company prefix. Set them via env:
 *   ISRC_COUNTRY        e.g. "US"
 *   ISRC_REGISTRANT     e.g. "MCH"  (3 chars)  ← REPLACE with your assigned code
 *   GS1_COMPANY_PREFIX  e.g. "0850001"          ← REPLACE with your assigned prefix
 *
 * Allocation is atomic via Firestore transactions on the `music_code_counters`
 * collection so codes are never reused across concurrent uploads.
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.allocateISRC = allocateISRC;
exports.isValidISRC = isValidISRC;
exports.allocateUPC = allocateUPC;
exports.ean13CheckDigit = ean13CheckDigit;
exports.isValidUPC = isValidUPC;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
// Lazy Firestore accessor — codes.ts is imported by distribution.ts BEFORE that
// service calls initializeApp(), so we must not grab the handle at module load.
function db() {
    return firebase_admin_1.default.firestore();
}
const ISRC_COUNTRY = process.env.ISRC_COUNTRY || 'US';
const ISRC_REGISTRANT = (process.env.ISRC_REGISTRANT || 'MCH').toUpperCase();
const GS1_COMPANY_PREFIX = process.env.GS1_COMPANY_PREFIX || '0850001';
/**
 * Allocate the next ISRC for the current reference year.
 * Throws if the per-year designation space (00000–99999) is exhausted.
 */
async function allocateISRC() {
    const year = new Date().getUTCFullYear();
    const yy = String(year % 100).padStart(2, '0');
    const counterId = `isrc_${ISRC_REGISTRANT}_${yy}`;
    const counterRef = db().collection('music_code_counters').doc(counterId);
    const designation = await db().runTransaction(async (tx) => {
        const snap = await tx.get(counterRef);
        const current = snap.exists ? snap.data().value : 0;
        const next = current + 1;
        if (next > 99999) {
            throw new Error(`ISRC designation space exhausted for ${ISRC_REGISTRANT} ${yy}`);
        }
        tx.set(counterRef, { value: next, updatedAt: firebase_admin_1.default.firestore.Timestamp.now() }, { merge: true });
        return next;
    });
    const nnnnn = String(designation).padStart(5, '0');
    // Stored canonical form without dashes is also common; we return the dashed display form.
    return `${ISRC_COUNTRY}-${ISRC_REGISTRANT}-${yy}-${nnnnn}`;
}
/** Validate an ISRC string (with or without dashes). */
function isValidISRC(isrc) {
    const compact = isrc.replace(/-/g, '').toUpperCase();
    return /^[A-Z]{2}[A-Z0-9]{3}\d{2}\d{5}$/.test(compact);
}
/**
 * Allocate the next UPC/EAN-13 barcode from the GS1 company prefix.
 * The product reference fills the digits between the prefix and the check digit.
 */
async function allocateUPC() {
    const prefix = GS1_COMPANY_PREFIX.replace(/\D/g, '');
    // 12 payload digits + 1 check digit = 13 (EAN-13). Reference length is the remainder.
    const referenceLength = 12 - prefix.length;
    if (referenceLength <= 0) {
        throw new Error('GS1_COMPANY_PREFIX is too long for EAN-13 allocation');
    }
    const counterId = `upc_${prefix}`;
    const counterRef = db().collection('music_code_counters').doc(counterId);
    const reference = await db().runTransaction(async (tx) => {
        const snap = await tx.get(counterRef);
        const current = snap.exists ? snap.data().value : 0;
        const next = current + 1;
        const max = Math.pow(10, referenceLength) - 1;
        if (next > max) {
            throw new Error(`UPC reference space exhausted for prefix ${prefix}`);
        }
        tx.set(counterRef, { value: next, updatedAt: firebase_admin_1.default.firestore.Timestamp.now() }, { merge: true });
        return next;
    });
    const payload = prefix + String(reference).padStart(referenceLength, '0');
    const check = ean13CheckDigit(payload);
    return payload + check;
}
/** Compute the EAN-13 / UPC-A check digit for a 12-digit payload. */
function ean13CheckDigit(payload12) {
    const digits = payload12.split('').map(Number);
    let sum = 0;
    for (let i = 0; i < digits.length; i++) {
        sum += digits[i] * (i % 2 === 0 ? 1 : 3);
    }
    const check = (10 - (sum % 10)) % 10;
    return String(check);
}
/** Validate a 13-digit UPC/EAN barcode including its check digit. */
function isValidUPC(upc) {
    const compact = upc.replace(/\D/g, '');
    if (compact.length !== 13)
        return false;
    return ean13CheckDigit(compact.slice(0, 12)) === compact[12];
}
