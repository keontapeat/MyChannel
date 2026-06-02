package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.firestore.FirebaseFirestore
import com.mychannel.domain.model.Channel
import com.mychannel.domain.model.Video
import com.mychannel.domain.repository.AuthRepository
import com.mychannel.domain.repository.ChannelRepository
import com.mychannel.domain.repository.VideoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import javax.inject.Inject

/**
 * State for the Creator Studio dashboard (REQ-8.4, REQ-8.5).
 *
 * Monetary figures here are **estimates** for creator-facing display only. They
 * are computed locally from public view/engagement data and are NOT authoritative
 * payout amounts — real money flows (escrow/payouts) are Cloud-Function-only.
 */
data class StudioUiState(
    val isLoading: Boolean = true,
    val channel: Channel? = null,
    val videos: List<Video> = emptyList(),
    val totalViews: Long = 0L,
    val subscriberCount: Long = 0L,
    val estimatedWatchTimeHours: Long = 0L,
    val estimatedRevenueCents: Long = 0L,
    val error: String? = null
)

/**
 * ViewModel for the Creator Studio screen (REQ-8.4, REQ-8.5).
 *
 * Combines the signed-in creator's channel document (subscriber/view totals)
 * with their uploaded videos (from the Task 2 data layer). Owner-scoped edit /
 * delete writes go directly to Firestore (injected per the design); Firebase
 * Security Rules remain the authoritative access-control layer.
 */
@HiltViewModel
class StudioViewModel @Inject constructor(
    private val videoRepository: VideoRepository,
    private val channelRepository: ChannelRepository,
    private val authRepository: AuthRepository,
    private val firestore: FirebaseFirestore
) : ViewModel() {

    private val _uiState = MutableStateFlow(StudioUiState())
    val uiState: StateFlow<StudioUiState> = _uiState.asStateFlow()

    init {
        loadStudio()
    }

    /** Observes the creator's channel + uploaded videos and derives dashboard stats. */
    fun loadStudio() {
        val uid = authRepository.currentUserId
        if (uid == null) {
            _uiState.value = StudioUiState(
                isLoading = false,
                error = "Sign in to access your Creator Studio."
            )
            return
        }

        _uiState.value = _uiState.value.copy(isLoading = true, error = null)

        combine(
            channelRepository.observeChannel(uid),
            videoRepository.observeChannelVideos(uid)
        ) { channel, videos ->
            buildState(channel, videos)
        }
            .catch { error ->
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = error.message ?: "Failed to load Creator Studio."
                )
            }
            .onEach { state -> _uiState.value = state }
            .launchIn(viewModelScope)
    }

    private fun buildState(channel: Channel?, videos: List<Video>): StudioUiState {
        val totalViewsFromVideos = videos.sumOf { it.viewCount }
        val totalViews = channel?.totalViewCount?.takeIf { it > 0 } ?: totalViewsFromVideos

        // Estimated cumulative watch time: assume each view watches ~60% of the
        // video. Display-only heuristic (REQ-8.4).
        val estimatedWatchTimeSeconds = videos.sumOf { it.viewCount * it.duration } * WATCH_RATIO_NUM / WATCH_RATIO_DEN
        val estimatedWatchTimeHours = estimatedWatchTimeSeconds / SECONDS_PER_HOUR

        // Estimated revenue: simple RPM model. Integer cents, never floating dollars.
        val estimatedRevenueCents = totalViews * ESTIMATED_RPM_CENTS / VIEWS_PER_RPM

        return StudioUiState(
            isLoading = false,
            channel = channel,
            videos = videos,
            totalViews = totalViews,
            subscriberCount = channel?.subscriberCount ?: 0L,
            estimatedWatchTimeHours = estimatedWatchTimeHours,
            estimatedRevenueCents = estimatedRevenueCents,
            error = null
        )
    }

    /**
     * Deletes one of the creator's videos. The Firestore document is removed
     * (owner-scoped; enforced by Security Rules); a Cloud Function cleans up the
     * backing Storage objects. The observed feed updates the list automatically.
     */
    fun deleteVideo(videoId: String) {
        if (videoId.isBlank()) return
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    firestore.collection(VIDEOS).document(videoId).delete().await()
                }
            }.onFailure { error ->
                _uiState.value = _uiState.value.copy(
                    error = error.message ?: "Couldn't delete the video."
                )
            }
        }
    }

    /** Updates editable metadata for one of the creator's videos (REQ-8.5). */
    fun updateVideoDetails(
        videoId: String,
        title: String,
        description: String,
        privacyStatus: String
    ) {
        if (videoId.isBlank()) return
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    firestore.collection(VIDEOS).document(videoId)
                        .update(
                            mapOf(
                                "title" to title.trim(),
                                "description" to description.trim(),
                                "privacyStatus" to privacyStatus
                            )
                        )
                        .await()
                }
            }.onFailure { error ->
                _uiState.value = _uiState.value.copy(
                    error = error.message ?: "Couldn't update the video."
                )
            }
        }
    }

    /** Clears a transient error after it has been shown. */
    fun consumeError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    private companion object {
        const val VIDEOS = "videos"

        // Watch-time estimate: ~60% average view-through.
        const val WATCH_RATIO_NUM = 6L
        const val WATCH_RATIO_DEN = 10L
        const val SECONDS_PER_HOUR = 3600L

        // Revenue estimate: $2.00 (200 cents) per 1000 views.
        const val ESTIMATED_RPM_CENTS = 200L
        const val VIEWS_PER_RPM = 1000L
    }
}
