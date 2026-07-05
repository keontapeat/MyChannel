package com.mychannel.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.mychannel.viewmodel.VideoAnalyticsViewModel

/**
 * Per-video analytics screen — views chart, watch time, likes, comments, CTR.
 * YouTube Studio parity: shows performance metrics for a single video.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VideoAnalyticsScreen(
    videoId: String,
    navController: NavController,
    viewModel: VideoAnalyticsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Video Analytics") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { innerPadding ->
        when {
            uiState.isLoading -> Box(
                Modifier.fillMaxSize().padding(innerPadding),
                contentAlignment = Alignment.Center
            ) { CircularProgressIndicator() }

            uiState.error != null -> Box(
                Modifier.fillMaxSize().padding(innerPadding),
                contentAlignment = Alignment.Center
            ) { Text(uiState.error ?: "Error loading analytics") }

            else -> LazyColumn(
                modifier = Modifier.fillMaxSize().padding(innerPadding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Stat cards row
                item(key = "stats") {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        listOf(
                            "Views" to formatCount(uiState.viewCount),
                            "Likes" to formatCount(uiState.likeCount),
                            "Comments" to formatCount(uiState.commentCount),
                            "Watch time" to "${uiState.watchTimeHours}h"
                        ).chunked(2).forEach { pair ->
                            Column(
                                modifier = Modifier.weight(1f),
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                pair.forEach { (label, value) ->
                                    Card(modifier = Modifier.fillMaxWidth()) {
                                        Column(modifier = Modifier.padding(12.dp)) {
                                            Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                                            Text(label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Views over time chart
                item(key = "chart") {
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text("Views over time", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                            Spacer(Modifier.height(8.dp))
                            if (uiState.viewsPerDay.isNotEmpty()) {
                                LineChart(
                                    data = uiState.viewsPerDay,
                                    modifier = Modifier.fillMaxWidth().height(160.dp),
                                    lineColor = MaterialTheme.colorScheme.primary
                                )
                            } else {
                                Box(
                                    Modifier.fillMaxWidth().height(160.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text("No daily data available", color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                                }
                            }
                        }
                    }
                }

                // Key metrics
                item(key = "metrics") {
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Text("Key metrics", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                            listOf(
                                "Avg. view duration" to uiState.avgViewDuration,
                                "Click-through rate" to "${uiState.ctr}%",
                                "Impressions" to formatCount(uiState.impressions),
                                "Est. revenue" to "$${"%.2f".format(uiState.estimatedRevenueCents / 100.0)}"
                            ).forEach { (label, value) ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text(value, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                                }
                            }
                        }
                    }
                }

                // Traffic sources
                if (uiState.trafficSources.isNotEmpty()) {
                    item(key = "traffic") {
                        Card(modifier = Modifier.fillMaxWidth()) {
                            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text("Traffic sources", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                                uiState.trafficSources.forEach { (source, pct) ->
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Text(source, style = MaterialTheme.typography.bodySmall)
                                        Text("$pct%", style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun LineChart(data: List<Long>, modifier: Modifier = Modifier, lineColor: Color) {
    val maxVal = remember(data) { data.maxOrNull()?.coerceAtLeast(1L) ?: 1L }
    Canvas(modifier = modifier.padding(horizontal = 8.dp, vertical = 4.dp)) {
        if (data.size < 2) return@Canvas
        val stepX = size.width / (data.size - 1)
        val points = data.mapIndexed { i, v ->
            Offset(i * stepX, size.height - (v.toFloat() / maxVal * size.height))
        }
        // Fill under the line
        val fillPath = Path().apply {
            moveTo(points.first().x, size.height)
            points.forEach { lineTo(it.x, it.y) }
            lineTo(points.last().x, size.height)
            close()
        }
        drawPath(
            fillPath,
            brush = Brush.verticalGradient(
                colors = listOf(lineColor.copy(alpha = 0.3f), lineColor.copy(alpha = 0.0f))
            )
        )
        // Draw line
        val linePath = Path().apply {
            moveTo(points.first().x, points.first().y)
            points.drop(1).forEach { lineTo(it.x, it.y) }
        }
        drawPath(linePath, color = lineColor, style = Stroke(width = 3.dp.toPx()))
        // Dots at each point
        points.forEach { drawCircle(lineColor, radius = 4.dp.toPx(), center = it) }
    }
}

private fun formatCount(n: Long): String = when {
    n >= 1_000_000L -> "%.1fM".format(n / 1_000_000.0)
    n >= 1_000L -> "%.1fK".format(n / 1_000.0)
    else -> n.toString()
}
