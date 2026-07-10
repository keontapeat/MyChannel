/**
 * Load championship rankings + recent VS matches from Firestore.
 * Falls back to empty arrays when unsigned / collections empty.
 */

import type { MedalDivision, RankedCompetitor } from "@/types/vs-matches";

export type RecentVSMatchRow = {
  id: string;
  player1: string;
  player2: string;
  wager: number;
  winner: 1 | 2;
  hoursAgo: number;
  date: Date;
  category: string;
};

function asDate(value: unknown): Date {
  if (value && typeof value === "object" && "toDate" in value) {
    return (value as { toDate: () => Date }).toDate();
  }
  if (typeof value === "string" || typeof value === "number") {
    return new Date(value);
  }
  return new Date();
}

export async function loadChampionshipRankings(
  division: MedalDivision
): Promise<RankedCompetitor[]> {
  try {
    const { getFirestore, collection, query, where, orderBy, limit, getDocs } =
      await import("firebase/firestore");
    const db = getFirestore();
    const snap = await getDocs(
      query(
        collection(db, "competitor_rankings"),
        where("division", "==", division),
        orderBy("rank", "asc"),
        limit(15)
      )
    );
    return snap.docs.map((d, i) => {
      const data = d.data();
      return {
        userId: String(data.userId ?? d.id),
        displayName: String(data.displayName ?? `Competitor ${i + 1}`),
        photoURL: data.photoURL ? String(data.photoURL) : null,
        division,
        rank: Number(data.rank ?? i + 1),
        wins: Number(data.wins ?? 0),
        losses: Number(data.losses ?? 0),
        winRate: Number(data.winRate ?? 0),
        totalWagered: Number(data.totalWagered ?? 0),
        totalWinnings: Number(data.totalWinnings ?? 0),
        currentStreak: Number(data.currentStreak ?? 0),
        lastMatchDate: asDate(data.lastMatchDate),
        isChampion: Boolean(data.isChampion ?? i === 0),
        defenseCount: data.defenseCount != null ? Number(data.defenseCount) : undefined,
        rankChange: data.rankChange != null ? Number(data.rankChange) : undefined,
      };
    });
  } catch (err) {
    console.warn("[medals] rankings query failed", err);
    return [];
  }
}

export async function loadRecentVersusMatches(
  limitCount = 5
): Promise<RecentVSMatchRow[]> {
  try {
    const { getFirestore, collection, query, orderBy, limit, getDocs } =
      await import("firebase/firestore");
    const db = getFirestore();
    const snap = await getDocs(
      query(collection(db, "versus_matches"), orderBy("createdAt", "desc"), limit(limitCount))
    );
    const now = Date.now();
    return snap.docs.map((d) => {
      const data = d.data();
      const created = asDate(data.createdAt);
      const hoursAgo = Math.max(1, Math.round((now - created.getTime()) / 3600000));
      const winnerId = data.winnerId ? String(data.winnerId) : "";
      const challengerId = String(data.challengerId ?? "");
      const winner: 1 | 2 =
        winnerId && winnerId === challengerId ? 1 : 2;
      return {
        id: d.id,
        player1: String(data.challengerUsername ?? data.challengerId ?? "Player 1"),
        player2: String(
          data.opponentUsername ?? data.opponentId ?? "Open challenge"
        ),
        wager: Number(data.wagerAmount ?? (data.wagerAmountCents ?? 0) / 100),
        winner,
        hoursAgo,
        date: created,
        category: String(data.category ?? "Gaming"),
      };
    });
  } catch (err) {
    console.warn("[medals] recent matches query failed", err);
    return [];
  }
}
