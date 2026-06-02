package com.mychannel.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mychannel.ui.theme.BrandRed

/**
 * Red "LIVE" pill badge (REQ-4.4).
 *
 * A compact rounded pill with a white dot and uppercase LIVE label, used to
 * mark live stream cards and the home Live Now section. Exposes a single
 * content description for TalkBack rather than reading each glyph.
 */
@Composable
fun LiveBadge(
    modifier: Modifier = Modifier,
    text: String = "LIVE"
) {
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(4.dp))
            .background(BrandRed)
            .padding(horizontal = 6.dp, vertical = 3.dp)
            .semantics { contentDescription = "Live now" },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        androidx.compose.foundation.layout.Box(
            modifier = Modifier
                .size(6.dp)
                .clip(CircleShape)
                .background(Color.White)
        )
        Text(
            text = text,
            color = Color.White,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold
        )
    }
}
