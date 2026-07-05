package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import com.mychannel.domain.model.Video
import com.mychannel.domain.repository.AuthRepository
import com.mychannel.domain.repository.VideoRepository
import com.mychannel.services.DownloadWorker
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class DownloadsUiState(
    val isLoading: Boolean = true,
    val downloads: List<Video> = emptyList(),
    val activeDownloads: Set<String> = emptySet(),  // videoIds currently being downloaded
    val error: String? = null
)

@HiltViewModel
class DownloadsViewModel @Inject constructor(
    private val videoRepository: VideoRepository,
    private val authRepository: AuthRepository,
    private val workManager: WorkManager
) : ViewModel() {

    private val _uiState = MutableStateFlow(DownloadsUiState())
    val uiState: StateFlow<DownloadsUiState> = _uiState.asStateFlow()

    init {
        loadDownloads()
    }

    private fun loadDownloads() {
        val uid = authRepository.currentUserId ?: run {
            _uiState.update { it.copy(isLoading = false) }
            return
        }
        videoRepository.observeDownloads(uid)
            .onEach { videos -> _uiState.update { it.copy(isLoading = false, downloads = videos) } }
            .catch { e -> _uiState.update { it.copy(isLoading = false, error = e.message) } }
            .launchIn(viewModelScope)
    }

    /**
     * Enqueues a WorkManager job to download [videoId] to device storage.
     * Requires WiFi by default — user can override in Settings.
     */
    fun downloadVideo(videoId: String, requireWifi: Boolean = false) {
        if (_uiState.value.activeDownloads.contains(videoId)) return

        _uiState.update { it.copy(activeDownloads = it.activeDownloads + videoId) }

        val constraints = Constraints.Builder()
            .setRequiredNetworkType(if (requireWifi) NetworkType.UNMETERED else NetworkType.CONNECTED)
            .setRequiresStorageNotLow(true)
            .build()

        val request = OneTimeWorkRequestBuilder<DownloadWorker>()
            .setInputData(workDataOf(DownloadWorker.KEY_VIDEO_ID to videoId))
            .setConstraints(constraints)
            .addTag(DownloadWorker.DOWNLOAD_WORK_TAG)
            .build()

        workManager.enqueueUniqueWork(
            "download_$videoId",
            ExistingWorkPolicy.KEEP,
            request
        )

        // Observe progress
        workManager.getWorkInfosByTagFlow(DownloadWorker.DOWNLOAD_WORK_TAG)
            .onEach { infos ->
                val done = infos.none { it.state == androidx.work.WorkInfo.State.RUNNING }
                if (done) {
                    _uiState.update { it.copy(activeDownloads = it.activeDownloads - videoId) }
                }
            }
            .catch { /* non-fatal */ }
            .launchIn(viewModelScope)
    }

    fun deleteDownload(videoId: String) {
        val uid = authRepository.currentUserId ?: return
        viewModelScope.launch {
            videoRepository.deleteDownload(uid, videoId)
        }
    }
}
