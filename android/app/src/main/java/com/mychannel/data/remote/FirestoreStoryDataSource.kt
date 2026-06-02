package com.mychannel.data.remote

import com.google.firebase.Timestamp
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import com.mychannel.domain.model.Story
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Remote data source for ephemeral creator stories (REQ-4.2).
 *
 * Real-time stories feed uses [callbackFlow] wrapping a Firestore snapshot
 * listener. Only non-expired stories are surfaced; expiry is filtered
 * client-side against the document's `expiresAt` field.
 */
@Singleton
class FirestoreStoryDataSource @Inject constructor(
    private val firestore: FirebaseFirestore
) {

    private fun stories() = firestore.collection(STORIES)

    /** Real-time feed of active (non-expired) stories, newest-first. */
    fun observeActiveStories(limit: Long = 30): Flow<List<Story>> = callbackFlow {
        val registration = stories()
            .orderBy("createdAt", Query.Direction.DESCENDING)
            .limit(limit)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    close(error)
                    return@addSnapshotListener
                }
                val now = Timestamp.now()
                val active = snapshot?.documents
                    ?.mapNotNull { doc -> doc.toObject(Story::class.java)?.copy(id = doc.id) }
                    ?.filter { story -> story.expiresAt > now || story.isLive }
                    ?: emptyList()
                trySend(active)
            }
        awaitClose { registration.remove() }
    }

    private companion object {
        const val STORIES = "stories"
    }
}
