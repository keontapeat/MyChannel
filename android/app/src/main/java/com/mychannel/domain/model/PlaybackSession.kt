package com.mychannel.domain.model

data class PlaybackSession(
    val sessionId: String,
    val videoId: String,
    val manifestUrl: String,
    val expiresAtEpochMs: Long?,
    val adsEnabled: Boolean,
    val supportsHls: Boolean,
    val supportsDash: Boolean,
    val supportsCaptions: Boolean,
    val supportsOfflineDownload: Boolean,
    val supportsPictureInPicture: Boolean,
    val supportsCasting: Boolean
)

class PlaybackAuthorizationException(
    override val message: String
) : IllegalStateException(message)
