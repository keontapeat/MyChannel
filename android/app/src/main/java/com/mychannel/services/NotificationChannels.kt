package com.mychannel.services

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.core.content.getSystemService
import com.mychannel.domain.model.NotificationType

/**
 * Central definition of the app's notification channels (Task 14 / REQ-14.1,
 * REQ-14.3) plus the mapping from a [NotificationType] to the channel a message
 * should post on.
 *
 * Channels are created once in [com.mychannel.MyChannelApp.onCreate] and are a
 * no-op below Android 8.0 (API 26). Keeping the IDs and the
 * type→channel mapping in one place keeps [MyChannelMessagingService] and the
 * app initialisation in sync.
 */
object NotificationChannels {

    /** New uploads / comments — general content activity. */
    const val NEW_CONTENT = "new_content"

    /** A followed creator started a live stream. */
    const val LIVE_STREAMS = "live_streams"

    /** VS Match challenges and results. */
    const val VS_MATCHES = "vs_matches"

    /** Payout-received notifications (display-only; no money logic here). */
    const val PAYOUTS = "payouts"

    /**
     * Resolves the channel a [type] should post on. Unknown/UI-less types fall
     * back to [NEW_CONTENT] so a message is never silently dropped.
     */
    fun channelFor(type: NotificationType): String = when (type) {
        NotificationType.NEW_SUBSCRIBER,
        NotificationType.NEW_COMMENT -> NEW_CONTENT
        NotificationType.LIVE_STARTED -> LIVE_STREAMS
        NotificationType.VS_MATCH_CHALLENGE,
        NotificationType.VS_MATCH_RESULT -> VS_MATCHES
        NotificationType.PAYOUT_RECEIVED -> PAYOUTS
        NotificationType.UNKNOWN -> NEW_CONTENT
    }

    /**
     * Creates all notification channels. Safe to call on every app start —
     * creating a channel that already exists updates its (mutable) name/
     * description without resetting user-controlled importance.
     */
    fun createAll(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        createChannelsApi26(context)
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun createChannelsApi26(context: Context) {
        val manager = context.getSystemService<NotificationManager>() ?: return
        val channels = listOf(
            NotificationChannel(
                NEW_CONTENT,
                "New Content",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "New videos, comments, and subscriber activity."
            },
            NotificationChannel(
                LIVE_STREAMS,
                "Live Streams",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts when creators you follow go live."
            },
            NotificationChannel(
                VS_MATCHES,
                "VS Matches",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "VS Match challenges and results."
            },
            NotificationChannel(
                PAYOUTS,
                "Payouts",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Updates about payouts to your account."
            }
        )
        manager.createNotificationChannels(channels)
    }
}
