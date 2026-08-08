package com.mychannel.services

import android.os.SystemClock
import android.util.Log
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.mychannel.data.remote.MusicQualifiedPlayReporter
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.util.Locale
import java.util.UUID
import javax.inject.Inject

/**
 * Background Media3 session for music playback and qualified-play accounting.
 */
@AndroidEntryPoint
class MediaPlaybackService : MediaSessionService() {

    @Inject
    lateinit var qualifiedPlayReporter: MusicQualifiedPlayReporter

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var mediaSession: MediaSession? = null
    private var playbackSession: QualifiedPlaybackSession? = null

    private val playerListener = object : Player.Listener {
        override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
            playbackSession = mediaItem?.mediaId
                ?.takeIf(String::isNotBlank)
                ?.let { QualifiedPlaybackSession(it, newSessionId()) }
                ?.also { session ->
                    if (mediaSession?.player?.isPlaying == true) {
                        session.lastPlayingRealtimeMs = SystemClock.elapsedRealtime()
                    }
                }
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            if (isPlaying) {
                ensurePlaybackSession(mediaSession?.player?.currentMediaItem)
                    ?.lastPlayingRealtimeMs = SystemClock.elapsedRealtime()
            } else {
                playbackSession?.lastPlayingRealtimeMs = null
            }
        }

        override fun onPlaybackStateChanged(playbackState: Int) {
            if (playbackState == Player.STATE_ENDED || playbackState == Player.STATE_IDLE) {
                playbackSession = null
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        val player = ExoPlayer.Builder(this)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                    .build(),
                /* handleAudioFocus= */ true
            )
            .setHandleAudioBecomingNoisy(true)
            .build()
        player.addListener(playerListener)

        mediaSession = MediaSession.Builder(this, player).build()
        monitorQualifiedPlayback(player)
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? =
        mediaSession

    private fun monitorQualifiedPlayback(player: Player) {
        serviceScope.launch {
            while (isActive) {
                delay(PROGRESS_INTERVAL_MS)
                if (!player.isPlaying) {
                    playbackSession?.lastPlayingRealtimeMs = null
                    continue
                }

                val session = ensurePlaybackSession(player.currentMediaItem) ?: continue
                val nowMs = SystemClock.elapsedRealtime()
                val previousRealtimeMs = session.lastPlayingRealtimeMs
                session.lastPlayingRealtimeMs = nowMs
                if (previousRealtimeMs == null) continue

                session.listenedMs += (nowMs - previousRealtimeMs)
                    .coerceIn(0L, MAX_PLAYING_DELTA_MS)
                if (session.listenedMs < QUALIFIED_PLAY_MS || session.submissionAttempted) continue

                session.submissionAttempted = true
                launch {
                    qualifiedPlayReporter.submit(session.trackId, session.sessionId)
                        .onFailure {
                            Log.w(TAG, "Qualified play accounting unavailable; playback continues")
                        }
                }
            }
        }
    }

    private fun ensurePlaybackSession(mediaItem: MediaItem?): QualifiedPlaybackSession? {
        val trackId = mediaItem?.mediaId?.takeIf(String::isNotBlank) ?: return null
        val currentSession = playbackSession
        if (currentSession != null && currentSession.trackId == trackId) return currentSession

        return QualifiedPlaybackSession(trackId, newSessionId()).also {
            playbackSession = it
        }
    }

    override fun onDestroy() {
        serviceScope.cancel()
        mediaSession?.run {
            player.removeListener(playerListener)
            player.release()
            release()
            mediaSession = null
        }
        playbackSession = null
        super.onDestroy()
    }

    private data class QualifiedPlaybackSession(
        val trackId: String,
        val sessionId: String,
        var listenedMs: Long = 0L,
        var lastPlayingRealtimeMs: Long? = null,
        var submissionAttempted: Boolean = false
    )

    private companion object {
        const val TAG = "MediaPlaybackService"
        const val PROGRESS_INTERVAL_MS = 1_000L
        const val MAX_PLAYING_DELTA_MS = 1_500L
        const val QUALIFIED_PLAY_MS = 30_000L

        fun newSessionId(): String = UUID.randomUUID().toString().lowercase(Locale.ROOT)
    }
}
