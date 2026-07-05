package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mychannel.domain.model.Video
import com.mychannel.domain.repository.VideoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import javax.inject.Inject

data class LibraryUiState(
    val recentHistory: List<Video> = emptyList(),
    val historyCount: Int = 0,
    val watchLaterCount: Int = 0,
    val playlistCount: Int = 0,
    val downloadCount: Int = 0,
    val isLoading: Boolean = false
)

@HiltViewModel
class LibraryViewModel @Inject constructor() : ViewModel() {

    private val _uiState = MutableStateFlow(LibraryUiState())
    val uiState: StateFlow<LibraryUiState> = _uiState.asStateFlow()

    // History, playlists, watch-later, and downloads are tracked locally via
    // Room in future tasks. Counts default to 0 until those features land.
}
