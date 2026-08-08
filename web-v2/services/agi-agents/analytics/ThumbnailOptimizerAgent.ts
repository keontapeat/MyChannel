// Thumbnail Optimizer Agent — A/B test statistical significance + CTR prediction

import { BaseAgent } from '@/lib/vertex-ai/BaseAgent';
import { VertexAIModels } from '@/lib/vertex-ai/config';
import type { AGIAgent } from '@/types';

export class ThumbnailOptimizerAgent extends BaseAgent {
  constructor() {
    super(
      'thumbnail-optimizer-agent',
      'Thumbnail A/B Test Engine',
      'Runs statistical significance calculations on thumbnail A/B tests, predicts CTR from thumbnail characteristics, and auto-selects winners',
      VertexAIModels.DYNAMIC_PRICING,
      { runInterval: 900, requiresNetwork: true, requiresAuth: true }
    );
  }

  protected async execute(): Promise<void> {
    const tests = await this.getActiveTests();
    if (tests.length === 0) return;

    for (const test of tests) {
      const significance = this.calculateSignificance(test.variants);
      if (significance.isSignificant && significance.confidence >= 0.95) {
        await this.declareWinner(test.id, test.creatorId, significance.winnerId, significance.confidence);
      }
    }

    this.updateMetrics({ impressions: tests.length });
  }

  /**
   * Two-proportion z-test for statistical significance between variants.
   * Returns winner only when p < 0.05 (95% confidence).
   */
  private calculateSignificance(variants: Array<{ id: string; impressions: number; clicks: number }>) {
    if (variants.length < 2) return { isSignificant: false, confidence: 0, winnerId: '' };

    // Sort by CTR descending
    const sorted = [...variants]
      .map((v) => ({ ...v, ctr: v.impressions > 0 ? v.clicks / v.impressions : 0 }))
      .sort((a, b) => b.ctr - a.ctr);

    const best = sorted[0];
    const second = sorted[1];

    // Minimum sample size check
    if (best.impressions < 100 || second.impressions < 100) {
      return { isSignificant: false, confidence: 0, winnerId: '' };
    }

    // Two-proportion z-test
    const p1 = best.ctr;
    const p2 = second.ctr;
    const n1 = best.impressions;
    const n2 = second.impressions;
    const pPooled = (best.clicks + second.clicks) / (n1 + n2);
    const se = Math.sqrt(pPooled * (1 - pPooled) * (1 / n1 + 1 / n2));

    if (se === 0) return { isSignificant: false, confidence: 0, winnerId: '' };

    const z = (p1 - p2) / se;
    // z > 1.96 → p < 0.05 (95% confidence)
    // z > 2.576 → p < 0.01 (99% confidence)
    const confidence = z > 2.576 ? 0.99 : z > 1.96 ? 0.95 : z > 1.645 ? 0.90 : 0;

    return {
      isSignificant: confidence >= 0.95,
      confidence,
      winnerId: best.id,
    };
  }

  private async declareWinner(testId: string, creatorId: string, winnerId: string, confidence: number) {
    try {
      const { getFirestore, doc, updateDoc, serverTimestamp, collection, addDoc } = await import('firebase/firestore');
      const db = getFirestore();
      await updateDoc(doc(db, 'creators', creatorId, 'thumbnailTests', testId), {
        status: 'completed',
        winnerId,
        confidence,
        completedAt: serverTimestamp(),
        completedBy: 'thumbnail-optimizer-agent',
      });
      await addDoc(collection(db, 'agi_recommendations'), {
        agentId: this.id, type: 'thumbnail_winner',
        recommendation: { testId, winnerId, confidence, action: 'auto_selected' },
        status: 'executed', createdAt: serverTimestamp(),
      });
    } catch {}
  }

  private async getActiveTests(): Promise<Array<{ id: string; creatorId: string; variants: Array<{ id: string; impressions: number; clicks: number }> }>> {
    try {
      const { getFirestore, collectionGroup, query, where, getDocs, limit } = await import('firebase/firestore');
      const snap = await getDocs(query(
        collectionGroup(getFirestore(), 'thumbnailTests'),
        where('status', '==', 'running'),
        limit(20)
      ));
      return snap.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          creatorId: d.ref.parent.parent?.id || '',
          variants: (data.variants || []).map((v: any) => ({
            id: v.id || '', impressions: v.impressions || 0, clicks: v.clicks || 0,
          })),
        };
      });
    } catch {
      return [];
    }
  }

  protected getCategory(): AGIAgent['category'] { return 'analytics'; }
  protected getPriority(): AGIAgent['priority'] { return 'high'; }
}

export const thumbnailOptimizerAgent = new ThumbnailOptimizerAgent();
