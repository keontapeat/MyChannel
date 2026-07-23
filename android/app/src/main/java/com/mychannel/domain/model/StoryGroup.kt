package com.mychannel.domain.model

/**
 * A group of active stories for a single channel, used in the Stories feed.
 */
data class StoryGroup(
    val channelId: String,
    val channelName: String,
    val channelAvatarUrl: String,
    val stories: List<Story>,
    val hasUnread: Boolean
)
