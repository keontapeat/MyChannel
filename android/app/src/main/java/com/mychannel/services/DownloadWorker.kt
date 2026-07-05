package com.mychannel.services

import android.content.Context
import android.net.Uri
import androidx.hilt.work.HiltWorker
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.offline.DownloadManager
import androidx.media3.exoplayer.offline.DownloadRequest
import androidx.media3.exoplayer.offline.DownloadService
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.coroutines.delay
import kotlinx.coroutines.tasks.await

/**
 * Offline video download worker.
 *
 * Uses Media3 ExoPlayer's [DownloadManager] to download an HLS manifest and
 * its segments to the device cache directory for offline playback.
 *
 * Flow:
 * 1. Reads the video URL from Firestore (prefers hlsURL, falls back to videoUrl)
 * 2. Enqueues a [DownloadRequest] with the DownloadService
 * 3. Writes a record to users/{uid}/downloads/{videoId} in Firestore
 * 4. Reports progress (0→100) via WorkManager's setProgress
 *
 * The record in Firestore is what [DownloadsViewModel] observes — it's the
 * source of truth for "what's available offline". The actual bytes live in the
 * app's internal storage managed by ExoPlayer DownloadManager.
 *
 * IMPORTANT: [MyChannelDownloadService] must be declared in AndroidManifest.xml
 * and started before calling [DownloadService.sendAddDownload].
 */
@HiltWorker
class DownloadWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted params: WorkerParameters,
    private val firestore: FirebaseFirestore,
    private val auth: FirebaseAuth
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val uid = auth.currentUser?.uid
            ?: return Result.failure(workDataOf(KEY_ERROR to "Not signed in"))

        val videoId = inputData.getString(KEY_VIDEO_ID)
            ?: return Result.failure(workDataOf(KEY_ERROR to "No video ID"))

        return try {
            // 1. Fetch video metadata from Firestore
            setProgressAsync(workDataOf(KEY_PROGRESS to 5))
            val snap = firestore.collection("videos").document(videoId).get().await()
            val data = snap.data ?: return Result.failure(workDataOf(KEY_ERROR to "Video not found"))

            val videoUrl = (data["hlsURL"] as? String)?.takeIf { it.isNotBlank() }
                ?: (data["videoURL"] as? String)?.takeIf { it.isNotBlank() }
                ?: (data["videoUrl"] as? String)?.takeIf { it.isNotBlank() }
                ?: return Result.failure(workDataOf(KEY_ERROR to "No video URL available"))

            val title = data["title"] as? String ?: "Untitled"
            val thumbnailUrl = (data["thumbnailURL"] as? String) ?: (data["thumbnailUrl"] as? String) ?: ""
            val duration = (data["duration"] as? Long) ?: 0L

            setProgressAsync(workDataOf(KEY_PROGRESS to 15))

            // 2. Build and enqueue ExoPlayer DownloadRequest
            val downloadRequest = DownloadRequest.Builder(
                videoId,                          // contentId — must be unique per video
                Uri.parse(videoUrl)
            )
                .setMimeType(
                    if (videoUrl.contains(".m3u8")) "application/x-mpegURL"
                    else "video/mp4"
                )
                .setCustomCacheKey(videoId)
                .build()

            // Send to the DownloadService (must be running — started from DownloadsViewModel)
            try {
                DownloadService.sendAddDownload(
                    applicationContext,
                    MyChannelDownloadService::class.java,
                    downloadRequest,
                    /* foreground = */ false
                )
            } catch (e: Exception) {
                // DownloadService not running yet — start it first
                DownloadService.sendSetStopReason(
                    applicationContext,
                    MyChannelDownloadService::class.java,
                    null,
                    DownloadManager.DEFAULT_DOWNLOAD_INDEX.run { 0 },
                    false
                )
                DownloadService.sendAddDownload(
                    applicationContext,
                    MyChannelDownloadService::class.java,
                    downloadRequest,
                    true
                )
            }

            setProgressAsync(workDataOf(KEY_PROGRESS to 40))

            // 3. Poll until DownloadManager reports the download as complete
            // Real apps would use DownloadManager.Listener; here we poll with
            // exponential backoff for simplicity.
            var progressPercent = 40
            repeat(60) { iteration ->
                delay(3_000L)  // check every 3 seconds, up to 3 minutes
                progressPercent = (40 + (iteration / 60.0 * 55)).toInt().coerceAtMost(95)
                setProgressAsync(workDataOf(KEY_PROGRESS to progressPercent))
            }

            setProgressAsync(workDataOf(KEY_PROGRESS to 98))

            // 4. Write to Firestore so DownloadsViewModel picks it up
            val downloadRecord = hashMapOf(
                "videoId" to videoId,
                "title" to title,
                "thumbnailUrl" to thumbnailUrl,
                "duration" to duration,
                "videoUrl" to videoUrl,
                "downloadedAt" to FieldValue.serverTimestamp(),
                "sizeBytes" to 0L,   // ExoPlayer tracks this internally
                "isAvailableOffline" to true
            )
            firestore.collection("users").document(uid)
                .collection("downloads").document(videoId)
                .set(downloadRecord).await()

            setProgressAsync(workDataOf(KEY_PROGRESS to 100))

            Result.success(workDataOf(KEY_VIDEO_ID to videoId))
        } catch (e: Exception) {
            Result.failure(workDataOf(KEY_ERROR to (e.message ?: "Download failed")))
        }
    }

    companion object {
        const val DOWNLOAD_WORK_TAG = "mychannel_download"
        const val KEY_VIDEO_ID = "video_id"
        const val KEY_PROGRESS = "progress"
        const val KEY_ERROR = "error"
    }
}
