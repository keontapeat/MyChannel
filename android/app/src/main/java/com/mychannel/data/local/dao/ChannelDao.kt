package com.mychannel.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.mychannel.data.local.entity.ChannelEntity
import kotlinx.coroutines.flow.Flow

/**
 * DAO for cached channels (offline-first per REQ-1.4).
 */
@Dao
interface ChannelDao {

    @Query("SELECT * FROM channels ORDER BY subscriberCount DESC")
    fun observeAll(): Flow<List<ChannelEntity>>

    @Query("SELECT * FROM channels WHERE id = :id LIMIT 1")
    fun observeById(id: String): Flow<ChannelEntity?>

    @Query("SELECT * FROM channels WHERE id = :id LIMIT 1")
    suspend fun getById(id: String): ChannelEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(channel: ChannelEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(channels: List<ChannelEntity>)

    @Query("DELETE FROM channels WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("DELETE FROM channels")
    suspend fun clear()
}
