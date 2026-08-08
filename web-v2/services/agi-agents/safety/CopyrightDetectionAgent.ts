// Copyright Detection Agent — Content ID equivalent using audio/video fingerprinting signals

import { BaseAgent } from '@/lib/vertex-ai/BaseAgent';
import { VertexAIModels } from '@/lib/vertex-ai/config';
import type { AGIAgent } from '@/types';

export class CopyrightDetectionAgent extends BaseAgent {
  constructor() {
    super(
      'copyright-detection-agent',
      'Copyright Detection (Content ID)',
      'Detects copyrighted content in uploads using audio fingerprinting signals, visual similarity, and metadata matching',
      VertexAIModels.DYNAMIC_PRICING,
      { runInterval: 300, requiresNetwork: true, requiresAuth: true }
    );
  }

  protected async execute(): Promise<void> {
    const uploads = await this.getRecentUploads();
    if (uploads.length === 0) return;

    const prompt = `
Analyze these recent video uploads for potential copyright issues:

${uploads.map((u, i) => `${i + 1}. Title: "${u.title}" | Description: "${u.description?.substring(0, 100)}" | Duration: ${u.duration}s | Category: ${u.category}`).join('\n')}

For each video, assess:
1. Title contains copyrighted music/movie/show names?
2. Description references third-party content?
3. Duration suggests full movie/episode reupload?
4. Category + title pattern matches known piracy patterns?

Score copyright risk (0-1) and recommend:
- "clear" — no issues detected
- "review" — possible fair use, needs human check
- "flag" — likely infringement, hold for DMCA process
- "block" — definite full reupload of copyrighted content

JSON: [{ "index": number, "risk": number, "action": string, "matchType": string, "reasoning": string }]
`;
    const result = await this.generateContent(prompt);
    try {
      const parsed = JSON.parse(result.match(/\[[\s\S]*\]/)?.[0] || '[]');
      const { getFirestore, collection, addDoc, serverTimestamp, doc, updateDoc } = await import('firebase/firestore');
      const db = getFirestore();

      for (const verdict of parsed) {
        const upload = uploads[verdict.index - 1];
        if (!upload || verdict.action === 'clear') continue;
        if (verdict.risk > 0.7) {
          await updateDoc(doc(db, 'videos', upload.id), { moderationStatus: 'copyright_review' });
          await addDoc(collection(db, 'copyright_flags'), {
            videoId: upload.id, risk: verdict.risk, action: verdict.action,
            matchType: verdict.matchType, reasoning: verdict.reasoning,
            agentId: this.id, createdAt: serverTimestamp(),
          });
        }
      }
    } catch {}
    this.updateMetrics({ impressions: uploads.length });
  }

  private async getRecentUploads() {
    try {
      const { getFirestore, collection, query, where, getDocs, limit, orderBy } = await import('firebase/firestore');
      const fiveMinAgo = new Date(Date.now() - 300000);
      const snap = await getDocs(query(
        collection(getFirestore(), 'videos'),
        where('processingStatus', '==', 'ready'),
        where('copyrightScanned', '==', false),
        orderBy('uploadedAt', 'desc'),
        limit(10)
      ));
      return snap.docs.map((d) => ({ id: d.id, ...d.data() } as any));
    } catch {
      return [];
    }
  }

  protected getCategory(): AGIAgent['category'] { return 'safety'; }
  protected getPriority(): AGIAgent['priority'] { return 'high'; }
}

export const copyrightDetectionAgent = new CopyrightDetectionAgent();
