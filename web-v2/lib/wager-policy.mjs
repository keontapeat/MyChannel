/**
 * ESM mirror of wager-policy.ts for `node --test` without tsx.
 * Keep in sync with lib/wager-policy.ts when policy constants change.
 */

export const WAGER_POLICY = {
  minimumAge: 18,
  minWagerDollars: 1,
  maxWagerDollars: 100_000,
  kycRequiredAtOrAboveDollars: 500,
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
};

/** Resolve medal division from wager amount (USD). Keep in sync with wager-policy.ts. */
export function getMedalDivision(wagerAmount) {
  if (wagerAmount >= 10_001) return "legend";
  if (wagerAmount >= 5_001) return "diamond";
  if (wagerAmount >= 1_001) return "platinum";
  if (wagerAmount >= 501) return "gold";
  if (wagerAmount >= 101) return "silver";
  return "bronze";
}

export function isOfAge(age) {
  return age >= WAGER_POLICY.minimumAge;
}

export function requiresKYC(amountDollars) {
  return amountDollars >= WAGER_POLICY.kycRequiredAtOrAboveDollars;
}

export function isValidWagerAmount(amountDollars) {
  return (
    amountDollars >= WAGER_POLICY.minWagerDollars &&
    amountDollars <= WAGER_POLICY.maxWagerDollars
  );
}

export function dailyLimitDollars(tier) {
  switch (tier) {
    case "new":
      return 100;
    case "verified":
      return 1_000;
    case "premium":
      return 10_000;
    case "vip":
      return 100_000;
    default:
      return 100;
  }
}

export function isWithinDailyLimit(alreadyWagered, newWager, limit) {
  return alreadyWagered + newWager <= limit;
}

export function isRegionAllowed(region) {
  return WAGER_POLICY.allowedRegions.has(region);
}

export function centsFromDollars(dollars) {
  return Math.round(dollars * 100);
}

export function dollarsFromCents(cents) {
  return cents / 100;
}

export function platformFeeCents(grossCents, feePercent = WAGER_POLICY.platformFeePercent) {
  return Math.round(grossCents * feePercent);
}

export function winnerPayoutCents(grossCents, feePercent = WAGER_POLICY.platformFeePercent) {
  return Math.max(0, grossCents - platformFeeCents(grossCents, feePercent));
}

export function canWagerClientPreflight(input) {
  const reasons = [];
  if (!isOfAge(input.age)) reasons.push("Must be 18+");
  if (!isValidWagerAmount(input.amountDollars)) {
    reasons.push(
      `Wager must be $${WAGER_POLICY.minWagerDollars}–$${WAGER_POLICY.maxWagerDollars}`
    );
  }
  if (requiresKYC(input.amountDollars) && !input.kycApproved) {
    reasons.push("KYC required for wagers of $500 or more");
  }
  if (!isRegionAllowed(input.region)) {
    reasons.push("Real-money play not available in your region");
  }
  const limit = dailyLimitDollars(input.tier);
  if (!isWithinDailyLimit(input.alreadyWageredToday, input.amountDollars, limit)) {
    reasons.push("Daily wager limit exceeded");
  }
  if (input.termsAcceptedVersion !== WAGER_POLICY.currentTermsVersion) {
    reasons.push("Accept the current VS Match terms");
  }
  return reasons.length === 0 ? { ok: true } : { ok: false, reasons };
}
