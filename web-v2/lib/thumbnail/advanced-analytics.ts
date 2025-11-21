// 🔥 ADVANCED ANALYTICS DASHBOARD - TRACK EVERYTHING 💣

import {
  collection,
  doc,
  setDoc,
  getDoc,
  getDocs,
  query,
  where,
  orderBy,
  limit as firestoreLimit,
  Timestamp,
  serverTimestamp,
} from 'firebase/firestore';
import { db } from '@/lib/firebase/config';

// Types
export interface ThumbnailAnalytics {
  thumbnailId: string;
  projectId: string;
  userId: string;
  videoId?: string;
  impressions: number;
  clicks: number;
  ctr: number; // Click-through rate
  views: number;
  watchTime: number; // seconds
  engagement: number; // likes + comments + shares
  revenue: number; // cents
  predictedCTR: number;
  actualCTR: number;
  ctrAccuracy: number;
  createdAt: Timestamp;
  lastUpdatedAt: Timestamp;
}

export interface ABTestResult {
  testId: string;
  projectId: string;
  userId: string;
  variantA: ThumbnailVariant;
  variantB: ThumbnailVariant;
  winner?: 'A' | 'B' | 'tie';
  confidenceLevel: number; // 0-100
  sampleSize: number;
  duration: number; // hours
  status: 'running' | 'completed' | 'cancelled';
  startedAt: Timestamp;
  completedAt?: Timestamp;
}

export interface ThumbnailVariant {
  id: string;
  name: string;
  thumbnailUrl: string;
  impressions: number;
  clicks: number;
  ctr: number;
  views: number;
  engagement: number;
}

export interface PerformanceMetrics {
  period: 'day' | 'week' | 'month' | 'year' | 'all-time';
  totalThumbnails: number;
  totalImpressions: number;
  totalClicks: number;
  averageCTR: number;
  totalViews: number;
  totalWatchTime: number;
  totalEngagement: number;
  totalRevenue: number;
  topPerformingThumbnails: ThumbnailPerformance[];
  ctrPredictionAccuracy: number;
  improvementOverTime: number; // percentage
}

export interface ThumbnailPerformance {
  thumbnailId: string;
  projectName: string;
  thumbnailUrl: string;
  ctr: number;
  views: number;
  engagement: number;
  revenue: number;
  createdAt: Date;
}

export interface AnalyticsDashboard {
  userId: string;
  overview: PerformanceMetrics;
  recentThumbnails: ThumbnailAnalytics[];
  activeABTests: ABTestResult[];
  insights: AnalyticsInsight[];
  recommendations: string[];
}

export interface AnalyticsInsight {
  type: 'success' | 'warning' | 'info' | 'tip';
  title: string;
  description: string;
  metric?: string;
  value?: number;
  change?: number; // percentage
}

// Track thumbnail impression
export async function trackImpression(
  thumbnailId: string,
  userId: string,
  videoId?: string
): Promise<void> {
  try {
    const analyticsRef = doc(db, 'thumbnail-analytics', thumbnailId);
    const analyticsDoc = await getDoc(analyticsRef);

    if (analyticsDoc.exists()) {
      const data = analyticsDoc.data() as ThumbnailAnalytics;
      await setDoc(analyticsRef, {
        ...data,
        impressions: data.impressions + 1,
        lastUpdatedAt: serverTimestamp(),
      });
    } else {
      const analytics: ThumbnailAnalytics = {
        thumbnailId,
        projectId: '', // Would be set from project
        userId,
        videoId,
        impressions: 1,
        clicks: 0,
        ctr: 0,
        views: 0,
        watchTime: 0,
        engagement: 0,
        revenue: 0,
        predictedCTR: 0,
        actualCTR: 0,
        ctrAccuracy: 0,
        createdAt: serverTimestamp() as Timestamp,
        lastUpdatedAt: serverTimestamp() as Timestamp,
      };
      await setDoc(analyticsRef, analytics);
    }
  } catch (error) {
    console.error('🚨 Failed to track impression:', error);
  }
}

// Track thumbnail click
export async function trackClick(thumbnailId: string): Promise<void> {
  try {
    const analyticsRef = doc(db, 'thumbnail-analytics', thumbnailId);
    const analyticsDoc = await getDoc(analyticsRef);

    if (analyticsDoc.exists()) {
      const data = analyticsDoc.data() as ThumbnailAnalytics;
      const newClicks = data.clicks + 1;
      const newCTR = (newClicks / data.impressions) * 100;

      await setDoc(analyticsRef, {
        ...data,
        clicks: newClicks,
        ctr: newCTR,
        actualCTR: newCTR,
        lastUpdatedAt: serverTimestamp(),
      });
    }
  } catch (error) {
    console.error('🚨 Failed to track click:', error);
  }
}

// Track video view
export async function trackView(
  thumbnailId: string,
  watchTime: number
): Promise<void> {
  try {
    const analyticsRef = doc(db, 'thumbnail-analytics', thumbnailId);
    const analyticsDoc = await getDoc(analyticsRef);

    if (analyticsDoc.exists()) {
      const data = analyticsDoc.data() as ThumbnailAnalytics;
      await setDoc(analyticsRef, {
        ...data,
        views: data.views + 1,
        watchTime: data.watchTime + watchTime,
        lastUpdatedAt: serverTimestamp(),
      });
    }
  } catch (error) {
    console.error('🚨 Failed to track view:', error);
  }
}

// Get analytics dashboard
export async function getAnalyticsDashboard(
  userId: string,
  period: 'day' | 'week' | 'month' | 'year' | 'all-time' = 'month'
): Promise<AnalyticsDashboard> {
  try {
    // Get user's thumbnails
    const analyticsRef = collection(db, 'thumbnail-analytics');
    const q = query(
      analyticsRef,
      where('userId', '==', userId),
      orderBy('lastUpdatedAt', 'desc')
    );
    const snapshot = await getDocs(q);

    const allAnalytics = snapshot.docs.map((doc) => doc.data() as ThumbnailAnalytics);

    // Filter by period
    const filteredAnalytics = filterByPeriod(allAnalytics, period);

    // Calculate overview metrics
    const overview = calculateOverviewMetrics(filteredAnalytics, period);

    // Get recent thumbnails
    const recentThumbnails = allAnalytics.slice(0, 10);

    // Get active A/B tests
    const activeABTests = await getActiveABTests(userId);

    // Generate insights
    const insights = generateInsights(filteredAnalytics, overview);

    // Generate recommendations
    const recommendations = generateRecommendations(filteredAnalytics, overview);

    return {
      userId,
      overview,
      recentThumbnails,
      activeABTests,
      insights,
      recommendations,
    };
  } catch (error) {
    console.error('🚨 Failed to get analytics dashboard:', error);
    throw error;
  }
}

// Filter analytics by period
function filterByPeriod(
  analytics: ThumbnailAnalytics[],
  period: string
): ThumbnailAnalytics[] {
  const now = Date.now();
  let cutoff: number;

  switch (period) {
    case 'day':
      cutoff = now - 24 * 60 * 60 * 1000;
      break;
    case 'week':
      cutoff = now - 7 * 24 * 60 * 60 * 1000;
      break;
    case 'month':
      cutoff = now - 30 * 24 * 60 * 60 * 1000;
      break;
    case 'year':
      cutoff = now - 365 * 24 * 60 * 60 * 1000;
      break;
    default:
      return analytics;
  }

  return analytics.filter((a) => a.createdAt.toMillis() >= cutoff);
}

// Calculate overview metrics
function calculateOverviewMetrics(
  analytics: ThumbnailAnalytics[],
  period: string
): PerformanceMetrics {
  const totalImpressions = analytics.reduce((sum, a) => sum + a.impressions, 0);
  const totalClicks = analytics.reduce((sum, a) => sum + a.clicks, 0);
  const totalViews = analytics.reduce((sum, a) => sum + a.views, 0);
  const totalWatchTime = analytics.reduce((sum, a) => sum + a.watchTime, 0);
  const totalEngagement = analytics.reduce((sum, a) => sum + a.engagement, 0);
  const totalRevenue = analytics.reduce((sum, a) => sum + a.revenue, 0);

  const averageCTR = totalImpressions > 0 ? (totalClicks / totalImpressions) * 100 : 0;

  // Calculate CTR prediction accuracy
  const predictedCTRs = analytics.map((a) => a.predictedCTR);
  const actualCTRs = analytics.map((a) => a.actualCTR);
  const ctrPredictionAccuracy = calculateAccuracy(predictedCTRs, actualCTRs);

  // Top performing thumbnails
  const topPerformingThumbnails = analytics
    .sort((a, b) => b.ctr - a.ctr)
    .slice(0, 10)
    .map((a) => ({
      thumbnailId: a.thumbnailId,
      projectName: '', // Would be fetched from project
      thumbnailUrl: '', // Would be fetched from project
      ctr: a.ctr,
      views: a.views,
      engagement: a.engagement,
      revenue: a.revenue,
      createdAt: a.createdAt.toDate(),
    }));

  return {
    period,
    totalThumbnails: analytics.length,
    totalImpressions,
    totalClicks,
    averageCTR,
    totalViews,
    totalWatchTime,
    totalEngagement,
    totalRevenue,
    topPerformingThumbnails,
    ctrPredictionAccuracy,
    improvementOverTime: 0, // Would calculate from historical data
  };
}

// Calculate accuracy
function calculateAccuracy(predicted: number[], actual: number[]): number {
  if (predicted.length === 0) return 0;

  let totalError = 0;
  for (let i = 0; i < predicted.length; i++) {
    const error = Math.abs(predicted[i] - actual[i]);
    totalError += error;
  }

  const averageError = totalError / predicted.length;
  const accuracy = Math.max(0, 100 - averageError);

  return accuracy;
}

// Generate insights
function generateInsights(
  analytics: ThumbnailAnalytics[],
  overview: PerformanceMetrics
): AnalyticsInsight[] {
  const insights: AnalyticsInsight[] = [];

  // High CTR insight
  if (overview.averageCTR > 10) {
    insights.push({
      type: 'success',
      title: 'Excellent CTR!',
      description: `Your average CTR of ${overview.averageCTR.toFixed(2)}% is above industry average (8-10%).`,
      metric: 'CTR',
      value: overview.averageCTR,
    });
  }

  // Low CTR warning
  if (overview.averageCTR < 5) {
    insights.push({
      type: 'warning',
      title: 'Low CTR',
      description: `Your average CTR of ${overview.averageCTR.toFixed(2)}% is below industry average. Consider A/B testing different designs.`,
      metric: 'CTR',
      value: overview.averageCTR,
    });
  }

  // High accuracy insight
  if (overview.ctrPredictionAccuracy > 85) {
    insights.push({
      type: 'success',
      title: 'Accurate Predictions!',
      description: `Our AI predictions are ${overview.ctrPredictionAccuracy.toFixed(1)}% accurate for your thumbnails.`,
      metric: 'Accuracy',
      value: overview.ctrPredictionAccuracy,
    });
  }

  // Revenue milestone
  if (overview.totalRevenue > 100000) {
    // $1000
    insights.push({
      type: 'success',
      title: 'Revenue Milestone!',
      description: `You've generated $${(overview.totalRevenue / 100).toFixed(2)} from videos using these thumbnails!`,
      metric: 'Revenue',
      value: overview.totalRevenue / 100,
    });
  }

  return insights;
}

// Generate recommendations
function generateRecommendations(
  analytics: ThumbnailAnalytics[],
  overview: PerformanceMetrics
): string[] {
  const recommendations: string[] = [];

  // CTR recommendations
  if (overview.averageCTR < 8) {
    recommendations.push('Try using brighter colors and larger text to improve CTR');
    recommendations.push('Add emotional expressions or action shots to thumbnails');
    recommendations.push('Run A/B tests to find what works best for your audience');
  }

  // Engagement recommendations
  if (overview.totalEngagement < overview.totalViews * 0.05) {
    recommendations.push('Thumbnails with higher contrast tend to get more engagement');
    recommendations.push('Consider adding text overlays that create curiosity');
  }

  // Template recommendations
  if (analytics.length > 10) {
    recommendations.push('You have enough data! Consider creating template presets from your best performers');
  }

  // A/B testing recommendations
  const hasABTests = analytics.some((a) => a.predictedCTR > 0);
  if (!hasABTests) {
    recommendations.push('Start A/B testing to optimize your thumbnail performance');
  }

  return recommendations;
}

// Get active A/B tests
async function getActiveABTests(userId: string): Promise<ABTestResult[]> {
  try {
    const testsRef = collection(db, 'ab-tests');
    const q = query(
      testsRef,
      where('userId', '==', userId),
      where('status', '==', 'running')
    );
    const snapshot = await getDocs(q);

    return snapshot.docs.map((doc) => doc.data() as ABTestResult);
  } catch (error) {
    console.error('🚨 Failed to get active A/B tests:', error);
    return [];
  }
}

// Export analytics report
export async function exportAnalyticsReport(
  userId: string,
  period: string,
  format: 'csv' | 'json' | 'pdf' = 'csv'
): Promise<Blob> {
  const dashboard = await getAnalyticsDashboard(userId, period as any);

  if (format === 'csv') {
    return exportToCSV(dashboard);
  } else if (format === 'json') {
    return exportToJSON(dashboard);
  } else {
    return exportToPDF(dashboard);
  }
}

// Export to CSV
function exportToCSV(dashboard: AnalyticsDashboard): Blob {
  const headers = [
    'Thumbnail ID',
    'Impressions',
    'Clicks',
    'CTR (%)',
    'Views',
    'Watch Time (s)',
    'Engagement',
    'Revenue ($)',
  ];

  const rows = dashboard.recentThumbnails.map((a) => [
    a.thumbnailId,
    a.impressions,
    a.clicks,
    a.ctr.toFixed(2),
    a.views,
    a.watchTime,
    a.engagement,
    (a.revenue / 100).toFixed(2),
  ]);

  const csv = [headers, ...rows].map((row) => row.join(',')).join('\n');

  return new Blob([csv], { type: 'text/csv' });
}

// Export to JSON
function exportToJSON(dashboard: AnalyticsDashboard): Blob {
  const json = JSON.stringify(dashboard, null, 2);
  return new Blob([json], { type: 'application/json' });
}

// Export to PDF (would need PDF library)
function exportToPDF(dashboard: AnalyticsDashboard): Blob {
  // Would use jsPDF or similar
  const text = `Analytics Report\n\nTotal Thumbnails: ${dashboard.overview.totalThumbnails}\nAverage CTR: ${dashboard.overview.averageCTR.toFixed(2)}%`;
  return new Blob([text], { type: 'text/plain' });
}




