package com.mychannel.services

import android.content.Context
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.cache.NoOpCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.exoplayer.offline.DefaultDownloadIndex
import androidx.media3.exoplayer.offline.DefaultDownloaderFactory
import androidx.media3.exoplayer.offline.DownloadManager
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.File
import java.util.concurrent.Executors
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Provides the singleton [DownloadManager] used by [MyChannelDownloadService]
 * and [DownloadWorker].
 *
 * Downloads are stored in the app's internal storage under `downloads/`.
 * The [SimpleCache] uses [NoOpCacheEvictor] so downloaded content is only
 * removed when the user explicitly deletes it from the Downloads screen.
 */
@Singleton
@OptIn(UnstableApi::class)
class DownloadManagerProvider @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val downloadDirectory: File by lazy {
        File(context.filesDir, "downloads").also { it.mkdirs() }
    }

    private val databaseProvider: StandaloneDatabaseProvider by lazy {
        StandaloneDatabaseProvider(context)
    }

    /** Shared cache backed by device internal storage. */
    val downloadCache: SimpleCache by lazy {
        SimpleCache(downloadDirectory, NoOpCacheEvictor(), databaseProvider)
    }

    val downloadManager: DownloadManager by lazy {
        DownloadManager(
            context,
            DefaultDownloadIndex(databaseProvider),
            DefaultDownloaderFactory(
                androidx.media3.datasource.cache.CacheDataSource.Factory()
                    .setCache(downloadCache)
                    .setUpstreamDataSourceFactory(
                        DefaultHttpDataSource.Factory()
                            .setUserAgent("MyChannel-Android")
                            .setAllowCrossProtocolRedirects(true)
                    ),
                Executors.newFixedThreadPool(3)   // max 3 parallel downloads
            )
        ).apply {
            maxParallelDownloads = 3
            minRetryCount = 5
        }
    }
}
