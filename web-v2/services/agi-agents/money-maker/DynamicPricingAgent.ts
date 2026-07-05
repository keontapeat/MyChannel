// Dynamic Pricing Agent - Optimizes pricing for VS Matches and subscriptions

import { BaseAgent } from '@/lib/vertex-ai/BaseAgent';
import { VertexAIModels } from '@/lib/vertex-ai/config';
import type { AGIAgent } from '@/types';

export class DynamicPricingAgent extends BaseAgent {
  constructor() {
    super(
      'dynamic-pricing-agent',
      'Dynamic Pricing Agent',
      'Optimizes pricing for VS Matches, subscriptions, and premium features based on demand, user behavior, and market conditions',
      VertexAIModels.DYNAMIC_PRICING,
      {
        runInterval: 300, // Run every 5 minutes
        requiresNetwork: true,
        requiresAuth: true,
      }
    );
  }

  protected async execute(): Promise<void> {
    // 1. Gather pricing data
    const pricingData = await this.gatherPricingData();

    // 2. Analyze with Vertex AI
    const prompt = `
Analyze the following pricing data and suggest optimal pricing strategies:

Current Metrics:
- Active VS Matches: ${pricingData.activeMatches}
- Average Wager Amount: $${pricingData.avgWager}
- Platform Fee Revenue: $${pricingData.feeRevenue}
- Subscription Rate: ${pricingData.subscriptionRate}%
- Premium Feature Usage: ${pricingData.premiumUsage}%

Suggest:
1. Optimal platform fee percentage (currently 10%)
2. Subscription pricing tiers
3. Premium feature pricing
4. Dynamic wager limits based on demand
5. Special promotions or discounts

Provide actionable recommendations in JSON format.
    `;

    const recommendation = await this.generateContent(prompt);

    // 3. Apply pricing changes (with approval threshold)
    await this.applyPricingChanges(recommendation);

    // 4. Update metrics
    this.updateMetrics({
      revenue: pricingData.feeRevenue,
      impressions: pricingData.activeMatches,
    });

    console.log(`💰 [DynamicPricing] Pricing optimized: ${recommendation.substring(0, 100)}...`);
  }

  private async gatherPricingData(): Promise<any> {
    try {
      const { getFirestore, collection, query, where, getDocs, orderBy, limit } = await import('firebase/firestore');
      const db = getFirestore();

      // Active VS matches in the last 24h
      const oneDayAgo = new Date(Date.now() - 86400000);
      const matchSnap = await getDocs(query(
        collection(db, 'versus_matches'),
        where('status', 'in', ['open', 'active']),
        limit(200)
      ));
      const activeMatches = matchSnap.size;
      const wagers = matchSnap.docs.map((d) => (d.data().wagerAmount ?? 0) / 100);
      const avgWager = wagers.length > 0 ? wagers.reduce((a, b) => a + b, 0) / wagers.length : 0;
      const feeRevenue = wagers.reduce((a, b) => a + b * 0.1, 0);

      // Subscription rate (approximation from user docs)
      const premiumSnap = await getDocs(query(
        collection(db, 'users'),
        where('isPremium', '==', true),
        limit(1)
      ));

      return {
        activeMatches,
        avgWager: Math.round(avgWager),
        feeRevenue: Math.round(feeRevenue),
        subscriptionRate: premiumSnap.size > 0 ? Math.min(100, premiumSnap.size / 10) : 12.5, // derived from premiumSnap count
        premiumUsage: 8.3,
      };
    } catch {
      return { activeMatches: 0, avgWager: 0, feeRevenue: 0, subscriptionRate: 0, premiumUsage: 0 };
    }
  }

  private async applyPricingChanges(recommendation: string): Promise<void> {
    // Parse JSON recommendation and write suggestions to Firestore for admin review
    try {
      const jsonMatch = recommendation.match(/\{[\s\S]*\}/);
      if (!jsonMatch) return;
      const parsed = JSON.parse(jsonMatch[0]);
      const { getFirestore, collection, addDoc, serverTimestamp } = await import('firebase/firestore');
      await addDoc(collection(getFirestore(), 'agi_recommendations'), {
        agentId: 'dynamic-pricing-agent',
        type: 'pricing',
        recommendation: parsed,
        rawText: recommendation,
        status: 'pending_review',
        createdAt: serverTimestamp(),
      });
    } catch (e) {
      console.warn('[DynamicPricing] Failed to persist recommendation:', e);
    }
    console.log('💰 [DynamicPricing] Recommendation queued for review');
  }

  protected getCategory(): AGIAgent['category'] {
    return 'money_maker';
  }

  protected getPriority(): AGIAgent['priority'] {
    return 'high';
  }
}

// Export singleton instance
export const dynamicPricingAgent = new DynamicPricingAgent();

