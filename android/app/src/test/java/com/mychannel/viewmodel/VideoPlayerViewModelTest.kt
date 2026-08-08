package com.mychannel.viewmodel

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.emptyPreferences
import com.google.common.truth.Truth.assertThat
import com.mychannel.data.remote.ModerationDataSource
import com.mychannel.domain.model.Channel
import com.mychannel.domain.model.Comment
import com.mychannel.domain.model.LiveStream
import com.mychannel.domain.model.PlaybackSession
import com.mychannel.domain.model.Story
import com.mychannel.domain.model.Video
import com.mychannel.domain.repository.ChannelRepository
import com.mychannel.domain.repository.PlaybackSessionRepository
import com.mychannel.domain.repository.VideoRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever

/**
 * Unit tests for [VideoPlayerViewModel] (REQ-5.x).
 *
 * The ExoPlayer instance lives in the composable, so the ViewModel is pure
 * repository-driven logic and fully testable on the JVM with hand-rolled fakes.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class VideoPlayerViewModelTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var videoRepo: FakeVideoRepository
    private lateinit var channelRepo: FakeChannelRepository
    private lateinit var playbackRepo: FakePlaybackSessionRepository
    private lateinit var moderationDataSource: ModerationDataSource
    private lateinit var dataStore: DataStore<Preferences>

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        videoRepo = FakeVideoRepository()
        channelRepo = FakeChannelRepository()
        playbackRepo = FakePlaybackSessionRepository()
        moderationDataSource = mock()
        dataStore = mock()
        whenever(dataStore.data).thenReturn(flowOf(emptyPreferences()))
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun createViewModel() = VideoPlayerViewModel(
        videoRepo,
        channelRepo,
        playbackRepo,
        moderationDataSource,
        dataStore
    )

    @Test
    fun `loadVideo populates video and clears loading`() = runTest {
        videoRepo.video = Video(id = "v1", title = "Clip", channelId = "c1")
        val viewModel = createViewModel()

        viewModel.loadVideo("v1")
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertThat(state.video?.id).isEqualTo("v1")
        assertThat(state.isLoading).isFalse()
        assertThat(state.error).isNull()
    }

    @Test
    fun `loadVideo does not count a view before qualified playback`() = runTest {
        videoRepo.video = Video(id = "v1", channelId = "c1")
        val viewModel = createViewModel()

        viewModel.loadVideo("v1")
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(playbackRepo.watchTimeReports).isEqualTo(0)
    }

    @Test
    fun `qualified playback counts a view once`() = runTest {
        videoRepo.video = Video(id = "v1", channelId = "c1")
        val viewModel = createViewModel()
        viewModel.loadVideo("v1")
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.recordQualifiedView("v1")
        viewModel.recordQualifiedView("v1")
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(playbackRepo.watchTimeReports).isEqualTo(1)
        assertThat(playbackRepo.lastQualifiedView).isTrue()
    }

    @Test
    fun `loadVideo hydrates like save and subscribe state`() = runTest {
        videoRepo.video = Video(id = "v1", channelId = "c1")
        videoRepo.liked = true
        videoRepo.saved = true
        channelRepo.subscribed = true
        val viewModel = createViewModel()

        viewModel.loadVideo("v1")
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertThat(state.isLiked).isTrue()
        assertThat(state.isSaved).isTrue()
        assertThat(state.isSubscribed).isTrue()
    }

    @Test
    fun `loadVideo failure surfaces error`() = runTest {
        videoRepo.getVideoThrows = true
        val viewModel = createViewModel()

        viewModel.loadVideo("v1")
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertThat(state.isLoading).isFalse()
        assertThat(state.error).isNotNull()
    }

    @Test
    fun `loading the same video twice is a no-op`() = runTest {
        videoRepo.video = Video(id = "v1", channelId = "c1")
        val viewModel = createViewModel()

        viewModel.loadVideo("v1")
        testDispatcher.scheduler.advanceUntilIdle()
        viewModel.loadVideo("v1")
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(playbackRepo.authorizationCalls).isEqualTo(1)
    }

    @Test
    fun `comments stream populates state`() = runTest {
        videoRepo.video = Video(id = "v1", channelId = "c1")
        val viewModel = createViewModel()
        backgroundScope.launch { viewModel.uiState.collect {} }

        viewModel.loadVideo("v1")
        videoRepo.comments.value = listOf(Comment(id = "cm1", videoId = "v1", text = "nice"))
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.comments).hasSize(1)
    }

    @Test
    fun `suggested excludes the current video`() = runTest {
        videoRepo.video = Video(id = "v1", channelId = "c1")
        val viewModel = createViewModel()
        backgroundScope.launch { viewModel.uiState.collect {} }

        viewModel.loadVideo("v1")
        videoRepo.trending.value = listOf(
            Video(id = "v1", title = "current", processingStatus = "ready", moderationStatus = "approved"),
            Video(id = "v2", title = "other", processingStatus = "ready", moderationStatus = "approved")
        )
        testDispatcher.scheduler.advanceUntilIdle()

        val suggested = viewModel.uiState.value.suggested
        assertThat(suggested.map { it.id }).containsExactly("v2")
    }

    @Test
    fun `toggleSave is optimistic and rolls back on failure`() = runTest {
        videoRepo.video = Video(id = "v1", channelId = "c1")
        videoRepo.setSavedThrows = true
        val viewModel = createViewModel()
        viewModel.loadVideo("v1")
        testDispatcher.scheduler.advanceUntilIdle()
        assertThat(viewModel.uiState.value.isSaved).isFalse()

        viewModel.toggleSave()
        // Optimistic flip happens synchronously before the coroutine resolves.
        assertThat(viewModel.uiState.value.isSaved).isTrue()

        testDispatcher.scheduler.advanceUntilIdle()
        // Failure rolls the optimistic update back.
        assertThat(viewModel.uiState.value.isSaved).isFalse()
    }

    @Test
    fun `toggleSubscribe is optimistic and rolls back on failure`() = runTest {
        videoRepo.video = Video(id = "v1", channelId = "c1")
        channelRepo.subscribeThrows = true
        val viewModel = createViewModel()
        viewModel.loadVideo("v1")
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.toggleSubscribe()
        assertThat(viewModel.uiState.value.isSubscribed).isTrue()

        testDispatcher.scheduler.advanceUntilIdle()
        assertThat(viewModel.uiState.value.isSubscribed).isFalse()
    }

    @Test
    fun `toggleLike before a video is loaded is a no-op`() = runTest {
        val viewModel = createViewModel()

        viewModel.toggleLike()
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.isLiked).isFalse()
        assertThat(videoRepo.toggleLikeCalls).isEqualTo(0)
    }

    private class FakePlaybackSessionRepository : PlaybackSessionRepository {
        var authorizationCalls = 0
        var watchTimeReports = 0
        var lastQualifiedView = false
        var failure: Throwable? = null

        override suspend fun authorize(videoId: String): Result<PlaybackSession> {
            authorizationCalls++
            failure?.let { return Result.failure(it) }
            return Result.success(
                PlaybackSession(
                    sessionId = "session-$videoId",
                    videoId = videoId,
                    manifestUrl = "https://storage.googleapis.com/test/$videoId.m3u8",
                    expiresAtEpochMs = null,
                    adsEnabled = false,
                    supportsHls = true,
                    supportsDash = false,
                    supportsCaptions = true,
                    supportsOfflineDownload = false,
                    supportsPictureInPicture = true,
                    supportsCasting = true
                )
            )
        }

        override suspend fun reportWatchTime(
            videoId: String,
            sessionId: String,
            watchTimeSeconds: Int,
            completionRate: Double?,
            qualifiedView: Boolean
        ): Result<Unit> {
            watchTimeReports++
            lastQualifiedView = qualifiedView
            return Result.success(Unit)
        }
    }

    private class FakeVideoRepository : VideoRepository {
        var video: Video = Video(id = "v1", channelId = "c1")
        var getVideoThrows = false
        var liked = false
        var saved = false
        var setSavedThrows = false
        var viewCountIncrements = 0
        var toggleLikeCalls = 0
        val comments = MutableStateFlow<List<Comment>>(emptyList())
        val trending = MutableStateFlow<List<Video>>(emptyList())

        override fun observeTrending(): Flow<List<Video>> = trending
        override fun recommendedFeed(category: String?) = flowOf<androidx.paging.PagingData<Video>>(androidx.paging.PagingData.empty())
        override fun observeLiveStreams(): Flow<List<LiveStream>> = flowOf(emptyList())
        override fun observeStories(): Flow<List<Story>> = flowOf(emptyList())
        override fun observeChannelVideos(channelId: String): Flow<List<Video>> = flowOf(emptyList())
        override fun observeShorts(): Flow<List<Video>> = flowOf(emptyList())

        override suspend fun getVideo(videoId: String): Result<Video> =
            if (getVideoThrows) Result.failure(IllegalStateException("boom")) else Result.success(video)

        override fun observeComments(videoId: String): Flow<List<Comment>> = comments

        override suspend fun postComment(videoId: String, text: String, parentId: String?): Result<Comment> =
            Result.success(Comment(id = "c1", videoId = videoId, text = text))

        override suspend fun toggleLike(videoId: String, like: Boolean): Result<Unit> {
            toggleLikeCalls++
            return Result.success(Unit)
        }

        override suspend fun toggleDislike(videoId: String, dislike: Boolean): Result<Unit> =
            Result.success(Unit)

        override suspend fun isLiked(videoId: String): Result<Boolean> = Result.success(liked)
        override suspend fun isDisliked(videoId: String): Result<Boolean> = Result.success(false)
        override suspend fun isSaved(videoId: String): Result<Boolean> = Result.success(saved)

        override suspend fun setSaved(video: Video, save: Boolean): Result<Unit> =
            if (setSavedThrows) Result.failure(IllegalStateException("boom")) else Result.success(Unit)

        override suspend fun incrementViewCount(videoId: String): Result<Unit> {
            viewCountIncrements++
            return Result.success(Unit)
        }

        override fun observeDownloads(userId: String): Flow<List<Video>> = flowOf(emptyList())
        override suspend fun deleteDownload(userId: String, videoId: String): Result<Unit> = Result.success(Unit)
    }

    private class FakeChannelRepository : ChannelRepository {
        var subscribed = false
        var subscribeThrows = false

        override fun observeChannel(channelId: String): Flow<Channel?> = flowOf(null)
        override suspend fun getChannel(channelId: String): Result<Channel> = Result.success(Channel(id = channelId))

        override suspend fun subscribe(channelId: String): Result<Unit> =
            if (subscribeThrows) Result.failure(IllegalStateException("boom")) else Result.success(Unit)

        override suspend fun unsubscribe(channelId: String): Result<Unit> =
            if (subscribeThrows) Result.failure(IllegalStateException("boom")) else Result.success(Unit)

        override suspend fun isSubscribed(channelId: String): Result<Boolean> = Result.success(subscribed)
        override fun observeSubscriptions(): Flow<List<Channel>> = flowOf(emptyList())
    }
}
