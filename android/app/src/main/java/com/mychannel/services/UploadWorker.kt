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
import com.google.firebase.storage.StorageException
import com.google.firebase.storage.StorageMetadata
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
 * After Storage succeeds, the worker atomically creates the canonical
 * `videos/{videoId}` reservation and deterministic `uploads/{videoId}` marker.
 * A trusted Cloud Function validates that marker and queues transcoding.
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
        val requestedPrivacy = inputData.getString(KEY_PRIVACY) ?: PRIVACY_PUBLIC
        val privacy = requestedPrivacy.takeIf { it in ALLOWED_PRIVACY } ?: PRIVACY_PUBLIC
        val durationSeconds = inputData.getLong(KEY_DURATION_SECONDS, 0L)
        val thumbnailUriString = inputData.getString(KEY_THUMBNAIL_URI)
        val tags = inputData.getString(KEY_TAGS)
            .orEmpty()
            .split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        val ageRestricted = inputData.getBoolean("ageRestricted", false)
        val madeForKids = inputData.getBoolean("madeForKids", false)
        val isPremiere = inputData.getBoolean("isPremiere", false)
        val scheduledAtMs = inputData.getLong("scheduledAtMs", 0L)

        // WorkManager keeps this UUID stable across retries, so a transient
        // failure cannot create duplicate Storage objects, video documents, or jobs.
        val videoId = id.toString()
        val sourceObjectPath = "temp_uploads/$uid/$videoId/source.mp4"
        val sourcePath = "gs://${storage.reference.bucket}/$sourceObjectPath"

        return try {
            // Raw source stays private and is consumed by the transcode service
            // through its service account. Never mint a client download URL for it.
            uploadFile(
                path = sourceObjectPath,
                uri = Uri.parse(videoUriString),
                contentType = "video/mp4",
                reportProgress = true,
                reuseExisting = true
            )

            val thumbnailUrl = thumbnailUriString?.let { thumb ->
                runCatching {
                    val thumbnailPath = "thumbnails/$uid/$videoId/cover.jpg"
                    uploadFile(
                        path = thumbnailPath,
                        uri = Uri.parse(thumb),
                        contentType = "image/jpeg",
                        reportProgress = false
                    )
                    storage.reference.child(thumbnailPath).downloadUrl.await().toString()
                }.getOrDefault("")
            }.orEmpty()

            // The upload marker is committed last, in the same transaction as
            // the canonical video reservation, so the server never sees a marker
            // for an incomplete object. Existing identical reservations are no-ops.
            finalizeUploadReservation(
                videoId = videoId,
                uid = uid,
                title = title,
                description = description,
                thumbnailUrl = thumbnailUrl,
                sourcePath = sourcePath,
                durationSeconds = durationSeconds,
                tags = tags,
                category = category,
                privacy = privacy,
                ageRestricted = ageRestricted,
                madeForKids = madeForKids,
                isPremiere = isPremiere,
                scheduledAtMs = scheduledAtMs
            )
            setProgress(workDataOf(KEY_PROGRESS to 100))

            Result.success(workDataOf(KEY_VIDEO_ID to videoId))
        } catch (cancellation: CancellationException) {
            // Propagate cooperative cancellation (user tapped cancel / work stopped).
            throw cancellation
        } catch (error: Exception) {
            if (runAttemptCount < MAX_RETRY_ATTEMPTS && isRetryable(error)) {
                Result.retry()
            } else {
                failure(error.message ?: "Upload failed. Please try again.")
            }
        }
    }

    /**
     * Uploads [uri] to [path]. When [reportProgress] is true, transfer progress
     * is published through [setProgressAsync]. Cancellation stops the upload.
     */
    private suspend fun uploadFile(
        path: String,
        uri: Uri,
        contentType: String,
        reportProgress: Boolean,
        reuseExisting: Boolean = false
    ) {
        val ref = storage.reference.child(path)
        if (reuseExisting) {
            try {
                val existing = ref.metadata.await()
                check(existing.contentType == contentType) {
                    "Existing upload has an unexpected content type."
                }
                if (reportProgress) setProgress(workDataOf(KEY_PROGRESS to 99))
                return
            } catch (error: StorageException) {
                if (error.errorCode != StorageException.ERROR_OBJECT_NOT_FOUND) throw error
            }
        }

        val metadata = StorageMetadata.Builder()
            .setContentType(contentType)
            .build()

        // Firebase's UploadTask is not a GMS Task, so bridge it to a coroutine
        // manually and forward cancellation to the underlying upload.
        suspendCancellableCoroutine<Unit> { continuation ->
            val uploadTask: UploadTask = ref.putFile(uri, metadata)

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
    }

    private fun isRetryable(error: Exception): Boolean = when (error) {
        is StorageException -> error.errorCode in setOf(
            StorageException.ERROR_UNKNOWN,
            StorageException.ERROR_RETRY_LIMIT_EXCEEDED,
            StorageException.ERROR_QUOTA_EXCEEDED
        )
        is com.google.firebase.firestore.FirebaseFirestoreException ->
            error.code in setOf(
                com.google.firebase.firestore.FirebaseFirestoreException.Code.ABORTED,
                com.google.firebase.firestore.FirebaseFirestoreException.Code.DEADLINE_EXCEEDED,
                com.google.firebase.firestore.FirebaseFirestoreException.Code.INTERNAL,
                com.google.firebase.firestore.FirebaseFirestoreException.Code.RESOURCE_EXHAUSTED,
                com.google.firebase.firestore.FirebaseFirestoreException.Code.UNAVAILABLE
            )
        is java.io.IOException -> true
        else -> false
    }

    private suspend fun finalizeUploadReservation(
        videoId: String,
        uid: String,
        title: String,
        description: String,
        thumbnailUrl: String,
        sourcePath: String,
        durationSeconds: Long,
        tags: List<String>,
        category: String,
        privacy: String,
        ageRestricted: Boolean = false,
        madeForKids: Boolean = false,
        isPremiere: Boolean = false,
        scheduledAtMs: Long = 0L
    ) {
        val isShort = durationSeconds in 1..SHORT_MAX_SECONDS
        val isScheduled = isPremiere && scheduledAtMs > 0
        val publicationStatus = if (isScheduled) STATUS_SCHEDULED else privacy
        val isPublic = privacy == PRIVACY_PUBLIC && !isScheduled
        val document = hashMapOf<String, Any>(
            "title" to title,
            "description" to description,
            "sourcePath" to sourcePath,
            "creatorId" to uid,
            "userId" to uid,
            "channelId" to uid,
            "channelName" to auth.currentUser?.displayName.orEmpty(),
            "channelAvatarUrl" to auth.currentUser?.photoUrl?.toString().orEmpty(),
            "viewCount" to 0L,
            "likeCount" to 0L,
            "dislikeCount" to 0L,
            "commentCount" to 0L,
            "shareCount" to 0L,
            "totalWatchTime" to 0L,
            "duration" to durationSeconds,
            "createdAt" to FieldValue.serverTimestamp(),
            "uploadedAt" to FieldValue.serverTimestamp(),
            "updatedAt" to FieldValue.serverTimestamp(),
            "tags" to tags,
            "category" to category,
            "isLive" to false,
            "isShort" to isShort,
            "privacyStatus" to privacy,
            "visibility" to publicationStatus,
            "isPublic" to isPublic,
            "ageRestricted" to ageRestricted,
            "madeForKids" to madeForKids,
            "commentsEnabled" to true,
            "likesEnabled" to true,
            "downloadsEnabled" to false,
            "isPremiere" to isPremiere,
            "status" to publicationStatus,
            "processingStatus" to STATUS_UPLOADED
        )
        if (thumbnailUrl.isNotBlank()) {
            document["thumbnailURL"] = thumbnailUrl
            document["thumbnailUrl"] = thumbnailUrl
        }
        if (isScheduled) {
            document["scheduledAt"] = com.google.firebase.Timestamp(scheduledAtMs / 1000, 0)
        }

        val videoRef = firestore.collection(VIDEOS).document(videoId)
        val uploadRef = firestore.collection(UPLOADS).document(videoId)
        firestore.runTransaction { transaction ->
            val existingVideo = transaction.get(videoRef)
            val existingUpload = transaction.get(uploadRef)

            if (existingVideo.exists()) {
                check(existingVideo.getString("creatorId") == uid) {
                    "Video reservation belongs to another creator."
                }
                check(existingVideo.getString("sourcePath") == sourcePath) {
                    "Video reservation source does not match."
                }
            } else {
                transaction.set(videoRef, document)
            }

            if (existingUpload.exists()) {
                check(existingUpload.getString("videoId") == videoId &&
                    existingUpload.getString("ownerUid") == uid &&
                    existingUpload.getString("sourcePath") == sourcePath) {
                    "Upload reservation does not match."
                }
            } else {
                transaction.set(uploadRef, mapOf(
                    "videoId" to videoId,
                    "ownerUid" to uid,
                    "sourcePath" to sourcePath,
                    "status" to STATUS_UPLOADED,
                    "createdAt" to FieldValue.serverTimestamp(),
                    "updatedAt" to FieldValue.serverTimestamp()
                ))
            }
            null
        }.await()
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
        private val ALLOWED_PRIVACY = setOf(
            PRIVACY_PUBLIC,
            PRIVACY_UNLISTED,
            PRIVACY_PRIVATE
        )

        const val STATUS_UPLOADED = "uploaded"
        const val STATUS_SCHEDULED = "scheduled"

        private const val VIDEOS = "videos"
        private const val UPLOADS = "uploads"
        private const val SHORT_MAX_SECONDS = 60L
        private const val MAX_RETRY_ATTEMPTS = 5
    }
}
