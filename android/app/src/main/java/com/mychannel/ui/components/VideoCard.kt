package com.mychannel.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
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
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.google.firebase.Timestamp
import com.mychannel.domain.model.Video
import java.util.concurrent.TimeUnit

/**
 * Reusable video card (REQ-4.3): 16:9 thumbnail with a duration badge, channel
 * avatar, two-line title, channel name, view count + relative upload date, and
 * an optional overflow menu.
 *
 * The [onClick]/[video]/[modifier] signature is preserved for existing callers;
 * overflow actions are opt-in via [overflowActions].
 */
@Composable
fun VideoCard(
    video: Video,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    overflowActions: List<VideoCardAction> = emptyList()
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
    ) {
        // Thumbnail with duration badge
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 9f)
                .clip(RoundedCornerShape(12.dp))
        ) {
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(video.thumbnailUrl)
                    .crossfade(true)
                    .build(),
                contentDescription = video.title,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop
            )

            if (video.isLive) {
                LiveBadge(
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(8.dp)
                )
            } else if (video.duration > 0L) {
                DurationBadge(
                    durationSeconds = video.duration,
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(6.dp)
                )
            }
        }

        // Metadata row: avatar + text + overflow
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(video.channelAvatarUrl)
                    .crossfade(true)
                    .build(),
                contentDescription = "${video.channelName} avatar",
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
            )

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = video.title,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = buildMetaLine(video),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 2.dp)
                )
            }

            if (overflowActions.isNotEmpty()) {
                VideoCardOverflowMenu(actions = overflowActions)
            }
        }
    }
}

/** A labelled action for the [VideoCard] overflow menu. */
data class VideoCardAction(
    val label: String,
    val onClick: () -> Unit
)

@Composable
private fun VideoCardOverflowMenu(actions: List<VideoCardAction>) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        IconButton(onClick = { expanded = true }) {
            Icon(
                imageVector = Icons.Default.MoreVert,
                contentDescription = "More options"
            )
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            actions.forEach { action ->
                DropdownMenuItem(
                    text = { Text(action.label) },
                    onClick = {
                        expanded = false
                        action.onClick()
                    }
                )
            }
        }
    }
}

@Composable
private fun DurationBadge(
    durationSeconds: Long,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(4.dp))
            .background(Color.Black.copy(alpha = 0.78f))
            .padding(horizontal = 5.dp, vertical = 2.dp)
    ) {
        Text(
            text = formatDuration(durationSeconds),
            color = Color.White,
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium
        )
    }
}

private fun buildMetaLine(video: Video): String {
    val views = "${formatViewCount(video.viewCount)} views"
    val age = formatRelativeTime(video.uploadedAt)
    return if (age.isNotEmpty()) "${video.channelName} · $views · $age"
    else "${video.channelName} · $views"
}

internal fun formatViewCount(count: Long): String = when {
    count >= 1_000_000_000L -> String.format("%.1fB", count / 1_000_000_000.0)
    count >= 1_000_000L -> String.format("%.1fM", count / 1_000_000.0)
    count >= 1_000L -> String.format("%.1fK", count / 1_000.0)
    else -> count.toString()
}

internal fun formatDuration(totalSeconds: Long): String {
    val hours = TimeUnit.SECONDS.toHours(totalSeconds)
    val minutes = TimeUnit.SECONDS.toMinutes(totalSeconds) % 60
    val seconds = totalSeconds % 60
    return if (hours > 0) {
        String.format("%d:%02d:%02d", hours, minutes, seconds)
    } else {
        String.format("%d:%02d", minutes, seconds)
    }
}

internal fun formatRelativeTime(timestamp: Timestamp): String {
    val epochMillis = timestamp.seconds * 1000L
    if (epochMillis <= 0L) return ""
    val now = System.currentTimeMillis()
    val diff = now - epochMillis
    if (diff < 0L) return ""

    val minutes = TimeUnit.MILLISECONDS.toMinutes(diff)
    val hours = TimeUnit.MILLISECONDS.toHours(diff)
    val days = TimeUnit.MILLISECONDS.toDays(diff)
    return when {
        minutes < 1L -> "just now"
        minutes < 60L -> "$minutes min ago"
        hours < 24L -> "$hours ${if (hours == 1L) "hour" else "hours"} ago"
        days < 7L -> "$days ${if (days == 1L) "day" else "days"} ago"
        days < 30L -> "${days / 7} ${if (days / 7 == 1L) "week" else "weeks"} ago"
        days < 365L -> "${days / 30} ${if (days / 30 == 1L) "month" else "months"} ago"
        else -> "${days / 365} ${if (days / 365 == 1L) "year" else "years"} ago"
    }
}
