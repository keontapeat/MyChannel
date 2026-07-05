package com.mychannel.ui.screens

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.Intent
import android.os.Build
import android.widget.Toast
import android.util.Rational
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.widget.FrameLayout
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.PictureInPicture
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.ThumbDown
import androidx.compose.material.icons.filled.ThumbUp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import androidx.navigation.NavController
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.mychannel.domain.model.Comment
import com.mychannel.domain.model.Video
import com.mychannel.services.DownloadWorker
import com.mychannel.ui.PipController
import com.mychannel.viewmodel.VideoPlayerViewModel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Full-screen video player screen with HLS playback, metadata, like/dislike,
 * share, channel subscription, and comments (REQ-5.1 – REQ-5.6).
 *
 * Uses Media3 ExoPlayer for HLS adaptive bitrate streaming. Player lifecycle
 * is tied to the Composable via [DisposableEffect].
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VideoPlayerScreen(
    videoId: String,
    navController: NavController,
    viewModel: VideoPlayerViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    LaunchedEffect(videoId) {
        viewModel.loadVideo(videoId)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    // PiP button — Android 8+ only
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val context = LocalContext.current
                        IconButton(onClick = {
                            val activity = context as? Activity ?: return@IconButton
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                val params = PictureInPictureParams.Builder()
                                    .setAspectRatio(Rational(16, 9))
                                    .build()
                                activity.enterPictureInPictureMode(params)
                            }
                        }) {
                            Icon(Icons.Filled.PictureInPicture, contentDescription = "Picture in Picture")
                        }
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

            uiState.error != null -> Box(
                Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Failed to load video", style = MaterialTheme.typography.bodyLarge)
                    TextButton(onClick = { viewModel.loadVideo(videoId) }) { Text("Retry") }
                }
            }

            uiState.video != null -> VideoPlayerContent(
                modifier = Modifier.fillMaxSize().padding(innerPadding),
                video = uiState.video!!,
                comments = uiState.comments,
                suggested = uiState.suggested,
                isLiked = uiState.isLiked,
                isSaved = uiState.isSaved,
                isSubscribed = uiState.isSubscribed,
                onLike = { viewModel.toggleLike(true) },
                onDislike = { viewModel.toggleLike(false) },
                onSave = { viewModel.toggleSave() },
                onSubscribe = { viewModel.toggleSubscribe() },
                onComment = { text -> viewModel.postComment(text) },
                onReplyComment = { text, parentId -> viewModel.postComment(text, parentId) },
                onChannelClick = { navController.navigate("channel/${uiState.video!!.channelId}") },
                navController = navController
            )
        }
    }
}

@Composable
private fun VideoPlayerContent(
    modifier: Modifier,
    video: Video,
    comments: List<Comment>,
    suggested: List<Video>,
    isLiked: Boolean,
    isSaved: Boolean,
    isSubscribed: Boolean,
    onLike: () -> Unit,
    onDislike: () -> Unit,
    onSave: () -> Unit,
    onSubscribe: () -> Unit,
    onComment: (String) -> Unit,
    onReplyComment: (String, String) -> Unit,
    onChannelClick: () -> Unit,
    navController: NavController? = null
) {
    val context = LocalContext.current
    var commentText by remember { mutableStateOf("") }
    var descExpanded by remember { mutableStateOf(false) }
    var replyingTo by remember { mutableStateOf<Pair<String, String>?>(null) } // (parentId, username)

    val topLevelComments = remember(comments) { comments.filter { it.parentId.isNullOrEmpty() } }
    val repliesByParent = remember(comments) { comments.filter { !it.parentId.isNullOrEmpty() }.groupBy { it.parentId } }

    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(bottom = 24.dp)
    ) {
        // Video player surface
        item(key = "player") {
            VideoSurface(
                videoUrl = video.videoUrl,
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(16f / 9f)
                    .background(Color.Black)
            )
        }

        // Title + metadata
        item(key = "meta") {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = video.title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = "${formatCount(video.viewCount)} views • ${formatTimestamp(video.uploadedAt.toDate())}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        // Like / share row
        item(key = "actions") {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onLike) {
                    Icon(
                        Icons.Filled.ThumbUp,
                        contentDescription = "Like",
                        tint = if (isLiked) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurface
                    )
                }
                Text(
                    text = formatCount(video.likeCount),
                    style = MaterialTheme.typography.bodySmall
                )
                IconButton(onClick = onDislike) {
                    Icon(Icons.Filled.ThumbDown, contentDescription = "Dislike")
                }
                Spacer(Modifier.weight(1f))
                IconButton(onClick = {
                    val shareUrl = "https://mychannel.live/watch/${video.id}"
                    val sendIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_SUBJECT, video.title)
                        putExtra(Intent.EXTRA_TEXT, "${video.title}\n$shareUrl")
                    }
                    context.startActivity(Intent.createChooser(sendIntent, "Share via"))
                }) {
                    Icon(Icons.Filled.Share, contentDescription = "Share")
                }
                IconButton(onClick = onSave) {
                    Icon(
                        if (isSaved) Icons.Filled.Bookmark else Icons.Filled.BookmarkBorder,
                        contentDescription = if (isSaved) "Saved" else "Save",
                        tint = if (isSaved) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                    )
                }
                IconButton(onClick = {
                    val request = OneTimeWorkRequestBuilder<DownloadWorker>()
                        .setInputData(workDataOf(DownloadWorker.KEY_VIDEO_ID to video.id))
                        .addTag(DownloadWorker.DOWNLOAD_WORK_TAG)
                        .build()
                    WorkManager.getInstance(context).enqueueUniqueWork(
                        "download_${video.id}",
                        ExistingWorkPolicy.KEEP,
                        request
                    )
                    Toast.makeText(context, "Download started", Toast.LENGTH_SHORT).show()
                }) {
                    Icon(Icons.Filled.Download, contentDescription = "Download")
                }
                // Super Thanks button
                if (navController != null) {
                    TextButton(
                        onClick = {
                            navController.navigate(
                                "super_thanks/${video.id}/${video.channelId}/${video.channelName}"
                            )
                        }
                    ) {
                        Text("❤️ Thanks", style = MaterialTheme.typography.labelMedium)
                    }
                }
            }
        }

        item(key = "divider1") { Divider(modifier = Modifier.padding(horizontal = 16.dp)) }

        // Channel row
        item(key = "channel") {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onChannelClick)
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                AsyncImage(
                    model = ImageRequest.Builder(LocalContext.current)
                        .data(video.channelAvatarUrl)
                        .crossfade(true)
                        .build(),
                    contentDescription = video.channelName,
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                )
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = video.channelName,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold
                    )
                }
                // Subscribe button
                Button(
                    onClick = onSubscribe,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isSubscribed) MaterialTheme.colorScheme.surfaceVariant
                        else MaterialTheme.colorScheme.error
                    )
                ) {
                    Text(
                        text = if (isSubscribed) "Subscribed" else "Subscribe",
                        color = if (isSubscribed) MaterialTheme.colorScheme.onSurfaceVariant
                        else androidx.compose.ui.graphics.Color.White
                    )
                }
            }
        }

        // Description (collapsible)
        if (video.description.isNotBlank()) {
            item(key = "description") {
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                        .clickable { descExpanded = !descExpanded },
                    shape = RoundedCornerShape(12.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant
                ) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Text(
                            text = video.description,
                            style = MaterialTheme.typography.bodyMedium,
                            maxLines = if (descExpanded) Int.MAX_VALUE else 3
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            text = if (descExpanded) "Show less" else "Show more",
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }

        item(key = "divider2") { Divider(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) }

        // Up next / suggested
        if (suggested.isNotEmpty()) {
            item(key = "upnext_header") {
                Text(
                    text = "Up next",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                )
            }
            items(items = suggested, key = { "s_${it.id}" }) { s ->
                SuggestedRow(video = s, onClick = { navController?.navigate("video/${s.id}") })
            }
            item(key = "divider_upnext") { Divider(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) }
        }

        // Comments header
        item(key = "comments_header") {
            Text(
                text = "${video.commentCount} Comments",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
            )
        }

        // Comment input (reply-aware)
        item(key = "comment_input") {
            Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                replyingTo?.let { (_, username) ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = "Replying to @$username",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.primary
                        )
                        TextButton(onClick = { replyingTo = null; commentText = "" }) {
                            Text("Cancel", style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    val submit: () -> Unit = {
                        if (commentText.isNotBlank()) {
                            val parent = replyingTo?.first
                            if (parent != null) onReplyComment(commentText.trim(), parent)
                            else onComment(commentText.trim())
                            commentText = ""
                            replyingTo = null
                        }
                    }
                    OutlinedTextField(
                        value = commentText,
                        onValueChange = { commentText = it },
                        placeholder = { Text(if (replyingTo != null) "Add a reply…" else "Add a comment…") },
                        modifier = Modifier.weight(1f),
                        maxLines = 3,
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                        keyboardActions = KeyboardActions(onSend = { submit() })
                    )
                    IconButton(onClick = submit) {
                        Icon(Icons.Filled.Send, contentDescription = "Post comment")
                    }
                }
            }
        }

        // Comment list (threaded: top-level + replies)
        items(items = topLevelComments, key = { it.id }) { comment ->
            CommentThread(
                comment = comment,
                replies = repliesByParent[comment.id] ?: emptyList(),
                onReply = { replyingTo = comment.id to comment.username }
            )
        }
    }
}

/**
 * Hosts a Media3 [PlayerView] inside Compose. The ExoPlayer is created once
 * and released when the composable leaves the composition. Play/pause follows
 * the lifecycle [Lifecycle.Event.ON_PAUSE] / [Lifecycle.Event.ON_RESUME].
 */
@Composable
private fun VideoSurface(videoUrl: String, modifier: Modifier) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    val exoPlayer = remember(videoUrl) {
        ExoPlayer.Builder(context).build().apply {
            setMediaItem(MediaItem.fromUri(videoUrl))
            prepare()
            playWhenReady = true
        }
    }

    // Track playback state so MainActivity.onUserLeaveHint can decide whether to
    // auto-enter PiP (Task 5). Only an actively-playing video is PiP-eligible.
    DisposableEffect(exoPlayer) {
        val listener = object : androidx.media3.common.Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                PipController.isVideoActive = isPlaying
            }
        }
        exoPlayer.addListener(listener)
        PipController.isVideoActive = exoPlayer.isPlaying
        onDispose {
            exoPlayer.removeListener(listener)
            PipController.isVideoActive = false
        }
    }

    // Pause/resume with lifecycle
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                // In PiP mode the lifecycle moves to STARTED (not PAUSED), so we
                // check whether the activity is actually in PiP before pausing.
                Lifecycle.Event.ON_PAUSE -> {
                    val activity = context as? Activity
                    val inPip = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        activity?.isInPictureInPictureMode == true
                    } else false
                    if (!inPip) exoPlayer.pause()
                }
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

    AndroidView(
        factory = { ctx ->
            PlayerView(ctx).apply {
                player = exoPlayer
                layoutParams = FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT)
                setShowSubtitleButton(true)
                // Fullscreen button → rotate to landscape and back
                setFullscreenButtonClickListener { isFullscreen ->
                    (ctx as? Activity)?.requestedOrientation = if (isFullscreen) {
                        android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                    } else {
                        android.content.pm.ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
                    }
                }
            }
        },
        modifier = modifier
    )
}

@Composable
private fun SuggestedRow(video: Video, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .width(160.dp)
                .aspectRatio(16f / 9f)
                .clip(RoundedCornerShape(8.dp))
                .background(Color.Black)
        ) {
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(video.thumbnailUrl)
                    .crossfade(true)
                    .build(),
                contentDescription = video.title,
                modifier = Modifier.fillMaxSize()
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = video.title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = video.channelName,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = "${formatCount(video.viewCount)} views",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun CommentThread(comment: Comment, replies: List<Comment>, onReply: () -> Unit) {
    Column {
        CommentRow(comment = comment)
        Row(modifier = Modifier.padding(start = 64.dp)) {
            TextButton(onClick = onReply) {
                Text("Reply", style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.SemiBold)
            }
        }
        replies.forEach { reply ->
            Box(modifier = Modifier.padding(start = 32.dp)) {
                CommentRow(comment = reply)
            }
        }
    }
}

@Composable
private fun CommentRow(comment: Comment) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        AsyncImage(
            model = ImageRequest.Builder(LocalContext.current)
                .data(comment.avatarUrl)
                .crossfade(true)
                .build(),
            contentDescription = comment.username,
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
        )
        Column(modifier = Modifier.weight(1f)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = comment.username,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = formatTimestamp(comment.createdAt.toDate()),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Text(
                text = comment.text,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(top = 2.dp)
            )
        }
    }
}

private fun formatCount(n: Long): String = when {
    n >= 1_000_000L -> "%.1fM".format(n / 1_000_000.0)
    n >= 1_000L -> "%.1fK".format(n / 1_000.0)
    else -> n.toString()
}

private fun formatTimestamp(date: Date): String {
    val now = System.currentTimeMillis()
    val diff = now - date.time
    return when {
        diff < 60_000L -> "just now"
        diff < 3_600_000L -> "${diff / 60_000}m ago"
        diff < 86_400_000L -> "${diff / 3_600_000}h ago"
        diff < 2_592_000_000L -> "${diff / 86_400_000}d ago"
        else -> SimpleDateFormat("MMM d, yyyy", Locale.getDefault()).format(date)
    }
}
