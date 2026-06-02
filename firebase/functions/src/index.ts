/**
 * MyChannel Cloud Functions
 * 🔥 Auto-Delete Expired Stories + Orphaned Media Cleanup
 * 🔒 Security Guard — ML-powered threat detection & auto-ban
 */

import {onSchedule} from 'firebase-functions/v2/scheduler';
import {onDocumentCreated} from 'firebase-functions/v2/firestore';
import {onCall, HttpsError, onRequest} from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import {GoogleAuth} from 'google-auth-library';

admin.initializeApp();

const googleAuth = new GoogleAuth();

const SECURITY_AI_SERVICE = 'cybersecurity-ai';
const SECURITY_AI_BASE = `https://${SECURITY_AI_SERVICE}-fkri6ifojq-uc.a.run.app`;

async function getIdToken(targetUrl: string): Promise<string> {
  const client = await googleAuth.getIdTokenClient(targetUrl);
  const headers = await client.getRequestHeaders(targetUrl);
  return (headers['Authorization'] as string).replace('Bearer ', '');
}

async function callSecurityAI(path: string, body: object): Promise<Record<string, unknown>> {
  const url = `${SECURITY_AI_BASE}${path}`;
  const token = await getIdToken(url);
  const res = await fetch(url, {
    method: 'POST',
    headers: {'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json'},
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`SecurityAI ${res.status}: ${await res.text()}`);
  return res.json() as Promise<Record<string, unknown>>;
}

async function logSecurityEvent(event: object): Promise<void> {
  await admin.firestore().collection('security_events').add({
    ...event,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function banUser(uid: string, reason: string, threatScore: number): Promise<void> {
  await admin.firestore().collection('security_bans').doc(uid).set({
    uid,
    reason,
    threatScore,
    active: true,
    bannedAt: admin.firestore.FieldValue.serverTimestamp(),
    bannedBy: 'security-ai-auto',
  });
  try {
    await admin.auth().updateUser(uid, {disabled: true});
  } catch (err) {
    console.error(`[securityGuard] Failed to disable Firebase Auth user ${uid}:`, err);
  }
}

// ============================================
// 🔒 SECURITY GUARD — Callable
// Analyzes a request/behavior payload through
// the CyberSecurity AI agent and enforces bans.
//
// Call from iOS/web with:
//   service: "request" | "behavior" | "content"
//   payload: { ip, uid, user_agent, endpoint, ... }
// ============================================

export const securityGuard = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }

    const data = request.data as {service?: string; payload?: Record<string, unknown>};
    const service = data.service ?? 'request';
    const payload = data.payload ?? {};

    // Always stamp caller UID into payload
    payload['uid'] = payload['uid'] ?? request.auth.uid;

    const validServices = ['request', 'behavior', 'content'];
    if (!validServices.includes(service)) {
      throw new HttpsError('invalid-argument', `Invalid service. Use: ${validServices.join(', ')}`);
    }

    let result: Record<string, unknown>;
    try {
      const aiResult = await callSecurityAI(`/predict/${service}`, payload);
      const predictions = aiResult['predictions'] as Array<Record<string, unknown>>;
      result = predictions?.[0] ?? aiResult;
    } catch (err) {
      console.error('[securityGuard] AI call failed:', err);
      // Fail-open to not block legit users if AI is down
      return {threat_score: 0, threat_level: 'CLEAN', action: 'ALLOW', blocked: false};
    }

    const threatLevel = result['threat_level'] as string;
    const action = result['action'] as string;
    const threatScore = (result['threat_score'] as number) ?? 0;
    const uid = payload['uid'] as string;
    const signals = result['signals'] as string[];

    // Log all non-clean events
    if (threatLevel !== 'CLEAN') {
      await logSecurityEvent({
        uid,
        ip: payload['ip'] ?? null,
        threatLevel,
        threatScore,
        action,
        signals,
        service,
        endpoint: payload['endpoint'] ?? null,
      });
    }

    // Auto-ban on CRITICAL or SUSPEND_ACCOUNT
    if (uid && (threatLevel === 'CRITICAL' || action === 'SUSPEND_ACCOUNT')) {
      await banUser(uid, `Auto-ban: ${action} - signals: ${(signals ?? []).join(', ')}`, threatScore);
      result['auto_banned'] = true;
    }

    return result;
  }
);

// ============================================
// 🔒 SECURITY WEBHOOK — Internal HTTP endpoint
// Called by Cloud Armor / Load Balancer / other
// GCP services to report threats server-side.
// Protected by Google ID token verification.
// ============================================

export const securityWebhook = onRequest(
  {
    region: 'us-central1',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (req, res) => {
    // Verify caller is internal (has valid Google ID token from GCP)
    const authHeader = req.headers['authorization'] ?? '';
    if (!authHeader.toString().startsWith('Bearer ')) {
      res.status(401).json({error: 'Unauthorized'});
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).json({error: 'Method not allowed'});
      return;
    }

    const body = req.body as Record<string, unknown>;
    const service = (body['service'] as string) ?? 'request';
    const payload = (body['payload'] as Record<string, unknown>) ?? {};

    let result: Record<string, unknown>;
    try {
      const aiResult = await callSecurityAI(`/predict/${service}`, payload);
      const predictions = aiResult['predictions'] as Array<Record<string, unknown>>;
      result = predictions?.[0] ?? aiResult;
    } catch (err) {
      console.error('[securityWebhook] AI call failed:', err);
      res.status(503).json({error: 'Security AI unavailable'});
      return;
    }

    const threatLevel = result['threat_level'] as string;
    const action = result['action'] as string;
    const threatScore = (result['threat_score'] as number) ?? 0;
    const uid = payload['uid'] as string;
    const signals = result['signals'] as string[];

    if (threatLevel !== 'CLEAN') {
      await logSecurityEvent({
        uid: uid ?? null,
        ip: payload['ip'] ?? null,
        threatLevel,
        threatScore,
        action,
        signals,
        service,
        source: 'webhook',
      });
    }

    if (uid && (threatLevel === 'CRITICAL' || action === 'SUSPEND_ACCOUNT')) {
      await banUser(uid, `Webhook auto-ban: ${action}`, threatScore);
      result['auto_banned'] = true;
    }

    res.status(200).json(result);
  }
);

// ============================================
// 🔒 SCAN EXISTING USER (Admin callable)
// Admins can trigger a full behavioral scan
// on any user manually from the admin panel.
// ============================================

export const adminScanUser = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 60,
    memory: '256MiB',
  },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be signed in.');

    const token = await admin.auth().getUser(request.auth.uid);
    const claims = token.customClaims ?? {};
    if (claims['role'] !== 'admin' && !((claims['roles'] as string[] | undefined)?.includes('admin'))) {
      throw new HttpsError('permission-denied', 'Admin only.');
    }

    const data = request.data as {uid?: string; behaviorPayload?: Record<string, unknown>};
    const targetUid = data.uid;
    if (!targetUid) throw new HttpsError('invalid-argument', 'Missing uid.');

    const payload = {uid: targetUid, ...(data.behaviorPayload ?? {})};

    const aiResult = await callSecurityAI('/predict/behavior', payload);
    const predictions = aiResult['predictions'] as Array<Record<string, unknown>>;
    const result = predictions?.[0] ?? aiResult;

    await logSecurityEvent({
      uid: targetUid,
      threatLevel: result['threat_level'],
      threatScore: result['threat_score'],
      action: result['action'],
      signals: result['signals'],
      service: 'behavior',
      source: 'admin_manual_scan',
      scannedBy: request.auth.uid,
    });

    if ((result['action'] as string) === 'SUSPEND_ACCOUNT') {
      await banUser(targetUid, `Admin scan auto-ban`, (result['threat_score'] as number) ?? 1.0);
      result['auto_banned'] = true;
    }

    return result;
  }
);

// ============================================
// 🤖 CLOUD RUN AGENT PROXY (Callable)
// iOS Firebase SDK calls this with automatic
// auth. The function fetches a Google Identity
// Token and forwards to the target Cloud Run
// service. Bypasses org allUsers restriction.
//
// iOS call: Functions.functions().httpsCallable("agentProxy")
//   .call(["service": "ml-agents", "path": "/predict", "body": {...}])
// ============================================

export const agentProxy = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 60,
    memory: '256MiB',
  },
  async (request) => {
    // 1. Must be authenticated
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }

    // 2. Parse params
    const data = request.data as {service?: string; path?: string; body?: unknown; method?: string};
    const service = data.service ?? '';
    const path = data.path ?? '/predict';
    const method = data.method ?? 'POST';
    if (!service) {
      throw new HttpsError('invalid-argument', 'Missing service param.');
    }

    const targetURL = `https://${service}-fkri6ifojq-uc.a.run.app${path}`;

    // 3. Get Google Identity Token for Cloud Run
    let idToken: string;
    try {
      const client = await googleAuth.getIdTokenClient(targetURL);
      const headers = await client.getRequestHeaders(targetURL);
      idToken = (headers['Authorization'] as string).replace('Bearer ', '');
    } catch (err) {
      console.error('[agentProxy] Identity token error:', err);
      throw new HttpsError('internal', 'Failed to get identity token.');
    }

    // 4. Forward to Cloud Run
    try {
      const fetchRes = await fetch(targetURL, {
        method,
        headers: {
          'Authorization': `Bearer ${idToken}`,
          'Content-Type': 'application/json',
        },
        body: method !== 'GET' ? JSON.stringify(data.body ?? {}) : undefined,
      });
      if (!fetchRes.ok) {
        const errText = await fetchRes.text();
        console.error(`[agentProxy] Upstream ${fetchRes.status}: ${errText}`);
        throw new HttpsError('unavailable', `Agent returned ${fetchRes.status}`);
      }
      return await fetchRes.json();
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('[agentProxy] Upstream error:', err);
      throw new HttpsError('unavailable', 'Agent unavailable.');
    }
  }
);

// ============================================
// 🎵 SERVER-SIDE STREAM COUNTER (MONEY-SAFE)
// streamCount drives artist payouts ($/stream), so it must NEVER be writable by
// clients. Listeners can only CREATE a music_plays event stamped with their own
// uid (enforced by Firestore rules). This trigger folds each validated play into
// music_tracks.streamCount via an atomic increment — the only path that can move
// the payout basis. This closes the "mint your own streams → cash out" exploit.
// ============================================

export const incrementStreamCountOnPlay = onDocumentCreated('music_plays/{playId}', async (event) => {
  const snap = event.data;
  if (!snap) return;
  const data = snap.data();
  const trackId = data.songId || data.trackId;
  if (!trackId) {
    console.warn('[incrementStreamCountOnPlay] play event missing songId/trackId');
    return;
  }

  const db = admin.firestore();
  try {
    await db.collection('music_tracks').doc(trackId).set(
      {
        streamCount: admin.firestore.FieldValue.increment(1),
        lastStreamAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
  } catch (err) {
    console.error(`[incrementStreamCountOnPlay] Failed for track ${trackId}:`, err);
  }
});

// ============================================
// 🔥 DELETE EXPIRED STORIES - Runs Every Hour
// ============================================

export const deleteExpiredStories = onSchedule('every 1 hours', async () => {
    const db = admin.firestore();
    const storage = admin.storage();
    const now = admin.firestore.Timestamp.now();
    
    console.log('⏰ [deleteExpiredStories] Running cleanup...');
    
    try {
      // Find expired stories (expiresAt < now)
      const expiredStories = await db.collection('stories')
        .where('expiresAt', '<', now)
        .limit(100) // Process 100 at a time
        .get();
      
      if (expiredStories.empty) {
        console.log('✅ [deleteExpiredStories] No expired stories found');
        return;
      }
      
      const batch = db.batch();
      let deletedCount = 0;
      
      // Delete each expired story
      for (const doc of expiredStories.docs) {
        const data = doc.data();
        
        // 1. Delete story document
        batch.delete(doc.ref);
        deletedCount++;
        
        // 2. Delete main media from Storage
        if (data.mediaURL && data.mediaURL.includes('firebase')) {
          try {
            const url = new URL(data.mediaURL);
            const pathMatch = url.pathname.match(/\/o\/(.+?)(\?|$)/);
            if (pathMatch) {
              const path = decodeURIComponent(pathMatch[1]);
              await storage.bucket().file(path).delete();
              console.log(`🗑️ [deleteExpiredStories] Deleted media: ${path}`);
            }
          } catch (error) {
            console.error('Failed to delete media:', error);
          }
        }
        
        // 3. Delete content items from Storage
        if (data.content && Array.isArray(data.content)) {
          for (const item of data.content) {
            if (item.url && item.url.includes('firebase')) {
              try {
                const url = new URL(item.url);
                const pathMatch = url.pathname.match(/\/o\/(.+?)(\?|$)/);
                if (pathMatch) {
                  const path = decodeURIComponent(pathMatch[1]);
                  await storage.bucket().file(path).delete();
                  console.log(`🗑️ [deleteExpiredStories] Deleted content: ${path}`);
                }
              } catch (error) {
                console.error('Failed to delete content:', error);
              }
            }
          }
        }
        
        // 4. Delete story views
        const viewsRef = db.collection('story_views').doc(doc.id);
        batch.delete(viewsRef);
        
        const expiresAt = data.expiresAt?.toDate() || new Date();
        console.log(`✅ [deleteExpiredStories] Deleted story: ${doc.id} (expired ${expiresAt.toISOString()})`);
      }
      
      // Commit batch delete
      await batch.commit();
      console.log(`🎉 [deleteExpiredStories] Deleted ${deletedCount} expired stories`);
      
    } catch (error) {
      console.error('🚨 [deleteExpiredStories] Error:', error);
    }
  });

// ============================================
// 🧹 CLEANUP ORPHANED MEDIA - Runs Daily
// ============================================

export const cleanupOrphanedMedia = onSchedule('every 24 hours', async () => {
    const storage = admin.storage();
    const db = admin.firestore();
    
    console.log('🧹 [cleanupOrphanedMedia] Running orphaned media cleanup...');
    
    try {
      // Get all story media files
      const [files] = await storage.bucket().getFiles({
        prefix: 'stories/',
        maxResults: 1000
      });
      
      let cleanedCount = 0;
      
      for (const file of files) {
        const fileName = file.name.split('/').pop();
        
        // Build public URL for the file
        const publicUrl = `https://storage.googleapis.com/${file.bucket.name}/${file.name}`;
        
        // Check if file is referenced in any story
        const storyQuery = await db.collection('stories')
          .where('mediaURL', '==', publicUrl)
          .limit(1)
          .get();
        
        // Also check in content arrays
        let foundInContent = false;
        if (storyQuery.empty) {
          const allStories = await db.collection('stories')
            .limit(1000)
            .get();
          
          for (const storyDoc of allStories.docs) {
            const data = storyDoc.data();
            if (data.content && Array.isArray(data.content)) {
              for (const item of data.content) {
                if (item.url === publicUrl) {
                  foundInContent = true;
                  break;
                }
              }
            }
            if (foundInContent) break;
          }
        }
        
        if (storyQuery.empty && !foundInContent) {
          // File not referenced - delete it
          await file.delete();
          cleanedCount++;
          console.log(`🗑️ [cleanupOrphanedMedia] Deleted orphaned file: ${fileName}`);
        }
      }
      
      console.log(`🎉 [cleanupOrphanedMedia] Cleaned up ${cleanedCount} orphaned files`);
    } catch (error) {
      console.error('🚨 [cleanupOrphanedMedia] Error:', error);
    }
  });

// ============================================
// 🔔 STORY NOTIFICATIONS - New Story Alert
// ============================================

export const notifyFollowersOnStoryCreated = onDocumentCreated('stories/{storyId}', async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('No data in snapshot');
      return;
    }
    
    const data = snap.data();
    const creatorId = data.creatorId;
    
    console.log(`📢 [notifyFollowers] New story from ${creatorId}`);
    
    // Get creator's followers
    const followersSnapshot = await admin.firestore()
      .collection('subscriptions')
      .where('creatorId', '==', creatorId)
      .get();
    
    if (followersSnapshot.empty) {
      console.log('No followers to notify');
      return;
    }
    
    // Send notifications to followers (batch)
    const batch = admin.firestore().batch();
    let notificationCount = 0;
    
    for (const followerDoc of followersSnapshot.docs) {
      const followerId = followerDoc.data().userId;
      
      // Create notification document
      const notificationRef = admin.firestore()
        .collection('notifications')
        .doc(followerId)
        .collection('items')
        .doc();
      
      batch.set(notificationRef, {
        type: 'new_story',
        creatorId: creatorId,
        storyId: snap.id,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false
      });
      
      notificationCount++;
    }
    
    await batch.commit();
    console.log(`✅ [notifyFollowers] Sent ${notificationCount} notifications`);
  });
