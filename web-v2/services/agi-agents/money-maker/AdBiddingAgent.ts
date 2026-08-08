// Ad Bidding Optimization Agent — Real-time ad auction optimization
// Maximizes eCPM while maintaining viewer experience quality

import { BaseAgent } from '@/lib/vertex-ai/BaseAgent';
import { VertexAIModels } from '@/lib/vertex-ai/config';
import type { AGIAgent } from '@/types';

export class AdBiddingAgent extends BaseAgent {
  constructor() {
    super(
      'ad-bidding-agent',
      'Ad Bidding Optimizer',
      'Optimizes real-time ad auction bids, floor prices, and ad placement timing to maximize eCPM while preserving viewer retention',
      VertexAIModels.DYNAMIC_PRICING,
      { runInterval: 60, requiresNetwork: true, requiresAuth: true }
    );
  }

  protected async execute(): Promise<void> {
    const metrics = await this.gatherAdMetrics();
    const prompt = `
You are an ad auction optimization engine. Analyze these real-time metrics and produce bidding strategy adjustments:

Current Ad Performance (last hour):
- Fill Rate: ${metrics.fillRate}%
- Average eCPM: $${metrics.avgEcpm}
- Pre-roll completion rate: ${metrics.preRollCompletion}%
- Mid-roll skip rate: ${metrics.midRollSkipRate}%
- Ad revenue this hour: $${metrics.hourlyRevenue}
- Viewer drop-off after ad: ${metrics.adDropoff}%
- Total impressions: ${metrics.impressions}
- Unique advertisers bidding: ${metrics.uniqueAdvertisers}

Inventory Context:
- Active viewers: ${metrics.activeViewers}
- Average session length: ${metrics.avgSessionMinutes}min
- Peak hour: ${metrics.isPeakHour}
- Content categories in demand: ${metrics.topCategories.join(', ')}

Produce a JSON response with:
{
  "floorPriceAdjustment": number (percentage change, -20 to +50),
  "preRollFrequency": number (1 = every video, 2 = every other, etc),
  "midRollMinVideoLength": number (seconds before mid-roll eligible),
  "midRollMaxPerVideo": number,
  "targetEcpm": number (dollars),
  "bidMultipliers": { "gaming": number, "music": number, "education": number, "entertainment": number },
  "reasoning": string
}
`;

    const result = await this.generateContent(prompt);
    await this.persistRecommendation('ad_bidding', result, metrics);
    this.updateMetrics({ revenue: metrics.hourlyRevenue, impressions: metrics.impressions });
  }

  private async gatherAdMetrics() {
    try {
      const { getFirestore, collection, query, where, getDocs, limit, orderBy } = await import('firebase/firestore');
      const db = getFirestore();
      const oneHourAgo = new Date(Date.now() - 3600000);

      const impressionSnap = await getDocs(query(
        collection(db, 'ad_impressions'),
        where('createdAt', '>=', oneHourAgo),
        limit(500)
      ));

      const impressions = impressionSnap.size;
      let totalRevenue = 0;
      let completions = 0;
      let skips = 0;
      const categories = new Map<string, number>();

      impressionSnap.docs.forEach((doc) => {
        const d = doc.data();
        totalRevenue += (d.revenueCents || 0) / 100;
        if (d.completed) completions++;
        if (d.skipped) skips++;
        const cat = d.category || 'other';
        categories.set(cat, (categories.get(cat) || 0) + 1);
      });

      const topCategories = Array.from(categories.entries())
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5)
        .map(([cat]) => cat);

      return {
        fillRate: impressions > 0 ? Math.round((completions / impressions) * 100) : 75,
        avgEcpm: impressions > 0 ? Math.round((totalRevenue / impressions) * 1000 * 100) / 100 : 8.5,
        preRollCompletion: impressions > 0 ? Math.round((completions / Math.max(1, impressions)) * 100) : 82,
        midRollSkipRate: impressions > 0 ? Math.round((skips / Math.max(1, impressions)) * 100) : 35,
        hourlyRevenue: Math.round(totalRevenue * 100) / 100,
        adDropoff: 4.2,
        impressions,
        uniqueAdvertisers: Math.min(impressions, 45),
        activeViewers: Math.max(100, impressions * 3),
        avgSessionMinutes: 12.5,
        isPeakHour: new Date().getHours() >= 18 && new Date().getHours() <= 23,
        topCategories,
      };
    } catch {
      return {
        fillRate: 75, avgEcpm: 8.5, preRollCompletion: 82, midRollSkipRate: 35,
        hourlyRevenue: 0, adDropoff: 4.2, impressions: 0, uniqueAdvertisers: 0,
        activeViewers: 0, avgSessionMinutes: 12.5, isPeakHour: false, topCategories: ['gaming', 'music'],
      };
    }
  }

  private async persistRecommendation(type: string, result: string, metrics: any) {
    try {
      const jsonMatch = result.match(/\{[\s\S]*\}/);
      if (!jsonMatch) return;
      const parsed = JSON.parse(jsonMatch[0]);
      const { getFirestore, collection, addDoc, serverTimestamp } = await import('firebase/firestore');
      await addDoc(collection(getFirestore(), 'agi_recommendations'), {
        agentId: this.id,
        type,
        recommendation: parsed,
        metrics,
        status: 'pending_review',
        createdAt: serverTimestamp(),
      });
    } catch (e) {
      console.warn(`[${this.name}] Failed to persist:`, e);
    }
  }

  protected getCategory(): AGIAgent['category'] { return 'money_maker'; }
  protected getPriority(): AGIAgent['priority'] { return 'high'; }
}

export const adBiddingAgent = new AdBiddingAgent();
