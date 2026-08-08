package com.mychannel.ui.screens

import android.content.ComponentName
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import androidx.navigation.NavController
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.mychannel.domain.model.MusicTrack
import com.mychannel.services.MediaPlaybackService
import com.mychannel.viewmodel.MusicUiState
import com.mychannel.viewmodel.MusicViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MusicScreen(
    navController: NavController,
    viewModel: MusicViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val appContext = LocalContext.current.applicationContext
    var controller by remember { mutableStateOf<MediaController?>(null) }
    var playingTrackId by remember { mutableStateOf<String?>(null) }
    val controllerFuture = remember(appContext) {
        val token = SessionToken(
            appContext,
            ComponentName(appContext, MediaPlaybackService::class.java)
        )
        MediaController.Builder(appContext, token).buildAsync()
    }

    DisposableEffect(controllerFuture) {
        controllerFuture.addListener(
            { controller = runCatching { controllerFuture.get() }.getOrNull() },
            ContextCompat.getMainExecutor(appContext)
        )
        onDispose {
            controller = null
            MediaController.releaseFuture(controllerFuture)
        }
    }

    DisposableEffect(controller) {
        val mediaController = controller
        if (mediaController == null) {
            onDispose { }
        } else {
            val listener = object : Player.Listener {
                override fun onIsPlayingChanged(isPlaying: Boolean) {
                    playingTrackId = mediaController.currentMediaItem
                        ?.mediaId
                        ?.takeIf { isPlaying }
                }

                override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
                    playingTrackId = mediaItem?.mediaId?.takeIf { mediaController.isPlaying }
                }

                override fun onPlaybackStateChanged(playbackState: Int) {
                    if (playbackState == Player.STATE_ENDED || playbackState == Player.STATE_IDLE) {
                        playingTrackId = null
                    }
                }
            }
            mediaController.addListener(listener)
            playingTrackId = mediaController.currentMediaItem
                ?.mediaId
                ?.takeIf { mediaController.isPlaying }
            onDispose {
                mediaController.removeListener(listener)
                playingTrackId = null
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Music Hub", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { innerPadding ->
        MusicContent(
            state = uiState,
            playerReady = controller != null,
            playingTrackId = playingTrackId,
            onRetry = viewModel::loadTracks,
            onPlay = { track ->
                controller?.let { mediaController ->
                    mediaController.setMediaItem(track.toMediaItem())
                    mediaController.prepare()
                    mediaController.play()
                }
            },
            modifier = Modifier.padding(innerPadding)
        )
    }
}

@Composable
private fun MusicContent(
    state: MusicUiState,
    playerReady: Boolean,
    playingTrackId: String?,
    onRetry: () -> Unit,
    onPlay: (MusicTrack) -> Unit,
    modifier: Modifier = Modifier
) {
    when {
        state.isLoading -> CenteredMessage(modifier) { CircularProgressIndicator() }
        state.errorMessage != null -> CenteredMessage(modifier) {
            Text(
                text = state.errorMessage,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodyLarge
            )
            Button(onClick = onRetry) { Text("Retry") }
        }
        state.tracks.isEmpty() -> CenteredMessage(modifier) {
            Icon(
                Icons.Filled.MusicNote,
                contentDescription = null,
                modifier = Modifier.size(48.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text("No published tracks yet", style = MaterialTheme.typography.titleMedium)
            Text(
                "Check back soon for new music.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        else -> LazyColumn(
            modifier = modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item(key = "music_heading") {
                Text(
                    text = "Published tracks",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
            }
            items(state.tracks, key = { it.id }) { track ->
                MusicTrackRow(
                    track = track,
                    playerReady = playerReady,
                    isPlaying = playingTrackId == track.id,
                    onPlay = { onPlay(track) }
                )
            }
        }
    }
}
@Composable
private fun CenteredMessage(
    modifier: Modifier,
    content: @Composable () -> Unit
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        content()
    }
}

@Composable
private fun MusicTrackRow(
    track: MusicTrack,
    playerReady: Boolean,
    isPlaying: Boolean,
    onPlay: () -> Unit
) {
    val playable = track.audioUrl.isSecureUrl()
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            TrackArtwork(track)
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = track.title.ifBlank { "Untitled track" },
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = track.artistName.ifBlank { "Unknown artist" },
                    style = MaterialTheme.typography.bodyMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = track.secondaryLabel(),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            TextButton(
                modifier = Modifier.semantics {
                    contentDescription = when {
                        !playable -> "${track.title} is unavailable for playback"
                        !playerReady -> "Player is connecting for ${track.title}"
                        isPlaying -> "Now playing ${track.title} by ${track.artistName}"
                        else -> "Play ${track.title} by ${track.artistName}"
                    }
                },
                enabled = playable && playerReady,
                onClick = onPlay
            ) {
                Icon(Icons.Filled.PlayArrow, contentDescription = null)
                Text(
                    when {
                        !playable -> "Unavailable"
                        !playerReady -> "Connecting"
                        isPlaying -> "Playing"
                        else -> "Play"
                    }
                )
            }
        }
    }
}

@Composable
private fun TrackArtwork(track: MusicTrack) {
    if (track.artworkUrl.isSecureUrl()) {
        AsyncImage(
            model = ImageRequest.Builder(LocalContext.current)
                .data(track.artworkUrl)
                .crossfade(true)
                .build(),
            contentDescription = "Cover art for ${track.title.ifBlank { "track" }}",
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .size(72.dp)
                .clip(RoundedCornerShape(8.dp))
        )
    } else {
        Box(
            modifier = Modifier
                .size(72.dp)
                .clip(RoundedCornerShape(8.dp)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Filled.MusicNote,
                contentDescription = "No cover art",
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

private fun MusicTrack.toMediaItem(): MediaItem {
    val artworkUri = artworkUrl.takeIf { it.isSecureUrl() }?.let(Uri::parse)
    return MediaItem.Builder()
        .setMediaId(id)
        .setUri(audioUrl)
        .setMediaMetadata(
            MediaMetadata.Builder()
                .setTitle(title.ifBlank { "Untitled track" })
                .setArtist(artistName.ifBlank { "Unknown artist" })
                .setAlbumTitle(albumName.takeIf { it.isNotBlank() })
                .setArtworkUri(artworkUri)
                .build()
        )
        .build()
}

private fun MusicTrack.secondaryLabel(): String = buildList {
    albumName.takeIf { it.isNotBlank() }?.let(::add)
    genre.takeIf { it.isNotBlank() }?.let(::add)
    if (isExplicit) add("Explicit")
    if (durationSeconds > 0L) add(formatDuration(durationSeconds))
}.joinToString(" • ").ifBlank { "Music track" }

private fun String.isSecureUrl(): Boolean = runCatching {
    Uri.parse(this).let { it.scheme.equals("https", ignoreCase = true) && !it.host.isNullOrBlank() }
}.getOrDefault(false)

private fun formatDuration(seconds: Long): String =
    "%d:%02d".format(seconds / 60L, seconds % 60L)
