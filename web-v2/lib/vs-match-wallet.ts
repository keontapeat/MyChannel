/**
 * Load VS Match wallet + transactions from Firestore (vs_match_wallets / vs_match_transactions).
 * Client never credits balances — reads only.
 * Also provides escrow status listeners for match detail pages.
 */

import { authService } from "@/lib/firebase/auth";
import { MONEY_CONTRACT } from "./money-contract";
import type {
  VSMatchTransaction,
  VSMatchTransactionStatus,
  VSMatchTransactionType,
  VSMatchWallet,
} from "@/types/vs-matches";

const emptyWallet = (userId: string): VSMatchWallet => ({
  userId,
  availableBalance: 0,
  pendingBalance: 0,
  totalDeposited: 0,
  totalWithdrawn: 0,
  totalWon: 0,
  totalLost: 0,
  createdAt: new Date(),
  updatedAt: new Date(),
});

function asDate(value: unknown): Date {
  if (value && typeof value === "object" && "toDate" in value) {
    return (value as { toDate: () => Date }).toDate();
  }
  if (typeof value === "string" || typeof value === "number") {
    return new Date(value);
  }
  return new Date();
}

export async function loadVSMatchWallet(): Promise<{
  wallet: VSMatchWallet;
  transactions: VSMatchTransaction[];
  signedIn: boolean;
}> {
  const token = await authService.getIdToken();
  const { auth } = await import("@/lib/firebase/config");
  const uid = auth.currentUser?.uid;
  if (!token || !uid) {
    return { wallet: emptyWallet("anonymous"), transactions: [], signedIn: false };
  }

  const { getFirestore, doc, getDoc, collection, query, where, orderBy, limit, getDocs } =
    await import("firebase/firestore");
  const db = getFirestore();

  const walletSnap = await getDoc(doc(db, "vs_match_wallets", uid));
  const data = walletSnap.exists() ? walletSnap.data() : {};
  const wallet: VSMatchWallet = {
    userId: uid,
    availableBalance: Number(data.availableBalance ?? 0),
    pendingBalance: Number(data.pendingBalance ?? 0),
    totalDeposited: Number(data.totalDeposited ?? 0),
    totalWithdrawn: Number(data.totalWithdrawn ?? 0),
    totalWon: Number(data.totalWon ?? 0),
    totalLost: Number(data.totalLost ?? 0),
    createdAt: asDate(data.createdAt),
    updatedAt: asDate(data.updatedAt),
  };

  let transactions: VSMatchTransaction[] = [];
  try {
    const txSnap = await getDocs(
      query(
        collection(db, "vs_match_transactions"),
        where("userId", "==", uid),
        orderBy("createdAt", "desc"),
        limit(50)
      )
    );
    transactions = txSnap.docs.map((d) => {
      const t = d.data();
      return {
        id: d.id,
        userId: String(t.userId ?? uid),
        type: (t.type as VSMatchTransactionType) ?? ("deposit" as VSMatchTransactionType),
        amount: Number(t.amount ?? 0),
        status: (t.status as VSMatchTransactionStatus) ?? ("pending" as VSMatchTransactionStatus),
        matchId: t.matchId ? String(t.matchId) : undefined,
        stripePaymentIntentId: t.stripePaymentIntentId
          ? String(t.stripePaymentIntentId)
          : undefined,
        createdAt: asDate(t.createdAt),
        completedAt: t.completedAt ? asDate(t.completedAt) : undefined,
        description: t.description ? String(t.description) : undefined,
      };
    });
  } catch (err) {
    console.warn("[wallet] transactions query failed (index?)", err);
  }

  return { wallet, transactions, signedIn: true };
}

export type EscrowRowStatus = "held" | "released" | "refunded" | "disputed" | "expired";

export type EscrowStatusSnapshot = {
  matchId: string;
  status: EscrowRowStatus;
  amountCents?: number;
  updatedAt?: Date;
};

/**
 * Subscribe to escrow rows for a match. Returns an unsubscribe function.
 * Requires Firebase client auth for Firestore rules.
 */
export async function subscribeEscrowStatus(
  matchId: string,
  onUpdate: (rows: EscrowStatusSnapshot[]) => void,
  onError?: (err: Error) => void
): Promise<() => void> {
  const { getFirestore, collection, query, where, onSnapshot } = await import(
    "firebase/firestore"
  );
  const db = getFirestore();
  const q = query(collection(db, "escrow"), where("matchId", "==", matchId));
  return onSnapshot(
    q,
    (snap) => {
      const rows: EscrowStatusSnapshot[] = snap.docs.map((docSnap) => {
        const data = docSnap.data();
        return {
          matchId: String(data.matchId ?? matchId),
          status: (data.status as EscrowRowStatus) ?? "held",
          amountCents: typeof data.amountCents === "number" ? data.amountCents : undefined,
          updatedAt: data.updatedAt?.toDate?.(),
        };
      });
      onUpdate(rows);
    },
    (err) => onError?.(err)
  );
}

export function escrowApiUrl(path: keyof typeof MONEY_CONTRACT.escrow.endpoints): string {
  return `${MONEY_CONTRACT.escrow.apiBase}${MONEY_CONTRACT.escrow.endpoints[path]}`;
}
