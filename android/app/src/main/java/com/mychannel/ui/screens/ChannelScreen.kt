package com.mychannel.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.mychannel.domain.model.Channel
import com.mychannel.domain.model.Video
import com.mychannel.ui.components.VideoCard
import com.mychannel.viewmodel.ChannelViewModel

/**
 * Channel profile screen — banner, avatar, stats, subscribe button, and
 * the channel's video grid (REQ-9.1 – REQ-9.4).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChannelScreen(
    channelId: String,
    navController: NavController,
    viewModel: ChannelViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    LaunchedEffect(channelId) {
        viewModel.loadChannel(channelId)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(uiState.channel?.name ?: "") },
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
                Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                contentAlignment = Alignment.Center
            ) { CircularProgressIndicator() }

            uiState.channel != null -> ChannelContent(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                channel = uiState.channel!!,
                videos = uiState.videos,
                isSubscribed = uiState.isSubscribed,
                isSubscribing = uiState.isSubscribing,
                onSubscribeToggle = viewModel::toggleSubscription,
                onVideoClick = { video -> navController.navigate("video/${video.id}") }
            )
        }
    }
}

@Composable
private fun ChannelContent(
    modifier: Modifier,
    channel: Channel,
    videos: List<Video>,
    isSubscribed: Boolean,
    isSubscribing: Boolean,
    onSubscribeToggle: () -> Unit,
    onVideoClick: (Video) -> Unit
) {
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(bottom = 24.dp)
    ) {
        item(key = "header") {
            ChannelHeader(
                channel = channel,
                isSubscribed = isSubscribed,
                isSubscribing = isSubscribing,
                onSubscribeToggle = onSubscribeToggle
            )
        }

        if (channel.description.isNotBlank()) {
            item(key = "description") {
                Text(
                    text = channel.description,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                )
            }
        }

        item(key = "videos_header") {
            Text(
                text = "Videos",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
            )
        }

        items(videos, key = { it.id }) { video ->
            VideoCard(
                video = video,
                onClick = { onVideoClick(video) },
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
            )
        }
    }
}

@Composable
private fun ChannelHeader(
    channel: Channel,
    isSubscribed: Boolean,
    isSubscribing: Boolean,
    onSubscribeToggle: () -> Unit
) {
    Column {
        // Banner
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(160.dp)
                .background(MaterialTheme.colorScheme.primaryContainer)
        ) {
            if (channel.bannerUrl.isNotBlank()) {
                AsyncImage(
                    model = ImageRequest.Builder(LocalContext.current)
                        .data(channel.bannerUrl)
                        .crossfade(true)
                        .build(),
                    contentDescription = "Channel banner",
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )
            }
        }

        // Avatar overlapping banner
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 16.dp, end = 16.dp, top = 0.dp),
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(channel.avatarUrl)
                    .crossfade(true)
                    .build(),
                contentDescription = channel.name,
                modifier = Modifier
                    .size(80.dp)
                    .offset(y = (-24).dp)
                    .clip(CircleShape)
            )
            Spacer(Modifier.weight(1f))
            if (isSubscribing) {
                CircularProgressIndicator(modifier = Modifier.size(36.dp))
            } else if (isSubscribed) {
                OutlinedButton(onClick = onSubscribeToggle) { Text("Subscribed") }
            } else {
                Button(onClick = onSubscribeToggle) { Text("Subscribe") }
            }
        }

        // Name + handle + verified
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(
                text = channel.name,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
            if (channel.isVerified) {
                Icon(
                    Icons.Filled.Verified,
                    contentDescription = "Verified",
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp)
                )
            }
        }

        Text(
            text = "@${channel.handle}",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 16.dp)
        )

        // Stats row
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            StatItem(label = "Subscribers", value = formatCount(channel.subscriberCount))
            StatItem(label = "Videos", value = formatCount(channel.videoCount))
            StatItem(label = "Views", value = formatCount(channel.totalViewCount))
        }
    }
}

@Composable
private fun StatItem(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(text = value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        Text(text = label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

private fun formatCount(n: Long): String = when {
    n >= 1_000_000L -> "%.1fM".format(n / 1_000_000.0)
    n >= 1_000L -> "%.1fK".format(n / 1_000.0)
    else -> n.toString()
}
