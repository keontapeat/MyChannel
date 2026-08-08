package com.mychannel.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Group
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
import com.mychannel.viewmodel.Collaboration
import com.mychannel.viewmodel.CollaborationViewModel

/**
 * Collaboration screen — manage co-creator invitations and joint content.
 * YouTube parity: collaborative videos, revenue splits, co-creator features.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CollaborationScreen(
    navController: NavController,
    viewModel: CollaborationViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Collaborations") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { innerPadding ->
        Column(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            TabRow(selectedTabIndex = uiState.selectedTab) {
                Tab(selected = uiState.selectedTab == 0, onClick = { viewModel.selectTab(0) }) {
                    Text("Active", modifier = Modifier.padding(16.dp))
                }
                Tab(selected = uiState.selectedTab == 1, onClick = { viewModel.selectTab(1) }) {
                    BadgedBox(badge = {
                        if (uiState.incomingRequests.isNotEmpty()) Badge { Text("${uiState.incomingRequests.size}") }
                    }) { Text("Requests", modifier = Modifier.padding(16.dp)) }
                }
                Tab(selected = uiState.selectedTab == 2, onClick = { viewModel.selectTab(2) }) {
                    Text("Past", modifier = Modifier.padding(16.dp))
                }
            }

            when {
                uiState.isLoading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                uiState.error != null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(uiState.error ?: "Error", color = MaterialTheme.colorScheme.error)
                        Spacer(Modifier.height(8.dp))
                        Button(onClick = { viewModel.retry() }) { Text("Retry") }
                    }
                }
                uiState.selectedTab == 0 -> CollabList(uiState.activeCollaborations, viewModel, showActions = false)
                uiState.selectedTab == 1 -> CollabList(uiState.incomingRequests, viewModel, showActions = true)
                uiState.selectedTab == 2 -> CollabList(uiState.pastCollaborations, viewModel, showActions = false)
            }
        }
    }
}

@Composable
private fun CollabList(collabs: List<Collaboration>, viewModel: CollaborationViewModel, showActions: Boolean) {
    if (collabs.isEmpty()) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Filled.Group, contentDescription = null, modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.primary)
                Text("No collaborations", style = MaterialTheme.typography.titleMedium)
                Text("Team up with other creators", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    } else {
        LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            items(collabs, key = { it.id }) { collab ->
                CollabCard(collab, showActions, viewModel)
            }
        }
    }
}

@Composable
private fun CollabCard(collab: Collaboration, showActions: Boolean, viewModel: CollaborationViewModel) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (collab.initiatorAvatar.isNotBlank()) {
                    AsyncImage(
                        model = ImageRequest.Builder(LocalContext.current).data(collab.initiatorAvatar).crossfade(true).build(),
                        contentDescription = collab.initiatorName,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.size(40.dp).clip(CircleShape)
                    )
                    Spacer(Modifier.width(12.dp))
                }
                Column(modifier = Modifier.weight(1f)) {
                    Text(collab.title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                    Text("From: ${collab.initiatorName}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                AssistChip(onClick = {}, label = { Text(collab.type) })
            }
            if (collab.description.isNotBlank()) {
                Spacer(Modifier.height(8.dp))
                Text(collab.description, style = MaterialTheme.typography.bodySmall, maxLines = 2)
            }
            if (collab.collaboratorNames.isNotEmpty()) {
                Spacer(Modifier.height(4.dp))
                Text("With: ${collab.collaboratorNames.joinToString(", ")}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Text("Status: ${collab.status}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (showActions && collab.status == "pending") {
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilledTonalButton(onClick = { viewModel.acceptCollaboration(collab.id) }) {
                        Icon(Icons.Filled.Check, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Accept")
                    }
                    OutlinedButton(onClick = { viewModel.declineCollaboration(collab.id) }) {
                        Icon(Icons.Filled.Close, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Decline")
                    }
                }
            }
        }
    }
}
