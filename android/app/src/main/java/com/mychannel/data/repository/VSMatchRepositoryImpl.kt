package com.mychannel.data.repository

import com.mychannel.data.remote.FirebaseAuthDataSource
import com.mychannel.data.remote.FirestoreVSMatchDataSource
import com.mychannel.domain.model.VSMatch
import com.mychannel.domain.repository.VSMatchRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import javax.inject.Inject
import javax.inject.Singleton

/**
 * [VSMatchRepository] backed by [FirestoreVSMatchDataSource].
 *
 * MONEY/COMPLIANCE RULE: create/accept are delegated to Cloud Function
 * callables in the data source — never direct Firestore writes. All wager
 * amounts are integer cents.
 */
@Singleton
class VSMatchRepositoryImpl @Inject constructor(
    private val vsMatchDataSource: FirestoreVSMatchDataSource,
    private val authDataSource: FirebaseAuthDataSource
) : VSMatchRepository {

    override fun observeOpenMatches(): Flow<List<VSMatch>> =
        vsMatchDataSource.observeOpenMatches()

    override fun observeMyMatches(): Flow<List<VSMatch>> {
        val uid = authDataSource.currentUserId ?: return flowOf(emptyList())
        return vsMatchDataSource.observeMyMatches(uid)
    }

    override fun observeMatch(matchId: String): Flow<VSMatch?> =
        vsMatchDataSource.observeMatch(matchId)

    override suspend fun createMatch(wagerCents: Long, division: String): Result<String> =
        runCatching {
            require(wagerCents > 0L) { "wagerCents must be positive integer cents" }
            vsMatchDataSource.createMatch(wagerCents, division)
        }

    override suspend fun acceptMatch(matchId: String): Result<Unit> = runCatching {
        vsMatchDataSource.acceptMatch(matchId)
    }
}
