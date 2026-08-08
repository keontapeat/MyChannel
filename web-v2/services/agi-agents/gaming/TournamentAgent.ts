// Tournament Agent — Manages bracket generation, seeding, and progression for esports events

import { BaseAgent } from '@/lib/vertex-ai/BaseAgent';
import { VertexAIModels } from '@/lib/vertex-ai/config';
import type { AGIAgent } from '@/types';

export class TournamentAgent extends BaseAgent {
  constructor() {
    super(
      'tournament-agent',
      'Tournament Orchestrator',
      'Generates tournament brackets, manages seeding based on ELO/championship rankings, handles progression logic and prize pool distribution',
      VertexAIModels.DYNAMIC_PRICING,
      { runInterval: 300, requiresNetwork: true, requiresAuth: true }
    );
  }

  protected async execute(): Promise<void> {
    const tournaments = await this.getActiveTournaments();
    if (tournaments.length === 0) return;

    for (const tournament of tournaments) {
      if (tournament.status === 'registration' && tournament.registeredCount >= tournament.minParticipants) {
        await this.generateBracket(tournament);
      } else if (tournament.status === 'in_progress') {
        await this.advanceRounds(tournament);
      }
    }
    this.updateMetrics({ impressions: tournaments.length });
  }

  private async generateBracket(tournament: any) {
    const prompt = `
Generate a fair tournament bracket:

Tournament: "${tournament.title}"
Format: ${tournament.format} (single_elimination, double_elimination, round_robin)
Participants: ${tournament.registeredCount}
Seeding method: ${tournament.seedingMethod} (elo, random, championship_rank)

Top seeds (by ELO):
${tournament.topSeeds?.map((s: any, i: number) => `${i + 1}. ${s.name} (ELO: ${s.elo})`).join('\n') || 'No seed data'}

Generate bracket with:
1. Proper seeding (1 vs lowest, 2 vs second-lowest, etc.)
2. Bye rounds if participants aren't a power of 2
3. Group assignments for round-robin
4. Estimated round durations

JSON: { "rounds": number, "matchups": [{ "round": number, "match": number, "seed1": number, "seed2": number }], "byes": number[], "estimatedDuration": string }
`;
    const result = await this.generateContent(prompt);
    try {
      const jsonMatch = result.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const { getFirestore, doc, updateDoc, serverTimestamp } = await import('firebase/firestore');
        await updateDoc(doc(getFirestore(), 'tournaments', tournament.id), {
          bracket: JSON.parse(jsonMatch[0]),
          status: 'in_progress',
          startedAt: serverTimestamp(),
        });
      }
    } catch {}
  }

  private async advanceRounds(tournament: any) {
    // Check if current round is complete and advance
    try {
      const { getFirestore, collection, query, where, getDocs } = await import('firebase/firestore');
      const matchesSnap = await getDocs(query(
        collection(getFirestore(), 'tournaments', tournament.id, 'matches'),
        where('round', '==', tournament.currentRound),
        where('status', '==', 'completed')
      ));
      const totalInRound = Math.ceil(tournament.registeredCount / Math.pow(2, tournament.currentRound));
      if (matchesSnap.size >= totalInRound) {
        // All matches in round complete — advance
        const { doc, updateDoc } = await import('firebase/firestore');
        await updateDoc(doc(getFirestore(), 'tournaments', tournament.id), {
          currentRound: tournament.currentRound + 1,
        });
      }
    } catch {}
  }

  private async getActiveTournaments(): Promise<any[]> {
    try {
      const { getFirestore, collection, query, where, getDocs, limit } = await import('firebase/firestore');
      const snap = await getDocs(query(
        collection(getFirestore(), 'tournaments'),
        where('status', 'in', ['registration', 'in_progress']),
        limit(10)
      ));
      return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    } catch {
      return [];
    }
  }

  protected getCategory(): AGIAgent['category'] { return 'gaming'; }
  protected getPriority(): AGIAgent['priority'] { return 'high'; }
}

export const tournamentAgent = new TournamentAgent();
