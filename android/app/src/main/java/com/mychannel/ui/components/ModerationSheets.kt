package com.mychannel.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mychannel.domain.model.ContentReportReason

/**
 * Shared moderation UI (user-generated-content safety) used across the video,
 * live stream, and channel surfaces. Keeping these in one place guarantees a
 * consistent report/block experience and avoids per-screen duplication.
 */

/** Options sheet offering "Report" and "Block". */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReportBlockOptionsSheet(
    reportLabel: String = "Report",
    blockLabel: String = "Block",
    onDismiss: () -> Unit,
    onReport: () -> Unit,
    onBlock: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState()
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(modifier = Modifier.padding(bottom = 24.dp)) {
            ListItem(
                headlineContent = { Text(reportLabel) },
                leadingContent = { Icon(Icons.Filled.Flag, contentDescription = null) },
                modifier = Modifier.clickable(onClick = onReport)
            )
            ListItem(
                headlineContent = { Text(blockLabel) },
                leadingContent = { Icon(Icons.Filled.Block, contentDescription = null) },
                modifier = Modifier.clickable(onClick = onBlock)
            )
        }
    }
}

/** Reason picker; selecting a reason submits the report. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReportReasonSheet(
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
