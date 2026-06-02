package com.mychannel.ui.screens.upload

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Analytics
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.MonetizationOn
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import coil.compose.AsyncImage
import com.mychannel.domain.model.Video
import com.mychannel.viewmodel.StudioUiState
import com.mychannel.viewmodel.StudioViewModel

/**
 * Creator Studio dashboard (REQ-8.4, REQ-8.5).
 *
 * Shows aggregate stat cards (views, subscribers, estimated watch time,
 * estimated revenue) and a list of the creator's uploaded videos with edit,
 * delete, and analytics actions per item.
 *
 * Revenue shown here is an estimate for display only — authoritative money
 * flows are Cloud-Function-only and never computed or written on the client.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StudioScreen(
    navController: NavController,
    viewModel: StudioViewModel = hiltViewModel()
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var videoToDelete by remember { mutableStateOf<Video?>(null) }
    var videoToEdit by remember { mutableStateOf<Video?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Creator Studio") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(
                            imageVector = Icons.Filled.ArrowBack,
                            contentDescription = "Go back"
                        )
                    }
                }
            )
        }
    ) { padding ->
        when {
            state.isLoading -> Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }

            state.error != null && state.videos.isEmpty() -> Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = state.error ?: "",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.error
                )
            }

            else -> StudioContent(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                state = state,
                onEdit = { videoToEdit = it },
                onDelete = { videoToDelete = it },
                onAnalytics = { /* Analytics screen is out of scope for this task. */ }
            )
        }
    }

    // Delete confirmation (REQ-8.5)
    videoToDelete?.let { video ->
        AlertDialog(
            onDismissRequest = { videoToDelete = null },
            title = { Text("Delete video?") },
            text = { Text("\"${video.title}\" will be permanently removed. This can't be undone.") },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.deleteVideo(video.id)
                    videoToDelete = null
                }) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { videoToDelete = null }) { Text("Cancel") }
            }
        )
    }

    // Edit metadata sheet (REQ-8.5)
    videoToEdit?.let { video ->
        EditVideoDialog(
            video = video,
            onDismiss = { videoToEdit = null },
            onSave = { title, description, privacy ->
                viewModel.updateVideoDetails(video.id, title, description, privacy)
                videoToEdit = null
            }
        )
    }
}

@Composable
private fun StudioContent(
    modifier: Modifier,
    state: StudioUiState,
    onEdit: (Video) -> Unit,
    onDelete: (Video) -> Unit,
    onAnalytics: (Video) -> Unit
) {
    LazyColumn(
        modifier = modifier,
        contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item(key = "stats") {
            StatsGrid(state = state)
        }

        item(key = "videos_header") {
            Text(
                text = "Your videos",
                style = MaterialTheme.typography.titleMedium
            )
        }

        if (state.videos.isEmpty()) {
            item(key = "empty") {
                Text(
                    text = "You haven't uploaded any videos yet.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            items(items = state.videos, key = { it.id }) { video ->
                StudioVideoRow(
                    video = video,
                    onEdit = { onEdit(video) },
                    onDelete = { onDelete(video) },
                    onAnalytics = { onAnalytics(video) }
                )
            }
        }
    }
}

@Composable
private fun StatsGrid(state: StudioUiState) {
    // Two rows of two stat cards.
    LazyVerticalGrid(
        columns = GridCells.Fixed(2),
        modifier = Modifier
            .fillMaxWidth()
            .height(220.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        userScrollEnabled = false
    ) {
        item {
            StatCard(
                label = "Total views",
                value = formatCount(state.totalViews),
                icon = Icons.Filled.Visibility
            )
        }
        item {
            StatCard(
                label = "Subscribers",
                value = formatCount(state.subscriberCount),
                icon = Icons.Filled.Group
            )
        }
        item {
            StatCard(
                label = "Watch time (hrs)",
                value = formatCount(state.estimatedWatchTimeHours),
                icon = Icons.Filled.Schedule
            )
        }
        item {
            StatCard(
                label = "Est. revenue",
                value = formatCents(state.estimatedRevenueCents),
                icon = Icons.Filled.MonetizationOn
            )
        }
    }
}

@Composable
private fun StatCard(label: String, value: String, icon: androidx.compose.ui.graphics.vector.ImageVector) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary
            )
            Text(
                text = value,
                style = MaterialTheme.typography.headlineSmall
            )
            Text(
                text = label,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun StudioVideoRow(
    video: Video,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    onAnalytics: () -> Unit
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Box(
                modifier = Modifier
                    .width(120.dp)
                    .aspectRatio(16f / 9f)
                    .clip(RoundedCornerShape(8.dp))
            ) {
                AsyncImage(
                    model = video.thumbnailUrl,
                    contentDescription = "Thumbnail for ${video.title}",
                    modifier = Modifier.fillMaxSize()
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = video.title.ifBlank { "Untitled" },
                    style = MaterialTheme.typography.titleSmall,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = "${formatCount(video.viewCount)} views",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = video.privacyStatus.replaceFirstChar { it.uppercase() },
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Column {
                IconButton(onClick = onEdit) {
                    Icon(imageVector = Icons.Filled.Edit, contentDescription = "Edit video")
                }
                IconButton(onClick = onAnalytics) {
                    Icon(imageVector = Icons.Filled.Analytics, contentDescription = "View analytics")
                }
                IconButton(onClick = onDelete) {
                    Icon(
                        imageVector = Icons.Filled.Delete,
                        contentDescription = "Delete video",
                        tint = MaterialTheme.colorScheme.error
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EditVideoDialog(
    video: Video,
    onDismiss: () -> Unit,
    onSave: (title: String, description: String, privacy: String) -> Unit
) {
    var title by remember { mutableStateOf(video.title) }
    var description by remember { mutableStateOf(video.description) }
    var privacy by remember { mutableStateOf(video.privacyStatus) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Edit video") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("Title") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = description,
                    onValueChange = { description = it },
                    label = { Text("Description") },
                    minLines = 2,
                    modifier = Modifier.fillMaxWidth()
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("public", "unlisted", "private").forEach { option ->
                        androidx.compose.material3.FilterChip(
                            selected = privacy == option,
                            onClick = { privacy = option },
                            label = { Text(option.replaceFirstChar { it.uppercase() }) }
                        )
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { onSave(title, description, privacy) }) { Text("Save") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}

/** Formats a count with K/M suffixes for compact display. */
private fun formatCount(count: Long): String = when {
    count >= 1_000_000 -> "%.1fM".format(count / 1_000_000.0)
    count >= 1_000 -> "%.1fK".format(count / 1_000.0)
    else -> count.toString()
}

/** Formats integer cents as a USD string (display-only estimate). */
private fun formatCents(cents: Long): String = "$%,.2f".format(cents / 100.0)
