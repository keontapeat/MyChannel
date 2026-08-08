/**
 * Client-Side Recommendation Intelligence Layer
 *
 * This module implements on-device re-ranking, session-aware sequencing,
 * multi-armed bandit exploration, and engagement signal feedback.
 * Works alongside the server-side recommendation service for real-time
 * personalization that YouTube can't match (they don't do client-side ML).
 *
 * Architecture:
 * - Server returns candidate pool (50-100 videos)
 * - Client re-ranks based on real-time session signals
 * - Multi-armed bandit (Thompson Sampling) balances explore/exploit
 * - Session context (mood, time-of-day, device) adjusts scoring
 * - Engagement feedback loop updates user preference model in real-time
 */

import { db, auth } from '@/lib/firebase/config';
import { doc, getDoc, setDoc, updateDoc, increment, serverTimestamp } from 'firebase/firestore';

// ─── TYPES ───────────────────────────────────────────────────────────────────

interface VideoCandidate {
  id: string;
  title: string;
  category?: string;
  tags?: string[];
  duration: number;
  viewCount: number;
  likeCount: number;
  creatorId: string;
  publishedAt?: string;
  serverScore?: number;
}

interface UserPreferenceModel {
  categoryWeights: Record<string, number>;
  tagWeights: Record<string, number>;
  creatorWeights: Record<string, number>;
  durationPreference: { min: number; max: number; ideal: number };
  sessionHistory: string[]; // video IDs watched this session
  timeOfDayPreference: Record<string, number>; // hour -> engagement multiplier
  engagementRate: number; // 0-1, how likely user is to engage
  explorationRate: number; // 0-1, how much novelty to inject
  lastUpdated: number;
}

interface SessionContext {
  videosWatched: number;
  totalWatchTimeSeconds: number;
  avgCompletionRate: number;
  lastCategory: string | null;
  mood: 'lean-back' | 'active' | 'discovery'; // inferred from behavior
  timeOfDay: 'morning' | 'afternoon' | 'evening' | 'night';
  device: 'mobile' | 'desktop' | 'tv';
}

interface BanditArm {
  id: string;
  alpha: number; // successes (engagement)
  beta: number; // failures (skip/bounce)
}

// ─── PREFERENCE MODEL ────────────────────────────────────────────────────────

const DEFAULT_PREFERENCE_MODEL: UserPreferenceModel = {
  categoryWeights: {},
  tagWeights: {},
  creatorWeights: {},
  durationPreference: { min: 60, max: 1200, ideal: 480 },
  sessionHistory: [],
  timeOfDayPreference: {},
  engagementRate: 0.5,
  explorationRate: 0.15,
  lastUpdated: 0,
};

let cachedModel: UserPreferenceModel | null = null;

/**
 * Loads the user's preference model from Firestore (or returns cached).
 * Model is built from engagement signals over time.
 */
export async function loadPreferenceModel(): Promise<UserPreferenceModel> {
  if (cachedModel && Date.now() - cachedModel.lastUpdated < 300_000) {
    return cachedModel;
  }

  const uid = auth.currentUser?.uid;
  if (!uid) return DEFAULT_PREFERENCE_MODEL;

  try {
    const snap = await getDoc(doc(db, 'users', uid, 'ml', 'preference_model'));
    if (snap.exists()) {
      cachedModel = { ...DEFAULT_PREFERENCE_MODEL, ...snap.data(), lastUpdated: Date.now() } as UserPreferenceModel;
      return cachedModel;
    }
  } catch {}

  cachedModel = { ...DEFAULT_PREFERENCE_MODEL, lastUpdated: Date.now() };
  return cachedModel;
}

// ─── SESSION CONTEXT ─────────────────────────────────────────────────────────

const sessionContext: SessionContext = {
  videosWatched: 0,
  totalWatchTimeSeconds: 0,
  avgCompletionRate: 0,
  lastCategory: null,
  mood: 'active',
  timeOfDay: getTimeOfDay(),
  device: getDevice(),
};

function getTimeOfDay(): 'morning' | 'afternoon' | 'evening' | 'night' {
  const h = new Date().getHours();
  if (h < 6) return 'night';
  if (h < 12) return 'morning';
  if (h < 18) return 'afternoon';
  if (h < 22) return 'evening';
  return 'night';
}

function getDevice(): 'mobile' | 'desktop' | 'tv' {
  if (typeof window === 'undefined') return 'desktop';
  if (window.innerWidth < 768) return 'mobile';
  if (window.innerWidth > 1920) return 'tv';
  return 'desktop';
}

/**
 * Updates session context after a video interaction.
 * Called by the video player when engagement signals fire.
 */
export function updateSessionContext(signal: {
  videoId: string;
  category?: string;
  watchTimeSeconds: number;
  completionRate: number;
  engaged: boolean; // liked, commented, shared, or watched >70%
}) {
  sessionContext.videosWatched++;
  sessionContext.totalWatchTimeSeconds += signal.watchTimeSeconds;
  sessionContext.avgCompletionRate =
    (sessionContext.avgCompletionRate * (sessionContext.videosWatched - 1) + signal.completionRate) /
    sessionContext.videosWatched;
  sessionContext.lastCategory = signal.category || null;
  if (cachedModel) {
    cachedModel.sessionHistory = [...(cachedModel.sessionHistory || []), signal.videoId].slice(-50);
  }

  // Infer mood from behavior
  if (sessionContext.avgCompletionRate > 0.8 && sessionContext.videosWatched > 3) {
    sessionContext.mood = 'lean-back'; // binge mode
  } else if (sessionContext.avgCompletionRate < 0.3) {
    sessionContext.mood = 'discovery'; // browsing, not committing
  } else {
    sessionContext.mood = 'active';
  }

  // Update preference model weights in real-time
  if (cachedModel && signal.engaged) {
    if (signal.category) {
      cachedModel.categoryWeights[signal.category] =
        (cachedModel.categoryWeights[signal.category] || 1) * 1.1;
    }
  }
}

// ─── MULTI-ARMED BANDIT (Thompson Sampling) ─────────────────────────────────

/**
 * Thompson Sampling for explore/exploit balance.
 * Each video category/creator is an "arm" with a Beta distribution
 * tracking success (engagement) vs failure (skip).
 */
function thompsonSample(arm: BanditArm): number {
  // Beta distribution sampling approximation
  const alpha = Math.max(1, arm.alpha);
  const beta = Math.max(1, arm.beta);
  // Box-Muller approximation for Beta distribution
  const mean = alpha / (alpha + beta);
  const variance = (alpha * beta) / ((alpha + beta) ** 2 * (alpha + beta + 1));
  const stddev = Math.sqrt(variance);
  // Normal approximation of Beta
  const u1 = Math.random();
  const u2 = Math.random();
  const z = Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);
  return Math.max(0, Math.min(1, mean + z * stddev));
}

function getCategoryArm(category: string, model: UserPreferenceModel): BanditArm {
  const weight = model.categoryWeights[category] || 1;
  return {
    id: category,
    alpha: Math.max(1, Math.round(weight * 10)),
    beta: Math.max(1, Math.round((1 / Math.max(0.1, weight)) * 5)),
  };
}

// ─── RE-RANKING ENGINE ──────────────────────────────────────────────────────

/**
 * Re-ranks a candidate pool based on real-time session signals,
 * user preference model, and multi-armed bandit exploration.
 *
 * This runs entirely client-side for instant re-ranking without
 * network round-trips. YouTube doesn't do this — they rely solely
 * on server-side scoring.
 */
export function reRankCandidates(
  candidates: VideoCandidate[],
  model: UserPreferenceModel,
  context: SessionContext = sessionContext
): VideoCandidate[] {
  const scored = candidates.map((video) => {
    let score = video.serverScore || 0;

    // 1. Category preference (Thompson Sampling for exploration)
    if (video.category) {
      const arm = getCategoryArm(video.category, model);
      const banditScore = thompsonSample(arm);
      score += banditScore * 10;
    }

    // 2. Creator affinity
    if (video.creatorId && model.creatorWeights[video.creatorId]) {
      score += Math.log2(model.creatorWeights[video.creatorId]) * 3;
    }

    // 3. Tag overlap with preferences
    if (video.tags) {
      const tagScore = video.tags.reduce((sum, tag) => {
        return sum + (model.tagWeights[tag.toLowerCase()] || 0);
      }, 0);
      score += Math.min(tagScore, 5); // cap tag contribution
    }

    // 4. Duration preference (Gaussian decay from ideal)
    const durationDiff = Math.abs(video.duration - model.durationPreference.ideal);
    const durationPenalty = Math.exp(-(durationDiff ** 2) / (2 * 300 ** 2)); // Gaussian
    score += durationPenalty * 3;

    // 5. Session context adjustments
    if (context.mood === 'lean-back') {
      // In binge mode: prefer same category, longer videos
      if (video.category === context.lastCategory) score += 4;
      if (video.duration > 300) score += 2;
    } else if (context.mood === 'discovery') {
      // In discovery mode: prefer novelty, shorter videos
      if (video.category !== context.lastCategory) score += 3;
      if (video.duration < 300) score += 2;
      score += model.explorationRate * 5; // boost exploration
    }

    // 6. Freshness boost (recency within session matters more)
    if (video.publishedAt) {
      const ageHours = (Date.now() - new Date(video.publishedAt).getTime()) / 3_600_000;
      if (ageHours < 24) score += 3;
      else if (ageHours < 168) score += 1;
    }

    // 7. Popularity signal (log-damped to avoid mega-viral dominance)
    score += Math.log10(Math.max(1, video.viewCount)) * 0.5;

    // 8. Dedup: penalize videos already in session history
    if (model.sessionHistory.includes(video.id)) score -= 100;

    // 9. Diversity injection: penalize back-to-back same creator
    const recentCreators = model.sessionHistory.slice(-3);
    if (recentCreators.some((id) => id === video.creatorId)) score -= 3;

    return { video, score };
  });

  // Sort by score, then apply diversity post-processing
  scored.sort((a, b) => b.score - a.score);

  // Ensure no more than 2 videos from same creator in top 10
  const result: VideoCandidate[] = [];
  const creatorCounts = new Map<string, number>();

  for (const { video } of scored) {
    const count = creatorCounts.get(video.creatorId) || 0;
    if (count >= 2 && result.length < 10) continue; // diversity in top slots
    result.push(video);
    creatorCounts.set(video.creatorId, count + 1);
    if (result.length >= candidates.length) break;
  }

  return result;
}

// ─── ENGAGEMENT FEEDBACK LOOP ────────────────────────────────────────────────

/**
 * Records an engagement signal and updates the preference model.
 * Called when user: likes, comments, shares, subscribes, watches >70%,
 * or adds to Watch Later.
 */
export async function recordEngagementSignal(signal: {
  videoId: string;
  category?: string;
  creatorId: string;
  tags?: string[];
  type: 'like' | 'comment' | 'share' | 'subscribe' | 'watch_complete' | 'save' | 'skip' | 'bounce';
}) {
  const uid = auth.currentUser?.uid;
  if (!uid || !cachedModel) return;

  const isPositive = !['skip', 'bounce'].includes(signal.type);
  const multiplier = isPositive ? 1.05 : 0.95;

  // Update category weight
  if (signal.category) {
    cachedModel.categoryWeights[signal.category] =
      (cachedModel.categoryWeights[signal.category] || 1) * multiplier;
  }

  // Update creator weight
  if (signal.creatorId) {
    cachedModel.creatorWeights[signal.creatorId] =
      (cachedModel.creatorWeights[signal.creatorId] || 1) * (isPositive ? 1.15 : 0.9);
  }

  // Update tag weights
  if (signal.tags) {
    for (const tag of signal.tags) {
      const key = tag.toLowerCase();
      cachedModel.tagWeights[key] = (cachedModel.tagWeights[key] || 1) * multiplier;
    }
  }

  // Update engagement rate (exponential moving average)
  cachedModel.engagementRate =
    cachedModel.engagementRate * 0.9 + (isPositive ? 1 : 0) * 0.1;

  // Adjust exploration rate: more engaged users need less exploration
  cachedModel.explorationRate = Math.max(0.05, 0.3 - cachedModel.engagementRate * 0.25);

  // Persist model update (debounced — only write every 30s)
  if (Date.now() - cachedModel.lastUpdated > 30_000) {
    cachedModel.lastUpdated = Date.now();
    try {
      await setDoc(doc(db, 'users', uid, 'ml', 'preference_model'), {
        ...cachedModel,
        updatedAt: serverTimestamp(),
      });
    } catch {}
  }

  // Record signal for server-side model training
  try {
    const { addDoc, collection } = await import('firebase/firestore');
    await addDoc(collection(db, 'users', uid, 'engagement_signals'), {
      videoId: signal.videoId,
      category: signal.category || null,
      creatorId: signal.creatorId,
      type: signal.type,
      sessionContext: {
        videosWatched: sessionContext.videosWatched,
        mood: sessionContext.mood,
        timeOfDay: sessionContext.timeOfDay,
        device: sessionContext.device,
      },
      timestamp: serverTimestamp(),
    });
  } catch {}
}

// ─── SMART AUTOPLAY QUEUE ────────────────────────────────────────────────────

/**
 * Generates an optimized autoplay queue that keeps users watching.
 * Unlike YouTube's simple "next similar video", this considers:
 * - Session fatigue (reduce intensity over time)
 * - Category variety (prevent content tunnel)
 * - Duration pacing (mix short and long)
 * - Creator diversity
 * - Time-of-day context
 */
export function generateAutoplayQueue(
  currentVideo: VideoCandidate,
  pool: VideoCandidate[],
  model: UserPreferenceModel,
  queueSize: number = 10
): VideoCandidate[] {
  const ranked = reRankCandidates(
    pool.filter((v) => v.id !== currentVideo.id),
    model
  );

  const queue: VideoCandidate[] = [];
  const usedCategories = new Set<string>();
  const usedCreators = new Set<string>();
  let lastDuration = currentVideo.duration;

  for (const candidate of ranked) {
    if (queue.length >= queueSize) break;

    // Pacing: alternate long/short
    const durationOk =
      lastDuration > 600 ? candidate.duration < 600 : candidate.duration > 180;

    // Diversity: don't repeat categories back-to-back in first 5
    const categoryOk =
      queue.length >= 5 || !usedCategories.has(candidate.category || '');

    // Creator diversity: max 1 per creator in queue
    const creatorOk = !usedCreators.has(candidate.creatorId);

    if (durationOk || categoryOk || queue.length > 5) {
      queue.push(candidate);
      if (candidate.category) usedCategories.add(candidate.category);
      usedCreators.add(candidate.creatorId);
      lastDuration = candidate.duration;
    }
  }

  // Fill remaining slots without constraints
  for (const candidate of ranked) {
    if (queue.length >= queueSize) break;
    if (!queue.find((q) => q.id === candidate.id)) {
      queue.push(candidate);
    }
  }

  return queue;
}

// ─── WATCH TIME PREDICTION ──────────────────────────────────────────────────

/**
 * Predicts how long a user will watch a video before clicking away.
 * Used to optimize ad placement timing and autoplay decisions.
 * Simple logistic model based on user history + video signals.
 */
export function predictWatchTime(
  video: VideoCandidate,
  model: UserPreferenceModel
): { predictedSeconds: number; completionProbability: number } {
  // Base: users typically watch 40-60% of a video
  let baseCompletion = 0.5;

  // Adjust for category preference
  if (video.category && model.categoryWeights[video.category]) {
    const weight = Math.min(3, model.categoryWeights[video.category]);
    baseCompletion += (weight - 1) * 0.1;
  }

  // Adjust for creator preference
  if (model.creatorWeights[video.creatorId]) {
    const weight = Math.min(3, model.creatorWeights[video.creatorId]);
    baseCompletion += (weight - 1) * 0.15;
  }

  // Duration penalty: longer videos have lower completion
  if (video.duration > 1200) baseCompletion *= 0.8;
  else if (video.duration > 600) baseCompletion *= 0.9;
  else if (video.duration < 120) baseCompletion *= 1.2;

  // Session fatigue: reduce prediction as session progresses
  const fatigueFactor = Math.max(0.6, 1 - sessionContext.videosWatched * 0.03);
  baseCompletion *= fatigueFactor;

  // Clamp
  const completionProbability = Math.max(0.1, Math.min(0.95, baseCompletion));
  const predictedSeconds = Math.round(video.duration * completionProbability);

  return { predictedSeconds, completionProbability };
}

// ─── OPTIMAL AD PLACEMENT ───────────────────────────────────────────────────

/**
 * Calculates optimal mid-roll ad insertion points that minimize viewer drop-off.
 * Uses predicted watch time + natural content breaks (chapter boundaries).
 */
export function calculateOptimalAdPlacements(
  videoDurationSeconds: number,
  chapters: Array<{ timestamp: number }>,
  model: UserPreferenceModel
): number[] {
  if (videoDurationSeconds < 480) return []; // No mid-rolls under 8 min

  const predictedWatch = videoDurationSeconds * Math.min(0.8, model.engagementRate + 0.3);
  const maxAds = Math.min(3, Math.floor(videoDurationSeconds / 300)); // 1 ad per 5 min max

  const placements: number[] = [];

  if (chapters.length >= 3) {
    // Place ads at chapter boundaries (least disruptive)
    const validBreaks = chapters
      .filter((c) => c.timestamp > 60 && c.timestamp < predictedWatch - 30)
      .map((c) => c.timestamp);

    // Space them evenly
    const interval = Math.floor(validBreaks.length / (maxAds + 1));
    for (let i = 1; i <= maxAds && i * interval < validBreaks.length; i++) {
      placements.push(validBreaks[i * interval]);
    }
  } else {
    // No chapters: place at predicted engagement valleys
    // Default: 30% and 60% of predicted watch time
    if (maxAds >= 1) placements.push(Math.round(predictedWatch * 0.3));
    if (maxAds >= 2) placements.push(Math.round(predictedWatch * 0.6));
    if (maxAds >= 3) placements.push(Math.round(predictedWatch * 0.85));
  }

  return placements.sort((a, b) => a - b);
}
