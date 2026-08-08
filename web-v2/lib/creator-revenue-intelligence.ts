/**
 * Creator Revenue Intelligence
 *
 * Real-time revenue optimization for creators. Tracks multiple income streams,
 * identifies growth opportunities, and provides actionable predictions.
 * This goes beyond YouTube's basic analytics — it's a revenue copilot.
 */

import { db, auth } from '@/lib/firebase/config';
import { doc, getDoc, collection, query, where, orderBy, limit, getDocs } from 'firebase/firestore';

// ─── TYPES ───────────────────────────────────────────────────────────────────

export interface RevenueStream {
  name: string;
  currentMonthCents: number;
  lastMonthCents: number;
  growth: number; // percentage
  trend: 'up' | 'down' | 'flat';
  projectedNextMonthCents: number;
}

export interface RevenueIntelligence {
  streams: RevenueStream[];
  totalMonthCents: number;
  projectedMonthCents: number;
  topOpportunity: string;
  rpmScore: number; // revenue per mille views
  monetizationHealth: 'excellent' | 'good' | 'needs_attention' | 'critical';
  insights: RevenueInsight[];
}

export interface RevenueInsight {
  type: 'opportunity' | 'warning' | 'achievement' | 'tip';
  title: string;
  description: string;
  impact: 'high' | 'medium' | 'low';
  actionUrl?: string;
}

export interface RPMBreakdown {
  totalRpm: number;
  adRpm: number;
  membershipRpm: number;
  tipsRpm: number;
  matchRpm: number;
  industryAvgRpm: number;
  percentile: number; // 0-100, where creator falls vs others
}

// ─── REVENUE DASHBOARD ──────────────────────────────────────────────────────

/**
 * Fetches comprehensive revenue intelligence for the current creator.
 */
export async function getRevenueIntelligence(): Promise<RevenueIntelligence | null> {
  const uid = auth.currentUser?.uid;
  if (!uid) return null;

  try {
    const [earningsDoc, lastMonthDoc, viewsDoc] = await Promise.all([
      getDoc(doc(db, 'creators', uid, 'monetization', 'current_month')),
      getDoc(doc(db, 'creators', uid, 'monetization', 'last_month')),
      getDoc(doc(db, 'creators', uid, 'monetization', 'stats')),
    ]);

    const current = earningsDoc.data() || {};
    const last = lastMonthDoc.data() || {};
    const stats = viewsDoc.data() || {};

    const streams: RevenueStream[] = [
      buildStream('Ad Revenue', current.adRevenueCents, last.adRevenueCents),
      buildStream('Memberships', current.membershipCents, last.membershipCents),
      buildStream('Super Thanks', current.tipsCents, last.tipsCents),
      buildStream('VS Match Winnings', current.matchWinningsCents, last.matchWinningsCents),
      buildStream('Premium Revenue', current.premiumCents, last.premiumCents),
    ];

    const totalMonthCents = streams.reduce((sum, s) => sum + s.currentMonthCents, 0);
    const projectedMonthCents = streams.reduce((sum, s) => sum + s.projectedNextMonthCents, 0);

    const monthlyViews = stats.monthlyViews || 1;
    const rpmScore = (totalMonthCents / 100) / (monthlyViews / 1000);

    const insights = generateInsights(streams, rpmScore, stats);
    const monetizationHealth = rpmScore > 8 ? 'excellent' : rpmScore > 4 ? 'good' : rpmScore > 1 ? 'needs_attention' : 'critical';

    return {
      streams: streams.filter((s) => s.currentMonthCents > 0 || s.lastMonthCents > 0),
      totalMonthCents,
      projectedMonthCents,
      topOpportunity: insights.find((i) => i.type === 'opportunity')?.title || 'Keep creating',
      rpmScore: Math.round(rpmScore * 100) / 100,
      monetizationHealth,
      insights,
    };
  } catch {
    return null;
  }
}

/**
 * Calculates RPM breakdown compared to industry averages.
 */
export async function getRPMBreakdown(): Promise<RPMBreakdown | null> {
  const uid = auth.currentUser?.uid;
  if (!uid) return null;

  try {
    const [creatorDoc, platformDoc] = await Promise.all([
      getDoc(doc(db, 'creators', uid, 'monetization', 'rpm')),
      getDoc(doc(db, 'platform', 'rpm_benchmarks')),
    ]);

    const creator = creatorDoc.data() || {};
    const platform = platformDoc.data() || {};

    return {
      totalRpm: creator.totalRpm || 0,
      adRpm: creator.adRpm || 0,
      membershipRpm: creator.membershipRpm || 0,
      tipsRpm: creator.tipsRpm || 0,
      matchRpm: creator.matchRpm || 0,
      industryAvgRpm: platform.avgRpm || 5.0,
      percentile: creator.percentile || 50,
    };
  } catch {
    return null;
  }
}

/**
 * Predicts next month's revenue based on growth trends and seasonality.
 */
export function predictNextMonthRevenue(
  streams: RevenueStream[],
  seasonalityFactor: number = 1.0 // 1.0 = normal, 1.3 = holiday season
): number {
  return streams.reduce((total, stream) => {
    // Use exponential smoothing with trend
    const trendFactor = 1 + stream.growth / 100;
    const dampened = 1 + (trendFactor - 1) * 0.7; // dampen extreme swings
    return total + Math.round(stream.currentMonthCents * dampened * seasonalityFactor);
  }, 0);
}

// ─── HELPERS ─────────────────────────────────────────────────────────────────

function buildStream(name: string, currentCents: number = 0, lastCents: number = 0): RevenueStream {
  const growth = lastCents > 0 ? ((currentCents - lastCents) / lastCents) * 100 : 0;
  const trend: 'up' | 'down' | 'flat' = growth > 5 ? 'up' : growth < -5 ? 'down' : 'flat';
  const dayOfMonth = new Date().getDate();
  const daysInMonth = new Date(new Date().getFullYear(), new Date().getMonth() + 1, 0).getDate();
  const projected = dayOfMonth > 5 ? Math.round(currentCents * (daysInMonth / dayOfMonth)) : lastCents;

  return { name, currentMonthCents: currentCents, lastMonthCents: lastCents, growth: Math.round(growth), trend, projectedNextMonthCents: projected };
}

function generateInsights(streams: RevenueStream[], rpm: number, stats: any): RevenueInsight[] {
  const insights: RevenueInsight[] = [];

  // Membership opportunity
  const membershipStream = streams.find((s) => s.name === 'Memberships');
  if (!membershipStream || membershipStream.currentMonthCents === 0) {
    if ((stats.subscriberCount || 0) > 1000) {
      insights.push({
        type: 'opportunity',
        title: 'Enable Memberships',
        description: `With ${stats.subscriberCount?.toLocaleString()} subscribers, memberships could add $${Math.round(stats.subscriberCount * 0.02 * 4.99)} /month.`,
        impact: 'high',
        actionUrl: '/studio/memberships',
      });
    }
  }

  // VS Match opportunity
  const matchStream = streams.find((s) => s.name === 'VS Match Winnings');
  if (!matchStream || matchStream.currentMonthCents === 0) {
    insights.push({
      type: 'opportunity',
      title: 'Try VS Matches',
      description: 'Compete head-to-head with other creators for real money. Top competitors earn $500+/month.',
      impact: 'medium',
      actionUrl: '/vs-matches',
    });
  }

  // RPM below average
  if (rpm < 3) {
    insights.push({
      type: 'warning',
      title: 'RPM Below Average',
      description: `Your RPM ($${rpm.toFixed(2)}) is below the platform average ($5.00). Consider longer videos with mid-roll ads.`,
      impact: 'high',
    });
  }

  // Growth achievement
  const growingStreams = streams.filter((s) => s.growth > 20);
  if (growingStreams.length > 0) {
    insights.push({
      type: 'achievement',
      title: `${growingStreams[0].name} +${growingStreams[0].growth}%`,
      description: `Your ${growingStreams[0].name.toLowerCase()} grew ${growingStreams[0].growth}% this month. Keep it up!`,
      impact: 'low',
    });
  }

  // Upload frequency tip
  if ((stats.uploadsThisMonth || 0) < 4) {
    insights.push({
      type: 'tip',
      title: 'Upload More Consistently',
      description: 'Creators who upload 4+ times per month earn 3x more on average. You have room to grow.',
      impact: 'medium',
    });
  }

  return insights;
}
