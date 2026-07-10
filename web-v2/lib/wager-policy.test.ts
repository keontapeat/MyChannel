/**
 * Node built-in tests for shared wager policy (no vitest dependency).
 * Run: `node --import tsx --test lib/wager-policy.test.ts` or compile via tsc.
 * Also importable as a plain assertion module from Playwright setup.
 */
import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  WAGER_POLICY,
  canWagerClientPreflight,
  centsFromDollars,
  dollarsFromCents,
  getMedalDivision,
  isOfAge,
  isRegionAllowed,
  isValidWagerAmount,
  isWithinDailyLimit,
  platformFeeCents,
  requiresKYC,
  winnerPayoutCents,
} from "./wager-policy";

describe("wager-policy", () => {
  it("rounds dollars to cents (no truncation)", () => {
    assert.equal(centsFromDollars(19.99), 1999);
    assert.equal(dollarsFromCents(1999), 19.99);
  });

  it("computes 10% platform fee on pot in cents", () => {
    const pot = centsFromDollars(50) * 2;
    assert.equal(platformFeeCents(pot), 1000);
    assert.equal(winnerPayoutCents(pot), 9000);
    assert.equal(platformFeeCents(pot) + winnerPayoutCents(pot), pot);
  });

  it("resolves medal division from wager amount", () => {
    assert.equal(getMedalDivision(50), "bronze");
    assert.equal(getMedalDivision(500), "gold");
    assert.equal(getMedalDivision(15_000), "legend");
  });

  it("validates wager bounds", () => {
    assert.equal(isValidWagerAmount(1), true);
    assert.equal(isValidWagerAmount(100_000), true);
    assert.equal(isValidWagerAmount(0.99), false);
    assert.equal(isValidWagerAmount(100_000.01), false);
  });

  it("requires KYC above $500", () => {
    assert.equal(requiresKYC(500), false);
    assert.equal(requiresKYC(500.01), true);
  });

  it("enforces age and region", () => {
    assert.equal(isOfAge(18), true);
    assert.equal(isOfAge(17), false);
    assert.equal(isRegionAllowed("US-CA"), true);
    assert.equal(isRegionAllowed("US-XX"), false);
  });

  it("enforces daily limit", () => {
    assert.equal(isWithinDailyLimit(90, 10, 100), true);
    assert.equal(isWithinDailyLimit(90, 11, 100), false);
  });

  it("preflight rejects stale terms version", () => {
    const result = canWagerClientPreflight({
      age: 21,
      kycApproved: true,
      amountDollars: 50,
      region: "US-CA",
      alreadyWageredToday: 0,
      tier: "verified",
      termsAcceptedVersion: "2024.1",
    });
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.ok(result.reasons.some((r) => r.toLowerCase().includes("terms")));
    }
  });

  it("preflight rejects KYC when wager over $500", () => {
    const result = canWagerClientPreflight({
      age: 21,
      kycApproved: false,
      amountDollars: 500.01,
      region: "US-CA",
      alreadyWageredToday: 0,
      tier: "verified",
      termsAcceptedVersion: WAGER_POLICY.currentTermsVersion,
    });
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.ok(result.reasons.some((r) => r.toLowerCase().includes("kyc")));
    }
  });

  it("preflight denies disallowed region", () => {
    const result = canWagerClientPreflight({
      age: 21,
      kycApproved: true,
      amountDollars: 50,
      region: "US-XX",
      alreadyWageredToday: 0,
      tier: "verified",
      termsAcceptedVersion: WAGER_POLICY.currentTermsVersion,
    });
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.ok(result.reasons.some((r) => r.toLowerCase().includes("region")));
    }
  });
});
