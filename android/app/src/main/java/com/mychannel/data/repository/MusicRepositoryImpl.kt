package com.mychannel.data.repository

import com.mychannel.data.remote.FirestoreMusicDataSource
import com.mychannel.domain.model.MusicTrack
import com.mychannel.domain.repository.MusicRepository
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class MusicRepositoryImpl @Inject constructor(
    private val musicDataSource: FirestoreMusicDataSource
) : MusicRepository {
    override suspend fun getPublishedTracks(): Result<List<MusicTrack>> =
        runCatching { musicDataSource.getPublishedTracks() }
}
