package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
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
    val error: String? = null
)

@HiltViewModel
class FlicksViewModel @Inject constructor(
    private val videoRepository: VideoRepository
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
}
