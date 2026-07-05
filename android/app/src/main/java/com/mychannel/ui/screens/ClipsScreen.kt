package com.mychannel.ui.screens

import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.widget.FrameLayout
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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ContentCut
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
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
import com.mychannel.viewmodel.ClipsViewModel
import kotlinx.coroutines.launch

/**
 * Clips — user-generated highlight clips from live streams and videos.
 * YouTube-parity feature: viewers clip short moments from longer content.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ClipsScreen(
    navController: NavController,
    videoId: String? = null,
    viewModel: ClipsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var showCreateSheet by remember { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Clips") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { showCreateSheet = true }) {
                        Icon(Icons.Filled.ContentCut, contentDescription = "Create clip")
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

            uiState.clips.isEmpty() -> Box(
                Modifier.fillMaxSize().padding(innerPadding),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(
                        Icons.Filled.ContentCut,
                        contentDescription = null,
                        modifier = Modifier.size(48.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        "No clips yet",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        "Clip your favourite moments from any video",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            else -> LazyVerticalGrid(
                columns = GridCells.Fixed(2),
                modifier = Modifier.fillMaxSize().padding(innerPadding),
                contentPadding = PaddingValues(8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(uiState.clips, key = { it.id }) { clip ->
                    ClipCard(
                        thumbnailUrl = clip.thumbnailUrl,
                        title = clip.title,
                        duration = clip.durationSeconds,
                        viewCount = clip.viewCount,
                        onPlay = { navController.navigate("video/${clip.sourceVideoId}") },
                        onShare = { /* share intent */ }
                    )
                }
            }
        }
    }

    if (showCreateSheet) {
        ModalBottomSheet(
            onDismissRequest = { showCreateSheet = false },
            sheetState = sheetState
        ) {
            CreateClipSheet(
                videoId = videoId ?: "",
                videoDurationSeconds = uiState.clips.firstOrNull()?.let { 300 } ?: 300,
                onDismiss = { scope.launch { sheetState.hide() }.invokeOnCompletion { showCreateSheet = false } },
                onSave = { title, startSec, endSec ->
                    viewModel.createClip(videoId ?: "", title, startSec, endSec)
                    scope.launch { sheetState.hide() }.invokeOnCompletion { showCreateSheet = false }
                }
            )
        }
    }
}

@Composable
private fun ClipCard(
    thumbnailUrl: String,
    title: String,
    duration: Int,
    viewCount: Long,
    onPlay: () -> Unit,
    onShare: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(16f / 9f)
            .clip(RoundedCornerShape(8.dp))
            .background(Color.Black)
    ) {
        AsyncImage(
            model = ImageRequest.Builder(LocalContext.current)
                .data(thumbnailUrl).crossfade(true).build(),
            contentDescription = title,
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop
        )

        // Duration badge
        Box(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(4.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(Color.Black.copy(alpha = 0.7f))
                .padding(horizontal = 4.dp, vertical = 2.dp)
        ) {
            Text(
                text = formatDuration(duration),
                style = MaterialTheme.typography.labelSmall,
                color = Color.White
            )
        }

        // Play button overlay
        IconButton(
            onClick = onPlay,
            modifier = Modifier.align(Alignment.Center)
        ) {
            Icon(
                Icons.Filled.PlayArrow,
                contentDescription = "Play",
                tint = Color.White,
                modifier = Modifier.size(36.dp)
            )
        }

        // Share button
        IconButton(
            onClick = onShare,
            modifier = Modifier.align(Alignment.TopEnd)
        ) {
            Icon(
                Icons.Filled.Share,
                contentDescription = "Share",
                tint = Color.White,
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

private fun formatDuration(secs: Int): String {
    val m = secs / 60
    val s = secs % 60
    return "%d:%02d".format(m, s)
}

// ── Create Clip Bottom Sheet ────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CreateClipSheet(
    videoId: String,
    videoDurationSeconds: Int,
    onDismiss: () -> Unit,
    onSave: (title: String, startSec: Int, endSec: Int) -> Unit
) {
    val maxClipSeconds = 60
    val totalDur = videoDurationSeconds.coerceAtLeast(maxClipSeconds)

    var title by remember { mutableStateOf("") }
    var startPct by remember { mutableFloatStateOf(0f) }
    var endPct by remember { mutableFloatStateOf(
        (maxClipSeconds.toFloat() / totalDur.toFloat()).coerceIn(0.01f, 1f)
    ) }

    val startSec = (startPct * totalDur).toInt()
    val endSec = (endPct * totalDur).toInt().coerceAtMost(startSec + maxClipSeconds)
    val clipDuration = endSec - startSec

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = 24.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            "Create Clip",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold
        )
        Text(
            "Select up to 60 seconds from this video",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        OutlinedTextField(
            value = title,
            onValueChange = { if (it.length <= 60) title = it },
            label = { Text("Clip title") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            supportingText = { Text("${title.length}/60") }
        )

        // Start position
        Column {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text("Start: ${formatDuration(startSec)}", style = MaterialTheme.typography.bodyMedium)
                Text("End: ${formatDuration(endSec)}", style = MaterialTheme.typography.bodyMedium)
            }
            Slider(
                value = startPct,
                onValueChange = { new ->
                    startPct = new.coerceIn(0f, (endPct - maxClipSeconds.toFloat() / totalDur).coerceAtLeast(0f))
                },
                valueRange = 0f..1f,
                modifier = Modifier.fillMaxWidth()
            )
            Slider(
                value = endPct,
                onValueChange = { new ->
                    endPct = new.coerceIn(
                        (startPct + 1f / totalDur).coerceAtMost(1f),
                        (startPct + maxClipSeconds.toFloat() / totalDur).coerceAtMost(1f)
                    )
                },
                valueRange = 0f..1f,
                modifier = Modifier.fillMaxWidth()
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            androidx.compose.material3.OutlinedButton(
                onClick = onDismiss,
                modifier = Modifier.weight(1f)
            ) { Text("Cancel") }
            Button(
                onClick = { if (title.isNotBlank() && clipDuration > 0) onSave(title, startSec, endSec) },
                modifier = Modifier.weight(1f),
                enabled = title.isNotBlank() && clipDuration > 0
            ) { Text("Create clip (${formatDuration(clipDuration)})") }
        }
        Spacer(Modifier.height(8.dp))
    }
}
