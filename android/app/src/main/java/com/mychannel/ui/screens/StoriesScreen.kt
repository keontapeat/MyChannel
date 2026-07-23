package com.mychannel.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.mychannel.viewmodel.StoriesViewModel
import kotlinx.coroutines.delay

private const val STORY_DURATION_MS = 5_000L

/**
 * Stories screen — ephemeral 24h content from subscribed creators.
 * YouTube parity: tray of channel bubbles, full-screen viewer with progress bar,
 * tap-to-advance, swipe/tap-to-previous, auto-advance after 5s.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StoriesScreen(
    navController: NavController,
    viewModel: StoriesViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    if (uiState.activeGroupIndex != null) {
        // Full-screen story viewer
        StoryViewer(
            viewModel = viewModel,
            uiState = uiState
        )
        return
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Stories", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { innerPadding ->
        when {
            uiState.isLoading -> Box(
                Modifier.fillMaxSize().padding(innerPadding),
                contentAlignment = Alignment.Center
            ) { CircularProgressIndicator() }

            uiState.storyGroups.isEmpty() -> Box(
                Modifier.fillMaxSize().padding(innerPadding),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text("No stories yet", style = MaterialTheme.typography.titleMedium)
                    Text(
                        "Subscribe to creators to see their stories here",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            else -> Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
            ) {
                // Channel story bubbles row
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    itemsIndexed(uiState.storyGroups, key = { _, g -> g.channelId }) { index, group ->
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.clickable { viewModel.openStoryGroup(index) }
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(72.dp)
                                    .clip(CircleShape)
                                    .background(
                                        if (group.hasUnread)
                                            MaterialTheme.colorScheme.primary
                                        else
                                            MaterialTheme.colorScheme.surfaceVariant
                                    )
                                    .padding(3.dp)
                            ) {
                                AsyncImage(
                                    model = ImageRequest.Builder(LocalContext.current)
                                        .data(group.channelAvatarUrl)
                                        .crossfade(true)
                                        .build(),
                                    contentDescription = group.channelName,
                                    modifier = Modifier
                                        .fillMaxSize()
                                        .clip(CircleShape),
                                    contentScale = ContentScale.Crop
                                )
                            }
                            Spacer(Modifier.height(4.dp))
                            Text(
                                text = group.channelName,
                                style = MaterialTheme.typography.labelSmall,
                                maxLines = 1
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun StoryViewer(
    viewModel: StoriesViewModel,
    uiState: com.mychannel.viewmodel.StoriesUiState
) {
    val groupIdx = uiState.activeGroupIndex ?: return
    val group = uiState.storyGroups.getOrNull(groupIdx) ?: return
    val story = group.stories.getOrNull(uiState.activeStoryIndex) ?: return

    // Auto-advance after STORY_DURATION_MS
    LaunchedEffect(groupIdx, uiState.activeStoryIndex) {
        viewModel.markCurrentSeen()
        delay(STORY_DURATION_MS)
        viewModel.nextStory()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .pointerInput(groupIdx, uiState.activeStoryIndex) {
                detectTapGestures(
                    onTap = { offset ->
                        if (offset.x < size.width / 2f) viewModel.prevStory()
                        else viewModel.nextStory()
                    }
                )
            }
    ) {
        // Story media
        AsyncImage(
            model = ImageRequest.Builder(LocalContext.current)
                .data(story.mediaUrl)
                .crossfade(true)
                .build(),
            contentDescription = story.caption,
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Fit
        )

        // Progress bars
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 8.dp)
                .align(Alignment.TopCenter),
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            group.stories.forEachIndexed { i, _ ->
                LinearProgressIndicator(
                    progress = when {
                        i < uiState.activeStoryIndex -> 1f
                        i == uiState.activeStoryIndex -> 0.5f  // animated in a real impl
                        else -> 0f
                    },
                    modifier = Modifier
                        .weight(1f)
                        .height(2.dp)
                        .clip(RoundedCornerShape(1.dp)),
                    color = Color.White,
                    trackColor = Color.White.copy(alpha = 0.4f)
                )
            }
        }

        // Channel info + close button
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 48.dp)
                .align(Alignment.TopCenter),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(group.channelAvatarUrl)
                    .crossfade(true)
                    .build(),
                contentDescription = group.channelName,
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape),
                contentScale = ContentScale.Crop
            )
            Text(
                text = group.channelName,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                modifier = Modifier.weight(1f)
            )
            Spacer(Modifier.width(8.dp))
            IconButton(onClick = viewModel::closeStories) {
                Icon(Icons.Filled.Close, contentDescription = "Close", tint = Color.White)
            }
        }

        // Caption
        if (story.mediaUrl.isNotBlank()) {
            Text(
                text = story.creatorName,
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(horizontal = 16.dp, vertical = 48.dp)
                    .background(Color.Black.copy(alpha = 0.4f), RoundedCornerShape(8.dp))
                    .padding(horizontal = 12.dp, vertical = 8.dp)
            )
        }
    }
}
