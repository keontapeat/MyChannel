package com.mychannel.data.remote

import com.google.firebase.auth.FirebaseAuth
import com.mychannel.BuildConfig
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.tasks.await
import okhttp3.Call
import okhttp3.Callback
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import org.json.JSONObject
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

@Singleton
class MusicQualifiedPlayReporter @Inject constructor(
    private val auth: FirebaseAuth,
    private val httpClient: OkHttpClient
) {
    private val accountingHttpClient = httpClient.newBuilder()
        .retryOnConnectionFailure(false)
        .followRedirects(false)
        .followSslRedirects(false)
        .build()

    suspend fun submit(trackId: String, sessionId: String): Result<Unit> = try {
        require(TRACK_ID.matches(trackId)) { "Invalid track ID" }
        require(CANONICAL_UUID.matches(sessionId)) { "Invalid playback session ID" }

        val baseUrl = BuildConfig.MUSIC_API_BASE_URL
            .trim()
            .toHttpUrlOrNull()
            ?.takeIf { it.isHttps && it.host.isNotBlank() }
            ?: return Result.failure(
                QualifiedPlayUnavailableException("API configuration unavailable")
            )
        val user = auth.currentUser
            ?: return Result.failure(
                QualifiedPlayUnavailableException("Authentication unavailable")
            )
        val idToken = user.getIdToken(false).await().token
            ?.takeIf(String::isNotBlank)
            ?: return Result.failure(
                QualifiedPlayUnavailableException("Authentication token unavailable")
            )
        val url = baseUrl.newBuilder()
            .addPathSegments("v1/music/tracks")
            .addPathSegment(trackId)
            .addPathSegment("plays")
            .build()
        val body = JSONObject()
            .put("sessionId", sessionId)
            .put("qualifiedSeconds", QUALIFIED_PLAY_SECONDS)
            .toString()
            .toRequestBody(JSON_MEDIA_TYPE)
        val request = Request.Builder()
            .url(url)
            .header("Authorization", "Bearer $idToken")
            .header("Idempotency-Key", sessionId)
            .post(body)
            .build()

        accountingHttpClient.newCall(request).awaitSuccessfulResponse()
        Result.success(Unit)
    } catch (error: CancellationException) {
        throw error
    } catch (error: Exception) {
        Result.failure(error)
    }

    private suspend fun Call.awaitSuccessfulResponse(): Unit =
        suspendCancellableCoroutine { continuation ->
            continuation.invokeOnCancellation { cancel() }
            enqueue(object : Callback {
                override fun onFailure(call: Call, error: IOException) {
                    if (continuation.isActive) continuation.resumeWithException(error)
                }

                override fun onResponse(call: Call, response: Response) {
                    response.use {
                        if (!continuation.isActive) return
                        if (response.isSuccessful) {
                            continuation.resume(Unit)
                        } else {
                            continuation.resumeWithException(
                                IOException(
                                    "Qualified music play request failed (${response.code})"
                                )
                            )
                        }
                    }
                }
            })
        }

    private class QualifiedPlayUnavailableException(message: String) :
        IllegalStateException(message)

    private companion object {
        const val QUALIFIED_PLAY_SECONDS = 30
        val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()
        val TRACK_ID = Regex("^[A-Za-z0-9_-]{1,128}$")
        val CANONICAL_UUID = Regex(
            "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
        )
    }
}
