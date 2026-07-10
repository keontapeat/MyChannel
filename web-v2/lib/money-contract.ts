/**
 * OpenAPI-ish shared money contract for web + Cloud Functions.
 * Mirrors iOS WagerPolicy / MoneyMath and web-v2/lib/wager-policy.ts.
 * Server enforcement remains authoritative; this is the client contract surface.
 */

import {
  WAGER_POLICY,
  getMedalDivision,
  centsFromDollars,
  dollarsFromCents,
  platformFeeCents,
  winnerPayoutCents,
  dailyLimitDollars,
  type AccountTier,
  type MedalDivision,
} from "./wager-policy";

export type { AccountTier, MedalDivision };

/** Branded cents type for Stripe / escrow amounts (integer cents, USD). */
export type WagerCents = number;

/** Contract version pin — must match escrow CF WAGER_POLICY.currentTermsVersion. */
export const MONEY_CONTRACT_VERSION = "2025.1" as const;

export const MONEY_CONTRACT = {
  version: MONEY_CONTRACT_VERSION,
  currency: "USD",
  /** Stripe amounts are always integer cents. */
  amountUnit: "cents" as const,
  terms: {
    currentVersion: WAGER_POLICY.currentTermsVersion,
    minimumAge: WAGER_POLICY.minimumAge,
  },
  wager: {
    minDollars: WAGER_POLICY.minWagerDollars,
    maxDollars: WAGER_POLICY.maxWagerDollars,
    kycRequiredAboveDollars: WAGER_POLICY.kycRequiredAboveDollars,
    platformFeePercent: WAGER_POLICY.platformFeePercent,
    allowedRegions: Array.from(WAGER_POLICY.allowedRegions),
    dailyLimitDollars: {
      new: dailyLimitDollars("new"),
      verified: dailyLimitDollars("verified"),
      premium: dailyLimitDollars("premium"),
      vip: dailyLimitDollars("vip"),
    },
  },
  escrow: {
    /** Cloud Function base (gen2 HTTP trigger). */
    apiBase:
      "https://us-central1-mychannel-ca26d.cloudfunctions.net/escrow-payments",
    endpoints: {
      createPayment: "/create-escrow-payment",
      capture: "/capture-payment",
      cancel: "/cancel-payment",
      transfer: "/create-transfer",
      webhook: "/webhook",
    },
    /** Wallet top-ups use this sentinel matchId (not a real versus match). */
    walletDepositMatchId: "wallet_deposit",
    captureMethod: {
      matchWager: "manual",
      walletDeposit: "automatic",
    },
  },
  collections: {
    versusMatches: "versus_matches",
    escrow: "stripe_escrow",
    wallet: "vs_match_wallets",
    walletCredits: "vs_match_wallet_credits",
    transactions: "vs_match_transactions",
    compliance: "vs_match_compliance",
  },
} as const;

export {
  WAGER_POLICY,
  getMedalDivision,
  centsFromDollars,
  dollarsFromCents,
  platformFeeCents,
  winnerPayoutCents,
  dailyLimitDollars,
};
