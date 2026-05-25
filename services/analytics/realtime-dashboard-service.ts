/**
 * Real-time Creator Analytics Dashboard
 * Live metrics with <1 second latency
 */

import { Firestore, FieldValue } from '@google-cloud/firestore';

interface AnalyticsMetrics {
  views: number;
  watchTime: number;
  engagement: number;
  revenue: number;
  subscribers: number;
  likes: number;
  comments: number;
  shares: number;
}

interface RealtimeUpdate {
  metric: string;
  value: number;
  timestamp: Date;
}

interface RealtimeWindowSummary {
  minutes: number;
  totals: Record<string, number>;
  eventCount: number;
  lastEventAt: Date | null;
}

export class RealtimeDashboardService {
  private firestore = new Firestore();
  private listeners: Map<string, Function> = new Map();

  private normalizeMetrics(data: Partial<AnalyticsMetrics> | undefined): AnalyticsMetrics {
    return {
      views: Number(data?.views || 0),
      watchTime: Number(data?.watchTime || 0),
      engagement: Number(data?.engagement || 0),
      revenue: Number(data?.revenue || 0),
      subscribers: Number(data?.subscribers || 0),
      likes: Number(data?.likes || 0),
      comments: Number(data?.comments || 0),
      shares: Number(data?.shares || 0),
    };
  }

  /**
   * Subscribe to real-time analytics updates
   */
  subscribeToMetrics(creatorId: string, callback: (metrics: AnalyticsMetrics) => void): () => void {
    console.log(`📊 [Analytics] Subscribing to real-time metrics for ${creatorId}`);

    const unsubscribe = this.firestore
      .collection('analytics')
      .doc(creatorId)
      .onSnapshot(snapshot => {
        if (!snapshot.exists) return;

        const data = this.normalizeMetrics(snapshot.data() as AnalyticsMetrics);
        callback(data);
      });

    this.listeners.set(creatorId, unsubscribe);

    return () => {
      unsubscribe();
      this.listeners.delete(creatorId);
    };
  }

  /**
   * Get current metrics snapshot
   */
  async getCurrentMetrics(creatorId: string): Promise<AnalyticsMetrics> {
    const doc = await this.firestore
      .collection('analytics')
      .doc(creatorId)
      .get();

    if (!doc.exists) {
      return this.getEmptyMetrics();
    }

    return this.normalizeMetrics(doc.data() as AnalyticsMetrics);
  }

  /**
   * Track real-time event
   */
  async trackEvent(creatorId: string, event: RealtimeUpdate): Promise<void> {
    const batch = this.firestore.batch();

    // Update main analytics doc
    const analyticsRef = this.firestore.collection('analytics').doc(creatorId);
    batch.update(analyticsRef, {
      [event.metric]: FieldValue.increment(event.value),
      lastUpdated: event.timestamp,
    });

    // Add to events stream
    const eventRef = this.firestore
      .collection('analytics')
      .doc(creatorId)
      .collection('events')
      .doc();
    
    batch.set(eventRef, event);

    await batch.commit();
    console.log(`✅ [Analytics] Event tracked: ${event.metric} +${event.value}`);
  }

  async getEventWindowSummary(creatorId: string, minutes: number = 60): Promise<RealtimeWindowSummary> {
    const since = new Date(Date.now() - minutes * 60 * 1000);
    const snapshot = await this.firestore
      .collection('analytics')
      .doc(creatorId)
      .collection('events')
      .where('timestamp', '>=', since)
      .orderBy('timestamp', 'desc')
      .limit(500)
      .get();

    const totals: Record<string, number> = {};
    let lastEventAt: Date | null = null;

    snapshot.docs.forEach(doc => {
      const data = doc.data() as RealtimeUpdate;
      totals[data.metric] = (totals[data.metric] || 0) + Number(data.value || 0);
      if (!lastEventAt) {
        lastEventAt = data.timestamp instanceof Date ? data.timestamp : new Date(data.timestamp as any);
      }
    });

    return {
      minutes,
      totals,
      eventCount: snapshot.size,
      lastEventAt,
    };
  }

  async getMetricDelta(creatorId: string, metric: keyof AnalyticsMetrics, minutes: number = 60): Promise<number> {
    const summary = await this.getEventWindowSummary(creatorId, minutes);
    return Number(summary.totals[String(metric)] || 0);
  }

  async getDashboardSnapshot(creatorId: string): Promise<any> {
    const [current, lastHour, lastDay, trendingVideos, revenueBreakdown, demographics] = await Promise.all([
      this.getCurrentMetrics(creatorId),
      this.getEventWindowSummary(creatorId, 60),
      this.getEventWindowSummary(creatorId, 24 * 60),
      this.getTrendingVideos(creatorId, 5),
      this.getRevenueBreakdown(creatorId, 'day'),
      this.getAudienceDemographics(creatorId),
    ]);

    return {
      current,
      deltas: {
        lastHour: lastHour.totals,
        last24Hours: lastDay.totals,
      },
      activity: {
        lastHourEventCount: lastHour.eventCount,
        last24HoursEventCount: lastDay.eventCount,
        lastEventAt: lastHour.lastEventAt || lastDay.lastEventAt,
      },
      trendingVideos,
      revenueBreakdown,
      demographics,
    };
  }

  /**
   * Get trending videos for creator
   */
  async getTrendingVideos(creatorId: string, limit: number = 10): Promise<any[]> {
    const snapshot = await this.firestore
      .collection('videos')
      .where('creatorId', '==', creatorId)
      .orderBy('trending_score', 'desc')
      .limit(limit)
      .get();

    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));
  }

  /**
   * Get revenue breakdown
   */
  async getRevenueBreakdown(creatorId: string, period: 'day' | 'week' | 'month'): Promise<any> {
    const now = new Date();
    const startDate = this.getStartDate(now, period);

    const snapshot = await this.firestore
      .collection('revenue')
      .where('creatorId', '==', creatorId)
      .where('timestamp', '>=', startDate)
      .get();

    const breakdown = {
      ads: 0,
      subscriptions: 0,
      tips: 0,
      superThanks: 0,
      total: 0,
    };

    snapshot.docs.forEach(doc => {
      const data = doc.data();
      breakdown.ads += data.ads || 0;
      breakdown.subscriptions += data.subscriptions || 0;
      breakdown.tips += data.tips || 0;
      breakdown.superThanks += data.superThanks || 0;
    });

    breakdown.total = breakdown.ads + breakdown.subscriptions + breakdown.tips + breakdown.superThanks;

    return breakdown;
  }

  /**
   * Get audience demographics
   */
  async getAudienceDemographics(creatorId: string): Promise<any> {
    const doc = await this.firestore
      .collection('analytics')
      .doc(creatorId)
      .collection('demographics')
      .doc('current')
      .get();

    if (!doc.exists) {
      return {
        ageGroups: {},
        genders: {},
        locations: {},
        devices: {},
      };
    }

    return doc.data();
  }

  private getEmptyMetrics(): AnalyticsMetrics {
    return {
      views: 0,
      watchTime: 0,
      engagement: 0,
      revenue: 0,
      subscribers: 0,
      likes: 0,
      comments: 0,
      shares: 0,
    };
  }

  private getStartDate(now: Date, period: 'day' | 'week' | 'month'): Date {
    const date = new Date(now);
    
    switch (period) {
      case 'day':
        date.setHours(0, 0, 0, 0);
        break;
      case 'week':
        date.setDate(date.getDate() - 7);
        break;
      case 'month':
        date.setMonth(date.getMonth() - 1);
        break;
    }

    return date;
  }

  /**
   * Cleanup all listeners
   */
  cleanup(): void {
    this.listeners.forEach(unsubscribe => unsubscribe());
    this.listeners.clear();
  }
}

export const dashboardService = new RealtimeDashboardService();
export default dashboardService;
