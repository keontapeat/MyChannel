package com.mychannel.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.google.firebase.Timestamp
import com.mychannel.domain.model.Video

/**
 * Room entity caching a [Video] for offline browsing (REQ-1.4).
 *
 * Firebase [Timestamp] values are persisted as epoch milliseconds in
 * [uploadedAtMillis]; [tags] is JSON-encoded via [com.mychannel.data.local.Converters].
 */
@Entity(tableName = "videos")
data class VideoEntity(
    @PrimaryKey val id: String,
    val title: String,
    val description: String,
    val thumbnailUrl: String,
    val videoUrl: String,
    val channelId: String,
    val channelName: String,
    val channelAvatarUrl: String,
    val viewCount: Long,
    val likeCount: Long,
    val dislikeCount: Long,
    val commentCount: Long,
    val duration: Long,
    val uploadedAtMillis: Long,
    val tags: List<String>,
    val category: String,
    val isLive: Boolean,
    val isShort: Boolean,
    val privacyStatus: String,
    /** Local cache insertion time (epoch millis) for ordering/eviction. */
    val cachedAtMillis: Long = System.currentTimeMillis()
)

/** Maps a cached [VideoEntity] to its [Video] domain model. */
fun VideoEntity.toDomain(): Video = Video(
    id = id,
    title = title,
    description = description,
    thumbnailUrl = thumbnailUrl,
    videoUrl = videoUrl,
    channelId = channelId,
    channelName = channelName,
    channelAvatarUrl = channelAvatarUrl,
    viewCount = viewCount,
    likeCount = likeCount,
    dislikeCount = dislikeCount,
    commentCount = commentCount,
    duration = duration,
    uploadedAt = millisToTimestamp(uploadedAtMillis),
    tags = tags,
    category = category,
    isLive = isLive,
    isShort = isShort,
    privacyStatus = privacyStatus
)

/** Maps a [Video] domain model to a cacheable [VideoEntity]. */
fun Video.toEntity(): VideoEntity = VideoEntity(
    id = id,
    title = title,
    description = description,
    thumbnailUrl = thumbnailUrl,
    videoUrl = videoUrl,
    channelId = channelId,
    channelName = channelName,
    channelAvatarUrl = channelAvatarUrl,
    viewCount = viewCount,
    likeCount = likeCount,
    dislikeCount = dislikeCount,
    commentCount = commentCount,
    duration = duration,
    uploadedAtMillis = uploadedAt.toDate().time,
    tags = tags,
    category = category,
    isLive = isLive,
    isShort = isShort,
    privacyStatus = privacyStatus
)

/** Convert epoch millis to a Firebase [Timestamp]. */
internal fun millisToTimestamp(millis: Long): Timestamp {
    val seconds = millis / 1000
    val nanos = ((millis % 1000) * 1_000_000).toInt()
    return Timestamp(seconds, nanos)
}
