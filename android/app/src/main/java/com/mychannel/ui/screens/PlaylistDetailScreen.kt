package com.mychannel.ui.screens

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Shuffle
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.mychannel.domain.model.Video
import com.mychannel.ui.components.VideoCard
import com.mychannel.viewmodel.PlaylistDetailViewModel

/**
 * Playlist Detail — YouTube parity.
 * Shows playlist header (thumbnail, title, owner, count), Play All / Shuffle,
 * and the ordered list of videos with index numbers.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlaylistDetailScreen(
    playlistId: String,
    navController: NavController,
    viewModel: PlaylistDetailViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var menuExpanded by remember { mutableStateOf(false) }

    LaunchedEffect(playlistId) {
        viewModel.load(playlistId)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(uiState.playlist?.title ?: "Playlist", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { /* share */ }) {
                        Icon(Icons.Filled.Share, contentDescription = "Share")
                    }
                    Box {
                        IconButton(onClick = { menuExpanded = true }) {
                            Icon(Icons.Filled.MoreVert, contentDescription = "More")
                        }
                        DropdownMenu(expanded = menuExpanded, onDismissRequest = { menuExpanded = false }) {
                            DropdownMenuItem(
                                text = { Text("Edit playlist") },
                                onClick = { menuExpanded = false; viewModel.startEdit() }
                            )
                            DropdownMenuItem(
                                text = { Text("Delete playlist", color = MaterialTheme.colorScheme.error) },
                                onClick = {
                                    menuExpanded = false
                                    viewModel.delete { navController.popBackStack() }
                                }
                            )
                        }
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

            uiState.playlist == null -> Box(
                Modifier.fillMaxSize().padding(innerPadding),
                contentAlignment = Alignment.Center
            ) { Text("Playlist not found") }

            else -> LazyColumn(
                modifier = Modifier.fillMaxSize().padding(innerPadding),
                contentPadding = PaddingValues(bottom = 24.dp)
            ) {
                // Header
                item(key = "header") {
                    PlaylistHeader(
                        thumbnailUrl = uiState.playlist!!.thumbnailUrl,
                        title = uiState.playlist!!.title,
                        description = uiState.playlist!!.description,
                        videoCount = uiState.videos.size,
                        isPrivate = uiState.playlist!!.privacyStatus == "private",
                        onPlayAll = {
                            uiState.videos.firstOrNull()?.let {
                                navController.navigate("video/${it.id}")
                            }
                        },
                        onShuffle = {
                            uiState.videos.shuffled().firstOrNull()?.let {
                                navController.navigate("video/${it.id}")
                            }
                        }
                    )
                }

                // Videos
                itemsIndexed(uiState.videos, key = { _, v -> "pl_${v.id}" }) { index, video ->
                    PlaylistVideoRow(
                        index = index + 1,
                        video = video,
                        onClick = { navController.navigate("video/${video.id}") }
                    )
                }

                if (uiState.videos.isEmpty()) {
                    item(key = "empty") {
                        Box(
                            Modifier.fillMaxWidth().padding(32.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                "This playlist is empty",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PlaylistHeader(
    thumbnailUrl: String,
    title: String,
    description: String,
    videoCount: Int,
    isPrivate: Boolean,
    onPlayAll: () -> Unit,
    onShuffle: () -> Unit
) {
    Column(modifier = Modifier.padding(16.dp)) {
        // Thumbnail
        if (thumbnailUrl.isNotBlank()) {
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(thumbnailUrl)
                    .crossfade(true)
                    .build(),
                contentDescription = title,
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(16f / 9f)
                    .clip(RoundedCornerShape(12.dp)),
                contentScale = ContentScale.Crop
            )
            Spacer(Modifier.height(12.dp))
        }

        // Meta
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                title,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f)
            )
            if (isPrivate) {
                Icon(
                    Icons.Filled.Lock,
                    contentDescription = "Private",
                    modifier = Modifier.size(16.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        Text(
            "$videoCount video${if (videoCount != 1) "s" else ""}",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        if (description.isNotBlank()) {
            Spacer(Modifier.height(4.dp))
            Text(
                description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis
            )
        }

        Spacer(Modifier.height(12.dp))

        // Play / Shuffle row
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = onPlayAll, modifier = Modifier.weight(1f)) {
                Icon(Icons.Filled.PlayArrow, contentDescription = null, modifier = Modifier.size(18.dp))
                Text("Play all")
            }
            OutlinedButton(onClick = onShuffle, modifier = Modifier.weight(1f)) {
                Icon(Icons.Filled.Shuffle, contentDescription = null, modifier = Modifier.size(18.dp))
                Text("Shuffle")
            }
        }
    }
}

@Composable
private fun PlaylistVideoRow(
    index: Int,
    video: Video,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "$index",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(20.dp),
        )
        VideoCard(
            video = video,
            onClick = onClick,
            modifier = Modifier.weight(1f)
        )
    }
}
