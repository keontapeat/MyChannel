/**
 * music-payouts/index.js
 * MyChannel Music — Stripe Connect payouts with real collaborator revenue splits.
 *
 * What this does (DistroKid/Stripe-parity):
 *   • Calculates unpaid stream revenue per track.
 *   • Splits each track's revenue across collaborators by their share %.
 *   • Sends a separate Stripe transfer to every payee that has a connected
 *     account, grouped under one transfer_group for reconciliation.
 *   • Records a per-payee ledger entry. Payees without a connected account
 *     accrue an "owed" balance they can claim after onboarding.
 *   • Marks tracks paid atomically so streams are never double-paid.
 *
 * Environment variables (see .env.example):
 *   STRIPE_SECRET_KEY      — sk_live_... (or sk_test_... for testing)
 *   STRIPE_WEBHOOK_SECRET  — whsec_... (from Stripe Dashboard > Webhooks)
 *   PAYOUT_RATE_USD        — per-stream rate (default 0.004)
 *   INSTANT_PAYOUT_FEE_PCT — instant payout fee fraction (default 0.015)
 *
 * Deploy:
 *   gcloud functions deploy payoutArtist \
 *     --runtime nodejs20 --trigger-http --allow-unauthenticated \
 *     --set-env-vars STRIPE_SECRET_KEY=...,STRIPE_WEBHOOK_SECRET=...
 */

const crypto = require("crypto");
const admin = require("firebase-admin");
const { Stripe } = require("stripe");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

// Secrets are bound to each function below and resolved at runtime.
const STRIPE_SECRET_KEY_PARAM = defineSecret("STRIPE_SECRET_KEY");
const STRIPE_WEBHOOK_SECRET_PARAM = defineSecret("STRIPE_WEBHOOK_SECRET");

// Lazy Stripe client — must read the bound secret at call time, not module load.
let _stripe = null;
function requiredStripeSecret(name, pattern) {
  const value = String(process.env[name] || "").trim();
  if (!pattern.test(value) || /TODO|PLACEHOLDER|CHANGEME/i.test(value)) {
    const err = new Error(`${name} is not configured`);
    err.status = 503;
    throw err;
  }
  return value;
}

function getStripe() {
  if (!_stripe) {
    const key = requiredStripeSecret("STRIPE_SECRET_KEY", /^sk_(?:test|live)_[A-Za-z0-9]/);
    _stripe = new Stripe(key, { apiVersion: "2024-04-10" });
  }
  return _stripe;
}

const PAYOUT_RATE = decimalToFraction(process.env.PAYOUT_RATE_USD || "0.004", "PAYOUT_RATE_USD");
const INSTANT_PAYOUT_FEE_RATE = decimalToFraction(
  process.env.INSTANT_PAYOUT_FEE_PCT || "0.015",
  "INSTANT_PAYOUT_FEE_PCT"
);
const MINIMUM_PAYOUT_CENTS = dollarsToCents(
  process.env.MINIMUM_PAYOUT_USD || "10.00",
  "MINIMUM_PAYOUT_USD"
);

if (INSTANT_PAYOUT_FEE_RATE.numerator > INSTANT_PAYOUT_FEE_RATE.denominator) {
  throw new Error("INSTANT_PAYOUT_FEE_PCT must be between 0 and 1");
}

const FIRESTORE_MAX_BATCH_WRITES = 500;
const MAX_TRACKS_PER_SETTLEMENT = 200;
const MAX_PAYEES_PER_SETTLEMENT = 200;
const MAX_CLAIM_ENTRIES = 450;
const PERCENT_SCALE = 1000000n;
const TOTAL_SHARE_UNITS = 100n * PERCENT_SCALE;

if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

// 🔒 Strict CORS allowlist — never reflect arbitrary origins on money endpoints.
const ALLOWED_ORIGINS = new Set([
  "https://mychannel.live",
  "https://www.mychannel.live",
  "https://mychannel-ca26d.web.app",
  "https://mychannel-ca26d.firebaseapp.com",
]);

function cors(req, res, methods) {
  const origin = req.headers.origin;
  // Native iOS/Android clients send no Origin header — allow those (CORS is a
  // browser-only control). For browsers, only echo back an allow-listed origin.
  if (!origin) {
    res.set("Access-Control-Allow-Origin", "https://mychannel.live");
  } else if (ALLOWED_ORIGINS.has(origin)) {
    res.set("Access-Control-Allow-Origin", origin);
    res.set("Vary", "Origin");
  }
  res.set("Access-Control-Allow-Methods", methods);
  res.set("Access-Control-Allow-Headers", "Content-Type,Authorization");
}

// 🔐 Verify the Firebase ID token on the Authorization: Bearer <token> header.
// Returns the decoded token, or throws an Error tagged with .status = 401.
async function requireAuth(req) {
  const header = req.headers.authorization || req.headers.Authorization || "";
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match) {
    const err = new Error("Missing or malformed Authorization header");
    err.status = 401;
    throw err;
  }
  try {
    return await admin.auth().verifyIdToken(match[1]);
  } catch (e) {
    const err = new Error("Invalid or expired authentication token");
    err.status = 401;
    throw err;
  }
}

const ADMIN_EMAILS = new Set([
  "keontapeat@mychannel.live",
  "keontapeat@gmail.com",
]);

function isAdmin(decoded) {
  return (
    decoded &&
    (decoded.admin === true ||
      (decoded.email_verified && ADMIN_EMAILS.has(decoded.email)))
  );
}

// Caller must be the artist themselves (token uid === artistId) or an admin.
function assertCanActForArtist(decoded, artistId) {
  if (decoded.uid === artistId || isAdmin(decoded)) return;
  const err = new Error("You are not allowed to act on behalf of this artist");
  err.status = 403;
  throw err;
}

function decimalToFraction(value, label) {
  const text = String(value).trim();
  if (!/^\d+(?:\.\d+)?$/.test(text)) {
    throw new Error(`${label} must be a non-negative decimal`);
  }
  const [whole, fraction = ""] = text.split(".");
  const denominator = 10n ** BigInt(fraction.length);
  return {
    numerator: BigInt(`${whole}${fraction}`),
    denominator,
  };
}

function bigintToSafeNumber(value, label) {
  if (value < 0n || value > BigInt(Number.MAX_SAFE_INTEGER)) {
    throw new Error(`${label} exceeds the supported integer range`);
  }
  return Number(value);
}

function divideRounded(numerator, denominator) {
  return (numerator + denominator / 2n) / denominator;
}

function dollarsToCents(value, label = "amount") {
  const fraction = decimalToFraction(value, label);
  return bigintToSafeNumber(
    divideRounded(fraction.numerator * 100n, fraction.denominator),
    `${label} cents`
  );
}

function calculateCumulativeRevenueCents(streamCount) {
  const cents = divideRounded(
    BigInt(streamCount) * PAYOUT_RATE.numerator * 100n,
    PAYOUT_RATE.denominator
  );
  return bigintToSafeNumber(cents, "track revenue cents");
}

function multiplyCentsByRate(cents, rate) {
  return bigintToSafeNumber(
    divideRounded(BigInt(cents) * rate.numerator, rate.denominator),
    "fee cents"
  );
}

function asSafeNonNegativeInteger(value, label) {
  const parsed = Number(value || 0);
  if (!Number.isSafeInteger(parsed) || parsed < 0) {
    const err = new Error(`${label} must be a non-negative safe integer`);
    err.status = 409;
    throw err;
  }
  return parsed;
}

function parsePercentageUnits(value) {
  let fraction;
  try {
    fraction = decimalToFraction(
      value == null ? "0" : value,
      "revenue share percentage"
    );
  } catch (error) {
    error.status = 409;
    throw error;
  }
  const scaledNumerator = fraction.numerator * PERCENT_SCALE;
  if (scaledNumerator % fraction.denominator !== 0n) {
    const err = new Error("Revenue share percentages support at most 6 decimal places");
    err.status = 409;
    throw err;
  }
  const units = scaledNumerator / fraction.denominator;
  if (units > TOTAL_SHARE_UNITS) {
    const err = new Error("A collaborator revenue share cannot exceed 100%");
    err.status = 409;
    throw err;
  }
  return units;
}

function parseBasisPointUnits(value) {
  if (!Number.isSafeInteger(value) || value < 0 || value > 10000) {
    const err = new Error("Revenue share basis points must be an integer from 0 to 10000");
    err.status = 409;
    throw err;
  }
  return BigInt(value) * TOTAL_SHARE_UNITS / 10000n;
}

function payableCounters(data, trackId) {
  // Legacy streamCount/lastPaidStreamCount may contain self or otherwise
  // nonpayable plays. Missing payable counters deliberately start at zero and
  // are never inferred from either legacy field.
  const currentPayableStreamCount = asSafeNonNegativeInteger(
    data.payableStreamCount !== undefined ? data.payableStreamCount : 0,
    `payableStreamCount for track ${trackId}`
  );
  const lastPaidPayableStreamCount = asSafeNonNegativeInteger(
    data.lastPaidPayableStreamCount !== undefined
      ? data.lastPaidPayableStreamCount
      : 0,
    `lastPaidPayableStreamCount for track ${trackId}`
  );
  return { currentPayableStreamCount, lastPaidPayableStreamCount };
}

function settlementTrackCounters(track) {
  if (track.currentPayableStreamCount === undefined ||
      track.lastPaidPayableStreamCount === undefined) {
    const err = new Error(`Settlement ${track.trackId} lacks explicit payable counters`);
    err.status = 409;
    throw err;
  }
  return {
    currentPayableStreamCount: asSafeNonNegativeInteger(
      track.currentPayableStreamCount,
      `settlement payableStreamCount for track ${track.trackId}`
    ),
    lastPaidPayableStreamCount: asSafeNonNegativeInteger(
      track.lastPaidPayableStreamCount,
      `settlement lastPaidPayableStreamCount for track ${track.trackId}`
    ),
  };
}

function stableHash(value) {
  return crypto.createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

function deterministicId(prefix, value) {
  return `${prefix}_${stableHash(value).slice(0, 40)}`;
}

function centsToUSD(cents) {
  return cents / 100;
}

function payoutThresholdFields(availableCents) {
  return {
    availableUSD: centsToUSD(availableCents),
    minimumPayoutUSD: centsToUSD(MINIMUM_PAYOUT_CENTS),
    meetsMinimumPayout:
      availableCents > 0 && availableCents >= MINIMUM_PAYOUT_CENTS,
  };
}

function allocateIntegerUnits(total, payees) {
  const allocations = payees.map((payee) => {
    const numerator = BigInt(total) * payee.shareUnits;
    return {
      payee,
      amount: numerator / TOTAL_SHARE_UNITS,
      remainder: numerator % TOTAL_SHARE_UNITS,
    };
  });
  let assigned = allocations.reduce((sum, item) => sum + item.amount, 0n);
  let remainder = BigInt(total) - assigned;
  const byRemainder = [...allocations].sort((a, b) => {
    if (a.remainder !== b.remainder) return a.remainder > b.remainder ? -1 : 1;
    return a.payee.payeeId.localeCompare(b.payee.payeeId);
  });
  for (let i = 0; remainder > 0n; i += 1, remainder -= 1n) {
    byRemainder[i].amount += 1n;
  }
  return new Map(
    allocations.map((item) => [
      item.payee.payeeId,
      bigintToSafeNumber(item.amount, "allocated units"),
    ])
  );
}

/** Return the Stripe connected account id only when every payout capability is ready. */
async function getConnectedAccount(artistId) {
  const doc = await db.collection("artist_stripe").doc(artistId).get();
  if (!doc.exists) return null;
  const data = doc.data() || {};
  if (
    !data.stripeAccountId ||
    data.connected !== true ||
    data.chargesEnabled !== true ||
    data.payoutsEnabled !== true
  ) {
    return null;
  }
  return data.stripeAccountId;
}

/**
 * Build a payee map for a single track.
 * Returns: { [payeeArtistId]: { share: 0..1, name, role } } plus the owner remainder.
 *
 * Collaborator docs live in music_track_collaborators/{trackId}:
 *   { collaborators: [{ id, name, role, revenueSharePercentage, artistId? }] }
 * Collaborators without an artistId can't be auto-paid; their share is logged
 * against the collaborator id so it can be claimed/settled later.
 */
async function getTrackSplits(trackId, ownerArtistId) {
  const snap = await db.collection("music_track_collaborators").doc(trackId).get();
  const payeeMap = new Map();
  let collaboratorShareTotal = 0n;
  const collaborators = snap.exists ? (snap.data() || {}).collaborators || [] : [];

  if (!Array.isArray(collaborators)) {
    const err = new Error(`Invalid collaborator data for track ${trackId}`);
    err.status = 409;
    throw err;
  }
  for (const collaborator of collaborators) {
    const shareUnits = collaborator.revenueShareBasisPoints !== undefined
      ? parseBasisPointUnits(collaborator.revenueShareBasisPoints)
      : parsePercentageUnits(collaborator.revenueSharePercentage);
    if (shareUnits === 0n) continue;
    collaboratorShareTotal += shareUnits;
    if (collaboratorShareTotal > TOTAL_SHARE_UNITS) {
      const err = new Error(`Collaborator revenue shares exceed 100% for track ${trackId}`);
      err.status = 409;
      throw err;
    }
    if (!collaborator.artistId && !collaborator.id) {
      const err = new Error(`A collaborator on track ${trackId} is missing an id`);
      err.status = 409;
      throw err;
    }
    const payeeId = collaborator.artistId || `collab:${collaborator.id}`;
    const existing = payeeMap.get(payeeId);
    if (existing) {
      existing.shareUnits += shareUnits;
    } else {
      payeeMap.set(payeeId, {
        payeeId,
        linkedArtistId: collaborator.artistId || null,
        name: collaborator.name || "Collaborator",
        role: collaborator.role || "collaborator",
        shareUnits,
        isOwner: payeeId === ownerArtistId,
      });
    }
  }

  const ownerShareUnits = TOTAL_SHARE_UNITS - collaboratorShareTotal;
  const existingOwner = payeeMap.get(ownerArtistId);
  if (existingOwner) {
    existingOwner.shareUnits += ownerShareUnits;
    existingOwner.isOwner = true;
    existingOwner.role = "owner";
  } else if (ownerShareUnits > 0n) {
    payeeMap.set(ownerArtistId, {
      payeeId: ownerArtistId,
      linkedArtistId: ownerArtistId,
      name: "Primary artist",
      role: "owner",
      shareUnits: ownerShareUnits,
      isOwner: true,
    });
  }

  return {
    payees: [...payeeMap.values()].sort((a, b) => a.payeeId.localeCompare(b.payeeId)),
    splitHash: stableHash(collaborators),
  };
}

/**
 * Compute a bounded, deterministic settlement from stream-count deltas.
 * All currency values returned by this function are integer cents.
 */
async function computeSettlement(ownerArtistId, payoutType = "standard") {
  const tracksSnap = await db
    .collection("music_tracks")
    .where("artistId", "==", ownerArtistId)
    .limit(MAX_TRACKS_PER_SETTLEMENT + 1)
    .get();

  if (tracksSnap.size > MAX_TRACKS_PER_SETTLEMENT) {
    const err = new Error(
      `Artist has more than ${MAX_TRACKS_PER_SETTLEMENT} tracks; settlement is safely bounded`
    );
    err.status = 409;
    throw err;
  }

  const perPayee = new Map();
  const trackStates = [];
  let totalGrossCents = 0;
  const trackDocs = [...tracksSnap.docs].sort((a, b) => a.id.localeCompare(b.id));

  for (const doc of trackDocs) {
    const data = doc.data() || {};
    const {
      currentPayableStreamCount,
      lastPaidPayableStreamCount,
    } = payableCounters(data, doc.id);
    if (currentPayableStreamCount <= lastPaidPayableStreamCount) continue;

    const trackRevenueCents =
      calculateCumulativeRevenueCents(currentPayableStreamCount) -
      calculateCumulativeRevenueCents(lastPaidPayableStreamCount);
    if (trackRevenueCents <= 0) continue;

    const { payees, splitHash } = await getTrackSplits(doc.id, ownerArtistId);
    const centAllocations = allocateIntegerUnits(trackRevenueCents, payees);
    const streamAllocations = allocateIntegerUnits(
      currentPayableStreamCount - lastPaidPayableStreamCount,
      payees
    );

    totalGrossCents += trackRevenueCents;
    trackStates.push({
      trackId: doc.id,
      lastPaidPayableStreamCount,
      currentPayableStreamCount,
      splitHash,
      revenueCents: trackRevenueCents,
    });

    for (const payee of payees) {
      const grossCents = centAllocations.get(payee.payeeId) || 0;
      if (grossCents <= 0) continue;
      const existing = perPayee.get(payee.payeeId) || {
        payeeId: payee.payeeId,
        grossCents: 0,
        streams: 0,
        linkedArtistId: payee.linkedArtistId,
        name: payee.name,
        role: payee.role,
        isOwner: !!payee.isOwner,
      };
      existing.grossCents += grossCents;
      existing.streams += streamAllocations.get(payee.payeeId) || 0;
      existing.isOwner = existing.isOwner || !!payee.isOwner;
      if (existing.isOwner) existing.role = "owner";
      perPayee.set(payee.payeeId, existing);
    }
  }

  const payees = [...perPayee.values()].sort((a, b) => a.payeeId.localeCompare(b.payeeId));
  if (payees.length > MAX_PAYEES_PER_SETTLEMENT) {
    const err = new Error(
      `Settlement has more than ${MAX_PAYEES_PER_SETTLEMENT} payees; no transfers were attempted`
    );
    err.status = 409;
    throw err;
  }

  const settlementPayload = {
    ownerArtistId,
    payoutType,
    totalGrossCents,
    tracks: trackStates,
    payees,
  };
  return {
    ...settlementPayload,
    settlementId: deterministicId("music_settlement", settlementPayload),
  };
}

/**
 * Execute transfers for a settlement.
 * feePct applies only to the requesting owner's portion (instant payout fee).
 */
async function attachSettlementDestinations(candidate) {
  const payees = await Promise.all(
    candidate.payees.map(async (payee) => ({
      ...payee,
      destinationAccount: payee.linkedArtistId
        ? await getConnectedAccount(payee.linkedArtistId)
        : null,
    }))
  );
  const payload = {
    ownerArtistId: candidate.ownerArtistId,
    payoutType: candidate.payoutType,
    totalGrossCents: candidate.totalGrossCents,
    tracks: candidate.tracks,
    payees,
  };
  return {
    ...payload,
    periodLabel: new Date().toLocaleString("en-US", {
      month: "long",
      year: "numeric",
    }),
    settlementId: deterministicId("music_settlement", payload),
  };
}

async function getPendingSettlement(ownerArtistId) {
  const snap = await db.collection("music_payout_locks").doc(ownerArtistId).get();
  const data = snap.exists ? snap.data() || {} : {};
  return data.status === "pending" && data.settlement ? data.settlement : null;
}

async function reserveSettlement(candidate) {
  const lockRef = db.collection("music_payout_locks").doc(candidate.ownerArtistId);
  return db.runTransaction(async (transaction) => {
    const lockSnap = await transaction.get(lockRef);
    const lockData = lockSnap.exists ? lockSnap.data() || {} : {};
    if (lockData.status === "pending" && lockData.settlement) {
      return lockData.settlement;
    }

    for (const track of candidate.tracks) {
      const trackRef = db.collection("music_tracks").doc(track.trackId);
      const splitRef = db.collection("music_track_collaborators").doc(track.trackId);
      const trackSnap = await transaction.get(trackRef);
      const splitSnap = await transaction.get(splitRef);
      if (!trackSnap.exists) {
        const err = new Error(`Track ${track.trackId} no longer exists`);
        err.status = 409;
        throw err;
      }
      const data = trackSnap.data() || {};
      const currentCounters = payableCounters(data, track.trackId);
      const expectedCounters = settlementTrackCounters(track);
      const collaborators = splitSnap.exists
        ? (splitSnap.data() || {}).collaborators || []
        : [];
      if (
        currentCounters.currentPayableStreamCount !==
          expectedCounters.currentPayableStreamCount ||
        currentCounters.lastPaidPayableStreamCount !==
          expectedCounters.lastPaidPayableStreamCount ||
        (track.splitHash !== undefined && stableHash(collaborators) !== track.splitHash)
      ) {
        const err = new Error("Payable counts or collaborator splits changed while preparing payout; retry safely");
        err.status = 409;
        throw err;
      }
    }

    transaction.set(lockRef, {
      artistId: candidate.ownerArtistId,
      settlementId: candidate.settlementId,
      status: "pending",
      settlement: candidate,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return candidate;
  });
}

function settlementStatus(results) {
  const paid = results.filter((result) => result.status === "paid").length;
  if (paid === results.length) return "paid";
  if (paid === 0) return "owed";
  return "partially_paid";
}

async function executeSettlement(settlement) {
  const {
    ownerArtistId,
    payoutType,
    settlementId,
    totalGrossCents,
    tracks,
    payees,
    periodLabel,
  } = settlement;
  const transferGroup = settlementId;
  const now = admin.firestore.Timestamp.now();
  const results = [];
  const ledgerWrites = [];

  for (const info of payees) {
    const feeCents =
      info.isOwner && payoutType === "instant"
        ? multiplyCentsByRate(info.grossCents, INSTANT_PAYOUT_FEE_RATE)
        : 0;
    const netAmountCents = info.grossCents - feeCents;
    if (netAmountCents <= 0) continue;

    const connectedAccount = info.destinationAccount || null;
    if (info.isOwner && !connectedAccount) {
      const err = new Error("Artist Stripe account is not fully enabled for charges and payouts");
      err.status = 409;
      throw err;
    }

    let transferId = null;
    let status = "owed";
    if (connectedAccount) {
      const idempotencyKey = deterministicId("music_transfer", {
        settlementId,
        payeeId: info.payeeId,
      });
      const transfer = await getStripe().transfers.create(
        {
          amount: netAmountCents,
          currency: "usd",
          destination: connectedAccount,
          transfer_group: transferGroup,
          description: `MyChannel Music ${info.role} payout — ${info.streams} streams`,
          metadata: {
            settlementId,
            ownerArtistId,
            payeeId: info.payeeId,
            payeeArtistId: info.linkedArtistId || "",
            role: info.role,
            streams: String(info.streams),
            payoutType,
            feeCents: String(feeCents),
          },
        },
        { idempotencyKey }
      );
      transferId = transfer.id;
      status = "paid";
    }

    const ledgerId = deterministicId("music_earning", {
      settlementId,
      payeeId: info.payeeId,
    });
    const ledgerRef = db.collection("music_split_earnings").doc(ledgerId);
    ledgerWrites.push({
      ref: ledgerRef,
      data: {
        id: ledgerId,
        settlementId,
        ownerArtistId,
        payeeId: info.payeeId,
        payeeArtistId: info.linkedArtistId || null,
        payeeName: info.name,
        role: info.role,
        grossAmountCents: info.grossCents,
        feeCents,
        netAmountCents,
        streams: info.streams,
        stripeTransferId: transferId,
        transferGroup,
        status,
        payoutType,
        periodLabel,
        createdAt: now,
        paidAt: status === "paid" ? now : null,
      },
    });
    results.push({
      payeeId: info.payeeId,
      payeeArtistId: info.linkedArtistId || null,
      name: info.name,
      role: info.role,
      amountCents: netAmountCents,
      feeCents,
      streams: info.streams,
      status,
      transferId,
    });
  }

  const writeCount = ledgerWrites.length + tracks.length + 2;
  if (writeCount > FIRESTORE_MAX_BATCH_WRITES) {
    throw new Error(`Settlement requires ${writeCount} writes; Firestore allows 500`);
  }

  const outcome = settlementStatus(results);
  const ownerResult = results.find((result) => result.role === "owner");
  const summaryRef = db.collection("artist_payouts").doc(settlementId);
  const lockRef = db.collection("music_payout_locks").doc(ownerArtistId);
  const batch = db.batch();
  for (const write of ledgerWrites) batch.set(write.ref, write.data);
  for (const track of tracks) {
    const { currentPayableStreamCount } = settlementTrackCounters(track);
    batch.update(db.collection("music_tracks").doc(track.trackId), {
      lastPaidAt: now,
      lastPaidPayableStreamCount: currentPayableStreamCount,
      lastPayoutGroup: transferGroup,
      lastSettlementId: settlementId,
    });
  }
  batch.set(summaryRef, {
    id: settlementId,
    artistId: ownerArtistId,
    transferGroup,
    amountCents: ownerResult ? ownerResult.amountCents : 0,
    totalGrossCents,
    totalDistributedCents: results.reduce((sum, result) => sum + result.amountCents, 0),
    streams: ownerResult ? ownerResult.streams : 0,
    payees: results.length,
    paidPayees: results.filter((result) => result.status === "paid").length,
    owedPayees: results.filter((result) => result.status === "owed").length,
    periodLabel,
    payoutType,
    status: outcome,
    paidAt: outcome === "paid" ? now : null,
    updatedAt: now,
  });
  batch.set(
    lockRef,
    {
      artistId: ownerArtistId,
      settlementId,
      status: "completed",
      outcome,
      completedAt: now,
      updatedAt: now,
    },
    { merge: true }
  );
  await batch.commit();

  return { transferGroup, results, status: outcome };
}

function publicSettlementResults(results) {
  return results.map((result) => ({
    ...result,
    amountUSD: centsToUSD(result.amountCents),
    fee: centsToUSD(result.feeCents),
  }));
}

function ownerGrossCents(settlement, artistId) {
  const owner = settlement.payees.find((payee) => payee.payeeId === artistId);
  return owner && Number.isSafeInteger(owner.grossCents) && owner.grossCents > 0
    ? owner.grossCents
    : 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /payoutArtist  — settle the current period for an artist (+ splits)
// ─────────────────────────────────────────────────────────────────────────────
async function handlePayoutArtist(req, res) {
  cors(req, res, "POST");
  if (req.method === "OPTIONS") return res.status(204).send("");
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  const { artistId } = req.body || {};
  if (!artistId) return res.status(400).json({ error: "artistId is required" });

  try {
    const decoded = await requireAuth(req);
    assertCanActForArtist(decoded, artistId);

    const pending = await getPendingSettlement(artistId);
    let candidate = pending;
    if (!pending) {
      const ownerAccount = await getConnectedAccount(artistId);
      if (!ownerAccount) {
        return res.status(400).json({
          error: "Artist Stripe account must be connected with charges and payouts enabled.",
        });
      }
      candidate = await attachSettlementDestinations(
        await computeSettlement(artistId, "standard")
      );
    }
    const ownerAvailableCents = ownerGrossCents(candidate, artistId);
    if (!pending &&
        (ownerAvailableCents < MINIMUM_PAYOUT_CENTS || candidate.tracks.length === 0)) {
      return res.status(200).json({
        success: false,
        message: `Artist payout of $${centsToUSD(ownerAvailableCents).toFixed(2)} is below the $${centsToUSD(MINIMUM_PAYOUT_CENTS).toFixed(2)} minimum. Keep streaming!`,
        amountCents: ownerAvailableCents,
        totalGrossUSD: centsToUSD(candidate.totalGrossCents),
        ...payoutThresholdFields(ownerAvailableCents),
      });
    }

    const settlement = pending || (await reserveSettlement(candidate));
    const { transferGroup, results, status } = await executeSettlement(settlement);
    return res.status(200).json({
      success: status === "paid" || status === "partially_paid",
      status,
      transferGroup,
      totalGrossUSD: centsToUSD(settlement.totalGrossCents),
      minimumPayoutUSD: centsToUSD(MINIMUM_PAYOUT_CENTS),
      splits: publicSettlementResults(results),
    });
  } catch (err) {
    console.error("❌ Payout error:", err);
    return res.status(err.status || 500).json({ error: err.message || "Payout failed" });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /requestPayout  — on-demand payout (instant or standard) with splits
// ─────────────────────────────────────────────────────────────────────────────
async function handleRequestPayout(req, res) {
  cors(req, res, "POST");
  if (req.method === "OPTIONS") return res.status(204).send("");
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  const { artistId, payoutType } = req.body || {};
  if (!artistId) return res.status(400).json({ error: "artistId is required" });
  const requestedType = payoutType === "instant" ? "instant" : "standard";

  try {
    const decoded = await requireAuth(req);
    assertCanActForArtist(decoded, artistId);

    const pending = await getPendingSettlement(artistId);
    let candidate = pending;
    if (!pending) {
      const ownerAccount = await getConnectedAccount(artistId);
      if (!ownerAccount) {
        return res.status(400).json({
          error: "Artist Stripe account must be connected with charges and payouts enabled.",
        });
      }
      candidate = await attachSettlementDestinations(
        await computeSettlement(artistId, requestedType)
      );
    }
    const ownerAvailableCents = ownerGrossCents(candidate, artistId);
    if (!pending &&
        (ownerAvailableCents < MINIMUM_PAYOUT_CENTS || candidate.tracks.length === 0)) {
      return res.status(200).json({
        success: false,
        message: `Artist payout of $${centsToUSD(ownerAvailableCents).toFixed(2)} is below the $${centsToUSD(MINIMUM_PAYOUT_CENTS).toFixed(2)} minimum.`,
        amountCents: ownerAvailableCents,
        totalGrossUSD: centsToUSD(candidate.totalGrossCents),
        ...payoutThresholdFields(ownerAvailableCents),
      });
    }

    const settlement = pending || (await reserveSettlement(candidate));
    const { transferGroup, results, status } = await executeSettlement(settlement);
    return res.status(200).json({
      success: status === "paid" || status === "partially_paid",
      status,
      transferGroup,
      payoutType: settlement.payoutType,
      totalGrossUSD: centsToUSD(settlement.totalGrossCents),
      minimumPayoutUSD: centsToUSD(MINIMUM_PAYOUT_CENTS),
      splits: publicSettlementResults(results),
      estimatedDelivery:
        settlement.payoutType === "instant" ? "1-2 business days" : "5-7 business days",
    });
  } catch (err) {
    console.error("❌ Payout request error:", err);
    return res.status(err.status || 500).json({ error: err.message || "Payout request failed" });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /getAvailableBalance  — preview balance + how it splits
// ─────────────────────────────────────────────────────────────────────────────
async function handleGetAvailableBalance(req, res) {
  cors(req, res, "GET");
  if (req.method === "OPTIONS") return res.status(204).send("");
  if (req.method !== "GET") return res.status(405).json({ error: "Method not allowed" });

  const { artistId } = req.query || {};
  if (!artistId) return res.status(400).json({ error: "artistId is required" });

  try {
    const decoded = await requireAuth(req);
    assertCanActForArtist(decoded, artistId);

    const settlement = await computeSettlement(artistId, "standard");
    const owner = settlement.payees.find((payee) => payee.payeeId === artistId) || {
      grossCents: 0,
      streams: 0,
    };
    const instantFeeCents = multiplyCentsByRate(
      owner.grossCents,
      INSTANT_PAYOUT_FEE_RATE
    );
    const payoutAccountReady = !!(await getConnectedAccount(artistId));
    const isReadyForPayout =
      payoutAccountReady &&
      settlement.tracks.length > 0 &&
      owner.grossCents >= MINIMUM_PAYOUT_CENTS;
    const splitPreview = await Promise.all(
      settlement.payees.map(async (info) => ({
        payeeId: info.payeeId,
        payeeArtistId: info.linkedArtistId || null,
        name: info.name,
        role: info.role,
        amountCents: info.grossCents,
        amountUSD: centsToUSD(info.grossCents),
        streams: info.streams,
        payable: !!(
          info.linkedArtistId && (await getConnectedAccount(info.linkedArtistId))
        ),
      }))
    );

    return res.status(200).json({
      artistId,
      amountCents: owner.grossCents,
      ownerAmountCents: owner.grossCents,
      totalGrossCents: settlement.totalGrossCents,
      minimumPayoutCents: MINIMUM_PAYOUT_CENTS,
      isReadyForPayout,
      stripeConnected: payoutAccountReady,
      payoutAccountReady,
      totalGrossUSD: centsToUSD(settlement.totalGrossCents),
      ...payoutThresholdFields(owner.grossCents),
      ownerAmountUSD: centsToUSD(owner.grossCents),
      ownerStreams: owner.streams || 0,
      instantPayoutAmountUSD: centsToUSD(
        Math.max(0, owner.grossCents - instantFeeCents)
      ),
      instantPayoutFeePct:
        Number(INSTANT_PAYOUT_FEE_RATE.numerator) /
        Number(INSTANT_PAYOUT_FEE_RATE.denominator),
      splitPreview,
      estimatedStandardDelivery: "5-7 business days",
      estimatedInstantDelivery: "1-2 business days",
    });
  } catch (err) {
    console.error("❌ Get available balance error:", err);
    return res.status(err.status || 500).json({ error: err.message || "Failed to get available balance" });
  }
}

function earningNetCents(data, entryId) {
  if (Number.isSafeInteger(data.netAmountCents) && data.netAmountCents >= 0) {
    return data.netAmountCents;
  }
  const legacyAmount = Number(data.netAmount || 0);
  if (!Number.isFinite(legacyAmount) || legacyAmount < 0) {
    const err = new Error(`Invalid owed amount for earning ${entryId}`);
    err.status = 409;
    throw err;
  }
  return asSafeNonNegativeInteger(Math.round(legacyAmount * 100), `owed cents for ${entryId}`);
}

async function getPendingClaim(artistId) {
  const snap = await db.collection("music_owed_claim_locks").doc(artistId).get();
  const data = snap.exists ? snap.data() || {} : {};
  return data.status === "pending" && data.claim ? data.claim : null;
}

async function buildClaimCandidate(artistId, destinationAccount) {
  const owedSnap = await db
    .collection("music_split_earnings")
    .where("payeeArtistId", "==", artistId)
    .where("status", "==", "owed")
    .limit(MAX_CLAIM_ENTRIES)
    .get();
  const entries = owedSnap.docs
    .map((doc) => ({
      entryId: doc.id,
      amountCents: earningNetCents(doc.data() || {}, doc.id),
    }))
    .filter((entry) => entry.amountCents > 0)
    .sort((a, b) => a.entryId.localeCompare(b.entryId));
  const totalCents = entries.reduce((sum, entry) => sum + entry.amountCents, 0);
  const payload = { artistId, destinationAccount, totalCents, entries };
  return { ...payload, claimId: deterministicId("music_claim", payload) };
}

async function reserveClaim(candidate) {
  const lockRef = db.collection("music_owed_claim_locks").doc(candidate.artistId);
  return db.runTransaction(async (transaction) => {
    const lockSnap = await transaction.get(lockRef);
    const lockData = lockSnap.exists ? lockSnap.data() || {} : {};
    if (lockData.status === "pending" && lockData.claim) return lockData.claim;

    for (const entry of candidate.entries) {
      const entryRef = db.collection("music_split_earnings").doc(entry.entryId);
      const entrySnap = await transaction.get(entryRef);
      const data = entrySnap.exists ? entrySnap.data() || {} : {};
      if (
        !entrySnap.exists ||
        data.status !== "owed" ||
        earningNetCents(data, entry.entryId) !== entry.amountCents
      ) {
        const err = new Error("Owed earnings changed while preparing claim; retry safely");
        err.status = 409;
        throw err;
      }
    }

    transaction.set(lockRef, {
      artistId: candidate.artistId,
      claimId: candidate.claimId,
      claim: candidate,
      status: "pending",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return candidate;
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /claimOwedEarnings — collaborator claims accrued "owed" splits after onboarding
// ─────────────────────────────────────────────────────────────────────────────
async function handleClaimOwedEarnings(req, res) {
  cors(req, res, "POST");
  if (req.method === "OPTIONS") return res.status(204).send("");
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  const { artistId } = req.body || {};
  if (!artistId) return res.status(400).json({ error: "artistId is required" });

  try {
    const decoded = await requireAuth(req);
    assertCanActForArtist(decoded, artistId);

    const pending = await getPendingClaim(artistId);
    let candidate = pending;
    if (!pending) {
      const account = await getConnectedAccount(artistId);
      if (!account) {
        return res.status(400).json({
          error: "Stripe must be connected with charges and payouts enabled before claiming.",
        });
      }
      candidate = await buildClaimCandidate(artistId, account);
    }
    if (!pending &&
        (candidate.entries.length === 0 || candidate.totalCents < MINIMUM_PAYOUT_CENTS)) {
      return res.status(200).json({
        success: false,
        message: `Claimable earnings of $${centsToUSD(candidate.totalCents).toFixed(2)} are below the $${centsToUSD(MINIMUM_PAYOUT_CENTS).toFixed(2)} minimum.`,
        ...payoutThresholdFields(candidate.totalCents),
      });
    }
    if (candidate.totalCents <= 0) {
      return res.status(200).json({
        success: false,
        message: 'Nothing claimable.',
        ...payoutThresholdFields(candidate.totalCents),
      });
    }

    const claim = pending || (await reserveClaim(candidate));
    const transfer = await getStripe().transfers.create(
      {
        amount: claim.totalCents,
        currency: "usd",
        destination: claim.destinationAccount,
        transfer_group: claim.claimId,
        description: "MyChannel Music — claimed collaborator earnings",
        metadata: {
          artistId,
          claimId: claim.claimId,
          entries: String(claim.entries.length),
        },
      },
      { idempotencyKey: deterministicId("music_claim_transfer", claim.claimId) }
    );

    if (claim.entries.length + 1 > FIRESTORE_MAX_BATCH_WRITES) {
      throw new Error("Claim exceeds Firestore write limits");
    }
    const now = admin.firestore.Timestamp.now();
    const batch = db.batch();
    for (const entry of claim.entries) {
      batch.update(db.collection("music_split_earnings").doc(entry.entryId), {
        status: "paid",
        claimId: claim.claimId,
        stripeTransferId: transfer.id,
        claimedAt: now,
        paidAt: now,
      });
    }
    batch.set(
      db.collection("music_owed_claim_locks").doc(artistId),
      {
        artistId,
        claimId: claim.claimId,
        status: "completed",
        transferId: transfer.id,
        amountCents: claim.totalCents,
        completedAt: now,
        updatedAt: now,
      },
      { merge: true }
    );
    await batch.commit();

    return res.status(200).json({
      success: true,
      claimId: claim.claimId,
      transferId: transfer.id,
      amountUSD: centsToUSD(claim.totalCents),
      entries: claim.entries.length,
    });
  } catch (err) {
    console.error("❌ Claim owed earnings error:", err);
    return res.status(err.status || 500).json({ error: err.message || "Claim failed" });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /createConnectOnboardingLink — start Stripe Express onboarding (API-based)
// ─────────────────────────────────────────────────────────────────────────────
async function handleCreateConnectOnboardingLink(req, res) {
  cors(req, res, "POST");
  if (req.method === "OPTIONS") return res.status(204).send("");
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  const { artistId, email, refreshUrl, returnUrl } = req.body || {};
  if (!artistId) return res.status(400).json({ error: "artistId is required" });

  try {
    const decoded = await requireAuth(req);
    assertCanActForArtist(decoded, artistId);

    const stripeRef = db.collection("artist_stripe").doc(artistId);
    const existing = await stripeRef.get();
    let accountId = existing.exists ? existing.data().stripeAccountId : null;

    if (!accountId) {
      const account = await getStripe().accounts.create({
        type: "express",
        email: email || undefined,
        capabilities: { transfers: { requested: true } },
        business_type: "individual",
        metadata: { artistId },
      });
      accountId = account.id;
      await stripeRef.set(
        {
          stripeAccountId: accountId,
          connected: false,
          chargesEnabled: false,
          payoutsEnabled: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    const link = await getStripe().accountLinks.create({
      account: accountId,
      refresh_url: refreshUrl || "https://mychannel.live/stripe/refresh",
      return_url: returnUrl || "https://mychannel.live/stripe/return",
      type: "account_onboarding",
    });

    return res.status(200).json({ url: link.url, stripeAccountId: accountId });
  } catch (err) {
    console.error("❌ Onboarding link error:", err);
    return res.status(err.status || 500).json({ error: err.message || "Could not create onboarding link" });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /stripeWebhook — mark accounts connected when onboarding completes
// ─────────────────────────────────────────────────────────────────────────────
async function handleStripeWebhook(req, res) {
  const sig = req.headers["stripe-signature"];

  let event;
  try {
    const webhookSecret = requiredStripeSecret(
      "STRIPE_WEBHOOK_SECRET",
      /^whsec_[A-Za-z0-9]/
    );
    event = getStripe().webhooks.constructEvent(req.rawBody, sig, webhookSecret);
  } catch (err) {
    console.error("Webhook signature verification failed:", err.message);
    return res.status(err.status || 400).send(
      err.status === 503 ? "Webhook is not configured" : `Webhook Error: ${err.message}`
    );
  }

  try {
    if (event.type === "account.updated") {
      const account = event.data.object;
      const ready =
        account.details_submitted && account.charges_enabled && account.payouts_enabled;
      const snap = await db
        .collection("artist_stripe")
        .where("stripeAccountId", "==", account.id)
        .limit(1)
        .get();
      if (!snap.empty) {
        await snap.docs[0].ref.update({
          connected: !!ready,
          chargesEnabled: !!account.charges_enabled,
          payoutsEnabled: !!account.payouts_enabled,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`✅ Stripe account ${account.id} ready=${ready}`);
      }
    }

    if (event.type === "account.application.authorized") {
      const account = event.data.object;
      const artistId = account.metadata && account.metadata.artistId;
      if (artistId) {
        await db.collection("artist_stripe").doc(artistId).set(
          {
            stripeAccountId: account.id,
            connected: !!(
              account.details_submitted && account.charges_enabled && account.payouts_enabled
            ),
            chargesEnabled: !!account.charges_enabled,
            payoutsEnabled: !!account.payouts_enabled,
            connectedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }
    }
  } catch (err) {
    console.error("Webhook handler error:", err.message);
  }

  res.status(200).json({ received: true });
}

// ─────────────────────────────────────────────────────────────────────────────
// Single combined HTTP function — routes by path so we deploy ONE Cloud Run
// service instead of six (keeps us well under the per-region CPU quota).
//
// Routes:
//   POST /payoutArtist
//   POST /requestPayout
//   GET  /getAvailableBalance
//   POST /claimOwedEarnings
//   POST /createConnectOnboardingLink
//   POST /stripeWebhook
// ─────────────────────────────────────────────────────────────────────────────
exports.musicPayouts = onRequest(
  {
    secrets: [STRIPE_SECRET_KEY_PARAM, STRIPE_WEBHOOK_SECRET_PARAM],
    cpu: 1,
    memory: "256MiB",
    minInstances: 0,
    maxInstances: 3,
    concurrency: 80,
    region: "us-east1",
    invoker: "public",
  },
  async (req, res) => {
    // Normalize the route from the path (last non-empty segment).
    const segments = (req.path || "/").split("/").filter(Boolean);
    const route = segments.length ? segments[segments.length - 1] : "";

    try {
      switch (route) {
        case "payoutArtist":
          return await handlePayoutArtist(req, res);
        case "requestPayout":
          return await handleRequestPayout(req, res);
        case "getAvailableBalance":
          return await handleGetAvailableBalance(req, res);
        case "claimOwedEarnings":
          return await handleClaimOwedEarnings(req, res);
        case "createConnectOnboardingLink":
          return await handleCreateConnectOnboardingLink(req, res);
        case "stripeWebhook":
          return await handleStripeWebhook(req, res);
        default:
          res.set("Access-Control-Allow-Origin", "*");
          res.set("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
          res.set("Access-Control-Allow-Headers", "Content-Type,Authorization,stripe-signature");
          if (req.method === "OPTIONS") return res.status(204).send("");
          return res.status(404).json({
            error: "Unknown route",
            available: [
              "payoutArtist",
              "requestPayout",
              "getAvailableBalance",
              "claimOwedEarnings",
              "createConnectOnboardingLink",
              "stripeWebhook",
            ],
          });
      }
    } catch (err) {
      console.error("musicPayouts router error:", err);
      return res.status(500).json({ error: err.message || "Internal error" });
    }
  }
);

