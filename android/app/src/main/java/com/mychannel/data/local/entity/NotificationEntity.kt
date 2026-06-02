package com.mychannel.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.mychannel.domain.model.Notification
import com.mychannel.domain.model.NotificationType

/**
 * Room entity caching a [Notification] for the in-app notification center
 * (REQ-14.2), enabling offline access to recent notifications.
 *
 * [type] is persisted as its enum name; [data] is JSON-encoded via
 * [com.mychannel.data.local.Converters].
 */
@Entity(tableName = "notifications")
data class NotificationEntity(
    @PrimaryKey val id: String,
    val type: String,
    val title: String,
    val body: String,
    val imageUrl: String,
    val data: Map<String, String>,
    val isRead: Boolean,
    val createdAtMillis: Long,
    val cachedAtMillis: Long = System.currentTimeMillis()
)

/** Maps a cached [NotificationEntity] to its [Notification] domain model. */
fun NotificationEntity.toDomain(): Notification = Notification(
    id = id,
    type = runCatching { NotificationType.valueOf(type) }.getOrDefault(NotificationType.UNKNOWN),
    title = title,
    body = body,
    imageUrl = imageUrl,
    data = data,
    isRead = isRead,
    createdAt = millisToTimestamp(createdAtMillis)
)

/** Maps a [Notification] domain model to a cacheable [NotificationEntity]. */
fun Notification.toEntity(): NotificationEntity = NotificationEntity(
    id = id,
    type = type.name,
    title = title,
    body = body,
    imageUrl = imageUrl,
    data = data,
    isRead = isRead,
    createdAtMillis = createdAt.toDate().time
)
