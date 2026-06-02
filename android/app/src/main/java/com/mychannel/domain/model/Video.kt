package com.mychannel.domain.model

import com.google.firebase.Timestamp

/**
 * Video domain model — mirrors the Firestore `videos/{videoId}` document.
 *
 * All fields have defaults so Firestore's `toObject(Video::class.java)`
 * deserialization works (Firestore requires a no-arg-friendly data class).
 *
 * Field names match design.md and the iOS/web clients.
 */
data class Video(
    val id: String = "",
    val title: String = "",
    val description: String = "",
    val thumbnailUrl: String = "",
    val videoUrl: String = "",          // HLS manifest URL
    val channelId: String = "",
    val channelName: String = "",
    val channelAvatarUrl: String = "",
    val viewCount: Long = 0L,
    val likeCount: Long = 0L,
    val dislikeCount: Long = 0L,
    val commentCount: Long = 0L,
    val duration: Long = 0L,            // seconds
    val uploadedAt: Timestamp = Timestamp(0, 0),
    val tags: List<String> = emptyList(),
    val category: String = "",
    val isLive: Boolean = false,
    val isShort: Boolean = false,
    val privacyStatus: String = "public" // "public" | "unlisted" | "private"
)
