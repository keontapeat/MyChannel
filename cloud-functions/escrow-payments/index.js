/**
 * 💰 STRIPE ESCROW CLOUD FUNCTIONS
 * Handles VS Match payments with Stripe Connect
 * 
 * Endpoints:
 * - POST /create-escrow-payment - Create payment intent (hold funds)
 * - POST /capture-payment - Capture held payment
 * - POST /cancel-payment - Cancel/refund held payment
 * - POST /create-transfer - Transfer to winner via Connect
 * - POST /webhook - Stripe webhook handler
 */

const functions = require('@google-cloud/functions-framework');
const Stripe = require('stripe');
const admin = require('firebase-admin');

// Initialize Firebase Admin once per Cloud Functions instance (cold start safe).
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

// Pin Stripe API version — must match server SDK + webhook event schema.
const STRIPE_API_VERSION = '2024-11-20.acacia';
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, {
  apiVersion: STRIPE_API_VERSION,
});

// Stable error codes for iOS / web clients (never rely on message text).
const MONEY_ERROR = {
  MISSING_FIELDS: 'MONEY_MISSING_FIELDS',
  INVALID_AMOUNT: 'MONEY_INVALID_AMOUNT',
  UNAUTHORIZED: 'MONEY_UNAUTHORIZED',
  FORBIDDEN: 'MONEY_FORBIDDEN',
  NOT_FOUND: 'MONEY_NOT_FOUND',
  CONFLICT: 'MONEY_CONFLICT',
  RATE_LIMITED: 'MONEY_RATE_LIMITED',
  COMPLIANCE_DENIED: 'MONEY_COMPLIANCE_DENIED',
  ESCROW_NOT_HELD: 'MONEY_ESCROW_NOT_HELD',
  INTERNAL: 'MONEY_INTERNAL',
};

const VALID_KYC_STATUSES = new Set(['none', 'pending', 'approved', 'rejected', 'expired']);

function moneyError(status, code, message) {
  const err = new Error(message);
  err.status = status;
  err.code = code;
  return err;
}

function jsonError(res, status, code, message) {
  return res.status(status).json({ error: message, code });
}

// Money endpoints that MUST be POST + Firebase-authenticated (webhook uses Stripe sig).
const MONEY_POST_PATHS = new Set([
  '/create-escrow-payment',
  '/capture-payment',
  '/cancel-payment',
  '/create-transfer',
  '/create-merch-order',
  '/refund-merch-order',
]);

function assertMoneyPostMethod(req, path) {
  if (!MONEY_POST_PATHS.has(path)) return;
  if (req.method !== 'POST') {
    throw moneyError(405, MONEY_ERROR.FORBIDDEN, `POST required for ${path}`);
  }
}

/**
 * Assert a VS Match has a verified, completed outcome BEFORE any transfer.
 * Throws 409 when status !== 'completed' or winnerId is missing.
 * See docs/backend-money-runbook.md
 */
function assertMatchOutcomeBeforeTransfer(match, matchId) {
  if (!match) {
    throw moneyError(404, MONEY_ERROR.NOT_FOUND, 'Match not found');
  }
  if (match.status !== 'completed' || !match.winnerId) {
    throw moneyError(
      409,
      MONEY_ERROR.CONFLICT,
      `Match ${matchId} is not completed with a verified winner`
    );
  }
  if (match.payoutTransferId) {
    throw moneyError(
      409,
      MONEY_ERROR.CONFLICT,
      'Winnings already paid out for this match'
    );
  }
  return match.winnerId;
}

/** Normalize region to US-XX (two-letter state) or pass through if already canonical. */
function normalizeRegion(raw) {
  if (!raw || typeof raw !== 'string') return null;
  const trimmed = raw.trim().toUpperCase();
  if (WAGER_POLICY.allowedRegions.has(trimmed)) return trimmed;
  // Accept bare state codes: CA → US-CA
  if (/^[A-Z]{2}$/.test(trimmed)) {
    const candidate = `US-${trimmed}`;
    if (WAGER_POLICY.allowedRegions.has(candidate)) return candidate;
  }
  return trimmed;
}

// Platform fee percentage (10%)
const PLATFORM_FEE_PERCENT = 0.10;

// ⚖️ WAGER POLICY — server-side source of truth. Mirrors the iOS WagerPolicy /
// VSMatchComplianceService so the client gate cannot be bypassed by a modified
// app. Client checks are UX only; THIS is authoritative for money.
const WAGER_POLICY = {
  minimumAge: 18,
  kycRequiredAboveDollars: 500,
  // Must match iOS WagerPolicy.currentTermsVersion / web wager-policy.ts
  currentTermsVersion: '2025.1',
  // Per-account-tier daily wager limit (USD). Must match WagerPolicy.dailyLimitDollars.
  dailyLimitDollars: { new: 100, verified: 1000, premium: 10000, vip: 100000 },
  // US states + DC where skill-based real-money play is offered.
  allowedRegions: new Set([
    'US-CA', 'US-NY', 'US-TX', 'US-FL', 'US-IL', 'US-PA', 'US-OH',
    'US-GA', 'US-NC', 'US-MI', 'US-NJ', 'US-VA', 'US-WA', 'US-AZ',
    'US-MA', 'US-TN', 'US-IN', 'US-MO', 'US-MD', 'US-WI', 'US-CO',
    'US-MN', 'US-SC', 'US-AL', 'US-LA', 'US-KY', 'US-OR', 'US-OK',
    'US-CT', 'US-IA', 'US-UT', 'US-AR', 'US-NV', 'US-MS', 'US-KS',
    'US-NM', 'US-NE', 'US-WV', 'US-ID', 'US-HI', 'US-NH', 'US-ME',
    'US-RI', 'US-MT', 'US-DE', 'US-SD', 'US-ND', 'US-AK', 'US-DC',
    'US-VT', 'US-WY',
  ]),
};

/**
 * 🔒 SERVER-SIDE COMPLIANCE GATE for real-money match wagers.
 * Mirrors VSMatchComplianceService.canUserWager. Throws a 403 (with a combined
 * reason) if the authenticated user is not eligible to wager `amountCents`.
 * Enforced BEFORE any PaymentIntent is created, so funds are never held for an
 * ineligible user even if the client skipped its own gate.
 */
async function assertWagerCompliance(uid, amountCents) {
  const amountDollars = amountCents / 100;
  const reasons = [];

  // Compliance profile (age / KYC / terms) + user profile (region / status / tier).
  const [complianceSnap, userSnap] = await Promise.all([
    db.collection('vs_match_compliance').doc(uid).get(),
    db.collection('users').doc(uid).get(),
  ]);

  // Fail closed: missing compliance doc = deny (never treat absent profile as eligible).
  if (!complianceSnap.exists) {
    const err = moneyError(
      403,
      MONEY_ERROR.COMPLIANCE_DENIED,
      'Not eligible to wager: Compliance profile required'
    );
    throw err;
  }
  const compliance = complianceSnap.data();
  const user = userSnap.exists ? userSnap.data() : {};

  // Validate kycStatus enum when present.
  if (compliance.kycStatus != null && !VALID_KYC_STATUSES.has(compliance.kycStatus)) {
    reasons.push('Invalid KYC status on file — contact support');
  }

  // Validate termsVersion string when present (must match current pin).
  if (compliance.termsVersion != null) {
    if (typeof compliance.termsVersion !== 'string' || compliance.termsVersion.trim() === '') {
      reasons.push('Invalid terms version on file');
    } else if (compliance.termsVersion !== WAGER_POLICY.currentTermsVersion) {
      reasons.push(
        `Accept the current VS Match terms (v${WAGER_POLICY.currentTermsVersion})`
      );
    }
  }

  // 1. Age (18+). Require the verified flag; also re-check stored age if present.
  const ageOK = compliance.ageVerified === true &&
    (typeof compliance.age !== 'number' || compliance.age >= WAGER_POLICY.minimumAge);
  if (!ageOK) reasons.push('Age verification required (18+)');

  // 2. KYC for wagers over $500.
  if (amountDollars > WAGER_POLICY.kycRequiredAboveDollars && compliance.kycStatus !== 'approved') {
    reasons.push('KYC verification required for wagers over $500');
  }

  // 3. Terms of Service acceptance — require the current version pin.
  if (compliance.termsAccepted !== true) {
    reasons.push('Terms of Service must be accepted');
  } else if (!compliance.termsVersion) {
    reasons.push(`Accept the current VS Match terms (v${WAGER_POLICY.currentTermsVersion})`);
  }

  // 4. Region allowlist. Fail closed when unset — never default to an allowed region.
  const rawRegion = user.region || compliance.region;
  const region = normalizeRegion(rawRegion);
  if (!region || !WAGER_POLICY.allowedRegions.has(region)) {
    reasons.push('Real-money wagering is not available in your region');
  }

  // 5. Account status.
  const accountStatus = user.accountStatus || 'active';
  if (accountStatus !== 'active') {
    reasons.push('Account is not active for wagering');
  }

  // 6. Daily wager limit (sum of today's prior wagers + this one <= tier limit).
  // Window resets at UTC midnight — must stay aligned with iOS WagerPolicy comment.
  const tier = user.accountTier || 'new';
  const dailyLimit = WAGER_POLICY.dailyLimitDollars[tier] ?? WAGER_POLICY.dailyLimitDollars.new;
  const startOfDay = new Date();
  startOfDay.setUTCHours(0, 0, 0, 0);
  const wagerSnap = await db.collection('vs_match_transactions')
    .where('userId', '==', uid)
    .where('type', '==', 'wager')
    .where('createdAt', '>', admin.firestore.Timestamp.fromDate(startOfDay))
    .get();
  let wageredTodayUSD = 0;
  wagerSnap.forEach((d) => { wageredTodayUSD += Number(d.data().amount) || 0; });
  if (wageredTodayUSD + amountDollars > dailyLimit) {
    reasons.push('Daily wager limit exceeded');
  }

  if (reasons.length > 0) {
    throw moneyError(
      403,
      MONEY_ERROR.COMPLIANCE_DENIED,
      `Not eligible to wager: ${reasons.join('; ')}`
    );
  }
}

/** Write an immutable audit row for every real-money wager attempt (success or deny). */
async function writeWagerAudit({ uid, matchId, amountCents, outcome, code, detail }) {
  try {
    await db.collection('money_audit_log').add({
      userId: uid,
      matchId: matchId || null,
      amountCents,
      type: 'wager',
      outcome, // 'created' | 'denied' | 'captured' | 'canceled' | 'transferred'
      code: code || null,
      detail: detail || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    console.error('⚠️ Audit log write failed (non-fatal):', e.message);
  }
}

/** Increment daily money volume counters for FinOps dashboards. */
async function recordMoneyMetric(kind, amountCents) {
  if (!Number.isInteger(amountCents) || amountCents <= 0) return;
  const day = new Date().toISOString().slice(0, 10);
  const ref = db.collection('money_metrics_daily').doc(day);
  try {
    await ref.set({
      [kind]: admin.firestore.FieldValue.increment(amountCents),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  } catch (e) {
    console.error('⚠️ Metrics write failed (non-fatal):', e.message);
  }
}

// 🔒 Strict CORS allowlist — never reflect arbitrary origins on money endpoints.
// Native iOS/Android clients send no Origin header; web clients must match ALLOWED_ORIGINS.
// Do NOT use `Access-Control-Allow-Origin: *` on any route in this handler.
const ALLOWED_ORIGINS = new Set([
  'https://mychannel.live',
  'https://www.mychannel.live',
  'https://mychannel-ca26d.web.app',
  'https://mychannel-ca26d.firebaseapp.com',
]);

function setCors(req, res) {
  const origin = req.headers.origin;
  if (!origin) {
    // Native mobile clients send no Origin header.
    res.set('Access-Control-Allow-Origin', 'https://mychannel.live');
  } else if (ALLOWED_ORIGINS.has(origin)) {
    res.set('Access-Control-Allow-Origin', origin);
    res.set('Vary', 'Origin');
  }
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

const ADMIN_EMAILS = new Set([
  'keontapeat@mychannel.live',
  'keontapeat@gmail.com',
]);

// Simple in-memory rate limit for create-escrow-payment (per uid).
// Resets on cold start — use Redis / Firestore for multi-instance enforcement.
const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_MAX_REQUESTS = 10;
const rateLimitBuckets = new Map();

function checkRateLimit(uid) {
  const now = Date.now();
  const bucket = rateLimitBuckets.get(uid) || [];
  const recent = bucket.filter((ts) => now - ts < RATE_LIMIT_WINDOW_MS);
  if (recent.length >= RATE_LIMIT_MAX_REQUESTS) {
    const err = new Error('Rate limit exceeded — try again in a minute');
    err.status = 429;
    throw err;
  }
  recent.push(now);
  rateLimitBuckets.set(uid, recent);
}

function isAdmin(decoded) {
  return (
    decoded &&
    (decoded.admin === true ||
      (decoded.email_verified && ADMIN_EMAILS.has(decoded.email)))
  );
}

// 🔐 Verify the Firebase ID token on the Authorization: Bearer <token> header.
async function requireAuth(req) {
  const header = req.headers.authorization || req.headers.Authorization || '';
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match) {
    const err = new Error('Missing or malformed Authorization header');
    err.status = 401;
    throw err;
  }
  try {
    return await admin.auth().verifyIdToken(match[1]);
  } catch (e) {
    const err = new Error('Invalid or expired authentication token');
    err.status = 401;
    throw err;
  }
}

/**
 * Main HTTP handler
 */
functions.http('escrowPayments', async (req, res) => {
  setCors(req, res);

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  const path = req.path;

  try {
    assertMoneyPostMethod(req, path);
    switch (path) {
      case '/create-escrow-payment':
        await handleCreateEscrowPayment(req, res);
        break;
      case '/capture-payment':
        await handleCapturePayment(req, res);
        break;
      case '/cancel-payment':
        await handleCancelPayment(req, res);
        break;
      case '/create-transfer':
        await handleCreateTransfer(req, res);
        break;
      // 🛍️ MERCH (physical goods) — Stripe Connect destination charges.
      // Physical goods MUST use an external processor per Apple Guideline
      // 3.1.3(e); they are NOT Apple IAP.
      case '/create-merch-order':
        await handleCreateMerchOrder(req, res);
        break;
      case '/refund-merch-order':
        await handleRefundMerchOrder(req, res);
        break;
      case '/webhook':
        await handleStripeWebhook(req, res);
        break;
      case '/cleanup-expired-escrows':
        await handleCleanupExpiredEscrows(req, res);
        break;
      case '/health':
        res.status(200).json({ status: 'healthy', stripe: 'connected' });
        break;
      default:
        res.status(404).json({ error: 'Not found' });
    }
  } catch (error) {
    console.error('Payment error:', error);
    const status = error.status || 500;
    const code = error.code || MONEY_ERROR.INTERNAL;
    res.status(status).json({ error: error.message, code });
  }
});

/**
 * CREATE ESCROW PAYMENT
 * Creates a PaymentIntent with capture_method=manual to hold funds
 */
async function handleCreateEscrowPayment(req, res) {
  const decoded = await requireAuth(req);
  checkRateLimit(decoded.uid);
  const { amount, matchId, captureMethod } = req.body;

  if (!amount || !matchId) {
    return jsonError(res, 400, MONEY_ERROR.MISSING_FIELDS, 'Missing required fields');
  }

  // Validate amount (min $1, max $100,000) and ensure it is a clean integer of cents.
  // Reject zero, negative, and fractional cent values explicitly.
  if (!Number.isInteger(amount) || amount <= 0 || amount < 100 || amount > 10000000) {
    return jsonError(
      res,
      400,
      MONEY_ERROR.INVALID_AMOUNT,
      'Amount must be a positive whole number of cents between $1 and $100,000'
    );
  }

  const isWalletDeposit = matchId === 'wallet_deposit';

  // 🔐 Authorization. For a match wager the caller must be a participant. For a
  // wallet deposit the caller funds their OWN wallet (no match needed).
  if (!isWalletDeposit) {
    const matchSnap = await db.collection('versus_matches').doc(matchId).get();
    if (!matchSnap.exists) {
      return res.status(404).json({ error: 'Match not found' });
    }
    const match = matchSnap.data();
    const participants = [match.challengerId, match.opponentId].filter(Boolean);
    if (!isAdmin(decoded) && !participants.includes(decoded.uid)) {
      return res.status(403).json({ error: 'You are not a participant in this match' });
    }

    // 🔒 COMPLIANCE GATE (server-authoritative). Mirrors the iOS gate: 18+, KYC
    // for $500+, terms, region, account status, and daily limit. Enforced here
    // so a modified client can never hold funds for an ineligible wager.
    // Throws 403 with a combined reason on failure.
    try {
      await assertWagerCompliance(decoded.uid, amount);
    } catch (complianceErr) {
      await writeWagerAudit({
        uid: decoded.uid,
        matchId,
        amountCents: amount,
        outcome: 'denied',
        code: complianceErr.code || MONEY_ERROR.COMPLIANCE_DENIED,
        detail: complianceErr.message,
      });
      throw complianceErr;
    }
  }

  // 🔐 Resolve the Stripe customer SERVER-SIDE from the authenticated uid. We
  // never trust a client-supplied customerId — that prevents charging or
  // attaching funds to someone else's customer.
  const userSnap = await db.collection('users').doc(decoded.uid).get();
  const customerId = userSnap.exists ? userSnap.data().stripeCustomerId : null;
  if (!customerId) {
    return res.status(409).json({ error: 'No payment profile on file for this user' });
  }

  console.log(`💰 Creating ${isWalletDeposit ? 'wallet deposit' : 'escrow'} payment: $${amount/100} (${decoded.uid})`);

  // Create PaymentIntent. Wallet deposits capture automatically; match wagers
  // hold funds with manual capture.
  const paymentIntent = await stripe.paymentIntents.create({
    amount: amount, // Amount in cents
    currency: 'usd',
    customer: customerId,
    capture_method: isWalletDeposit ? 'automatic' : (captureMethod || 'manual'),
    metadata: {
      matchId: matchId,
      userId: decoded.uid,
      type: isWalletDeposit ? 'wallet_deposit' : 'vs_match_escrow',
      createdAt: new Date().toISOString(),
    },
    description: isWalletDeposit ? 'MyChannel Wallet Deposit' : `VS Match Wager - Match ${matchId}`,
    statement_descriptor: 'MYCHANNEL',
    automatic_payment_methods: {
      enabled: true,
      allow_redirects: 'never',
    },
  });

  // Store escrow record in Firestore
  await db.collection('stripe_escrow').doc(paymentIntent.id).set({
    paymentIntentId: paymentIntent.id,
    customerId: customerId,
    matchId: matchId,
    userId: decoded.uid,
    amount: amount,
    type: isWalletDeposit ? 'wallet_deposit' : 'vs_match_escrow',
    status: 'requires_capture',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 📋 Compliance: for real-money match wagers, record a 'wager' transaction so the
  // per-user daily wager limit can be enforced. VSMatchComplianceService.getDailyWagerAmount
  // sums vs_match_transactions where userId==uid, type=='wager', createdAt>startOfDay, and
  // reads `amount` in DOLLARS. Without this record the daily limit always summed to $0.
  if (!isWalletDeposit) {
    await db.collection('vs_match_transactions').add({
      userId: decoded.uid,
      type: 'wager',
      amount: amount / 100, // dollars, to match the limit reader
      matchId: matchId,
      paymentIntentId: paymentIntent.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await writeWagerAudit({
      uid: decoded.uid,
      matchId,
      amountCents: amount,
      outcome: 'created',
      code: null,
      detail: paymentIntent.id,
    });
    await recordMoneyMetric('wagerVolumeCents', amount);
  }

  console.log(`✅ PaymentIntent created: ${paymentIntent.id}`);

  res.status(200).json({
    paymentIntentId: paymentIntent.id,
    clientSecret: paymentIntent.client_secret,
    status: paymentIntent.status,
  });
}

/**
 * CAPTURE PAYMENT
 * Captures a held payment after match completion. Server-authorized only:
 * the caller must be an admin or a participant of the match the escrow belongs to.
 */
async function handleCapturePayment(req, res) {
  const decoded = await requireAuth(req);
  const { paymentIntentId } = req.body;

  if (!paymentIntentId) {
    return res.status(400).json({ error: 'Missing paymentIntentId' });
  }

  const escrowSnap = await db.collection('stripe_escrow').doc(paymentIntentId).get();
  if (!escrowSnap.exists) {
    return res.status(404).json({ error: 'Escrow record not found' });
  }
  const escrow = escrowSnap.data();
  await assertMatchParticipantOrAdmin(decoded, escrow.matchId);

  // Escrow capture only when funds are held (requires_capture).
  const existingPI = await stripe.paymentIntents.retrieve(paymentIntentId);
  if (existingPI.status !== 'requires_capture') {
    return jsonError(
      res,
      409,
      MONEY_ERROR.ESCROW_NOT_HELD,
      `Payment is not in a capturable state (status: ${existingPI.status})`
    );
  }

  console.log(`🔒 Capturing payment: ${paymentIntentId}`);

  // Capture the payment
  const paymentIntent = await stripe.paymentIntents.capture(paymentIntentId);

  // Update Firestore record
  await db.collection('stripe_escrow').doc(paymentIntentId).update({
    status: 'captured',
    capturedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await writeWagerAudit({
    uid: escrow.userId || decoded.uid,
    matchId: escrow.matchId,
    amountCents: escrow.amount,
    outcome: 'captured',
    code: null,
    detail: paymentIntentId,
  });
  await recordMoneyMetric('capturedVolumeCents', escrow.amount || 0);

  console.log(`✅ Payment captured: ${paymentIntent.id}`);

  res.status(200).json({
    paymentIntentId: paymentIntent.id,
    status: paymentIntent.status,
    amountCaptured: paymentIntent.amount_received,
  });
}

/**
 * CANCEL PAYMENT
 * Cancels a held payment (refund). Server-authorized only.
 * For match wagers, cancels ALL held escrow legs for the match so both
 * participants are refunded — never cancel only one leg.
 */
async function handleCancelPayment(req, res) {
  const decoded = await requireAuth(req);
  const { paymentIntentId, matchId: bodyMatchId } = req.body;

  // Bulk cancel by matchId — refunds both participants.
  if (!paymentIntentId && bodyMatchId) {
    return cancelAllEscrowForMatch(req, res, decoded, bodyMatchId);
  }

  if (!paymentIntentId) {
    return jsonError(res, 400, MONEY_ERROR.MISSING_FIELDS, 'Missing paymentIntentId or matchId');
  }

  const escrowSnap = await db.collection('stripe_escrow').doc(paymentIntentId).get();
  if (!escrowSnap.exists) {
    return jsonError(res, 404, MONEY_ERROR.NOT_FOUND, 'Escrow record not found');
  }
  const escrow = escrowSnap.data();
  await assertMatchParticipantOrAdmin(decoded, escrow.matchId);

  const existingPI = await stripe.paymentIntents.retrieve(paymentIntentId);
  if (!['requires_capture', 'requires_payment_method', 'requires_confirmation', 'requires_action'].includes(existingPI.status)) {
    return jsonError(
      res,
      409,
      MONEY_ERROR.ESCROW_NOT_HELD,
      `Payment is not in a cancellable state (status: ${existingPI.status})`
    );
  }

  console.log(`❌ Cancelling payment: ${paymentIntentId}`);

  const paymentIntent = await stripe.paymentIntents.cancel(paymentIntentId);

  await db.collection('stripe_escrow').doc(paymentIntentId).update({
    status: 'canceled',
    canceledAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await writeWagerAudit({
    uid: escrow.userId || decoded.uid,
    matchId: escrow.matchId,
    amountCents: escrow.amount,
    outcome: 'canceled',
    code: null,
    detail: paymentIntentId,
  });

  console.log(`✅ Payment canceled: ${paymentIntent.id}`);

  res.status(200).json({
    paymentIntentId: paymentIntent.id,
    status: paymentIntent.status,
  });
}

/** Cancel every held escrow leg for a match (both participants). */
async function cancelAllEscrowForMatch(req, res, decoded, matchId) {
  await assertMatchParticipantOrAdmin(decoded, matchId);

  const heldQuery = await db.collection('stripe_escrow')
    .where('matchId', '==', matchId)
    .where('status', '==', 'requires_capture')
    .get();

  if (heldQuery.empty) {
    return jsonError(res, 409, MONEY_ERROR.ESCROW_NOT_HELD, 'No held funds to cancel for this match');
  }

  const canceled = [];
  for (const doc of heldQuery.docs) {
    const row = doc.data();
    const piId = doc.id;
    try {
      const existingPI = await stripe.paymentIntents.retrieve(piId);
      if (existingPI.status === 'requires_capture') {
        await stripe.paymentIntents.cancel(piId);
      }
      await doc.ref.update({
        status: 'canceled',
        canceledAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await writeWagerAudit({
        uid: row.userId,
        matchId,
        amountCents: row.amount,
        outcome: 'canceled',
        code: null,
        detail: piId,
      });
      canceled.push(piId);
    } catch (e) {
      console.error(`⚠️ Failed to cancel ${piId}:`, e.message);
    }
  }

  res.status(200).json({ matchId, canceledPaymentIntentIds: canceled, count: canceled.length });
}

// Caller must be a participant in the match, or an admin.
async function assertMatchParticipantOrAdmin(decoded, matchId) {
  if (isAdmin(decoded)) return;
  if (!matchId) {
    const err = new Error('Escrow has no associated match');
    err.status = 400;
    throw err;
  }
  const matchSnap = await db.collection('versus_matches').doc(matchId).get();
  const match = matchSnap.exists ? matchSnap.data() : {};
  const participants = [match.challengerId, match.opponentId].filter(Boolean);
  if (!participants.includes(decoded.uid)) {
    const err = new Error('You are not authorized for this match');
    err.status = 403;
    throw err;
  }
}

/**
 * CREATE TRANSFER
 * Transfers winnings to the match winner via Stripe Connect.
 *
 * 🔐 HARDENED: the client may ONLY name the match. The winner, the payout
 * amount, and the destination account are all derived server-side from the
 * recorded match outcome and the captured escrow rows — never trusted from the
 * request body. This makes it impossible to redirect funds or inflate amounts.
 */
async function handleCreateTransfer(req, res) {
  const decoded = await requireAuth(req);
  const { matchId } = req.body;

  if (!matchId) {
    return res.status(400).json({ error: 'Missing matchId' });
  }

  // 1. Load the match and assert verified outcome BEFORE any transfer.
  const matchSnap = await db.collection('versus_matches').doc(matchId).get();
  if (!matchSnap.exists) {
    return res.status(404).json({ error: 'Match not found' });
  }
  const match = matchSnap.data();
  const participants = [match.challengerId, match.opponentId].filter(Boolean);
  if (!isAdmin(decoded) && !participants.includes(decoded.uid)) {
    return res.status(403).json({ error: 'You are not a participant in this match' });
  }
  const winnerId = assertMatchOutcomeBeforeTransfer(match, matchId);

  // ASSERT (money invariant): transfer amount, winner, and destination are SERVER-DERIVED.
  // The client body MUST contain only `matchId` — never `amount`, `destination`, or `winnerId`.
  // Pot = sum of captured stripe_escrow rows; payout account = users/{winnerId}.stripeConnectAccountId.

  // 2. Derive the pot from CAPTURED escrow rows for this match (never the body).
  const escrowQuery = await db
    .collection('stripe_escrow')
    .where('matchId', '==', matchId)
    .where('status', '==', 'captured')
    .get();
  let grossAmount = 0;
  escrowQuery.forEach((d) => { grossAmount += Number(d.data().amount) || 0; });
  if (grossAmount <= 0) {
    return res.status(409).json({ error: 'No captured funds available for this match' });
  }

  // 3. Resolve the winner's connected account from server records only.
  const winnerSnap = await db.collection('users').doc(winnerId).get();
  const destination = winnerSnap.exists ? winnerSnap.data().stripeConnectAccountId : null;
  if (!destination) {
    return res.status(409).json({ error: 'Winner has no connected payout account' });
  }

  const platformFee = Math.round(grossAmount * PLATFORM_FEE_PERCENT);
  const transferAmount = grossAmount - platformFee;

  console.log(`💸 Settling match ${matchId}: $${transferAmount/100} to winner ${winnerId}`);

  // 4. Create transfer to winner's Connect account, keyed for idempotency so a
  //    retry can never double-pay.
  const transfer = await stripe.transfers.create(
    {
      amount: transferAmount,
      currency: 'usd',
      destination: destination,
      metadata: {
        matchId: matchId,
        winnerId: winnerId,
        type: 'vs_match_winner_payout',
        platformFee: platformFee,
        grossAmount: grossAmount,
      },
      description: `VS Match Winner Payout - Match ${matchId}`,
    },
    { idempotencyKey: `vs_match_payout_${matchId}` }
  );

  // Record transaction in Firestore
  await db.collection('stripe_transfers').doc(transfer.id).set({
    transferId: transfer.id,
    matchId: matchId,
    winnerId: winnerId,
    destination: destination,
    grossAmount: grossAmount,
    platformFee: platformFee,
    netAmount: transferAmount,
    status: 'paid',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Mark the match as paid so it can never be settled twice.
  await matchSnap.ref.update({
    payoutTransferId: transfer.id,
    paidOutAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await writeWagerAudit({
    uid: winnerId,
    matchId,
    amountCents: transferAmount,
    outcome: 'transferred',
    code: null,
    detail: transfer.id,
  });
  await recordMoneyMetric('transferVolumeCents', transferAmount);

  // Record platform revenue
  await db.collection('platform_revenue').add({
    type: 'vs_match_fee',
    matchId: matchId,
    amount: platformFee,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 🏆 Update player stats + championship points SERVER-SIDE. These were
  // previously client-writable and therefore forgeable. This runs exactly once
  // per match (guarded above by the payoutTransferId single-settle check).
  // Best-effort: a stats failure must not fail the (already-completed) payout.
  try {
    const loserId = participants.find((p) => p !== winnerId) || null;
    await settleMatchStats({ matchId, winnerId, loserId, escrowQuery, transferAmount, platformFee });
  } catch (statsErr) {
    console.error(`⚠️ Stats settlement failed for match ${matchId} (payout already sent):`, statsErr.message);
  }

  console.log(`✅ Transfer created: ${transfer.id} ($${transferAmount/100} after $${platformFee/100} fee)`);

  res.status(200).json({
    transferId: transfer.id,
    amount: transferAmount,
    platformFee: platformFee,
    status: transfer.status,
  });
}

/**
 * 🛍️ CREATE MERCH ORDER  (PHYSICAL GOODS — Stripe, NOT Apple IAP)
 *
 * Apple Guideline 3.1.3(e): physical goods/services consumed outside the app
 * MUST use a payment method other than IAP. This endpoint charges the buyer via
 * Stripe and pays the creator through their connected account (destination
 * charge), taking the 10% platform fee.
 *
 * 🔐 Money-safety: the client may ONLY name the product + quantity + shipping
 * address. Price, stock, totals, and the destination account are all derived
 * SERVER-SIDE from Firestore. The client can never set the price or recipient.
 */
async function handleCreateMerchOrder(req, res) {
  const decoded = await requireAuth(req);
  const { productId, quantity, shippingAddress } = req.body;

  const qty = Number.isInteger(quantity) ? quantity : parseInt(quantity, 10);
  if (!productId || !Number.isInteger(qty) || qty < 1 || qty > 25) {
    return res.status(400).json({ error: 'Invalid product or quantity (1–25)' });
  }
  if (!shippingAddress || typeof shippingAddress !== 'object' ||
      !shippingAddress.line1 || !shippingAddress.city ||
      !shippingAddress.postalCode || !shippingAddress.country) {
    return res.status(400).json({ error: 'Complete shipping address is required for physical goods' });
  }

  // 1. Load the product server-side — this is the source of truth for price.
  const productSnap = await db.collection('creator_products').doc(productId).get();
  if (!productSnap.exists) {
    return res.status(404).json({ error: 'Product not found' });
  }
  const product = productSnap.data();
  if (product.isActive === false) {
    return res.status(409).json({ error: 'Product is not available' });
  }
  const creatorId = product.creatorId;
  if (!creatorId) {
    return res.status(409).json({ error: 'Product has no creator' });
  }
  if (creatorId === decoded.uid) {
    return res.status(409).json({ error: 'You cannot purchase your own product' });
  }

  // 2. Stock check (server-side).
  const stock = Number.isInteger(product.stock) ? product.stock : 0;
  if (stock < qty) {
    return res.status(409).json({ error: 'Not enough stock available' });
  }

  // 3. Money math in integer cents — never trust client amounts.
  const unitCents = Math.round(Number(product.price) * 100);
  if (!Number.isInteger(unitCents) || unitCents < 50) {
    return res.status(409).json({ error: 'Product price is invalid' });
  }
  const subtotalCents = unitCents * qty;
  // Flat shipping placeholder ($5.99). Real shipping/tax can be computed later.
  const shippingCents = 599;
  const totalCents = subtotalCents + shippingCents;
  const platformFeeCents = Math.round(subtotalCents * PLATFORM_FEE_PERCENT);

  // 4. Resolve buyer's Stripe customer + creator's connected account server-side.
  const buyerSnap = await db.collection('users').doc(decoded.uid).get();
  const customerId = buyerSnap.exists ? buyerSnap.data().stripeCustomerId : null;
  if (!customerId) {
    return res.status(409).json({ error: 'No payment profile on file. Add a payment method first.' });
  }
  const creatorSnap = await db.collection('users').doc(creatorId).get();
  const destination = creatorSnap.exists ? creatorSnap.data().stripeConnectAccountId : null;
  if (!destination) {
    return res.status(409).json({ error: 'This creator is not set up to receive payments yet' });
  }

  // 5. Pre-create the order row (pending) so the webhook can reconcile it.
  const orderRef = db.collection('merch_orders').doc();

  // 6. Destination charge: buyer pays, platform keeps fee, rest goes to creator.
  const paymentIntent = await stripe.paymentIntents.create(
    {
      amount: totalCents,
      currency: 'usd',
      customer: customerId,
      capture_method: 'automatic',
      application_fee_amount: platformFeeCents,
      transfer_data: { destination: destination },
      metadata: {
        type: 'merch_order',
        orderId: orderRef.id,
        productId: productId,
        creatorId: creatorId,
        buyerId: decoded.uid,
        quantity: String(qty),
        platformFeeCents: String(platformFeeCents),
      },
      description: `MyChannel Merch — ${product.name || productId}`,
      statement_descriptor_suffix: 'MERCH',
      automatic_payment_methods: { enabled: true, allow_redirects: 'never' },
    },
    { idempotencyKey: `merch_${orderRef.id}` }
  );

  await orderRef.set({
    orderId: orderRef.id,
    productId: productId,
    productName: product.name || '',
    creatorId: creatorId,
    buyerId: decoded.uid,
    quantity: qty,
    unitCents: unitCents,
    subtotalCents: subtotalCents,
    shippingCents: shippingCents,
    totalCents: totalCents,
    platformFeeCents: platformFeeCents,
    currency: 'usd',
    goodsType: 'physical',
    shippingAddress: {
      line1: String(shippingAddress.line1).slice(0, 200),
      line2: shippingAddress.line2 ? String(shippingAddress.line2).slice(0, 200) : '',
      city: String(shippingAddress.city).slice(0, 100),
      state: shippingAddress.state ? String(shippingAddress.state).slice(0, 100) : '',
      postalCode: String(shippingAddress.postalCode).slice(0, 20),
      country: String(shippingAddress.country).slice(0, 2).toUpperCase(),
    },
    status: 'pending',
    paymentIntentId: paymentIntent.id,
    fulfillment: 'unfulfilled',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`🛍️ Merch order ${orderRef.id} created: $${totalCents / 100} (creator ${creatorId})`);

  res.status(200).json({
    orderId: orderRef.id,
    paymentIntentId: paymentIntent.id,
    clientSecret: paymentIntent.client_secret,
    amount: totalCents,
    status: paymentIntent.status,
  });
}

/**
 * 🛍️ REFUND MERCH ORDER
 * Buyer (their own order) or creator (their product) or admin may refund.
 * Refunds the buyer; the connected-account transfer is reversed.
 */
async function handleRefundMerchOrder(req, res) {
  const decoded = await requireAuth(req);
  const { orderId } = req.body;
  if (!orderId) {
    return res.status(400).json({ error: 'Missing orderId' });
  }

  const orderSnap = await db.collection('merch_orders').doc(orderId).get();
  if (!orderSnap.exists) {
    return res.status(404).json({ error: 'Order not found' });
  }
  const order = orderSnap.data();

  const isParty = decoded.uid === order.buyerId || decoded.uid === order.creatorId;
  if (!isParty && !isAdmin(decoded)) {
    return res.status(403).json({ error: 'Not authorized to refund this order' });
  }
  if (order.status === 'refunded') {
    return res.status(409).json({ error: 'Order already refunded' });
  }
  if (order.status !== 'paid') {
    return res.status(409).json({ error: 'Only paid orders can be refunded' });
  }

  const refund = await stripe.refunds.create(
    {
      payment_intent: order.paymentIntentId,
      reverse_transfer: true,
      refund_application_fee: true,
      metadata: { orderId: orderId, type: 'merch_refund' },
    },
    { idempotencyKey: `merch_refund_${orderId}` }
  );

  await orderSnap.ref.update({
    status: 'refunded',
    refundId: refund.id,
    refundedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Restore stock.
  await db.collection('creator_products').doc(order.productId).set({
    stock: admin.firestore.FieldValue.increment(order.quantity || 0),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log(`↩️ Merch order ${orderId} refunded (${refund.id})`);
  res.status(200).json({ orderId: orderId, refundId: refund.id, status: 'refunded' });
}

/**
 * STRIPE WEBHOOK
 * Handles Stripe webhook events
 */
async function handleStripeWebhook(req, res) {
  const sig = req.headers['stripe-signature'];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  let event;

  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  console.log(`📩 Webhook received: ${event.type}`);

  // Idempotency: Stripe may retry the same event.id — process at most once.
  const eventRef = db.collection('stripe_webhook_events').doc(event.id);
  const prior = await eventRef.get();
  if (prior.exists) {
    console.log(`↩️ Duplicate webhook ignored: ${event.id}`);
    return res.status(200).json({ received: true, duplicate: true });
  }
  await eventRef.set({
    type: event.type,
    receivedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  let handlerError = null;
  // Handle specific events
  try {
    switch (event.type) {
      case 'payment_intent.succeeded':
        await handlePaymentSucceeded(event.data.object);
        break;

      case 'payment_intent.payment_failed':
        await handlePaymentFailed(event.data.object);
        break;

      case 'transfer.created':
        await handleTransferCreated(event.data.object);
        break;

      case 'payout.paid':
        await handlePayoutPaid(event.data.object);
        break;

      case 'account.updated':
        await handleAccountUpdated(event.data.object);
        break;

      case 'identity.verification_session.verified':
        await handleIdentityVerified(event.data.object);
        break;

      case 'identity.verification_session.requires_input':
      case 'identity.verification_session.canceled':
        await handleIdentityPendingOrCanceled(event.data.object);
        break;

      default:
        console.log(`Unhandled event type: ${event.type}`);
    }
    await eventRef.update({ processedAt: admin.firestore.FieldValue.serverTimestamp(), status: 'ok' });
  } catch (handlerErr) {
    handlerError = handlerErr;
    console.error(`❌ Webhook handler failed for ${event.id}:`, handlerErr.message);
    await eventRef.update({
      status: 'failed',
      error: handlerErr.message,
      failedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // Dead-letter queue for manual replay / alerting.
    await db.collection('stripe_webhook_dead_letter').doc(event.id).set({
      eventId: event.id,
      type: event.type,
      error: handlerErr.message,
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // Always 200 so Stripe does not infinite-retry poison events; dead-letter captures failures.
  res.status(200).json({ received: true, handlerError: handlerError ? handlerError.message : null });
}

// 🔐 Credit a VS-match wallet SERVER-SIDE (Admin SDK bypasses security rules).
// This is the ONLY place wallet balances move up — clients can never self-credit.
// Idempotent: a given sourceId (paymentIntent/transfer id) is applied at most once.
async function creditWallet(userId, amountCents, kind, sourceId) {
  if (!userId || !Number.isInteger(amountCents) || amountCents <= 0) return;
  const amountUSD = amountCents / 100;
  const ledgerRef = db.collection('vs_match_wallet_credits').doc(sourceId);
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(ledgerRef);
    if (existing.exists) return; // already applied — idempotent guard
    const walletRef = db.collection('vs_match_wallets').doc(userId);
    tx.set(
      walletRef,
      {
        availableBalance: admin.firestore.FieldValue.increment(amountUSD),
        lifetimeEarnings: admin.firestore.FieldValue.increment(amountUSD),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    tx.set(ledgerRef, {
      userId,
      amountUSD,
      kind, // 'wallet_deposit' | 'match_winnings'
      sourceId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  console.log(`✅ Credited $${amountUSD} to wallet ${userId} (${kind})`);
}

/**
 * 🏆 Server-authoritative match stats settlement. Writes win/loss records,
 * net earnings, and championship points from the VERIFIED match outcome and the
 * captured escrow legs — never from client input. Amounts are stored in dollars
 * to match the existing readers (player_stats.totalEarnings, etc.).
 */
async function settleMatchStats({ matchId, winnerId, loserId, escrowQuery, transferAmount, platformFee }) {
  // Per-user captured stake (cents) from the escrow legs.
  const stakeByUser = {};
  escrowQuery.forEach((d) => {
    const row = d.data();
    if (row.userId) stakeByUser[row.userId] = (stakeByUser[row.userId] || 0) + (Number(row.amount) || 0);
  });

  const winnerStakeCents = stakeByUser[winnerId] || 0;
  const loserStakeCents = loserId
    ? (stakeByUser[loserId] || 0)
    : Math.max(0, (transferAmount + platformFee) - winnerStakeCents);
  // Net profit for the winner = what they received minus what they staked.
  const winnerProfitUSD = Math.max(0, (transferAmount - winnerStakeCents)) / 100;
  const loserLossUSD = loserStakeCents / 100;
  // Championship points: 100 base + 1 point per $10 wagered (winner's stake).
  const points = 100 + Math.floor((winnerStakeCents / 100) / 10);
  const now = admin.firestore.FieldValue.serverTimestamp();
  const inc = admin.firestore.FieldValue.increment;

  const batch = db.batch();
  batch.set(db.collection('player_stats').doc(winnerId), {
    wins: inc(1),
    totalEarnings: inc(winnerProfitUSD),
    lastMatchDate: now,
  }, { merge: true });

  if (loserId) {
    batch.set(db.collection('player_stats').doc(loserId), {
      losses: inc(1),
      totalLosses: inc(loserLossUSD),
      lastMatchDate: now,
    }, { merge: true });
  }

  batch.set(db.collection('championship_rankings').doc(winnerId), {
    points: inc(points),
    lastWin: now,
  }, { merge: true });

  await batch.commit();
  console.log(`🏆 Settled stats for match ${matchId}: winner +${points} pts, +$${winnerProfitUSD}`);
}

// Webhook handlers
async function handlePaymentSucceeded(paymentIntent) {
  console.log(`✅ Payment succeeded: ${paymentIntent.id}`);
  
  await db.collection('stripe_escrow').doc(paymentIntent.id).set({
    status: 'succeeded',
    succeededAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  // 🔐 Credit the user's in-app wallet ONLY after Stripe confirms the charge.
  if (paymentIntent.metadata && paymentIntent.metadata.type === 'wallet_deposit') {
    await creditWallet(
      paymentIntent.metadata.userId,
      paymentIntent.amount_received || paymentIntent.amount,
      'wallet_deposit',
      paymentIntent.id
    );
  }

  // 🛍️ Finalize a merch order once Stripe confirms payment. Idempotent: the
  // transaction no-ops if the order is already marked paid, so duplicate webhook
  // deliveries can't double-decrement stock.
  if (paymentIntent.metadata && paymentIntent.metadata.type === 'merch_order') {
    await finalizeMerchOrder(paymentIntent);
  }
}

// Mark a merch order paid and decrement product stock atomically + idempotently.
async function finalizeMerchOrder(paymentIntent) {
  const orderId = paymentIntent.metadata.orderId;
  const productId = paymentIntent.metadata.productId;
  const quantity = parseInt(paymentIntent.metadata.quantity, 10) || 0;
  if (!orderId) return;

  const orderRef = db.collection('merch_orders').doc(orderId);
  await db.runTransaction(async (tx) => {
    const orderDoc = await tx.get(orderRef);
    if (!orderDoc.exists) return;
    if (orderDoc.data().status === 'paid') return; // already finalized

    tx.update(orderRef, {
      status: 'paid',
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (productId && quantity > 0) {
      const productRef = db.collection('creator_products').doc(productId);
      tx.set(productRef, {
        stock: admin.firestore.FieldValue.increment(-quantity),
        salesCount: admin.firestore.FieldValue.increment(quantity),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    // Record platform revenue for the merch fee.
    const feeCents = parseInt(paymentIntent.metadata.platformFeeCents, 10);
    const revRef = db.collection('platform_revenue').doc(`merch_${orderId}`);
    tx.set(revRef, {
      type: 'merch_fee',
      orderId: orderId,
      creatorId: paymentIntent.metadata.creatorId || null,
      amount: Number.isInteger(feeCents) ? feeCents : null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  console.log(`🛍️ Merch order ${orderId} finalized as paid`);
}

async function handlePaymentFailed(paymentIntent) {
  console.log(`❌ Payment failed: ${paymentIntent.id}`);
  
  await db.collection('stripe_escrow').doc(paymentIntent.id).update({
    status: 'failed',
    failedAt: admin.firestore.FieldValue.serverTimestamp(),
    failureMessage: paymentIntent.last_payment_error?.message,
  });
}

async function handleTransferCreated(transfer) {
  console.log(`💸 Transfer created: ${transfer.id}`);
  
  await db.collection('stripe_transfers').doc(transfer.id).update({
    status: 'created',
    transferredAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function handlePayoutPaid(payout) {
  console.log(`💰 Payout completed: ${payout.id}`);
  
  // Update user's payout status
  if (payout.metadata?.userId) {
    await db.collection('users').doc(payout.metadata.userId).update({
      lastPayoutAt: admin.firestore.FieldValue.serverTimestamp(),
      lastPayoutAmount: payout.amount,
    });
  }
}

async function handleAccountUpdated(account) {
  console.log(`👤 Account updated: ${account.id}`);
  
  // Update Connect account status in Firestore
  const userSnapshot = await db.collection('users')
    .where('stripeConnectAccountId', '==', account.id)
    .limit(1)
    .get();
  
  if (!userSnapshot.empty) {
    const userDoc = userSnapshot.docs[0];
    await userDoc.ref.update({
      stripeAccountStatus: account.details_submitted ? 'active' : 'incomplete',
      stripePayoutsEnabled: account.payouts_enabled,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

// MARK: - Scheduled stub (not wired to Cloud Scheduler yet)
// Daily wager limits are windowed in assertWagerCompliance (UTC startOfDay query).
// Deploy this when/if persistent daily counters are added to vs_match_compliance.
//
// async function resetDailyWagerLimits() {
//   console.log('[reset_daily_wager_limits] noop — limits reset automatically at UTC midnight');
// }

/** Marks held escrow rows past ESCROW_HOLD_TTL_MS as expired (admin/cron). */
const ESCROW_HOLD_TTL_MS = 7 * 24 * 60 * 60 * 1000;

async function handleCleanupExpiredEscrows(req, res) {
  const decoded = await requireAuth(req);
  if (!isAdmin(decoded)) {
    return res.status(403).json({ error: 'Admin only' });
  }
  const cutoff = Date.now() - ESCROW_HOLD_TTL_MS;
  const snap = await db.collection('escrow').where('status', '==', 'held').get();
  let updated = 0;
  const batch = db.batch();
  snap.forEach((doc) => {
    const heldAt = doc.data().heldAt?.toDate?.()?.getTime?.() ?? 0;
    if (heldAt > 0 && heldAt < cutoff) {
      batch.update(doc.ref, {
        status: 'expired',
        expiredAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      updated += 1;
    }
  });
  if (updated > 0) await batch.commit();
  console.log(`🧹 Expired escrow cleanup: ${updated} rows`);
  res.status(200).json({ expired: updated });
}

/**
 * KYC approved webhook — updates Firestore, sets ageVerified, clears session id.
 * Session id is stored only while kycStatus is pending.
 */
async function handleIdentityVerified(session) {
  const userId = session.metadata?.userId;
  if (!userId) {
    console.warn('identity.verified missing metadata.userId');
    return;
  }
  const dob = session.verified_outputs?.dob;
  let age = null;
  if (dob?.year) {
    const now = new Date();
    age = now.getFullYear() - dob.year;
  }
  await db.collection('vs_match_compliance').doc(userId).set({
    kycStatus: 'approved',
    kycApprovedAt: admin.firestore.FieldValue.serverTimestamp(),
    ageVerified: true,
    age: age,
    stripeIdentitySessionId: admin.firestore.FieldValue.delete(),
    verificationMethod: 'stripe_identity',
  }, { merge: true });
  console.log(`✅ KYC approved for ${userId}`);
}

async function handleIdentityPendingOrCanceled(session) {
  const userId = session.metadata?.userId;
  if (!userId) return;
  const status = session.status === 'canceled' ? 'rejected' : 'pending';
  const patch = {
    kycStatus: status,
    stripeIdentitySessionId: session.id,
    verificationMethod: 'stripe_identity',
  };
  if (status === 'rejected') {
    patch.stripeIdentitySessionId = admin.firestore.FieldValue.delete();
  }
  await db.collection('vs_match_compliance').doc(userId).set(patch, { merge: true });
}

module.exports = { stripe };













