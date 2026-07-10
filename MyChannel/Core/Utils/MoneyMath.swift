//
//  MoneyMath.swift
//  MyChannel
//
//  Pure, testable money arithmetic. Currency is handled in INTEGER CENTS to avoid
//  floating-point rounding errors (per money-and-compliance rules). The only place
//  dollars→cents conversion happens should be through `cents(fromDollars:)`, which
//  rounds rather than truncates — `Int(19.99 * 100)` is 1998, not 1999.
//
//  Firestore contract (canonical):
//  - Prefer `amountCents` / `platformFeeCents` / `netAmountCents` (Int) on money docs.
//  - Dollar Doubles may remain for display/legacy reads; never use them for settlement.
//  - Server escrow Cloud Functions are authoritative for captures/transfers.
//

import Foundation

enum MoneyMath {
    /// Platform fee on VS Matches (10%).
    static let platformFeePercent: Double = 0.10

    /// Convert a dollar amount to integer cents, rounding to the nearest cent.
    /// Rounding (not truncation) prevents undercharging by a penny on values
    /// like 19.99 that aren't exactly representable in binary floating point.
    static func cents(fromDollars dollars: Double) -> Int {
        Int((dollars * 100).rounded())
    }

    /// Convert integer cents back to dollars.
    static func dollars(fromCents cents: Int) -> Double {
        Double(cents) / 100.0
    }

    /// Platform fee in cents for a gross amount in cents, rounded to the nearest cent.
    static func platformFeeCents(grossCents: Int, feePercent: Double = platformFeePercent) -> Int {
        Int((Double(grossCents) * feePercent).rounded())
    }

    /// Winner payout in cents: gross minus platform fee. Always non-negative.
    static func winnerPayoutCents(grossCents: Int, feePercent: Double = platformFeePercent) -> Int {
        max(0, grossCents - platformFeeCents(grossCents: grossCents, feePercent: feePercent))
    }

    /// Splits a gross escrow amount into refund vs retained portions (both in cents).
    /// `requestedRefundCents` is clamped to `[0, grossCents]` so retained is never negative.
    static func partialRefundCents(grossCents: Int, requestedRefundCents: Int) -> (refund: Int, retained: Int) {
        let refund = max(0, min(requestedRefundCents, grossCents))
        return (refund: refund, retained: grossCents - refund)
    }

    /// Super Thanks platform fee (30% — creator receives 70%).
    static let superThanksPlatformFeePercent: Double = 0.30

    /// Creator share of a Super Thanks gross amount in cents.
    static func superThanksCreatorShareCents(grossCents: Int) -> Int {
        max(0, grossCents - platformFeeCents(grossCents: grossCents, feePercent: superThanksPlatformFeePercent))
    }

    /// Revenue per single impression in cents from a CPM quoted in dollars (e.g. $12.50 → 1.25¢).
    static func impressionCents(fromCPM cpmDollars: Double) -> Int {
        Int((cpmDollars / 1000.0 * 100).rounded())
    }
}
