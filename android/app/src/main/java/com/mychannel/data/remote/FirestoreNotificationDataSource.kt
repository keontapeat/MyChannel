package com.mychannel.data.remote

import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import com.google.firebase.firestore.SetOptions
import com.mychannel.domain.model.Notification
import com.mychannel.domain.model.NotificationType
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Remote data source for the user's notification center
 * (`notifications/{uid}/items`, REQ-14.2).
 *
 * Real-time list uses [callbackFlow]; mutations run on [Dispatchers.IO].
 */
@Singleton
class FirestoreNotificationDataSource @Inject constructor(
    private val firestore: FirebaseFirestore
) {

    private fun items(userId: String) =
        firestore.collection(NOTIFICATIONS).document(userId).collection(ITEMS)

    fun observeNotifications(userId: String): Flow<List<Notification>> = callbackFlow {
        val registration = items(userId)
            .orderBy("createdAt", Query.Direction.DESCENDING)
            .limit(100)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    close(error)
                    return@addSnapshotListener
                }
                val notifications = snapshot?.documents?.map { doc ->
                    Notification(
                        id = doc.id,
                        type = NotificationType.fromRaw(doc.getString("type")),
                        title = doc.getString("title").orEmpty(),
                        body = doc.getString("body").orEmpty(),
                        imageUrl = doc.getString("imageUrl").orEmpty(),
                        @Suppress("UNCHECKED_CAST")
                        data = (doc.get("data") as? Map<String, String>) ?: emptyMap(),
                        isRead = doc.getBoolean("isRead") ?: false,
                        createdAt = doc.getTimestamp("createdAt")
                            ?: com.google.firebase.Timestamp(0, 0)
                    )
                } ?: emptyList()
                trySend(notifications)
            }
        awaitClose { registration.remove() }
    }

    suspend fun markAsRead(userId: String, notificationId: String): Unit =
        withContext(Dispatchers.IO) {
            items(userId).document(notificationId).update("isRead", true).await()
        }

    suspend fun markAllAsRead(userId: String): Unit = withContext(Dispatchers.IO) {
        val unread = items(userId).whereEqualTo("isRead", false).get().await()
        val batch = firestore.batch()
        unread.documents.forEach { batch.update(it.reference, "isRead", true) }
        batch.commit().await()
    }

    suspend fun deleteNotification(userId: String, notificationId: String): Unit =
        withContext(Dispatchers.IO) {
            items(userId).document(notificationId).delete().await()
        }

    /** Adds the device FCM token to the user document's `fcmTokens` array. */
    suspend fun updateFcmToken(userId: String, token: String): Unit =
        withContext(Dispatchers.IO) {
            firestore.collection(USERS).document(userId)
                .set(mapOf("fcmTokens" to FieldValue.arrayUnion(token)), SetOptions.merge())
                .await()
        }

    private companion object {
        const val NOTIFICATIONS = "notifications"
        const val ITEMS = "items"
        const val USERS = "users"
    }
}
