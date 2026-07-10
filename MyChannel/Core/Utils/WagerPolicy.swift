//
//  WagerPolicy.swift
//  MyChannel
//
//  Pure, testable real-money wager policy: the compliance thresholds that gate
//  VS Match wagering (18+, KYC > $500, per-tier daily limits, region allowlist).
//  Centralized here so the constants are a single source of truth and unit-tested.
//  Enforcement still happens in VSMatchComplianceService (and must also be enforced
//  server-side — client checks alone are never authoritative for money).
//

import Foundation

enum WagerPolicy {
    /// Minimum age to wager real money.
    static let minimumAge: Int = 18

    /// Wager amount bounds (USD).
    static let minWagerDollars: Double = 1
    static let maxWagerDollars: Double = 100_000

    /// KYC is required for wagers strictly greater than this amount (USD).
    static let kycRequiredAboveDollars: Double = 500

    /// Current VS Match Terms of Service version. Bump this when the wagering
    /// terms change so previously-accepted users are re-prompted.
    static let currentTermsVersion: String = "2025.1"

    /// Platform fee on VS Match pots — mirrors `MoneyMath.platformFeePercent`.
    static var platformFeePercent: Double { MoneyMath.platformFeePercent }

    static func isOfAge(_ age: Int) -> Bool { age >= minimumAge }

    static func requiresKYC(amountDollars: Double) -> Bool { amountDollars > kycRequiredAboveDollars }

    static func isValidWagerAmount(_ amountDollars: Double) -> Bool {
        amountDollars >= minWagerDollars && amountDollars <= maxWagerDollars
    }

    /// Per-account-tier daily wager limit (USD).
    static func dailyLimitDollars(tier: AccountTier) -> Double {
        switch tier {
        case .new: return 100
        case .verified: return 1_000
        case .premium: return 10_000
        case .vip: return 100_000
        }
    }

    /// True if a new wager keeps the user within their daily limit.
    /// NOTE: Server escrow (`assertWagerCompliance` in index.js) resets the daily
    /// window at **UTC midnight**. iOS `getDailyWagerAmount` currently uses local
    /// `Calendar.current.startOfDay` — keep these aligned before launch or users
    /// near timezone boundaries may see a client/server mismatch for ~hours.
    static func isWithinDailyLimit(alreadyWagered: Double, newWager: Double, limit: Double) -> Bool {
        alreadyWagered + newWager <= limit
    }

    /// Regions (US states + DC) where skill-based real-money play is offered.
    static let allowedRegions: Set<String> = [
        "US-CA", "US-NY", "US-TX", "US-FL", "US-IL", "US-PA", "US-OH",
        "US-GA", "US-NC", "US-MI", "US-NJ", "US-VA", "US-WA", "US-AZ",
        "US-MA", "US-TN", "US-IN", "US-MO", "US-MD", "US-WI", "US-CO",
        "US-MN", "US-SC", "US-AL", "US-LA", "US-KY", "US-OR", "US-OK",
        "US-CT", "US-IA", "US-UT", "US-AR", "US-NV", "US-MS", "US-KS",
        "US-NM", "US-NE", "US-WV", "US-ID", "US-HI", "US-NH", "US-ME",
        "US-RI", "US-MT", "US-DE", "US-SD", "US-ND", "US-AK", "US-DC",
        "US-VT", "US-WY"
    ]

    static func isRegionAllowed(_ region: String) -> Bool {
        allowedRegions.contains(region)
    }

    /// Fail closed: user must have accepted the *current* terms version.
    static func isTermsAcceptanceValid(accepted: Bool, version: String) -> Bool {
        accepted && version == currentTermsVersion
    }
}
