// Toxicity Filter Agent — Real-time comment/chat toxicity scoring and auto-moderation

import { BaseAgent } from '@/lib/vertex-ai/BaseAgent';
import { VertexAIModels } from '@/lib/vertex-ai/config';
import type { AGIAgent } from '@/types';

export class ToxicityFilterAgent extends BaseAgent {
  constructor() {
    super(
      'toxicity-filter-agent',
      'Toxicity Filter',
      'Real-time toxicity scoring for comments and live chat. Auto-removes harmful content, shadows toxic users, and protects creators',
      VertexAIModels.DYNAMIC_PRICING,
      { runInterval: 30, requiresNetwork: true, requiresAuth: true }
    );
  }

  protected async execute(): Promise<void> {
    const batch = await this.getUnmoderatedContent();
    if (batch.length === 0) return;

    const prompt = `
Score each piece of content for toxicity (0.0 = safe, 1.0 = severely toxic):

Content to moderate:
${batch.map((c, i) => `${i + 1}. [${c.type}] "${c.text.substring(0, 200)}"`).join('\n')}

For each item, provide:
- toxicity: number (0-1)
- categories: string[] (harassment, hate_speech, sexual, violence, spam, self_harm, misinformation)
- action: "approve" | "shadow" | "remove" | "escalate"
- reason: brief explanation

JSON array: [{ "index": number, "toxicity": number, "categories": string[], "action": string, "reason": string }]
`;
    const result = await this.generateContent(prompt);
    try {
      const parsed = JSON.parse(result.match(/\[[\s\S]*\]/)?.[0] || '[]');
      const { getFirestore, doc, updateDoc, deleteDoc, collection, addDoc, serverTimestamp } = await import('firebase/firestore');
      const db = getFirestore();
      let removed = 0;

      for (const verdict of parsed) {
        const item = batch[verdict.index - 1];
        if (!item) continue;
        if (verdict.action === 'remove' && verdict.toxicity > 0.8) {
          await deleteDoc(doc(db, item.collection, item.id));
          removed++;
        } else if (verdict.action === 'shadow') {
          await updateDoc(doc(db, item.collection, item.id), { shadowBanned: true });
        }
      }

      await addDoc(collection(db, 'moderation_logs'), {
        agentId: this.id, batchSize: batch.length, removed,
        timestamp: serverTimestamp(),
      });
    } catch {}
    this.updateMetrics({ impressions: batch.length });
  }

  private async getUnmoderatedContent(): Promise<Array<{ id: string; type: string; text: string; collection: string }>> {
    try {
      const { getFirestore, collection, query, where, getDocs, limit, orderBy } = await import('firebase/firestore');
      const db = getFirestore();
      const snap = await getDocs(query(
        collection(db, 'moderation_queue'),
        where('status', '==', 'pending'),
        where('type', 'in', ['comment', 'chat_message']),
        orderBy('createdAt', 'asc'),
        limit(20)
      ));
      return snap.docs.map((d) => ({
        id: d.id, type: d.data().type || 'comment',
        text: d.data().text || '', collection: 'moderation_queue',
      }));
    } catch {
      return [];
    }
  }

  protected getCategory(): AGIAgent['category'] { return 'safety'; }
  protected getPriority(): AGIAgent['priority'] { return 'high'; }
}

export const toxicityFilterAgent = new ToxicityFilterAgent();
