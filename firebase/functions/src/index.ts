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
import {onDocumentCreated, onDocumentDeleted, onDocumentUpdated} from 'firebase-functions/v2/firestore';
import {onValueWritten} from 'firebase-functions/v2/database';
import {onCall, HttpsError, onRequest} from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import {GoogleAuth} from 'google-auth-library';
import {createHash} from 'node:crypto';

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

const SUBSCRIBER_RECONCILIATION_PAGE_SIZE = 100;
const SUBSCRIBER_RECONCILIATION_CONCURRENCY = 20;

// Incremental counters are fast but can drift after legacy writes, retries, or
// partial migrations. This bounded cursor sweep repairs a fixed number of
// creators per run using Firestore's server-side count aggregation.
export const reconcileSubscriberCounts = onSchedule(
  {schedule: 'every 30 minutes', region: 'us-east1', memory: '512MiB', timeoutSeconds: 300},
  async () => {
    const db = admin.firestore();
    const stateRef = db.collection('_maintenance').doc('subscriberCountReconciliation');
    const stateSnap = await stateRef.get();
    const cursor = stateSnap.get('cursor');

    let creatorsQuery = db.collection('users')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(SUBSCRIBER_RECONCILIATION_PAGE_SIZE);
    if (typeof cursor === 'string' && cursor) creatorsQuery = creatorsQuery.startAfter(cursor);

    let creators = await creatorsQuery.get();
    if (creators.empty && cursor) {
      creators = await db.collection('users')
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(SUBSCRIBER_RECONCILIATION_PAGE_SIZE)
        .get();
    }

    const counts = new Map<string, number>();
    for (let offset = 0; offset < creators.docs.length; offset += SUBSCRIBER_RECONCILIATION_CONCURRENCY) {
      const page = creators.docs.slice(offset, offset + SUBSCRIBER_RECONCILIATION_CONCURRENCY);
      const results = await Promise.all(page.map(async creator => {
        const aggregate = await creator.ref.collection('subscribers').count().get();
        return [creator.id, aggregate.data().count] as const;
      }));
      for (const [creatorId, count] of results) counts.set(creatorId, count);
    }

    const batch = db.batch();
    let repaired = 0;
    for (const creator of creators.docs) {
      const authoritativeCount = counts.get(creator.id) ?? 0;
      if (Number(creator.get('subscriberCount') ?? 0) !== authoritativeCount) {
        batch.update(creator.ref, {
          subscriberCount: authoritativeCount,
          subscriberCountReconciledAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        repaired += 1;
      }
    }

    const lastCreator = creators.docs.at(-1)?.id ?? null;
    const cycleComplete = creators.size < SUBSCRIBER_RECONCILIATION_PAGE_SIZE;
    batch.set(stateRef, {
      cursor: cycleComplete ? null : lastCreator,
      processed: creators.size,
      repaired,
      cycleComplete,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    await batch.commit();
    console.log(`[reconcileSubscriberCounts] checked ${creators.size}, repaired ${repaired}`);
  },
);

// ─── FIRESTORE TRIGGERS ─────────────────────────────────────────────────────
// NOTE: All function names are unique strings that have NEVER been deployed
// before as HTTPS functions, to avoid Cloud Run service name collisions.

type NotificationFanoutType = 'new_story' | 'video_upload' | 'video_remove';
type NotificationSuppressionReason =
  | 'allowed'
  | 'channel_disabled'
  | 'personalization_unavailable'
  | 'global_disabled';

const FANOUT_PAGE_SIZE = 200;
const FANOUT_LEASE_MS = 10 * 60 * 1000;
const FANOUT_MAX_ATTEMPTS = 5;

function isAlreadyExistsError(error: unknown): boolean {
  const code = (error as {code?: string | number} | null)?.code;
  return code === 6 || code === 'already-exists' || code === 'ALREADY_EXISTS';
}

function isPublicVideo(data: admin.firestore.DocumentData): boolean {
  if (data.isPublic === false) return false;
  if (typeof data.visibility === 'string' && data.visibility !== 'public') return false;
  if (typeof data.privacyStatus === 'string' && data.privacyStatus !== 'public') return false;
  return !['private', 'unlisted', 'scheduled'].includes(String(data.status ?? ''));
}

async function loadNotificationEligibility(
  subscriberIds: string[],
  creatorId: string,
  type: NotificationFanoutType,
): Promise<Map<string, NotificationSuppressionReason>> {
  const result = new Map<string, NotificationSuppressionReason>();
  if (type === 'video_remove' || subscriberIds.length === 0) return result;

  const db = admin.firestore();
  const channelRefs = subscriberIds.map(subscriberId => db.collection('users')
    .doc(subscriberId).collection('notification_settings').doc(creatorId));
  const globalRefs = subscriberIds.map(subscriberId => db.collection('users')
    .doc(subscriberId).collection('settings').doc('notifications'));
  const [channelSettings, globalSettings] = await Promise.all([
    db.getAll(...channelRefs),
    db.getAll(...globalRefs),
  ]);

  subscriberIds.forEach((subscriberId, index) => {
    const level = String(channelSettings[index]?.get('level') ?? 'All').toLowerCase();
    if (level === 'none') {
      result.set(subscriberId, 'channel_disabled');
      return;
    }
    // Personalized delivery needs an explicit ranking decision. Until that
    // scorer exists, fail closed rather than silently treating it as "All".
    if (level === 'personalized') {
      result.set(subscriberId, 'personalization_unavailable');
      return;
    }

    const globalField = type === 'video_upload' ? 'newVideos' : 'newStories';
    if (globalSettings[index]?.get(globalField) === false) {
      result.set(subscriberId, 'global_disabled');
      return;
    }
    result.set(subscriberId, 'allowed');
  });
  return result;
}

async function enqueueNotificationFanout(
  type: NotificationFanoutType,
  creatorId: string,
  contentId: string,
  payload: Record<string, unknown>,
): Promise<void> {
  if (!creatorId || !contentId) return;
  const jobId = engagementStateId(type, creatorId, contentId, 'root');
  const jobRef = admin.firestore().collection('_notificationFanoutJobs').doc(jobId);
  try {
    await jobRef.create({
      type,
      creatorId,
      contentId,
      payload,
      cursor: null,
      rootJobId: jobId,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    if (!isAlreadyExistsError(error)) throw error;
  }
}

async function claimNotificationFanoutPage(
  jobRef: admin.firestore.DocumentReference,
): Promise<{data: admin.firestore.DocumentData; leaseToken: string} | null> {
  const db = admin.firestore();
  const leaseToken = db.collection('_notificationFanoutLeaseTokens').doc().id;
  return db.runTransaction(async transaction => {
    const current = await transaction.get(jobRef);
    if (!current.exists) return null;
    const data = current.data() ?? {};
    const status = String(data.status ?? '');
    if (status === 'completed' || status === 'rejected') return null;

    const now = admin.firestore.Timestamp.now();
    const leaseUntil = data.leaseUntil instanceof admin.firestore.Timestamp
      ? data.leaseUntil.toMillis()
      : 0;
    if (status === 'processing' && leaseUntil > now.toMillis()) {
      throw new Error(`Fanout page ${jobRef.id} already has an active lease`);
    }
    if (status !== 'pending' && status !== 'processing') return null;

    transaction.set(jobRef, {
      status: 'processing',
      leaseToken,
      leaseUntil: admin.firestore.Timestamp.fromMillis(now.toMillis() + FANOUT_LEASE_MS),
      attempts: admin.firestore.FieldValue.increment(1),
      lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return {data, leaseToken};
  });
}

async function rejectNotificationFanoutPage(
  jobRef: admin.firestore.DocumentReference,
  leaseToken: string,
): Promise<void> {
  const db = admin.firestore();
  await db.runTransaction(async transaction => {
    const current = await transaction.get(jobRef);
    if (current.get('status') !== 'processing' || current.get('leaseToken') !== leaseToken) return;
    transaction.set(jobRef, {
      status: 'rejected',
      leaseToken: admin.firestore.FieldValue.delete(),
      leaseUntil: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  });
}

function stableFanoutErrorCode(error: unknown): string {
  const value = (error as {code?: unknown} | null)?.code;
  if (typeof value === 'string' || typeof value === 'number') {
    return String(value).slice(0, 100);
  }
  return 'fanout_processing_failed';
}

async function failNotificationFanoutPage(
  jobRef: admin.firestore.DocumentReference,
  leaseToken: string,
  error: unknown,
): Promise<boolean> {
  const db = admin.firestore();
  return db.runTransaction(async transaction => {
    const current = await transaction.get(jobRef);
    if (current.get('status') !== 'processing' || current.get('leaseToken') !== leaseToken) {
      return false;
    }

    const attempts = Math.max(1, Number(current.get('attempts') ?? 1));
    const isTerminal = attempts >= FANOUT_MAX_ATTEMPTS;
    const errorCode = stableFanoutErrorCode(error);
    const data = current.data() ?? {};
    const rootJobId = String(data.rootJobId ?? jobRef.id);
    transaction.set(jobRef, {
      status: isTerminal ? 'dead_lettered' : 'pending',
      lastErrorCode: errorCode,
      lastFailureAt: admin.firestore.FieldValue.serverTimestamp(),
      leaseToken: admin.firestore.FieldValue.delete(),
      leaseUntil: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(isTerminal ? {
        deadLetteredAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(rootJobId === jobRef.id ? {
          fanoutComplete: false,
          fanoutFailed: true,
          deadLetterCount: admin.firestore.FieldValue.increment(1),
        } : {}),
      } : {}),
    }, {merge: true});

    if (isTerminal) {
      transaction.set(db.collection('_notificationFanoutDeadLetters').doc(jobRef.id), {
        jobId: jobRef.id,
        rootJobId,
        type: String(data.type ?? ''),
        creatorId: String(data.creatorId ?? ''),
        contentId: String(data.contentId ?? ''),
        cursor: typeof data.cursor === 'string' ? data.cursor : null,
        payloadKeys: Object.keys(data.payload ?? {}).slice(0, 20),
        attempts,
        errorCode,
        firstAttemptAt: data.lastAttemptAt ?? null,
        deadLetteredAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: false});
      if (rootJobId !== jobRef.id) {
        transaction.set(db.collection('_notificationFanoutJobs').doc(rootJobId), {
          fanoutComplete: false,
          fanoutFailed: true,
          deadLetterCount: admin.firestore.FieldValue.increment(1),
          lastErrorCode: errorCode,
          lastFailureAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      }
    }
    return isTerminal;
  });
}

export const notifyFollowersOnStoryCreated = onDocumentCreated(
  {document: 'stories/{storyId}', region: 'us-east1'},
  async event => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    const creatorId = String(data.creatorId ?? '');
    if (!creatorId) return;
    await enqueueNotificationFanout('new_story', creatorId, snap.id, {
      title: `${String(data.creatorName ?? 'A creator').slice(0, 100)} posted a story`,
      message: String(data.caption ?? 'New story').slice(0, 200),
      thumbnailURL: String(data.thumbnailURL ?? data.mediaURL ?? '').slice(0, 2048),
      deepLink: `mychannel://story/${snap.id}`,
    });
  },
);

// Initial video documents are private/unprocessed reservations. Subscriber
// distribution starts only on the trusted transition to ready.
export const onVideoUploaded = onDocumentCreated(
  {document: 'videos/{videoId}', region: 'us-east1'},
  async () => undefined,
);

export const onVideoBecameReady = onDocumentUpdated(
  {document: 'videos/{videoId}', region: 'us-east1'},
  async event => {
    const change = event.data;
    if (!change) return;
    const before = change.before.data() ?? {};
    const after = change.after.data() ?? {};
    const contentId = String(event.params.videoId ?? '');
    const creatorId = String(after.creatorId ?? after.userId ?? before.creatorId ?? before.userId ?? '');
    if (!creatorId || !contentId) return;

    const becamePublicAndReady = before.processingStatus !== 'ready' &&
      after.processingStatus === 'ready' && isPublicVideo(after);
    const becameUnavailable = before.processingStatus === 'ready' &&
      isPublicVideo(before) && !isPublicVideo(after);
    if (!becamePublicAndReady && !becameUnavailable) return;

    if (becameUnavailable) {
      await enqueueNotificationFanout('video_remove', creatorId, contentId, {});
      return;
    }

    const creatorSnap = await admin.firestore().collection('users').doc(creatorId).get();
    const creatorName = String(creatorSnap.get('displayName') ?? 'A creator').slice(0, 100);
    await enqueueNotificationFanout('video_upload', creatorId, contentId, {
      title: `${creatorName} uploaded a new video`,
      message: String(after.title ?? 'New video').slice(0, 200),
      thumbnailURL: String(after.thumbnailURL ?? after.thumbnailUrl ?? '').slice(0, 2048),
      duration: Number(after.duration ?? 0),
      publishedAt: after.publishedAt ?? after.createdAt ?? admin.firestore.Timestamp.now(),
      deepLink: `mychannel://video/${contentId}`,
    });
  },
);

export const processNotificationFanoutPage = onDocumentCreated(
  {
    document: '_notificationFanoutJobs/{jobId}',
    region: 'us-east1',
    retry: true,
  },
  async event => {
    const eventSnap = event.data;
    if (!eventSnap) return;
    const claim = await claimNotificationFanoutPage(eventSnap.ref);
    if (!claim) return;

    const {data, leaseToken} = claim;
    const type = String(data.type ?? '') as NotificationFanoutType;
    const creatorId = String(data.creatorId ?? '');
    const contentId = String(data.contentId ?? '');
    const rootJobId = String(data.rootJobId ?? eventSnap.id);
    const cursor = typeof data.cursor === 'string' ? data.cursor : null;
    if (!['new_story', 'video_upload', 'video_remove'].includes(type) || !creatorId || !contentId) {
      await rejectNotificationFanoutPage(eventSnap.ref, leaseToken);
      return;
    }

    const db = admin.firestore();
    try {
      let subscribersQuery = db.collection('users').doc(creatorId)
        .collection('subscribers')
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(FANOUT_PAGE_SIZE);
      if (cursor) subscribersQuery = subscribersQuery.startAfter(cursor);
      const subscribers = await subscribersQuery.get();
      const subscriberIds = subscribers.docs
        .map(subscriber => subscriber.id)
        .filter(subscriberId => subscriberId !== creatorId);
      const notificationEligibility = await loadNotificationEligibility(
        subscriberIds,
        creatorId,
        type,
      );
      const lastSubscriber = subscribers.docs.at(-1)?.id ?? null;
      const hasNextPage = subscribers.size === FANOUT_PAGE_SIZE && lastSubscriber !== null;

      let completedMetrics: Record<string, number> = {};
      await db.runTransaction(async transaction => {
        const current = await transaction.get(eventSnap.ref);
        if (current.get('status') !== 'processing' || current.get('leaseToken') !== leaseToken) return;

        let notificationCount = 0;
        let feedItemCount = 0;
        let preferenceSuppressed = 0;
        let channelDisabled = 0;
        let personalizationUnavailable = 0;
        let globalDisabled = 0;
        for (const subscriber of subscribers.docs) {
          if (subscriber.id === creatorId) continue;

          const suppressionReason = notificationEligibility.get(subscriber.id) ?? 'allowed';
          if (type !== 'video_remove' && suppressionReason === 'allowed') {
            const notificationId = engagementStateId(type, contentId, subscriber.id);
            const message = String(data.payload?.message ?? '').slice(0, 500);
            const thumbnailURL = String(data.payload?.thumbnailURL ?? '').slice(0, 2048);
            const deepLink = String(data.payload?.deepLink ?? '').slice(0, 2048);
            transaction.set(db.collection('notifications').doc(notificationId), {
              userId: subscriber.id,
              type,
              creatorId,
              ...(type === 'video_upload' ? {videoId: contentId} : {storyId: contentId}),
              title: String(data.payload?.title ?? '').slice(0, 200),
              message,
              body: message,
              thumbnailURL,
              imageURL: thumbnailURL,
              deepLink,
              link: deepLink,
              read: false,
              isRead: false,
              groupedCount: 1,
              fanoutJobId: rootJobId,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            }, {merge: false});
            notificationCount += 1;
          } else if (type !== 'video_remove') {
            preferenceSuppressed += 1;
            if (suppressionReason === 'channel_disabled') channelDisabled += 1;
            if (suppressionReason === 'personalization_unavailable') personalizationUnavailable += 1;
            if (suppressionReason === 'global_disabled') globalDisabled += 1;
          }

          const feedRef = db.collection('feeds').doc(subscriber.id).collection('items').doc(contentId);
          if (type === 'video_upload') {
            transaction.set(feedRef, {
              videoId: contentId,
              creatorId,
              title: String(data.payload?.message ?? '').slice(0, 200),
              thumbnailURL: String(data.payload?.thumbnailURL ?? '').slice(0, 2048),
              duration: Math.max(0, Number(data.payload?.duration ?? 0)),
              createdAt: data.payload?.publishedAt ?? admin.firestore.FieldValue.serverTimestamp(),
              addedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, {merge: false});
            feedItemCount += 1;
          } else if (type === 'video_remove') {
            transaction.delete(feedRef);
            feedItemCount += 1;
          }
        }

        if (hasNextPage) {
          const nextJobId = engagementStateId(rootJobId, lastSubscriber);
          transaction.create(db.collection('_notificationFanoutJobs').doc(nextJobId), {
            type,
            creatorId,
            contentId,
            payload: data.payload ?? {},
            cursor: lastSubscriber,
            rootJobId,
            status: 'pending',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        completedMetrics = {
          recipientsScanned: subscriberIds.length,
          notificationCount,
          feedItemCount,
          preferenceSuppressed,
          channelDisabled,
          personalizationUnavailable,
          globalDisabled,
        };
        const rootPageMetrics = eventSnap.id === rootJobId ? {
          totalRecipientsScanned: subscriberIds.length,
          totalNotificationsCreated: notificationCount,
          totalFeedWrites: feedItemCount,
          totalPreferenceSuppressed: preferenceSuppressed,
          totalChannelDisabled: channelDisabled,
          totalPersonalizationUnavailable: personalizationUnavailable,
          totalGlobalDisabled: globalDisabled,
          fanoutComplete: !hasNextPage,
          ...(!hasNextPage ? {fanoutCompletedAt: admin.firestore.FieldValue.serverTimestamp()} : {}),
        } : {};
        transaction.set(eventSnap.ref, {
          status: 'completed',
          ...completedMetrics,
          ...rootPageMetrics,
          nextCursor: hasNextPage ? lastSubscriber : null,
          leaseToken: admin.firestore.FieldValue.delete(),
          leaseUntil: admin.firestore.FieldValue.delete(),
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

        if (eventSnap.id !== rootJobId) {
          transaction.set(db.collection('_notificationFanoutJobs').doc(rootJobId), {
            totalRecipientsScanned: admin.firestore.FieldValue.increment(subscriberIds.length),
            totalNotificationsCreated: admin.firestore.FieldValue.increment(notificationCount),
            totalFeedWrites: admin.firestore.FieldValue.increment(feedItemCount),
            totalPreferenceSuppressed: admin.firestore.FieldValue.increment(preferenceSuppressed),
            totalChannelDisabled: admin.firestore.FieldValue.increment(channelDisabled),
            totalPersonalizationUnavailable: admin.firestore.FieldValue.increment(
              personalizationUnavailable,
            ),
            totalGlobalDisabled: admin.firestore.FieldValue.increment(globalDisabled),
            fanoutComplete: !hasNextPage,
            ...(!hasNextPage ? {
              fanoutCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
            } : {}),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
        }
      });
      console.info('notification_fanout_page_completed', {
        jobId: eventSnap.id,
        rootJobId,
        type,
        hasNextPage,
        ...completedMetrics,
      });
    } catch (error) {
      const terminal = await failNotificationFanoutPage(eventSnap.ref, leaseToken, error);
      console.error('notification_fanout_page_failed', {
        jobId: eventSnap.id,
        rootJobId,
        type,
        terminal,
        errorCode: stableFanoutErrorCode(error),
      });
      if (!terminal) throw error;
    }
  },
);

const PUSH_DELIVERY_PAGE_SIZE = 500;
const PUSH_DELIVERY_LEASE_MS = 10 * 60 * 1000;
const PUSH_DELIVERY_MAX_ATTEMPTS = 5;

async function enqueuePushDelivery(notificationId: string): Promise<void> {
  if (!notificationId) return;
  const db = admin.firestore();
  const rootJobId = engagementStateId('push', notificationId, 'root');
  try {
    await db.collection('_pushDeliveryJobs').doc(rootJobId).create({
      notificationId,
      rootJobId,
      cursor: null,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    if (!isAlreadyExistsError(error)) throw error;
  }
}

async function claimPushDeliveryJob(
  jobRef: admin.firestore.DocumentReference,
): Promise<{data: admin.firestore.DocumentData; leaseToken: string} | null> {
  const db = admin.firestore();
  const leaseToken = db.collection('_pushDeliveryLeaseTokens').doc().id;
  return db.runTransaction(async transaction => {
    const current = await transaction.get(jobRef);
    if (!current.exists) return null;
    const data = current.data() ?? {};
    const status = String(data.status ?? '');
    if (status === 'completed' || status === 'dead_lettered' || status === 'rejected') {
      return null;
    }

    const now = admin.firestore.Timestamp.now();
    const leaseUntil = data.leaseUntil instanceof admin.firestore.Timestamp
      ? data.leaseUntil.toMillis()
      : 0;
    if (status === 'processing' && leaseUntil > now.toMillis()) return null;
    if (status !== 'pending' && status !== 'processing') return null;

    transaction.set(jobRef, {
      status: 'processing',
      leaseToken,
      leaseUntil: admin.firestore.Timestamp.fromMillis(now.toMillis() + PUSH_DELIVERY_LEASE_MS),
      attempts: admin.firestore.FieldValue.increment(1),
      lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return {data, leaseToken};
  });
}

async function failPushDeliveryJob(
  jobRef: admin.firestore.DocumentReference,
  leaseToken: string,
  error: unknown,
): Promise<boolean> {
  const db = admin.firestore();
  return db.runTransaction(async transaction => {
    const current = await transaction.get(jobRef);
    if (current.get('status') !== 'processing' || current.get('leaseToken') !== leaseToken) {
      return false;
    }

    const attempts = Math.max(1, Number(current.get('attempts') ?? 1));
    const terminal = attempts >= PUSH_DELIVERY_MAX_ATTEMPTS;
    const errorCode = stableFanoutErrorCode(error);
    const data = current.data() ?? {};
    transaction.set(jobRef, {
      status: terminal ? 'dead_lettered' : 'pending',
      lastErrorCode: errorCode,
      lastFailureAt: admin.firestore.FieldValue.serverTimestamp(),
      leaseToken: admin.firestore.FieldValue.delete(),
      leaseUntil: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(terminal ? {deadLetteredAt: admin.firestore.FieldValue.serverTimestamp()} : {}),
    }, {merge: true});

    if (terminal) {
      transaction.set(db.collection('_pushDeliveryDeadLetters').doc(jobRef.id), {
        jobId: jobRef.id,
        rootJobId: String(data.rootJobId ?? jobRef.id),
        notificationId: String(data.notificationId ?? ''),
        cursor: typeof data.cursor === 'string' ? data.cursor : null,
        attempts,
        errorCode,
        deadLetteredAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: false});
    }
    return terminal;
  });
}

function isPermanentlyInvalidFcmTokenError(code: string): boolean {
  return code.includes('registration-token-not-registered') ||
    code.includes('invalid-registration-token');
}

async function processPushDeliveryJob(
  jobRef: admin.firestore.DocumentReference,
): Promise<void> {
  const claim = await claimPushDeliveryJob(jobRef);
  if (!claim) return;

  const {data, leaseToken} = claim;
  const db = admin.firestore();
  const notificationId = String(data.notificationId ?? '');
  const rootJobId = String(data.rootJobId ?? jobRef.id);
  const cursor = typeof data.cursor === 'string' ? data.cursor : null;

  try {
    const notificationRef = db.collection('notifications').doc(notificationId);
    const notificationSnap = await notificationRef.get();
    if (!notificationSnap.exists) {
      await db.runTransaction(async transaction => {
        const current = await transaction.get(jobRef);
        if (current.get('status') !== 'processing' || current.get('leaseToken') !== leaseToken) return;
        transaction.set(jobRef, {
          status: 'completed',
          completionReason: 'notification_missing',
          leaseToken: admin.firestore.FieldValue.delete(),
          leaseUntil: admin.firestore.FieldValue.delete(),
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      });
      return;
    }

    const notification = notificationSnap.data() ?? {};
    const userId = String(notification.userId ?? '');
    const title = String(notification.title ?? '').slice(0, 200);
    const body = String(notification.message ?? notification.body ?? '').slice(0, 500);
    if (!userId || !title) throw new Error('invalid_notification_payload');

    let tokenQuery = db.collection('users').doc(userId)
      .collection('fcmTokens')
      .where('active', '==', true)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(PUSH_DELIVERY_PAGE_SIZE);
    if (cursor) tokenQuery = tokenQuery.startAfter(cursor);
    const tokenDocs = await tokenQuery.get();
    const tokenRecords = tokenDocs.docs
      .map(tokenDoc => ({
        token: String(tokenDoc.get('token') ?? tokenDoc.id),
        ref: tokenDoc.ref,
      }))
      .filter(record => record.token.length > 0 && !record.token.includes('/'));

    let successCount = 0;
    let permanentFailures = 0;
    if (tokenRecords.length > 0) {
      const type = String(notification.type ?? 'general').slice(0, 100);
      const deepLink = String(notification.deepLink ?? notification.link ?? '').slice(0, 2048);
      const thumbnailURL = String(
        notification.thumbnailURL ?? notification.imageURL ?? '',
      ).slice(0, 2048);
      const collapseId = engagementStateId('push', notificationId);
      const response = await admin.messaging().sendEachForMulticast({
        tokens: tokenRecords.map(record => record.token),
        notification: {
          title,
          body,
          ...(thumbnailURL ? {imageUrl: thumbnailURL} : {}),
        },
        android: {
          priority: 'high',
          collapseKey: collapseId,
          notification: {
            title,
            body,
            ...(thumbnailURL ? {imageUrl: thumbnailURL} : {}),
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
        apns: {
          headers: {
            'apns-priority': '10',
            'apns-collapse-id': collapseId,
          },
          payload: {
            aps: {
              alert: {title, body},
              badge: 1,
              sound: 'default',
              contentAvailable: true,
              mutableContent: true,
            },
          },
        },
        data: {
          type,
          deepLink,
          notificationId,
          thumbnailURL,
        },
      });

      successCount = response.successCount;
      const invalidTokenRefs: admin.firestore.DocumentReference[] = [];
      const transientErrorCodes: string[] = [];
      response.responses.forEach((result, index) => {
        if (result.success) return;
        const errorCode = String(result.error?.code ?? 'messaging/unknown-error').toLowerCase();
        if (isPermanentlyInvalidFcmTokenError(errorCode)) {
          invalidTokenRefs.push(tokenRecords[index].ref);
          permanentFailures += 1;
        } else {
          transientErrorCodes.push(errorCode.slice(0, 100));
        }
      });

      if (invalidTokenRefs.length > 0) {
        const cleanup = db.batch();
        invalidTokenRefs.forEach(tokenRef => cleanup.delete(tokenRef));
        await cleanup.commit();
      }
      if (transientErrorCodes.length > 0) {
        const retryError = new Error('transient_push_delivery_failure') as Error & {code?: string};
        retryError.code = transientErrorCodes[0];
        throw retryError;
      }
    }

    const lastTokenId = tokenDocs.docs.at(-1)?.id ?? null;
    const hasNextPage = tokenDocs.size === PUSH_DELIVERY_PAGE_SIZE && lastTokenId !== null;
    await db.runTransaction(async transaction => {
      const current = await transaction.get(jobRef);
      if (current.get('status') !== 'processing' || current.get('leaseToken') !== leaseToken) return;

      transaction.set(jobRef, {
        status: 'completed',
        attempted: tokenRecords.length,
        delivered: successCount,
        permanentFailures,
        hasNextPage,
        leaseToken: admin.firestore.FieldValue.delete(),
        leaseUntil: admin.firestore.FieldValue.delete(),
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      if (hasNextPage) {
        const nextJobId = engagementStateId(rootJobId, lastTokenId);
        transaction.create(db.collection('_pushDeliveryJobs').doc(nextJobId), {
          notificationId,
          rootJobId,
          cursor: lastTokenId,
          status: 'pending',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });

    console.log('push_delivery_page_completed', {
      jobId: jobRef.id,
      attempted: tokenRecords.length,
      delivered: successCount,
      permanentFailures,
      hasNextPage,
    });
  } catch (error) {
    const terminal = await failPushDeliveryJob(jobRef, leaseToken, error);
    console.error('push_delivery_page_failed', {
      jobId: jobRef.id,
      terminal,
      errorCode: stableFanoutErrorCode(error),
    });
    if (!terminal) throw error;
  }
}

export const enqueuePushOnNotificationCreated = onDocumentCreated(
  {document: 'notifications/{notificationId}', region: 'us-east1'},
  async event => {
    if (!event.data) return;
    await enqueuePushDelivery(String(event.params.notificationId ?? ''));
  },
);

export const processPushDeliveryJobCreated = onDocumentCreated(
  {
    document: '_pushDeliveryJobs/{jobId}',
    region: 'us-east1',
    retry: true,
    timeoutSeconds: 120,
  },
  async event => {
    if (!event.data) return;
    await processPushDeliveryJob(event.data.ref);
  },
);

export const retryPushDeliveryJobs = onSchedule(
  {schedule: 'every 5 minutes', region: 'us-east1', timeoutSeconds: 300},
  async () => {
    const db = admin.firestore();
    const [pending, processing] = await Promise.all([
      db.collection('_pushDeliveryJobs').where('status', '==', 'pending').limit(25).get(),
      db.collection('_pushDeliveryJobs').where('status', '==', 'processing').limit(25).get(),
    ]);
    const nowMillis = Date.now();
    const jobs = [
      ...pending.docs,
      ...processing.docs.filter(job => {
        const leaseUntil = job.get('leaseUntil');
        return !(leaseUntil instanceof admin.firestore.Timestamp) || leaseUntil.toMillis() <= nowMillis;
      }),
    ];
    for (const job of jobs) {
      try {
        await processPushDeliveryJob(job.ref);
      } catch {
        // The worker already returned the job to pending and logged a stable code.
        // Continue draining other jobs instead of failing the entire sweep.
      }
    }
  },
);

export const onStoryReplyCreated = onDocumentCreated(
  {
    document: 'story_replies/{replyId}',
    region: 'us-east1',
    retry: true,
  },
  async event => {
    const createdReply = event.data;
    if (!createdReply) return;

    const db = admin.firestore();
    const replyId = String(event.params.replyId ?? '');
    const stateRef = db.collection('_storyReplyState').doc(replyId);

    await db.runTransaction(async transaction => {
      const replyRef = createdReply.ref;
      const replySnap = await transaction.get(replyRef);
      if (!replySnap.exists) return;

      const reply = replySnap.data() ?? {};
      const storyId = String(reply.storyId ?? '');
      const senderId = String(reply.senderId ?? '');
      const claimedCreatorId = String(reply.creatorId ?? '');
      const text = typeof reply.text === 'string' ? reply.text.trim() : '';
      const allowedKeys = new Set([
        'storyId', 'creatorId', 'senderId', 'text', 'createdAt', 'status',
      ]);
      const hasExactSchema = Object.keys(reply).length === allowedKeys.size &&
        Object.keys(reply).every(key => allowedKeys.has(key));
      const hasValidFields = hasExactSchema &&
        storyId.length > 0 && storyId.length <= 256 &&
        senderId.length > 0 && senderId.length <= 128 &&
        claimedCreatorId.length > 0 && claimedCreatorId.length <= 128 &&
        text.length > 0 && text.length <= 2000 &&
        reply.status === 'sent' &&
        reply.createdAt instanceof admin.firestore.Timestamp;

      const storyRef = db.collection('stories').doc(storyId || '_invalid');
      const [storySnap, stateSnap] = await Promise.all([
        transaction.get(storyRef),
        transaction.get(stateRef),
      ]);
      if (stateSnap.exists) return;

      const story = storySnap.data() ?? {};
      const creatorId = String(story.creatorId ?? story.userId ?? '');
      if (!hasValidFields || !storySnap.exists || creatorId !== claimedCreatorId) {
        transaction.create(stateRef, {
          replyId,
          storyId,
          status: 'rejected',
          reason: !hasValidFields
            ? 'invalid_reply'
            : !storySnap.exists
              ? 'story_not_found'
              : 'creator_mismatch',
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      const processedAt = admin.firestore.FieldValue.serverTimestamp();
      transaction.update(storyRef, {
        replyCount: admin.firestore.FieldValue.increment(1),
        commentCount: admin.firestore.FieldValue.increment(1),
        updatedAt: processedAt,
      });

      if (creatorId !== senderId) {
        const notificationId = engagementStateId('storyReply', replyId, creatorId);
        const deepLink = `mychannel://story/${storyId}`;
        transaction.set(db.collection('notifications').doc(notificationId), {
          userId: creatorId,
          type: 'storyReply',
          title: 'New story reply',
          message: 'Someone replied to your story',
          body: 'Someone replied to your story',
          storyId,
          senderId,
          deepLink,
          link: deepLink,
          read: false,
          isRead: false,
          groupedCount: 1,
          createdAt: reply.createdAt,
        }, {merge: false});
      }

      transaction.create(stateRef, {
        replyId,
        storyId,
        senderId,
        creatorId,
        status: 'counted',
        processedAt,
      });
    });
  },
);

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
  const videoId = String(event.params.videoId ?? '');
  const creatorId = String(data.creatorId ?? data.userId ?? '');
  if (creatorId && videoId) {
    await enqueueNotificationFanout('video_remove', creatorId, videoId, {});
  }

  const storage = admin.storage();
  for (const urlField of [data.videoURL, data.thumbnailURL]) {
    if (urlField?.includes('firebasestorage')) {
      try {
        const match = new URL(urlField).pathname.match(/\/o\/(.+?)(\?|$)/);
        if (match) await storage.bucket().file(decodeURIComponent(match[1])).delete().catch(() => {});
      } catch { /* skip */ }
    }
  }
  console.log(`[onVideoRemoved] cleaned up ${videoId}`);
});

async function syncChannelSubscription(
  userId: string,
  creatorId: string,
): Promise<void> {
  if (!userId || !creatorId || userId === creatorId) return;

  const db = admin.firestore();
  const userRef = db.collection('users').doc(userId);
  const creatorRef = db.collection('users').doc(creatorId);
  const subscriptionRef = userRef.collection('subscriptions').doc(creatorId);
  const reverseRef = creatorRef.collection('subscribers').doc(userId);
  const stateRef = creatorRef.collection('_subscriptionState')
    .doc(engagementStateId(userId));

  await db.runTransaction(async transaction => {
    const [subscriptionSnap, creatorSnap, reverseSnap, stateSnap] = await Promise.all([
      transaction.get(subscriptionRef),
      transaction.get(creatorRef),
      transaction.get(reverseRef),
      transaction.get(stateRef),
    ]);
    if (!creatorSnap.exists) return;

    const isSubscribed = subscriptionSnap.exists;
    // The reverse edge predates the semantic state ledger and is the safest
    // baseline for historical rows. Reading current state also makes delayed
    // create/delete triggers converge instead of applying their event order.
    const wasSubscribed = stateSnap.exists
      ? stateSnap.get('subscribed') === true
      : reverseSnap.exists;
    const now = admin.firestore.FieldValue.serverTimestamp();

    if (isSubscribed) {
      transaction.set(reverseRef, {
        userId,
        creatorId,
        subscribedAt: subscriptionSnap.get('subscribedAt') ?? now,
        syncedAt: now,
      }, {merge: true});
    } else {
      transaction.delete(reverseRef);
    }

    if (isSubscribed !== wasSubscribed) {
      const currentCount = Math.max(0, Number(creatorSnap.get('subscriberCount') ?? 0));
      transaction.update(creatorRef, {
        subscriberCount: Math.max(0, currentCount + (isSubscribed ? 1 : -1)),
        updatedAt: now,
      });
    }

    transaction.set(stateRef, {
      userId,
      subscribed: isSubscribed,
      updatedAt: now,
    }, {merge: true});
  });
}

export const onChannelSubscribed = onDocumentCreated(
  {document: 'users/{userId}/subscriptions/{creatorId}', region: 'us-east1'},
  async event => {
    await syncChannelSubscription(
      String(event.params.userId ?? ''),
      String(event.params.creatorId ?? ''),
    );
  },
);

export const onChannelUnsubscribed = onDocumentDeleted(
  {document: 'users/{userId}/subscriptions/{creatorId}', region: 'us-east1'},
  async event => {
    await syncChannelSubscription(
      String(event.params.userId ?? ''),
      String(event.params.creatorId ?? ''),
    );
  },
);

// ─── COMMUNITY LIKE AGGREGATION ─────────────────────────────────────────────
// Both collection spellings remain active during migration. Clients own only
// their deterministic like document; retry-safe semantic state owns aggregates.
async function syncCommunityLike(
  collectionName: 'communityPosts' | 'community_posts',
  postId: string,
  userId: string,
  eventLiked: boolean,
): Promise<void> {
  if (!postId || !userId) return;
  const db = admin.firestore();
  const postRef = db.collection(collectionName).doc(postId);
  const likeRef = postRef.collection('likes').doc(userId);
  const stateRef = postRef.collection('_likeState').doc(userId);

  await db.runTransaction(async transaction => {
    const [postSnap, likeSnap, stateSnap] = await Promise.all([
      transaction.get(postRef),
      transaction.get(likeRef),
      transaction.get(stateRef),
    ]);
    if (!postSnap.exists) return;

    // Event delivery can be delayed or reordered. The current marker is the
    // desired state; the event transition is used only to seed legacy rows
    // that predate the semantic-state ledger.
    const desired = likeSnap.exists;
    const current = stateSnap.exists
      ? stateSnap.get('liked') === true
      : !eventLiked;
    if (current === desired) return;

    const currentCount = Math.max(0, Number(postSnap.get('likeCount') ?? 0));
    transaction.set(stateRef, {
      userId,
      liked: desired,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.update(postRef, {
      likeCount: Math.max(0, currentCount + (desired ? 1 : -1)),
      lastEngagementAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

export const onCommunityPostLiked = onDocumentCreated(
  {document: 'communityPosts/{postId}/likes/{userId}', region: 'us-east1'},
  event => syncCommunityLike(
    'communityPosts',
    String(event.params.postId ?? ''),
    String(event.params.userId ?? ''),
    true,
  ),
);

export const onCommunityPostUnliked = onDocumentDeleted(
  {document: 'communityPosts/{postId}/likes/{userId}', region: 'us-east1'},
  event => syncCommunityLike(
    'communityPosts',
    String(event.params.postId ?? ''),
    String(event.params.userId ?? ''),
    false,
  ),
);

export const onLegacyCommunityPostLiked = onDocumentCreated(
  {document: 'community_posts/{postId}/likes/{userId}', region: 'us-east1'},
  event => syncCommunityLike(
    'community_posts',
    String(event.params.postId ?? ''),
    String(event.params.userId ?? ''),
    true,
  ),
);

export const onLegacyCommunityPostUnliked = onDocumentDeleted(
  {document: 'community_posts/{postId}/likes/{userId}', region: 'us-east1'},
  event => syncCommunityLike(
    'community_posts',
    String(event.params.postId ?? ''),
    String(event.params.userId ?? ''),
    false,
  ),
);

// ─── COMMUNITY POLL AGGREGATION ─────────────────────────────────────────────
// Votes are immutable, deterministic per-user facts. Trusted aggregation owns
// every public total for both collection spellings during migration.
async function syncCommunityPollVote(
  collectionName: 'communityPosts' | 'community_posts',
  postId: string,
  userId: string,
): Promise<void> {
  if (!postId || !userId) return;
  const db = admin.firestore();
  const postRef = db.collection(collectionName).doc(postId);
  const voteRef = postRef.collection('votes').doc(userId);
  const stateRef = postRef.collection('_voteState').doc(userId);

  await db.runTransaction(async transaction => {
    const [postSnap, voteSnap, stateSnap] = await Promise.all([
      transaction.get(postRef),
      transaction.get(voteRef),
      transaction.get(stateRef),
    ]);
    if (!postSnap.exists || !voteSnap.exists || stateSnap.exists) return;

    const optionIndex = Number(voteSnap.get('optionIndex'));
    if (!Number.isInteger(optionIndex) || optionIndex < 0) return;

    const post = postSnap.data() ?? {};
    const now = admin.firestore.FieldValue.serverTimestamp();
    if (collectionName === 'communityPosts') {
      const poll = Array.isArray(post.poll) ? [...post.poll] : [];
      if (optionIndex >= poll.length) return;
      const selected = poll[optionIndex];
      if (!selected || typeof selected !== 'object') return;
      poll[optionIndex] = {
        ...selected,
        votes: Math.max(0, Number(selected.votes ?? 0)) + 1,
      };
      transaction.update(postRef, {poll, lastEngagementAt: now});
    } else {
      const poll = post.poll && typeof post.poll === 'object' ? {...post.poll} : null;
      const options = poll && Array.isArray(poll.options) ? [...poll.options] : [];
      if (!poll || optionIndex >= options.length) return;
      const selected = options[optionIndex];
      if (!selected || typeof selected !== 'object') return;
      options[optionIndex] = {
        ...selected,
        voteCount: Math.max(0, Number(selected.voteCount ?? 0)) + 1,
      };
      transaction.update(postRef, {
        poll: {
          ...poll,
          options,
          totalVotes: Math.max(0, Number(poll.totalVotes ?? 0)) + 1,
        },
        lastEngagementAt: now,
      });
    }

    transaction.create(stateRef, {
      userId,
      optionIndex,
      countedAt: now,
    });
  });
}

export const onCommunityPostPollVoted = onDocumentCreated(
  {document: 'communityPosts/{postId}/votes/{userId}', region: 'us-east1'},
  event => syncCommunityPollVote(
    'communityPosts',
    String(event.params.postId ?? ''),
    String(event.params.userId ?? ''),
  ),
);

export const onLegacyCommunityPostPollVoted = onDocumentCreated(
  {document: 'community_posts/{postId}/votes/{userId}', region: 'us-east1'},
  event => syncCommunityPollVote(
    'community_posts',
    String(event.params.postId ?? ''),
    String(event.params.userId ?? ''),
  ),
);

// ─── FLICKS ENGAGEMENT AGGREGATION ──────────────────────────────────────────
// The deterministic user marker is the canonical reaction state. A semantic
// ledger makes create/delete retries and out-of-order trigger delivery converge.
async function syncFlickLike(
  flickId: string,
  userId: string,
  eventLiked: boolean,
): Promise<void> {
  if (!flickId || !userId) return;
  const db = admin.firestore();
  const flickRef = db.collection('flicks').doc(flickId);
  const markerRef = db.collection('users').doc(userId)
    .collection('flickLikes').doc(flickId);
  const stateRef = flickRef.collection('_engagementState')
    .doc(`reaction_${engagementStateId(userId)}`);

  await db.runTransaction(async transaction => {
    const [flickSnap, markerSnap, stateSnap] = await Promise.all([
      transaction.get(flickRef),
      transaction.get(markerRef),
      transaction.get(stateRef),
    ]);
    if (!flickSnap.exists) return;

    const desired = markerSnap.exists;
    const current = stateSnap.exists
      ? stateSnap.get('liked') === true
      : !eventLiked;
    if (current === desired) return;

    const currentCount = Math.max(0, Number(flickSnap.get('likeCount') ?? 0));
    transaction.set(stateRef, {
      userId,
      liked: desired,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.update(flickRef, {
      likeCount: Math.max(0, currentCount + (desired ? 1 : -1)),
      lastEngagementAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

export const onFlickLiked = onDocumentCreated(
  {document: 'users/{userId}/flickLikes/{flickId}', region: 'us-east1'},
  event => syncFlickLike(
    String(event.params.flickId ?? ''),
    String(event.params.userId ?? ''),
    true,
  ),
);

export const onFlickUnliked = onDocumentDeleted(
  {document: 'users/{userId}/flickLikes/{flickId}', region: 'us-east1'},
  event => syncFlickLike(
    String(event.params.flickId ?? ''),
    String(event.params.userId ?? ''),
    false,
  ),
);

// Legacy immutable reaction events remain accepted during client migration and
// fold into the same semantic ledger, so marker + event delivery cannot double count.
export const onFlickEngagementEvent = onDocumentCreated(
  {document: 'flicks/{flickId}/events/{eventId}', region: 'us-east1'},
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const db = admin.firestore();
    const flickRef = db.collection('flicks').doc(event.params.flickId);
    const state = flickRef.collection('_engagementState');

    await db.runTransaction(async transaction => {
      const [eventSnap, flickSnap] = await Promise.all([
        transaction.get(snap.ref),
        transaction.get(flickRef),
      ]);
      if (!eventSnap.exists || !flickSnap.exists || eventSnap.get('processedAt')) return;

      const data = eventSnap.data() ?? {};
      const flick = flickSnap.data() ?? {};
      const type = String(data.type ?? '');
      const userId = String(data.userId ?? '');
      const sessionId = String(data.sessionId ?? '');
      const eventMillis = timestampMillis(data.createdAt);
      const now = admin.firestore.FieldValue.serverTimestamp();
      const currentCount = (field: string) => Math.max(0, Number(flick[field] ?? 0));
      const finish = (ignored = false, reason?: string) => {
        transaction.update(snap.ref, {
          processedAt: now,
          ...(ignored && {ignored: true}),
          ...(reason && {ignoreReason: reason}),
        });
      };
      const updateFlick = (updates: Record<string, number>) => {
        transaction.update(flickRef, {...updates, lastEngagementAt: now});
      };

      if (!userId || !sessionId || !eventMillis) {
        finish(true, 'invalid_event');
        return;
      }

      if (type === 'like' || type === 'unlike') {
        const reactionRef = state.doc(`reaction_${engagementStateId(userId)}`);
        const reactionSnap = await transaction.get(reactionRef);
        const currentLiked = reactionSnap.get('liked') === true;
        const desiredLiked = type === 'like';
        if (currentLiked === desiredLiked) {
          finish(true, 'duplicate_reaction');
          return;
        }

        transaction.set(reactionRef, {userId, liked: desiredLiked, updatedAt: now});
        updateFlick({likeCount: Math.max(0, currentCount('likeCount') + (desiredLiked ? 1 : -1))});
        finish();
        return;
      }

      if (type === 'view') {
        const viewerRef = state.doc(`viewer_${engagementStateId(userId)}`);
        const sessionRef = state.doc(`session_${engagementStateId(userId, sessionId)}`);
        const [viewerSnap, sessionSnap] = await Promise.all([
          transaction.get(viewerRef),
          transaction.get(sessionRef),
        ]);
        if (sessionSnap.exists) {
          finish(true, 'duplicate_session');
          return;
        }

        transaction.set(sessionRef, {userId, sessionId, startedAt: data.createdAt});
        const previousViewMillis = timestampMillis(viewerSnap.get('lastCountedAt'));
        if (previousViewMillis > 0 && eventMillis - previousViewMillis < 30 * 60 * 1000) {
          finish(true, 'view_cooldown');
          return;
        }

        transaction.set(viewerRef, {userId, lastCountedAt: data.createdAt}, {merge: true});
        const creatorId = String(flick.creatorId ?? flick.userId ?? '');
        if (userId !== creatorId) updateFlick({viewCount: currentCount('viewCount') + 1});
        finish();
        return;
      }

      if (type === 'watch_time') {
        const sessionRef = state.doc(`session_${engagementStateId(userId, sessionId)}`);
        const watchRef = state.doc(`watch_${engagementStateId(userId, sessionId)}`);
        const [sessionSnap, watchSnap] = await Promise.all([
          transaction.get(sessionRef),
          transaction.get(watchRef),
        ]);
        const startedMillis = timestampMillis(sessionSnap.get('startedAt'));
        if (!sessionSnap.exists || !startedMillis || eventMillis < startedMillis) {
          finish(true, 'unknown_session');
          return;
        }

        const elapsedSeconds = Math.floor((eventMillis - startedMillis) / 1000) + 15;
        const reportedSeconds = Math.round(Number(data.watchTime ?? 0));
        const acceptedSeconds = Math.max(0, Math.min(reportedSeconds, elapsedSeconds, 86400));
        const previousSeconds = Math.max(0, Number(watchSnap.get('accountedSeconds') ?? 0));
        const delta = Math.max(0, acceptedSeconds - previousSeconds);
        if (delta === 0) {
          finish(true, 'duplicate_watch_time');
          return;
        }

        transaction.set(watchRef, {userId, sessionId, accountedSeconds: acceptedSeconds, updatedAt: now});
        updateFlick({totalWatchTime: currentCount('totalWatchTime') + delta});
        finish();
        return;
      }

      if (type === 'share') {
        const shareRef = state.doc(`share_${engagementStateId(userId, sessionId)}`);
        const shareSnap = await transaction.get(shareRef);
        if (shareSnap.exists) {
          finish(true, 'duplicate_share');
          return;
        }
        transaction.set(shareRef, {userId, sessionId, createdAt: data.createdAt});
        updateFlick({shareCount: currentCount('shareCount') + 1});
        finish();
        return;
      }

      finish(true, 'unsupported_event');
    });
  },
);

async function syncFlickCommentCount(
  flickId: string,
  commentId: string,
  existsNow: boolean,
): Promise<void> {
  if (!flickId || !commentId) return;
  const db = admin.firestore();
  const flickRef = db.collection('flicks').doc(flickId);
  const stateRef = flickRef.collection('_engagementState')
    .doc(`comment_${engagementStateId(commentId)}`);

  await db.runTransaction(async transaction => {
    const [flickSnap, stateSnap] = await Promise.all([
      transaction.get(flickRef),
      transaction.get(stateRef),
    ]);
    if (!flickSnap.exists) return;

    const current = stateSnap.exists
      ? stateSnap.get('counted') === true
      : !existsNow;
    if (current === existsNow) return;

    const count = Math.max(0, Number(flickSnap.get('commentCount') ?? 0));
    transaction.set(stateRef, {
      commentId,
      counted: existsNow,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    transaction.update(flickRef, {
      commentCount: Math.max(0, count + (existsNow ? 1 : -1)),
      lastEngagementAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

export const onFlickCommentCreatedAggregate = onDocumentCreated(
  {document: 'videos/{flickId}/comments/{commentId}', region: 'us-east1'},
  event => syncFlickCommentCount(
    String(event.params.flickId ?? ''),
    String(event.params.commentId ?? ''),
    true,
  ),
);

export const onFlickCommentDeletedAggregate = onDocumentDeleted(
  {document: 'videos/{flickId}/comments/{commentId}', region: 'us-east1'},
  event => syncFlickCommentCount(
    String(event.params.flickId ?? ''),
    String(event.params.commentId ?? ''),
    false,
  ),
);
// ─── VIDEO ENGAGEMENT AGGREGATION ──────────────────────────────────────────
// Client facts are folded through server-only semantic ledgers. Trigger retries,
// duplicate reaction taps, refreshes, and forged random event IDs cannot inflate
// counters because every transition is validated inside the same transaction.
function engagementStateId(...parts: string[]): string {
  return createHash('sha256').update(parts.join('\u001f')).digest('hex');
}

function timestampMillis(value: unknown): number {
  return value instanceof admin.firestore.Timestamp ? value.toMillis() : 0;
}

export const onVideoEngagementEvent = onDocumentCreated(
  {document: 'videos/{videoId}/events/{eventId}', region: 'us-east1'},
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const db = admin.firestore();
    const videoRef = db.collection('videos').doc(event.params.videoId);
    const state = videoRef.collection('_engagementState');

    await db.runTransaction(async (transaction) => {
      const [eventSnap, videoSnap] = await Promise.all([
        transaction.get(snap.ref),
        transaction.get(videoRef),
      ]);
      if (!eventSnap.exists || !videoSnap.exists || eventSnap.get('processedAt')) return;

      const data = eventSnap.data() ?? {};
      const video = videoSnap.data() ?? {};
      const type = String(data.type ?? '');
      const userId = String(data.userId ?? '');
      const sessionId = String(data.sessionId ?? '');
      const eventMillis = timestampMillis(data.createdAt);
      const now = admin.firestore.FieldValue.serverTimestamp();

      const finish = (ignored = false, reason?: string) => {
        transaction.update(snap.ref, {
          processedAt: now,
          ...(ignored && {ignored: true}),
          ...(reason && {ignoreReason: reason}),
        });
      };
      const updateVideo = (updates: Record<string, number | admin.firestore.FieldValue>) => {
        transaction.update(videoRef, {...updates, lastEngagementAt: now});
      };
      const currentCount = (field: string) => Math.max(0, Number(video[field] ?? 0));

      if (!userId || !sessionId || !eventMillis) {
        finish(true, 'invalid_event');
        return;
      }

      if (['like', 'unlike', 'dislike', 'undislike'].includes(type)) {
        const reactionRef = state.doc(`reaction_${engagementStateId(userId)}`);
        const reactionSnap = await transaction.get(reactionRef);
        const current = String(reactionSnap.get('state') ?? 'none');
        let desired = current;
        if (type === 'like') desired = 'like';
        if (type === 'dislike') desired = 'dislike';
        if (type === 'unlike' && current === 'like') desired = 'none';
        if (type === 'undislike' && current === 'dislike') desired = 'none';

        if (desired === current) {
          finish(true, 'duplicate_reaction');
          return;
        }

        let likeDelta = 0;
        let dislikeDelta = 0;
        if (current === 'like') likeDelta--;
        if (current === 'dislike') dislikeDelta--;
        if (desired === 'like') likeDelta++;
        if (desired === 'dislike') dislikeDelta++;
        transaction.set(reactionRef, {userId, state: desired, updatedAt: now});
        updateVideo({
          likeCount: Math.max(0, currentCount('likeCount') + likeDelta),
          dislikeCount: Math.max(0, currentCount('dislikeCount') + dislikeDelta),
        });
        finish();
        return;
      }

      if (type === 'view') {
        const userViewRef = state.doc(`viewer_${engagementStateId(userId)}`);
        const sessionRef = state.doc(`session_${engagementStateId(userId, sessionId)}`);
        const [userViewSnap, sessionSnap] = await Promise.all([
          transaction.get(userViewRef),
          transaction.get(sessionRef),
        ]);
        if (sessionSnap.exists) {
          finish(true, 'duplicate_session');
          return;
        }

        transaction.set(sessionRef, {userId, sessionId, startedAt: data.createdAt});
        const previousViewMillis = timestampMillis(userViewSnap.get('lastCountedAt'));
        const withinCooldown = previousViewMillis > 0 && eventMillis - previousViewMillis < 30 * 60 * 1000;
        if (withinCooldown) {
          finish(true, 'view_cooldown');
          return;
        }

        transaction.set(userViewRef, {userId, lastCountedAt: data.createdAt}, {merge: true});
        const creatorId = String(video.creatorId ?? video.userId ?? '');
        if (userId !== creatorId) updateVideo({viewCount: currentCount('viewCount') + 1});
        finish();
        return;
      }

      if (type === 'watch_time') {
        const sessionRef = state.doc(`session_${engagementStateId(userId, sessionId)}`);
        const watchRef = state.doc(`watch_${engagementStateId(userId, sessionId)}`);
        const [sessionSnap, watchSnap] = await Promise.all([
          transaction.get(sessionRef),
          transaction.get(watchRef),
        ]);
        const startedMillis = timestampMillis(sessionSnap.get('startedAt'));
        if (!sessionSnap.exists || !startedMillis || eventMillis < startedMillis) {
          finish(true, 'unknown_session');
          return;
        }

        const elapsedSeconds = Math.floor((eventMillis - startedMillis) / 1000) + 15;
        const reportedSeconds = Math.round(Number(data.watchTime ?? 0));
        const acceptedSeconds = Math.max(0, Math.min(reportedSeconds, elapsedSeconds, 86400));
        const previousSeconds = Math.max(0, Number(watchSnap.get('accountedSeconds') ?? 0));
        const delta = Math.max(0, acceptedSeconds - previousSeconds);
        if (delta === 0) {
          finish(true, 'duplicate_watch_time');
          return;
        }

        transaction.set(watchRef, {userId, sessionId, accountedSeconds: acceptedSeconds, updatedAt: now});
        updateVideo({totalWatchTime: currentCount('totalWatchTime') + delta});
        finish();
        return;
      }

      if (type === 'comment') {
        const commentRef = videoRef.collection('comments').doc(sessionId);
        const countedRef = state.doc(`comment_${engagementStateId(sessionId)}`);
        const [commentSnap, countedSnap] = await Promise.all([
          transaction.get(commentRef),
          transaction.get(countedRef),
        ]);
        if (!commentSnap.exists || commentSnap.get('userId') !== userId || countedSnap.exists) {
          finish(true, 'invalid_or_duplicate_comment');
          return;
        }

        const parentCommentId = String(commentSnap.get('parentCommentId') ?? '');
        const parentRef = parentCommentId
          ? videoRef.collection('comments').doc(parentCommentId)
          : null;
        const parentSnap = parentRef ? await transaction.get(parentRef) : null;
        if (parentRef && !parentSnap?.exists) {
          finish(true, 'invalid_parent_comment');
          return;
        }

        transaction.set(countedRef, {userId, commentId: sessionId, countedAt: now});
        if (parentRef && parentSnap) {
          transaction.update(parentRef, {
            replyCount: Math.max(0, Number(parentSnap.get('replyCount') ?? 0)) + 1,
          });
        }
        updateVideo({commentCount: currentCount('commentCount') + 1});
        finish();
        return;
      }

      if (['comment_like', 'comment_unlike'].includes(type)) {
        const commentRef = videoRef.collection('comments').doc(sessionId);
        const reactionRef = state.doc(`commentReaction_${engagementStateId(userId, sessionId)}`);
        const [commentSnap, reactionSnap] = await Promise.all([
          transaction.get(commentRef),
          transaction.get(reactionRef),
        ]);
        if (!commentSnap.exists) {
          finish(true, 'comment_not_found');
          return;
        }

        const current = reactionSnap.get('liked') === true;
        const desired = type === 'comment_like';
        if (current === desired) {
          finish(true, 'duplicate_comment_reaction');
          return;
        }

        const likeCount = Math.max(0, Number(commentSnap.get('likeCount') ?? 0));
        transaction.set(reactionRef, {userId, commentId: sessionId, liked: desired, updatedAt: now});
        transaction.update(commentRef, {likeCount: Math.max(0, likeCount + (desired ? 1 : -1))});
        finish();
        return;
      }

      if (['comment_heart', 'comment_unheart'].includes(type)) {
        const creatorId = String(video.creatorId ?? video.userId ?? '');
        if (!creatorId || creatorId !== userId) {
          finish(true, 'creator_authority_required');
          return;
        }

        const commentRef = videoRef.collection('comments').doc(sessionId);
        const commentSnap = await transaction.get(commentRef);
        if (!commentSnap.exists) {
          finish(true, 'comment_not_found');
          return;
        }

        const desired = type === 'comment_heart';
        if (commentSnap.get('creatorHearted') === desired) {
          finish(true, 'duplicate_comment_heart');
          return;
        }
        transaction.update(commentRef, {creatorHearted: desired});
        finish();
        return;
      }

      if (type === 'share') {
        const shareRef = state.doc(`share_${engagementStateId(userId)}`);
        const shareSnap = await transaction.get(shareRef);
        const previousShareMillis = timestampMillis(shareSnap.get('lastCountedAt'));
        if (previousShareMillis > 0 && eventMillis - previousShareMillis < 30 * 1000) {
          finish(true, 'share_cooldown');
          return;
        }
        transaction.set(shareRef, {userId, lastCountedAt: data.createdAt}, {merge: true});
        updateVideo({shareCount: currentCount('shareCount') + 1});
        finish();
        return;
      }

      finish(true, 'unsupported_type');
    });
  }
);

const LIVE_QOE_EVENT_TYPES = new Set(['startup', 'rebuffer', 'heartbeat', 'error', 'end']);

function qoeMetric(data: admin.firestore.DocumentData, field: string, maximum: number): number | undefined {
  const value = Number(data[field]);
  if (!Number.isFinite(value) || value < 0 || value > maximum) return undefined;
  return Math.round(value);
}

// Viewer QoE is submitted as immutable, authenticated facts and folded through
// a per-session semantic ledger. Trigger retries and rapid heartbeat replays do
// not inflate creator analytics; clients never write aggregate documents.
export const onLiveQoEEvent = onDocumentCreated(
  {document: 'live_streams/{streamId}/qoe_events/{eventId}', region: 'us-east1'},
  async (event) => {
    const createdEvent = event.data;
    if (!createdEvent) return;

    const db = admin.firestore();
    const streamId = event.params.streamId;
    const streamRef = db.collection('live_streams').doc(streamId);
    const signalRef = db.collection('live_stream_quality_signals').doc(streamId);

    await db.runTransaction(async (transaction) => {
      const eventSnap = await transaction.get(createdEvent.ref);
      if (!eventSnap.exists || eventSnap.get('processedAt')) return;

      const data = eventSnap.data() ?? {};
      const userId = String(data.userId ?? '');
      const sessionId = String(data.sessionId ?? '');
      const eventType = String(data.eventType ?? '');
      const eventMillis = timestampMillis(data.createdAt);
      const sessionRef = streamRef.collection('_qoeState')
        .doc(engagementStateId(userId, sessionId));
      const [streamSnap, sessionSnap] = await Promise.all([
        transaction.get(streamRef),
        transaction.get(sessionRef),
      ]);
      const now = admin.firestore.FieldValue.serverTimestamp();
      const finish = (ignored = false, reason?: string) => {
        transaction.update(createdEvent.ref, {
          processedAt: now,
          ...(ignored && {ignored: true}),
          ...(reason && {ignoreReason: reason}),
        });
      };

      if (!streamSnap.exists || !userId || !sessionId || !eventMillis ||
          !LIVE_QOE_EVENT_TYPES.has(eventType)) {
        finish(true, 'invalid_event');
        return;
      }

      const session = sessionSnap.data() ?? {};
      if (session.endedAt && eventType !== 'end') {
        finish(true, 'session_ended');
        return;
      }

      const statePatch: Record<string, unknown> = {
        userId,
        sessionId,
        lastEventAt: data.createdAt,
        updatedAt: now,
      };
      if (eventType === 'startup') {
        if (session.startupAt) {
          finish(true, 'duplicate_startup');
          return;
        }
        statePatch.startupAt = data.createdAt;
      }
      if (eventType === 'heartbeat') {
        const lastHeartbeatMillis = timestampMillis(session.lastHeartbeatAt);
        if (lastHeartbeatMillis > 0 && eventMillis - lastHeartbeatMillis < 20_000) {
          finish(true, 'heartbeat_rate_limited');
          return;
        }
        statePatch.lastHeartbeatAt = data.createdAt;
      }
      if (eventType === 'rebuffer') {
        const rebufferCount = Math.max(0, Number(session.rebufferCount ?? 0));
        if (rebufferCount >= 100) {
          finish(true, 'rebuffer_limit_reached');
          return;
        }
        statePatch.rebufferCount = rebufferCount + 1;
      }
      if (eventType === 'error') {
        const errorCount = Math.max(0, Number(session.errorCount ?? 0));
        if (errorCount >= 20) {
          finish(true, 'error_limit_reached');
          return;
        }
        statePatch.errorCount = errorCount + 1;
      }
      if (eventType === 'end') {
        if (session.endedAt) {
          finish(true, 'duplicate_end');
          return;
        }
        statePatch.endedAt = data.createdAt;
      }

      const aggregate: Record<string, unknown> = {
        eventCount: admin.firestore.FieldValue.increment(1),
        updatedAt: now,
      };
      const startupMs = qoeMetric(data, 'startupMs', 120_000);
      const rebufferMs = qoeMetric(data, 'rebufferMs', 120_000);
      const liveLatencyMs = qoeMetric(data, 'liveLatencyMs', 300_000);
      const bitrateKbps = qoeMetric(data, 'bitrateKbps', 100_000);
      const width = qoeMetric(data, 'width', 8_192);
      const height = qoeMetric(data, 'height', 8_192);
      const droppedFrames = qoeMetric(data, 'droppedFrames', 100_000);

      if (eventType === 'startup') {
        aggregate.startupSampleCount = admin.firestore.FieldValue.increment(1);
        if (startupMs !== undefined) {
          aggregate.startupMsTotal = admin.firestore.FieldValue.increment(startupMs);
        }
      }
      if (eventType === 'rebuffer') {
        aggregate.rebufferEventCount = admin.firestore.FieldValue.increment(1);
        if (rebufferMs !== undefined) {
          aggregate.rebufferMsTotal = admin.firestore.FieldValue.increment(rebufferMs);
        }
      }
      if (eventType === 'heartbeat') {
        aggregate.heartbeatCount = admin.firestore.FieldValue.increment(1);
      }
      if (eventType === 'error') {
        aggregate.errorCount = admin.firestore.FieldValue.increment(1);
        const errorCode = String(data.errorCode ?? '').slice(0, 64);
        if (errorCode) aggregate.lastErrorCode = errorCode;
      }
      if (eventType === 'end') {
        aggregate.completedSessionCount = admin.firestore.FieldValue.increment(1);
      }
      if (liveLatencyMs !== undefined) {
        aggregate.liveLatencySampleCount = admin.firestore.FieldValue.increment(1);
        aggregate.liveLatencyMsTotal = admin.firestore.FieldValue.increment(liveLatencyMs);
      }
      if (droppedFrames !== undefined && droppedFrames > 0) {
        aggregate.droppedFramesTotal = admin.firestore.FieldValue.increment(droppedFrames);
      }
      if (bitrateKbps !== undefined) aggregate.latestBitrateKbps = bitrateKbps;
      if (width !== undefined) aggregate.latestWidth = width;
      if (height !== undefined) aggregate.latestHeight = height;

      const hourKey = new Date(eventMillis).toISOString().slice(0, 13).replace(/[-T]/g, '');
      transaction.set(sessionRef, statePatch, {merge: true});
      transaction.set(signalRef, aggregate, {merge: true});
      transaction.set(signalRef.collection('hours').doc(hourKey), aggregate, {merge: true});
      finish();
    });
  },
);

// Decrement comment and reply aggregates only when the create trigger previously
// counted the comment. A deletion ledger makes Firestore trigger retries harmless.
export const onVideoCommentDeletedAggregate = onDocumentDeleted(
  {document: 'videos/{videoId}/comments/{commentId}', region: 'us-east1'},
  async (event) => {
    const deletedComment = event.data;
    if (!deletedComment) return;

    const db = admin.firestore();
    const videoRef = db.collection('videos').doc(event.params.videoId);
    const state = videoRef.collection('_engagementState');
    const countedRef = state.doc(`comment_${engagementStateId(event.params.commentId)}`);
    const deletionRef = state.doc(`commentDeletion_${engagementStateId(event.params.commentId)}`);

    await db.runTransaction(async (transaction) => {
      const [videoSnap, countedSnap, deletionSnap] = await Promise.all([
        transaction.get(videoRef),
        transaction.get(countedRef),
        transaction.get(deletionRef),
      ]);
      if (!videoSnap.exists || deletionSnap.exists || !countedSnap.exists) return;

      const parentCommentId = String(deletedComment.get('parentCommentId') ?? '');
      const parentRef = parentCommentId
        ? videoRef.collection('comments').doc(parentCommentId)
        : null;
      const parentSnap = parentRef ? await transaction.get(parentRef) : null;
      const now = admin.firestore.FieldValue.serverTimestamp();
      const commentCount = Math.max(0, Number(videoSnap.get('commentCount') ?? 0) - 1);

      transaction.set(deletionRef, {commentId: event.params.commentId, deletedAt: now});
      transaction.update(videoRef, {commentCount, lastEngagementAt: now});
      if (parentRef && parentSnap?.exists) {
        transaction.update(parentRef, {
          replyCount: Math.max(0, Number(parentSnap.get('replyCount') ?? 0) - 1),
        });
      }
    });
  },
);

// Recompute unique authenticated viewers from connection presence. A transaction
// derives the count from current state, so concurrent joins/leaves and trigger
// retries converge on the same server-owned value.
export const syncLiveViewerCount = onValueWritten(
  {
    ref: 'live_viewers/{streamId}/viewers/{userId}/{connectionId}',
    region: 'us-east1',
  },
  async (event) => {
    const streamId = String(event.params.streamId ?? '');
    if (!streamId) return;

    const streamPresenceRef = admin.database().ref(`live_viewers/${streamId}`);
    const countResult = await streamPresenceRef.transaction(value => {
      const current = value && typeof value === 'object'
        ? value as Record<string, unknown>
        : {};
      const viewers = current.viewers && typeof current.viewers === 'object'
        ? current.viewers as Record<string, unknown>
        : {};
      const viewerCount = Object.values(viewers).reduce<number>((total, connections) => {
        if (!connections || typeof connections !== 'object') return total;
        return Object.keys(connections as Record<string, unknown>).length > 0
          ? total + 1
          : total;
      }, 0);
      return {...current, viewerCount};
    });

    const viewerCount = Math.max(0, Number(countResult.snapshot.child('viewerCount').val() ?? 0));
    const db = admin.firestore();
    await db.runTransaction(async transaction => {
      const liveRef = db.collection('live_streams').doc(streamId);
      const shoppingRef = db.collection('live_shopping_shows').doc(streamId);
      const [liveSnap, shoppingSnap] = await Promise.all([
        transaction.get(liveRef),
        transaction.get(shoppingRef),
      ]);
      const updatedAt = admin.firestore.FieldValue.serverTimestamp();
      if (liveSnap.exists) {
        transaction.update(liveRef, {
          viewerCount,
          peakViewerCount: Math.max(viewerCount, Number(liveSnap.get('peakViewerCount') ?? 0)),
          viewerCountUpdatedAt: updatedAt,
        });
      }
      if (shoppingSnap.exists) {
        transaction.update(shoppingRef, {
          viewerCount,
          peakViewerCount: Math.max(viewerCount, Number(shoppingSnap.get('peakViewerCount') ?? 0)),
          viewerCountUpdatedAt: updatedAt,
        });
      }
    });
  },
);

// Shopping analytics are immutable client facts. A semantic ledger suppresses
// duplicate onAppear callbacks and repeated checkout taps from the same session.
export const onShoppingEngagementEvent = onDocumentCreated(
  {document: 'shopping_events/{eventId}', region: 'us-east1'},
  async event => {
    const createdEvent = event.data;
    if (!createdEvent) return;

    const db = admin.firestore();
    const data = createdEvent.data() ?? {};
    const productId = String(data.productId ?? '');
    const userId = String(data.userId ?? '');
    const sessionId = String(data.sessionId ?? '');
    const type = String(data.type ?? '');
    if (!/^[A-Za-z0-9_-]{1,256}$/.test(productId) ||
        !/^[A-Za-z0-9_-]{1,128}$/.test(userId) ||
        !/^[A-Za-z0-9_-]{1,128}$/.test(sessionId) ||
        !['product_view', 'checkout_tap'].includes(type)) {
      await createdEvent.ref.set({
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        ignored: true,
        ignoreReason: 'invalid_event',
      }, {merge: true});
      return;
    }
    const productRef = db.collection('shopping_products').doc(productId);
    const state = productRef.collection('_engagementState');
    const sessionRef = state.doc(`session_${engagementStateId(type, userId, sessionId)}`);
    const viewerRef = state.doc(`viewer_${engagementStateId(userId)}`);

    await db.runTransaction(async transaction => {
      const [eventSnap, productSnap, sessionSnap, viewerSnap] = await Promise.all([
        transaction.get(createdEvent.ref),
        transaction.get(productRef),
        transaction.get(sessionRef),
        transaction.get(viewerRef),
      ]);
      if (!eventSnap.exists || eventSnap.get('processedAt')) return;

      const now = admin.firestore.FieldValue.serverTimestamp();
      const finish = (ignored = false, reason?: string) => {
        transaction.update(createdEvent.ref, {
          processedAt: now,
          ...(ignored ? {ignored: true} : {}),
          ...(reason ? {ignoreReason: reason} : {}),
        });
      };
      const eventMillis = timestampMillis(eventSnap.get('createdAt'));
      if (!productSnap.exists || !productId || !userId || !sessionId || !eventMillis ||
          !['product_view', 'checkout_tap'].includes(type)) {
        finish(true, 'invalid_event');
        return;
      }
      if (sessionSnap.exists) {
        finish(true, 'duplicate_session_event');
        return;
      }

      transaction.set(sessionRef, {type, userId, sessionId, createdAt: eventSnap.get('createdAt')});
      if (type === 'product_view') {
        const previousViewMillis = timestampMillis(viewerSnap.get('lastCountedAt'));
        if (previousViewMillis > 0 && eventMillis - previousViewMillis < 30 * 60 * 1000) {
          finish(true, 'view_cooldown');
          return;
        }
        transaction.set(viewerRef, {userId, lastCountedAt: eventSnap.get('createdAt')}, {merge: true});
        transaction.update(productRef, {
          views: Math.max(0, Number(productSnap.get('views') ?? 0)) + 1,
          lastEngagementAt: now,
        });
      } else {
        transaction.update(productRef, {
          checkoutTaps: Math.max(0, Number(productSnap.get('checkoutTaps') ?? 0)) + 1,
          lastEngagementAt: now,
        });
      }
      finish();
    });
  },
);

// Server-authoritative live reactions and shares. Per-user semantic state keeps
// retries and repeated taps from inflating public counters.
export const onLiveEngagementEvent = onDocumentCreated(
  {document: 'live_streams/{streamId}/engagement_events/{eventId}', region: 'us-east1'},
  async (event) => {
    const createdEvent = event.data;
    if (!createdEvent) return;

    const db = admin.firestore();
    const streamRef = db.collection('live_streams').doc(event.params.streamId);
    const state = streamRef.collection('_engagementState');

    await db.runTransaction(async transaction => {
      const [eventSnap, streamSnap] = await Promise.all([
        transaction.get(createdEvent.ref),
        transaction.get(streamRef),
      ]);
      if (!eventSnap.exists || !streamSnap.exists || eventSnap.get('processedAt')) return;

      const data = eventSnap.data() ?? {};
      const userId = String(data.userId ?? '');
      const type = String(data.type ?? '');
      const eventMillis = timestampMillis(data.createdAt);
      const now = admin.firestore.FieldValue.serverTimestamp();
      const finish = (ignored = false, reason?: string) => {
        transaction.update(createdEvent.ref, {
          processedAt: now,
          ...(ignored && {ignored: true}),
          ...(reason && {ignoreReason: reason}),
        });
      };
      if (!userId || !eventMillis || !['like', 'unlike', 'share'].includes(type)) {
        finish(true, 'invalid_event');
        return;
      }

      if (type === 'like' || type === 'unlike') {
        const reactionRef = state.doc(`reaction_${engagementStateId(userId)}`);
        const reactionSnap = await transaction.get(reactionRef);
        const currentlyLiked = reactionSnap.get('liked') === true;
        const desired = type === 'like';
        if (currentlyLiked === desired) {
          finish(true, 'duplicate_reaction');
          return;
        }
        const currentCount = Math.max(0, Number(streamSnap.get('likeCount') ?? 0));
        transaction.set(reactionRef, {userId, liked: desired, updatedAt: now});
        transaction.update(streamRef, {
          likeCount: Math.max(0, currentCount + (desired ? 1 : -1)),
          lastEngagementAt: now,
        });
        finish();
        return;
      }

      const shareRef = state.doc(`share_${engagementStateId(userId)}`);
      const shareSnap = await transaction.get(shareRef);
      const previousShareMillis = timestampMillis(shareSnap.get('lastCountedAt'));
      if (previousShareMillis > 0 && eventMillis - previousShareMillis < 30_000) {
        finish(true, 'share_cooldown');
        return;
      }
      const shareCount = Math.max(0, Number(streamSnap.get('shareCount') ?? 0));
      transaction.set(shareRef, {userId, lastCountedAt: data.createdAt}, {merge: true});
      transaction.update(streamRef, {shareCount: shareCount + 1, lastEngagementAt: now});
      finish();
    });
  },
);
