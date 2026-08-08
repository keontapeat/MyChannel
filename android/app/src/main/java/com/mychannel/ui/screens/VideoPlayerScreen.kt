package com.mychannel.ui.screens

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.Intent
import android.net.Uri
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.Cast
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.ClosedCaption
import androidx.compose.material.icons.filled.ClosedCaptionDisabled
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Hd
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.PictureInPicture
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.ThumbDown
import androidx.compose.material.icons.filled.ThumbUp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Divider
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.ui.PlayerView
import androidx.navigation.NavController
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.mychannel.domain.model.Comment
import com.mychannel.domain.model.ContentReportReason
import com.mychannel.domain.model.Video
import com.mychannel.services.DownloadWorker
import com.mychannel.ui.PipController
import com.mychannel.viewmodel.VideoPlayerViewModel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.delay

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
    val context = LocalContext.current
    var showOverflowMenu by remember { mutableStateOf(false) }
    var showReportSheet by remember { mutableStateOf(false) }
    var reportingComment by remember { mutableStateOf<Comment?>(null) }
    var showCastSheet by remember { mutableStateOf(false) }

    LaunchedEffect(videoId) {
        viewModel.loadVideo(videoId)
    }

    // Surface action feedback (engagement/moderation) as a toast, then clear it.
    LaunchedEffect(uiState.actionMessage) {
        uiState.actionMessage?.let { message ->
            Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
            viewModel.clearActionMessage()
        }
    }

    if (showCastSheet) {
        CastingBottomSheet(onDismiss = { showCastSheet = false })
    }

    if (showReportSheet) {
        ReportReasonSheet(
            title = "Report video",
            onDismiss = { showReportSheet = false },
            onSelectReason = { reason ->
                showReportSheet = false
                viewModel.reportVideo(reason)
            }
        )
    }

    reportingComment?.let { comment ->
        ReportReasonSheet(
            title = "Report comment",
            onDismiss = { reportingComment = null },
            onSelectReason = { reason ->
                reportingComment = null
                viewModel.reportComment(comment, reason)
            }
        )
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
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        uiState.playbackSession?.supportsPictureInPicture == true
                    ) {
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
                    // Cast button
                    IconButton(onClick = { showCastSheet = true }) {
                        Icon(Icons.Filled.Cast, contentDescription = "Cast to TV")
                    }
                    // Overflow: Report / Block (UGC safety — required for store review)
                    IconButton(onClick = { showOverflowMenu = true }) {
                        Icon(Icons.Filled.MoreVert, contentDescription = "More options")
                    }
                    DropdownMenu(
                        expanded = showOverflowMenu,
                        onDismissRequest = { showOverflowMenu = false }
                    ) {
                        DropdownMenuItem(
                            text = { Text("Report video") },
                            leadingIcon = { Icon(Icons.Filled.Flag, contentDescription = null) },
                            onClick = {
                                showOverflowMenu = false
                                showReportSheet = true
                            }
                        )
                        DropdownMenuItem(
                            text = { Text("Block channel") },
                            leadingIcon = { Icon(Icons.Filled.Block, contentDescription = null) },
                            onClick = {
                                showOverflowMenu = false
                                viewModel.blockChannel()
                            }
                        )
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
                    TextButton(onClick = viewModel::retryVideo) { Text("Retry") }
                }
            }

            uiState.playbackError != null -> Box(
                Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(uiState.playbackError!!, style = MaterialTheme.typography.bodyLarge)
                    TextButton(onClick = viewModel::retryVideo) { Text("Retry") }
                }
            }

            uiState.video != null && uiState.authorizedPlaybackUrl != null -> VideoPlayerContent(
                modifier = Modifier.fillMaxSize().padding(innerPadding),
                video = uiState.video!!,
                authorizedPlaybackUrl = uiState.authorizedPlaybackUrl!!,
                comments = uiState.comments,
                suggested = uiState.suggested,
                isLiked = uiState.isLiked,
                isDisliked = uiState.isDisliked,
                isSaved = uiState.isSaved,
                isSubscribed = uiState.isSubscribed,
                playbackPositionMs = uiState.playbackPositionMs,
                supportsCaptions = uiState.playbackSession?.supportsCaptions == true,
                supportsOfflineDownload = uiState.playbackSession?.supportsOfflineDownload == true,
                onLike = viewModel::toggleLike,
                onDislike = viewModel::toggleDislike,
                onSave = viewModel::toggleSave,
                onSubscribe = viewModel::toggleSubscribe,
                onQualifiedView = { viewModel.recordQualifiedView(uiState.video!!.id) },
                onPlaybackProgress = { positionMs, durationMs, watchedMs ->
                    viewModel.savePlaybackProgress(
                        uiState.video!!.id,
                        positionMs,
                        durationMs,
                        watchedMs
                    )
                },
                onComment = { text -> viewModel.postComment(text) },
                onReplyComment = { text, parentId -> viewModel.postComment(text, parentId) },
                onReportComment = { comment -> reportingComment = comment },
                onChannelClick = {
                    navController.navigate("channel/${Uri.encode(uiState.video!!.channelId)}")
                },
                navController = navController
            )
        }
    }
}

@Composable
private fun VideoPlayerContent(
    modifier: Modifier,
    video: Video,
    authorizedPlaybackUrl: String,
    comments: List<Comment>,
    suggested: List<Video>,
    isLiked: Boolean,
    isDisliked: Boolean,
    isSaved: Boolean,
    isSubscribed: Boolean,
    playbackPositionMs: Long,
    supportsCaptions: Boolean,
    supportsOfflineDownload: Boolean,
    onLike: () -> Unit,
    onDislike: () -> Unit,
    onSave: () -> Unit,
    onSubscribe: () -> Unit,
    onQualifiedView: () -> Unit,
    onPlaybackProgress: (Long, Long, Long) -> Unit,
    onComment: (String) -> Unit,
    onReplyComment: (String, String) -> Unit,
    onReportComment: (Comment) -> Unit,
    onChannelClick: () -> Unit,
    navController: NavController? = null
) {
    val context = LocalContext.current
    var commentText by remember { mutableStateOf("") }
    var descExpanded by remember { mutableStateOf(false) }
    var replyingTo by remember { mutableStateOf<Pair<String, String>?>(null) } // (parentId, username)
    var showQualitySheet by remember { mutableStateOf(false) }
    var showSpeedSheet by remember { mutableStateOf(false) }
    var selectedSpeed by remember { mutableStateOf(1.0f) }
    var captionsEnabled by remember { mutableStateOf(supportsCaptions) }
    var selectedQuality by remember { mutableStateOf("Auto") }

    val topLevelComments = remember(comments) { comments.filter { it.parentId.isNullOrEmpty() } }

    // Quality selector sheet
    if (showQualitySheet) {
        QualitySheet(
            selectedQuality = selectedQuality,
            onQualitySelected = { selectedQuality = it },
            onDismiss = { showQualitySheet = false }
        )
    }
    if (showSpeedSheet) {
        SpeedSheet(
            selectedSpeed = selectedSpeed,
            onSpeedSelected = { selectedSpeed = it; showSpeedSheet = false },
            onDismiss = { showSpeedSheet = false }
        )
    }
    val repliesByParent = remember(comments) { comments.filter { !it.parentId.isNullOrEmpty() }.groupBy { it.parentId } }

    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(bottom = 24.dp)
    ) {
        // Video player surface with ambient glow
        item(key = "player") {
            val ambientColor = rememberAmbientColor(video.thumbnailUrl)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        brush = androidx.compose.ui.graphics.Brush.verticalGradient(
                            listOf(
                                ambientColor.value,
                                androidx.compose.ui.graphics.Color.Black,
                                ambientColor.value
                            )
                        )
                    )
            ) {
                VideoSurface(
                        videoId = video.id,
                        videoUrl = authorizedPlaybackUrl,
                        initialPositionMs = playbackPositionMs,
                        supportsCaptions = supportsCaptions,
                        captionsEnabled = captionsEnabled,
                        playbackSpeed = selectedSpeed,
                        maxQuality = selectedQuality,
                        onQualifiedView = onQualifiedView,
                        onProgress = onPlaybackProgress,
                        modifier = Modifier
                            .fillMaxWidth()
                            .aspectRatio(16f / 9f)
                            .background(Color.Black)
                    )
            }
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

        // Chapter markers (YouTube-style scrollable strip)
        if (video.chapters.isNotEmpty()) {
            item(key = "chapters") {
                ChaptersRow(
                    chapters = video.chapters,
                    durationMs = video.duration * 1000L,
                    currentPositionMs = playbackPositionMs,
                    onChapterClick = { chapterSec ->
                        // Navigate to chapter start via callback
                        onPlaybackProgress(chapterSec * 1000L, video.duration * 1000L, 0L)
                    }
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
                IconButton(
                    onClick = onLike,
                    modifier = Modifier.semantics { selected = isLiked }
                ) {
                    Icon(
                        Icons.Filled.ThumbUp,
                        contentDescription = if (isLiked) "Unlike" else "Like",
                        tint = if (isLiked) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurface
                    )
                }
                Text(
                    text = formatCount(video.likeCount),
                    style = MaterialTheme.typography.bodySmall
                )
                IconButton(
                    onClick = onDislike,
                    modifier = Modifier.semantics { selected = isDisliked }
                ) {
                    Icon(
                        Icons.Filled.ThumbDown,
                        contentDescription = if (isDisliked) "Remove dislike" else "Dislike",
                        tint = if (isDisliked) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurface
                    )
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
                IconButton(
                    onClick = onSave,
                    modifier = Modifier.semantics { selected = isSaved }
                ) {
                    Icon(
                        if (isSaved) Icons.Filled.Bookmark else Icons.Filled.BookmarkBorder,
                        contentDescription = if (isSaved) "Saved" else "Save",
                        tint = if (isSaved) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                    )
                }
                if (supportsOfflineDownload) {
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
                }
                // Super Thanks button
                if (navController != null) {
                    TextButton(
                        onClick = {
                            navController.navigate(
                                "super_thanks/${Uri.encode(video.id)}/${Uri.encode(video.channelId)}/${Uri.encode(video.channelName)}"
                            )
                        }
                    ) {
                        Text("❤️ Thanks", style = MaterialTheme.typography.labelMedium)
                    }
                }
                // Quality selector
                IconButton(onClick = { showQualitySheet = true }) {
                    Icon(
                        Icons.Filled.Hd,
                        contentDescription = "Quality",
                        tint = MaterialTheme.colorScheme.onSurface
                    )
                }
                // Playback speed
                IconButton(onClick = { showSpeedSheet = true }) {
                    Text(
                        text = if (selectedSpeed == 1.0f) "1×" else "${selectedSpeed}×",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
                // Captions toggle
                if (supportsCaptions) {
                    IconButton(onClick = { captionsEnabled = !captionsEnabled }) {
                        Icon(
                            if (captionsEnabled) Icons.Filled.ClosedCaption else Icons.Filled.ClosedCaptionDisabled,
                            contentDescription = if (captionsEnabled) "Captions on" else "Captions off",
                            tint = if (captionsEnabled) MaterialTheme.colorScheme.primary
                                   else MaterialTheme.colorScheme.onSurface
                        )
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
                    modifier = Modifier.semantics { selected = isSubscribed },
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
                SuggestedRow(
                    video = s,
                    onClick = { navController?.navigate("video/${Uri.encode(s.id)}") }
                )
            }
            item(key = "divider_upnext") { Divider(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) }
        }

        if (video.commentsEnabled && !video.madeForKids) {
            item(key = "comments_header") {
                Text(
                    text = "${video.commentCount} Comments",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                )
            }

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

            items(items = topLevelComments, key = { it.id }) { comment ->
                CommentThread(
                    comment = comment,
                    replies = repliesByParent[comment.id] ?: emptyList(),
                    onReply = { replyingTo = comment.id to comment.username },
                    onReportComment = onReportComment
                )
            }
        } else {
            item(key = "comments_disabled") {
                Text(
                    text = "Comments are turned off for this video.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(16.dp)
                )
            }
        }
    }
}

/**
 * Hosts a Media3 [PlayerView] inside Compose. The ExoPlayer is created once
 * and released when the composable leaves the composition. Play/pause follows
 * the lifecycle [Lifecycle.Event.ON_PAUSE] / [Lifecycle.Event.ON_RESUME].
 */
@Composable
private fun VideoSurface(
    videoId: String,
    videoUrl: String,
    initialPositionMs: Long,
    supportsCaptions: Boolean,
    captionsEnabled: Boolean,
    playbackSpeed: Float,
    maxQuality: String,
    onQualifiedView: () -> Unit,
    onProgress: (Long, Long, Long) -> Unit,
    modifier: Modifier
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val currentOnQualifiedView by rememberUpdatedState(onQualifiedView)
    val currentOnProgress by rememberUpdatedState(onProgress)
    var resumeAfterPause by remember(videoUrl) { mutableStateOf(false) }
    var watchedPlaybackMs by remember(videoUrl) { mutableStateOf(0L) }
    var hasReportedQualifiedView by remember(videoUrl) { mutableStateOf(false) }

    val trackSelector = remember(videoUrl) { DefaultTrackSelector(context) }
    val exoPlayer = remember(videoUrl) {
        ExoPlayer.Builder(context)
            .setTrackSelector(trackSelector)
            .build().apply {
                setMediaItem(MediaItem.fromUri(videoUrl))
                if (initialPositionMs > 0L) seekTo(initialPositionMs)
                prepare()
                playWhenReady = true
            }
    }

    LaunchedEffect(maxQuality) {
        val params = trackSelector.buildUponParameters()
        when (maxQuality) {
            "360p"  -> params.setMaxVideoSize(640, 360).setMaxVideoBitrate(800_000)
            "480p"  -> params.setMaxVideoSize(854, 480).setMaxVideoBitrate(1_500_000)
            "720p"  -> params.setMaxVideoSize(1280, 720).setMaxVideoBitrate(4_000_000)
            "1080p" -> params.setMaxVideoSize(1920, 1080).setMaxVideoBitrate(8_000_000)
            else    -> params.clearVideoSizeConstraints().setMaxVideoBitrate(Int.MAX_VALUE)
        }
        trackSelector.setParameters(params)
    }

    // Wire captions toggle to ExoPlayer text track selection
    LaunchedEffect(captionsEnabled) {
        val params = trackSelector.buildUponParameters()
        if (captionsEnabled) {
            params.setPreferredTextLanguage("en")
                  .setIgnoredTextSelectionFlags(0)
        } else {
            params.setRendererDisabled(
                exoPlayer.rendererCount.let { count ->
                    (0 until count).firstOrNull { exoPlayer.getRendererType(it) == androidx.media3.common.C.TRACK_TYPE_TEXT } ?: -1
                },
                true
            )
        }
        trackSelector.setParameters(params)
    }

    // Apply playback speed
    LaunchedEffect(playbackSpeed) {
        exoPlayer.setPlaybackSpeed(playbackSpeed)
    }

    LaunchedEffect(exoPlayer, videoId) {
        while (true) {
            delay(PROGRESS_POLL_INTERVAL_MS)
            if (exoPlayer.isPlaying) {
                watchedPlaybackMs += PROGRESS_POLL_INTERVAL_MS
                if (!hasReportedQualifiedView && watchedPlaybackMs >= QUALIFIED_VIEW_THRESHOLD_MS) {
                    hasReportedQualifiedView = true
                    currentOnQualifiedView()
                }
            }
            val durationMs = exoPlayer.duration.takeIf { it > 0L } ?: 0L
            currentOnProgress(
                exoPlayer.currentPosition.coerceAtLeast(0L),
                durationMs,
                watchedPlaybackMs
            )
        }
    }

    DisposableEffect(lifecycleOwner, exoPlayer) {
        val listener = object : androidx.media3.common.Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                PipController.isVideoActive = isPlaying
            }
        }
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_PAUSE -> {
                    val activity = context as? Activity
                    val inPip = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        activity?.isInPictureInPictureMode == true
                    } else {
                        false
                    }
                    if (!inPip) {
                        resumeAfterPause = exoPlayer.isPlaying
                        exoPlayer.pause()
                    }
                }
                Lifecycle.Event.ON_RESUME -> {
                    if (resumeAfterPause) {
                        exoPlayer.play()
                        resumeAfterPause = false
                    }
                }
                else -> Unit
            }
        }
        exoPlayer.addListener(listener)
        PipController.isVideoActive = exoPlayer.isPlaying
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            currentOnProgress(
                exoPlayer.currentPosition.coerceAtLeast(0L),
                exoPlayer.duration.takeIf { it > 0L } ?: 0L,
                watchedPlaybackMs
            )
            lifecycleOwner.lifecycle.removeObserver(observer)
            exoPlayer.removeListener(listener)
            PipController.isVideoActive = false
            (context as? Activity)?.requestedOrientation =
                android.content.pm.ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            exoPlayer.release()
        }
    }

    AndroidView(
        factory = { ctx ->
            PlayerView(ctx).apply {
                player = exoPlayer
                layoutParams = FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT)
                setShowSubtitleButton(supportsCaptions)
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

private const val PROGRESS_POLL_INTERVAL_MS = 1_000L
private const val QUALIFIED_VIEW_THRESHOLD_MS = 5_000L

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
private fun CommentThread(
    comment: Comment,
    replies: List<Comment>,
    onReply: () -> Unit,
    onReportComment: (Comment) -> Unit
) {
    Column {
        CommentRow(comment = comment, onReport = { onReportComment(comment) })
        Row(modifier = Modifier.padding(start = 64.dp)) {
            TextButton(onClick = onReply) {
                Text("Reply", style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.SemiBold)
            }
        }
        replies.forEach { reply ->
            Box(modifier = Modifier.padding(start = 32.dp)) {
                CommentRow(comment = reply, onReport = { onReportComment(reply) })
            }
        }
    }
}

@Composable
private fun CommentRow(comment: Comment, onReport: () -> Unit) {
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
        // Report entry for user-generated comments (UGC moderation).
        IconButton(onClick = onReport) {
            Icon(
                Icons.Filled.Flag,
                contentDescription = "Report comment",
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

/**
 * Bottom sheet listing the standard content-report reasons. Selecting one
 * submits a report through the ViewModel. Required for user-generated-content
 * moderation on both the App Store (Guideline 1.2) and Google Play.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReportReasonSheet(
    title: String,
    onDismiss: () -> Unit,
    onSelectReason: (ContentReportReason) -> Unit
) {
    val sheetState = rememberModalBottomSheetState()
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(modifier = Modifier.padding(bottom = 24.dp)) {
            Text(
                text = title,
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

/**
 * Quality selector bottom sheet — lets the viewer pick from Auto / 1080p / 720p / 480p / 360p.
 * The selected quality is applied immediately to [VideoSurface] via [DefaultTrackSelector];
 * ExoPlayer re-selects the nearest available rendition within the ABR stream.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun QualitySheet(
    selectedQuality: String,
    onQualitySelected: (String) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState()
    val qualities = listOf("Auto", "1080p", "720p", "480p", "360p", "240p")

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(modifier = Modifier.padding(bottom = 32.dp)) {
            Text(
                "Quality",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)
            )
            qualities.forEach { quality ->
                ListItem(
                    headlineContent = { Text(quality) },
                    leadingContent = {
                        Icon(
                            if (quality == selectedQuality) Icons.Filled.CheckCircle else Icons.Filled.Circle,
                            contentDescription = null,
                            tint = if (quality == selectedQuality) MaterialTheme.colorScheme.primary
                                   else MaterialTheme.colorScheme.outlineVariant,
                            modifier = Modifier.size(20.dp)
                        )
                    },
                    modifier = Modifier.clickable {
                        onQualitySelected(quality)
                        onDismiss()
                    }
                )
            }
        }
    }
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

// MARK: - Chapter markers (YouTube-style scrollable strip)
@Composable
private fun ChaptersRow(
    chapters: List<com.mychannel.domain.model.VideoChapter>,
    durationMs: Long,
    currentPositionMs: Long,
    onChapterClick: (Long) -> Unit
) {
    if (chapters.isEmpty()) return

    val currentChapterIdx = remember(currentPositionMs, chapters) {
        chapters.indexOfLast { it.startSec * 1000L <= currentPositionMs }.coerceAtLeast(0)
    }

    Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
        Text(
            "Chapters",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(Modifier.height(8.dp))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            itemsIndexed(chapters) { idx, chapter ->
                val isActive = idx == currentChapterIdx
                val nextStartMs = chapters.getOrNull(idx + 1)?.startSec?.times(1000L) ?: durationMs
                val chapterDurationSec = ((nextStartMs - chapter.startSec * 1000L) / 1000L).coerceAtLeast(0L)
                val progressFraction = if (isActive && durationMs > 0) {
                    ((currentPositionMs - chapter.startSec * 1000L).coerceAtLeast(0L).toFloat() /
                        (nextStartMs - chapter.startSec * 1000L).coerceAtLeast(1L).toFloat()).coerceIn(0f, 1f)
                } else if (idx < currentChapterIdx) 1f else 0f

                Surface(
                    shape = MaterialTheme.shapes.small,
                    color = if (isActive) MaterialTheme.colorScheme.primaryContainer
                            else MaterialTheme.colorScheme.surfaceVariant,
                    modifier = Modifier
                        .width(140.dp)
                        .clickable { onChapterClick(chapter.startSec) }
                ) {
                    Column(modifier = Modifier.padding(10.dp)) {
                        Text(
                            chapter.title,
                            style = MaterialTheme.typography.bodySmall,
                            fontWeight = if (isActive) FontWeight.Bold else FontWeight.Normal,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            formatDuration(chapter.startSec),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(Modifier.height(6.dp))
                        LinearProgressIndicator(
                            progress = { progressFraction },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(2.dp)
                                .clip(MaterialTheme.shapes.extraSmall),
                            color = if (isActive) MaterialTheme.colorScheme.primary
                                    else MaterialTheme.colorScheme.outline
                        )
                    }
                }
            }
        }
    }
}

private fun formatDuration(seconds: Long): String {
    val h = seconds / 3600
    val m = (seconds % 3600) / 60
    val s = seconds % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s)
    else "%d:%02d".format(m, s)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SpeedSheet(
    selectedSpeed: Float,
    onSpeedSelected: (Float) -> Unit,
    onDismiss: () -> Unit
) {
    val speeds = listOf(0.25f, 0.5f, 0.75f, 1.0f, 1.25f, 1.5f, 1.75f, 2.0f)
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(modifier = Modifier.padding(bottom = 24.dp)) {
            Text(
                "Playback Speed",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(16.dp)
            )
            speeds.forEach { speed ->
                ListItem(
                    headlineContent = {
                        Text(if (speed == 1.0f) "Normal (1×)" else "${speed}×")
                    },
                    leadingContent = {
                        Icon(
                            if (speed == selectedSpeed) Icons.Filled.CheckCircle else Icons.Filled.Circle,
                            contentDescription = null,
                            tint = if (speed == selectedSpeed) MaterialTheme.colorScheme.primary
                                   else MaterialTheme.colorScheme.outlineVariant,
                            modifier = Modifier.size(20.dp)
                        )
                    },
                    modifier = Modifier.clickable { onSpeedSelected(speed) }
                )
            }
        }
    }
}
