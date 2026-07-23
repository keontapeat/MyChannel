package com.mychannel.domain.model

/**
 * Represents a single end screen element overlaid on the last 20s of a video.
 * Type values: "video" | "playlist" | "subscribe" | "channel" | "link"
 */
data class EndScreenElement(
    val id: String = "",
    val type: String = "video",
    val title: String = "",
    val targetId: String = "",
    val xPct: Float = 0.5f,
    val yPct: Float = 0.5f,
    val startSeconds: Double = 0.0,
    val endSeconds: Double = 0.0
)
