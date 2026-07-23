package com.mychannel.domain.repository

import androidx.paging.PagingData
import com.mychannel.domain.model.Comment
import com.mychannel.domain.model.EndScreenElement
import com.mychannel.domain.model.LiveStream
import com.mychannel.domain.model.Playlist
import com.mychannel.domain.model.Story
import com.mychannel.domain.model.StoryGroup
import com.mychannel.domain.model.Video
import kotlinx.coroutines.flow.Flow

/**
 * Repository for video data (REQ-4.x, REQ-5.x).
 *
 * Real-time feeds use [Flow] (backed by Firestore snapshot listeners via
 * callbackFlow); one-shot reads/writes are suspend functions returning [Result].
 */
interface VideoRepository {

    /** Real-time trending feed, ordered by view count. */
    fun observeTrending(): Flow<List<Video>>

    /**
     * Paginated recommended feed for the Home screen (REQ-4.5). Backed by a
     * Firestore cursor [androidx.paging.PagingSource]. When [category] is null
     * the full public long-form feed is returned; otherwise it is constrained
     * to that category.
     */
    fun recommendedFeed(category: String?): Flow<PagingData<Video>>

    /** Real-time "Live Now" feed of currently-live streams (REQ-4.4). */
    fun observeLiveStreams(): Flow<List<LiveStream>>

    /** Real-time feed of active creator stories for the Home stories row (REQ-4.2). */
    fun observeStories(): Flow<List<Story>>

    /** Real-time feed of a single channel's videos. */
    fun observeChannelVideos(channelId: String): Flow<List<Video>>

    /** Real-time feed of short-form videos for the Flicks screen (isShort == true). */
    fun observeShorts(): Flow<List<Video>>

    suspend fun getVideo(videoId: String): Result<Video>

    /** Real-time comments for a video, ordered newest-first. */
    fun observeComments(videoId: String): Flow<List<Comment>>

    suspend fun postComment(videoId: String, text: String, parentId: String?): Result<Comment>

    suspend fun toggleLike(videoId: String, like: Boolean): Result<Unit>

    suspend fun toggleDislike(videoId: String, dislike: Boolean): Result<Unit>

    /** Whether the current user has liked this video. */
    suspend fun isLiked(videoId: String): Result<Boolean>

    /** Whether the current user has disliked this video. */
    suspend fun isDisliked(videoId: String): Result<Boolean>

    /** Whether this video is in the current user's Watch Later. */
    suspend fun isSaved(videoId: String): Result<Boolean>

    /** Add or remove a video from the current user's Watch Later. */
    suspend fun setSaved(video: Video, save: Boolean): Result<Unit>

    suspend fun incrementViewCount(videoId: String): Result<Unit>

    /** Real-time list of videos downloaded by [userId] for offline playback. */
    fun observeDownloads(userId: String): Flow<List<Video>>

    /** Remove a downloaded video from the user's offline cache. */
    suspend fun deleteDownload(userId: String, videoId: String): Result<Unit>

    // ── Watch History ──────────────────────────────────────────────────────────

    /** Real-time watch history for [userId], newest-first. */
    fun observeWatchHistory(userId: String): Flow<List<Video>>

    /** Remove a single video from the user's watch history. */
    suspend fun removeFromWatchHistory(userId: String, videoId: String): Result<Unit>

    /** Clear all watch history for [userId]. */
    suspend fun clearWatchHistory(userId: String): Result<Unit>

    // ── Watch Later ────────────────────────────────────────────────────────────

    /** Real-time Watch Later queue for [userId], in order added. */
    fun observeWatchLater(userId: String): Flow<List<Video>>

    /** Remove a video from the user's Watch Later queue. */
    suspend fun removeFromWatchLater(userId: String, videoId: String): Result<Unit>

    /** Clear the entire Watch Later queue for [userId]. */
    suspend fun clearWatchLater(userId: String): Result<Unit>

    // ── Playlists ──────────────────────────────────────────────────────────────

    /** Fetch all playlists owned by [userId]. */
    suspend fun fetchPlaylists(userId: String): List<Playlist>

    /** Fetch a single playlist by ID. Returns null if not found. */
    suspend fun fetchPlaylist(playlistId: String): Playlist?

    /** Create a new playlist for [userId] with the given [title]. */
    suspend fun createPlaylist(userId: String, title: String): Result<Unit>

    /** Delete a playlist owned by [userId]. */
    suspend fun deletePlaylist(userId: String, playlistId: String): Result<Unit>

    /** Fetch multiple videos by their IDs, preserving order. */
    suspend fun fetchVideosByIds(videoIds: List<String>): List<Video>

    // ── Trending (with category filter) ───────────────────────────────────────

    /** Fetch trending videos, optionally filtered by [category]. */
    suspend fun fetchTrending(category: String?, limit: Int): List<Video>

    // ── Movies ─────────────────────────────────────────────────────────────────

    /** Fetch movie-length videos (duration >= 1800s). */
    suspend fun fetchMovies(limit: Int): List<Video>

    // ── Stories ────────────────────────────────────────────────────────────────

    /** Fetch active stories grouped by channel for the subscribed user [userId]. */
    suspend fun fetchStoriesForSubscriptions(userId: String): List<StoryGroup>

    /** Mark a story as seen by [userId]. */
    suspend fun markStorySeen(userId: String, storyId: String)

    // ── End Screen Elements ────────────────────────────────────────────────────

    /** Fetch end screen elements for [videoId]. */
    suspend fun fetchEndScreenElements(videoId: String): List<EndScreenElement>

    /** Save end screen elements for [videoId] to Firestore. */
    suspend fun saveEndScreenElements(videoId: String, elements: List<EndScreenElement>): Result<Unit>

    // ── Videos by creator ─────────────────────────────────────────────────────

    /** Fetch videos by creator, newest-first, up to [limit]. */
    suspend fun fetchVideosByCreator(creatorId: String, limit: Int): List<Video>
}
