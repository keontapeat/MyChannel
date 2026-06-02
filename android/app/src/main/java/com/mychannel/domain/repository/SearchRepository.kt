package com.mychannel.domain.repository

import com.mychannel.domain.model.Channel
import com.mychannel.domain.model.Video
import kotlinx.coroutines.flow.Flow

/**
 * Repository for search (REQ-6.x). Combines remote Firestore queries with
 * locally-persisted search history (Room).
 */
interface SearchRepository {

    suspend fun searchVideos(query: String): Result<List<Video>>

    suspend fun searchChannels(query: String): Result<List<Channel>>

    /** Real-time local search history (most-recent first). */
    fun observeSearchHistory(): Flow<List<String>>

    suspend fun addToHistory(query: String)

    suspend fun removeFromHistory(query: String)

    suspend fun clearHistory()

    /** Trending search terms fetched from Firestore. */
    suspend fun getTrendingSearches(): Result<List<String>>
}
