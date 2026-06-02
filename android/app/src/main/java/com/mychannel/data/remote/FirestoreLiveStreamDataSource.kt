package com.mychannel.data.remote

import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import com.mychannel.domain.model.LiveStream
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Remote data source for live stream documents (REQ-4.4, REQ-12.x).
 *
 * Real-time "Live Now" feed uses [callbackFlow] wrapping a Firestore snapshot
 * listener, consistent with Task 2's realtime pattern.
 */
@Singleton
class FirestoreLiveStreamDataSource @Inject constructor(
    private val firestore: FirebaseFirestore
) {

    private fun liveStreams() = firestore.collection(LIVE_STREAMS)

    /** Real-time feed of currently-live streams, ordered by viewer count. */
    fun observeLiveNow(limit: Long = 20): Flow<List<LiveStream>> = callbackFlow {
        val registration = liveStreams()
            .whereEqualTo("status", "live")
            .orderBy("viewerCount", Query.Direction.DESCENDING)
            .limit(limit)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    close(error)
                    return@addSnapshotListener
                }
                val streams = snapshot?.documents?.mapNotNull { doc ->
                    doc.toObject(LiveStream::class.java)?.copy(id = doc.id)
                } ?: emptyList()
                trySend(streams)
            }
        awaitClose { registration.remove() }
    }

    private companion object {
        const val LIVE_STREAMS = "liveStreams"
    }
}
