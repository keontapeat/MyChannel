package com.mychannel.data.remote

import androidx.paging.PagingSource
import androidx.paging.PagingState
import com.google.firebase.firestore.Query
import com.google.firebase.firestore.QuerySnapshot
import com.mychannel.domain.model.Video
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

/**
 * Paging 3 [PagingSource] for the Home recommended feed (REQ-4.5).
 *
 * Cursor-based pagination over a Firestore [Query]: each page keeps the last
 * [QuerySnapshot] so the next page can `startAfter` the final document. All
 * reads run on [Dispatchers.IO] consistent with Task 2's one-shot read pattern.
 */
class FirestoreVideoPagingSource(
    private val baseQuery: Query,
    private val pageSize: Long = DEFAULT_PAGE_SIZE
) : PagingSource<QuerySnapshot, Video>() {

    override suspend fun load(
        params: LoadParams<QuerySnapshot>
    ): LoadResult<QuerySnapshot, Video> = withContext(Dispatchers.IO) {
        try {
            val currentPage = params.key
                ?: baseQuery.limit(pageSize).get().await()

            val videos = currentPage.documents.mapNotNull { doc ->
                doc.toObject(Video::class.java)?.copy(id = doc.id)
            }

            val lastVisible = currentPage.documents.lastOrNull()
            // Only fetch a follow-on page when the current page was full and a
            // cursor exists; an empty follow-on page terminates pagination.
            val nextPage = if (lastVisible != null && currentPage.size().toLong() >= pageSize) {
                baseQuery.startAfter(lastVisible).limit(pageSize).get().await()
            } else {
                null
            }

            LoadResult.Page(
                data = videos,
                prevKey = null, // forward-only paging
                nextKey = if (nextPage == null || nextPage.isEmpty) null else nextPage
            )
        } catch (e: Exception) {
            LoadResult.Error(e)
        }
    }

    override fun getRefreshKey(state: PagingState<QuerySnapshot, Video>): QuerySnapshot? = null

    private companion object {
        const val DEFAULT_PAGE_SIZE = 20L
    }
}
