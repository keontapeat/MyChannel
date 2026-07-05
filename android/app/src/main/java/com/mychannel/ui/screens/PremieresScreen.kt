package com.mychannel.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.NotificationsNone
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Tv
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.mychannel.viewmodel.PremieresViewModel
import kotlinx.coroutines.delay
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Premieres — scheduled video releases with countdown and reminder support.
 * YouTube-parity: shows upcoming, live, and past premieres.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PremieresScreen(
    navController: NavController,
    viewModel: PremieresViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Premieres") },
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

            uiState.premieres.isEmpty() -> Box(
                Modifier.fillMaxSize().padding(innerPadding),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(Icons.Filled.Tv, contentDescription = null, modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("No premieres scheduled", style = MaterialTheme.typography.titleMedium)
                    Text("Follow creators to see their upcoming premieres", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }

            else -> LazyColumn(
                modifier = Modifier.fillMaxSize().padding(innerPadding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(uiState.premieres, key = { it.id }) { premiere ->
                    PremiereCard(
                        premiere = premiere,
                        onWatch = { navController.navigate("video/${premiere.id}") },
                        onReminder = { viewModel.toggleReminder(premiere.id, premiere.hasReminder) }
                    )
                }
            }
        }
    }
}

@Composable
private fun PremiereCard(
    premiere: com.mychannel.viewmodel.Premiere,
    onWatch: () -> Unit,
    onReminder: () -> Unit
) {
    val now = System.currentTimeMillis()
    val scheduledMs = premiere.scheduledAtMs
    val isPast = scheduledMs < now
    val isImminent = !isPast && scheduledMs - now < 600_000L

    var countdown by remember { mutableLongStateOf(scheduledMs - System.currentTimeMillis()) }
    LaunchedEffect(scheduledMs) {
        while (countdown > 0) {
            delay(1000)
            countdown = scheduledMs - System.currentTimeMillis()
        }
    }

    Card(modifier = Modifier.fillMaxWidth()) {
        Column {
            // Thumbnail
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(16f / 9f)
                    .clip(RoundedCornerShape(topStart = 12.dp, topEnd = 12.dp))
            ) {
                AsyncImage(
                    model = ImageRequest.Builder(LocalContext.current).data(premiere.thumbnailUrl).crossfade(true).build(),
                    contentDescription = premiere.title,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop
                )
                // Premiere badge
                Box(modifier = Modifier.align(Alignment.TopStart).padding(8.dp)) {
                    androidx.compose.material3.Badge(
                        containerColor = if (premiere.isLive) MaterialTheme.colorScheme.error
                        else MaterialTheme.colorScheme.primaryContainer
                    ) {
                        Text(if (premiere.isLive) "LIVE" else "PREMIERE", style = MaterialTheme.typography.labelSmall)
                    }
                }
            }

            Column(modifier = Modifier.padding(16.dp)) {
                Text(premiere.title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, maxLines = 2)

                // Schedule info / countdown
                if (premiere.isLive) {
                    Text("Live now", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error, fontWeight = FontWeight.Bold)
                } else if (isPast) {
                    Text(
                        "Premiered ${SimpleDateFormat("MMM d", Locale.getDefault()).format(Date(scheduledMs))}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                } else {
                    val h = countdown / 3_600_000
                    val m = (countdown % 3_600_000) / 60_000
                    val s = (countdown % 60_000) / 1000
                    val countdownText = if (h > 0) "${h}h ${m}m" else "${m}m ${s}s"
                    Text(
                        "Starts in $countdownText",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary,
                        fontWeight = FontWeight.SemiBold
                    )
                }

                Row(
                    modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    if (premiere.isLive || isPast) {
                        Button(onClick = onWatch, modifier = Modifier.weight(1f)) {
                            Icon(Icons.Filled.PlayArrow, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(4.dp))
                            Text(if (premiere.isLive) "Watch Live" else "Watch")
                        }
                    } else {
                        OutlinedButton(onClick = onReminder, modifier = Modifier.weight(1f)) {
                            Icon(
                                if (premiere.hasReminder) Icons.Filled.Notifications else Icons.Filled.NotificationsNone,
                                contentDescription = null,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(Modifier.width(4.dp))
                            Text(if (premiere.hasReminder) "Reminder set" else "Set reminder")
                        }
                    }
                }
            }
        }
    }
}
