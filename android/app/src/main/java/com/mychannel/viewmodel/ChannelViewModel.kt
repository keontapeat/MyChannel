package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mychannel.domain.model.Channel
import com.mychannel.domain.model.Video
import com.mychannel.domain.repository.ChannelRepository
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

data class ChannelUiState(
    val channel: Channel? = null,
    val videos: List<Video> = emptyList(),
    val isSubscribed: Boolean = false,
    val isLoading: Boolean = true,
    val isSubscribing: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class ChannelViewModel @Inject constructor(
    private val channelRepository: ChannelRepository,
    private val videoRepository: VideoRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(ChannelUiState())
    val uiState: StateFlow<ChannelUiState> = _uiState.asStateFlow()

    private var currentChannelId: String = ""

    fun loadChannel(channelId: String) {
        if (currentChannelId == channelId) return
        currentChannelId = channelId
        _uiState.update { it.copy(isLoading = true, error = null) }

        viewModelScope.launch {
            channelRepository.isSubscribed(channelId)
                .onSuccess { subscribed -> _uiState.update { it.copy(isSubscribed = subscribed) } }
        }

        channelRepository.observeChannel(channelId)
            .onEach { channel ->
                _uiState.update { it.copy(channel = channel, isLoading = false) }
            }
            .launchIn(viewModelScope)

        videoRepository.observeChannelVideos(channelId)
            .onEach { videos -> _uiState.update { it.copy(videos = videos) } }
            .launchIn(viewModelScope)
    }

    fun toggleSubscription() {
        val channelId = currentChannelId.ifBlank { return }
        val wasSubscribed = _uiState.value.isSubscribed
        _uiState.update { it.copy(isSubscribing = true) }
        viewModelScope.launch {
            val result = if (wasSubscribed) {
                channelRepository.unsubscribe(channelId)
            } else {
                channelRepository.subscribe(channelId)
            }
            result.onSuccess {
                _uiState.update { it.copy(isSubscribed = !wasSubscribed, isSubscribing = false) }
            }.onFailure {
                _uiState.update { it.copy(isSubscribing = false) }
            }
        }
    }
}
