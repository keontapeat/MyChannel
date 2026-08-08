package com.mychannel.data.repository

import com.google.firebase.auth.FirebaseAuth
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.mychannel.BuildConfig
import com.mychannel.domain.model.PlaybackAuthorizationException
import com.mychannel.domain.model.PlaybackSession
import com.mychannel.domain.repository.PlaybackSessionRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.net.URI
import java.time.Instant
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class PlaybackSessionRepositoryImpl @Inject constructor(
    private val auth: FirebaseAuth,
    private val httpClient: OkHttpClient
) : PlaybackSessionRepository {

    override suspend fun authorize(videoId: String): Result<PlaybackSession> = withContext(Dispatchers.IO) {
        runCatching {
            require(VIDEO_ID.matches(videoId)) { "Video unavailable" }
            check(auth.currentUser != null) { "Sign in to watch this video" }
            val request = Request.Builder()
                .url("${BuildConfig.API_BASE_URL.trimEnd('/')}/v1/videos/$videoId/playback-session")
                .post("{}".toRequestBody(JSON_MEDIA_TYPE))
                .build()
            httpClient.newCall(request).execute().use { response ->
                val payload = response.body?.string()?.let(JsonParser::parseString)?.asJsonObject
                    ?: throw PlaybackAuthorizationException("Video unavailable")
                parseSession(videoId, payload)
            }
        }
    }

    override suspend fun reportWatchTime(
        videoId: String,
        sessionId: String,
        watchTimeSeconds: Int,
        completionRate: Double?,
        qualifiedView: Boolean
    ): Result<Unit> = withContext(Dispatchers.IO) {
        runCatching {
            require(VIDEO_ID.matches(videoId) && VIDEO_ID.matches(sessionId)) { "Invalid playback session" }
            require(watchTimeSeconds in 1..86_400) { "Invalid watch time" }
            require(completionRate == null || completionRate in 0.0..1.0) { "Invalid completion rate" }
            check(auth.currentUser != null) { "Sign in to watch this video" }
            val payload = JsonObject().apply {
                addProperty("sessionId", sessionId)
                addProperty("watchTime", watchTimeSeconds)
                completionRate?.let { addProperty("completionRate", it) }
                if (qualifiedView) addProperty("qualifiedView", true)
            }
            val request = Request.Builder()
                .url("${BuildConfig.API_BASE_URL.trimEnd('/')}/v1/videos/$videoId/engagement/watch-time")
                .post(payload.toString().toRequestBody(JSON_MEDIA_TYPE))
                .build()
            httpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    throw PlaybackAuthorizationException("Playback engagement rejected")
                }
            }
        }
    }

    private fun parseSession(videoId: String, payload: JsonObject): PlaybackSession {
        val denialReason = payload.string("denialReason")
        if (payload.string("version") != "1.0" || payload.string("videoId") != videoId ||
            !payload.hasObject("policy") || !payload.hasObject("ads") ||
            !payload.hasObject("capabilities") || payload.boolean("canPlay") != true) {
            throw PlaybackAuthorizationException(denialMessage(denialReason))
        }
        val sessionId = payload.string("sessionId")
            ?.takeIf { VIDEO_ID.matches(it) }
            ?: throw PlaybackAuthorizationException("Video unavailable")
        val manifest = payload.string("playbackManifestUrl")
            ?.takeIf(::isApprovedManifest)
            ?: throw PlaybackAuthorizationException("Video unavailable")
        val expiresAt = payload.string("expiresAt")?.let {
            runCatching { Instant.parse(it).toEpochMilli() }.getOrNull()
                ?: throw PlaybackAuthorizationException("Video unavailable")
        }
        if (expiresAt != null && expiresAt <= System.currentTimeMillis()) {
            throw PlaybackAuthorizationException("Playback authorization expired")
        }
        val ads = payload.getAsJsonObject("ads")
        val capabilities = payload.getAsJsonObject("capabilities")
        val supportsHls = capabilities.boolean("hls") == true
        val supportsDash = capabilities.boolean("dash") == true
        if (!supportsHls && !supportsDash) {
            throw PlaybackAuthorizationException("Video unavailable")
        }
        return PlaybackSession(
            sessionId = sessionId,
            videoId = videoId,
            manifestUrl = manifest,
            expiresAtEpochMs = expiresAt,
            adsEnabled = ads.boolean("enabled") == true,
            supportsHls = supportsHls,
            supportsDash = supportsDash,
            supportsCaptions = capabilities.boolean("captions") == true,
            supportsOfflineDownload = capabilities.boolean("offlineDownload") == true,
            supportsPictureInPicture = capabilities.boolean("pictureInPicture") == true,
            supportsCasting = capabilities.boolean("casting") == true
        )
    }

    private fun isApprovedManifest(value: String): Boolean = runCatching {
        val uri = URI(value)
        val host = uri.host?.lowercase() ?: return false
        val path = uri.path?.lowercase().orEmpty()
        uri.scheme == "https" && uri.userInfo == null &&
            APPROVED_MEDIA_HOSTS.any { host == it || host.endsWith(".$it") } &&
            (path.endsWith(".m3u8") || path.endsWith(".mpd"))
    }.getOrDefault(false)

    private fun denialMessage(reason: String?): String = when (reason) {
        "authentication_required" -> "Sign in to watch this video"
        "app_check_required" -> "Device verification is required"
        "age_verification_required" -> "Age verification is required"
        "region_denied" -> "This video is not available in your region"
        "entitlement_required" -> "A channel membership is required"
        "processing_not_ready" -> "This video is still processing"
        "moderation_not_approved" -> "This video is under review"
        "manifest_expired" -> "Playback authorization expired"
        else -> "Video unavailable"
    }

    private fun JsonObject.string(name: String): String? =
        get(name)?.takeUnless { it.isJsonNull }?.asString

    private fun JsonObject.boolean(name: String): Boolean? =
        get(name)?.takeUnless { it.isJsonNull }?.asBoolean

    private fun JsonObject.hasObject(name: String): Boolean =
        get(name)?.isJsonObject == true

    private companion object {
        val VIDEO_ID = Regex("^[A-Za-z0-9_-]{1,128}$")
        val JSON_MEDIA_TYPE = "application/json".toMediaType()
        val APPROVED_MEDIA_HOSTS = setOf(
            "firebasestorage.googleapis.com",
            "storage.googleapis.com",
            "commondatastorage.googleapis.com",
            "devstreaming-cdn.apple.com",
            "akamaized.net",
            "cloudfront.net",
            "mychannel.live"
        )
    }
}
