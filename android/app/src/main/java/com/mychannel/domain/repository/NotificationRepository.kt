package com.mychannel.domain.repository

import com.mychannel.domain.model.Notification
import kotlinx.coroutines.flow.Flow

/**
 * Repository for the in-app notification center (REQ-14.2, REQ-14.3).
 *
 * Reads the current user's `notifications/{uid}/items` collection in real time
 * and supports read/unread tracking and deletion.
 */
interface NotificationRepository {

    /** Real-time list of the current user's notifications, newest-first. */
    fun observeNotifications(): Flow<List<Notification>>

    /** Real-time unread count for badge display. */
    fun observeUnreadCount(): Flow<Int>

    suspend fun markAsRead(notificationId: String): Result<Unit>

    suspend fun markAllAsRead(): Result<Unit>

    suspend fun deleteNotification(notificationId: String): Result<Unit>

    /** Registers/updates the device's FCM token on the user document (REQ-14.1). */
    suspend fun updateFcmToken(token: String): Result<Unit>
}
