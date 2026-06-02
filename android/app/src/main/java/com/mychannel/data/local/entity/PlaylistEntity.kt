package com.mychannel.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.mychannel.domain.model.Playlist

/**
 * Room entity caching a [Playlist] for the Library screen (REQ-10.3).
 *
 * [videoIds] is JSON-encoded via [com.mychannel.data.local.Converters].
 */
@Entity(tableName = "playlists")
data class PlaylistEntity(
    @PrimaryKey val id: String,
    val ownerId: String,
    val title: String,
    val description: String,
    val thumbnailUrl: String,
    val videoIds: List<String>,
    val videoCount: Long,
    val privacyStatus: String,
    val createdAtMillis: Long,
    val updatedAtMillis: Long,
    val cachedAtMillis: Long = System.currentTimeMillis()
)

/** Maps a cached [PlaylistEntity] to its [Playlist] domain model. */
fun PlaylistEntity.toDomain(): Playlist = Playlist(
    id = id,
    ownerId = ownerId,
    title = title,
    description = description,
    thumbnailUrl = thumbnailUrl,
    videoIds = videoIds,
    videoCount = videoCount,
    privacyStatus = privacyStatus,
    createdAt = millisToTimestamp(createdAtMillis),
    updatedAt = millisToTimestamp(updatedAtMillis)
)

/** Maps a [Playlist] domain model to a cacheable [PlaylistEntity]. */
fun Playlist.toEntity(): PlaylistEntity = PlaylistEntity(
    id = id,
    ownerId = ownerId,
    title = title,
    description = description,
    thumbnailUrl = thumbnailUrl,
    videoIds = videoIds,
    videoCount = videoCount,
    privacyStatus = privacyStatus,
    createdAtMillis = createdAt.toDate().time,
    updatedAtMillis = updatedAt.toDate().time
)
