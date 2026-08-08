package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mychannel.data.remote.ModerationDataSource
import com.mychannel.domain.model.ContentReportReason
import com.mychannel.domain.model.ContentReportType
import com.mychannel.domain.model.Video
import com.mychannel.domain.repository.VideoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class FlicksUiState(
    val shorts: List<Video> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null,
    /** Transient user feedback for moderation actions (report/block); shown then cleared. */
    val moderationMessage: String? = null
)

@HiltViewModel
class FlicksViewModel @Inject constructor(
    private val videoRepository: VideoRepository,
    private val moderationDataSource: ModerationDataSource
) : ViewModel() {

    private val _uiState = MutableStateFlow(FlicksUiState())
    val uiState: StateFlow<FlicksUiState> = _uiState.asStateFlow()

    init {
        videoRepository.observeShorts()
            .onEach { shorts ->
                _uiState.update { it.copy(shorts = shorts, isLoading = false) }
            }
            .launchIn(viewModelScope)
    }

    fun toggleLike(videoId: String) {
        viewModelScope.launch {
            videoRepository.toggleLike(videoId, true)
        }
    }

    /**
     * Reports a flick. Flicks are stored as short [Video] documents in the
     * `videos` collection, so they report as [ContentReportType.VIDEO] (the
     * Firestore rules validate against `videos/{id}`, not a `flicks/{id}` doc).
     */
    fun reportFlick(flick: Video, reason: ContentReportReason) {
        viewModelScope.launch {
            val message = runCatching {
                moderationDataSource.submitReport(
                    type = ContentReportType.VIDEO,
                    contentId = flick.id,
                    contentCreatorId = flick.channelId,
                    reason = reason
                )
            }.fold(
                onSuccess = { "Report submitted. Thanks for keeping MyChannel safe." },
                onFailure = { it.message ?: "Unable to submit report." }
            )
            _uiState.update { it.copy(moderationMessage = message) }
        }
    }

    /** Blocks the flick's creator so their content can be filtered from feeds. */
    fun blockFlickCreator(flick: Video) {
        viewModelScope.launch {
            val message = runCatching {
                moderationDataSource.blockUser(
                    blockedUserId = flick.channelId,
                    blockedUserDisplayName = flick.channelName
                )
            }.fold(
                onSuccess = { "Channel blocked. You won't see their content." },
                onFailure = { it.message ?: "Unable to block channel." }
            )
            _uiState.update { it.copy(moderationMessage = message) }
        }
    }

    fun clearModerationMessage() {
        _uiState.update { it.copy(moderationMessage = null) }
    }
}
