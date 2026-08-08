/**
 * Smart Notification Delivery Engine
 *
 * Client-side notification intelligence that determines:
 * - WHEN to show notifications (optimal timing per user)
 * - WHAT to show (relevance ranking)
 * - HOW MANY to show (fatigue prevention)
 * - WHAT FORMAT (preview, digest, or full)
 *
 * Works with the server-side SmartNotificationAgent for policy decisions.
 */

import { db, auth } from '@/lib/firebase/config';
import { doc, getDoc, setDoc, serverTimestamp, collection, query, where, orderBy, limit, getDocs } from 'firebase/firestore';

interface NotificationPreferences {
  quietHoursStart: number; // hour (0-23)
  quietHoursEnd: number;
  maxPerDay: number;
  maxPerHour: number;
  digestEnabled: boolean;
  digestTime: string; // "18:00"
  categories: Record<string, boolean>; // which types are enabled
  frequencyMultiplier: number; // 0.5 = half as many, 2 = double
}

interface NotificationCandidate {
  id: string;
  type: 'new_video' | 'live_now' | 'vs_match' | 'community' | 'comment_reply' | 'milestone' | 'recommendation';
  title: string;
  body: string;
  priority: number; // 0-10
  creatorId?: string;
  videoId?: string;
  createdAt: Date;
  expiresAt?: Date;
}

interface DeliveryDecision {
  shouldDeliver: boolean;
  reason: string;
  delay?: number; // ms to wait before showing
  format: 'full' | 'silent' | 'digest' | 'suppress';
}

const DEFAULT_PREFS: NotificationPreferences = {
  quietHoursStart: 23,
  quietHoursEnd: 7,
  maxPerDay: 15,
  maxPerHour: 3,
  digestEnabled: true,
  digestTime: '18:00',
  categories: {
    new_video: true,
    live_now: true,
    vs_match: true,
    community: true,
    comment_reply: true,
    milestone: true,
    recommendation: true,
  },
  frequencyMultiplier: 1.0,
};

/**
 * Determines whether and how to deliver a notification.
 * Implements intelligent suppression, timing, and formatting.
 */
export async function evaluateNotification(
  candidate: NotificationCandidate
): Promise<DeliveryDecision> {
  const prefs = await loadNotificationPreferences();
  const hour = new Date().getHours();

  // 1. Quiet hours check
  if (isQuietHours(hour, prefs)) {
    if (candidate.priority >= 9) {
      // Critical notifications (vs match accepted, payout) bypass quiet hours
      return { shouldDeliver: true, reason: 'critical_override', format: 'full' };
    }
    return { shouldDeliver: false, reason: 'quiet_hours', format: 'suppress' };
  }

  // 2. Category preference check
  if (!prefs.categories[candidate.type]) {
    return { shouldDeliver: false, reason: 'category_disabled', format: 'suppress' };
  }

  // 3. Rate limiting
  const recentCount = await getRecentNotificationCount(60); // last hour
  if (recentCount >= prefs.maxPerHour * prefs.frequencyMultiplier) {
    if (candidate.priority >= 8) {
      return { shouldDeliver: true, reason: 'high_priority_override', format: 'silent' };
    }
    return { shouldDeliver: false, reason: 'rate_limited', format: 'digest' };
  }

  // 4. Expired notifications
  if (candidate.expiresAt && candidate.expiresAt < new Date()) {
    return { shouldDeliver: false, reason: 'expired', format: 'suppress' };
  }

  // 5. Engagement-based timing optimization
  const optimalDelay = calculateOptimalDelay(hour, candidate.type);

  // 6. Priority-based format selection
  let format: 'full' | 'silent' | 'digest' = 'full';
  if (candidate.priority <= 3) format = 'silent';
  else if (candidate.priority <= 5 && prefs.digestEnabled) format = 'digest';

  return {
    shouldDeliver: true,
    reason: 'approved',
    delay: optimalDelay,
    format,
  };
}

/**
 * Batches low-priority notifications into a digest.
 * Returns a single digest notification summarizing multiple events.
 */
export function createDigest(
  notifications: NotificationCandidate[]
): NotificationCandidate | null {
  if (notifications.length === 0) return null;
  if (notifications.length === 1) return notifications[0];

  const videoCount = notifications.filter((n) => n.type === 'new_video').length;
  const liveCount = notifications.filter((n) => n.type === 'live_now').length;
  const otherCount = notifications.length - videoCount - liveCount;

  const parts: string[] = [];
  if (videoCount > 0) parts.push(`${videoCount} new video${videoCount > 1 ? 's' : ''}`);
  if (liveCount > 0) parts.push(`${liveCount} live now`);
  if (otherCount > 0) parts.push(`${otherCount} update${otherCount > 1 ? 's' : ''}`);

  return {
    id: `digest_${Date.now()}`,
    type: 'recommendation',
    title: 'MyChannel Digest',
    body: parts.join(', '),
    priority: 5,
    createdAt: new Date(),
  };
}

/**
 * Scores notification relevance for the current user.
 * Higher score = more relevant = should be shown first.
 */
export function scoreNotificationRelevance(
  notification: NotificationCandidate,
  userInterests: string[],
  recentCreators: string[]
): number {
  let score = notification.priority;

  // Type boost
  const typeScores: Record<string, number> = {
    live_now: 3, // time-sensitive
    vs_match: 2.5, // money involved
    comment_reply: 2, // personal
    milestone: 1.5,
    new_video: 1,
    community: 0.5,
    recommendation: 0,
  };
  score += typeScores[notification.type] || 0;

  // Creator relevance (recently watched = more relevant)
  if (notification.creatorId && recentCreators.includes(notification.creatorId)) {
    score += 2;
  }

  // Recency boost (newer = higher priority)
  const ageMinutes = (Date.now() - notification.createdAt.getTime()) / 60_000;
  if (ageMinutes < 5) score += 2;
  else if (ageMinutes < 30) score += 1;
  else if (ageMinutes > 120) score -= 1;

  return Math.max(0, score);
}

// ─── HELPERS ─────────────────────────────────────────────────────────────────

function isQuietHours(hour: number, prefs: NotificationPreferences): boolean {
  if (prefs.quietHoursStart > prefs.quietHoursEnd) {
    // Wraps midnight: e.g. 23-7
    return hour >= prefs.quietHoursStart || hour < prefs.quietHoursEnd;
  }
  return hour >= prefs.quietHoursStart && hour < prefs.quietHoursEnd;
}

function calculateOptimalDelay(hour: number, type: string): number {
  // Time-sensitive notifications: no delay
  if (['live_now', 'vs_match'].includes(type)) return 0;

  // Peak engagement hours (6-9pm): deliver immediately
  if (hour >= 18 && hour <= 21) return 0;

  // Off-peak: delay 5-15 minutes to batch
  if (hour >= 22 || hour < 8) return 15 * 60 * 1000;
  return 5 * 60 * 1000;
}

async function loadNotificationPreferences(): Promise<NotificationPreferences> {
  const uid = auth.currentUser?.uid;
  if (!uid) return DEFAULT_PREFS;

  try {
    const snap = await getDoc(doc(db, 'users', uid, 'settings', 'notifications'));
    if (snap.exists()) return { ...DEFAULT_PREFS, ...snap.data() } as NotificationPreferences;
  } catch {}

  return DEFAULT_PREFS;
}

async function getRecentNotificationCount(minutesAgo: number): Promise<number> {
  const uid = auth.currentUser?.uid;
  if (!uid) return 0;

  try {
    const since = new Date(Date.now() - minutesAgo * 60_000);
    const snap = await getDocs(query(
      collection(db, 'users', uid, 'notification_log'),
      where('deliveredAt', '>=', since),
      limit(50)
    ));
    return snap.size;
  } catch {
    return 0;
  }
}
