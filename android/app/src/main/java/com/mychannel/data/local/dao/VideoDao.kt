package com.mychannel.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.mychannel.data.local.entity.VideoEntity
import kotlinx.coroutines.flow.Flow

/**
 * DAO for cached videos. Read queries return [Flow] so the UI observes cache
 * changes reactively (offline-first per REQ-1.4).
 */
@Dao
interface VideoDao {

    @Query("SELECT * FROM videos ORDER BY uploadedAtMillis DESC")
    fun observeAll(): Flow<List<VideoEntity>>

    @Query("SELECT * FROM videos WHERE isShort = 0 ORDER BY viewCount DESC")
    fun observeTrending(): Flow<List<VideoEntity>>

    @Query("SELECT * FROM videos WHERE isShort = 1 ORDER BY uploadedAtMillis DESC")
    fun observeShorts(): Flow<List<VideoEntity>>

    @Query("SELECT * FROM videos WHERE channelId = :channelId ORDER BY uploadedAtMillis DESC")
    fun observeByChannel(channelId: String): Flow<List<VideoEntity>>

    @Query("SELECT * FROM videos WHERE id = :id LIMIT 1")
    suspend fun getById(id: String): VideoEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(video: VideoEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(videos: List<VideoEntity>)

    @Query("DELETE FROM videos WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("DELETE FROM videos")
    suspend fun clear()
}
