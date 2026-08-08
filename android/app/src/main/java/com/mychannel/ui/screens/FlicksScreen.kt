package com.mychannel.ui.screens

import android.content.Intent
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.widget.FrameLayout
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.pager.VerticalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.Comment
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import android.widget.Toast
import androidx.navigation.NavController
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.mychannel.domain.model.ContentReportReason
import com.mychannel.domain.model.Video
import com.mychannel.viewmodel.FlicksViewModel

/** Premium, edge-to-edge short-form video feed. */
@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
fun FlicksScreen(
    navController: NavController,
    viewModel: FlicksViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    var selectedFeed by rememberSaveable { mutableStateOf("Flicks") }
    var optionsFlick by remember { mutableStateOf<Video?>(null) }
    var reportingFlick by remember { mutableStateOf<Video?>(null) }

    // Surface moderation feedback (report/block) as a toast, then clear it.
    LaunchedEffect(uiState.moderationMessage) {
        uiState.moderationMessage?.let { message ->
            Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
            viewModel.clearModerationMessage()
        }
    }

    optionsFlick?.let { flick ->
        FlickOptionsSheet(
            onDismiss = { optionsFlick = null },
            onReport = {
                optionsFlick = null
                reportingFlick = flick
            },
            onBlock = {
                optionsFlick = null
                viewModel.blockFlickCreator(flick)
            }
        )
    }

    reportingFlick?.let { flick ->
        FlickReportReasonSheet(
            onDismiss = { reportingFlick = null },
            onSelectReason = { reason ->
                reportingFlick = null
                viewModel.reportFlick(flick, reason)
            }
        )
    }

    val exoPlayer = remember {
        ExoPlayer.Builder(context).build().apply { playWhenReady = true }
    }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_PAUSE -> exoPlayer.pause()
                Lifecycle.Event.ON_RESUME -> exoPlayer.play()
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            exoPlayer.release()
        }
    }

    when {
        uiState.isLoading -> Box(
            Modifier.fillMaxSize().background(Color.Black),
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator(color = Color.White)
        }

        uiState.shorts.isEmpty() -> Box(
            Modifier.fillMaxSize().background(Color.Black),
            contentAlignment = Alignment.Center
        ) {
            Text("No Flicks yet", color = Color.White, style = MaterialTheme.typography.bodyLarge)
        }

        else -> {
            val pagerState = rememberPagerState(pageCount = { uiState.shorts.size })

            LaunchedEffect(pagerState) {
                snapshotFlow { pagerState.currentPage }.collect { page ->
                    val video = uiState.shorts.getOrNull(page) ?: return@collect
                    exoPlayer.setMediaItem(MediaItem.fromUri(video.videoUrl))
                    exoPlayer.prepare()
                    exoPlayer.play()
                }
            }

            Box(Modifier.fillMaxSize().background(Color.Black)) {
                VerticalPager(state = pagerState, modifier = Modifier.fillMaxSize()) { page ->
                    val video = uiState.shorts[page]
                    FlickItem(
                        video = video,
                        exoPlayer = exoPlayer,
                        onLike = { viewModel.toggleLike(video.id) },
                        onChannelClick = { navController.navigate("channel/${video.channelId}") },
                        onComment = { },
                        onMore = { optionsFlick = video },
                        onShare = {
                            val share = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, "https://mychannel.live/flicks")
                                putExtra(Intent.EXTRA_TITLE, video.title)
                            }
                            context.startActivity(Intent.createChooser(share, "Share Flick"))
                        }
                    )
                }

                FlicksTopChrome(
                    videos = uiState.shorts,
                    selectedFeed = selectedFeed,
                    onFeedSelected = { selectedFeed = it },
                    modifier = Modifier.align(Alignment.TopCenter)
                )
            }
        }
    }
}

@Composable
private fun FlicksTopChrome(
    videos: List<Video>,
    selectedFeed: String,
    onFeedSelected: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .statusBarsPadding()
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        listOf("Flicks", "Following").forEach { feed ->
            Column(
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .clickable { onFeedSelected(feed) }
                    .padding(horizontal = 2.dp, vertical = 6.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = feed,
                    color = if (selectedFeed == feed) Color.White else Color.White.copy(alpha = 0.6f),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = if (selectedFeed == feed) FontWeight.Bold else FontWeight.SemiBold
                )
                Spacer(Modifier.height(4.dp))
                Box(
                    Modifier
                        .size(width = if (selectedFeed == feed) 22.dp else 0.dp, height = 2.dp)
                        .clip(CircleShape)
                        .background(Color.White)
                )
            }
        }

        Row(horizontalArrangement = Arrangement.spacedBy((-8).dp)) {
            videos.distinctBy { it.channelId }.take(3).forEach { video ->
                AsyncImage(
                    model = ImageRequest.Builder(LocalContext.current)
                        .data(video.channelAvatarUrl)
                        .crossfade(true)
                        .build(),
                    contentDescription = video.channelName,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .size(27.dp)
                        .clip(CircleShape)
                        .border(1.5.dp, Color.White.copy(alpha = 0.9f), CircleShape)
                )
            }
        }
    }
}

@Composable
private fun FlickItem(
    video: Video,
    exoPlayer: ExoPlayer,
    onLike: () -> Unit,
    onChannelClick: () -> Unit,
    onComment: () -> Unit,
    onMore: () -> Unit,
    onShare: () -> Unit
) {
    var isLiked by rememberSaveable(video.id) { mutableStateOf(false) }
    var isFollowing by rememberSaveable(video.channelId) { mutableStateOf(false) }

    Box(modifier = Modifier.fillMaxSize().background(Color.Black)) {
        AndroidView(
            factory = { ctx ->
                PlayerView(ctx).apply {
                    player = exoPlayer
                    useController = false
                    resizeMode = AspectRatioFrameLayout.RESIZE_MODE_ZOOM
                    layoutParams = FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT)
                }
            },
            update = { it.player = exoPlayer },
            modifier = Modifier.fillMaxSize()
        )

        Box(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        0f to Color.Black.copy(alpha = 0.34f),
                        0.48f to Color.Transparent,
                        1f to Color.Black.copy(alpha = 0.86f)
                    )
                )
        )

        Column(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .navigationBarsPadding()
                .padding(end = 10.dp, bottom = 136.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            FlickActionButton(
                icon = if (isLiked) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
                label = formatCount(video.likeCount + if (isLiked) 1 else 0),
                tint = if (isLiked) Color(0xFFFF3040) else Color.White
            ) {
                isLiked = !isLiked
                onLike()
            }
            FlickActionButton(Icons.Filled.Comment, formatCount(video.commentCount), onClick = onComment)
            FlickActionButton(Icons.Filled.Share, "Share", onClick = onShare)
            FlickActionButton(Icons.Filled.BookmarkBorder, "Save", onClick = { })
            FlickActionButton(Icons.Filled.MoreVert, "", onClick = onMore)
        }

        Column(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(start = 16.dp, end = 78.dp, bottom = 16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                AsyncImage(
                    model = ImageRequest.Builder(LocalContext.current)
                        .data(video.channelAvatarUrl)
                        .crossfade(true)
                        .build(),
                    contentDescription = video.channelName,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .border(2.dp, Color.White, CircleShape)
                        .clickable(onClick = onChannelClick)
                )
                Text(
                    text = video.channelName,
                    color = Color.White,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = if (isFollowing) "Following" else "Follow",
                    color = Color.White,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(Color.Black.copy(alpha = 0.35f))
                        .border(1.dp, Color.White.copy(alpha = 0.75f), CircleShape)
                        .clickable { isFollowing = !isFollowing }
                        .padding(horizontal = 14.dp, vertical = 7.dp)
                )
            }

            Text(
                text = video.title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = Color.White,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (video.description.isNotBlank()) {
                Text(
                    text = video.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.88f),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
            if (video.tags.isNotEmpty()) {
                Text(
                    text = video.tags.take(3).joinToString("  ") { "#$it" },
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White.copy(alpha = 0.9f),
                    maxLines = 1
                )
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp)
                    .clip(CircleShape)
                    .background(Color(0xE617191E))
                    .border(1.dp, Color.White.copy(alpha = 0.1f), CircleShape)
                    .clickable(onClick = onComment)
                    .padding(horizontal = 18.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Add a comment…", color = Color.White.copy(alpha = 0.65f), style = MaterialTheme.typography.bodyMedium)
                Spacer(Modifier.weight(1f))
                Text("☺", color = Color.White.copy(alpha = 0.7f), style = MaterialTheme.typography.titleMedium)
            }
        }
    }
}

@Composable
private fun FlickActionButton(
    icon: ImageVector,
    label: String,
    tint: Color = Color.White,
    onClick: () -> Unit
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier
                .size(46.dp)
                .clip(CircleShape)
                .background(Color.Black.copy(alpha = 0.34f))
                .clickable(onClick = onClick),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = label, tint = tint, modifier = Modifier.size(27.dp))
        }
        if (label.isNotEmpty()) {
            Text(text = label, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.SemiBold, color = Color.White)
        }
    }
}

/** Options sheet for a flick: report the video or block its creator (UGC safety). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FlickOptionsSheet(
    onDismiss: () -> Unit,
    onReport: () -> Unit,
    onBlock: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState()
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(modifier = Modifier.padding(bottom = 24.dp)) {
            ListItem(
                headlineContent = { Text("Report") },
                leadingContent = { Icon(Icons.Filled.Flag, contentDescription = null) },
                modifier = Modifier.clickable(onClick = onReport)
            )
            ListItem(
                headlineContent = { Text("Block channel") },
                leadingContent = { Icon(Icons.Filled.Block, contentDescription = null) },
                modifier = Modifier.clickable(onClick = onBlock)
            )
        }
    }
}

/** Reason picker for reporting a flick. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FlickReportReasonSheet(
    onDismiss: () -> Unit,
    onSelectReason: (ContentReportReason) -> Unit
) {
    val sheetState = rememberModalBottomSheetState()
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(modifier = Modifier.padding(bottom = 24.dp)) {
            Text(
                text = "Report Flick",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
            )
            Text(
                text = "Tell us what's wrong. Reports are reviewed by our moderation team.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
            Spacer(Modifier.height(8.dp))
            ContentReportReason.values().forEach { reason ->
                ListItem(
                    headlineContent = { Text(reason.title) },
                    modifier = Modifier.clickable { onSelectReason(reason) }
                )
            }
        }
    }
}

private fun formatCount(n: Long): String = when {
    n >= 1_000_000L -> "%.1fM".format(n / 1_000_000.0)
    n >= 1_000L -> "%.1fK".format(n / 1_000.0)
    else -> n.toString()
}
