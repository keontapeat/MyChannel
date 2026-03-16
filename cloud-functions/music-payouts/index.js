/**
 * music-payouts/index.js
 * MyChannel Music — Stripe Connect payout trigger
 *
 * Environment variables (set in GCP Cloud Functions console or .env):
 *   STRIPE_SECRET_KEY      — sk_live_... (or sk_test_... for testing)
 *   STRIPE_WEBHOOK_SECRET  — whsec_... (from Stripe Dashboard > Webhooks)
 *
 * Deploy:
 *   gcloud functions deploy payoutArtist \
 *     --runtime nodejs20 \
 *     --trigger-http \
 *     --allow-unauthenticated \
 *     --set-env-vars STRIPE_SECRET_KEY=sk_live_TODO,STRIPE_WEBHOOK_SECRET=whsec_TODO
 */

const admin = require("firebase-admin");
const { Stripe } = require("stripe");

// TODO: Set STRIPE_SECRET_KEY in Cloud Function environment variables
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || "sk_test_TODO", {
  apiVersion: "2024-04-10",
});

const PAYOUT_RATE_USD = 0.004; // $0.004 per stream
const MINIMUM_PAYOUT_USD = 10.0; // $10 minimum to trigger payout

if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

/**
 * POST /payoutArtist
 * Body: { artistId: string }
 *
 * Calculates streams for the current month, triggers a Stripe transfer
 * to the artist's connected account, and records the payout in Firestore.
 */
exports.payoutArtist = async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type,Authorization");
    return res.status(204).send("");
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const { artistId } = req.body || {};
  if (!artistId) {
    return res.status(400).json({ error: "artistId is required" });
  }

  try {
    // 1. Fetch artist's Stripe connected account ID
    const stripeDoc = await db.collection("artist_stripe").doc(artistId).get();
    if (!stripeDoc.exists || !stripeDoc.data().stripeAccountId) {
      return res.status(400).json({
        error: "Artist has not connected Stripe. Complete onboarding first.",
      });
    }
    const stripeAccountId = stripeDoc.data().stripeAccountId;

    // 2. Sum unpaid streams from music_tracks
    const tracksSnap = await db
      .collection("music_tracks")
      .where("artistId", "==", artistId)
      .where("lastPaidAt", "==", null)
      .get();

    // Also fetch tracks paid before this month
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    const unpaidTracksSnap = await db
      .collection("music_tracks")
      .where("artistId", "==", artistId)
      .get();

    let unpaidStreams = 0;
    const trackIds = [];
    unpaidTracksSnap.forEach((doc) => {
      const data = doc.data();
      const lastPaid = data.lastPaidAt ? data.lastPaidAt.toDate() : null;
      if (!lastPaid || lastPaid < monthStart) {
        unpaidStreams += data.streamCount || 0;
        trackIds.push(doc.id);
      }
    });

    const payoutAmountUSD = unpaidStreams * PAYOUT_RATE_USD;

    if (payoutAmountUSD < MINIMUM_PAYOUT_USD) {
      return res.status(200).json({
        success: false,
        message: `Payout of $${payoutAmountUSD.toFixed(2)} is below the $${MINIMUM_PAYOUT_USD} minimum. Keep streaming!`,
        streams: unpaidStreams,
        amountUSD: payoutAmountUSD,
      });
    }

    // 3. Create Stripe Transfer to artist's connected account
    const amountCents = Math.floor(payoutAmountUSD * 100);
    const transfer = await stripe.transfers.create({
      amount: amountCents,
      currency: "usd",
      destination: stripeAccountId,
      description: `MyChannel Music payout — ${unpaidStreams} streams @ $${PAYOUT_RATE_USD}/stream`,
      metadata: {
        artistId,
        streams: String(unpaidStreams),
        periodStart: monthStart.toISOString(),
        periodEnd: now.toISOString(),
      },
    });

    // 4. Record payout in Firestore
    const payoutRef = db.collection("artist_payouts").doc();
    await payoutRef.set({
      id: payoutRef.id,
      artistId,
      stripeTransferId: transfer.id,
      stripeAccountId,
      amount: payoutAmountUSD,
      amountCents,
      streams: unpaidStreams,
      periodLabel: now.toLocaleString("en-US", { month: "long", year: "numeric" }),
      periodStart: admin.firestore.Timestamp.fromDate(monthStart),
      periodEnd: admin.firestore.Timestamp.fromDate(now),
      status: "paid",
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 5. Mark tracks as paid this month
    const batch = db.batch();
    for (const trackId of trackIds) {
      batch.update(db.collection("music_tracks").doc(trackId), {
        lastPaidAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    console.log(
      `✅ Payout complete: $${payoutAmountUSD.toFixed(2)} → ${stripeAccountId} (${unpaidStreams} streams)`
    );

    return res.status(200).json({
      success: true,
      payoutId: payoutRef.id,
      transferId: transfer.id,
      amountUSD: payoutAmountUSD,
      streams: unpaidStreams,
    });
  } catch (err) {
    console.error("❌ Payout error:", err);
    return res.status(500).json({
      error: err.message || "Payout failed",
    });
  }
};

/**
 * POST /stripeWebhook
 * Handles Stripe Connect account.updated webhook to mark artist as connected.
 */
exports.stripeWebhook = async (req, res) => {
  const sig = req.headers["stripe-signature"];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET || "whsec_TODO";

  let event;
  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
  } catch (err) {
    console.error("Webhook signature verification failed:", err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  if (event.type === "account.updated") {
    const account = event.data.object;
    if (account.details_submitted && account.charges_enabled) {
      // Find artist by stripeAccountId and mark as connected
      const snap = await db
        .collection("artist_stripe")
        .where("stripeAccountId", "==", account.id)
        .limit(1)
        .get();
      if (!snap.empty) {
        await snap.docs[0].ref.update({
          connected: true,
          chargesEnabled: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`✅ Artist Stripe account verified: ${account.id}`);
      }
    }
  }

  if (event.type === "account.application.authorized") {
    // OAuth connect flow completed
    const account = event.data.object;
    const artistId = account.metadata?.artistId;
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
      console.log(`✅ New Stripe Connect account linked: ${artistId} → ${account.id}`);
    }
  }

  res.status(200).json({ received: true });
};
