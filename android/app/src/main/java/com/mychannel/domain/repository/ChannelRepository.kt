package com.mychannel.domain.repository

import com.mychannel.domain.model.Channel
import com.mychannel.domain.model.MembershipTier
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

    // ── Memberships ────────────────────────────────────────────────────────────

    /** Fetch membership tiers for a channel. */
    suspend fun fetchMembershipTiers(channelId: String): List<MembershipTier>

    /** Fetch the active membership tier ID for [userId] on [channelId], or null. */
    suspend fun fetchActiveMembership(userId: String, channelId: String): String?

    /**
     * Initiate joining a membership tier.
     * 💰 Money note: actual charge is handled server-side via Cloud Function.
     * This only writes the intent to Firestore; the function processes billing.
     */
    suspend fun joinMembershipTier(userId: String, channelId: String, tierId: String): Result<Unit>

    /** Cancel the active membership for [userId] on [channelId]. */
    suspend fun cancelMembership(userId: String, channelId: String): Result<Unit>
}
