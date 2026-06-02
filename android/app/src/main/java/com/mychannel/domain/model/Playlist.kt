package com.mychannel.domain.model

import com.google.firebase.Timestamp

/**
 * Playlist domain model — a curated, ordered collection of videos.
 *
 * [videoIds] preserves ordering. [privacyStatus] matches the video privacy
 * vocabulary ("public" | "unlisted" | "private").
 */
data class Playlist(
    val id: String = "",
    val ownerId: String = "",
    val title: String = "",
    val description: String = "",
    val thumbnailUrl: String = "",
    val videoIds: List<String> = emptyList(),
    val videoCount: Long = 0L,
    val privacyStatus: String = "private",
    val createdAt: Timestamp = Timestamp(0, 0),
    val updatedAt: Timestamp = Timestamp(0, 0)
)
