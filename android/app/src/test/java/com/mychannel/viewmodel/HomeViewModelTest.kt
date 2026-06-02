package com.mychannel.viewmodel

import androidx.paging.PagingData
import com.google.common.truth.Truth.assertThat
import com.mychannel.domain.model.LiveStream
import com.mychannel.domain.model.Story
import com.mychannel.domain.model.Video
import com.mychannel.domain.repository.VideoRepository
import com.mychannel.domain.model.Comment
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test

/**
 * Unit tests for [HomeViewModel] (REQ-4.1 – REQ-4.6).
 *
 * Uses a hand-rolled fake [VideoRepository] (no Firebase / no Paging assertions)
 * to verify state transitions for the real-time Home sections and the filter
 * selection logic. Paging content is out of scope (would require
 * paging-testing); we only assert the filter drives feed re-subscription via
 * the public state.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class HomeViewModelTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var repository: FakeVideoRepository

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        repository = FakeVideoRepository()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun createViewModel() = HomeViewModel(repository)

    @Test
    fun `initial state is loading with default filter`() = runTest {
        val viewModel = createViewModel()
        // Before the dispatcher runs the launched flows, state is the initial value.
        assertThat(viewModel.uiState.value.isLoading).isTrue()
        assertThat(viewModel.uiState.value.selectedFilter).isEqualTo("All")
    }

    @Test
    fun `trending emission populates state and clears loading`() = runTest {
        val viewModel = createViewModel()
        val videos = listOf(Video(id = "v1", title = "One"), Video(id = "v2", title = "Two"))

        repository.trending.value = videos
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertThat(state.isLoading).isFalse()
        assertThat(state.trendingVideos).isEqualTo(videos)
        assertThat(state.recommendedVideos).isEqualTo(videos)
        assertThat(state.error).isNull()
    }

    @Test
    fun `live streams emission populates state`() = runTest {
        val viewModel = createViewModel()
        val streams = listOf(LiveStream(id = "s1", title = "Stream"))

        repository.live.value = streams
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.liveStreams).isEqualTo(streams)
    }

    @Test
    fun `stories emission populates state`() = runTest {
        val viewModel = createViewModel()
        val stories = listOf(Story(id = "st1", creatorName = "Creator", isLive = true))

        repository.stories.value = stories
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.stories).isEqualTo(stories)
    }

    @Test
    fun `trending error surfaces error message and stops loading`() = runTest {
        repository.trendingThrows = true
        val viewModel = createViewModel()

        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertThat(state.isLoading).isFalse()
        assertThat(state.error).isNotNull()
    }

    @Test
    fun `selectFilter updates selected filter and category for category chip`() = runTest {
        val viewModel = createViewModel()
        // Collect the paging feed so the cachedIn upstream (flatMapLatest) runs.
        backgroundScope.launch { viewModel.recommendedFeed.collect {} }
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.selectFilter("Gaming")
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.selectedFilter).isEqualTo("Gaming")
        // "Gaming" maps to a lowercase category constraint.
        assertThat(repository.lastRequestedCategory).isEqualTo("gaming")
    }

    @Test
    fun `selectFilter All leaves recommended feed unconstrained`() = runTest {
        val viewModel = createViewModel()
        backgroundScope.launch { viewModel.recommendedFeed.collect {} }
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.selectFilter("Music")
        testDispatcher.scheduler.advanceUntilIdle()
        assertThat(repository.lastRequestedCategory).isEqualTo("music")

        viewModel.selectFilter("All")
        testDispatcher.scheduler.advanceUntilIdle()
        assertThat(viewModel.uiState.value.selectedFilter).isEqualTo("All")
        assertThat(repository.lastRequestedCategory).isNull()
    }

    @Test
    fun `selecting same filter twice is a no-op`() = runTest {
        val viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.selectFilter("Live")
        testDispatcher.scheduler.advanceUntilIdle()
        val filterAfterFirst = viewModel.uiState.value.selectedFilter

        viewModel.selectFilter("Live")
        testDispatcher.scheduler.advanceUntilIdle()

        // Filter is unchanged and remains "Live".
        assertThat(viewModel.uiState.value.selectedFilter).isEqualTo(filterAfterFirst)
        assertThat(viewModel.uiState.value.selectedFilter).isEqualTo("Live")
    }

    @Test
    fun `retry re-subscribes and clears prior error`() = runTest {
        repository.trendingThrows = true
        val viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        assertThat(viewModel.uiState.value.error).isNotNull()

        // Recover: stop throwing and retry.
        repository.trendingThrows = false
        viewModel.retry()
        repository.trending.value = listOf(Video(id = "v9", title = "Recovered"))
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertThat(state.error).isNull()
        assertThat(state.trendingVideos).hasSize(1)
    }

    /**
     * Hand-rolled fake [VideoRepository]. Real-time sections are backed by
     * [MutableStateFlow]s so tests can drive emissions; the paginated feed is a
     * trivial flow and its [recommendedFeed] arg is recorded for verification.
     */
    private class FakeVideoRepository : VideoRepository {
        val trending = MutableStateFlow<List<Video>>(emptyList())
        val live = MutableStateFlow<List<LiveStream>>(emptyList())
        val stories = MutableStateFlow<List<Story>>(emptyList())

        var trendingThrows = false
        var lastRequestedCategory: String? = null
        var recommendedFeedCalls = 0

        override fun observeTrending(): Flow<List<Video>> =
            if (trendingThrows) flow { throw IllegalStateException("boom") } else trending

        override fun recommendedFeed(category: String?): Flow<PagingData<Video>> {
            recommendedFeedCalls++
            lastRequestedCategory = category
            return flowOf(PagingData.empty())
        }

        override fun observeLiveStreams(): Flow<List<LiveStream>> = live

        override fun observeStories(): Flow<List<Story>> = stories

        override fun observeChannelVideos(channelId: String): Flow<List<Video>> = flowOf(emptyList())

        override fun observeShorts(): Flow<List<Video>> = flowOf(emptyList())

        override suspend fun getVideo(videoId: String): Result<Video> =
            Result.success(Video(id = videoId))

        override fun observeComments(videoId: String): Flow<List<Comment>> = flowOf(emptyList())

        override suspend fun postComment(
            videoId: String,
            text: String,
            parentId: String?
        ): Result<Comment> = Result.success(Comment(id = "c1", videoId = videoId, text = text))

        override suspend fun toggleLike(videoId: String, like: Boolean): Result<Unit> =
            Result.success(Unit)

        override suspend fun incrementViewCount(videoId: String): Result<Unit> =
            Result.success(Unit)
    }
}
