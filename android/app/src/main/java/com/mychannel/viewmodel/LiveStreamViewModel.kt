package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mychannel.data.remote.ModerationDataSource
import com.mychannel.domain.model.ContentReportReason
import com.mychannel.domain.model.ContentReportType
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

/**
 * Minimal chat message for the live stream chat overlay.
 * Full-featured chat will be backed by Firebase Realtime Database.
 */
data class ChatMessage(val id: String, val username: String, val text: String)

data class LiveStreamUiState(
    val streamUrl: String? = null,
    val streamTitle: String = "",
    val channelId: String = "",
    val channelName: String = "",
    val viewerCount: Long = 0L,
    val chatMessages: List<ChatMessage> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null,
    /** Transient user feedback for moderation actions (report/block); shown then cleared. */
    val moderationMessage: String? = null
)

@HiltViewModel
class LiveStreamViewModel @Inject constructor(
    private val videoRepository: VideoRepository,
    private val moderationDataSource: ModerationDataSource
) : ViewModel() {

    private val _uiState = MutableStateFlow(LiveStreamUiState())
    val uiState: StateFlow<LiveStreamUiState> = _uiState.asStateFlow()

    private var currentStreamId: String = ""

    fun loadStream(streamId: String) {
        if (currentStreamId == streamId) return
        currentStreamId = streamId
        _uiState.update { it.copy(isLoading = true, error = null) }

        // Observe the live stream document. For a live stream, videoUrl == HLS ingest URL.
        viewModelScope.launch {
            videoRepository.getVideo(streamId)
                .onSuccess { video ->
                    _uiState.update {
                        it.copy(
                            streamUrl = video.videoUrl,
                            streamTitle = video.title,
                            channelId = video.channelId,
                            channelName = video.channelName,
                            isLoading = false
                        )
                    }
                }
                .onFailure { e ->
                    _uiState.update { it.copy(isLoading = false, error = e.message) }
                }
        }

        // Chat subscription — backed by Firebase Realtime DB in the full impl.
        // Viewer count comes from Firestore live-stream doc real-time updates.
    }

    fun sendChatMessage(text: String) {
        // Chat write goes to Firebase Realtime Database via the repository layer.
        // Optimistically append to local list for immediate feedback.
        val msg = ChatMessage(
            id = System.currentTimeMillis().toString(),
            username = "You",
            text = text
        )
        _uiState.update { it.copy(chatMessages = it.chatMessages + msg) }
    }

    /**
     * Reports the current live stream. Android loads streams from the `videos`
     * collection (via [VideoRepository.getVideo]), so it reports as
     * [ContentReportType.VIDEO] to satisfy the Firestore rule's `videos/{id}`
     * existence check.
     */
    fun reportStream(reason: ContentReportReason) {
        val streamId = currentStreamId.ifBlank { return }
        viewModelScope.launch {
            val message = runCatching {
                moderationDataSource.submitReport(
                    type = ContentReportType.VIDEO,
                    contentId = streamId,
                    contentCreatorId = _uiState.value.channelId,
                    reason = reason
                )
            }.fold(
                onSuccess = { "Report submitted. Thanks for keeping MyChannel safe." },
                onFailure = { it.message ?: "Unable to submit report." }
            )
            _uiState.update { it.copy(moderationMessage = message) }
        }
    }

    /** Blocks the streamer so their content can be filtered from feeds. */
    fun blockStreamer() {
        val channelId = _uiState.value.channelId.ifBlank { return }
        viewModelScope.launch {
            val message = runCatching {
                moderationDataSource.blockUser(
                    blockedUserId = channelId,
                    blockedUserDisplayName = _uiState.value.channelName
                )
            }.fold(
                onSuccess = { "Streamer blocked. You won't see their content." },
                onFailure = { it.message ?: "Unable to block streamer." }
            )
            _uiState.update { it.copy(moderationMessage = message) }
        }
    }

    fun clearModerationMessage() {
        _uiState.update { it.copy(moderationMessage = null) }
    }
}
