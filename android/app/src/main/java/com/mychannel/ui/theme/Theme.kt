package com.mychannel.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val DarkColorScheme = darkColorScheme(
    primary = BrandRed,
    onPrimary = OnErrorColor,
    primaryContainer = BrandRedDark,
    onPrimaryContainer = OnErrorColor,
    secondary = SecondaryDark,
    onSecondary = OnSurfaceDark,
    secondaryContainer = SurfaceVariantDark,
    onSecondaryContainer = OnSurfaceDark,
    tertiary = TertiaryDark,
    onTertiary = OnSurfaceDark,
    background = BackgroundDark,
    onBackground = OnBackgroundDark,
    surface = SurfaceDark,
    onSurface = OnSurfaceDark,
    surfaceVariant = SurfaceVariantDark,
    onSurfaceVariant = OnSurfaceVariantDark,
    error = ErrorColor,
    onError = OnErrorColor,
    errorContainer = ErrorContainerDark,
    outline = OutlineDark
)

private val LightColorScheme = lightColorScheme(
    primary = BrandRed,
    onPrimary = OnErrorColor,
    primaryContainer = BrandRedLight,
    onPrimaryContainer = OnErrorColor,
    secondary = SecondaryLight,
    onSecondary = OnSurfaceLight,
    secondaryContainer = SurfaceVariantLight,
    onSecondaryContainer = OnSurfaceLight,
    tertiary = TertiaryLight,
    onTertiary = OnSurfaceLight,
    background = BackgroundLight,
    onBackground = OnBackgroundLight,
    surface = SurfaceLight,
    onSurface = OnSurfaceLight,
    surfaceVariant = SurfaceVariantLight,
    onSurfaceVariant = OnSurfaceVariantLight,
    error = ErrorColor,
    onError = OnErrorColor,
    errorContainer = ErrorContainerLight,
    outline = OutlineLight
)

/**
 * MyChannel theme composable.
 *
 * Supports three modes:
 * - System (follows device dark/light setting)
 * - Dark (forced dark)
 * - Light (forced light)
 *
 * @param darkTheme Whether to use the dark color scheme. Defaults to system setting.
 * @param content The composable content to theme.
 */
@Composable
fun MyChannelTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.background.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = MyChannelTypography,
        shapes = MyChannelShapes,
        content = content
    )
}
