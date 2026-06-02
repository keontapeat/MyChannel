package com.mychannel.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import com.mychannel.data.local.dao.ChannelDao
import com.mychannel.data.local.dao.NotificationDao
import com.mychannel.data.local.dao.PlaylistDao
import com.mychannel.data.local.dao.SearchHistoryDao
import com.mychannel.data.local.dao.VideoDao
import com.mychannel.data.local.entity.ChannelEntity
import com.mychannel.data.local.entity.NotificationEntity
import com.mychannel.data.local.entity.PlaylistEntity
import com.mychannel.data.local.entity.SearchHistoryEntity
import com.mychannel.data.local.entity.VideoEntity

/**
 * MyChannel Room database — local cache for offline browsing (REQ-1.4).
 *
 * Version history:
 * 1 - Initial schema: videos, channels, search_history, playlists, notifications
 */
@Database(
    entities = [
        VideoEntity::class,
        ChannelEntity::class,
        SearchHistoryEntity::class,
        PlaylistEntity::class,
        NotificationEntity::class
    ],
    version = 1,
    exportSchema = false
)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun videoDao(): VideoDao
    abstract fun channelDao(): ChannelDao
    abstract fun searchHistoryDao(): SearchHistoryDao
    abstract fun playlistDao(): PlaylistDao
    abstract fun notificationDao(): NotificationDao
}
