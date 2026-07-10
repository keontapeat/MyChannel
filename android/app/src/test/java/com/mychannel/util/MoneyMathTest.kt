package com.mychannel.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

/**
 * Android MoneyMath unit tests — mirrors iOS MoneyMathTests / MoneyMathGoldenTests.
 */
class MoneyMathTest {

    @Test
    fun centsFromDollars_roundsNotTruncates() {
        assertEquals(1999, MoneyMath.centsFromDollars(19.99))
        assertNotEquals(1998, MoneyMath.centsFromDollars(19.99))
    }

    @Test
    fun twoSidedPot_feeAndPayout() {
        val pot = MoneyMath.centsFromDollars(50.0) * 2
        assertEquals(10_000, pot)
        assertEquals(1_000, MoneyMath.platformFeeCents(pot))
        assertEquals(9_000, MoneyMath.winnerPayoutCents(pot))
        assertEquals(pot, MoneyMath.platformFeeCents(pot) + MoneyMath.winnerPayoutCents(pot))
    }

    @Test
    fun goldenTable_knownValues() {
        val rows = listOf(
            Triple(1.0, 200, 180),
            Triple(19.99, 3998, 3598),
            Triple(50.0, 10_000, 9_000)
        )
        for ((dollars, expectedPot, expectedPayout) in rows) {
            val pot = MoneyMath.centsFromDollars(dollars) * 2
            assertEquals(expectedPot, pot)
            assertEquals(expectedPayout, MoneyMath.winnerPayoutCents(pot))
        }
    }
}
