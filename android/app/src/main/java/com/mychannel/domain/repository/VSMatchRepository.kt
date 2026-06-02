package com.mychannel.domain.repository

import com.mychannel.domain.model.VSMatch
import kotlinx.coroutines.flow.Flow

/**
 * Repository for VS Match real-money competitions (REQ-13.x).
 *
 * MONEY/COMPLIANCE RULE: match creation and acceptance are NEVER direct
 * Firestore writes from the client. They are routed through the
 * `createVSMatch` Cloud Function callable, which performs all server-side
 * compliance checks (age 18+, KYC for wagers >= $500, terms, region, daily
 * limits) and locks escrow atomically. All wager amounts are integer cents.
 */
interface VSMatchRepository {

    /** Real-time list of open challenges. */
    fun observeOpenMatches(): Flow<List<VSMatch>>

    /** Real-time list of the current user's matches (any status). */
    fun observeMyMatches(): Flow<List<VSMatch>>

    /** Real-time updates for a single match (status, winner, payout). */
    fun observeMatch(matchId: String): Flow<VSMatch?>

    /**
     * Create a VS Match via the Cloud Function callable.
     * @param wagerCents the wager in integer cents (never floating point).
     * @return the created match id.
     */
    suspend fun createMatch(wagerCents: Long, division: String): Result<String>

    /** Accept an open challenge via the Cloud Function callable. */
    suspend fun acceptMatch(matchId: String): Result<Unit>
}
