// Anti-Cheat Agent — Detects manipulation in VS Matches (view bots, vote rigging, collusion)

import { BaseAgent } from '@/lib/vertex-ai/BaseAgent';
import { VertexAIModels } from '@/lib/vertex-ai/config';
import type { AGIAgent } from '@/types';

export class AntiCheatAgent extends BaseAgent {
  constructor() {
    super(
      'anti-cheat-agent',
      'Anti-Cheat Guardian',
      'Detects and prevents cheating in VS Matches including view bots, vote manipulation, collusion rings, and wager laundering',
      VertexAIModels.DYNAMIC_PRICING,
      { runInterval: 300, requiresNetwork: true, requiresAuth: true }
    );
  }

  protected async execute(): Promise<void> {
    const signals = await this.detectAnomalies();
    if (signals.suspiciousMatches === 0 && signals.anomalies.length === 0) {
      this.updateMetrics({ impressions: signals.totalActive });
      return;
    }

    const prompt = `
Analyze VS Match integrity signals and determine if cheating is occurring:

Active Matches: ${signals.totalActive}
Suspicious Signals Detected: ${signals.suspiciousMatches}

Anomalies:
${signals.anomalies.map((a) => `- ${a.type}: ${a.description} (confidence: ${a.confidence})`).join('\n')}

Patterns to check:
1. View count spikes from single IP ranges (bot farms)
2. Coordinated voting from new accounts (vote manipulation)
3. Same users repeatedly matching each other (collusion)
4. Wager amounts that follow suspicious patterns (laundering)
5. Account creation clusters before high-value matches (multi-accounting)

For each suspicious match/pattern:
- Confidence (0-1) that cheating is occurring
- Type of manipulation detected
- Recommended action (monitor, warn, pause, void, ban)
- Evidence summary

JSON: { "verdicts": [{ "matchId": string, "cheatType": string, "confidence": number, "action": string, "evidence": string }], "systemicPatterns": [...], "urgentActions": number }
`;
    const result = await this.generateContent(prompt);
    try {
      const jsonMatch = result.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const { getFirestore, collection, addDoc, serverTimestamp } = await import('firebase/firestore');
        await addDoc(collection(getFirestore(), 'agi_recommendations'), {
          agentId: this.id, type: 'anti_cheat',
          recommendation: JSON.parse(jsonMatch[0]),
          status: 'urgent_review', createdAt: serverTimestamp(),
        });
      }
    } catch {}
    this.updateMetrics({ impressions: signals.totalActive });
  }

  private async detectAnomalies() {
    try {
      const { getFirestore, collection, query, where, getDocs, limit } = await import('firebase/firestore');
      const db = getFirestore();
      const activeSnap = await getDocs(query(collection(db, 'versus_matches'), where('status', 'in', ['open', 'active', 'voting']), limit(200)));
      const anomalies: Array<{ type: string; description: string; confidence: number }> = [];

      // Check for rapid view count spikes
      const votingMatches = activeSnap.docs.filter((d) => d.data().status === 'voting');
      for (const match of votingMatches.slice(0, 10)) {
        const data = match.data();
        const totalVotes = (data.challengerVotes || 0) + (data.opponentVotes || 0);
        const matchAge = Date.now() - (data.votingStartedAt?.toDate?.()?.getTime() || Date.now());
        const votesPerMinute = totalVotes / Math.max(1, matchAge / 60000);
        if (votesPerMinute > 50) {
          anomalies.push({ type: 'vote_spike', description: `Match ${match.id}: ${votesPerMinute.toFixed(0)} votes/min (threshold: 50)`, confidence: 0.7 });
        }
      }

      return { totalActive: activeSnap.size, suspiciousMatches: anomalies.length, anomalies };
    } catch {
      return { totalActive: 0, suspiciousMatches: 0, anomalies: [] };
    }
  }

  protected getCategory(): AGIAgent['category'] { return 'gaming'; }
  protected getPriority(): AGIAgent['priority'] { return 'high'; }
}

export const antiCheatAgent = new AntiCheatAgent();
