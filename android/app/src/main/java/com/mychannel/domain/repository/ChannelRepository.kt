package com.mychannel.domain.repository

import com.mychannel.domain.model.Channel
import kotlinx.coroutines.flow.Flow

/**
 * Repository for channel data and subscriptions (REQ-9.x, REQ-11.x).
 */
interface ChannelRepository {

    /** Real-time channel document updates (subscriber counts, etc.). */
    fun observeChannel(channelId: String): Flow<Channel?>

    suspend fun getChannel(channelId: String): Result<Channel>

    /** Subscribe the current user to a channel (atomic subscriber-count update). */
    suspend fun subscribe(channelId: String): Result<Unit>

    /** Unsubscribe the current user from a channel (atomic update). */
    suspend fun unsubscribe(channelId: String): Result<Unit>

    /** Whether the current user is subscribed to [channelId]. */
    suspend fun isSubscribed(channelId: String): Result<Boolean>

    /** Real-time list of channels the current user is subscribed to. */
    fun observeSubscriptions(): Flow<List<Channel>>
}
