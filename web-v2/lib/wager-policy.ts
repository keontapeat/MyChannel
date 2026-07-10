/**
 * Shared wager / money policy — mirrors iOS `WagerPolicy` + `MoneyMath`.
 * Single source of truth for web VS Matches compliance gates.
 * Server must still enforce these; client checks are never authoritative.
 *
 * SSR-safe: no `window`, `document`, or browser-only globals.
 */

export const WAGER_POLICY = {
  minimumAge: 18,
  minWagerDollars: 1,
  maxWagerDollars: 100_000,
  /** KYC required for wagers strictly greater than this amount (USD). */
  kycRequiredAboveDollars: 500,
  currentTermsVersion: "2025.1",
  platformFeePercent: 0.1,
  allowedRegions: new Set([
    "US-CA", "US-NY", "US-TX", "US-FL", "US-IL", "US-PA", "US-OH",
    "US-GA", "US-NC", "US-MI", "US-NJ", "US-VA", "US-WA", "US-AZ",
    "US-MA", "US-TN", "US-IN", "US-MO", "US-MD", "US-WI", "US-CO",
    "US-MN", "US-SC", "US-AL", "US-LA", "US-KY", "US-OR", "US-OK",
    "US-CT", "US-IA", "US-UT", "US-AR", "US-NV", "US-MS", "US-KS",
    "US-NM", "US-NE", "US-WV", "US-ID", "US-HI", "US-NH", "US-ME",
    "US-RI", "US-MT", "US-DE", "US-SD", "US-ND", "US-AK", "US-DC",
    "US-VT", "US-WY",
  ]),
} as const;

export type AccountTier = "new" | "verified" | "premium" | "vip";

/** Medal division tiers — mirrors iOS ChampionshipBeltSystem / types/vs-matches. */
export type MedalDivision =
  | "bronze"
  | "silver"
  | "gold"
  | "platinum"
  | "diamond"
  | "legend";

/** Resolve medal division from wager amount (USD). Single source for web money UI. */
export function getMedalDivision(wagerAmount: number): MedalDivision {
  if (wagerAmount >= 10_001) return "legend";
  if (wagerAmount >= 5_001) return "diamond";
  if (wagerAmount >= 1_001) return "platinum";
  if (wagerAmount >= 501) return "gold";
  if (wagerAmount >= 101) return "silver";
  return "bronze";
}

export function isOfAge(age: number): boolean {
  return age >= WAGER_POLICY.minimumAge;
}

export function requiresKYC(amountDollars: number): boolean {
  return amountDollars > WAGER_POLICY.kycRequiredAboveDollars;
}

export function isValidWagerAmount(amountDollars: number): boolean {
  return (
    amountDollars >= WAGER_POLICY.minWagerDollars &&
    amountDollars <= WAGER_POLICY.maxWagerDollars
  );
}

export function dailyLimitDollars(tier: AccountTier): number {
  switch (tier) {
    case "new":
      return 100;
    case "verified":
      return 1_000;
    case "premium":
      return 10_000;
    case "vip":
      return 100_000;
  }
}

export function isWithinDailyLimit(
  alreadyWagered: number,
  newWager: number,
  limit: number
): boolean {
  return alreadyWagered + newWager <= limit;
}

export function isRegionAllowed(region: string): boolean {
  return WAGER_POLICY.allowedRegions.has(region);
}

/** Convert dollars → integer cents with rounding (not truncation). */
export function centsFromDollars(dollars: number): number {
  return Math.round(dollars * 100);
}

export function dollarsFromCents(cents: number): number {
  return cents / 100;
}

export function platformFeeCents(
  grossCents: number,
  feePercent: number = WAGER_POLICY.platformFeePercent
): number {
  return Math.round(grossCents * feePercent);
}

export function winnerPayoutCents(
  grossCents: number,
  feePercent: number = WAGER_POLICY.platformFeePercent
): number {
  return Math.max(0, grossCents - platformFeeCents(grossCents, feePercent));
}

/**
 * Client-side preflight for creating/accepting a wager.
 * Server must re-validate; this only blocks obvious UI mistakes.
 */
export function canWagerClientPreflight(input: {
  age: number;
  kycApproved: boolean;
  amountDollars: number;
  region: string;
  alreadyWageredToday: number;
  tier: AccountTier;
  termsAcceptedVersion: string | null;
}): { ok: true } | { ok: false; reasons: string[] } {
  const reasons: string[] = [];
  if (!isOfAge(input.age)) reasons.push("Must be 18+");
  if (!isValidWagerAmount(input.amountDollars)) {
    reasons.push(
      `Wager must be $${WAGER_POLICY.minWagerDollars}–$${WAGER_POLICY.maxWagerDollars}`
    );
  }
  if (requiresKYC(input.amountDollars) && !input.kycApproved) {
    reasons.push("KYC required for wagers over $500");
  }
  if (!isRegionAllowed(input.region)) {
    reasons.push("Real-money play not available in your region");
  }
  const limit = dailyLimitDollars(input.tier);
  if (
    !isWithinDailyLimit(input.alreadyWageredToday, input.amountDollars, limit)
  ) {
    reasons.push("Daily wager limit exceeded");
  }
  if (input.termsAcceptedVersion !== WAGER_POLICY.currentTermsVersion) {
    reasons.push("Accept the current VS Match terms");
  }
  return reasons.length === 0 ? { ok: true } : { ok: false, reasons };
}
