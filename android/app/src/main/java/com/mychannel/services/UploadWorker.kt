package com.mychannel.services

import android.content.Context
import android.net.Uri
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.storage.FirebaseStorage
import com.google.firebase.storage.UploadTask
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.tasks.await
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Background video upload worker (REQ-8.2, REQ-8.6).
 *
 * Runs as a [CoroutineWorker] so the upload survives the user navigating away
 * from the upload screen or backgrounding the app. Firebase Storage's
 * [UploadTask] uploads in resumable chunks; progress is surfaced to the UI via
 * [setProgressAsync] so [com.mychannel.viewmodel.UploadViewModel] can observe a
 * live percentage through `WorkInfo`.
 *
 * On a successful upload the worker writes the `videos/{videoId}` Firestore
 * document with `status: "processing"`. A Cloud Function `onFinalize` trigger
 * performs transcoding / thumbnail generation and flips the status to `ready`.
 *
 * Constructed by Hilt's [androidx.hilt.work.HiltWorkerFactory] (see
 * [com.mychannel.MyChannelApp]) which injects the Firebase singletons.
 */
@HiltWorker
class UploadWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted params: WorkerParameters,
    private val storage: FirebaseStorage,
    private val firestore: FirebaseFirestore,
    private val auth: FirebaseAuth
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val uid = auth.currentUser?.uid
            ?: return failure("You must be signed in to upload.")

        val videoUriString = inputData.getString(KEY_VIDEO_URI)
            ?: return failure("No video selected.")
        val title = inputData.getString(KEY_TITLE).orEmpty().trim()
        if (title.isEmpty()) return failure("A title is required.")

        val description = inputData.getString(KEY_DESCRIPTION).orEmpty()
        val category = inputData.getString(KEY_CATEGORY).orEmpty()
        val privacy = inputData.getString(KEY_PRIVACY) ?: PRIVACY_PUBLIC
        val durationSeconds = inputData.getLong(KEY_DURATION_SECONDS, 0L)
        val thumbnailUriString = inputData.getString(KEY_THUMBNAIL_URI)
        val tags = inputData.getString(KEY_TAGS)
            .orEmpty()
            .split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }

        // Deterministic id so the storage object and Firestore doc line up and
        // retries don't create duplicate documents.
        val videoId = firestore.collection(VIDEOS).document().id

        return try {
            val videoUrl = uploadFile(
                path = "videos/$uid/$videoId/source.mp4",
                uri = Uri.parse(videoUriString),
                reportProgress = true
            )

            val thumbnailUrl = thumbnailUriString?.let { thumb ->
                runCatching {
                    uploadFile(
                        path = "thumbnails/$uid/$videoId/cover.jpg",
                        uri = Uri.parse(thumb),
                        reportProgress = false
                    )
                }.getOrDefault("")
            }.orEmpty()

            // Upload complete — moving into server-side processing.
            setProgress(workDataOf(KEY_PROGRESS to 100))

            writeVideoDocument(
                videoId = videoId,
                uid = uid,
                title = title,
                description = description,
                thumbnailUrl = thumbnailUrl,
                videoUrl = videoUrl,
                durationSeconds = durationSeconds,
                tags = tags,
                category = category,
                privacy = privacy
            )

            Result.success(workDataOf(KEY_VIDEO_ID to videoId))
        } catch (cancellation: CancellationException) {
            // Propagate cooperative cancellation (user tapped cancel / work stopped).
            throw cancellation
        } catch (error: Exception) {
            failure(error.message ?: "Upload failed. Please try again.")
        }
    }

    /**
     * Uploads [uri] to [path] in Firebase Storage and returns the download URL.
     * When [reportProgress] is true, transfer progress is published to the UI
     * via [setProgressAsync]. Cancelling the worker cancels the [UploadTask].
     */
    private suspend fun uploadFile(path: String, uri: Uri, reportProgress: Boolean): String {
        val ref = storage.reference.child(path)

        // Firebase's UploadTask is not a GMS Task, so bridge it to a coroutine
        // manually and forward cancellation to the underlying upload.
        suspendCancellableCoroutine<Unit> { continuation ->
            val uploadTask: UploadTask = ref.putFile(uri)

            if (reportProgress) {
                uploadTask.addOnProgressListener { snapshot ->
                    val total = snapshot.totalByteCount
                    val percent = if (total > 0) {
                        ((snapshot.bytesTransferred * 100) / total).toInt().coerceIn(0, 99)
                    } else {
                        0
                    }
                    setProgressAsync(workDataOf(KEY_PROGRESS to percent))
                }
            }

            uploadTask
                .addOnSuccessListener {
                    if (continuation.isActive) continuation.resume(Unit)
                }
                .addOnFailureListener { error ->
                    if (continuation.isActive) continuation.resumeWithException(error)
                }
                .addOnCanceledListener {
                    if (continuation.isActive) {
                        continuation.resumeWithException(CancellationException("Upload cancelled"))
                    }
                }

            continuation.invokeOnCancellation { uploadTask.cancel() }
        }

        return ref.downloadUrl.await().toString()
    }

    private suspend fun writeVideoDocument(
        videoId: String,
        uid: String,
        title: String,
        description: String,
        thumbnailUrl: String,
        videoUrl: String,
        durationSeconds: Long,
        tags: List<String>,
        category: String,
        privacy: String
    ) {
        val isShort = durationSeconds in 1..SHORT_MAX_SECONDS
        val document = hashMapOf(
            "title" to title,
            "description" to description,
            "thumbnailUrl" to thumbnailUrl,
            "videoUrl" to videoUrl,
            "channelId" to uid,
            "channelName" to (auth.currentUser?.displayName.orEmpty()),
            "channelAvatarUrl" to (auth.currentUser?.photoUrl?.toString().orEmpty()),
            "viewCount" to 0L,
            "likeCount" to 0L,
            "dislikeCount" to 0L,
            "commentCount" to 0L,
            "duration" to durationSeconds,
            "uploadedAt" to FieldValue.serverTimestamp(),
            "tags" to tags,
            "category" to category,
            "isLive" to false,
            "isShort" to isShort,
            "privacyStatus" to privacy,
            // Cloud Function `onFinalize` advances this to "ready" once processed.
            "status" to STATUS_PROCESSING
        )
        firestore.collection(VIDEOS).document(videoId).set(document).await()
    }

    private fun failure(message: String): Result =
        Result.failure(workDataOf(KEY_ERROR to message))

    companion object {
        const val UPLOAD_WORK_NAME = "mychannel_video_upload"

        // Input keys
        const val KEY_VIDEO_URI = "video_uri"
        const val KEY_THUMBNAIL_URI = "thumbnail_uri"
        const val KEY_TITLE = "title"
        const val KEY_DESCRIPTION = "description"
        const val KEY_TAGS = "tags"
        const val KEY_CATEGORY = "category"
        const val KEY_PRIVACY = "privacy"
        const val KEY_DURATION_SECONDS = "duration_seconds"

        // Output / progress keys
        const val KEY_PROGRESS = "progress"
        const val KEY_VIDEO_ID = "video_id"
        const val KEY_ERROR = "error"

        const val PRIVACY_PUBLIC = "public"
        const val PRIVACY_UNLISTED = "unlisted"
        const val PRIVACY_PRIVATE = "private"

        const val STATUS_PROCESSING = "processing"

        private const val VIDEOS = "videos"
        private const val SHORT_MAX_SECONDS = 60L
    }
}
