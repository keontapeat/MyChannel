package com.mychannel.viewmodel

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mychannel.data.remote.ModerationDataSource
import com.mychannel.domain.model.Comment
import com.mychannel.domain.model.ContentReportReason
import com.mychannel.domain.model.ContentReportType
import com.mychannel.domain.model.PlaybackSession
import com.mychannel.domain.model.Video
import com.mychannel.domain.repository.ChannelRepository
import com.mychannel.domain.repository.PlaybackSessionRepository
import com.mychannel.domain.repository.VideoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlin.math.abs
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class VideoPlayerUiState(
    val video: Video? = null,
    val comments: List<Comment> = emptyList(),
    val suggested: List<Video> = emptyList(),
    val playbackPositionMs: Long = 0L,
    val authorizedPlaybackUrl: String? = null,
    val playbackSessionId: String? = null,
    val playbackSession: PlaybackSession? = null,
    val playbackError: String? = null,
    val isLiked: Boolean = false,
    val isDisliked: Boolean = false,
    val isSaved: Boolean = false,
    val isSubscribed: Boolean = false,
    val isLoading: Boolean = true,
    val error: String? = null,
    /** Transient action feedback; shown by the screen and then cleared. */
    val actionMessage: String? = null
)

@HiltViewModel
class VideoPlayerViewModel @Inject constructor(
    private val videoRepository: VideoRepository,
    private val channelRepository: ChannelRepository,
    private val playbackSessionRepository: PlaybackSessionRepository,
    private val moderationDataSource: ModerationDataSource,
    private val dataStore: DataStore<Preferences>
) : ViewModel() {

    private val _uiState = MutableStateFlow(VideoPlayerUiState())
    val uiState: StateFlow<VideoPlayerUiState> = _uiState.asStateFlow()

    private var currentVideoId: String = ""
    private var loadJob: Job? = null
    private var playbackAuthorizationJob: Job? = null
    private var commentsJob: Job? = null
    private var suggestionsJob: Job? = null
    private var lastSavedPositionMs: Long = 0L
    private var lastReportedWatchSeconds: Int = 0
    private var accumulatedWatchOffsetMs: Long = 0L
    private var lastSurfaceWatchMs: Long = 0L
    private var qualifiedViewVideoId: String? = null

    fun loadVideo(videoId: String, force: Boolean = false) {
        if (videoId.isBlank()) {
            _uiState.update { it.copy(isLoading = false, error = "Video unavailable") }
            return
        }
        if (!force && currentVideoId == videoId) return

        loadJob?.cancel()
        playbackAuthorizationJob?.cancel()
        commentsJob?.cancel()
        suggestionsJob?.cancel()
        currentVideoId = videoId
        lastSavedPositionMs = 0L
        lastReportedWatchSeconds = 0
        accumulatedWatchOffsetMs = 0L
        lastSurfaceWatchMs = 0L
        qualifiedViewVideoId = null
        _uiState.value = VideoPlayerUiState(isLoading = true)

        loadJob = viewModelScope.launch {
            val videoResult = videoRepository.getVideo(videoId)
            val video = videoResult.getOrElse { error ->
                if (currentVideoId == videoId) {
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = error.message ?: "Unable to load video"
                        )
                    }
                }
                return@launch
            }

            val sessionResult = playbackSessionRepository.authorize(videoId)
            val session = sessionResult.getOrElse { error ->
                if (currentVideoId == videoId) {
                    _uiState.update {
                        it.copy(
                            video = video,
                            isLoading = false,
                            playbackError = error.message ?: "Video unavailable"
                        )
                    }
                }
                return@launch
            }
            if (currentVideoId != videoId) return@launch

            val playbackPosition = dataStore.data.first()[playbackKey(videoId)] ?: 0L
            lastSavedPositionMs = playbackPosition
            _uiState.update {
                it.copy(
                    video = video,
                    authorizedPlaybackUrl = session.manifestUrl,
                    playbackSessionId = session.sessionId,
                    playbackSession = session,
                    playbackPositionMs = playbackPosition,
                    isLoading = false,
                    playbackError = null
                )
            }
            schedulePlaybackRenewal(videoId, session.expiresAtEpochMs)

            coroutineScope {
                val liked = async { videoRepository.isLiked(videoId).getOrDefault(false) }
                val disliked = async { videoRepository.isDisliked(videoId).getOrDefault(false) }
                val saved = async { videoRepository.isSaved(videoId).getOrDefault(false) }
                val subscribed = async {
                    channelRepository.isSubscribed(video.channelId).getOrDefault(false)
                }
                val engagement = liked.await() to disliked.await()
                if (currentVideoId == videoId) {
                    _uiState.update {
                        it.copy(
                            isLiked = engagement.first,
                            isDisliked = engagement.second,
                            isSaved = saved.await(),
                            isSubscribed = subscribed.await()
                        )
                    }
                }
            }
        }

        commentsJob = videoRepository.observeComments(videoId)
            .onEach { comments ->
                if (currentVideoId == videoId) _uiState.update { it.copy(comments = comments) }
            }
            .catch { error -> showActionError("Comments", error) }
            .launchIn(viewModelScope)

        // The existing trending API is server-filtered to public, processed long-form
        // videos. Apply client-side policy guards for legacy/incomplete documents.
        suggestionsJob = videoRepository.observeTrending()
            .onEach { videos ->
                if (currentVideoId == videoId) {
                    _uiState.update { state ->
                        state.copy(
                            suggested = videos.asSequence()
                                .filter { it.id != videoId }
                                .filter { it.privacyStatus.lowercase() == "public" && !it.isShort }
                                .filter { it.processingStatus.lowercase() == "ready" }
                                .filter { it.moderationStatus.lowercase() == "approved" }
                                .filter { !it.ageRestricted && !it.isPremium }
                                // Region-restricted rows require a trusted viewer policy;
                                // this client omits them rather than guessing a location.
                                .filter { it.allowedRegions.isEmpty() && it.blockedRegions.isEmpty() }
                                .take(MAX_SUGGESTIONS)
                                .toList()
                        )
                    }
                }
            }
            .catch { error -> showActionError("Recommendations", error) }
            .launchIn(viewModelScope)
    }

    private fun schedulePlaybackRenewal(videoId: String, expiresAtEpochMs: Long?) {
        playbackAuthorizationJob?.cancel()
        if (expiresAtEpochMs == null) return
        playbackAuthorizationJob = viewModelScope.launch {
            delay((expiresAtEpochMs - System.currentTimeMillis() - SESSION_RENEWAL_WINDOW_MS).coerceAtLeast(1_000L))
            if (currentVideoId != videoId) return@launch
            playbackSessionRepository.authorize(videoId)
                .onSuccess { session ->
                    if (currentVideoId == videoId) {
                        _uiState.update {
                            it.copy(
                                authorizedPlaybackUrl = session.manifestUrl,
                                playbackSessionId = session.sessionId,
                                playbackSession = session,
                                playbackError = null
                            )
                        }
                        schedulePlaybackRenewal(videoId, session.expiresAtEpochMs)
                    }
                }
                .onFailure { error ->
                    if (currentVideoId == videoId) {
                        _uiState.update {
                            it.copy(
                                authorizedPlaybackUrl = null,
                                playbackSessionId = null,
                                playbackSession = null,
                                playbackError = error.message ?: "Video unavailable"
                            )
                        }
                    }
                }
        }
    }

    fun retryVideo() {
        val videoId = currentVideoId
        if (videoId.isNotBlank()) loadVideo(videoId, force = true)
    }

    fun recordQualifiedView(videoId: String) {
        if (videoId != currentVideoId || qualifiedViewVideoId == videoId) return
        val session = _uiState.value.playbackSession ?: return
        qualifiedViewVideoId = videoId
        viewModelScope.launch {
            playbackSessionRepository.reportWatchTime(
                videoId = videoId,
                sessionId = session.sessionId,
                watchTimeSeconds = QUALIFIED_VIEW_SECONDS,
                completionRate = null,
                qualifiedView = true
            ).onFailure { error ->
                if (currentVideoId == videoId) {
                    qualifiedViewVideoId = null
                    showActionError("View", error)
                }
            }
        }
    }

    fun toggleLike() {
        val videoId = currentVideoId.ifBlank { return }
        val before = _uiState.value
        val next = !before.isLiked
        viewModelScope.launch {
            videoRepository.toggleLike(videoId, next)
                .onSuccess {
                    if (currentVideoId == videoId) {
                        _uiState.update { state ->
                            val video = state.video
                            state.copy(
                                video = video?.copy(
                                    likeCount = (video.likeCount + if (next) 1 else -1).coerceAtLeast(0),
                                    dislikeCount = (video.dislikeCount - if (next && state.isDisliked) 1 else 0)
                                        .coerceAtLeast(0)
                                ),
                                isLiked = next,
                                isDisliked = if (next) false else state.isDisliked
                            )
                        }
                    }
                }
                .onFailure { showActionError("Like", it) }
        }
    }

    fun toggleDislike() {
        val videoId = currentVideoId.ifBlank { return }
        val before = _uiState.value
        val next = !before.isDisliked
        viewModelScope.launch {
            videoRepository.toggleDislike(videoId, next)
                .onSuccess {
                    if (currentVideoId == videoId) {
                        _uiState.update { state ->
                            val video = state.video
                            state.copy(
                                video = video?.copy(
                                    dislikeCount = (video.dislikeCount + if (next) 1 else -1).coerceAtLeast(0),
                                    likeCount = (video.likeCount - if (next && state.isLiked) 1 else 0)
                                        .coerceAtLeast(0)
                                ),
                                isLiked = if (next) false else state.isLiked,
                                isDisliked = next
                            )
                        }
                    }
                }
                .onFailure { showActionError("Dislike", it) }
        }
    }

    fun toggleSave() {
        val video = _uiState.value.video ?: return
        val next = !_uiState.value.isSaved
        _uiState.update { it.copy(isSaved = next) }
        viewModelScope.launch {
            videoRepository.setSaved(video, next)
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isSaved = !next,
                            actionMessage = error.message ?: "Unable to update Watch Later"
                        )
                    }
                }
        }
    }

    fun toggleSubscribe() {
        val channelId = _uiState.value.video?.channelId ?: return
        val next = !_uiState.value.isSubscribed
        _uiState.update { it.copy(isSubscribed = next) }
        viewModelScope.launch {
            val result = if (next) {
                channelRepository.subscribe(channelId)
            } else {
                channelRepository.unsubscribe(channelId)
            }
            result.onFailure { error ->
                _uiState.update {
                    it.copy(
                        isSubscribed = !next,
                        actionMessage = error.message ?: "Unable to update subscription"
                    )
                }
            }
        }
    }

    fun postComment(text: String, parentId: String? = null) {
        val videoId = currentVideoId.ifBlank { return }
        viewModelScope.launch {
            videoRepository.postComment(videoId, text, parentId)
                .onFailure { showActionError("Comment", it) }
        }
    }

    fun savePlaybackProgress(
        videoId: String,
        positionMs: Long,
        durationMs: Long,
        watchedPlaybackMs: Long
    ) {
        if (videoId != currentVideoId || positionMs < 0L || watchedPlaybackMs < 0L) return

        val surfaceWatchMs = watchedPlaybackMs.coerceAtMost(MAX_WATCH_TIME_MS)
        // Media3 recreates the surface when a renewed signed manifest changes.
        // Rebase its per-surface counter so cumulative reporting stays monotonic
        // and resumes immediately instead of waiting to overtake the old watermark.
        if (surfaceWatchMs < lastSurfaceWatchMs) {
            accumulatedWatchOffsetMs =
                (accumulatedWatchOffsetMs + lastSurfaceWatchMs).coerceAtMost(MAX_WATCH_TIME_MS)
        }
        lastSurfaceWatchMs = surfaceWatchMs
        val watchedSeconds =
            ((accumulatedWatchOffsetMs + surfaceWatchMs).coerceAtMost(MAX_WATCH_TIME_MS) / 1_000L).toInt()
        val session = _uiState.value.playbackSession
        if (session != null && watchedSeconds >= lastReportedWatchSeconds + WATCH_TIME_REPORT_INTERVAL_SECONDS) {
            val previousReported = lastReportedWatchSeconds
            lastReportedWatchSeconds = watchedSeconds
            val completionRate = if (durationMs > 0L) {
                (positionMs.toDouble() / durationMs.toDouble()).coerceIn(0.0, 1.0)
            } else {
                null
            }
            viewModelScope.launch {
                playbackSessionRepository.reportWatchTime(
                    videoId = videoId,
                    sessionId = session.sessionId,
                    watchTimeSeconds = watchedSeconds,
                    completionRate = completionRate
                ).onFailure {
                    if (currentVideoId == videoId) {
                        lastReportedWatchSeconds = minOf(lastReportedWatchSeconds, previousReported)
                    }
                }
            }
        }

        val completed = durationMs > 0L && positionMs >= durationMs - COMPLETION_WINDOW_MS
        val valueToSave = if (completed || positionMs < MIN_RESUME_POSITION_MS) 0L else positionMs
        if (valueToSave != 0L && abs(valueToSave - lastSavedPositionMs) < PROGRESS_WRITE_INTERVAL_MS) return
        if (valueToSave == 0L && lastSavedPositionMs == 0L) return
        lastSavedPositionMs = valueToSave
        viewModelScope.launch {
            dataStore.edit { preferences ->
                val key = playbackKey(videoId)
                if (valueToSave == 0L) preferences.remove(key) else preferences[key] = valueToSave
            }
        }
    }

    /** Reports the current video for the given reason (UGC safety — App/Play compliance). */
    fun reportVideo(reason: ContentReportReason) {
        val video = _uiState.value.video ?: return
        viewModelScope.launch {
            val message = runCatching {
                moderationDataSource.submitReport(
                    type = ContentReportType.VIDEO,
                    contentId = video.id,
                    contentCreatorId = video.channelId,
                    reason = reason
                )
            }.fold(
                onSuccess = { "Report submitted. Thanks for keeping MyChannel safe." },
                onFailure = { it.message ?: "Unable to submit report." }
            )
            _uiState.update { it.copy(actionMessage = message) }
        }
    }

    /** Reports a comment for the given reason. */
    fun reportComment(comment: Comment, reason: ContentReportReason) {
        viewModelScope.launch {
            val message = runCatching {
                moderationDataSource.submitReport(
                    type = ContentReportType.COMMENT,
                    contentId = comment.id,
                    contentCreatorId = comment.userId,
                    reason = reason,
                    videoId = comment.videoId.ifBlank { currentVideoId }
                )
            }.fold(
                onSuccess = { "Report submitted. Thanks for keeping MyChannel safe." },
                onFailure = { it.message ?: "Unable to submit report." }
            )
            _uiState.update { it.copy(actionMessage = message) }
        }
    }

    /** Blocks the current video's channel/creator so their content can be filtered. */
    fun blockChannel() {
        val video = _uiState.value.video ?: return
        viewModelScope.launch {
            val message = runCatching {
                moderationDataSource.blockUser(
                    blockedUserId = video.channelId,
                    blockedUserDisplayName = video.channelName
                )
            }.fold(
                onSuccess = { "Channel blocked. You won't see their content." },
                onFailure = { it.message ?: "Unable to block channel." }
            )
            _uiState.update { it.copy(actionMessage = message) }
        }
    }

    fun clearActionMessage() {
        _uiState.update { it.copy(actionMessage = null) }
    }

    private fun showActionError(action: String, error: Throwable) {
        _uiState.update {
            it.copy(actionMessage = error.message ?: "$action failed. Please try again.")
        }
    }

    private fun playbackKey(videoId: String) = longPreferencesKey("video_progress_$videoId")

    private companion object {
        const val MAX_SUGGESTIONS = 20
        const val MIN_RESUME_POSITION_MS = 5_000L
        const val COMPLETION_WINDOW_MS = 10_000L
        const val PROGRESS_WRITE_INTERVAL_MS = 5_000L
        const val SESSION_RENEWAL_WINDOW_MS = 60_000L
        const val MAX_WATCH_TIME_MS = 86_400_000L
        const val QUALIFIED_VIEW_SECONDS = 5
        const val WATCH_TIME_REPORT_INTERVAL_SECONDS = 15
    }
}
