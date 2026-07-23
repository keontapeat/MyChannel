package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mychannel.domain.model.Video
import com.mychannel.domain.repository.AuthRepository
import com.mychannel.domain.repository.VideoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class HistoryUiState(
    val isLoading: Boolean = true,
    // Map of date-section label → videos in that section
    val history: Map<String, List<Video>> = emptyMap(),
    val isPaused: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class HistoryViewModel @Inject constructor(
    private val videoRepository: VideoRepository,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(HistoryUiState())
    val uiState: StateFlow<HistoryUiState> = _uiState.asStateFlow()

    init {
        loadHistory()
    }

    private fun loadHistory() {
        val uid = authRepository.currentUserId ?: run {
            _uiState.update { it.copy(isLoading = false) }
            return
        }
        videoRepository.observeWatchHistory(uid)
            .onEach { videos ->
                _uiState.update {
                    it.copy(isLoading = false, history = groupByDate(videos))
                }
            }
            .catch { e -> _uiState.update { it.copy(isLoading = false, error = e.message) } }
            .launchIn(viewModelScope)
    }

    fun removeFromHistory(videoId: String) {
        val uid = authRepository.currentUserId ?: return
        viewModelScope.launch {
            videoRepository.removeFromWatchHistory(uid, videoId)
        }
    }

    fun clearAll() {
        val uid = authRepository.currentUserId ?: return
        viewModelScope.launch {
            videoRepository.clearWatchHistory(uid)
        }
    }

    fun togglePause() {
        _uiState.update { it.copy(isPaused = !it.isPaused) }
        // Persist pause state via repository in a real implementation
    }

    /** Groups a flat list of videos into labelled date sections (Today, Yesterday, etc.) */
    private fun groupByDate(videos: List<Video>): Map<String, List<Video>> {
        if (videos.isEmpty()) return emptyMap()
        val now = System.currentTimeMillis()
        val dayMs = 86_400_000L
        val weekMs = 7 * dayMs
        val monthMs = 30 * dayMs

        return videos.groupBy { video ->
            val uploadMs = video.uploadedAt.toDate().time
            val diff = now - uploadMs
            when {
                diff < dayMs   -> "Today"
                diff < 2 * dayMs -> "Yesterday"
                diff < weekMs  -> "This week"
                diff < monthMs -> "This month"
                else           -> "Older"
            }
        }
    }
}
