package com.mychannel.data.remote

import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.mychannel.domain.model.Channel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Remote data source for channel documents and subscription relationships.
 *
 * Subscriptions are modeled as `users/{uid}/subscriptions/{channelId}` docs,
 * with the channel's `subscriberCount` adjusted atomically via [FieldValue.increment].
 */
@Singleton
class FirestoreChannelDataSource @Inject constructor(
    private val firestore: FirebaseFirestore
) {

    private fun channels() = firestore.collection(CHANNELS)

    fun observeChannel(channelId: String): Flow<Channel?> = callbackFlow {
        val registration = channels().document(channelId)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    close(error)
                    return@addSnapshotListener
                }
                trySend(snapshot?.toObject(Channel::class.java)?.copy(id = snapshot.id))
            }
        awaitClose { registration.remove() }
    }

    suspend fun getChannel(channelId: String): Channel = withContext(Dispatchers.IO) {
        val snapshot = channels().document(channelId).get().await()
        snapshot.toObject(Channel::class.java)?.copy(id = snapshot.id)
            ?: throw NoSuchElementException("Channel not found: $channelId")
    }

    suspend fun subscribe(userId: String, channelId: String): Unit = withContext(Dispatchers.IO) {
        firestore.runTransaction { txn ->
            val channelRef = channels().document(channelId)
            val subRef = firestore.collection(USERS).document(userId)
                .collection(SUBSCRIPTIONS).document(channelId)
            txn.set(subRef, mapOf("subscribedAt" to FieldValue.serverTimestamp()))
            txn.update(channelRef, "subscriberCount", FieldValue.increment(1L))
        }.await()
    }

    suspend fun unsubscribe(userId: String, channelId: String): Unit = withContext(Dispatchers.IO) {
        firestore.runTransaction { txn ->
            val channelRef = channels().document(channelId)
            val subRef = firestore.collection(USERS).document(userId)
                .collection(SUBSCRIPTIONS).document(channelId)
            txn.delete(subRef)
            txn.update(channelRef, "subscriberCount", FieldValue.increment(-1L))
        }.await()
    }

    suspend fun isSubscribed(userId: String, channelId: String): Boolean =
        withContext(Dispatchers.IO) {
            firestore.collection(USERS).document(userId)
                .collection(SUBSCRIPTIONS).document(channelId)
                .get().await().exists()
        }

    fun observeSubscriptions(userId: String): Flow<List<Channel>> = callbackFlow {
        val registration = firestore.collection(USERS).document(userId)
            .collection(SUBSCRIPTIONS)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    close(error)
                    return@addSnapshotListener
                }
                // Channel documents are loaded lazily by the repository; here we
                // emit lightweight channels keyed by the subscription doc id.
                val channels = snapshot?.documents?.map { doc ->
                    Channel(id = doc.id)
                } ?: emptyList()
                trySend(channels)
            }
        awaitClose { registration.remove() }
    }

    private companion object {
        const val CHANNELS = "channels"
        const val USERS = "users"
        const val SUBSCRIPTIONS = "subscriptions"
    }
}
