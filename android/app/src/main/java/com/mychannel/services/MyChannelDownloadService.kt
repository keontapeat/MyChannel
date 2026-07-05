package com.mychannel.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.annotation.OptIn
import androidx.core.app.NotificationCompat
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.offline.DownloadManager
import androidx.media3.exoplayer.offline.DownloadNotificationHelper
import androidx.media3.exoplayer.offline.DownloadService
import androidx.media3.exoplayer.scheduler.PlatformScheduler
import androidx.media3.exoplayer.scheduler.Scheduler
import com.mychannel.R
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

/**
 * Media3 [DownloadService] subclass that runs in the foreground while
 * HLS segments are being downloaded for offline playback.
 *
 * Must be declared in AndroidManifest.xml:
 * ```xml
 * <service
 *     android:name=".services.MyChannelDownloadService"
 *     android:exported="false"
 *     android:foregroundServiceType="dataSync" />
 * ```
 *
 * Provides the notification shown in the status bar during download.
 * The underlying [DownloadManager] singleton is injected by Hilt via
 * [DownloadManagerProvider] — this ensures a single download queue
 * shared across the app.
 */
@AndroidEntryPoint
@OptIn(UnstableApi::class)
class MyChannelDownloadService : DownloadService(
    FOREGROUND_NOTIFICATION_ID,
    DEFAULT_FOREGROUND_NOTIFICATION_UPDATE_INTERVAL,
    DOWNLOAD_CHANNEL_ID,
    R.string.app_name,   // channel name string resource
    0                    // no channel description
) {

    @Inject
    lateinit var downloadManagerProvider: DownloadManagerProvider

    @Inject
    lateinit var notificationHelper: DownloadNotificationHelper

    override fun getDownloadManager(): DownloadManager =
        downloadManagerProvider.downloadManager

    override fun getScheduler(): Scheduler =
        PlatformScheduler(this, JOB_ID)

    override fun getForegroundNotification(
        downloads: List<androidx.media3.exoplayer.offline.Download>,
        notMetRequirements: Int
    ): Notification {
        createNotificationChannel()
        return notificationHelper.buildProgressNotification(
            this,
            R.drawable.ic_notification,  // small icon — must exist in res/drawable
            null,
            null,
            downloads,
            notMetRequirements
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                DOWNLOAD_CHANNEL_ID,
                "Downloads",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "MyChannel offline video downloads"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    companion object {
        private const val FOREGROUND_NOTIFICATION_ID = 2001
        private const val DOWNLOAD_CHANNEL_ID = "mychannel_downloads"
        private const val JOB_ID = 1000
    }
}
