package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mychannel.domain.model.Comment
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

data class VideoPlayerUiState(
    val video: Video? = null,
    val comments: List<Comment> = emptyList(),
    val suggested: List<Video> = emptyList(),
    val isLiked: Boolean = false,
    val isSaved: Boolean = false,
    val isSubscribed: Boolean = false,
    val isLoading: Boolean = true,
    val error: String? = null
)

@HiltViewModel
class VideoPlayerViewModel @Inject constructor(
    private val videoRepository: VideoRepository,
    private val channelRepository: ChannelRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(VideoPlayerUiState())
    val uiState: StateFlow<VideoPlayerUiState> = _uiState.asStateFlow()

    private var currentVideoId: String = ""

    fun loadVideo(videoId: String) {
        if (currentVideoId == videoId) return
        currentVideoId = videoId
        _uiState.update { it.copy(isLoading = true, error = null) }

        viewModelScope.launch {
            videoRepository.getVideo(videoId)
                .onSuccess { video ->
                    _uiState.update { it.copy(video = video, isLoading = false) }
                    videoRepository.incrementViewCount(videoId)
                    // Load per-user state (like / save / subscribe) in parallel
                    videoRepository.isLiked(videoId).onSuccess { liked -> _uiState.update { it.copy(isLiked = liked) } }
                    videoRepository.isSaved(videoId).onSuccess { saved -> _uiState.update { it.copy(isSaved = saved) } }
                    channelRepository.isSubscribed(video.channelId).onSuccess { sub -> _uiState.update { it.copy(isSubscribed = sub) } }
                }
                .onFailure { e ->
                    _uiState.update { it.copy(isLoading = false, error = e.message) }
                }
        }

        videoRepository.observeComments(videoId)
            .onEach { comments ->
                _uiState.update { it.copy(comments = comments) }
            }
            .launchIn(viewModelScope)

        // Suggested / up-next: reuse the trending feed, excluding the current video
        videoRepository.observeTrending()
            .onEach { videos ->
                _uiState.update { state ->
                    state.copy(suggested = videos.filter { it.id != videoId }.take(20))
                }
            }
            .launchIn(viewModelScope)
    }

    fun toggleLike(like: Boolean) {
        val videoId = currentVideoId.ifBlank { return }
        val next = if (like) !_uiState.value.isLiked else false
        viewModelScope.launch {
            videoRepository.toggleLike(videoId, next)
                .onSuccess { _uiState.update { it.copy(isLiked = next) } }
        }
    }

    fun toggleSave() {
        val video = _uiState.value.video ?: return
        val next = !_uiState.value.isSaved
        _uiState.update { it.copy(isSaved = next) } // optimistic
        viewModelScope.launch {
            videoRepository.setSaved(video, next)
                .onFailure { _uiState.update { it.copy(isSaved = !next) } } // rollback
        }
    }

    fun toggleSubscribe() {
        val channelId = _uiState.value.video?.channelId ?: return
        val next = !_uiState.value.isSubscribed
        _uiState.update { it.copy(isSubscribed = next) } // optimistic
        viewModelScope.launch {
            val result = if (next) channelRepository.subscribe(channelId) else channelRepository.unsubscribe(channelId)
            result.onFailure { _uiState.update { it.copy(isSubscribed = !next) } } // rollback
        }
    }

    fun postComment(text: String, parentId: String? = null) {
        val videoId = currentVideoId.ifBlank { return }
        viewModelScope.launch {
            videoRepository.postComment(videoId, text, parentId)
        }
    }
}
