package com.mychannel.viewmodel

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.workDataOf
import com.mychannel.services.UploadWorker
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import java.util.UUID
import javax.inject.Inject

/**
 * The phase of the upload pipeline (REQ-8.2, REQ-8.6).
 */
sealed interface UploadStatus {
    /** No video selected yet. */
    data object Idle : UploadStatus

    /** A video has been selected; the form is being filled out. */
    data object Selecting : UploadStatus

    /** The video bytes are being transferred, with a 0–100 [progress]. */
    data class Uploading(val progress: Int) : UploadStatus

    /** Upload finished; the backend is transcoding (Firestore status "processing"). */
    data object Processing : UploadStatus

    /** The upload completed and the video document was written. */
    data class Complete(val videoId: String?) : UploadStatus

    /** The upload failed with a user-facing [message]. */
    data class Error(val message: String) : UploadStatus
}

/**
 * Form + status state for the upload screen.
 *
 * The selected video / thumbnail are kept as [String] URIs so they can be
 * handed directly to [UploadWorker] via WorkManager input data.
 */
data class UploadUiState(
    val status: UploadStatus = UploadStatus.Idle,
    val videoUri: String? = null,
    val thumbnailUri: String? = null,
    val durationSeconds: Long = 0L,
    val title: String = "",
    val description: String = "",
    val tags: String = "",
    val category: String = "",
    val privacy: String = UploadWorker.PRIVACY_PUBLIC,
    val ageRestricted: Boolean = false,
    val madeForKids: Boolean = false,
    val isPremiere: Boolean = false,
    val scheduledAtMs: Long = 0L   // 0 = not scheduled
) {
    /** True while bytes are transferring — used to show the progress bar. */
    val isUploading: Boolean get() = status is UploadStatus.Uploading

    /** A video is ready to be submitted once selected and titled. */
    val canStartUpload: Boolean
        get() = videoUri != null &&
            title.isNotBlank() &&
            status !is UploadStatus.Uploading &&
            status !is UploadStatus.Processing
}

/**
 * ViewModel for the upload flow (REQ-8.1 – REQ-8.6).
 *
 * Enqueues an [UploadWorker] via [WorkManager] so the upload runs in the
 * background and survives the user leaving the screen. Progress is observed
 * through `WorkInfo` and reflected into [UploadUiState.status].
 */
@HiltViewModel
class UploadViewModel @Inject constructor(
    private val workManager: WorkManager
) : ViewModel() {

    private val _uiState = MutableStateFlow(UploadUiState())
    val uiState: StateFlow<UploadUiState> = _uiState.asStateFlow()

    /** Id of the currently-enqueued upload work, for progress observation and cancellation. */
    private var currentWorkId: UUID? = null

    /** Records the selected video and moves into the form-filling phase (REQ-8.1). */
    fun selectVideo(uri: Uri, durationSeconds: Long = 0L) {
        _uiState.update {
            it.copy(
                videoUri = uri.toString(),
                durationSeconds = durationSeconds,
                status = UploadStatus.Selecting
            )
        }
    }

    /** Records a custom thumbnail selected by the user (REQ-8.3). */
    fun selectThumbnail(uri: Uri) {
        _uiState.update { it.copy(thumbnailUri = uri.toString()) }
    }

    fun updateTitle(value: String) = _uiState.update { it.copy(title = value) }

    fun updateDescription(value: String) = _uiState.update { it.copy(description = value) }

    fun updateTags(value: String) = _uiState.update { it.copy(tags = value) }

    fun updateCategory(value: String) = _uiState.update { it.copy(category = value) }
    fun updatePrivacy(value: String) = _uiState.update { it.copy(privacy = value) }
    fun updateAgeRestricted(value: Boolean) = _uiState.update { it.copy(ageRestricted = value, madeForKids = if (value) false else it.madeForKids) }
    fun updateMadeForKids(value: Boolean) = _uiState.update { it.copy(madeForKids = value, ageRestricted = if (value) false else it.ageRestricted) }
    fun updateIsPremiere(value: Boolean) = _uiState.update { it.copy(isPremiere = value) }
    fun updateScheduledAt(ms: Long) = _uiState.update { it.copy(scheduledAtMs = ms) }

    /**
     * Validates the form and enqueues the background [UploadWorker] (REQ-8.2,
     * REQ-8.6). Uses [ExistingWorkPolicy.KEEP] so re-tapping submit doesn't
     * launch a duplicate upload.
     */
    fun startUpload() {
        val state = _uiState.value
        val videoUri = state.videoUri
        if (videoUri == null) {
            _uiState.update { it.copy(status = UploadStatus.Error("Select a video to upload.")) }
            return
        }
        if (state.title.isBlank()) {
            _uiState.update { it.copy(status = UploadStatus.Error("Add a title before uploading.")) }
            return
        }

        val inputData = workDataOf(
            UploadWorker.KEY_VIDEO_URI to videoUri,
            UploadWorker.KEY_THUMBNAIL_URI to state.thumbnailUri,
            UploadWorker.KEY_TITLE to state.title.trim(),
            UploadWorker.KEY_DESCRIPTION to state.description.trim(),
            UploadWorker.KEY_TAGS to state.tags.trim(),
            UploadWorker.KEY_CATEGORY to state.category.trim(),
            UploadWorker.KEY_PRIVACY to state.privacy,
            UploadWorker.KEY_DURATION_SECONDS to state.durationSeconds,
            "ageRestricted" to state.ageRestricted,
            "madeForKids" to state.madeForKids,
            "isPremiere" to state.isPremiere,
            "scheduledAtMs" to state.scheduledAtMs
        )

        // Require a network connection; upload is deferrable but should not run
        // on no connectivity (REQ-8.2 resumable upload).
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val request = OneTimeWorkRequestBuilder<UploadWorker>()
            .setInputData(inputData)
            .setConstraints(constraints)
            .addTag(UploadWorker.UPLOAD_WORK_NAME)
            .build()

        currentWorkId = request.id
        _uiState.update { it.copy(status = UploadStatus.Uploading(progress = 0)) }

        workManager.enqueueUniqueWork(
            UploadWorker.UPLOAD_WORK_NAME,
            ExistingWorkPolicy.KEEP,
            request
        )

        observeWork(request.id)
    }

    /** Cancels the in-flight upload and returns to the form (REQ-8.6). */
    fun cancelUpload() {
        currentWorkId?.let { workManager.cancelWorkById(it) }
        workManager.cancelUniqueWork(UploadWorker.UPLOAD_WORK_NAME)
        currentWorkId = null
        _uiState.update {
            val status = if (it.videoUri != null) UploadStatus.Selecting else UploadStatus.Idle
            it.copy(status = status)
        }
    }

    /** Clears all form state after a successful upload so the screen can be reused. */
    fun reset() {
        currentWorkId = null
        _uiState.value = UploadUiState()
    }

    /**
     * Observes the enqueued work's [WorkInfo] and maps it onto [UploadStatus].
     * Progress is read from `WorkInfo.progress`; terminal states surface
     * completion or the worker's error message.
     */
    private fun observeWork(id: UUID) {
        workManager.getWorkInfoByIdFlow(id)
            .onEach { info -> info?.let { handleWorkInfo(it) } }
            .launchIn(viewModelScope)
    }

    private fun handleWorkInfo(info: WorkInfo) {
        when (info.state) {
            WorkInfo.State.ENQUEUED,
            WorkInfo.State.BLOCKED -> {
                _uiState.update {
                    if (it.status is UploadStatus.Uploading) it else it.copy(status = UploadStatus.Uploading(0))
                }
            }

            WorkInfo.State.RUNNING -> {
                val progress = info.progress.getInt(UploadWorker.KEY_PROGRESS, 0)
                _uiState.update {
                    if (progress >= 100) {
                        it.copy(status = UploadStatus.Processing)
                    } else {
                        it.copy(status = UploadStatus.Uploading(progress))
                    }
                }
            }

            WorkInfo.State.SUCCEEDED -> {
                val videoId = info.outputData.getString(UploadWorker.KEY_VIDEO_ID)
                _uiState.update { it.copy(status = UploadStatus.Complete(videoId)) }
            }

            WorkInfo.State.FAILED -> {
                val message = info.outputData.getString(UploadWorker.KEY_ERROR)
                    ?: "Upload failed. Please try again."
                _uiState.update { it.copy(status = UploadStatus.Error(message)) }
            }

            WorkInfo.State.CANCELLED -> {
                _uiState.update {
                    val status = if (it.videoUri != null) UploadStatus.Selecting else UploadStatus.Idle
                    it.copy(status = status)
                }
            }
        }
    }
}
