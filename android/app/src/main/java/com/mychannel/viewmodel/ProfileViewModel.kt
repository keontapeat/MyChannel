package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mychannel.domain.model.Video
import com.mychannel.domain.repository.AuthRepository
import com.mychannel.domain.repository.ChannelRepository
import com.mychannel.domain.repository.VideoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ProfileUiState(
    val isLoading: Boolean = true,
    val isOwnProfile: Boolean = false,
    val displayName: String = "",
    val username: String = "",
    val avatarUrl: String = "",
    val bannerUrl: String = "",
    val bio: String = "",
    val joinedDate: String = "",
    val totalViews: Long = 0L,
    val subscriberCount: Long = 0L,
    val videoCount: Int = 0,
    val location: String = "",
    val links: List<String> = emptyList(),
    val videos: List<Video> = emptyList(),
    val isSubscribed: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val channelRepository: ChannelRepository,
    private val videoRepository: VideoRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    private var targetChannelId: String = ""

    init {
        // Default: load own profile
        loadProfile(null)
    }

    fun loadProfile(channelId: String?) {
        val currentUserId = authRepository.currentUserId ?: run {
            _uiState.update { it.copy(isLoading = false, error = "Sign in to view your profile") }
            return
        }
        targetChannelId = channelId ?: currentUserId
        val isOwn = targetChannelId == currentUserId

        _uiState.update { it.copy(isLoading = true, error = null, isOwnProfile = isOwn) }

        combine(
            channelRepository.observeChannel(targetChannelId),
            videoRepository.observeChannelVideos(targetChannelId)
        ) { channel, videos ->
            _uiState.update {
                it.copy(
                    isLoading = false,
                    displayName = channel?.displayName ?: "",
                    username = channel?.username ?: "",
                    avatarUrl = channel?.avatarUrl ?: "",
                    bannerUrl = channel?.bannerUrl ?: "",
                    bio = channel?.bio ?: "",
                    joinedDate = channel?.createdAt ?: "",
                    totalViews = channel?.totalViewCount ?: 0L,
                    subscriberCount = channel?.subscriberCount ?: 0L,
                    videoCount = videos.size,
                    location = channel?.location ?: "",
                    links = channel?.links ?: emptyList(),
                    videos = videos
                )
            }
        }
            .catch { e -> _uiState.update { it.copy(isLoading = false, error = e.message) } }
            .launchIn(viewModelScope)

        // Check subscription state if viewing another channel
        if (!isOwn) {
            viewModelScope.launch {
                channelRepository.isSubscribed(targetChannelId)
                    .onSuccess { subscribed -> _uiState.update { it.copy(isSubscribed = subscribed) } }
            }
        }
    }

    fun toggleSubscribe() {
        viewModelScope.launch {
            val currentlySubscribed = _uiState.value.isSubscribed
            if (currentlySubscribed) {
                channelRepository.unsubscribe(targetChannelId)
            } else {
                channelRepository.subscribe(targetChannelId)
            }
            _uiState.update { it.copy(isSubscribed = !currentlySubscribed) }
        }
    }
}
