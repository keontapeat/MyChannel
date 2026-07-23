package com.mychannel.data.repository

import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.mychannel.data.local.dao.ChannelDao
import com.mychannel.data.local.entity.toEntity
import com.mychannel.data.remote.FirebaseAuthDataSource
import com.mychannel.data.remote.FirestoreChannelDataSource
import com.mychannel.domain.model.Channel
import com.mychannel.domain.model.MembershipTier
import com.mychannel.domain.repository.ChannelRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

/**
 * [ChannelRepository] backed by [FirestoreChannelDataSource] with Room caching.
 *
 * Subscription mutations are atomic Firestore transactions performed in the
 * data source. The current user id is resolved from [FirebaseAuthDataSource].
 */
@Singleton
class ChannelRepositoryImpl @Inject constructor(
    private val channelDataSource: FirestoreChannelDataSource,
    private val authDataSource: FirebaseAuthDataSource,
    private val channelDao: ChannelDao,
    private val firestore: FirebaseFirestore
) : ChannelRepository {

    override fun observeChannel(channelId: String): Flow<Channel?> =
        channelDataSource.observeChannel(channelId)
            .onEach { channel -> channel?.let { channelDao.upsert(it.toEntity()) } }
            .flowOn(Dispatchers.IO)

    override suspend fun getChannel(channelId: String): Result<Channel> = runCatching {
        channelDataSource.getChannel(channelId).also { channelDao.upsert(it.toEntity()) }
    }

    override suspend fun subscribe(channelId: String): Result<Unit> = runCatching {
        val uid = requireUserId()
        channelDataSource.subscribe(uid, channelId)
    }

    override suspend fun unsubscribe(channelId: String): Result<Unit> = runCatching {
        val uid = requireUserId()
        channelDataSource.unsubscribe(uid, channelId)
    }

    override suspend fun isSubscribed(channelId: String): Result<Boolean> = runCatching {
        val uid = requireUserId()
        channelDataSource.isSubscribed(uid, channelId)
    }

    override fun observeSubscriptions(): Flow<List<Channel>> {
        val uid = authDataSource.currentUserId
            ?: return kotlinx.coroutines.flow.flowOf(emptyList())
        return channelDataSource.observeSubscriptions(uid)
    }

    // ── Memberships ────────────────────────────────────────────────────────────

    override suspend fun fetchMembershipTiers(channelId: String): List<MembershipTier> {
        val snap = firestore.collection("membershipTiers")
            .whereEqualTo("channelId", channelId)
            .get().await()
        return snap.documents.mapNotNull { d ->
            val data = d.data ?: return@mapNotNull null
            MembershipTier(
                id = d.id,
                name = data["name"] as? String ?: "",
                priceMonthly = (data["priceMonthly"] as? Long) ?: 499L,
                perks = (data["perks"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
                memberCount = ((data["memberCount"] as? Long) ?: 0L).toInt(),
                badgeEmoji = data["badgeEmoji"] as? String ?: "⭐"
            )
        }
    }

    override suspend fun fetchActiveMembership(userId: String, channelId: String): String? {
        val snap = firestore.collection("memberships")
            .whereEqualTo("userId", userId)
            .whereEqualTo("channelId", channelId)
            .whereEqualTo("status", "active")
            .limit(1)
            .get().await()
        return snap.documents.firstOrNull()?.getString("tierId")
    }

    /**
     * 💰 Money note: actual billing is processed by the Cloud Function
     * `onMembershipJoin`. This only writes the intent to Firestore.
     */
    override suspend fun joinMembershipTier(
        userId: String,
        channelId: String,
        tierId: String
    ): Result<Unit> = runCatching {
        firestore.collection("membershipIntents").add(
            mapOf(
                "userId" to userId,
                "channelId" to channelId,
                "tierId" to tierId,
                "status" to "pending",
                "createdAt" to FieldValue.serverTimestamp()
            )
        ).await()
    }

    override suspend fun cancelMembership(userId: String, channelId: String): Result<Unit> = runCatching {
        val snap = firestore.collection("memberships")
            .whereEqualTo("userId", userId)
            .whereEqualTo("channelId", channelId)
            .whereEqualTo("status", "active")
            .limit(1)
            .get().await()
        snap.documents.firstOrNull()?.reference?.update(
            mapOf(
                "status" to "cancelled",
                "cancelledAt" to FieldValue.serverTimestamp()
            )
        )?.await()
    }

    private fun requireUserId(): String =
        authDataSource.currentUserId ?: throw IllegalStateException("Not authenticated")
}
