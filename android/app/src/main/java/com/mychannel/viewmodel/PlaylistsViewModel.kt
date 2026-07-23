package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mychannel.domain.model.Playlist
import com.mychannel.domain.repository.AuthRepository
import com.mychannel.domain.repository.VideoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class PlaylistsUiState(
    val isLoading: Boolean = true,
    val playlists: List<Playlist> = emptyList(),
    val error: String? = null
)

@HiltViewModel
class PlaylistsViewModel @Inject constructor(
    private val videoRepository: VideoRepository,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(PlaylistsUiState())
    val uiState: StateFlow<PlaylistsUiState> = _uiState.asStateFlow()

    init {
        loadPlaylists()
    }

    private fun loadPlaylists() {
        val uid = authRepository.currentUserId ?: run {
            _uiState.update { it.copy(isLoading = false) }
            return
        }
        viewModelScope.launch {
            try {
                val playlists = videoRepository.fetchPlaylists(uid)
                _uiState.update { it.copy(isLoading = false, playlists = playlists) }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun createPlaylist(title: String) {
        val uid = authRepository.currentUserId ?: return
        viewModelScope.launch {
            try {
                videoRepository.createPlaylist(uid, title)
                loadPlaylists()
            } catch (e: Exception) {
                _uiState.update { it.copy(error = e.message) }
            }
        }
    }

    fun deletePlaylist(playlistId: String) {
        val uid = authRepository.currentUserId ?: return
        viewModelScope.launch {
            try {
                videoRepository.deletePlaylist(uid, playlistId)
                _uiState.update { it.copy(playlists = it.playlists.filter { p -> p.id != playlistId }) }
            } catch (e: Exception) {
                _uiState.update { it.copy(error = e.message) }
            }
        }
    }
}
