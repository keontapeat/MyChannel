package com.mychannel.data.remote

import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import com.mychannel.domain.model.Channel
import com.mychannel.domain.model.Video
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Remote data source for search queries (REQ-6.1, REQ-6.3).
 *
 * Uses Firestore prefix-range queries on lowercase title/name fields. All
 * reads run on [Dispatchers.IO]. (A production deployment would front this with
 * a dedicated search index such as Algolia/Typesense; the Firestore prefix
 * query is the on-platform baseline.)
 */
@Singleton
class FirestoreSearchDataSource @Inject constructor(
    private val firestore: FirebaseFirestore
) {

    suspend fun searchVideos(query: String, limit: Long = 30): List<Video> =
        withContext(Dispatchers.IO) {
            val normalized = query.trim()
            if (normalized.isEmpty()) return@withContext emptyList()
            firestore.collection(VIDEOS)
                .whereEqualTo("privacyStatus", "public")
                .orderBy("title")
                .startAt(normalized)
                .endAt(normalized + PREFIX_TERMINATOR)
                .limit(limit)
                .get().await()
                .documents.mapNotNull { doc ->
                    doc.toObject(Video::class.java)?.copy(id = doc.id)
                }
        }

    suspend fun searchChannels(query: String, limit: Long = 30): List<Channel> =
        withContext(Dispatchers.IO) {
            val normalized = query.trim()
            if (normalized.isEmpty()) return@withContext emptyList()
            firestore.collection(CHANNELS)
                .orderBy("name")
                .startAt(normalized)
                .endAt(normalized + PREFIX_TERMINATOR)
                .limit(limit)
                .get().await()
                .documents.mapNotNull { doc ->
                    doc.toObject(Channel::class.java)?.copy(id = doc.id)
                }
        }

    suspend fun getTrendingSearches(limit: Long = 10): List<String> =
        withContext(Dispatchers.IO) {
            firestore.collection(TRENDING_SEARCHES)
                .orderBy("count", Query.Direction.DESCENDING)
                .limit(limit)
                .get().await()
                .documents.mapNotNull { it.getString("term") }
        }

    private companion object {
        const val VIDEOS = "videos"
        const val CHANNELS = "channels"
        const val TRENDING_SEARCHES = "trendingSearches"
        // High code point to bound a Firestore prefix range query.
        const val PREFIX_TERMINATOR = "\uf8ff"
    }
}
