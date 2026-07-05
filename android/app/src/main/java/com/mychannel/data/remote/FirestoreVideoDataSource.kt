package com.mychannel.data.remote

import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import com.google.firebase.auth.FirebaseAuth
import com.mychannel.domain.model.Comment
import com.mychannel.domain.model.Video
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Remote data source for video documents and their comments subcollection.
 *
 * - Real-time feeds use [callbackFlow] wrapping Firestore snapshot listeners.
 * - One-shot reads/writes run on [Dispatchers.IO].
 */
@Singleton
class FirestoreVideoDataSource @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val auth: FirebaseAuth
) {

    private fun videos() = firestore.collection(VIDEOS)

    private fun uid(): String? = auth.currentUser?.uid

    fun observeTrending(limit: Long = 50): Flow<List<Video>> = callbackFlow {
        val registration = videos()
            .whereEqualTo("isShort", false)
            .whereEqualTo("privacyStatus", "public")
            .orderBy("viewCount", Query.Direction.DESCENDING)
            .limit(limit)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    close(error)
                    return@addSnapshotListener
                }
                trySend(snapshot.toVideos())
            }
        awaitClose { registration.remove() }
    }

    /**
     * Builds the base Firestore query for the recommended feed (public,
     * long-form videos ordered newest-first). Used by [FirestoreVideoPagingSource]
     * for cursor-based infinite scroll (REQ-4.5).
     */
    fun recommendedQuery(): Query =
        videos()
            .whereEqualTo("isShort", false)
            .whereEqualTo("privacyStatus", "public")
            .orderBy("uploadedAt", Query.Direction.DESCENDING)

    /**
     * Builds the recommended feed query constrained to a single category, used
     * when a Home filter chip other than "All" / "Live" / "Shorts" is selected.
     */
    fun recommendedQueryForCategory(category: String): Query =
        videos()
            .whereEqualTo("isShort", false)
            .whereEqualTo("privacyStatus", "public")
            .whereEqualTo("category", category)
            .orderBy("uploadedAt", Query.Direction.DESCENDING)

    fun observeShorts(limit: Long = 50): Flow<List<Video>> = callbackFlow {
        val registration = videos()
            .whereEqualTo("isShort", true)
            .whereEqualTo("privacyStatus", "public")
            .orderBy("uploadedAt", Query.Direction.DESCENDING)
            .limit(limit)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    close(error)
                    return@addSnapshotListener
                }
                trySend(snapshot.toVideos())
            }
        awaitClose { registration.remove() }
    }

    fun observeChannelVideos(channelId: String): Flow<List<Video>> = callbackFlow {
        val registration = videos()
            .whereEqualTo("channelId", channelId)
            .orderBy("uploadedAt", Query.Direction.DESCENDING)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    close(error)
                    return@addSnapshotListener
                }
                trySend(snapshot.toVideos())
            }
        awaitClose { registration.remove() }
    }

    suspend fun getVideo(videoId: String): Video = withContext(Dispatchers.IO) {
        val snapshot = videos().document(videoId).get().await()
        snapshot.toObject(Video::class.java)?.copy(id = snapshot.id)
            ?: throw NoSuchElementException("Video not found: $videoId")
    }

    fun observeComments(videoId: String, limit: Long = 100): Flow<List<Comment>> = callbackFlow {
        val registration = videos().document(videoId).collection(COMMENTS)
            .orderBy("createdAt", Query.Direction.DESCENDING)
            .limit(limit)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    close(error)
                    return@addSnapshotListener
                }
                val comments = snapshot?.documents?.mapNotNull { doc ->
                    doc.toObject(Comment::class.java)?.copy(id = doc.id, videoId = videoId)
                } ?: emptyList()
                trySend(comments)
            }
        awaitClose { registration.remove() }
    }

    suspend fun postComment(videoId: String, text: String, parentId: String?): Comment =
        withContext(Dispatchers.IO) {
            val docRef = videos().document(videoId).collection(COMMENTS).document()
            val data = hashMapOf(
                "text" to text,
                "parentId" to parentId,
                "likeCount" to 0L,
                "replyCount" to 0L,
                "createdAt" to com.google.firebase.firestore.FieldValue.serverTimestamp()
            )
            docRef.set(data).await()
            val saved = docRef.get().await()
            saved.toObject(Comment::class.java)?.copy(id = saved.id, videoId = videoId)
                ?: Comment(id = docRef.id, videoId = videoId, text = text, parentId = parentId)
        }

    /**
     * Atomically adjusts the like count for a video. The boolean toggles the
     * direction; per-user like state is enforced by Cloud Functions / Rules.
     */
    suspend fun adjustLikeCount(videoId: String, like: Boolean): Unit =
        withContext(Dispatchers.IO) {
            val delta = if (like) 1L else -1L
            videos().document(videoId)
                .update("likeCount", com.google.firebase.firestore.FieldValue.increment(delta))
                .await()
        }

    suspend fun incrementViewCount(videoId: String): Unit = withContext(Dispatchers.IO) {
        videos().document(videoId)
            .update("viewCount", com.google.firebase.firestore.FieldValue.increment(1L))
            .await()
    }

    // ── Per-user like state ────────────────────────────────────────────────

    /** Whether the current user has liked [videoId]. */
    suspend fun isLiked(videoId: String): Boolean = withContext(Dispatchers.IO) {
        val u = uid() ?: return@withContext false
        val doc = firestore.collection("users").document(u)
            .collection("videoLikes").document(videoId).get().await()
        doc.exists() && doc.getString("value") == "like"
    }

    /**
     * Persists the current user's like for [videoId] and adjusts the aggregate
     * count only on an actual state change (idempotent — guards double-counting).
     */
    suspend fun setLike(videoId: String, like: Boolean): Unit = withContext(Dispatchers.IO) {
        val u = uid()
        if (u == null) {
            // Signed-out: best-effort count only
            adjustLikeCount(videoId, like)
            return@withContext
        }
        val ref = firestore.collection("users").document(u)
            .collection("videoLikes").document(videoId)
        val existing = ref.get().await()
        val already = existing.exists() && existing.getString("value") == "like"
        if (like && !already) {
            ref.set(
                mapOf(
                    "value" to "like",
                    "videoId" to videoId,
                    "createdAt" to com.google.firebase.firestore.FieldValue.serverTimestamp()
                )
            ).await()
            adjustLikeCount(videoId, true)
        } else if (!like && already) {
            ref.delete().await()
            adjustLikeCount(videoId, false)
        }
    }

    // ── Watch Later (save) ──────────────────────────────────────────────────

    /** Whether [videoId] is in the current user's Watch Later. */
    suspend fun isSaved(videoId: String): Boolean = withContext(Dispatchers.IO) {
        val u = uid() ?: return@withContext false
        firestore.collection("users").document(u)
            .collection("watchLater").document(videoId).get().await().exists()
    }

    /** Add or remove [video] from the current user's Watch Later. */
    suspend fun setSaved(video: Video, save: Boolean): Unit = withContext(Dispatchers.IO) {
        val u = uid() ?: return@withContext
        val ref = firestore.collection("users").document(u)
            .collection("watchLater").document(video.id)
        if (save) {
            ref.set(
                mapOf(
                    "videoId" to video.id,
                    "title" to video.title,
                    "thumbnailUrl" to video.thumbnailUrl,
                    "addedAt" to com.google.firebase.firestore.FieldValue.serverTimestamp()
                )
            ).await()
        } else {
            ref.delete().await()
        }
    }

    // ── Downloads (offline) ──────────────────────────────────────────────────

    /**
     * Real-time list of the user's downloaded video IDs from Firestore, joined
     * against the videos collection. Downloads are stored as
     * users/{uid}/downloads/{videoId} with a `videoId` field.
     */
    fun observeDownloads(userId: String): Flow<List<Video>> = callbackFlow {
        val ref = firestore.collection("users").document(userId).collection("downloads")
        val registration = ref.addSnapshotListener { snapshot, error ->
            if (error != null) { close(error); return@addSnapshotListener }
            val videoIds = snapshot?.documents?.mapNotNull { it.getString("videoId") } ?: emptyList()
            if (videoIds.isEmpty()) { trySend(emptyList()); return@addSnapshotListener }
            // Batch-fetch video docs (max 20 at a time, Firestore IN limit)
            CoroutineScope(Dispatchers.IO).launch {
                runCatching {
                    videoIds.chunked(10).flatMap { chunk ->
                        firestore.collection("videos")
                            .whereIn("__name__", chunk)
                            .get().await().documents
                            .mapNotNull { doc -> doc.toObject(Video::class.java)?.copy(id = doc.id) }
                    }
                }.onSuccess { trySend(it) }.onFailure { close(it as? Exception) }
            }
        }
        awaitClose { registration.remove() }
    }

    suspend fun deleteDownload(userId: String, videoId: String): Unit = withContext(Dispatchers.IO) {
        firestore.collection("users").document(userId)
            .collection("downloads").document(videoId)
            .delete().await()
    }

    private fun com.google.firebase.firestore.QuerySnapshot?.toVideos(): List<Video> =
        this?.documents?.mapNotNull { doc ->
            doc.toObject(Video::class.java)?.copy(id = doc.id)
        } ?: emptyList()

    private companion object {
        const val VIDEOS = "videos"
        const val COMMENTS = "comments"
    }
}
