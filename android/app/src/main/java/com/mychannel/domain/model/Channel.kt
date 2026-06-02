package com.mychannel.domain.model

import com.google.firebase.Timestamp

/**
 * Channel domain model — mirrors the Firestore `channels/{channelId}` document.
 *
 * Channels share most fields with [User] (a creator channel), with additional
 * branding and aggregate stats.
 */
data class Channel(
    val id: String = "",
    val ownerId: String = "",
    val name: String = "",
    val handle: String = "",
    val description: String = "",
    val avatarUrl: String = "",
    val bannerUrl: String = "",
    val subscriberCount: Long = 0L,
    val videoCount: Long = 0L,
    val totalViewCount: Long = 0L,
    val isVerified: Boolean = false,
    val createdAt: Timestamp = Timestamp(0, 0)
)
