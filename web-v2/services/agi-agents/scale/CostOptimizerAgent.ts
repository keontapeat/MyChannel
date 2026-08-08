// Cost Optimizer Agent — Reduces infrastructure costs while maintaining performance

import { BaseAgent } from '@/lib/vertex-ai/BaseAgent';
import { VertexAIModels } from '@/lib/vertex-ai/config';
import type { AGIAgent } from '@/types';

export class CostOptimizerAgent extends BaseAgent {
  constructor() {
    super(
      'cost-optimizer-agent',
      'Infrastructure Cost Optimizer',
      'Analyzes cloud spending patterns, identifies waste, and recommends cost reduction strategies without degrading performance',
      VertexAIModels.DYNAMIC_PRICING,
      { runInterval: 3600, requiresNetwork: true, requiresAuth: true }
    );
  }

  protected async execute(): Promise<void> {
    const costs = await this.gatherCostData();
    const prompt = `
Optimize cloud infrastructure costs:

Monthly Spend Breakdown:
- Firebase (Firestore reads/writes): $${costs.firestoreCost}
- Firebase Storage (bandwidth): $${costs.storageCost}
- Cloud Functions (invocations): $${costs.functionsCost}
- Cloud Run (services): $${costs.cloudRunCost}
- CDN bandwidth: $${costs.cdnCost}
- Vertex AI (inference): $${costs.aiCost}
- Total monthly: $${costs.totalMonthly}

Usage Patterns:
- Peak hours: ${costs.peakHours}
- Off-peak utilization: ${costs.offPeakUtil}%
- Firestore reads/day: ${costs.firestoreReadsDaily}
- Storage egress/day: ${costs.storageEgressGB}GB
- Function invocations/day: ${costs.functionInvocationsDaily}
- CDN cache hit rate: ${costs.cdnHitRate}%

Recommend:
1. Caching strategies to reduce Firestore reads
2. CDN optimization to reduce egress
3. Function cold-start reduction
4. Autoscaling policies for Cloud Run
5. Data lifecycle (archive old videos to cheaper storage)
6. AI inference batching/caching

JSON: { "savings": [{ "area": string, "currentCost": number, "projectedCost": number, "action": string }], "totalSavingsProjected": number, "performanceImpact": string, "priority": string }
`;
    const result = await this.generateContent(prompt);
    try {
      const jsonMatch = result.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const { getFirestore, collection, addDoc, serverTimestamp } = await import('firebase/firestore');
        await addDoc(collection(getFirestore(), 'agi_recommendations'), {
          agentId: this.id, type: 'cost_optimization',
          recommendation: JSON.parse(jsonMatch[0]),
          status: 'pending_review', createdAt: serverTimestamp(),
        });
      }
    } catch {}
    this.updateMetrics({ revenue: -costs.totalMonthly, impressions: 1 });
  }

  private async gatherCostData() {
    try {
      const { getFirestore, doc, getDoc } = await import('firebase/firestore');
      const d = (await getDoc(doc(getFirestore(), 'platform', 'cost_metrics'))).data() || {};
      return {
        firestoreCost: d.firestoreCost || 0, storageCost: d.storageCost || 0,
        functionsCost: d.functionsCost || 0, cloudRunCost: d.cloudRunCost || 0,
        cdnCost: d.cdnCost || 0, aiCost: d.aiCost || 0,
        totalMonthly: d.totalMonthly || 0, peakHours: d.peakHours || '18:00-23:00 UTC',
        offPeakUtil: d.offPeakUtil || 15, firestoreReadsDaily: d.firestoreReadsDaily || 0,
        storageEgressGB: d.storageEgressGB || 0, functionInvocationsDaily: d.functionInvocationsDaily || 0,
        cdnHitRate: d.cdnHitRate || 85,
      };
    } catch {
      return { firestoreCost: 0, storageCost: 0, functionsCost: 0, cloudRunCost: 0, cdnCost: 0, aiCost: 0, totalMonthly: 0, peakHours: '18:00-23:00', offPeakUtil: 15, firestoreReadsDaily: 0, storageEgressGB: 0, functionInvocationsDaily: 0, cdnHitRate: 85 };
    }
  }

  protected getCategory(): AGIAgent['category'] { return 'scale'; }
  protected getPriority(): AGIAgent['priority'] { return 'medium'; }
}

export const costOptimizerAgent = new CostOptimizerAgent();
