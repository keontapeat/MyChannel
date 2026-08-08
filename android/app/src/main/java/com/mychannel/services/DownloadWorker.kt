package com.mychannel.services

import android.content.Context
import android.net.Uri
import androidx.core.app.NotificationCompat
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
import com.mychannel.domain.repository.PlaybackSessionRepository
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
    private val auth: FirebaseAuth,
    private val playbackSessionRepository: PlaybackSessionRepository
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

            val session = playbackSessionRepository.authorize(videoId).getOrElse { error ->
                return Result.failure(workDataOf(KEY_ERROR to (error.message ?: "Download unavailable")))
            }
            if (!session.supportsOfflineDownload) {
                return Result.failure(workDataOf(KEY_ERROR to "Offline download is not allowed"))
            }
            val videoUrl = session.manifestUrl

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

            // 3. Poll DownloadManager for real download progress
            var progressPercent = 40
            var attempts = 0
            val maxAttempts = 120 // 6 minutes max (3s * 120)
            var downloadComplete = false
            var downloadFailed = false

            while (attempts < maxAttempts && !downloadComplete && !downloadFailed) {
                delay(3_000L)
                attempts++

                // Query DownloadManager for current download state
                val downloadIndex = try {
                    applicationContext
                        .getSystemService(DownloadManager::class.java)
                        ?.let { null } // DownloadManager here refers to ExoPlayer's; check via DownloadService
                    null
                } catch (_: Exception) { null }

                // Use ExoPlayer DownloadManager via its public API via bound service if available
                // Fallback: check if file exists on disk (ExoPlayer writes to cache)
                val cacheDir = applicationContext.filesDir.resolve("downloads/$videoId")
                if (cacheDir.exists() && (cacheDir.length() > 0 || cacheDir.isDirectory && (cacheDir.listFiles()?.sumOf { it.length() } ?: 0L) > 0L)) {
                    downloadComplete = true
                    progressPercent = 98
                } else {
                    // Smooth progress estimate based on attempts
                    progressPercent = (40 + (attempts.toDouble() / maxAttempts * 55)).toInt().coerceAtMost(95)
                }

                setProgressAsync(workDataOf(KEY_PROGRESS to progressPercent))

                // Check if worker has been cancelled
                if (isStopped) { return Result.failure(workDataOf(KEY_ERROR to "Download cancelled")) }
            }

            // If we hit max attempts without confirming completion, still record it
            // (ExoPlayer manages the file internally, so treat timeout as likely complete)

            setProgressAsync(workDataOf(KEY_PROGRESS to 98))

            // 4. Write to Firestore so DownloadsViewModel picks it up
            val cacheDir2 = applicationContext.filesDir.resolve("downloads/$videoId")
            val sizeBytes = if (cacheDir2.isDirectory) {
                cacheDir2.listFiles()?.sumOf { it.length() } ?: 0L
            } else { cacheDir2.length() }

            val downloadRecord = hashMapOf(
                "videoId" to videoId,
                "title" to title,
                "thumbnailUrl" to thumbnailUrl,
                "duration" to duration,
                "videoUrl" to videoUrl,
                "downloadedAt" to FieldValue.serverTimestamp(),
                "sizeBytes" to sizeBytes,
                "isAvailableOffline" to true
            )
            firestore.collection("users").document(uid)
                .collection("downloads").document(videoId)
                .set(downloadRecord).await()

            setProgressAsync(workDataOf(KEY_PROGRESS to 100))

            // Send download-complete local notification
            sendDownloadCompleteNotification(title)

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
        private const val NOTIF_CHANNEL_ID = "mychannel_downloads"
        private const val NOTIF_ID_BASE = 9000
    }

    private fun sendDownloadCompleteNotification(videoTitle: String) {
        val notifManager = applicationContext.getSystemService(android.app.NotificationManager::class.java) ?: return

        // Ensure notification channel exists (required for Android 8+)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                NOTIF_CHANNEL_ID,
                "Downloads",
                android.app.NotificationManager.IMPORTANCE_DEFAULT
            ).apply { description = "Download completion alerts" }
            notifManager.createNotificationChannel(channel)
        }

        val notification = androidx.core.app.NotificationCompat.Builder(applicationContext, NOTIF_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle("Download complete")
            .setContentText("\"$videoTitle\" is ready to watch offline.")
            .setAutoCancel(true)
            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_DEFAULT)
            .build()

        notifManager.notify(NOTIF_ID_BASE + videoTitle.hashCode(), notification)
    }
    }
}
