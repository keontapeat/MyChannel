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

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

// Initialize Stripe with secret key from environment
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

// Platform fee percentage (10%)
const PLATFORM_FEE_PERCENT = 0.10;

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

/**
 * Main HTTP handler
 */
functions.http('escrowPayments', async (req, res) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders);
    res.status(204).send('');
    return;
  }

  res.set(corsHeaders);

  const path = req.path;

  try {
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
      case '/webhook':
        await handleStripeWebhook(req, res);
        break;
      case '/health':
        res.status(200).json({ status: 'healthy', stripe: 'connected' });
        break;
      default:
        res.status(404).json({ error: 'Not found' });
    }
  } catch (error) {
    console.error('Payment error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * CREATE ESCROW PAYMENT
 * Creates a PaymentIntent with capture_method=manual to hold funds
 */
async function handleCreateEscrowPayment(req, res) {
  const { customerId, amount, matchId, captureMethod } = req.body;

  if (!customerId || !amount || !matchId) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  // Validate amount (min $1, max $100,000)
  if (amount < 100 || amount > 10000000) {
    return res.status(400).json({ error: 'Amount must be between $1 and $100,000' });
  }

  console.log(`💰 Creating escrow payment: $${amount/100} for match ${matchId}`);

  // Create PaymentIntent with manual capture (holds funds)
  const paymentIntent = await stripe.paymentIntents.create({
    amount: amount, // Amount in cents
    currency: 'usd',
    customer: customerId,
    capture_method: captureMethod || 'manual', // Don't capture immediately
    metadata: {
      matchId: matchId,
      type: 'vs_match_escrow',
      createdAt: new Date().toISOString(),
    },
    description: `VS Match Wager - Match ${matchId}`,
    statement_descriptor: 'MYCHANNEL VS MATCH',
    // Auto-confirm if customer has default payment method
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
    amount: amount,
    status: 'requires_capture',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`✅ PaymentIntent created: ${paymentIntent.id}`);

  res.status(200).json({
    paymentIntentId: paymentIntent.id,
    clientSecret: paymentIntent.client_secret,
    status: paymentIntent.status,
  });
}

/**
 * CAPTURE PAYMENT
 * Captures a held payment after match completion
 */
async function handleCapturePayment(req, res) {
  const { paymentIntentId } = req.body;

  if (!paymentIntentId) {
    return res.status(400).json({ error: 'Missing paymentIntentId' });
  }

  console.log(`🔒 Capturing payment: ${paymentIntentId}`);

  // Capture the payment
  const paymentIntent = await stripe.paymentIntents.capture(paymentIntentId);

  // Update Firestore record
  await db.collection('stripe_escrow').doc(paymentIntentId).update({
    status: 'captured',
    capturedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`✅ Payment captured: ${paymentIntent.id}`);

  res.status(200).json({
    paymentIntentId: paymentIntent.id,
    status: paymentIntent.status,
    amountCaptured: paymentIntent.amount_received,
  });
}

/**
 * CANCEL PAYMENT
 * Cancels a held payment (refund)
 */
async function handleCancelPayment(req, res) {
  const { paymentIntentId } = req.body;

  if (!paymentIntentId) {
    return res.status(400).json({ error: 'Missing paymentIntentId' });
  }

  console.log(`❌ Cancelling payment: ${paymentIntentId}`);

  // Cancel the payment intent
  const paymentIntent = await stripe.paymentIntents.cancel(paymentIntentId);

  // Update Firestore record
  await db.collection('stripe_escrow').doc(paymentIntentId).update({
    status: 'canceled',
    canceledAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`✅ Payment canceled: ${paymentIntent.id}`);

  res.status(200).json({
    paymentIntentId: paymentIntent.id,
    status: paymentIntent.status,
  });
}

/**
 * CREATE TRANSFER
 * Transfers funds to winner via Stripe Connect
 */
async function handleCreateTransfer(req, res) {
  const { amount, destination, matchId } = req.body;

  if (!amount || !destination || !matchId) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  console.log(`💸 Creating transfer: $${amount/100} to ${destination}`);

  // Calculate platform fee
  const platformFee = Math.round(amount * PLATFORM_FEE_PERCENT);
  const transferAmount = amount - platformFee;

  // Create transfer to winner's Connect account
  const transfer = await stripe.transfers.create({
    amount: transferAmount,
    currency: 'usd',
    destination: destination, // Stripe Connect account ID
    metadata: {
      matchId: matchId,
      type: 'vs_match_winner_payout',
      platformFee: platformFee,
      grossAmount: amount,
    },
    description: `VS Match Winner Payout - Match ${matchId}`,
  });

  // Record transaction in Firestore
  await db.collection('stripe_transfers').doc(transfer.id).set({
    transferId: transfer.id,
    matchId: matchId,
    destination: destination,
    grossAmount: amount,
    platformFee: platformFee,
    netAmount: transferAmount,
    status: 'paid',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Record platform revenue
  await db.collection('platform_revenue').add({
    type: 'vs_match_fee',
    matchId: matchId,
    amount: platformFee,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`✅ Transfer created: ${transfer.id} ($${transferAmount/100} after $${platformFee/100} fee)`);

  res.status(200).json({
    transferId: transfer.id,
    amount: transferAmount,
    platformFee: platformFee,
    status: transfer.status,
  });
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

  // Handle specific events
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

    default:
      console.log(`Unhandled event type: ${event.type}`);
  }

  res.status(200).json({ received: true });
}

// Webhook handlers
async function handlePaymentSucceeded(paymentIntent) {
  console.log(`✅ Payment succeeded: ${paymentIntent.id}`);
  
  await db.collection('stripe_escrow').doc(paymentIntent.id).update({
    status: 'succeeded',
    succeededAt: admin.firestore.FieldValue.serverTimestamp(),
  });
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

module.exports = { stripe };





