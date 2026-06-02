package com.mychannel.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.mychannel.data.local.entity.PlaylistEntity
import kotlinx.coroutines.flow.Flow

/**
 * DAO for cached playlists (REQ-10.3).
 */
@Dao
interface PlaylistDao {

    @Query("SELECT * FROM playlists ORDER BY updatedAtMillis DESC")
    fun observeAll(): Flow<List<PlaylistEntity>>

    @Query("SELECT * FROM playlists WHERE ownerId = :ownerId ORDER BY updatedAtMillis DESC")
    fun observeByOwner(ownerId: String): Flow<List<PlaylistEntity>>

    @Query("SELECT * FROM playlists WHERE id = :id LIMIT 1")
    suspend fun getById(id: String): PlaylistEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(playlist: PlaylistEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(playlists: List<PlaylistEntity>)

    @Query("DELETE FROM playlists WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("DELETE FROM playlists")
    suspend fun clear()
}
