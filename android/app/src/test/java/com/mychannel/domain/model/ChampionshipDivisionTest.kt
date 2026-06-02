package com.mychannel.domain.model

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Unit tests for the money-critical [ChampionshipDivision] classification.
 *
 * MONEY RULE: all wager amounts are integer cents. These tests assert the
 * boundary mapping from the compliance steering (Lightweight through Ultra
 * Heavyweight) using integer cents only — never floating point dollars.
 */
class ChampionshipDivisionTest {

    @Test
    fun `below one dollar is unknown`() {
        assertThat(ChampionshipDivision.fromWagerCents(0L))
            .isEqualTo(ChampionshipDivision.UNKNOWN)
        assertThat(ChampionshipDivision.fromWagerCents(99L))
            .isEqualTo(ChampionshipDivision.UNKNOWN)
    }

    @Test
    fun `lightweight covers one dollar through one hundred dollars`() {
        // $1 = 100 cents, $100 = 10_000 cents
        assertThat(ChampionshipDivision.fromWagerCents(100L))
            .isEqualTo(ChampionshipDivision.LIGHTWEIGHT)
        assertThat(ChampionshipDivision.fromWagerCents(10_000L))
            .isEqualTo(ChampionshipDivision.LIGHTWEIGHT)
    }

    @Test
    fun `welterweight covers just over one hundred through five hundred dollars`() {
        assertThat(ChampionshipDivision.fromWagerCents(10_001L))
            .isEqualTo(ChampionshipDivision.WELTERWEIGHT)
        assertThat(ChampionshipDivision.fromWagerCents(50_000L))
            .isEqualTo(ChampionshipDivision.WELTERWEIGHT)
    }

    @Test
    fun `middleweight covers just over five hundred through one thousand dollars`() {
        assertThat(ChampionshipDivision.fromWagerCents(50_001L))
            .isEqualTo(ChampionshipDivision.MIDDLEWEIGHT)
        assertThat(ChampionshipDivision.fromWagerCents(100_000L))
            .isEqualTo(ChampionshipDivision.MIDDLEWEIGHT)
    }

    @Test
    fun `heavyweight covers just over one thousand through five thousand dollars`() {
        assertThat(ChampionshipDivision.fromWagerCents(100_001L))
            .isEqualTo(ChampionshipDivision.HEAVYWEIGHT)
        assertThat(ChampionshipDivision.fromWagerCents(500_000L))
            .isEqualTo(ChampionshipDivision.HEAVYWEIGHT)
    }

    @Test
    fun `super heavyweight covers just over five thousand through ten thousand dollars`() {
        assertThat(ChampionshipDivision.fromWagerCents(500_001L))
            .isEqualTo(ChampionshipDivision.SUPER_HEAVYWEIGHT)
        assertThat(ChampionshipDivision.fromWagerCents(1_000_000L))
            .isEqualTo(ChampionshipDivision.SUPER_HEAVYWEIGHT)
    }

    @Test
    fun `ultra heavyweight covers above ten thousand dollars`() {
        assertThat(ChampionshipDivision.fromWagerCents(1_000_001L))
            .isEqualTo(ChampionshipDivision.ULTRA_HEAVYWEIGHT)
        assertThat(ChampionshipDivision.fromWagerCents(50_000_000L))
            .isEqualTo(ChampionshipDivision.ULTRA_HEAVYWEIGHT)
    }

    @Test
    fun `vsmatch derives division from its wager amount`() {
        val match = VSMatch(wagerAmount = 250_000L) // $2,500
        assertThat(match.championshipDivision).isEqualTo(ChampionshipDivision.HEAVYWEIGHT)
    }

    @Test
    fun `fromRaw parses known division strings and defaults to unknown`() {
        assertThat(ChampionshipDivision.fromRaw("lightweight"))
            .isEqualTo(ChampionshipDivision.LIGHTWEIGHT)
        assertThat(ChampionshipDivision.fromRaw("ULTRA_HEAVYWEIGHT"))
            .isEqualTo(ChampionshipDivision.ULTRA_HEAVYWEIGHT)
        assertThat(ChampionshipDivision.fromRaw("nonsense"))
            .isEqualTo(ChampionshipDivision.UNKNOWN)
        assertThat(ChampionshipDivision.fromRaw(null))
            .isEqualTo(ChampionshipDivision.UNKNOWN)
    }
}
