package com.mychannel.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Science
import androidx.compose.material3.*
import androidx.compose.runtime.*
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
import com.mychannel.viewmodel.ThumbnailTest
import com.mychannel.viewmodel.ThumbnailTestingViewModel
import com.mychannel.viewmodel.ThumbnailVariant

/**
 * Thumbnail A/B Testing screen.
 * YouTube parity: test multiple thumbnails, view CTR metrics, pick winners.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ThumbnailTestingScreen(
    navController: NavController,
    viewModel: ThumbnailTestingViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Thumbnail Testing") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { innerPadding ->
        when {
            uiState.isLoading -> Box(Modifier.fillMaxSize().padding(innerPadding), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
            uiState.error != null -> Box(Modifier.fillMaxSize().padding(innerPadding), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(uiState.error ?: "Error", color = MaterialTheme.colorScheme.error)
                    Spacer(Modifier.height(8.dp))
                    Button(onClick = { viewModel.retry() }) { Text("Retry") }
                }
            }
            uiState.tests.isEmpty() -> Box(Modifier.fillMaxSize().padding(innerPadding), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Icon(Icons.Filled.Science, contentDescription = null, modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.primary)
                    Text("No thumbnail tests", style = MaterialTheme.typography.titleMedium)
                    Text("Start a test from your video manager", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            else -> LazyColumn(
                modifier = Modifier.fillMaxSize().padding(innerPadding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                items(uiState.tests, key = { it.id }) { test ->
                    ThumbnailTestCard(test, viewModel)
                }
            }
        }
    }
}

@Composable
private fun ThumbnailTestCard(test: ThumbnailTest, viewModel: ThumbnailTestingViewModel) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(test.videoTitle, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                AssistChip(onClick = {}, label = { Text(test.status) })
            }
            Spacer(Modifier.height(12.dp))

            test.variants.forEach { variant ->
                VariantRow(variant, isWinner = variant.id == test.winnerId, onSelect = {
                    if (test.status == "running") viewModel.endTest(test.id, variant.id)
                })
                Spacer(Modifier.height(8.dp))
            }
        }
    }
}

@Composable
private fun VariantRow(variant: ThumbnailVariant, isWinner: Boolean, onSelect: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        if (variant.imageUrl.isNotBlank()) {
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current).data(variant.imageUrl).crossfade(true).build(),
                contentDescription = "Variant ${variant.label}",
                contentScale = ContentScale.Crop,
                modifier = Modifier.size(80.dp, 45.dp).clip(RoundedCornerShape(8.dp))
            )
        } else {
            Surface(
                modifier = Modifier.size(80.dp, 45.dp),
                shape = RoundedCornerShape(8.dp),
                color = MaterialTheme.colorScheme.surfaceVariant
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text(variant.label, style = MaterialTheme.typography.titleMedium)
                }
            }
        }

        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Variant ${variant.label}", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold)
                if (isWinner) {
                    Spacer(Modifier.width(4.dp))
                    Icon(Icons.Filled.EmojiEvents, contentDescription = "Winner", tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(16.dp))
                }
            }
            Text("CTR: ${"%.1f".format(variant.ctr)}% • ${variant.impressions} imp • ${variant.clicks} clicks", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        if (!isWinner) {
            TextButton(onClick = onSelect) { Text("Pick") }
        }
    }
}
