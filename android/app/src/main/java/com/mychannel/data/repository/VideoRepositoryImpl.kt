package com.mychannel.data.repository

import androidx.paging.Pager
import androidx.paging.PagingConfig
import androidx.paging.PagingData
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import com.mychannel.data.local.dao.VideoDao
import com.mychannel.data.local.entity.toEntity
import com.mychannel.data.remote.FirestoreLiveStreamDataSource
import com.mychannel.data.remote.FirestoreStoryDataSource
import com.mychannel.data.remote.FirestoreVideoDataSource
import com.mychannel.data.remote.FirestoreVideoPagingSource
import com.mychannel.domain.model.Comment
import com.mychannel.domain.model.EndScreenElement
import com.mychannel.domain.model.LiveStream
import com.mychannel.domain.model.Playlist
import com.mychannel.domain.model.Story
import com.mychannel.domain.model.StoryGroup
import com.mychannel.domain.model.Video
import com.mychannel.domain.repository.VideoRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

/**
 * [VideoRepository] backed by [FirestoreVideoDataSource] with Room caching.
 *
 * Real-time feeds are streamed from Firestore and written through to the
 * [VideoDao] cache for offline browsing (REQ-1.4). The recommended feed uses
 * Paging 3 with a Firestore cursor [FirestoreVideoPagingSource] (REQ-4.5).
 */
@Singleton
class VideoRepositoryImpl @Inject constructor(
    private val videoDataSource: FirestoreVideoDataSource,
    private val liveStreamDataSource: FirestoreLiveStreamDataSource,
    private val storyDataSource: FirestoreStoryDataSource,
    private val videoDao: VideoDao,
    private val firestore: FirebaseFirestore,
    private val recommendationApi: com.mychannel.data.remote.RecommendationApi
) : VideoRepository {

    override fun observeTrending(): Flow<List<Video>> =
        videoDataSource.observeTrending()
            .onEach { videos -> videoDao.upsertAll(videos.map { it.toEntity() }) }
            .flowOn(Dispatchers.IO)

    override fun recommendedFeed(category: String?): Flow<PagingData<Video>> =
        Pager(
            config = PagingConfig(
                pageSize = PAGE_SIZE,
                prefetchDistance = PREFETCH_DISTANCE,
                enablePlaceholders = false,
                initialLoadSize = PAGE_SIZE
            ),
            pagingSourceFactory = {
                val query = if (category.isNullOrBlank()) {
                    videoDataSource.recommendedQuery()
                } else {
                    videoDataSource.recommendedQueryForCategory(category)
                }
                FirestoreVideoPagingSource(query, PAGE_SIZE.toLong())
            }
        ).flow

    override fun observeLiveStreams(): Flow<List<LiveStream>> =
        liveStreamDataSource.observeLiveNow()
            .flowOn(Dispatchers.IO)

    override fun observeStories(): Flow<List<Story>> =
        storyDataSource.observeActiveStories()
            .flowOn(Dispatchers.IO)

    override fun observeChannelVideos(channelId: String): Flow<List<Video>> =
        videoDataSource.observeChannelVideos(channelId)
            .onEach { videos -> videoDao.upsertAll(videos.map { it.toEntity() }) }
            .flowOn(Dispatchers.IO)

    override fun observeShorts(): Flow<List<Video>> =
        videoDataSource.observeShorts()
            .onEach { videos -> videoDao.upsertAll(videos.map { it.toEntity() }) }
            .flowOn(Dispatchers.IO)

    override suspend fun getVideo(videoId: String): Result<Video> = runCatching {
        videoDataSource.getVideo(videoId).also { videoDao.upsert(it.toEntity()) }
    }

    override fun observeComments(videoId: String): Flow<List<Comment>> =
        videoDataSource.observeComments(videoId)

    override suspend fun postComment(
        videoId: String,
        text: String,
        parentId: String?
    ): Result<Comment> = runCatching {
        videoDataSource.postComment(videoId, text, parentId)
    }

    override suspend fun toggleLike(videoId: String, like: Boolean): Result<Unit> = runCatching {
        videoDataSource.setLike(videoId, like)
    }

    override suspend fun toggleDislike(videoId: String, dislike: Boolean): Result<Unit> = runCatching {
        videoDataSource.setDislike(videoId, dislike)
    }

    override suspend fun isLiked(videoId: String): Result<Boolean> = runCatching {
        videoDataSource.isLiked(videoId)
    }

    override suspend fun isDisliked(videoId: String): Result<Boolean> = runCatching {
        videoDataSource.isDisliked(videoId)
    }

    override suspend fun isSaved(videoId: String): Result<Boolean> = runCatching {
        videoDataSource.isSaved(videoId)
    }

    override suspend fun setSaved(video: Video, save: Boolean): Result<Unit> = runCatching {
        videoDataSource.setSaved(video, save)
    }

    override suspend fun incrementViewCount(videoId: String): Result<Unit> = runCatching {
        videoDataSource.incrementViewCount(videoId)
    }

    override fun observeDownloads(userId: String): Flow<List<Video>> =
        videoDataSource.observeDownloads(userId)
            .flowOn(Dispatchers.IO)

    override suspend fun deleteDownload(userId: String, videoId: String): Result<Unit> = runCatching {
        videoDataSource.deleteDownload(userId, videoId)
    }

    // ── Watch History ──────────────────────────────────────────────────────────

    override fun observeWatchHistory(userId: String): Flow<List<Video>> =
        videoDataSource.observeWatchHistory(userId).flowOn(Dispatchers.IO)

    override suspend fun removeFromWatchHistory(userId: String, videoId: String): Result<Unit> = runCatching {
        firestore.collection("users").document(userId)
            .collection("watchHistory").document(videoId)
            .delete().await()
    }

    override suspend fun clearWatchHistory(userId: String): Result<Unit> = runCatching {
        val docs = firestore.collection("users").document(userId)
            .collection("watchHistory").get().await()
        val batch = firestore.batch()
        docs.documents.forEach { batch.delete(it.reference) }
        batch.commit().await()
    }

    // ── Watch Later ────────────────────────────────────────────────────────────

    override fun observeWatchLater(userId: String): Flow<List<Video>> =
        videoDataSource.observeWatchLater(userId).flowOn(Dispatchers.IO)

    override suspend fun removeFromWatchLater(userId: String, videoId: String): Result<Unit> = runCatching {
        firestore.collection("users").document(userId)
            .collection("watchLater").document(videoId)
            .delete().await()
    }

    override suspend fun clearWatchLater(userId: String): Result<Unit> = runCatching {
        val docs = firestore.collection("users").document(userId)
            .collection("watchLater").get().await()
        val batch = firestore.batch()
        docs.documents.forEach { batch.delete(it.reference) }
        batch.commit().await()
    }

    // ── Playlists ──────────────────────────────────────────────────────────────

    override suspend fun fetchPlaylists(userId: String): List<Playlist> {
        val snap = firestore.collection("playlists")
            .whereEqualTo("ownerId", userId)
            .orderBy("createdAt", Query.Direction.DESCENDING)
            .get().await()
        return snap.documents.mapNotNull { it.toObject(Playlist::class.java)?.copy(id = it.id) }
    }

    override suspend fun fetchPlaylist(playlistId: String): Playlist? {
        val snap = firestore.collection("playlists").document(playlistId).get().await()
        return if (snap.exists()) snap.toObject(Playlist::class.java)?.copy(id = snap.id) else null
    }

    override suspend fun createPlaylist(userId: String, title: String): Result<Unit> = runCatching {
        firestore.collection("playlists").add(
            mapOf(
                "ownerId" to userId,
                "title" to title,
                "videoIds" to emptyList<String>(),
                "videoCount" to 0L,
                "privacyStatus" to "private",
                "createdAt" to FieldValue.serverTimestamp(),
                "updatedAt" to FieldValue.serverTimestamp()
            )
        ).await()
    }

    override suspend fun deletePlaylist(userId: String, playlistId: String): Result<Unit> = runCatching {
        firestore.collection("playlists").document(playlistId).delete().await()
    }

    override suspend fun fetchVideosByIds(videoIds: List<String>): List<Video> {
        if (videoIds.isEmpty()) return emptyList()
        // Firestore whereIn max 30 items — batch if needed
        val results = mutableListOf<Video>()
        videoIds.chunked(30).forEach { chunk ->
            val snap = firestore.collection("videos")
                .whereIn("__name__", chunk.map { firestore.collection("videos").document(it) })
                .get().await()
            snap.documents.mapNotNull { it.toObject(Video::class.java)?.copy(id = it.id) }
                .let { results.addAll(it) }
        }
        return results.sortedBy { videoIds.indexOf(it.id) }
    }

    // ── Trending with category ─────────────────────────────────────────────────

    override suspend fun fetchTrending(category: String?, limit: Int): List<Video> {
        var q = firestore.collection("videos")
            .whereEqualTo("isPublic", true)
            .whereEqualTo("processingStatus", "ready")
            .orderBy("viewCount", Query.Direction.DESCENDING)
            .limit(limit.toLong())
        if (!category.isNullOrBlank()) {
            q = firestore.collection("videos")
                .whereEqualTo("isPublic", true)
                .whereEqualTo("category", category)
                .orderBy("viewCount", Query.Direction.DESCENDING)
                .limit(limit.toLong())
        }
        return q.get().await().documents
            .mapNotNull { it.toObject(Video::class.java)?.copy(id = it.id) }
    }

    /**
     * Fetches personalized recommendations from the recommendation service
     * using hybrid algorithm (content-based 70% + collaborative filtering 30%).
     * Falls back to trending on network/auth failure.
     */
    override suspend fun fetchPersonalizedRecommendations(limit: Int): Result<List<Video>> =
        runCatching {
            val response = recommendationApi.getPersonalRecommendations(limit = limit)
            response.videos.map { rec ->
                Video(
                    id = rec.id,
                    title = rec.title,
                    description = rec.description,
                    thumbnailUrl = rec.thumbnailUrl,
                    duration = rec.duration.toLong(),
                    viewCount = rec.viewCount,
                    likeCount = rec.likeCount,
                    channelId = rec.creator?.id ?: "",
                    channelName = rec.creator?.displayName ?: "",
                    channelAvatarUrl = rec.creator?.avatarUrl ?: "",
                    isVerified = rec.creator?.verified ?: false
                )
            }
        }.recoverCatching {
            // Fallback: trending from Firestore
            fetchTrending(null, limit)
        }

    // ── Movies ─────────────────────────────────────────────────────────────────

    override suspend fun fetchMovies(limit: Int): List<Video> =
        firestore.collection("videos")
            .whereEqualTo("isPublic", true)
            .whereGreaterThanOrEqualTo("duration", 1800L)
            .orderBy("duration")
            .orderBy("viewCount", Query.Direction.DESCENDING)
            .limit(limit.toLong())
            .get().await()
            .documents
            .mapNotNull { it.toObject(Video::class.java)?.copy(id = it.id) }

    // ── Stories ────────────────────────────────────────────────────────────────

    override suspend fun fetchStoriesForSubscriptions(userId: String): List<StoryGroup> {
        // Get subscribed channel IDs
        val subSnap = firestore.collection("users").document(userId)
            .collection("subscriptions").get().await()
        val channelIds = subSnap.documents.map { it.id }
        if (channelIds.isEmpty()) return emptyList()

        val now = com.google.firebase.Timestamp.now()
        val groups = mutableListOf<StoryGroup>()

        channelIds.chunked(30).forEach { chunk ->
            val storiesSnap = firestore.collection("stories")
                .whereIn("channelId", chunk)
                .whereGreaterThan("expiresAt", now)
                .orderBy("expiresAt")
                .get().await()

            val byChannel = storiesSnap.documents
                .mapNotNull { it.toObject(com.mychannel.domain.model.Story::class.java)?.copy(id = it.id) }
                .groupBy { it.channelId }

            byChannel.forEach { (channelId, stories) ->
                val userSnap = firestore.collection("users").document(channelId).get().await()
                val channelName = userSnap.getString("displayName") ?: userSnap.getString("username") ?: stories.firstOrNull()?.creatorName ?: "Creator"
                val channelAvatar = userSnap.getString("profileImageURL") ?: stories.firstOrNull()?.avatarUrl ?: ""
                groups.add(
                    StoryGroup(
                        channelId = channelId,
                        channelName = channelName,
                        channelAvatarUrl = channelAvatar,
                        stories = stories,
                        hasUnread = stories.any { !it.isViewed }
                    )
                )
            }
        }
        return groups
    }

    override suspend fun markStorySeen(userId: String, storyId: String) {
        runCatching {
            firestore.collection("users").document(userId)
                .collection("seenStories").document(storyId)
                .set(mapOf("seenAt" to FieldValue.serverTimestamp())).await()
        }
    }

    // ── End Screens ────────────────────────────────────────────────────────────

    override suspend fun fetchEndScreenElements(videoId: String): List<EndScreenElement> {
        val snap = firestore.collection("videos").document(videoId).get().await()
        val raw = snap.get("endScreenElements") as? List<*> ?: return emptyList()
        return raw.filterIsInstance<Map<*, *>>().map { m ->
            EndScreenElement(
                id = m["id"] as? String ?: java.util.UUID.randomUUID().toString(),
                type = m["type"] as? String ?: "video",
                title = m["title"] as? String ?: "",
                targetId = m["targetId"] as? String ?: "",
                xPct = (m["xPct"] as? Double)?.toFloat() ?: 0.5f,
                yPct = (m["yPct"] as? Double)?.toFloat() ?: 0.5f,
                startSeconds = m["startSeconds"] as? Double ?: 0.0,
                endSeconds = m["endSeconds"] as? Double ?: 0.0
            )
        }
    }

    override suspend fun saveEndScreenElements(
        videoId: String,
        elements: List<EndScreenElement>
    ): Result<Unit> = runCatching {
        val payload = elements.map { el ->
            mapOf(
                "id" to el.id,
                "type" to el.type,
                "title" to el.title,
                "targetId" to el.targetId,
                "xPct" to el.xPct.toDouble(),
                "yPct" to el.yPct.toDouble(),
                "startSeconds" to el.startSeconds,
                "endSeconds" to el.endSeconds
            )
        }
        firestore.collection("videos").document(videoId)
            .update(mapOf("endScreenElements" to payload, "updatedAt" to FieldValue.serverTimestamp()))
            .await()
    }

    // ── Videos by creator ─────────────────────────────────────────────────────

    override suspend fun fetchVideosByCreator(creatorId: String, limit: Int): List<Video> =
        firestore.collection("videos")
            .whereEqualTo("creatorId", creatorId)
            .whereEqualTo("isPublic", true)
            .orderBy("createdAt", Query.Direction.DESCENDING)
            .limit(limit.toLong())
            .get().await()
            .documents
            .mapNotNull { it.toObject(Video::class.java)?.copy(id = it.id) }

    private companion object {
        const val PAGE_SIZE = 20
        const val PREFETCH_DISTANCE = 5
    }
}
