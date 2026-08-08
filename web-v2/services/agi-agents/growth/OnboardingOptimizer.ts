// Onboarding Optimizer Agent — Maximizes new user activation and first-session engagement

import { BaseAgent } from '@/lib/vertex-ai/BaseAgent';
import { VertexAIModels } from '@/lib/vertex-ai/config';
import type { AGIAgent } from '@/types';

export class OnboardingOptimizerAgent extends BaseAgent {
  constructor() {
    super(
      'onboarding-optimizer-agent',
      'Onboarding Optimizer',
      'Maximizes new user activation by optimizing signup flow, first-session content, and interest selection to reduce day-1 churn',
      VertexAIModels.DYNAMIC_PRICING,
      { runInterval: 7200, requiresNetwork: true, requiresAuth: true }
    );
  }

  protected async execute(): Promise<void> {
    const data = await this.gatherOnboardingData();
    const prompt = `
Optimize new user onboarding:

Funnel Metrics (last 7 days):
- Signups: ${data.signups}
- Completed onboarding: ${data.completedOnboarding} (${Math.round(data.completedOnboarding / Math.max(1, data.signups) * 100)}%)
- Watched first video: ${data.watchedFirst} (${Math.round(data.watchedFirst / Math.max(1, data.signups) * 100)}%)
- Returned day 2: ${data.returnedDay2} (${Math.round(data.returnedDay2 / Math.max(1, data.signups) * 100)}%)
- Still active day 7: ${data.activeDay7} (${Math.round(data.activeDay7 / Math.max(1, data.signups) * 100)}%)
- Average interests selected: ${data.avgInterests}
- Most popular first-watch category: ${data.topFirstCategory}
- Avg time to first action: ${data.avgTimeToFirstAction}s

Drop-off Points:
- At signup form: ${data.dropSignup}%
- At interest selection: ${data.dropInterests}%
- Before first video: ${data.dropBeforeVideo}%

Recommend improvements to:
1. Signup flow (reduce friction)
2. Interest selection (categories, UI, defaults)
3. First content served (what to show immediately)
4. Activation triggers (what makes users "stick")
5. Day-1 push notification content

JSON: { "signupChanges": [...], "interestFlow": {...}, "firstContent": {...}, "activationTriggers": [...], "pushContent": [...], "projectedActivationLift": number }
`;
    const result = await this.generateContent(prompt);
    try {
      const jsonMatch = result.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const { getFirestore, collection, addDoc, serverTimestamp } = await import('firebase/firestore');
        await addDoc(collection(getFirestore(), 'agi_recommendations'), {
          agentId: this.id, type: 'onboarding_optimization',
          recommendation: JSON.parse(jsonMatch[0]),
          status: 'pending_review', createdAt: serverTimestamp(),
        });
      }
    } catch {}
    this.updateMetrics({ impressions: data.signups });
  }

  private async gatherOnboardingData() {
    try {
      const { getFirestore, doc, getDoc } = await import('firebase/firestore');
      const d = (await getDoc(doc(getFirestore(), 'platform', 'onboarding_stats'))).data() || {};
      return {
        signups: d.signups || 0, completedOnboarding: d.completedOnboarding || 0,
        watchedFirst: d.watchedFirst || 0, returnedDay2: d.returnedDay2 || 0,
        activeDay7: d.activeDay7 || 0, avgInterests: d.avgInterests || 3.2,
        topFirstCategory: d.topFirstCategory || 'gaming',
        avgTimeToFirstAction: d.avgTimeToFirstAction || 45,
        dropSignup: d.dropSignup || 22, dropInterests: d.dropInterests || 15, dropBeforeVideo: d.dropBeforeVideo || 28,
      };
    } catch {
      return { signups: 0, completedOnboarding: 0, watchedFirst: 0, returnedDay2: 0, activeDay7: 0, avgInterests: 3.2, topFirstCategory: 'gaming', avgTimeToFirstAction: 45, dropSignup: 22, dropInterests: 15, dropBeforeVideo: 28 };
    }
  }

  protected getCategory(): AGIAgent['category'] { return 'growth'; }
  protected getPriority(): AGIAgent['priority'] { return 'medium'; }
}

export const onboardingOptimizerAgent = new OnboardingOptimizerAgent();
