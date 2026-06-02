package com.mychannel.domain.model

import com.google.firebase.Timestamp

/**
 * Notification type discriminator. Values map to the `type` field on the
 * Firestore `notifications/{uid}/items/{notifId}` document and to FCM payloads.
 */
enum class NotificationType {
    NEW_SUBSCRIBER,
    NEW_COMMENT,
    LIVE_STARTED,
    VS_MATCH_CHALLENGE,
    VS_MATCH_RESULT,
    PAYOUT_RECEIVED,
    UNKNOWN;

    companion object {
        /** Parse a raw Firestore/FCM type string into a [NotificationType]. */
        fun fromRaw(raw: String?): NotificationType = when (raw?.lowercase()) {
            "new_subscriber", "new_sub" -> NEW_SUBSCRIBER
            "new_comment", "comment" -> NEW_COMMENT
            "live_started", "live" -> LIVE_STARTED
            "vs_match_challenge", "vs_challenge" -> VS_MATCH_CHALLENGE
            "vs_match_result", "vs_result" -> VS_MATCH_RESULT
            "payout_received", "payout" -> PAYOUT_RECEIVED
            else -> UNKNOWN
        }
    }
}

/**
 * Notification domain model — mirrors `notifications/{uid}/items/{notifId}`.
 *
 * [data] carries deep-link routing info (e.g. videoId, channelId, matchId)
 * used to navigate when a notification is tapped.
 */
data class Notification(
    val id: String = "",
    val type: NotificationType = NotificationType.UNKNOWN,
    val title: String = "",
    val body: String = "",
    val imageUrl: String = "",
    val data: Map<String, String> = emptyMap(),
    val isRead: Boolean = false,
    val createdAt: Timestamp = Timestamp(0, 0)
)
