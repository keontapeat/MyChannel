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

data class WatchLaterUiState(
    val isLoading: Boolean = true,
    val videos: List<Video> = emptyList(),
    val totalDurationLabel: String = "",
    val error: String? = null
)

@HiltViewModel
class WatchLaterViewModel @Inject constructor(
    private val videoRepository: VideoRepository,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(WatchLaterUiState())
    val uiState: StateFlow<WatchLaterUiState> = _uiState.asStateFlow()

    init {
        loadWatchLater()
    }

    private fun loadWatchLater() {
        val uid = authRepository.currentUserId ?: run {
            _uiState.update { it.copy(isLoading = false) }
            return
        }
        videoRepository.observeWatchLater(uid)
            .onEach { videos ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        videos = videos,
                        totalDurationLabel = formatTotalDuration(videos.sumOf { v -> v.duration })
                    )
                }
            }
            .catch { e -> _uiState.update { it.copy(isLoading = false, error = e.message) } }
            .launchIn(viewModelScope)
    }

    fun remove(videoId: String) {
        val uid = authRepository.currentUserId ?: return
        viewModelScope.launch {
            videoRepository.removeFromWatchLater(uid, videoId)
        }
    }

    fun clearAll() {
        val uid = authRepository.currentUserId ?: return
        viewModelScope.launch {
            videoRepository.clearWatchLater(uid)
        }
    }

    private fun formatTotalDuration(totalSeconds: Long): String {
        if (totalSeconds <= 0L) return ""
        val h = totalSeconds / 3600
        val m = (totalSeconds % 3600) / 60
        return if (h > 0) "${h}h ${m}m" else "${m}m"
    }
}
