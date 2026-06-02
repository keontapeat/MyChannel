package com.mychannel.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.mychannel.domain.model.Channel

/**
 * Room entity caching a [Channel] for offline browsing (REQ-1.4).
 */
@Entity(tableName = "channels")
data class ChannelEntity(
    @PrimaryKey val id: String,
    val ownerId: String,
    val name: String,
    val handle: String,
    val description: String,
    val avatarUrl: String,
    val bannerUrl: String,
    val subscriberCount: Long,
    val videoCount: Long,
    val totalViewCount: Long,
    val isVerified: Boolean,
    val createdAtMillis: Long,
    val cachedAtMillis: Long = System.currentTimeMillis()
)

/** Maps a cached [ChannelEntity] to its [Channel] domain model. */
fun ChannelEntity.toDomain(): Channel = Channel(
    id = id,
    ownerId = ownerId,
    name = name,
    handle = handle,
    description = description,
    avatarUrl = avatarUrl,
    bannerUrl = bannerUrl,
    subscriberCount = subscriberCount,
    videoCount = videoCount,
    totalViewCount = totalViewCount,
    isVerified = isVerified,
    createdAt = millisToTimestamp(createdAtMillis)
)

/** Maps a [Channel] domain model to a cacheable [ChannelEntity]. */
fun Channel.toEntity(): ChannelEntity = ChannelEntity(
    id = id,
    ownerId = ownerId,
    name = name,
    handle = handle,
    description = description,
    avatarUrl = avatarUrl,
    bannerUrl = bannerUrl,
    subscriberCount = subscriberCount,
    videoCount = videoCount,
    totalViewCount = totalViewCount,
    isVerified = isVerified,
    createdAtMillis = createdAt.toDate().time
)
