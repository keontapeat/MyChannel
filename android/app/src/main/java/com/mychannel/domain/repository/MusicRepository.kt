package com.mychannel.domain.repository

import com.mychannel.domain.model.MusicTrack

interface MusicRepository {
    suspend fun getPublishedTracks(): Result<List<MusicTrack>>
}
