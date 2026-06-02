package com.mychannel.data.repository

import com.mychannel.data.local.dao.SearchHistoryDao
import com.mychannel.data.local.entity.SearchHistoryEntity
import com.mychannel.data.remote.FirestoreSearchDataSource
import com.mychannel.domain.model.Channel
import com.mychannel.domain.model.Video
import com.mychannel.domain.repository.SearchRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * [SearchRepository] combining remote Firestore search with locally-persisted
 * search history (Room, REQ-6.2).
 */
@Singleton
class SearchRepositoryImpl @Inject constructor(
    private val searchDataSource: FirestoreSearchDataSource,
    private val searchHistoryDao: SearchHistoryDao
) : SearchRepository {

    override suspend fun searchVideos(query: String): Result<List<Video>> = runCatching {
        searchDataSource.searchVideos(query)
    }

    override suspend fun searchChannels(query: String): Result<List<Channel>> = runCatching {
        searchDataSource.searchChannels(query)
    }

    override fun observeSearchHistory(): Flow<List<String>> =
        searchHistoryDao.observeRecent().map { entries -> entries.map { it.query } }

    override suspend fun addToHistory(query: String) {
        val trimmed = query.trim()
        if (trimmed.isEmpty()) return
        withContext(Dispatchers.IO) {
            searchHistoryDao.upsert(SearchHistoryEntity(query = trimmed))
        }
    }

    override suspend fun removeFromHistory(query: String) = withContext(Dispatchers.IO) {
        searchHistoryDao.delete(query)
    }

    override suspend fun clearHistory() = withContext(Dispatchers.IO) {
        searchHistoryDao.clear()
    }

    override suspend fun getTrendingSearches(): Result<List<String>> = runCatching {
        searchDataSource.getTrendingSearches()
    }
}
