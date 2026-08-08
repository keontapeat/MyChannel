/**
 * AGI Agent Scheduler — Cloud Function that triggers agents on schedule.
 *
 * Deployed as a Firebase Scheduled Function (Cloud Scheduler + Pub/Sub).
 * Runs every 5 minutes and dispatches agents based on their configured intervals.
 *
 * Architecture:
 * - Cloud Scheduler → Pub/Sub → This function
 * - Function reads agent registry from Firestore
 * - Dispatches due agents by writing to `agi_agent_runs` collection
 * - Each agent run is picked up by the web client's AGIAgentManager (or a
 *   dedicated Cloud Run worker in production)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();

// Agent definitions with their run intervals (seconds)
const AGENT_REGISTRY = [
  { id: 'dynamic-pricing-agent', interval: 300, category: 'money_maker' },
  { id: 'ad-bidding-agent', interval: 60, category: 'money_maker' },
  { id: 'revenue-maximizer-agent', interval: 900, category: 'money_maker' },
  { id: 'creator-payout-agent', interval: 1800, category: 'money_maker' },
  { id: 'subscription-optimizer-agent', interval: 3600, category: 'money_maker' },
  { id: 'viral-prediction-agent', interval: 600, category: 'growth' },
  { id: 'retention-predictor-agent', interval: 3600, category: 'growth' },
  { id: 'onboarding-optimizer-agent', interval: 7200, category: 'growth' },
  { id: 'subscriber-growth-agent', interval: 1800, category: 'growth' },
  { id: 'match-orchestrator-agent', interval: 300, category: 'gaming' },
  { id: 'anti-cheat-agent', interval: 300, category: 'gaming' },
  { id: 'fairness-agent', interval: 600, category: 'gaming' },
  { id: 'tournament-agent', interval: 300, category: 'gaming' },
  { id: 'content-moderation-agent', interval: 120, category: 'safety' },
  { id: 'fraud-detection-agent', interval: 120, category: 'safety' },
  { id: 'copyright-detection-agent', interval: 300, category: 'safety' },
  { id: 'toxicity-filter-agent', interval: 30, category: 'safety' },
  { id: 'age-verification-agent', interval: 600, category: 'safety' },
  { id: 'creator-analytics-agent', interval: 900, category: 'analytics' },
  { id: 'watch-time-analytics-agent', interval: 1800, category: 'analytics' },
  { id: 'thumbnail-optimizer-agent', interval: 900, category: 'analytics' },
  { id: 'audience-insights-agent', interval: 3600, category: 'analytics' },
  { id: 'cdn-optimizer-agent', interval: 600, category: 'scale' },
  { id: 'cost-optimizer-agent', interval: 3600, category: 'scale' },
  { id: 'smart-notification-agent', interval: 900, category: 'scale' },
  { id: 'auto-scaler-agent', interval: 600, category: 'scale' },
];

/**
 * Scheduled function: runs every 5 minutes.
 * Checks which agents are due and dispatches them.
 */
exports.dispatchAgents = functions.pubsub
  .schedule('every 5 minutes')
  .timeZone('America/Los_Angeles')
  .onRun(async (context) => {
    const now = Date.now();
    const batch = db.batch();
    let dispatched = 0;

    for (const agent of AGENT_REGISTRY) {
      const lastRunRef = db.collection('agi_agent_state').doc(agent.id);
      const lastRunSnap = await lastRunRef.get();
      const lastRunAt = lastRunSnap.data()?.lastRunAt?.toMillis?.() || 0;
      const elapsed = (now - lastRunAt) / 1000;

      if (elapsed >= agent.interval) {
        // Agent is due — dispatch it
        const runRef = db.collection('agi_agent_runs').doc();
        batch.set(runRef, {
          agentId: agent.id,
          category: agent.category,
          status: 'pending',
          dispatchedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Update last run time
        batch.set(lastRunRef, {
          lastRunAt: admin.firestore.FieldValue.serverTimestamp(),
          status: 'dispatched',
        }, { merge: true });

        dispatched++;
      }
    }

    if (dispatched > 0) {
      await batch.commit();
      console.log(`🤖 [AGI Scheduler] Dispatched ${dispatched} agents at ${new Date().toISOString()}`);
    }

    // Update scheduler health
    await db.collection('platform').doc('agi_health').set({
      lastSchedulerRun: admin.firestore.FieldValue.serverTimestamp(),
      agentsDispatched: dispatched,
      totalAgents: AGENT_REGISTRY.length,
      status: 'healthy',
    }, { merge: true });

    return null;
  });

/**
 * HTTP endpoint for manual agent triggering (admin only).
 * POST /triggerAgent { agentId: string }
 */
exports.triggerAgent = functions.https.onCall(async (data, context) => {
  // Require authenticated admin
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  const role = userDoc.data()?.role;
  if (role !== 'admin' && role !== 'moderator') {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { agentId } = data;
  if (!agentId || !AGENT_REGISTRY.find((a) => a.id === agentId)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid agent ID');
  }

  const runRef = db.collection('agi_agent_runs').doc();
  await runRef.set({
    agentId,
    category: AGENT_REGISTRY.find((a) => a.id === agentId)?.category || 'unknown',
    status: 'pending',
    triggeredBy: context.auth.uid,
    dispatchedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await db.collection('agi_agent_state').doc(agentId).set({
    lastRunAt: admin.firestore.FieldValue.serverTimestamp(),
    status: 'manually_triggered',
    triggeredBy: context.auth.uid,
  }, { merge: true });

  return { success: true, runId: runRef.id, agentId };
});

/**
 * Real-time listener: when an agent run is marked 'completed', aggregate metrics.
 */
exports.onAgentRunComplete = functions.firestore
  .document('agi_agent_runs/{runId}')
  .onUpdate(async (change, context) => {
    const after = change.after.data();
    const before = change.before.data();

    if (before.status === 'pending' && after.status === 'completed') {
      // Increment run counter
      const stateRef = db.collection('agi_agent_state').doc(after.agentId);
      await stateRef.set({
        totalRuns: admin.firestore.FieldValue.increment(1),
        lastCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastDurationMs: after.durationMs || 0,
        status: 'idle',
      }, { merge: true });
    }

    if (before.status === 'pending' && after.status === 'failed') {
      const stateRef = db.collection('agi_agent_state').doc(after.agentId);
      await stateRef.set({
        totalErrors: admin.firestore.FieldValue.increment(1),
        lastError: after.error || 'Unknown error',
        lastErrorAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'error',
      }, { merge: true });
    }

    return null;
  });
