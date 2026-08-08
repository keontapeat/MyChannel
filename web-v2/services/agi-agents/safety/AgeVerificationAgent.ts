// Age Verification Agent — Enforces age gates for real-money features and mature content

import { BaseAgent } from '@/lib/vertex-ai/BaseAgent';
import { VertexAIModels } from '@/lib/vertex-ai/config';
import type { AGIAgent } from '@/types';

export class AgeVerificationAgent extends BaseAgent {
  constructor() {
    super(
      'age-verification-agent',
      'Age Verification Guardian',
      'Monitors and enforces age verification for real-money wagers, mature content, and compliance requirements (COPPA, gambling laws)',
      VertexAIModels.DYNAMIC_PRICING,
      { runInterval: 600, requiresNetwork: true, requiresAuth: true }
    );
  }

  protected async execute(): Promise<void> {
    const data = await this.scanCompliance();
    if (data.violations === 0) {
      this.updateMetrics({ impressions: data.checked });
      return;
    }

    const prompt = `
Age verification compliance check results:

Accounts Checked: ${data.checked}
Violations Found: ${data.violations}

Violation Types:
- Unverified accounts attempting wagers: ${data.unverifiedWagers}
- Accounts flagged as potentially underage: ${data.potentiallyUnderage}
- Accounts bypassing age gates: ${data.bypassAttempts}
- KYC-required transactions without verification: ${data.kycMissing}

For each violation type, recommend:
1. Immediate action (block, suspend, warn)
2. Additional verification required
3. Pattern detection (organized circumvention?)
4. Regulatory risk level

JSON: { "actions": [{ "type": string, "count": number, "action": string, "riskLevel": string }], "systemicRisk": boolean, "regulatoryFlags": [...], "enhancedVerificationNeeded": number }
`;
    const result = await this.generateContent(prompt);
    try {
      const jsonMatch = result.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const { getFirestore, collection, addDoc, serverTimestamp } = await import('firebase/firestore');
        await addDoc(collection(getFirestore(), 'agi_recommendations'), {
          agentId: this.id, type: 'age_compliance',
          recommendation: JSON.parse(jsonMatch[0]),
          status: 'urgent_review', createdAt: serverTimestamp(),
        });
      }
    } catch {}
    this.updateMetrics({ impressions: data.checked });
  }

  private async scanCompliance() {
    try {
      const { getFirestore, doc, getDoc } = await import('firebase/firestore');
      const d = (await getDoc(doc(getFirestore(), 'platform', 'age_compliance'))).data() || {};
      return {
        checked: d.checked || 0, violations: d.violations || 0,
        unverifiedWagers: d.unverifiedWagers || 0, potentiallyUnderage: d.potentiallyUnderage || 0,
        bypassAttempts: d.bypassAttempts || 0, kycMissing: d.kycMissing || 0,
      };
    } catch {
      return { checked: 0, violations: 0, unverifiedWagers: 0, potentiallyUnderage: 0, bypassAttempts: 0, kycMissing: 0 };
    }
  }

  protected getCategory(): AGIAgent['category'] { return 'safety'; }
  protected getPriority(): AGIAgent['priority'] { return 'high'; }
}

export const ageVerificationAgent = new AgeVerificationAgent();
