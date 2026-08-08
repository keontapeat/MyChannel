package com.mychannel.data.remote

import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
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
 * Remote data source for the canonical flat notification inbox
 * (`notifications/{notificationId}` with an owner-bound `userId`).
 *
 * Real-time list uses [callbackFlow]; mutations run on [Dispatchers.IO].
 */
@Singleton
class FirestoreNotificationDataSource @Inject constructor(
    private val firestore: FirebaseFirestore
) {

    private fun notification(notificationId: String) =
        firestore.collection(NOTIFICATIONS).document(notificationId)

    private fun notificationQuery(userId: String) =
        firestore.collection(NOTIFICATIONS).whereEqualTo("userId", userId)

    fun observeNotifications(userId: String): Flow<List<Notification>> = callbackFlow {
        val registration = notificationQuery(userId)
            .orderBy("createdAt", Query.Direction.DESCENDING)
            .limit(100)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    close(error)
                    return@addSnapshotListener
                }
                val notifications = snapshot?.documents?.map { doc ->
                    val routingData = mutableMapOf<String, String>()
                    doc.getString("deepLink")?.let { routingData["deepLink"] = it }
                    doc.getString("videoId")?.let { routingData["videoId"] = it }
                    doc.getString("storyId")?.let { routingData["storyId"] = it }
                    @Suppress("UNCHECKED_CAST")
                    routingData.putAll((doc.get("data") as? Map<String, String>) ?: emptyMap())
                    Notification(
                        id = doc.id,
                        type = NotificationType.fromRaw(doc.getString("type")),
                        title = doc.getString("title").orEmpty(),
                        body = doc.getString("body") ?: doc.getString("message").orEmpty(),
                        imageUrl = doc.getString("imageURL")
                            ?: doc.getString("thumbnailURL").orEmpty(),
                        data = routingData,
                        isRead = doc.getBoolean("isRead") ?: doc.getBoolean("read") ?: false,
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
            notification(notificationId).update(
                mapOf("isRead" to true, "read" to true)
            ).await()
        }

    suspend fun markAllAsRead(userId: String): Unit = withContext(Dispatchers.IO) {
        val unread = notificationQuery(userId).whereEqualTo("isRead", false).get().await()
        val batch = firestore.batch()
        unread.documents.forEach {
            batch.update(it.reference, mapOf("isRead" to true, "read" to true))
        }
        batch.commit().await()
    }

    suspend fun deleteNotification(userId: String, notificationId: String): Unit =
        withContext(Dispatchers.IO) {
            notification(notificationId).delete().await()
        }

    /** Registers one active device token in the canonical per-token subcollection. */
    suspend fun updateFcmToken(userId: String, token: String): Unit =
        withContext(Dispatchers.IO) {
            if (token.isBlank() || token.contains('/')) return@withContext
            firestore.collection(USERS).document(userId)
                .collection(FCM_TOKENS).document(token)
                .set(
                    mapOf(
                        "token" to token,
                        "platform" to "android",
                        "active" to true,
                        "registeredAt" to FieldValue.serverTimestamp(),
                        "updatedAt" to FieldValue.serverTimestamp()
                    )
                )
                .await()
        }

    /** Detaches this device before sign-out so another account never receives its pushes. */
    suspend fun deleteFcmToken(userId: String, token: String): Unit =
        withContext(Dispatchers.IO) {
            if (token.isBlank() || token.contains('/')) return@withContext
            firestore.collection(USERS).document(userId)
                .collection(FCM_TOKENS).document(token)
                .delete()
                .await()
        }

    private companion object {
        const val NOTIFICATIONS = "notifications"
        const val USERS = "users"
        const val FCM_TOKENS = "fcmTokens"
    }
}
