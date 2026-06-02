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

const admin = require("firebase-admin");
const { Stripe } = require("stripe");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

// Secrets are bound to each function below and resolved at runtime.
const STRIPE_SECRET_KEY_PARAM = defineSecret("STRIPE_SECRET_KEY");
const STRIPE_WEBHOOK_SECRET_PARAM = defineSecret("STRIPE_WEBHOOK_SECRET");

// Lazy Stripe client — must read the secret at call time, not module load.
let _stripe = null;
function getStripe() {
  if (!_stripe) {
    const key = process.env.STRIPE_SECRET_KEY || "sk_test_TODO";
    _stripe = new Stripe(key, { apiVersion: "2024-04-10" });
  }
  return _stripe;
}

const PAYOUT_RATE_USD = parseFloat(process.env.PAYOUT_RATE_USD || "0.004");
const INSTANT_PAYOUT_FEE_PCT = parseFloat(process.env.INSTANT_PAYOUT_FEE_PCT || "0.015");
const MINIMUM_PAYOUT_USD = parseFloat(process.env.MINIMUM_PAYOUT_USD || "0.0");

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

function roundCents(usd) {
  return Math.round(usd * 100);
}

/** Return the Stripe connected account id for an artist, or null if not ready. */
async function getConnectedAccount(artistId) {
  const doc = await db.collection("artist_stripe").doc(artistId).get();
  if (!doc.exists) return null;
  const data = doc.data() || {};
  if (!data.stripeAccountId) return null;
  // Only pay accounts that can actually receive funds.
  if (data.connected === false || data.chargesEnabled === false) {
    // Still return the id — we attempt the transfer and let Stripe reject if not ready.
    return data.stripeAccountId;
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
  const payees = [];
  let collaboratorShareTotal = 0;

  if (snap.exists) {
    const collaborators = (snap.data() || {}).collaborators || [];
    for (const c of collaborators) {
      const pct = Math.max(0, Math.min(100, Number(c.revenueSharePercentage) || 0));
      if (pct <= 0) continue;
      collaboratorShareTotal += pct;
      payees.push({
        payeeId: c.artistId || `collab:${c.id}`,
        linkedArtistId: c.artistId || null,
        name: c.name || "Collaborator",
        role: c.role || "collaborator",
        share: pct / 100,
      });
    }
  }

  // Owner takes the remainder (never negative; clamp collaborator total to 100).
  const ownerPct = Math.max(0, 100 - Math.min(100, collaboratorShareTotal));
  payees.push({
    payeeId: ownerArtistId,
    linkedArtistId: ownerArtistId,
    name: "Primary artist",
    role: "owner",
    share: ownerPct / 100,
    isOwner: true,
  });

  return payees;
}

/**
 * Core settlement: compute per-payee amounts across all unpaid tracks for an artist.
 * Returns { perPayee, trackIds, totalGross }.
 */
async function computeSettlement(ownerArtistId) {
  const tracksSnap = await db
    .collection("music_tracks")
    .where("artistId", "==", ownerArtistId)
    .get();

  const perPayee = {}; // payeeId -> { gross, linkedArtistId, name, role, streams }
  const trackIds = [];
  let totalGross = 0;

  for (const doc of tracksSnap.docs) {
    const data = doc.data();
    const lastPaid = data.lastPaidAt ? data.lastPaidAt.toDate() : null;
    if (lastPaid) continue; // already settled

    const streams = data.streamCount || 0;
    if (streams <= 0) continue;

    const trackRevenue = streams * PAYOUT_RATE_USD;
    totalGross += trackRevenue;
    trackIds.push(doc.id);

    const payees = await getTrackSplits(doc.id, ownerArtistId);
    for (const p of payees) {
      const amount = trackRevenue * p.share;
      if (amount <= 0) continue;
      if (!perPayee[p.payeeId]) {
        perPayee[p.payeeId] = {
          gross: 0,
          streams: 0,
          linkedArtistId: p.linkedArtistId,
          name: p.name,
          role: p.role,
          isOwner: !!p.isOwner,
        };
      }
      perPayee[p.payeeId].gross += amount;
      perPayee[p.payeeId].streams += Math.round(streams * p.share);
    }
  }

  return { perPayee, trackIds, totalGross };
}

/**
 * Execute transfers for a settlement.
 * feePct applies only to the requesting owner's portion (instant payout fee).
 */
async function executeSettlement({ ownerArtistId, perPayee, trackIds, totalGross, payoutType }) {
  const transferGroup = `mychannel_music_${ownerArtistId}_${Date.now()}`;
  const now = admin.firestore.Timestamp.now();
  const periodLabel = new Date().toLocaleString("en-US", { month: "long", year: "numeric" });

  const results = [];
  const ledgerWrites = [];

  for (const [payeeId, info] of Object.entries(perPayee)) {
    let amountUSD = info.gross;
    let fee = 0;
    if (info.isOwner && payoutType === "instant") {
      fee = amountUSD * INSTANT_PAYOUT_FEE_PCT;
      amountUSD = amountUSD - fee;
    }
    if (amountUSD <= 0) continue;

    const connectedAccount = info.linkedArtistId
      ? await getConnectedAccount(info.linkedArtistId)
      : null;

    let transferId = null;
    let status = "owed";

    if (connectedAccount) {
      try {
        const transfer = await getStripe().transfers.create({
          amount: roundCents(amountUSD),
          currency: "usd",
          destination: connectedAccount,
          transfer_group: transferGroup,
          description: `MyChannel Music ${info.role} payout — ${info.streams} streams`,
          metadata: {
            ownerArtistId,
            payeeId,
            payeeArtistId: info.linkedArtistId || "",
            role: info.role,
            streams: String(info.streams),
            payoutType: payoutType || "standard",
            fee: fee.toFixed(4),
          },
        });
        transferId = transfer.id;
        status = "paid";
      } catch (err) {
        // Transfer failed (e.g. account not ready) — record as owed so it isn't lost.
        console.error(`Transfer to ${payeeId} failed: ${err.message}`);
        status = "owed";
      }
    }

    const ledgerRef = db.collection("music_split_earnings").doc();
    ledgerWrites.push({
      ref: ledgerRef,
      data: {
        id: ledgerRef.id,
        ownerArtistId,
        payeeId,
        payeeArtistId: info.linkedArtistId || null,
        payeeName: info.name,
        role: info.role,
        grossAmount: info.gross,
        fee,
        netAmount: amountUSD,
        streams: info.streams,
        stripeTransferId: transferId,
        transferGroup,
        status, // "paid" | "owed"
        payoutType: payoutType || "standard",
        periodLabel,
        createdAt: now,
        paidAt: status === "paid" ? now : null,
      },
    });

    results.push({
      payeeId,
      payeeArtistId: info.linkedArtistId || null,
      name: info.name,
      role: info.role,
      amountUSD,
      fee,
      streams: info.streams,
      status,
      transferId,
    });
  }

  // Atomically: write ledger + mark tracks paid + write a payout summary.
  const batch = db.batch();
  for (const w of ledgerWrites) batch.set(w.ref, w.data);
  for (const trackId of trackIds) {
    batch.update(db.collection("music_tracks").doc(trackId), {
      lastPaidAt: now,
      lastPayoutGroup: transferGroup,
    });
  }
  const summaryRef = db.collection("artist_payouts").doc();
  const ownerResult = results.find((r) => r.role === "owner");
  batch.set(summaryRef, {
    id: summaryRef.id,
    artistId: ownerArtistId,
    transferGroup,
    amount: ownerResult ? ownerResult.amountUSD : 0,
    totalDistributed: results.reduce((s, r) => s + r.amountUSD, 0),
    streams: ownerResult ? ownerResult.streams : 0,
    payees: results.length,
    periodLabel,
    payoutType: payoutType || "standard",
    status: "paid",
    paidAt: now,
  });
  await batch.commit();

  return { transferGroup, results };
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

    const ownerAccount = await getConnectedAccount(artistId);
    if (!ownerAccount) {
      return res.status(400).json({
        error: "Artist has not connected Stripe. Complete onboarding first.",
      });
    }

    const { perPayee, trackIds, totalGross } = await computeSettlement(artistId);

    if (totalGross < MINIMUM_PAYOUT_USD || trackIds.length === 0) {
      return res.status(200).json({
        success: false,
        message: `Payout of $${totalGross.toFixed(2)} is below the $${MINIMUM_PAYOUT_USD} minimum. Keep streaming!`,
        amountUSD: totalGross,
      });
    }

    const { transferGroup, results } = await executeSettlement({
      ownerArtistId: artistId,
      perPayee,
      trackIds,
      totalGross,
      payoutType: "standard",
    });

    return res.status(200).json({
      success: true,
      transferGroup,
      totalGrossUSD: totalGross,
      splits: results,
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
  const type = payoutType === "instant" ? "instant" : "standard";

  try {
    const decoded = await requireAuth(req);
    assertCanActForArtist(decoded, artistId);

    const ownerAccount = await getConnectedAccount(artistId);
    if (!ownerAccount) {
      return res.status(400).json({
        error: "Artist has not connected Stripe. Complete onboarding first.",
      });
    }

    const { perPayee, trackIds, totalGross } = await computeSettlement(artistId);
    if (totalGross <= 0 || trackIds.length === 0) {
      return res.status(200).json({
        success: false,
        message: `Insufficient balance for payout. Available: $${totalGross.toFixed(2)}`,
        availableUSD: totalGross,
      });
    }

    const { transferGroup, results } = await executeSettlement({
      ownerArtistId: artistId,
      perPayee,
      trackIds,
      totalGross,
      payoutType: type,
    });

    return res.status(200).json({
      success: true,
      transferGroup,
      payoutType: type,
      totalGrossUSD: totalGross,
      splits: results,
      estimatedDelivery: type === "instant" ? "1-2 business days" : "5-7 business days",
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

    const { perPayee, totalGross } = await computeSettlement(artistId);
    const owner = perPayee[artistId] || { gross: 0, streams: 0 };
    const instantAmount = owner.gross * (1 - INSTANT_PAYOUT_FEE_PCT);

    const splitPreview = Object.entries(perPayee).map(([payeeId, info]) => ({
      payeeId,
      payeeArtistId: info.linkedArtistId || null,
      name: info.name,
      role: info.role,
      amountUSD: Number(info.gross.toFixed(2)),
      streams: info.streams,
      payable: !!info.linkedArtistId,
    }));

    return res.status(200).json({
      artistId,
      totalGrossUSD: Number(totalGross.toFixed(2)),
      ownerAmountUSD: Number(owner.gross.toFixed(2)),
      ownerStreams: owner.streams || 0,
      instantPayoutAmountUSD: Number(Math.max(0, instantAmount).toFixed(2)),
      instantPayoutFeePct: INSTANT_PAYOUT_FEE_PCT,
      splitPreview,
      estimatedStandardDelivery: "5-7 business days",
      estimatedInstantDelivery: "1-2 business days",
    });
  } catch (err) {
    console.error("❌ Get available balance error:", err);
    return res.status(err.status || 500).json({ error: err.message || "Failed to get available balance" });
  }
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

    const account = await getConnectedAccount(artistId);
    if (!account) {
      return res.status(400).json({ error: "Connect Stripe before claiming earnings." });
    }

    const owedSnap = await db
      .collection("music_split_earnings")
      .where("payeeArtistId", "==", artistId)
      .where("status", "==", "owed")
      .get();

    if (owedSnap.empty) {
      return res.status(200).json({ success: false, message: "No owed earnings to claim." });
    }

    let totalUSD = 0;
    owedSnap.forEach((d) => (totalUSD += d.data().netAmount || 0));
    if (totalUSD <= 0) {
      return res.status(200).json({ success: false, message: "Nothing claimable." });
    }

    const transferGroup = `mychannel_music_claim_${artistId}_${Date.now()}`;
    const transfer = await getStripe().transfers.create({
      amount: roundCents(totalUSD),
      currency: "usd",
      destination: account,
      transfer_group: transferGroup,
      description: `MyChannel Music — claimed collaborator earnings`,
      metadata: { artistId, entries: String(owedSnap.size) },
    });

    const now = admin.firestore.Timestamp.now();
    const batch = db.batch();
    owedSnap.forEach((d) =>
      batch.update(d.ref, {
        status: "paid",
        stripeTransferId: transfer.id,
        claimedAt: now,
        paidAt: now,
      })
    );
    await batch.commit();

    return res.status(200).json({
      success: true,
      transferId: transfer.id,
      amountUSD: totalUSD,
      entries: owedSnap.size,
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
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET || "whsec_TODO";

  let event;
  try {
    event = getStripe().webhooks.constructEvent(req.rawBody, sig, webhookSecret);
  } catch (err) {
    console.error("Webhook signature verification failed:", err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  try {
    if (event.type === "account.updated") {
      const account = event.data.object;
      const ready = account.details_submitted && account.charges_enabled;
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
            connected: true,
            chargesEnabled: account.charges_enabled || false,
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

