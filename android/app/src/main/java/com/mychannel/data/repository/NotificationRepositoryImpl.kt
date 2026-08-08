package com.mychannel.data.repository

import com.mychannel.data.local.dao.NotificationDao
import com.mychannel.data.local.entity.toEntity
import com.mychannel.data.remote.FirebaseAuthDataSource
import com.mychannel.data.remote.FirestoreNotificationDataSource
import com.mychannel.domain.model.Notification
import com.mychannel.domain.repository.NotificationRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.onEach
import javax.inject.Inject
import javax.inject.Singleton

/**
 * [NotificationRepository] backed by [FirestoreNotificationDataSource] with
 * Room caching for offline access to recent notifications (REQ-14.2).
 */
@Singleton
class NotificationRepositoryImpl @Inject constructor(
    private val notificationDataSource: FirestoreNotificationDataSource,
    private val authDataSource: FirebaseAuthDataSource,
    private val notificationDao: NotificationDao
) : NotificationRepository {

    override fun observeNotifications(): Flow<List<Notification>> {
        val uid = authDataSource.currentUserId ?: return flowOf(emptyList())
        return notificationDataSource.observeNotifications(uid)
            .onEach { notifications ->
                notificationDao.upsertAll(notifications.map { it.toEntity() })
            }
            .flowOn(Dispatchers.IO)
    }

    override fun observeUnreadCount(): Flow<Int> = notificationDao.observeUnreadCount()

    override suspend fun markAsRead(notificationId: String): Result<Unit> = runCatching {
        val uid = requireUserId()
        notificationDataSource.markAsRead(uid, notificationId)
        notificationDao.markAsRead(notificationId)
    }

    override suspend fun markAllAsRead(): Result<Unit> = runCatching {
        val uid = requireUserId()
        notificationDataSource.markAllAsRead(uid)
        notificationDao.markAllAsRead()
    }

    override suspend fun deleteNotification(notificationId: String): Result<Unit> = runCatching {
        val uid = requireUserId()
        notificationDataSource.deleteNotification(uid, notificationId)
        notificationDao.deleteById(notificationId)
    }

    override suspend fun updateFcmToken(token: String): Result<Unit> = runCatching {
        val uid = requireUserId()
        notificationDataSource.updateFcmToken(uid, token)
    }

    override suspend fun unregisterFcmToken(token: String): Result<Unit> = runCatching {
        val uid = requireUserId()
        notificationDataSource.deleteFcmToken(uid, token)
    }

    private fun requireUserId(): String =
        authDataSource.currentUserId ?: throw IllegalStateException("Not authenticated")
}
