/**
 * MyChannel Cloud Functions — story-functions codebase
 * Deployed to us-east1 to avoid us-central1 CPU quota limits.
 *
 * Functions in this file:
 *   HTTPS/Callable:  securityGuard, securityWebhook, adminScanUser, agentProxy
 *   Scheduled:       deleteExpiredStories, cleanupOrphanedMedia, aggregateChannelStats
 *   Firestore:       notifyFollowersOnStoryCreated,
 *                    onVideoUploaded (notify subscribers),
 *                    onVideoCommented (notify creator),
 *                    onVideoRemoved (cleanup storage),
 *                    onChannelSubscribed / onChannelUnsubscribed (subscriber count)
 */

import {onSchedule} from 'firebase-functions/v2/scheduler';
import {onDocumentCreated, onDocumentDeleted} from 'firebase-functions/v2/firestore';
import {onCall, HttpsError, onRequest} from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import {GoogleAuth} from 'google-auth-library';

admin.initializeApp();

// Thumbnail AI analysis functions (relocated from web-v2/app/api).
export {predictThumbnailCtr, aiVideoThumbnail} from './thumbnail-ai';

// University: server-authoritative watch aggregation + certificate issuance + leaderboard mirror.
export {
  issueUniversityViewToken,
  onUniversityWatchEvent,
  onUniversityProgressWritten,
  onUniversityStatsWritten,
} from './university';

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
    uid, reason, threatScore,
    active: true,
    bannedAt: admin.firestore.FieldValue.serverTimestamp(),
    bannedBy: 'security-ai-auto',
  });
  try {
    await admin.auth().updateUser(uid, {disabled: true});
  } catch (err) {
    console.error('[banUser] Failed to disable auth user:', err);
  }
}

// ─── SECURITY GUARD ─────────────────────────────────────────────────────────

export const securityGuard = onCall(
  {region: 'us-east1', timeoutSeconds: 30, memory: '256MiB'},
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be signed in.');
    const data = request.data as {service?: string; payload?: Record<string, unknown>};
    const service = data.service ?? 'request';
    const payload = data.payload ?? {};
    payload['uid'] = payload['uid'] ?? request.auth.uid;
    if (!['request', 'behavior', 'content'].includes(service)) {
      throw new HttpsError('invalid-argument', 'Invalid service.');
    }
    let result: Record<string, unknown>;
    try {
      const aiResult = await callSecurityAI(`/predict/${service}`, payload);
      const predictions = aiResult['predictions'] as Array<Record<string, unknown>>;
      result = predictions?.[0] ?? aiResult;
    } catch {
      return {threat_score: 0, threat_level: 'CLEAN', action: 'ALLOW', blocked: false};
    }
    const threatLevel = result['threat_level'] as string;
    const action = result['action'] as string;
    const threatScore = (result['threat_score'] as number) ?? 0;
    const uid = payload['uid'] as string;
    const signals = result['signals'] as string[];
    if (threatLevel !== 'CLEAN') {
      await logSecurityEvent({uid, ip: payload['ip'] ?? null, threatLevel, threatScore, action, signals, service});
    }
    if (uid && (threatLevel === 'CRITICAL' || action === 'SUSPEND_ACCOUNT')) {
      await banUser(uid, `Auto-ban: ${action}`, threatScore);
      result['auto_banned'] = true;
    }
    return result;
  }
);

export const securityWebhook = onRequest(
  {region: 'us-east1', timeoutSeconds: 30, memory: '256MiB'},
  async (req, res) => {
    const authHeader = req.headers['authorization'] ?? '';
    if (!authHeader.toString().startsWith('Bearer ')) { res.status(401).json({error: 'Unauthorized'}); return; }
    if (req.method !== 'POST') { res.status(405).json({error: 'Method not allowed'}); return; }
    const body = req.body as Record<string, unknown>;
    const service = (body['service'] as string) ?? 'request';
    const payload = (body['payload'] as Record<string, unknown>) ?? {};
    let result: Record<string, unknown>;
    try {
      const aiResult = await callSecurityAI(`/predict/${service}`, payload);
      const predictions = aiResult['predictions'] as Array<Record<string, unknown>>;
      result = predictions?.[0] ?? aiResult;
    } catch { res.status(503).json({error: 'Security AI unavailable'}); return; }
    const threatLevel = result['threat_level'] as string;
    const action = result['action'] as string;
    const threatScore = (result['threat_score'] as number) ?? 0;
    const uid = payload['uid'] as string;
    const signals = result['signals'] as string[];
    if (threatLevel !== 'CLEAN') {
      await logSecurityEvent({uid: uid ?? null, ip: payload['ip'] ?? null, threatLevel, threatScore, action, signals, service, source: 'webhook'});
    }
    if (uid && (threatLevel === 'CRITICAL' || action === 'SUSPEND_ACCOUNT')) {
      await banUser(uid, `Webhook auto-ban: ${action}`, threatScore);
      result['auto_banned'] = true;
    }
    res.status(200).json(result);
  }
);

export const adminScanUser = onCall(
  {region: 'us-east1', timeoutSeconds: 60, memory: '256MiB'},
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
    await logSecurityEvent({uid: targetUid, threatLevel: result['threat_level'], threatScore: result['threat_score'], action: result['action'], signals: result['signals'], service: 'behavior', source: 'admin_manual_scan', scannedBy: request.auth.uid});
    if ((result['action'] as string) === 'SUSPEND_ACCOUNT') {
      await banUser(targetUid, 'Admin scan auto-ban', (result['threat_score'] as number) ?? 1.0);
      result['auto_banned'] = true;
    }
    return result;
  }
);

export const agentProxy = onCall(
  {region: 'us-east1', timeoutSeconds: 60, memory: '256MiB'},
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be signed in.');
    const data = request.data as {service?: string; path?: string; body?: unknown; method?: string};
    const service = data.service ?? '';
    const path = data.path ?? '/predict';
    const method = data.method ?? 'POST';
    if (!service) throw new HttpsError('invalid-argument', 'Missing service param.');
    const targetURL = `https://${service}-fkri6ifojq-uc.a.run.app${path}`;
    let idToken: string;
    try {
      const client = await googleAuth.getIdTokenClient(targetURL);
      const headers = await client.getRequestHeaders(targetURL);
      idToken = (headers['Authorization'] as string).replace('Bearer ', '');
    } catch {
      throw new HttpsError('internal', 'Failed to get identity token.');
    }
    try {
      const fetchRes = await fetch(targetURL, {
        method,
        headers: {'Authorization': `Bearer ${idToken}`, 'Content-Type': 'application/json'},
        body: method !== 'GET' ? JSON.stringify(data.body ?? {}) : undefined,
      });
      if (!fetchRes.ok) throw new HttpsError('unavailable', `Agent returned ${fetchRes.status}`);
      return await fetchRes.json();
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      throw new HttpsError('unavailable', 'Agent unavailable.');
    }
  }
);

// ─── SCHEDULED ──────────────────────────────────────────────────────────────

export const deleteExpiredStories = onSchedule(
  {schedule: 'every 1 hours', region: 'us-east1'},
  async () => {
    const db = admin.firestore();
    const storage = admin.storage();
    const now = admin.firestore.Timestamp.now();
    const expired = await db.collection('stories').where('expiresAt', '<', now).limit(100).get();
    if (expired.empty) return;
    const batch = db.batch();
    for (const doc of expired.docs) {
      const d = doc.data();
      batch.delete(doc.ref);
      batch.delete(db.collection('story_views').doc(doc.id));
      for (const urlField of [d.mediaURL, ...(d.content ?? []).map((c: {url?: string}) => c.url)]) {
        if (urlField?.includes('firebase')) {
          try {
            const match = new URL(urlField).pathname.match(/\/o\/(.+?)(\?|$)/);
            if (match) await storage.bucket().file(decodeURIComponent(match[1])).delete().catch(() => {});
          } catch { /* skip */ }
        }
      }
    }
    await batch.commit();
    console.log(`[deleteExpiredStories] deleted ${expired.size}`);
  }
);

export const cleanupOrphanedMedia = onSchedule(
  {schedule: 'every 24 hours', region: 'us-east1'},
  async () => {
    const storage = admin.storage();
    const db = admin.firestore();
    const [files] = await storage.bucket().getFiles({prefix: 'stories/', maxResults: 1000});
    let cleaned = 0;
    for (const file of files) {
      const publicUrl = `https://storage.googleapis.com/${file.bucket.name}/${file.name}`;
      const q = await db.collection('stories').where('mediaURL', '==', publicUrl).limit(1).get();
      if (q.empty) { await file.delete().catch(() => {}); cleaned++; }
    }
    console.log(`[cleanupOrphanedMedia] cleaned ${cleaned}`);
  }
);

export const aggregateChannelStats = onSchedule(
  {schedule: 'every 6 hours', region: 'us-east1', memory: '512MiB', timeoutSeconds: 300},
  async () => {
    const db = admin.firestore();
    const snap = await db.collection('videos').orderBy('createdAt', 'desc').limit(10000).get();
    const map: Record<string, {views: number; likes: number; comments: number; videoCount: number; totalDuration: number}> = {};
    for (const v of snap.docs) {
      const d = v.data();
      const cid: string = d.creatorId;
      if (!cid) continue;
      if (!map[cid]) map[cid] = {views: 0, likes: 0, comments: 0, videoCount: 0, totalDuration: 0};
      map[cid].views += d.viewCount ?? 0;
      map[cid].likes += d.likeCount ?? 0;
      map[cid].comments += d.commentCount ?? 0;
      map[cid].videoCount++;
      map[cid].totalDuration += d.duration ?? 0;
    }
    let batch = db.batch();
    let n = 0;
    for (const [cid, s] of Object.entries(map)) {
      const avgDur = s.videoCount > 0 ? s.totalDuration / s.videoCount : 0;
      batch.set(db.collection('creator_analytics').doc(cid), {
        creatorId: cid,
        totalViews: s.views, totalLikes: s.likes, totalComments: s.comments, totalVideos: s.videoCount,
        watchTimeHours: Math.round((s.views * avgDur * 0.55) / 3600),
        revenueEstimate: Math.round((s.views / 1000) * 185) / 100,
        rpm: 1.85,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      n++;
      if (n % 499 === 0) { await batch.commit(); batch = db.batch(); }
    }
    await batch.commit();
    console.log(`[aggregateChannelStats] rolled up ${n} creators`);
  }
);

// ─── FIRESTORE TRIGGERS ─────────────────────────────────────────────────────
// NOTE: All function names are unique strings that have NEVER been deployed
// before as HTTPS functions, to avoid Cloud Run service name collisions.

export const notifyFollowersOnStoryCreated = onDocumentCreated({document: 'stories/{storyId}', region: 'us-east1'}, async (event) => {
  const snap = event.data;
  if (!snap) return;
  const data = snap.data();
  const creatorId = data.creatorId;
  if (!creatorId) return;
  const db = admin.firestore();
  const followers = await db.collection('subscriptions').where('creatorId', '==', creatorId).get();
  if (followers.empty) return;
  const batch = db.batch();
  for (const f of followers.docs) {
    const ref = db.collection('notifications').doc(f.data().userId).collection('items').doc();
    batch.set(ref, {type: 'new_story', creatorId, storyId: snap.id, createdAt: admin.firestore.FieldValue.serverTimestamp(), read: false});
  }
  await batch.commit();
  console.log(`[storyNotify] sent ${followers.size} notifications`);
});

export const onVideoUploaded = onDocumentCreated({document: 'videos/{videoId}', region: 'us-east1'}, async (event) => {
  const snap = event.data;
  if (!snap) return;
  const data = snap.data();
  if (data.isPublic === false) return;
  const creatorId: string = data.creatorId;
  if (!creatorId) return;
  const db = admin.firestore();
  const subs = await db.collection('users').doc(creatorId).collection('subscribers').limit(500).get();
  if (subs.empty) return;
  const creatorSnap = await db.collection('users').doc(creatorId).get();
  const creatorName = creatorSnap.exists ? (creatorSnap.data()?.displayName ?? 'A creator') : 'A creator';
  let batch = db.batch();
  let n = 0;
  for (const sub of subs.docs) {
    if (sub.id === creatorId) continue;
    batch.set(db.collection('notifications').doc(), {
      userId: sub.id, type: 'video_upload', creatorId, videoId: snap.id,
      title: `${creatorName} uploaded a new video`, message: data.title ?? 'New video',
      thumbnailURL: data.thumbnailURL ?? '', read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    n++;
    if (n % 499 === 0) { await batch.commit(); batch = db.batch(); }
  }
  await batch.commit();
  console.log(`[onVideoUploaded] notified ${n} subscribers`);
});

export const onVideoCommented = onDocumentCreated({document: 'videos/{videoId}/comments/{commentId}', region: 'us-east1'}, async (event) => {
  const snap = event.data;
  if (!snap) return;
  const data = snap.data();
  const videoId = event.params.videoId;
  const commenterId: string = data.userId ?? '';
  const db = admin.firestore();
  const videoSnap = await db.collection('videos').doc(videoId).get();
  if (!videoSnap.exists) return;
  const videoData = videoSnap.data()!;
  const creatorId: string = videoData.creatorId ?? '';
  if (!creatorId || creatorId === commenterId) return;
  const text: string = data.text ?? '';
  await db.collection('notifications').add({
    userId: creatorId, type: 'comment_reply', videoId, commentId: snap.id, commenterId,
    title: `${data.displayName ?? 'Someone'} commented on your video`,
    message: text.length > 100 ? text.slice(0, 97) + '…' : text,
    thumbnailURL: videoData.thumbnailURL ?? '', read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
});

export const onVideoRemoved = onDocumentDeleted({document: 'videos/{videoId}', region: 'us-east1'}, async (event) => {
  const snap = event.data;
  if (!snap) return;
  const data = snap.data();
  const storage = admin.storage();
  for (const urlField of [data.videoURL, data.thumbnailURL]) {
    if (urlField?.includes('firebasestorage')) {
      try {
        const match = new URL(urlField).pathname.match(/\/o\/(.+?)(\?|$)/);
        if (match) await storage.bucket().file(decodeURIComponent(match[1])).delete().catch(() => {});
      } catch { /* skip */ }
    }
  }
  console.log(`[onVideoRemoved] cleaned up ${event.params.videoId}`);
});

export const onChannelSubscribed = onDocumentCreated({document: 'users/{userId}/subscriptions/{creatorId}', region: 'us-east1'}, async (event) => {
  const creatorId = event.params.creatorId;
  try {
    await admin.firestore().collection('users').doc(creatorId).update({
      subscriberCount: admin.firestore.FieldValue.increment(1),
    });
  } catch (err) {
    console.error('[onChannelSubscribed]', err);
  }
});

export const onChannelUnsubscribed = onDocumentDeleted({document: 'users/{userId}/subscriptions/{creatorId}', region: 'us-east1'}, async (event) => {
  const creatorId = event.params.creatorId;
  try {
    await admin.firestore().collection('users').doc(creatorId).update({
      subscriberCount: admin.firestore.FieldValue.increment(-1),
    });
  } catch (err) {
    console.error('[onChannelUnsubscribed]', err);
  }
});

// ─── FLICKS ENGAGEMENT AGGREGATION ──────────────────────────────────────────
// 🔒 SECURITY: Flick view/like/share/comment counts are server-authoritative.
// Clients no longer increment these counters directly (that was spoofable).
// Instead they create userId-stamped docs in /flicks/{id}/events, and this
// trigger aggregates them into the parent flick's counters via the Admin SDK
// (which bypasses security rules). Watch time arrives as a "watch_time" event
// carrying a numeric `watchTime` (seconds) and updates totalWatchTime only.
export const onFlickEngagementEvent = onDocumentCreated(
  {document: 'flicks/{flickId}/events/{eventId}', region: 'us-east1'},
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    const type = data.type as string;
    const flickId = event.params.flickId;

    const updates: Record<string, admin.firestore.FieldValue> = {};
    switch (type) {
      case 'view':
        updates.viewCount = admin.firestore.FieldValue.increment(1);
        break;
      case 'like':
        updates.likeCount = admin.firestore.FieldValue.increment(1);
        break;
      case 'unlike':
        updates.likeCount = admin.firestore.FieldValue.increment(-1);
        break;
      case 'comment':
        updates.commentCount = admin.firestore.FieldValue.increment(1);
        break;
      case 'share':
        updates.shareCount = admin.firestore.FieldValue.increment(1);
        break;
      case 'watch_time': {
        // Clamp to a sane range (0, 24h) so a bad client can't poison the metric.
        const wt = Number(data.watchTime ?? 0);
        if (wt > 0 && wt < 86400) {
          updates.totalWatchTime = admin.firestore.FieldValue.increment(Math.round(wt));
        }
        break;
      }
      default:
        return; // ignore unknown event types
    }
    if (Object.keys(updates).length === 0) return;
    updates.lastEngagementAt = admin.firestore.FieldValue.serverTimestamp();

    try {
      await admin.firestore().collection('flicks').doc(flickId).update(updates);
    } catch (err) {
      // Parent flick may not exist (e.g. demo/seed content) — safe to skip.
      console.error('[onFlickEngagementEvent]', flickId, type, err);
    }
  }
);
