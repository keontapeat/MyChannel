package com.mychannel.domain.model

import com.google.firebase.Timestamp

/**
 * LiveStream domain model — mirrors the Firestore `liveStreams/{streamId}` document.
 *
 * `creatorName` is retained for UI display (used by HomeScreen) in addition to
 * the design's documented fields.
 */
data class LiveStream(
    val id: String = "",
    val channelId: String = "",
    val creatorName: String = "",
    val title: String = "",
    val thumbnailUrl: String = "",
    val hlsUrl: String = "",
    val viewerCount: Long = 0L,
    val startedAt: Timestamp = Timestamp(0, 0),
    val status: String = "live"          // "live" | "ended" | "scheduled"
)
