package com.mychannel.util

/**
 * Real-money wager policy — mirrors iOS `WagerPolicy.swift` and web `wager-policy.ts`.
 * Client checks are never authoritative; server escrow Cloud Functions enforce limits.
 *
 * @see docs/android-money-parity.md (phase-486)
 */
object WagerPolicy {
    const val MINIMUM_AGE: Int = 18
    const val MIN_WAGER_DOLLARS: Double = 1.0
    const val MAX_WAGER_DOLLARS: Double = 100_000.0
    const val KYC_REQUIRED_ABOVE_DOLLARS: Double = 500.0
    const val CURRENT_TERMS_VERSION: String = "2025.1"
    const val PLATFORM_FEE_PERCENT: Double = 0.10

    val ALLOWED_REGIONS: Set<String> = setOf(
        "US-CA", "US-NY", "US-TX", "US-FL", "US-IL", "US-PA", "US-OH",
        "US-GA", "US-NC", "US-MI", "US-NJ", "US-VA", "US-WA", "US-AZ",
        "US-MA", "US-TN", "US-IN", "US-MO", "US-MD", "US-WI", "US-CO",
        "US-MN", "US-SC", "US-AL", "US-LA", "US-KY", "US-OR", "US-OK",
        "US-CT", "US-IA", "US-UT", "US-AR", "US-NV", "US-MS", "US-KS",
        "US-NM", "US-NE", "US-WV", "US-ID", "US-HI", "US-NH", "US-ME",
        "US-RI", "US-MT", "US-DE", "US-SD", "US-ND", "US-AK", "US-DC",
        "US-VT", "US-WY"
    )

    fun isOfAge(age: Int): Boolean = age >= MINIMUM_AGE

    fun requiresKYC(amountDollars: Double): Boolean = amountDollars > KYC_REQUIRED_ABOVE_DOLLARS

    fun isValidWagerAmount(amountDollars: Double): Boolean =
        amountDollars in MIN_WAGER_DOLLARS..MAX_WAGER_DOLLARS

    fun dailyLimitDollars(tier: AccountTier): Double = when (tier) {
        AccountTier.NEW -> 100.0
        AccountTier.VERIFIED -> 1_000.0
        AccountTier.PREMIUM -> 10_000.0
        AccountTier.VIP -> 100_000.0
    }

    fun isWithinDailyLimit(alreadyWagered: Double, newWager: Double, limit: Double): Boolean =
        alreadyWagered + newWager <= limit

    fun isRegionAllowed(region: String): Boolean = ALLOWED_REGIONS.contains(region)

    enum class AccountTier {
        NEW, VERIFIED, PREMIUM, VIP
    }
}
