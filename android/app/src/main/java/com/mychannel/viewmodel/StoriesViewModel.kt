package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mychannel.domain.model.StoryGroup
import com.mychannel.domain.repository.AuthRepository
import com.mychannel.domain.repository.VideoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class StoriesUiState(
    val isLoading: Boolean = true,
    val storyGroups: List<StoryGroup> = emptyList(),
    val activeGroupIndex: Int? = null,
    val activeStoryIndex: Int = 0,
    val error: String? = null
)

@HiltViewModel
class StoriesViewModel @Inject constructor(
    private val videoRepository: VideoRepository,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(StoriesUiState())
    val uiState: StateFlow<StoriesUiState> = _uiState.asStateFlow()

    init {
        loadStories()
    }

    private fun loadStories() {
        val uid = authRepository.currentUserId ?: run {
            _uiState.update { it.copy(isLoading = false) }
            return
        }
        viewModelScope.launch {
            try {
                val groups = videoRepository.fetchStoriesForSubscriptions(uid)
                _uiState.update { it.copy(isLoading = false, storyGroups = groups) }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun openStoryGroup(index: Int) {
        _uiState.update { it.copy(activeGroupIndex = index, activeStoryIndex = 0) }
    }

    fun closeStories() {
        _uiState.update { it.copy(activeGroupIndex = null, activeStoryIndex = 0) }
    }

    fun nextStory() {
        val state = _uiState.value
        val groupIdx = state.activeGroupIndex ?: return
        val group = state.storyGroups.getOrNull(groupIdx) ?: return
        if (state.activeStoryIndex < group.stories.size - 1) {
            _uiState.update { it.copy(activeStoryIndex = it.activeStoryIndex + 1) }
        } else if (groupIdx < state.storyGroups.size - 1) {
            _uiState.update { it.copy(activeGroupIndex = groupIdx + 1, activeStoryIndex = 0) }
        } else {
            closeStories()
        }
    }

    fun prevStory() {
        val state = _uiState.value
        if (state.activeStoryIndex > 0) {
            _uiState.update { it.copy(activeStoryIndex = it.activeStoryIndex - 1) }
        } else {
            val groupIdx = state.activeGroupIndex ?: return
            if (groupIdx > 0) {
                val prevGroup = state.storyGroups[groupIdx - 1]
                _uiState.update {
                    it.copy(
                        activeGroupIndex = groupIdx - 1,
                        activeStoryIndex = prevGroup.stories.size - 1
                    )
                }
            }
        }
    }

    fun markCurrentSeen() {
        val state = _uiState.value
        val groupIdx = state.activeGroupIndex ?: return
        val uid = authRepository.currentUserId ?: return
        val story = state.storyGroups.getOrNull(groupIdx)
            ?.stories?.getOrNull(state.activeStoryIndex) ?: return
        viewModelScope.launch {
            videoRepository.markStorySeen(uid, story.id)
        }
    }
    }
}
