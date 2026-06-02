package com.mychannel.domain.model

import com.google.firebase.Timestamp

/**
 * Story domain model — ephemeral creator content shown in the Home stories row.
 *
 * [isLive] drives the pulsing live ring on the home Stories row for creators
 * who are currently broadcasting.
 */
data class Story(
    val id: String = "",
    val channelId: String = "",
    val creatorName: String = "",
    val avatarUrl: String = "",
    val mediaUrl: String = "",
    val isLive: Boolean = false,
    val isViewed: Boolean = false,
    val createdAt: Timestamp = Timestamp(0, 0),
    val expiresAt: Timestamp = Timestamp(0, 0)
)
