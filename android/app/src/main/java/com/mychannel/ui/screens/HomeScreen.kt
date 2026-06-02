package com.mychannel.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.ExperimentalMaterialApi
import androidx.compose.material.pullrefresh.PullRefreshIndicator
import androidx.compose.material.pullrefresh.pullRefresh
import androidx.compose.material.pullrefresh.rememberPullRefreshState
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import androidx.paging.LoadState
import androidx.paging.compose.collectAsLazyPagingItems
import androidx.paging.compose.itemKey
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.mychannel.R
import com.mychannel.domain.model.LiveStream
import com.mychannel.ui.components.FilterChips
import com.mychannel.ui.components.LiveBadge
import com.mychannel.ui.components.StoriesRow
import com.mychannel.ui.components.StoriesRowSkeleton
import com.mychannel.ui.components.VideoCard
import com.mychannel.ui.components.VideoCardSkeleton
import com.mychannel.viewmodel.HomeViewModel

/**
 * Home screen (REQ-4.1 – REQ-4.6).
 *
 * A single [LazyColumn] composes the Stories row, filter chips, trending
 * section, Live Now section, and the paginated recommended feed. The first
 * load renders shimmer [VideoCardSkeleton]s; pull-to-refresh re-subscribes the
 * real-time sections and refreshes the Paging feed.
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalMaterialApi::class)
@Composable
fun HomeScreen(
    navController: NavController,
    viewModel: HomeViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val recommended = viewModel.recommendedFeed.collectAsLazyPagingItems()

    val isRefreshing = uiState.isLoading ||
        recommended.loadState.refresh is LoadState.Loading
    val pullRefreshState = rememberPullRefreshState(
        refreshing = isRefreshing,
        onRefresh = {
            viewModel.retry()
            recommended.refresh()
        }
    )

    Column(modifier = Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("MyChannel", fontWeight = FontWeight.Bold) },
            actions = {
                IconButton(onClick = { /* Search wired in Task 8 */ }) {
                    Icon(
                        painter = painterResource(R.drawable.ic_search),
                        contentDescription = "Search"
                    )
                }
                IconButton(onClick = { /* Profile/Notifications wired in later tasks */ }) {
                    Icon(
                        painter = painterResource(R.drawable.ic_profile),
                        contentDescription = "Profile"
                    )
                }
            }
        )

        Box(
            modifier = Modifier
                .fillMaxSize()
                .pullRefresh(pullRefreshState)
        ) {
            when {
                uiState.error != null && uiState.trendingVideos.isEmpty() -> {
                    HomeError(
                        message = uiState.error ?: "Unknown error",
                        onRetry = {
                            viewModel.retry()
                            recommended.refresh()
                        }
                    )
                }

                uiState.isLoading && uiState.trendingVideos.isEmpty() -> {
                    HomeSkeleton(
                        selectedFilter = uiState.selectedFilter,
                        onFilterSelected = viewModel::selectFilter
                    )
                }

                else -> {
                    HomeContent(
                        navController = navController,
                        uiState = uiState,
                        recommended = recommended,
                        onFilterSelected = viewModel::selectFilter
                    )
                }
            }

            PullRefreshIndicator(
                refreshing = isRefreshing,
                state = pullRefreshState,
                modifier = Modifier.align(Alignment.TopCenter)
            )
        }
    }
}

@Composable
private fun HomeContent(
    navController: NavController,
    uiState: com.mychannel.viewmodel.HomeUiState,
    recommended: androidx.paging.compose.LazyPagingItems<com.mychannel.domain.model.Video>,
    onFilterSelected: (String) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Stories row
        if (uiState.stories.isNotEmpty()) {
            item(key = "stories") {
                StoriesRow(
                    stories = uiState.stories,
                    onStoryClick = { story ->
                        if (story.isLive) navController.navigate("live/${story.channelId}")
                    },
                    modifier = Modifier.padding(top = 8.dp)
                )
            }
        }

        // Filter chips
        item(key = "filters") {
            FilterChips(
                selectedFilter = uiState.selectedFilter,
                onFilterSelected = onFilterSelected
            )
        }

        // Trending section
        if (uiState.trendingVideos.isNotEmpty()) {
            item(key = "trending_header") { SectionHeader("Trending Now") }
            items(
                items = uiState.trendingVideos,
                key = { "trending_${it.id}" }
            ) { video ->
                VideoCard(
                    video = video,
                    onClick = { navController.navigate("video/${video.id}") },
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }
        }

        // Live Now section
        if (uiState.liveStreams.isNotEmpty()) {
            item(key = "live_header") { SectionHeader("Live Now") }
            items(
                items = uiState.liveStreams,
                key = { "live_${it.id}" }
            ) { stream ->
                LiveStreamCard(
                    stream = stream,
                    onClick = { navController.navigate("live/${stream.id}") },
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }
        }

        // Recommended (paginated) section
        item(key = "recommended_header") { SectionHeader("Recommended for You") }
        items(
            count = recommended.itemCount,
            key = recommended.itemKey { "rec_${it.id}" }
        ) { index ->
            recommended[index]?.let { video ->
                VideoCard(
                    video = video,
                    onClick = { navController.navigate("video/${video.id}") },
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }
        }

        // Append loading indicator while the next page loads
        if (recommended.loadState.append is LoadState.Loading) {
            item(key = "append_loading") {
                VideoCardSkeleton(modifier = Modifier.padding(horizontal = 16.dp))
            }
        }
    }
}

@Composable
private fun HomeSkeleton(
    selectedFilter: String,
    onFilterSelected: (String) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item(key = "skeleton_stories") {
            StoriesRowSkeleton(modifier = Modifier.padding(start = 16.dp, top = 8.dp))
        }
        item(key = "skeleton_filters") {
            FilterChips(
                selectedFilter = selectedFilter,
                onFilterSelected = onFilterSelected
            )
        }
        items(count = 5, key = { "skeleton_card_$it" }) {
            VideoCardSkeleton(modifier = Modifier.padding(horizontal = 16.dp))
        }
    }
}

@Composable
private fun HomeError(
    message: String,
    onRetry: () -> Unit
) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = "Something went wrong",
                style = MaterialTheme.typography.headlineSmall
            )
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 8.dp)
            )
            Button(onClick = onRetry, modifier = Modifier.padding(top = 16.dp)) {
                Text("Retry")
            }
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleLarge,
        fontWeight = FontWeight.Bold,
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
    )
}

@Composable
private fun LiveStreamCard(
    stream: LiveStream,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surface)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 9f)
                .clip(RoundedCornerShape(12.dp))
        ) {
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(stream.thumbnailUrl)
                    .crossfade(true)
                    .build(),
                contentDescription = stream.title,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop
            )
            LiveBadge(
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(8.dp)
            )
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(8.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(MaterialTheme.colorScheme.scrim.copy(alpha = 0.6f))
                    .padding(horizontal = 6.dp, vertical = 2.dp)
            ) {
                Text(
                    text = "${formatWatching(stream.viewerCount)} watching",
                    style = MaterialTheme.typography.labelSmall,
                    color = androidx.compose.ui.graphics.Color.White
                )
            }
        }
        Column(modifier = Modifier.padding(top = 8.dp)) {
            Text(
                text = stream.title,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2
            )
            Text(
                text = stream.creatorName,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 2.dp)
            )
        }
    }
}

private fun formatWatching(count: Long): String = when {
    count >= 1_000_000L -> String.format("%.1fM", count / 1_000_000.0)
    count >= 1_000L -> String.format("%.1fK", count / 1_000.0)
    else -> count.toString()
}
