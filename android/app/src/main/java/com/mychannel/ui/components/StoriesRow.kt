package com.mychannel.ui.components

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import androidx.compose.ui.platform.LocalContext
import com.mychannel.domain.model.Story
import com.mychannel.ui.theme.BrandRed

/**
 * Horizontal row of circular creator avatars (REQ-4.2).
 *
 * Live creators get a pulsing red ring (animated alpha) to draw the eye; non-live
 * stories show a static accent ring. Each item is keyed by story id for stable
 * recomposition in the [LazyRow].
 */
@Composable
fun StoriesRow(
    stories: List<Story>,
    onStoryClick: (Story) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyRow(
        modifier = modifier,
        contentPadding = PaddingValues(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items(items = stories, key = { it.id }) { story ->
            StoryAvatar(story = story, onClick = { onStoryClick(story) })
        }
    }
}

@Composable
private fun StoryAvatar(
    story: Story,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val ringAlpha = if (story.isLive) {
        val transition = rememberInfiniteTransition(label = "liveRing")
        transition.animateFloat(
            initialValue = 0.4f,
            targetValue = 1f,
            animationSpec = infiniteRepeatable(
                animation = tween(durationMillis = 800),
                repeatMode = RepeatMode.Reverse
            ),
            label = "liveRingAlpha"
        ).value
    } else {
        1f
    }

    val ringColor = if (story.isLive) BrandRed else MaterialTheme.colorScheme.primary

    Column(
        modifier = modifier
            .width(72.dp)
            .clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(contentAlignment = Alignment.Center) {
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(story.avatarUrl)
                    .crossfade(true)
                    .build(),
                contentDescription = "${story.creatorName} story",
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(64.dp)
                    .clip(CircleShape)
                    .border(
                        width = 2.5.dp,
                        color = ringColor.copy(alpha = ringAlpha),
                        shape = CircleShape
                    )
                    .padding(3.dp)
                    .clip(CircleShape)
            )
            if (story.isLive) {
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .clip(CircleShape)
                ) {
                    LiveBadge()
                }
            }
        }
        Text(
            text = story.creatorName,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .padding(top = 4.dp)
                .alpha(if (story.isViewed) 0.6f else 1f)
        )
    }
}
