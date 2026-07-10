package com.mychannel.util

import kotlin.math.roundToInt

/**
 * Pure money arithmetic in integer cents — mirrors iOS `MoneyMath.swift`.
 * Always round to nearest cent; never truncate (19.99 → 1999, not 1998).
 *
 * @see docs/android-money-parity.md (phase-487)
 */
object MoneyMath {
    const val PLATFORM_FEE_PERCENT: Double = WagerPolicy.PLATFORM_FEE_PERCENT

    fun centsFromDollars(dollars: Double): Int =
        (dollars * 100.0).roundToInt()

    fun dollarsFromCents(cents: Int): Double =
        cents / 100.0

    fun platformFeeCents(
        grossCents: Int,
        feePercent: Double = PLATFORM_FEE_PERCENT
    ): Int =
        (grossCents * feePercent).roundToInt()

    fun winnerPayoutCents(
        grossCents: Int,
        feePercent: Double = PLATFORM_FEE_PERCENT
    ): Int =
        maxOf(0, grossCents - platformFeeCents(grossCents, feePercent))
}
