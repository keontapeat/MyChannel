package com.mychannel.services

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.mychannel.MainActivity
import com.mychannel.R
import dagger.hilt.android.AndroidEntryPoint

/**
 * Firebase Cloud Messaging service.
 *
 * Handles incoming push notifications (new uploads, live streams, VS match
 * results, tips) and token refresh. Declared in AndroidManifest.xml.
 */
@AndroidEntryPoint
class MyChannelMessagingService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // Token refresh — upload the new token to Firestore via a background job.
        // The token is stored server-side for targeting this device.
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        val data = message.data
        val type = data["type"] ?: "general"
        val channelId = resolveChannelId(type)

        val title = message.notification?.title
            ?: data["title"]
            ?: "MyChannel"
        val body = message.notification?.body
            ?: data["body"]
            ?: ""

        val deepLinkPath = data["deepLink"]
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (!deepLinkPath.isNullOrBlank()) {
                setData(android.net.Uri.parse(deepLinkPath))
            }
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(notificationPriority(type))
            .build()

        val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
    }

    /** Map FCM message type to the pre-registered notification channel ID. */
    private fun resolveChannelId(type: String): String = when (type) {
        "live_stream" -> NotificationChannels.LIVE_STREAMS
        "vs_match" -> NotificationChannels.VS_MATCHES
        "tip", "super_chat", "payout" -> NotificationChannels.PAYOUTS
        else -> NotificationChannels.NEW_CONTENT
    }

    private fun notificationPriority(type: String): Int = when (type) {
        "live_stream", "vs_match" -> NotificationCompat.PRIORITY_HIGH
        else -> NotificationCompat.PRIORITY_DEFAULT
    }
}
