package com.mychannel.domain.model

import com.google.firebase.Timestamp

/**
 * Championship belt divisions, keyed by wager tier.
 *
 * MONEY RULE: all bounds are expressed in **integer cents** to avoid floating
 * point currency math. Dollar amounts from the compliance steering map as:
 *   Lightweight        $1–$100        ->     100..10_000 cents
 *   Welterweight       $101–$500      ->  10_100..50_000 cents
 *   Middleweight       $501–$1K       ->  50_100..100_000 cents
 *   Heavyweight        $1K–$5K        -> 100_100..500_000 cents
 *   Super Heavyweight  $5K–$10K       -> 500_100..1_000_000 cents
 *   Ultra Heavyweight  $10K+          -> 1_000_100.. cents
 */
enum class ChampionshipDivision(val raw: String) {
    LIGHTWEIGHT("lightweight"),
    WELTERWEIGHT("welterweight"),
    MIDDLEWEIGHT("middleweight"),
    HEAVYWEIGHT("heavyweight"),
    SUPER_HEAVYWEIGHT("super_heavyweight"),
    ULTRA_HEAVYWEIGHT("ultra_heavyweight"),
    UNKNOWN("unknown");

    companion object {
        /**
         * Classify a wager (in integer cents) into its championship division.
         * Uses integer comparisons only — never floating point.
         */
        fun fromWagerCents(wagerCents: Long): ChampionshipDivision = when {
            wagerCents < 100L -> UNKNOWN
            wagerCents <= 10_000L -> LIGHTWEIGHT
            wagerCents <= 50_000L -> WELTERWEIGHT
            wagerCents <= 100_000L -> MIDDLEWEIGHT
            wagerCents <= 500_000L -> HEAVYWEIGHT
            wagerCents <= 1_000_000L -> SUPER_HEAVYWEIGHT
            else -> ULTRA_HEAVYWEIGHT
        }

        /** Parse a raw Firestore division string into a [ChampionshipDivision]. */
        fun fromRaw(raw: String?): ChampionshipDivision =
            entries.firstOrNull { it.raw == raw?.lowercase() } ?: UNKNOWN
    }
}

/**
 * VS Match domain model — mirrors the Firestore `vsMatches/{matchId}` document.
 *
 * MONEY RULE: [wagerAmount] is stored and transmitted as **integer cents**
 * (never raw dollars / floating point). All wager funds flow through escrow
 * via Cloud Functions; the client never writes money fields directly.
 *
 * The platform fee is 10%, so the winner payout is `wagerAmount * 2 * 0.9`,
 * computed server-side. Use [payoutCents] for the authoritative payout value.
 */
data class VSMatch(
    val id: String = "",
    val challengerId: String = "",
    val challengerName: String = "",
    val opponentId: String? = null,
    val opponentName: String? = null,
    val wagerAmount: Long = 0L,         // integer cents
    val division: String = "",          // "lightweight" | "welterweight" | ...
    val status: String = "open",        // "open" | "active" | "completed" | "cancelled"
    val winnerId: String? = null,
    val escrowId: String = "",
    val payoutCents: Long = 0L,         // authoritative payout (set by Cloud Function)
    val createdAt: Timestamp = Timestamp(0, 0)
) {
    /** The championship belt division derived from the wager tier. */
    val championshipDivision: ChampionshipDivision
        get() = ChampionshipDivision.fromWagerCents(wagerAmount)
}
