/**
 * Real-time Creator Analytics Dashboard
 * Live metrics with <1 second latency
 */

import { Firestore } from '@google-cloud/firestore';

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

export class RealtimeDashboardService {
  private firestore = new Firestore();
  private listeners: Map<string, Function> = new Map();

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

        const data = snapshot.data() as AnalyticsMetrics;
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

    return doc.data() as AnalyticsMetrics;
  }

  /**
   * Track real-time event
   */
  async trackEvent(creatorId: string, event: RealtimeUpdate): Promise<void> {
    const batch = this.firestore.batch();

    // Update main analytics doc
    const analyticsRef = this.firestore.collection('analytics').doc(creatorId);
    batch.update(analyticsRef, {
      [event.metric]: Firestore.FieldValue.increment(event.value),
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
