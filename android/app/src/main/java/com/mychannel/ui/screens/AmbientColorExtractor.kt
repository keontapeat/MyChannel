package com.mychannel.ui.screens

import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.runtime.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import coil.ImageLoader
import coil.request.ImageRequest
import coil.request.SuccessResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.math.sqrt

/**
 * Extracts the dominant colour from a thumbnail URL and provides it for ambient mode.
 *
 * Usage:
 * ```
 * val ambient = rememberAmbientColor(thumbnailUrl)
 * Box(modifier = Modifier.background(ambient.value)) { ... }
 * ```
 */
@Composable
fun rememberAmbientColor(thumbnailUrl: String?): State<Color> {
    val context = LocalContext.current
    var dominant by remember(thumbnailUrl) { mutableStateOf(Color.Transparent) }

    LaunchedEffect(thumbnailUrl) {
        if (thumbnailUrl.isNullOrBlank()) return@LaunchedEffect
        val color = withContext(Dispatchers.IO) {
            runCatching {
                val loader = ImageLoader(context)
                val request = ImageRequest.Builder(context)
                    .data(thumbnailUrl)
                    .size(64)          // small sample for speed
                    .allowHardware(false)
                    .build()
                val result = loader.execute(request)
                val bitmap = (result as? SuccessResult)?.drawable?.let {
                    (it as? BitmapDrawable)?.bitmap
                } ?: return@runCatching null
                extractDominantColor(bitmap)
            }.getOrNull()
        }
        color?.let { dominant = it.copy(alpha = 0.35f) }
    }

    return animateColorAsState(
        targetValue = dominant,
        animationSpec = tween(durationMillis = 600),
        label = "ambient_color"
    )
}

/**
 * Simple dominant-color extraction: averages pixels in the center 50%×50% crop.
 */
private fun extractDominantColor(bitmap: Bitmap): Color {
    val w = bitmap.width
    val h = bitmap.height
    val x0 = w / 4
    val y0 = h / 4
    val x1 = 3 * w / 4
    val y1 = 3 * h / 4

    var rSum = 0L; var gSum = 0L; var bSum = 0L; var count = 0L
    val pixels = IntArray((x1 - x0) * (y1 - y0))
    bitmap.getPixels(pixels, 0, x1 - x0, x0, y0, x1 - x0, y1 - y0)
    for (px in pixels) {
        rSum += (px shr 16 and 0xFF)
        gSum += (px shr  8 and 0xFF)
        bSum += (px        and 0xFF)
        count++
    }
    if (count == 0) return Color.Black
    return Color(
        red   = (rSum / count).toInt(),
        green = (gSum / count).toInt(),
        blue  = (bSum / count).toInt()
    )
}
