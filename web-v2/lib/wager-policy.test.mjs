/**
 * Node built-in test runner for wager-policy (no tsx required).
 * Mirrors lib/wager-policy.test.ts — keep in sync when policy changes.
 */
import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  WAGER_POLICY,
  canWagerClientPreflight,
  centsFromDollars,
  dollarsFromCents,
  isOfAge,
  isRegionAllowed,
  isValidWagerAmount,
  isWithinDailyLimit,
  platformFeeCents,
  requiresKYC,
  winnerPayoutCents,
} from "./wager-policy.mjs";

describe("wager-policy (mjs)", () => {
  it("rounds dollars to cents", () => {
    assert.equal(centsFromDollars(19.99), 1999);
    assert.equal(dollarsFromCents(1999), 19.99);
  });

  it("fee + payout equals gross", () => {
    const pot = centsFromDollars(50) * 2;
    assert.equal(platformFeeCents(pot) + winnerPayoutCents(pot), pot);
  });

  it("validates wager bounds", () => {
    assert.equal(isValidWagerAmount(1), true);
    assert.equal(isValidWagerAmount(0.99), false);
  });

  it("requires KYC at $500 and above", () => {
    assert.equal(requiresKYC(499.99), false);
    assert.equal(requiresKYC(500), true);
    assert.equal(requiresKYC(500.01), true);
  });

  it("enforces age and region", () => {
    assert.equal(isOfAge(18), true);
    assert.equal(isRegionAllowed("US-CA"), true);
    assert.equal(isRegionAllowed("US-XX"), false);
  });

  it("enforces daily limit", () => {
    assert.equal(isWithinDailyLimit(90, 10, 100), true);
    assert.equal(isWithinDailyLimit(90, 11, 100), false);
  });

  it("preflight rejects stale terms", () => {
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
  });

  it("preflight accepts current terms", () => {
    const result = canWagerClientPreflight({
      age: 21,
      kycApproved: true,
      amountDollars: 50,
      region: "US-TX",
      alreadyWageredToday: 0,
      tier: "verified",
      termsAcceptedVersion: WAGER_POLICY.currentTermsVersion,
    });
    assert.deepEqual(result, { ok: true });
  });

  it("preflight rejects KYC at the $500 boundary", () => {
    const result = canWagerClientPreflight({
      age: 21,
      kycApproved: false,
      amountDollars: 500,
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
