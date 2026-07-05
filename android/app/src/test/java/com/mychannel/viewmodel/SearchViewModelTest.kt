package com.mychannel.viewmodel

import com.google.common.truth.Truth.assertThat
import com.mychannel.domain.model.Channel
import com.mychannel.domain.model.Video
import com.mychannel.domain.repository.SearchRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test

/**
 * Unit tests for [SearchViewModel] (REQ-6.x).
 *
 * Uses a hand-rolled fake [SearchRepository] to verify the debounced live
 * search, history observation/persistence, trending load, and result mapping
 * without touching Firestore or Room.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class SearchViewModelTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var repository: FakeSearchRepository

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        repository = FakeSearchRepository()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun createViewModel() = SearchViewModel(repository)

    @Test
    fun `initial state is empty with suggestions shown`() = runTest {
        val viewModel = createViewModel()
        val state = viewModel.uiState.value
        assertThat(state.query).isEmpty()
        assertThat(state.hasResults).isFalse()
        assertThat(state.showSuggestions).isTrue()
    }

    @Test
    fun `trending searches load on init`() = runTest {
        repository.trending = listOf("gaming", "music")
        val viewModel = createViewModel()

        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.trendingSearches).containsExactly("gaming", "music")
    }

    @Test
    fun `search history emissions populate state`() = runTest {
        val viewModel = createViewModel()

        repository.history.value = listOf("cats", "dogs")
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.searchHistory).containsExactly("cats", "dogs")
    }

    @Test
    fun `onQueryChange triggers debounced search and populates results`() = runTest {
        repository.videos = listOf(Video(id = "v1", title = "Match"))
        repository.channels = listOf(Channel(id = "c1"))
        val viewModel = createViewModel()

        viewModel.onQueryChange("mat")
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertThat(state.videoResults).hasSize(1)
        assertThat(state.channelResults).hasSize(1)
        assertThat(state.hasResults).isTrue()
        assertThat(state.isSearching).isFalse()
    }

    @Test
    fun `single-character query does not trigger search`() = runTest {
        repository.videos = listOf(Video(id = "v1", title = "Match"))
        val viewModel = createViewModel()

        viewModel.onQueryChange("m")
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.videoResults).isEmpty()
    }

    @Test
    fun `clearing the query wipes results`() = runTest {
        repository.videos = listOf(Video(id = "v1", title = "Match"))
        val viewModel = createViewModel()

        viewModel.onQueryChange("match")
        testDispatcher.scheduler.advanceUntilIdle()
        assertThat(viewModel.uiState.value.videoResults).isNotEmpty()

        viewModel.onQueryChange("")
        testDispatcher.scheduler.advanceUntilIdle()
        assertThat(viewModel.uiState.value.videoResults).isEmpty()
    }

    @Test
    fun `search persists the query to history`() = runTest {
        val viewModel = createViewModel()

        viewModel.search("skateboarding")
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(repository.addedToHistory).contains("skateboarding")
    }

    @Test
    fun `blank search is a no-op`() = runTest {
        val viewModel = createViewModel()

        viewModel.search("   ")
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(repository.addedToHistory).isEmpty()
    }

    @Test
    fun `search error surfaces the error message`() = runTest {
        repository.videosThrow = true
        val viewModel = createViewModel()

        viewModel.onQueryChange("boom")
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.error).isNotNull()
        assertThat(viewModel.uiState.value.isSearching).isFalse()
    }

    @Test
    fun `removeFromHistory and clearHistory delegate to repository`() = runTest {
        val viewModel = createViewModel()

        viewModel.removeFromHistory("cats")
        viewModel.clearHistory()
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(repository.removedFromHistory).contains("cats")
        assertThat(repository.historyCleared).isTrue()
    }

    /**
     * Hand-rolled fake [SearchRepository]. History is a [MutableStateFlow] so
     * tests can drive emissions; search results and trending are plain fields.
     */
    private class FakeSearchRepository : SearchRepository {
        val history = MutableStateFlow<List<String>>(emptyList())
        var videos: List<Video> = emptyList()
        var channels: List<Channel> = emptyList()
        var trending: List<String> = emptyList()

        var videosThrow = false
        val addedToHistory = mutableListOf<String>()
        val removedFromHistory = mutableListOf<String>()
        var historyCleared = false

        override suspend fun searchVideos(query: String): Result<List<Video>> =
            if (videosThrow) Result.failure(IllegalStateException("boom")) else Result.success(videos)

        override suspend fun searchChannels(query: String): Result<List<Channel>> =
            Result.success(channels)

        override fun observeSearchHistory(): Flow<List<String>> = history

        override suspend fun addToHistory(query: String) {
            addedToHistory += query
        }

        override suspend fun removeFromHistory(query: String) {
            removedFromHistory += query
        }

        override suspend fun clearHistory() {
            historyCleared = true
        }

        override suspend fun getTrendingSearches(): Result<List<String>> =
            Result.success(trending)
    }
}
