package com.mychannel.viewmodel

import android.net.Uri
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.workDataOf
import com.google.common.truth.Truth.assertThat
import com.mychannel.services.UploadWorker
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.mockito.kotlin.any
import org.mockito.kotlin.doReturn
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.times
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import java.util.UUID

/**
 * Unit tests for [UploadViewModel] (REQ-8.1, REQ-8.2, REQ-8.6).
 *
 * [WorkManager] is mocked; its `getWorkInfoByIdFlow` is backed by a
 * [MutableStateFlow] the test drives to simulate work progress / completion.
 * The ViewModel never touches the Android runtime directly (URIs are kept as
 * strings), so no Robolectric is needed.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class UploadViewModelTest {

    private val testDispatcher = StandardTestDispatcher()

    private lateinit var workManager: WorkManager
    private lateinit var workInfoFlow: MutableStateFlow<WorkInfo?>
    private lateinit var viewModel: UploadViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        workManager = mock()
        workInfoFlow = MutableStateFlow(null)
        // Any work id observation resolves to our controllable flow.
        whenever(workManager.getWorkInfoByIdFlow(any())).thenReturn(workInfoFlow)
        viewModel = UploadViewModel(workManager)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun mockUri(value: String): Uri = mock<Uri> { on { toString() } doReturn value }

    @Test
    fun `initial state is idle`() {
        assertThat(viewModel.uiState.value.status).isEqualTo(UploadStatus.Idle)
        assertThat(viewModel.uiState.value.canStartUpload).isFalse()
    }

    @Test
    fun `selectVideo moves to selecting and records uri`() {
        viewModel.selectVideo(mockUri("content://video/1"), durationSeconds = 42L)

        val state = viewModel.uiState.value
        assertThat(state.status).isEqualTo(UploadStatus.Selecting)
        assertThat(state.videoUri).isEqualTo("content://video/1")
        assertThat(state.durationSeconds).isEqualTo(42L)
    }

    @Test
    fun `canStartUpload requires both video and title`() {
        viewModel.selectVideo(mockUri("content://video/1"))
        assertThat(viewModel.uiState.value.canStartUpload).isFalse()

        viewModel.updateTitle("My Video")
        assertThat(viewModel.uiState.value.canStartUpload).isTrue()
    }

    @Test
    fun `startUpload without video sets error and does not enqueue`() {
        viewModel.startUpload()

        assertThat(viewModel.uiState.value.status).isInstanceOf(UploadStatus.Error::class.java)
        verify(workManager, never()).enqueueUniqueWork(any(), any(), any<androidx.work.OneTimeWorkRequest>())
    }

    @Test
    fun `startUpload without title sets error`() {
        viewModel.selectVideo(mockUri("content://video/1"))

        viewModel.startUpload()

        assertThat(viewModel.uiState.value.status).isInstanceOf(UploadStatus.Error::class.java)
    }

    @Test
    fun `startUpload enqueues work and enters uploading state`() = runTest {
        viewModel.selectVideo(mockUri("content://video/1"))
        viewModel.updateTitle("My Video")

        viewModel.startUpload()
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.status).isEqualTo(UploadStatus.Uploading(0))
        verify(workManager, times(1)).enqueueUniqueWork(
            any(),
            any(),
            any<androidx.work.OneTimeWorkRequest>()
        )
    }

    @Test
    fun `running work info updates progress`() = runTest {
        viewModel.selectVideo(mockUri("content://video/1"))
        viewModel.updateTitle("My Video")
        viewModel.startUpload()
        testDispatcher.scheduler.advanceUntilIdle()

        workInfoFlow.value = runningInfo(progress = 57)
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.status).isEqualTo(UploadStatus.Uploading(57))
    }

    @Test
    fun `running work at full progress transitions to processing`() = runTest {
        viewModel.selectVideo(mockUri("content://video/1"))
        viewModel.updateTitle("My Video")
        viewModel.startUpload()
        testDispatcher.scheduler.advanceUntilIdle()

        workInfoFlow.value = runningInfo(progress = 100)
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.status).isEqualTo(UploadStatus.Processing)
    }

    @Test
    fun `succeeded work info transitions to complete with video id`() = runTest {
        viewModel.selectVideo(mockUri("content://video/1"))
        viewModel.updateTitle("My Video")
        viewModel.startUpload()
        testDispatcher.scheduler.advanceUntilIdle()

        workInfoFlow.value = succeededInfo(videoId = "vid_123")
        testDispatcher.scheduler.advanceUntilIdle()

        val status = viewModel.uiState.value.status
        assertThat(status).isInstanceOf(UploadStatus.Complete::class.java)
        assertThat((status as UploadStatus.Complete).videoId).isEqualTo("vid_123")
    }

    @Test
    fun `failed work info surfaces error message`() = runTest {
        viewModel.selectVideo(mockUri("content://video/1"))
        viewModel.updateTitle("My Video")
        viewModel.startUpload()
        testDispatcher.scheduler.advanceUntilIdle()

        workInfoFlow.value = failedInfo(message = "Network down")
        testDispatcher.scheduler.advanceUntilIdle()

        val status = viewModel.uiState.value.status
        assertThat(status).isInstanceOf(UploadStatus.Error::class.java)
        assertThat((status as UploadStatus.Error).message).isEqualTo("Network down")
    }

    @Test
    fun `cancelUpload cancels work and returns to selecting`() = runTest {
        viewModel.selectVideo(mockUri("content://video/1"))
        viewModel.updateTitle("My Video")
        viewModel.startUpload()
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.cancelUpload()

        assertThat(viewModel.uiState.value.status).isEqualTo(UploadStatus.Selecting)
        verify(workManager).cancelUniqueWork(UploadWorker.UPLOAD_WORK_NAME)
    }

    @Test
    fun `reset clears all form state`() {
        viewModel.selectVideo(mockUri("content://video/1"))
        viewModel.updateTitle("My Video")

        viewModel.reset()

        val state = viewModel.uiState.value
        assertThat(state.status).isEqualTo(UploadStatus.Idle)
        assertThat(state.videoUri).isNull()
        assertThat(state.title).isEmpty()
    }

    private fun runningInfo(progress: Int): WorkInfo = mock {
        on { state } doReturn WorkInfo.State.RUNNING
        on { this.progress } doReturn workDataOf(UploadWorker.KEY_PROGRESS to progress)
    }

    private fun succeededInfo(videoId: String): WorkInfo = mock {
        on { state } doReturn WorkInfo.State.SUCCEEDED
        on { outputData } doReturn workDataOf(UploadWorker.KEY_VIDEO_ID to videoId)
    }

    private fun failedInfo(message: String): WorkInfo = mock {
        on { state } doReturn WorkInfo.State.FAILED
        on { outputData } doReturn workDataOf(UploadWorker.KEY_ERROR to message)
    }
}
