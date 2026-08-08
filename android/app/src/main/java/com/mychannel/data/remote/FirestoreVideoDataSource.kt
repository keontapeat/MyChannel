package com.mychannel.data.remote

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import com.mychannel.domain.model.Comment
import com.mychannel.domain.model.Video
import java.util.UUID
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
            .whereEqualTo("processingStatus", "ready")
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
     * ready, long-form videos ordered newest-first). Used by
     * [FirestoreVideoPagingSource] for cursor-based infinite scroll (REQ-4.5).
     */
    fun recommendedQuery(): Query =
        videos()
            .whereEqualTo("isShort", false)
            .whereEqualTo("privacyStatus", "public")
            .whereEqualTo("processingStatus", "ready")
            .orderBy("uploadedAt", Query.Direction.DESCENDING)

    /**
     * Builds the recommended feed query constrained to a single category, used
     * when a Home filter chip other than "All" / "Live" / "Shorts" is selected.
     */
    fun recommendedQueryForCategory(category: String): Query =
        videos()
            .whereEqualTo("isShort", false)
            .whereEqualTo("privacyStatus", "public")
            .whereEqualTo("processingStatus", "ready")
            .whereEqualTo("category", category)
            .orderBy("uploadedAt", Query.Direction.DESCENDING)

    fun observeShorts(limit: Long = 50): Flow<List<Video>> = callbackFlow {
        val registration = videos()
            .whereEqualTo("isShort", true)
            .whereEqualTo("privacyStatus", "public")
            .whereEqualTo("processingStatus", "ready")
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
                val comments = snapshot?.documents?.mapNotNull { document ->
                    document.toComment(videoId)
                } ?: emptyList()
                trySend(comments)
            }
        awaitClose { registration.remove() }
    }

    suspend fun postComment(videoId: String, text: String, parentId: String?): Comment =
        withContext(Dispatchers.IO) {
            val user = auth.currentUser ?: throw IllegalStateException("Sign in required")
            val normalizedText = text.trim()
            require(normalizedText.isNotEmpty() && normalizedText.length <= MAX_COMMENT_LENGTH) {
                "Comment must be between 1 and $MAX_COMMENT_LENGTH characters"
            }

            val videoRef = videos().document(videoId)
            val commentRef = videoRef.collection(COMMENTS).document()
            val eventRef = videoRef.collection(EVENTS).document(UUID.randomUUID().toString())
            val comment = hashMapOf(
                "userId" to user.uid,
                "displayName" to (user.displayName ?: "Creator"),
                "avatarURL" to (user.photoUrl?.toString() ?: ""),
                "text" to normalizedText,
                "likeCount" to 0L,
                "replyCount" to 0L,
                "isPinned" to false,
                "creatorHearted" to false,
                "parentCommentId" to parentId,
                "createdAt" to FieldValue.serverTimestamp()
            )
            val event = engagementEvent(
                userId = user.uid,
                type = "comment",
                sessionId = commentRef.id
            )
            firestore.batch().apply {
                set(commentRef, comment)
                set(eventRef, event)
            }.commit().await()

            commentRef.get().await().toComment(videoId)
                ?: Comment(
                    id = commentRef.id,
                    videoId = videoId,
                    userId = user.uid,
                    username = user.displayName ?: "Creator",
                    avatarUrl = user.photoUrl?.toString() ?: "",
                    text = normalizedText,
                    parentId = parentId
                )
        }

    /** Records an immutable semantic reaction transition for server aggregation. */
    suspend fun adjustLikeCount(videoId: String, like: Boolean): Unit =
        withContext(Dispatchers.IO) {
            val userId = uid() ?: throw IllegalStateException("Sign in required")
            recordEngagementEvent(videoId, userId, if (like) "like" else "unlike")
        }

    suspend fun incrementViewCount(videoId: String): Unit = withContext(Dispatchers.IO) {
        val userId = uid() ?: return@withContext
        recordEngagementEvent(videoId, userId, "view")
    }

    // ── Per-user reaction state ────────────────────────────────────────────

    suspend fun isLiked(videoId: String): Boolean = reactionValue(videoId) == "like"

    suspend fun isDisliked(videoId: String): Boolean = reactionValue(videoId) == "dislike"

    suspend fun setLike(videoId: String, like: Boolean): Unit =
        setReaction(videoId, "like", like)

    suspend fun setDislike(videoId: String, dislike: Boolean): Unit =
        setReaction(videoId, "dislike", dislike)

    private suspend fun reactionValue(videoId: String): String? = withContext(Dispatchers.IO) {
        val userId = uid() ?: return@withContext null
        firestore.collection("users").document(userId)
            .collection("videoLikes").document(videoId).get().await().getString("value")
    }

    /**
     * Stores one private reaction marker and immutable semantic transition events
     * atomically. Re-reading the marker makes successful retries idempotent.
     */
    private suspend fun setReaction(
        videoId: String,
        target: String,
        enabled: Boolean
    ): Unit = withContext(Dispatchers.IO) {
        require(target == "like" || target == "dislike")
        val userId = uid() ?: throw IllegalStateException("Sign in required")
        val markerRef = firestore.collection("users").document(userId)
            .collection("videoLikes").document(videoId)
        val previous = markerRef.get().await().getString("value")
        val next = when {
            enabled -> target
            previous == target -> null
            else -> return@withContext
        }
        if (previous == next) return@withContext

        val transitions = buildList {
            if (previous == "like") add("unlike")
            if (previous == "dislike") add("undislike")
            if (next != null) add(next)
        }
        val batch = firestore.batch()
        if (next == null) {
            batch.delete(markerRef)
        } else {
            batch.set(
                markerRef,
                mapOf(
                    "value" to next,
                    "videoId" to videoId,
                    "updatedAt" to FieldValue.serverTimestamp()
                )
            )
        }
        transitions.forEach { type ->
            val eventId = UUID.randomUUID().toString()
            val eventRef = videos().document(videoId).collection(EVENTS).document(eventId)
            batch.set(eventRef, engagementEvent(userId, type, eventId))
        }
        batch.commit().await()
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

    private suspend fun recordEngagementEvent(
        videoId: String,
        userId: String,
        type: String
    ) {
        val sessionId = UUID.randomUUID().toString()
        videos().document(videoId).collection(EVENTS)
            .document(UUID.randomUUID().toString())
            .set(engagementEvent(userId, type, sessionId))
            .await()
    }

    private fun engagementEvent(
        userId: String,
        type: String,
        sessionId: String
    ): Map<String, Any> = mapOf(
        "userId" to userId,
        "type" to type,
        "sessionId" to sessionId,
        "createdAt" to FieldValue.serverTimestamp()
    )

    private fun DocumentSnapshot.toComment(videoId: String): Comment? {
        if (!exists()) return null
        val commentText = getString("text") ?: return null
        return Comment(
            id = id,
            videoId = videoId,
            userId = getString("userId").orEmpty(),
            username = getString("displayName") ?: getString("username").orEmpty(),
            avatarUrl = getString("avatarURL") ?: getString("avatarUrl").orEmpty(),
            text = commentText,
            likeCount = getLong("likeCount") ?: 0L,
            replyCount = getLong("replyCount") ?: 0L,
            parentId = getString("parentCommentId") ?: getString("parentId"),
            createdAt = getTimestamp("createdAt") ?: com.google.firebase.Timestamp(0, 0)
        )
    }

    private fun com.google.firebase.firestore.QuerySnapshot?.toVideos(): List<Video> =
        this?.documents?.mapNotNull { doc ->
            doc.toObject(Video::class.java)?.copy(id = doc.id)
        } ?: emptyList()

    private companion object {
        const val VIDEOS = "videos"
        const val COMMENTS = "comments"
        const val EVENTS = "events"
        const val MAX_COMMENT_LENGTH = 10_000
    }
}
