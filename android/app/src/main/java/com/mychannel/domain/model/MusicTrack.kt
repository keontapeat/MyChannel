package com.mychannel.domain.model

import com.google.firebase.Timestamp

/** Read-only music track metadata from `music_tracks/{trackId}`. */
data class MusicTrack(
    val id: String,
    val title: String,
    val artistName: String,
    val albumName: String,
    val genre: String,
    val isExplicit: Boolean,
    val durationSeconds: Long,
    val artworkUrl: String,
    val audioUrl: String,
    val streamCount: Long,
    val createdAt: Timestamp
)
