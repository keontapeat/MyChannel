package com.mychannel.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.unit.dp

/**
 * MyChannel standardized corner radii following Material Design 3.
 * Uses a 4dp base grid for consistent rounding across components.
 */
val MyChannelShapes = Shapes(
    // Extra small: chips, badges, small buttons
    extraSmall = RoundedCornerShape(4.dp),
    // Small: text fields, small cards
    small = RoundedCornerShape(8.dp),
    // Medium: cards, dialogs, menus
    medium = RoundedCornerShape(12.dp),
    // Large: bottom sheets, navigation drawers
    large = RoundedCornerShape(16.dp),
    // Extra large: full-screen dialogs, large cards
    extraLarge = RoundedCornerShape(28.dp)
)
