/**
 * VS Match create + escrow helpers for web.
 * Escrow CF is authoritative; client preflight is UX only.
 */

import { authService } from "@/lib/firebase/auth";
import { centsFromDollars } from "@/lib/wager-policy";

const ESCROW_BASE =
  "https://us-central1-mychannel-ca26d.cloudfunctions.net";

export type CreateMatchInput = {
  wagerAmountDollars: number;
  category: string;
  opponentUsername?: string;
  description?: string;
};

export type CreateMatchResult =
  | { ok: true; matchId: string; paymentIntentId?: string; clientSecret?: string }
  | { ok: false; error: string };

/**
 * Creates a versus_matches draft in Firestore, then holds the challenger's
 * wager via the authenticated create-escrow-payment Cloud Function.
 * Requires a signed-in user with a Stripe customer on file.
 */
export async function createVersusMatchWithEscrow(
  input: CreateMatchInput
): Promise<CreateMatchResult> {
  const token = await authService.getIdToken();
  if (!token) {
    return { ok: false, error: "Sign in to create a real-money match" };
  }

  const amountCents = centsFromDollars(input.wagerAmountDollars);
  if (!Number.isInteger(amountCents) || amountCents < 100 || amountCents > 10_000_000) {
    return { ok: false, error: "Wager must be between $1 and $100,000" };
  }

  let matchId: string;
  try {
    const { getFirestore, collection, addDoc, serverTimestamp } = await import(
      "firebase/firestore"
    );
    const { auth } = await import("@/lib/firebase/config");
    const uid = auth.currentUser?.uid;
    if (!uid) {
      return { ok: false, error: "Sign in to create a real-money match" };
    }

    const db = getFirestore();
    const docRef = await addDoc(collection(db, "versus_matches"), {
      challengerId: uid,
      opponentId: null,
      opponentUsername: input.opponentUsername?.trim() || null,
      category: input.category,
      wagerAmount: input.wagerAmountDollars,
      wagerAmountCents: amountCents,
      description: input.description?.trim() || null,
      status: "pending",
      createdAt: serverTimestamp(),
      termsVersion: "2025.1",
    });
    matchId = docRef.id;
  } catch (err) {
    console.error("[vs-match] failed to create match doc", err);
    return { ok: false, error: "Could not create match. Try again." };
  }

  try {
    const res = await fetch(`${ESCROW_BASE}/create-escrow-payment`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        amount: amountCents,
        matchId,
        captureMethod: "manual",
      }),
    });

    const json = (await res.json().catch(() => ({}))) as {
      error?: string;
      paymentIntentId?: string;
      clientSecret?: string;
    };

    if (!res.ok) {
      return {
        ok: false,
        error: json.error || `Escrow failed (${res.status})`,
      };
    }

    return {
      ok: true,
      matchId,
      paymentIntentId: json.paymentIntentId,
      clientSecret: json.clientSecret,
    };
  } catch (err) {
    console.error("[vs-match] escrow request failed", err);
    return {
      ok: false,
      error: "Could not hold funds in escrow. Match draft was created.",
    };
  }
}
