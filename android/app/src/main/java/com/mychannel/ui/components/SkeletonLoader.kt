package com.mychannel.ui.components

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * Shimmer loading placeholders (REQ-4.5).
 *
 * [shimmerBrush] produces an animated linear-gradient brush that sweeps across
 * placeholder boxes. [VideoCardSkeleton] mirrors the [VideoCard] layout so the
 * first-load state matches the real content footprint and avoids layout jumps.
 */
@Composable
fun shimmerBrush(): Brush {
    val shimmerColors = listOf(
        Color.LightGray.copy(alpha = 0.35f),
        Color.LightGray.copy(alpha = 0.18f),
        Color.LightGray.copy(alpha = 0.35f)
    )

    val transition = rememberInfiniteTransition(label = "shimmer")
    val translate by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1000f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1200),
            repeatMode = RepeatMode.Restart
        ),
        label = "shimmerTranslate"
    )

    return Brush.linearGradient(
        colors = shimmerColors,
        start = Offset(translate - 400f, translate - 400f),
        end = Offset(translate, translate)
    )
}

/** A single shimmering block with a rounded shape. */
@Composable
fun SkeletonBox(
    modifier: Modifier = Modifier,
    cornerRadius: Int = 8
) {
    androidx.compose.foundation.layout.Box(
        modifier = modifier
            .clip(RoundedCornerShape(cornerRadius.dp))
            .background(shimmerBrush())
    )
}

/** Skeleton placeholder matching the [VideoCard] footprint. */
@Composable
fun VideoCardSkeleton(modifier: Modifier = Modifier) {
    Column(modifier = modifier.fillMaxWidth()) {
        SkeletonBox(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 9f),
            cornerRadius = 12
        )
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            SkeletonBox(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape),
                cornerRadius = 20
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                SkeletonBox(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(14.dp)
                )
                SkeletonBox(
                    modifier = Modifier
                        .fillMaxWidth(0.6f)
                        .height(12.dp)
                )
            }
        }
    }
}

/** A vertical stack of [VideoCardSkeleton]s shown during the first feed load. */
@Composable
fun VideoFeedSkeleton(
    modifier: Modifier = Modifier,
    itemCount: Int = 5
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        repeat(itemCount) {
            VideoCardSkeleton()
        }
    }
}

/** A horizontal row of circular skeletons mirroring the Stories row. */
@Composable
fun StoriesRowSkeleton(
    modifier: Modifier = Modifier,
    itemCount: Int = 6
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        repeat(itemCount) {
            Column(horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally) {
                SkeletonBox(
                    modifier = Modifier
                        .size(64.dp)
                        .clip(CircleShape),
                    cornerRadius = 32
                )
                Spacer(modifier = Modifier.height(6.dp))
                SkeletonBox(
                    modifier = Modifier
                        .width(48.dp)
                        .height(10.dp)
                )
            }
        }
    }
}
