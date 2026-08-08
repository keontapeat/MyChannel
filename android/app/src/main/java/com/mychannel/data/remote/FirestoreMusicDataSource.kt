package com.mychannel.data.remote

import com.google.firebase.Timestamp
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import com.mychannel.domain.model.MusicTrack
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.net.URI
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FirestoreMusicDataSource @Inject constructor(
    private val firestore: FirebaseFirestore
) {
    suspend fun getPublishedTracks(limit: Long = MAX_TRACKS): List<MusicTrack> =
        withContext(Dispatchers.IO) {
            firestore.collection(COLLECTION)
                .whereEqualTo("isPublished", true)
                .whereEqualTo("status", "published")
                .orderBy("uploadedAt", Query.Direction.DESCENDING)
                .limit(limit.coerceIn(1L, MAX_TRACKS))
                .get()
                .await()
                .documents
                .mapNotNull { document ->
                    val renditions = document.get("renditions") as? Map<*, *>
                    val audioUrl = listOfNotNull(
                        renditions?.get("hls") as? String,
                        document.getString("hlsURL"),
                        document.getString("hlsUrl"),
                        document.getString("streamURL"),
                        document.getString("streamUrl"),
                        renditions?.get("mp3") as? String,
                        document.getString("mp3URL"),
                        document.getString("mp3Url")
                    ).firstOrNull { candidate -> candidate.trim().isPublicRenditionUrl() }
                        ?.trim()
                        ?: return@mapNotNull null

                    MusicTrack(
                        id = document.id,
                        title = document.getString("title").orEmpty(),
                        artistName = document.getString("artistName").orEmpty(),
                        albumName = document.getString("albumName").orEmpty(),
                        genre = document.getString("genre").orEmpty(),
                        isExplicit = document.getBoolean("isExplicit") ?: false,
                        durationSeconds = (document.get("duration") as? Number)?.toLong() ?: 0L,
                        artworkUrl = document.getString("artworkURL")
                            ?.trim()
                            ?.takeIf(String::isPublicRenditionUrl)
                            .orEmpty(),
                        audioUrl = audioUrl,
                        streamCount = (document.get("streamCount") as? Number)?.toLong() ?: 0L,
                        createdAt = document.getTimestamp("createdAt") ?: Timestamp(0, 0)
                    )
                }
        }

    private fun String.isPublicRenditionUrl(): Boolean = runCatching {
        val uri = URI(this)
        uri.scheme.equals("https", ignoreCase = true) && !uri.host.isNullOrBlank()
    }.getOrDefault(false)

    private companion object {
        const val COLLECTION = "music_tracks"
        const val MAX_TRACKS = 50L
    }
}
