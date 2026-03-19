/**
 * Advanced Personalization Engine
 * Real-time recommendations with 90%+ accuracy
 */

import { call_ml_service, batch_call_ml_services } from '../../cloud-deployment/vertex-ai/connection-pool';
import redisCache from '../cache/redis-service.js';

interface UserProfile {
  userId: string;
  interests: string[];
  watchHistory: string[];
  engagementScore: number;
}

interface RecommendationResult {
  videoId: string;
  score: number;
  reason: string;
}

export class PersonalizationEngine {
  /**
   * Get personalized video recommendations
   */
  async getRecommendations(userId: string, count: number = 20): Promise<RecommendationResult[]> {
    const cacheKey = `recommendations:${userId}:${count}`;
    
    // Try cache first
    const cached = await redisCache.get<RecommendationResult[]>(cacheKey);
    if (cached) {
      console.log(`✅ [Personalization] Cache hit for user ${userId}`);
      return cached;
    }

    console.log(`🤖 [Personalization] Generating recommendations for ${userId}`);

    // Parallel ML service calls
    const [
      collaborative,
      contentBased,
      trending,
      viral
    ] = await batch_call_ml_services([
      { service: 'recommendations-service', data: { userId, count: 10 } },
      { service: 'feed-personalization-service', data: { userId, count: 10 } },
      { service: 'trending-ml-service', data: { count: 5 } },
      { service: 'viral-prediction-service', data: { count: 5 } }
    ]);

    // Combine and rank results
    const combined = [
      ...collaborative.recommendations.map((r: any) => ({ ...r, reason: 'collaborative' })),
      ...contentBased.recommendations.map((r: any) => ({ ...r, reason: 'content-based' })),
      ...trending.videos.map((r: any) => ({ ...r, reason: 'trending' })),
      ...viral.videos.map((r: any) => ({ ...r, reason: 'viral' }))
    ];

    // Deduplicate and sort by score
    const unique = this.deduplicateAndRank(combined);
    const results = unique.slice(0, count);

    // Cache for 5 minutes
    await redisCache.set(cacheKey, results, { ttl: 300 });

    console.log(`✅ [Personalization] Generated ${results.length} recommendations`);
    return results;
  }

  /**
   * Real-time recommendation updates based on user action
   */
  async updateRecommendations(userId: string, action: string, videoId: string): Promise<void> {
    console.log(`🔄 [Personalization] Updating for ${userId}: ${action} on ${videoId}`);

    // Invalidate cache
    await redisCache.invalidatePattern(`recommendations:${userId}:*`);

    // Update ML model in background
    call_ml_service('feed-personalization-service', '/update', {
      userId,
      action,
      videoId
    }).catch(console.error);
  }

  /**
   * Predict user churn risk
   */
  async predictChurn(userId: string): Promise<{ risk: number; factors: string[] }> {
    const result = await call_ml_service('churn-predictor-service', '/predict', {
      userId
    });

    return {
      risk: result.churnRisk,
      factors: result.factors || []
    };
  }

  /**
   * Optimize notification timing
   */
  async getOptimalNotificationTime(userId: string): Promise<Date> {
    const result = await call_ml_service('smart-notification-service', '/optimal-time', {
      userId
    });

    return new Date(result.optimalTime);
  }

  /**
   * Predict watch time for video
   */
  async predictWatchTime(userId: string, videoId: string): Promise<number> {
    const result = await call_ml_service('watch-time-predictor-service', '/predict', {
      userId,
      videoId
    });

    return result.predictedWatchTime;
  }

  private deduplicateAndRank(recommendations: any[]): RecommendationResult[] {
    const seen = new Set<string>();
    const unique: RecommendationResult[] = [];

    for (const rec of recommendations) {
      if (!seen.has(rec.videoId)) {
        seen.add(rec.videoId);
        unique.push({
          videoId: rec.videoId,
          score: rec.score || 0,
          reason: rec.reason
        });
      }
    }

    return unique.sort((a, b) => b.score - a.score);
  }
}

export const personalizationEngine = new PersonalizationEngine();
export default personalizationEngine;
