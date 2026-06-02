package com.mychannel.data.repository

import androidx.paging.Pager
import androidx.paging.PagingConfig
import androidx.paging.PagingData
import com.mychannel.data.local.dao.VideoDao
import com.mychannel.data.local.entity.toEntity
import com.mychannel.data.remote.FirestoreLiveStreamDataSource
import com.mychannel.data.remote.FirestoreStoryDataSource
import com.mychannel.data.remote.FirestoreVideoDataSource
import com.mychannel.data.remote.FirestoreVideoPagingSource
import com.mychannel.domain.model.Comment
import com.mychannel.domain.model.LiveStream
import com.mychannel.domain.model.Story
import com.mychannel.domain.model.Video
import com.mychannel.domain.repository.VideoRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.flowOn
import javax.inject.Inject
import javax.inject.Singleton

/**
 * [VideoRepository] backed by [FirestoreVideoDataSource] with Room caching.
 *
 * Real-time feeds are streamed from Firestore and written through to the
 * [VideoDao] cache for offline browsing (REQ-1.4). The recommended feed uses
 * Paging 3 with a Firestore cursor [FirestoreVideoPagingSource] (REQ-4.5).
 */
@Singleton
class VideoRepositoryImpl @Inject constructor(
    private val videoDataSource: FirestoreVideoDataSource,
    private val liveStreamDataSource: FirestoreLiveStreamDataSource,
    private val storyDataSource: FirestoreStoryDataSource,
    private val videoDao: VideoDao
) : VideoRepository {

    override fun observeTrending(): Flow<List<Video>> =
        videoDataSource.observeTrending()
            .onEach { videos -> videoDao.upsertAll(videos.map { it.toEntity() }) }
            .flowOn(Dispatchers.IO)

    override fun recommendedFeed(category: String?): Flow<PagingData<Video>> =
        Pager(
            config = PagingConfig(
                pageSize = PAGE_SIZE,
                prefetchDistance = PREFETCH_DISTANCE,
                enablePlaceholders = false,
                initialLoadSize = PAGE_SIZE
            ),
            pagingSourceFactory = {
                val query = if (category.isNullOrBlank()) {
                    videoDataSource.recommendedQuery()
                } else {
                    videoDataSource.recommendedQueryForCategory(category)
                }
                FirestoreVideoPagingSource(query, PAGE_SIZE.toLong())
            }
        ).flow

    override fun observeLiveStreams(): Flow<List<LiveStream>> =
        liveStreamDataSource.observeLiveNow()
            .flowOn(Dispatchers.IO)

    override fun observeStories(): Flow<List<Story>> =
        storyDataSource.observeActiveStories()
            .flowOn(Dispatchers.IO)

    override fun observeChannelVideos(channelId: String): Flow<List<Video>> =
        videoDataSource.observeChannelVideos(channelId)
            .onEach { videos -> videoDao.upsertAll(videos.map { it.toEntity() }) }
            .flowOn(Dispatchers.IO)

    override fun observeShorts(): Flow<List<Video>> =
        videoDataSource.observeShorts()
            .onEach { videos -> videoDao.upsertAll(videos.map { it.toEntity() }) }
            .flowOn(Dispatchers.IO)

    override suspend fun getVideo(videoId: String): Result<Video> = runCatching {
        videoDataSource.getVideo(videoId).also { videoDao.upsert(it.toEntity()) }
    }

    override fun observeComments(videoId: String): Flow<List<Comment>> =
        videoDataSource.observeComments(videoId)

    override suspend fun postComment(
        videoId: String,
        text: String,
        parentId: String?
    ): Result<Comment> = runCatching {
        videoDataSource.postComment(videoId, text, parentId)
    }

    override suspend fun toggleLike(videoId: String, like: Boolean): Result<Unit> = runCatching {
        videoDataSource.adjustLikeCount(videoId, like)
    }

    override suspend fun incrementViewCount(videoId: String): Result<Unit> = runCatching {
        videoDataSource.incrementViewCount(videoId)
    }

    private companion object {
        const val PAGE_SIZE = 20
        const val PREFETCH_DISTANCE = 5
    }
}
