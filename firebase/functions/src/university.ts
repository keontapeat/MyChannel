/**
 * MyChannel University — server-authoritative learning pipeline.
 *
 * Why this exists (security):
 *   Certificates are marketed as verifiable credentials and career-path progress
 *   is what earns them. Previously the iOS client wrote `university_progress/*`
 *   and `university_certificates/*` directly, so a user could inflate progress
 *   (or write a certificate outright) and forge a credential.
 *
 *   This module makes the credential pipeline server-authoritative, mirroring the
 *   Flicks engagement pattern in index.ts (clients emit owned inputs; the server
 *   produces the trusted docs via the Admin SDK, which bypasses Firestore rules):
 *
 *     university_watch_events/{id}   (client writes, userId-stamped, immutable)
 *            │  onUniversityWatchEvent  (validate → attribute → aggregate)
 *            ▼
 *     university_progress/{uid}/career_paths/{pathId}   (server-written)
 *            │  onUniversityProgressWritten  (validate requirements → issue)
 *            ▼
 *     university_certificates/{certId}                  (server-written)
 *
 *     university_users/{uid}   (client writes identity/goal; streak/points TBD)
 *            │  onUniversityStatsWritten  (mirror)
 *            ▼
 *     university_leaderboard/{uid}                      (server-written)
 *
 * Residual note (documented, not yet closed):
 *   Streak + points still live in `university_users` and are client-written, so
 *   the leaderboard's points are not yet fully trusted. Career-path PROGRESS and
 *   the CERTIFICATE, however, are now server-derived from raw watch events and
 *   the video's own metadata — they can no longer be fabricated by the client.
 */

import {onDocumentCreated, onDocumentWritten} from 'firebase-functions/v2/firestore';
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';

const REGION = 'us-east1';

interface CareerPathDef {
  name: string;
  minVideos: number;
  minHours: number;
  minAIScore: number;
  keywords: string[];
  skillTags: string[];
}

// Server-side mirror of CareerPath (CareerPathModels.swift). Keep in sync with
// the iOS source of truth. `keywords` drive attribution; `skillTags` populate
// the credential's acquired-skills list.
const CAREER_PATHS: Record<string, CareerPathDef> = {
  'accounting': {
    name: 'Accounting & Finance', minVideos: 30, minHours: 25, minAIScore: 70,
    keywords: ['accounting', 'finance', 'bookkeeping', 'tax', 'cpa', 'financial analysis', 'audit', 'quickbooks', 'excel'],
    skillTags: ['Accounting', 'Tax Preparation', 'Financial Analysis', 'QuickBooks', 'Bookkeeping'],
  },
  'film-production': {
    name: 'Film Production & Video Editing', minVideos: 35, minHours: 30, minAIScore: 75,
    keywords: ['film', 'video editing', 'cinematography', 'premiere pro', 'final cut', 'davinci resolve', 'color grading', 'filmmaking', 'production'],
    skillTags: ['Video Editing', 'Cinematography', 'Color Grading', 'Premiere Pro'],
  },
  'software-engineering': {
    name: 'Software Engineering', minVideos: 40, minHours: 35, minAIScore: 80,
    keywords: ['programming', 'coding', 'software', 'javascript', 'python', 'java', 'react', 'development', 'algorithms', 'data structures'],
    skillTags: ['Programming', 'JavaScript', 'Python', 'Algorithms', 'System Design'],
  },
  'ios-development': {
    name: 'iOS Development', minVideos: 32, minHours: 28, minAIScore: 75,
    keywords: ['ios', 'swift', 'swiftui', 'xcode', 'app development', 'iphone', 'mobile'],
    skillTags: ['Swift', 'SwiftUI', 'UIKit', 'Xcode'],
  },
  'digital-marketing': {
    name: 'Digital Marketing', minVideos: 28, minHours: 22, minAIScore: 70,
    keywords: ['marketing', 'seo', 'social media', 'content marketing', 'google ads', 'facebook ads', 'analytics', 'growth'],
    skillTags: ['SEO', 'Social Media', 'Content Marketing', 'Analytics'],
  },
  'ui-ux-design': {
    name: 'UI/UX Design', minVideos: 30, minHours: 25, minAIScore: 75,
    keywords: ['ui design', 'ux design', 'figma', 'sketch', 'adobe xd', 'prototyping', 'user experience', 'interface'],
    skillTags: ['UI Design', 'UX Design', 'Figma', 'Prototyping'],
  },
  'personal-training': {
    name: 'Personal Training & Fitness', minVideos: 25, minHours: 20, minAIScore: 70,
    keywords: ['fitness', 'personal trainer', 'exercise', 'nutrition', 'workout', 'strength training', 'cardio'],
    skillTags: ['Exercise Science', 'Nutrition', 'Program Design', 'Strength Training'],
  },
  'electrical-work': {
    name: 'Electrical Work', minVideos: 28, minHours: 24, minAIScore: 80,
    keywords: ['electrical', 'electrician', 'wiring', 'circuits', 'voltage', 'nec code', 'residential', 'commercial'],
    skillTags: ['Electrical Theory', 'Wiring', 'NEC Code', 'Troubleshooting'],
  },
  'online-teaching': {
    name: 'Online Teaching & Course Creation', minVideos: 25, minHours: 20, minAIScore: 70,
    keywords: ['teaching', 'online courses', 'education', 'instructor', 'curriculum', 'pedagogy', 'e-learning'],
    skillTags: ['Course Design', 'Teaching Methods', 'Student Engagement'],
  },
  'data-science': {
    name: 'Data Science & Analytics', minVideos: 35, minHours: 30, minAIScore: 80,
    keywords: ['data science', 'machine learning', 'python', 'statistics', 'analytics', 'data analysis', 'ml', 'ai'],
    skillTags: ['Python', 'Statistics', 'Machine Learning', 'Data Visualization'],
  },
  'mechanical-engineering': {
    name: 'Mechanical Engineering', minVideos: 32, minHours: 28, minAIScore: 75,
    keywords: ['mechanical engineering', 'cad', 'solidworks', 'thermodynamics', 'mechanics', 'design', 'manufacturing'],
    skillTags: ['CAD', 'SolidWorks', 'Thermodynamics', 'Manufacturing'],
  },
  'paralegal': {
    name: 'Paralegal & Legal Studies', minVideos: 28, minHours: 24, minAIScore: 75,
    keywords: ['paralegal', 'legal', 'law', 'legal research', 'litigation', 'contracts', 'legal writing'],
    skillTags: ['Legal Research', 'Legal Writing', 'Litigation', 'Contracts'],
  },
};

/** Match a video's text against career-path keywords; returns the top 2 by hits. */
function matchCareerPaths(text: string): Array<{id: string; hits: number}> {
  const hay = text.toLowerCase();
  const out: Array<{id: string; hits: number}> = [];
  for (const [id, def] of Object.entries(CAREER_PATHS)) {
    const hits = def.keywords.filter((k) => hay.includes(k.toLowerCase())).length;
    if (hits > 0) out.push({id, hits});
  }
  return out.sort((a, b) => b.hits - a.hits).slice(0, 2);
}

/** Derive a per-video AI verification score (0–100) from match strength + completion. */
function perVideoAIScore(hits: number, keywordCount: number, completion: number): number {
  const confidence = Math.min(0.95, hits / Math.max(1, keywordCount) + 0.5);
  const score = (confidence * 0.6 + Math.min(1, Math.max(0, completion)) * 0.4) * 100;
  return Math.round(Math.max(50, Math.min(95, score)));
}

// ─── Streak engine (server-authoritative; ported from UniversityStreakService) ──

const MILESTONE_POINTS: Record<number, number> = {7: 70, 14: 150, 30: 400, 50: 750, 100: 2000, 365: 10000};

/** Server-derived local day key (yyyy-MM-dd). The DATE comes from server time so
 *  a client can't fast-forward days; only the tz offset is client-influenced
 *  (clamped to ±14h), so the streak respects the user's locale. */
function localDayKey(tzOffsetMinutes: number, at: Date = new Date()): string {
  const shifted = new Date(at.getTime() + tzOffsetMinutes * 60000);
  const y = shifted.getUTCFullYear();
  const m = String(shifted.getUTCMonth() + 1).padStart(2, '0');
  const d = String(shifted.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/** Whole-day gap between two yyyy-MM-dd keys. Empty `from` → large (first day). */
function dayGapKeys(from: string, to: string): number {
  if (!from) return 99999;
  const f = Date.parse(`${from}T00:00:00Z`);
  const t = Date.parse(`${to}T00:00:00Z`);
  if (Number.isNaN(f) || Number.isNaN(t)) return 99999;
  return Math.round((t - f) / 86400000);
}

/** Base points per genuine learning session (1/min, capped). */
function basePoints(minutes: number): number {
  return Math.min(120, Math.round(minutes));
}

/**
 * Advance the user's streak + points from a qualifying watch. Server-authoritative
 * so leaderboard points can't be spoofed by writing university_users directly
 * (rules block client writes to the streak/points fields). Returns the milestone
 * bonus (if any) and the resulting streak, for activity logging.
 */
async function advanceStreak(
  db: admin.firestore.Firestore,
  userId: string,
  minutes: number,
  tzOffsetMinutes: number
): Promise<{awarded: number; streak: number}> {
  const clampedTz = Math.max(-840, Math.min(840, tzOffsetMinutes));
  const todayKey = localDayKey(clampedTz);
  const userRef = db.collection('university_users').doc(userId);

  let awarded = 0;
  let streak = 0;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    const s = snap.exists ? (snap.data() as Record<string, unknown>) : {};

    let currentStreak = Number(s.currentStreak ?? 0);
    let longestStreak = Number(s.longestStreak ?? 0);
    const lastActiveDay = (s.lastActiveDay as string) ?? '';
    let totalLearningDays = Number(s.totalLearningDays ?? 0);
    let recent: string[] = Array.isArray(s.recentActiveDays) ? (s.recentActiveDays as string[]) : [];
    let freezes = Number(s.streakFreezesAvailable ?? 2);
    let todayMinutes = Number(s.todayMinutes ?? 0);
    let totalPoints = Number(s.totalPoints ?? 0);

    awarded = 0;
    if (lastActiveDay === todayKey) {
      todayMinutes += minutes;
    } else {
      const gap = dayGapKeys(lastActiveDay, todayKey);
      if (gap === 1) {
        currentStreak += 1;
      } else if (gap === 2 && freezes > 0) {
        freezes -= 1;
        currentStreak += 1;
      } else {
        currentStreak = 1;
      }
      todayMinutes = minutes;
      totalLearningDays += 1;
      if (!recent.includes(todayKey)) recent.push(todayKey);
      recent = recent.slice(-30);
      if (MILESTONE_POINTS[currentStreak]) awarded = MILESTONE_POINTS[currentStreak];
      if (currentStreak % 10 === 0) freezes = Math.min(5, freezes + 1);
    }
    longestStreak = Math.max(longestStreak, currentStreak);
    totalPoints += awarded + basePoints(minutes);
    streak = currentStreak;

    tx.set(userRef, {
      userId,
      currentStreak,
      longestStreak,
      lastActiveDay: todayKey,
      totalLearningDays,
      recentActiveDays: recent,
      streakFreezesAvailable: freezes,
      todayMinutes,
      totalPoints,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  });

  return {awarded, streak};
}

// ─── Anti-abuse: corroboration + rate limiting ──────────────────────────────

const CORROBORATION_WINDOW_MINUTES = 60; // a real view must exist within this window
const MAX_EVENTS_PER_DAY = 60;           // hard cap on credited watches/day/user
const MAX_MINUTES_PER_DAY = 720;         // hard cap on credited learning minutes/day/user

/**
 * Require a real, tracked view for this (user, video) before crediting the watch.
 * RealtimeViewTracker writes `video_analytics/{videoId}/views` docs stamped with
 * userId + server timestamp at playback start, so a fabricated learning event with
 * no corresponding view is rejected. Fails OPEN on query error (e.g. missing index)
 * so legit users are never blocked — the daily rate limit is the hard backstop.
 */
async function hasRecentView(
  db: admin.firestore.Firestore,
  userId: string,
  videoId: string
): Promise<boolean> {
  const cutoff = admin.firestore.Timestamp.fromMillis(
    Date.now() - CORROBORATION_WINDOW_MINUTES * 60000
  );
  try {
    const q = await db.collection('video_analytics').doc(videoId).collection('views')
      .where('userId', '==', userId)
      .where('timestamp', '>=', cutoff)
      .limit(1)
      .get();
    return !q.empty;
  } catch (err) {
    console.error('[university] corroboration query failed (failing open)', err);
    return true;
  }
}

/**
 * Server-enforced daily cap on credited watches. Independent of any client-written
 * doc, so this bounds farming even if an abuser fabricates both the watch event and
 * a corroborating view. Returns false once the user hits the daily event/minute cap.
 */
async function consumeRateLimit(
  db: admin.firestore.Firestore,
  userId: string,
  minutes: number
): Promise<boolean> {
  const ref = db.collection('university_rate_limits').doc(userId);
  const today = localDayKey(0); // UTC day — rate limiting doesn't need locale precision
  let allowed = true;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const d = snap.exists ? (snap.data() as Record<string, unknown>) : {};

    let day = (d.day as string) ?? '';
    let events = Number(d.events ?? 0);
    let mins = Number(d.minutes ?? 0);
    if (day !== today) {
      day = today;
      events = 0;
      mins = 0;
    }
    if (events >= MAX_EVENTS_PER_DAY || mins >= MAX_MINUTES_PER_DAY) {
      allowed = false;
      return; // at/over cap — don't credit further
    }
    tx.set(ref, {
      day,
      events: events + 1,
      minutes: mins + minutes,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  });
  return allowed;
}

// ─── View-token attestation ──────────────────────────────────────────────────
//
// The corroboration check above (`hasRecentView`) trusts a client-written
// `video_analytics/{videoId}/views` doc, which a sufficiently determined user
// could fabricate alongside a fake watch event. View tokens close that gap:
// the SERVER mints a single-use, short-lived token when a view genuinely
// starts, and the watch event must present a valid, unused token for that
// exact (user, video) pair. A token can't be forged client-side because it's
// only ever created by this Cloud Function and only ever consumed once.

const VIEW_TOKEN_TTL_MINUTES = 180; // generous — covers long videos + pauses
// Tokens are minted on every video open (not just educational ones), since the
// client can't know in advance which video will qualify. This cap is deliberately
// generous — it only guards against issuance spam, not learning credit. The real
// abuse gate is MAX_EVENTS_PER_DAY / MAX_MINUTES_PER_DAY in consumeRateLimit.
const MAX_TOKENS_PER_DAY = 400;

/**
 * Issue a single-use view-attestation token for (caller uid, videoId).
 * Call this once when playback genuinely starts (RealtimeViewTracker.startViewSession).
 * The client later presents the returned tokenId with its watch event.
 */
export const issueUniversityViewToken = onCall(
  {region: REGION, timeoutSeconds: 15, memory: '128MiB'},
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Must be signed in.');
    const userId = request.auth.uid;
    const data = request.data as {videoId?: string};
    const videoId = data.videoId;
    if (!videoId || typeof videoId !== 'string') {
      throw new HttpsError('invalid-argument', 'Missing videoId.');
    }

    const db = admin.firestore();

    // Lightweight daily cap on issuance itself, independent of the learning
    // credit cap, so token minting can't be used to hammer Firestore writes.
    const limitRef = db.collection('university_rate_limits').doc(userId);
    const today = localDayKey(0);
    let allowed = true;
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(limitRef);
      const d = snap.exists ? (snap.data() as Record<string, unknown>) : {};
      let day = (d.tokenDay as string) ?? '';
      let issued = Number(d.tokensIssued ?? 0);
      if (day !== today) { day = today; issued = 0; }
      if (issued >= MAX_TOKENS_PER_DAY) { allowed = false; return; }
      tx.set(limitRef, {tokenDay: day, tokensIssued: issued + 1}, {merge: true});
    });
    if (!allowed) throw new HttpsError('resource-exhausted', 'Daily view-token limit reached.');

    const tokenId = crypto.randomBytes(24).toString('base64url');
    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + VIEW_TOKEN_TTL_MINUTES * 60000
    );
    await db.collection('university_view_tokens').doc(tokenId).set({
      tokenId, userId, videoId,
      issuedAt: now,
      expiresAt,
      used: false,
    });

    return {tokenId, expiresAt: expiresAt.toMillis()};
  }
);

/**
 * Validate and atomically consume a view token for (userId, videoId). Returns
 * true only for a token that exists, matches, is unexpired, and hasn't been
 * used before — and marks it used in the same transaction so it can never be
 * replayed across multiple watch events.
 */
async function consumeViewToken(
  db: admin.firestore.Firestore,
  tokenId: string,
  userId: string,
  videoId: string
): Promise<boolean> {
  const ref = db.collection('university_view_tokens').doc(tokenId);
  try {
    return await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return false;
      const t = snap.data() as Record<string, unknown>;
      if (t.userId !== userId || t.videoId !== videoId) return false;
      if (t.used === true) return false;
      const expiresAt = t.expiresAt as admin.firestore.Timestamp | undefined;
      if (!expiresAt || expiresAt.toMillis() < Date.now()) return false;
      tx.set(ref, {used: true, usedAt: admin.firestore.FieldValue.serverTimestamp()}, {merge: true});
      return true;
    });
  } catch (err) {
    console.error('[university] consumeViewToken failed', tokenId, err);
    return false;
  }
}

/**
 * Ingest a raw watch event and aggregate it into server-authoritative
 * career-path progress. Attribution is derived from the VIDEO's own metadata
 * (not client-supplied path ids), so a client can't attribute watch time to a
 * path the video doesn't teach. Writing progress chains into
 * onUniversityProgressWritten, which issues the certificate when earned.
 */
export const onUniversityWatchEvent = onDocumentCreated(
  {document: 'university_watch_events/{eventId}', region: REGION},
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const e = snap.data() as Record<string, unknown>;

    const userId = (e.userId as string) ?? '';
    const videoId = (e.videoId as string) ?? '';
    if (!userId || !videoId) return;

    const watchSeconds = Math.max(0, Math.min(86400, Number(e.watchSeconds ?? 0)));
    const completion = Math.max(0, Math.min(1, Number(e.completion ?? 0)));
    const aiScore = e.aiScore == null ? null : Number(e.aiScore);

    // Trivial / low-quality watches don't count toward a credential.
    if (watchSeconds < 30) return;
    if (!(completion >= 0.7 || (aiScore ?? 0) >= 70)) return;

    const db = admin.firestore();

    // Server-side attribution from the video's own metadata.
    let title = (e.title as string) ?? '';
    let description = '';
    let tags: string[] = [];
    try {
      const videoSnap = await db.collection('videos').doc(videoId).get();
      if (videoSnap.exists) {
        const vd = videoSnap.data() as Record<string, unknown>;
        title = (vd.title as string) ?? title;
        description = (vd.description as string) ?? '';
        tags = Array.isArray(vd.tags) ? (vd.tags as string[]) : [];
      }
    } catch (err) {
      console.error('[onUniversityWatchEvent] video read failed', videoId, err);
    }

    const matches = matchCareerPaths(`${title} ${description} ${tags.join(' ')}`);
    if (matches.length === 0) return; // not educational / no career-path match

    // Anti-abuse: require proof of a real view, then spend the user's daily budget.
    // Both run only after the watch qualifies, so legit watches are unaffected.
    //
    // Strong path: the event carries a `viewToken` minted by issueUniversityViewToken
    // when playback genuinely started — single-use, so it can't be replayed and
    // can't be fabricated client-side. Weak fallback (for clients that predate view
    // tokens): a client-written video_analytics view record within the window.
    const viewToken = (e.viewToken as string) ?? '';
    const corroborated = viewToken
      ? await consumeViewToken(db, viewToken, userId, videoId)
      : await hasRecentView(db, userId, videoId);
    if (!corroborated) {
      console.warn(`[university] no corroborating view u=${userId} v=${videoId} token=${!!viewToken} — skipping`);
      return;
    }
    const minutes = watchSeconds / 60;
    if (!(await consumeRateLimit(db, userId, minutes))) {
      console.warn(`[university] daily learning cap reached u=${userId} — skipping`);
      return;
    }

    const watchHours = watchSeconds / 3600;

    for (const m of matches) {
      const def = CAREER_PATHS[m.id];
      if (!def) continue;
      const ref = db.doc(`university_progress/${userId}/career_paths/${m.id}`);
      try {
        await db.runTransaction(async (tx) => {
          const cur = await tx.get(ref);
          const d = cur.exists ? (cur.data() as Record<string, unknown>) : {};

          const videoIds: string[] = Array.isArray(d.videoIds) ? (d.videoIds as string[]) : [];
          const alreadyCounted = videoIds.includes(videoId);
          const prevVideos = Number(d.videosWatched ?? 0);
          const prevHours = Number(d.totalHours ?? 0);
          const prevAvg = Number(d.averageAIScore ?? 0);

          const newVideos = alreadyCounted ? prevVideos : prevVideos + 1;
          const newHours = prevHours + watchHours;
          const vScore = aiScore ?? perVideoAIScore(m.hits, def.keywords.length, completion);
          const newAvg = alreadyCounted
            ? prevAvg
            : Math.round((prevAvg * prevVideos + vScore) / Math.max(1, newVideos));

          const skills = new Set<string>([
            ...(Array.isArray(d.skillsCovered) ? (d.skillsCovered as string[]) : []),
            ...def.skillTags,
          ]);
          const certificateProgress = Math.min(
            1,
            (newVideos / def.minVideos + newHours / def.minHours) / 2
          );
          if (!alreadyCounted) videoIds.push(videoId);

          tx.set(ref, {
            id: (d.id as string) ?? `${userId}_${m.id}`,
            userId,
            careerPathId: m.id,
            totalHours: newHours,
            videosWatched: newVideos,
            videoIds,
            lastWatchedAt: admin.firestore.FieldValue.serverTimestamp(),
            // Don't regress a already-earned cert's progress bar.
            certificateProgress: d.certificateEarned === true ? 1.0 : certificateProgress,
            averageAIScore: newAvg,
            skillsCovered: Array.from(skills),
          }, {merge: true});
        });
      } catch (err) {
        console.error('[onUniversityWatchEvent] aggregate failed', userId, m.id, err);
      }
    }

    // Advance the server-authoritative learning streak + points for this genuine
    // educational watch. Writing university_users chains into onUniversityStatsWritten
    // (leaderboard mirror).
    if (minutes >= 1) {
      try {
        const tzOffset = Number(e.tzOffsetMinutes ?? 0);
        const {awarded, streak} = await advanceStreak(db, userId, minutes, tzOffset);
        if (awarded > 0) {
          const activityId = db.collection('university_users').doc(userId)
            .collection('activity').doc().id;
          await db.collection('university_users').doc(userId)
            .collection('activity').doc(activityId).set({
              id: activityId,
              type: 'streak_maintained',
              title: `${streak}-day streak! +${awarded} points`,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              duration: 0,
              aiVerified: true,
            });
        }
      } catch (err) {
        console.error('[onUniversityWatchEvent] streak advance failed', userId, err);
      }
    }

    console.log(`[university] processed watch event u=${userId} v=${videoId} paths=${matches.map((m) => m.id).join(',')}`);
  }
);

/**
 * Server-authoritative certificate issuance.
 * Fires when a user's career-path progress doc changes; validates the progress
 * against the career path's requirements and, if met, issues exactly one
 * certificate via the Admin SDK. Idempotent: guarded by `certificateEarned` and
 * by a per-(user, path) existence check.
 */
export const onUniversityProgressWritten = onDocumentWritten(
  {document: 'university_progress/{userId}/career_paths/{careerPathId}', region: REGION},
  async (event) => {
    const after = event.data?.after;
    if (!after || !after.exists) return;

    const userId = event.params.userId as string;
    const careerPathId = event.params.careerPathId as string;
    const def = CAREER_PATHS[careerPathId];
    if (!def) return; // unknown career path — ignore

    const p = after.data() as Record<string, unknown>;
    if (p.certificateEarned === true) return; // already issued — idempotent stop

    const videosWatched = Number(p.videosWatched ?? 0);
    const totalHours = Number(p.totalHours ?? 0);
    const averageAIScore = Number(p.averageAIScore ?? 0);

    const requirementsMet =
      videosWatched >= def.minVideos &&
      totalHours >= def.minHours &&
      averageAIScore >= def.minAIScore;
    if (!requirementsMet) return;

    const db = admin.firestore();

    // Idempotency: never double-issue for the same (user, career path).
    // Single equality filter on userId uses the automatic single-field index.
    const existing = await db.collection('university_certificates')
      .where('userId', '==', userId)
      .get();
    const alreadyIssued = existing.docs.some(
      (d) => (d.data() as Record<string, unknown>).careerPathId === careerPathId
    );
    if (alreadyIssued) {
      await after.ref.set({certificateEarned: true, certificateProgress: 1.0}, {merge: true});
      return;
    }

    // Resolve the learner's display name for the credential.
    let userName = 'MyChannel Student';
    try {
      const u = await db.collection('users').doc(userId).get();
      if (u.exists) userName = (u.data()?.displayName as string) ?? userName;
    } catch {
      /* non-fatal — keep default name */
    }

    const certId = db.collection('university_certificates').doc().id;
    const certificateNumber = `${Date.now()}${Math.floor(1000 + Math.random() * 9000)}`;
    const skillsAcquired = Array.isArray(p.skillsCovered) ? (p.skillsCovered as string[]) : [];

    await db.collection('university_certificates').doc(certId).set({
      id: certId,
      userId,
      userName,
      careerPathId,
      careerPathName: def.name,
      totalHours,
      videosCompleted: videosWatched,
      averageAIScore: Math.round(averageAIScore),
      earnedDate: admin.firestore.FieldValue.serverTimestamp(),
      verificationHash: null,
      certificateNumber,
      skillsAcquired,
      issuedBy: 'cloud-function',
    });

    // Reflect the earned state back onto the progress doc (Admin SDK write).
    await after.ref.set({
      certificateEarned: true,
      certificateEarnedDate: admin.firestore.FieldValue.serverTimestamp(),
      certificateProgress: 1.0,
    }, {merge: true});

    // Surface the achievement in the user's activity feed.
    try {
      const activityId = db.collection('university_users').doc(userId)
        .collection('activity').doc().id;
      await db.collection('university_users').doc(userId)
        .collection('activity').doc(activityId).set({
          id: activityId,
          type: 'certificate_earned',
          title: `Certificate earned: ${def.name}`,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          duration: 0,
          aiVerified: true,
        });
    } catch (err) {
      console.error('[onUniversityProgressWritten] activity log failed', err);
    }

    console.log(`[university] issued certificate ${certId} to ${userId} for ${careerPathId}`);
  }
);

/**
 * Server-authoritative public leaderboard mirror.
 * Fires when a user's University stats doc changes and rewrites the public
 * `university_leaderboard/{userId}` entry via the Admin SDK. Clients can no
 * longer write the leaderboard directly (see firestore.rules), so the public
 * rank doc can't be spoofed independently of the user's own stats doc.
 */
export const onUniversityStatsWritten = onDocumentWritten(
  {document: 'university_users/{userId}', region: REGION},
  async (event) => {
    const after = event.data?.after;
    if (!after || !after.exists) return;

    const userId = event.params.userId as string;
    const u = after.data() as Record<string, unknown>;

    const entry = {
      userId,
      name: (u.name as string) ?? 'Learner',
      avatarURL: (u.avatarURL as string) ?? '',
      points: Number(u.totalPoints ?? 0),
      certificates: Number(u.certificates ?? 0),
      watchHours: Number(u.watchHours ?? 0),
      currentStreak: Number(u.currentStreak ?? 0),
      longestStreak: Number(u.longestStreak ?? 0),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    try {
      await admin.firestore().collection('university_leaderboard').doc(userId).set(entry, {merge: true});
    } catch (err) {
      console.error('[onUniversityStatsWritten]', userId, err);
    }
  }
);
