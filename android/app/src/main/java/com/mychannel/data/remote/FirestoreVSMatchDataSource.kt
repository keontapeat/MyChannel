package com.mychannel.data.remote

import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import com.google.firebase.functions.FirebaseFunctions
import com.mychannel.domain.model.VSMatch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Remote data source for VS Match real-money competitions.
 *
 * MONEY/COMPLIANCE RULE:
 * - Reads are real-time Firestore listeners (clients may READ match docs).
 * - WRITES (create/accept) go ONLY through Cloud Function callables, which
 *   perform server-side compliance checks (age, KYC, region, daily limits)
 *   and lock escrow atomically. The client never writes money fields directly.
 * - All wager amounts are integer cents.
 */
@Singleton
class FirestoreVSMatchDataSource @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val functions: FirebaseFunctions
) {

    private fun matches() = firestore.collection(VS_MATCHES)

    fun observeOpenMatches(): Flow<List<VSMatch>> = callbackFlow {
        val registration = matches()
            .whereEqualTo("status", "open")
            .orderBy("createdAt", Query.Direction.DESCENDING)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    close(error)
                    return@addSnapshotListener
                }
                trySend(snapshot.toMatches())
            }
        awaitClose { registration.remove() }
    }

    fun observeMyMatches(userId: String): Flow<List<VSMatch>> = callbackFlow {
        val registration = matches()
            .whereEqualTo("challengerId", userId)
            .orderBy("createdAt", Query.Direction.DESCENDING)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    close(error)
                    return@addSnapshotListener
                }
                trySend(snapshot.toMatches())
            }
        awaitClose { registration.remove() }
    }

    fun observeMatch(matchId: String): Flow<VSMatch?> = callbackFlow {
        val registration = matches().document(matchId)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    close(error)
                    return@addSnapshotListener
                }
                trySend(snapshot?.toObject(VSMatch::class.java)?.copy(id = snapshot.id))
            }
        awaitClose { registration.remove() }
    }

    /**
     * Creates a VS Match through the `createVSMatch` Cloud Function callable.
     * @param wagerCents wager in integer cents (never floating point).
     * @return the created match id returned by the server.
     */
    suspend fun createMatch(wagerCents: Long, division: String): String =
        withContext(Dispatchers.IO) {
            val payload = hashMapOf(
                "wagerCents" to wagerCents,
                "division" to division
            )
            val result = functions.getHttpsCallable(FN_CREATE_MATCH)
                .call(payload)
                .await()
            @Suppress("UNCHECKED_CAST")
            val data = result.data as? Map<String, Any?>
            (data?.get("matchId") as? String)
                ?: throw IllegalStateException("createVSMatch did not return a matchId")
        }

    /** Accepts an open challenge through the `acceptVSMatch` Cloud Function callable. */
    suspend fun acceptMatch(matchId: String): Unit = withContext(Dispatchers.IO) {
        val payload = hashMapOf("matchId" to matchId)
        functions.getHttpsCallable(FN_ACCEPT_MATCH).call(payload).await()
    }

    private fun com.google.firebase.firestore.QuerySnapshot?.toMatches(): List<VSMatch> =
        this?.documents?.mapNotNull { doc ->
            doc.toObject(VSMatch::class.java)?.copy(id = doc.id)
        } ?: emptyList()

    private companion object {
        const val VS_MATCHES = "vsMatches"
        const val FN_CREATE_MATCH = "createVSMatch"
        const val FN_ACCEPT_MATCH = "acceptVSMatch"
    }
}
