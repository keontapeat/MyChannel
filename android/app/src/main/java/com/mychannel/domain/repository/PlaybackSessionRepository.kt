package com.mychannel.domain.repository

import com.mychannel.domain.model.PlaybackSession

interface PlaybackSessionRepository {
    suspend fun authorize(videoId: String): Result<PlaybackSession>

    suspend fun reportWatchTime(
        videoId: String,
        sessionId: String,
        watchTimeSeconds: Int,
        completionRate: Double?,
        qualifiedView: Boolean = false
    ): Result<Unit>
}
