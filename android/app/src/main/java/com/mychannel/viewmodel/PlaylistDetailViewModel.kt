package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mychannel.domain.model.Playlist
import com.mychannel.domain.model.Video
import com.mychannel.domain.repository.AuthRepository
import com.mychannel.domain.repository.VideoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class PlaylistDetailUiState(
    val isLoading: Boolean = true,
    val playlist: Playlist? = null,
    val videos: List<Video> = emptyList(),
    val error: String? = null
)

@HiltViewModel
class PlaylistDetailViewModel @Inject constructor(
    private val videoRepository: VideoRepository,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(PlaylistDetailUiState())
    val uiState: StateFlow<PlaylistDetailUiState> = _uiState.asStateFlow()

    fun load(playlistId: String) {
        _uiState.update { it.copy(isLoading = true) }
        viewModelScope.launch {
            try {
                val playlist = videoRepository.fetchPlaylist(playlistId)
                if (playlist == null) {
                    _uiState.update { it.copy(isLoading = false) }
                    return@launch
                }
                // Fetch videos for each videoId in order
                val videos = if (playlist.videoIds.isNotEmpty()) {
                    videoRepository.fetchVideosByIds(playlist.videoIds)
                        .sortedBy { playlist.videoIds.indexOf(it.id) }
                } else {
                    emptyList()
                }
                _uiState.update { it.copy(isLoading = false, playlist = playlist, videos = videos) }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun startEdit() {
        // Navigate to edit — handled by caller via notification or nav
    }

    fun delete(onComplete: () -> Unit) {
        val playlist = _uiState.value.playlist ?: return
        val uid = authRepository.currentUserId ?: return
        viewModelScope.launch {
            try {
                videoRepository.deletePlaylist(uid, playlist.id)
                onComplete()
            } catch (e: Exception) {
                _uiState.update { it.copy(error = e.message) }
            }
        }
    }
}
