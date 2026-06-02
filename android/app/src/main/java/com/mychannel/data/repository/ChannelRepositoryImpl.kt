package com.mychannel.data.repository

import com.mychannel.data.local.dao.ChannelDao
import com.mychannel.data.local.entity.toEntity
import com.mychannel.data.remote.FirebaseAuthDataSource
import com.mychannel.data.remote.FirestoreChannelDataSource
import com.mychannel.domain.model.Channel
import com.mychannel.domain.repository.ChannelRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.onEach
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
    private val channelDao: ChannelDao
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

    private fun requireUserId(): String =
        authDataSource.currentUserId ?: throw IllegalStateException("Not authenticated")
}
