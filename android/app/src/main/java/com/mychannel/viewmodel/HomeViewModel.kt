package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.paging.PagingData
import androidx.paging.cachedIn
import com.mychannel.domain.model.LiveStream
import com.mychannel.domain.model.Story
import com.mychannel.domain.model.Video
import com.mychannel.domain.repository.VideoRepository
import com.mychannel.ui.components.HomeFilters
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * State for the Home screen (REQ-4.x).
 *
 * The paginated recommended feed is exposed separately as a
 * [androidx.paging.PagingData] flow; this state holds the one-shot/real-time
 * sections (trending, live, stories) plus the loading/error/filter chrome.
 */
data class HomeUiState(
    val isLoading: Boolean = true,
    val trendingVideos: List<Video> = emptyList(),
    val recommendedVideos: List<Video> = emptyList(),
    val liveStreams: List<LiveStream> = emptyList(),
    val stories: List<Story> = emptyList(),
    val selectedFilter: String = "All",
    val error: String? = null
)

/**
 * ViewModel for the Home screen (REQ-4.1 – REQ-4.6).
 *
 * - `trendingVideos`, `liveStreams`, and `stories` stream in real time from
 *   Firestore via the [VideoRepository].
 * - `recommendedFeed` is a Paging 3 [PagingData] flow that reacts to the
 *   selected filter and is cached in [viewModelScope].
 * - [selectFilter] switches the active filter; [retry] re-subscribes the
 *   real-time sections; [loadFeed] is the initial subscription kickoff.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class HomeViewModel @Inject constructor(
    private val videoRepository: VideoRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    /** Drives the recommended Paging feed; null = no category constraint. */
    private val selectedCategory = MutableStateFlow<String?>(null)

    /**
     * Paginated recommended feed (REQ-4.5). Switches source whenever the
     * selected category changes and survives configuration changes via
     * [cachedIn].
     */
    val recommendedFeed: Flow<PagingData<Video>> =
        selectedCategory
            .flatMapLatest { category -> videoRepository.recommendedFeed(category) }
            .cachedIn(viewModelScope)

    init {
        loadFeed()
        loadPersonalizedRecommendations()
    }

    /** Subscribes to the real-time Home sections (trending, live, stories). */
    fun loadFeed() {
        _uiState.update { it.copy(isLoading = true, error = null) }
        observeTrending()
        observeLiveStreams()
        observeStories()
    }

    /**
     * Loads personalized recommendations from the recommendation service
     * (hybrid: content-based 70% + collaborative filtering 30%).
     * Falls back to trending on failure. Replaces the generic trending feed
     * in recommendedVideos once loaded.
     */
    private fun loadPersonalizedRecommendations() {
        viewModelScope.launch {
            videoRepository.fetchPersonalizedRecommendations(limit = 24)
                .onSuccess { personalized ->
                    if (personalized.isNotEmpty()) {
                        _uiState.update { it.copy(recommendedVideos = personalized) }
                    }
                }
            // On failure: recommendedVideos stays as trending (already populated by observeTrending)
        }
    }

    private fun observeTrending() {
        videoRepository.observeTrending()
            .onEach { videos ->
                _uiState.update {
                    it.copy(
                        trendingVideos = videos,
                        recommendedVideos = videos,
                        isLoading = false,
                        error = null
                    )
                }
            }
            .catch { throwable ->
                _uiState.update {
                    it.copy(isLoading = false, error = throwable.message ?: "Failed to load feed")
                }
            }
            .launchIn(viewModelScope)
    }

    private fun observeLiveStreams() {
        videoRepository.observeLiveStreams()
            .onEach { streams -> _uiState.update { it.copy(liveStreams = streams) } }
            .catch { /* Live section is non-critical; ignore transient errors. */ }
            .launchIn(viewModelScope)
    }

    private fun observeStories() {
        videoRepository.observeStories()
            .onEach { stories -> _uiState.update { it.copy(stories = stories) } }
            .catch { /* Stories section is non-critical; ignore transient errors. */ }
            .launchIn(viewModelScope)
    }

    /**
     * Applies a Home filter (REQ-4.1). "All", "Live", and "Shorts" do not map to
     * a Firestore `category`, so they leave the recommended feed unconstrained;
     * other chips constrain the paginated feed by lowercase category.
     */
    fun selectFilter(filter: String) {
        if (filter == _uiState.value.selectedFilter) return
        _uiState.update { it.copy(selectedFilter = filter) }
        selectedCategory.value = when (filter) {
            "All", "Live", "Shorts" -> null
            else -> filter.lowercase()
        }
    }

    /** Re-subscribes the real-time sections after an error. */
    fun retry() {
        loadFeed()
    }

    /** Exposed for callers/tests that need the canonical filter list. */
    val filters: List<String> get() = HomeFilters
}
