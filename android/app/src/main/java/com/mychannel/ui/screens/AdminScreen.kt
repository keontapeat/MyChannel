package com.mychannel.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.mychannel.viewmodel.AdminViewModel
import com.mychannel.viewmodel.ModerationItem
import com.mychannel.viewmodel.PlatformStats

/**
 * Admin/Trust & Safety dashboard.
 * Platform moderation, content review, user management.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminScreen(
    navController: NavController,
    viewModel: AdminViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Admin Panel") },
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
            !uiState.isAdmin -> Box(Modifier.fillMaxSize().padding(innerPadding), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Filled.Lock, contentDescription = null, modifier = Modifier.size(48.dp))
                    Spacer(Modifier.height(8.dp))
                    Text("Admin Access Required", style = MaterialTheme.typography.titleMedium)
                    Text("You don't have permission to access this area", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            else -> {
                Column(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
                    TabRow(selectedTabIndex = uiState.selectedTab) {
                        Tab(selected = uiState.selectedTab == 0, onClick = { viewModel.selectTab(0) }) {
                            Text("Dashboard", modifier = Modifier.padding(16.dp))
                        }
                        Tab(selected = uiState.selectedTab == 1, onClick = { viewModel.selectTab(1) }) {
                            BadgedBox(badge = {
                                if (uiState.moderationQueue.isNotEmpty()) Badge { Text("${uiState.moderationQueue.size}") }
                            }) { Text("Moderation", modifier = Modifier.padding(16.dp)) }
                        }
                    }

                    when (uiState.selectedTab) {
                        0 -> AdminDashboard(uiState.stats)
                        1 -> ModerationQueue(uiState.moderationQueue, viewModel)
                    }
                }
            }
        }
    }
}

@Composable
private fun AdminDashboard(stats: PlatformStats) {
    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Text("Platform Overview", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        }
        item {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                AdminStatCard("Total Users", "${stats.totalUsers}", Icons.Filled.People, Modifier.weight(1f))
                AdminStatCard("Active Today", "${stats.activeUsersToday}", Icons.Filled.TrendingUp, Modifier.weight(1f))
            }
        }
        item {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                AdminStatCard("Total Videos", "${stats.totalVideos}", Icons.Filled.VideoLibrary, Modifier.weight(1f))
                AdminStatCard("Uploads Today", "${stats.uploadsToday}", Icons.Filled.Upload, Modifier.weight(1f))
            }
        }
        item {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                AdminStatCard("Total Reports", "${stats.totalReports}", Icons.Filled.Flag, Modifier.weight(1f))
                AdminStatCard("Pending", "${stats.pendingReports}", Icons.Filled.Warning, Modifier.weight(1f))
            }
        }
        item {
            Card(modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)) {
                Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.AttachMoney, contentDescription = null, modifier = Modifier.size(32.dp))
                    Spacer(Modifier.width(12.dp))
                    Column {
                        Text("Revenue Today", style = MaterialTheme.typography.labelMedium)
                        Text("$${stats.revenueTodayCents / 100}", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}

@Composable
private fun AdminStatCard(label: String, value: String, icon: androidx.compose.ui.graphics.vector.ImageVector, modifier: Modifier = Modifier) {
    Card(modifier = modifier) {
        Column(modifier = Modifier.padding(16.dp)) {
            Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(24.dp))
            Spacer(Modifier.height(8.dp))
            Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun ModerationQueue(items: List<ModerationItem>, viewModel: AdminViewModel) {
    if (items.isEmpty()) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Filled.CheckCircle, contentDescription = null, modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.primary)
                Text("Queue is clear", style = MaterialTheme.typography.titleMedium)
                Text("No pending content to review", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    } else {
        LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            items(items, key = { it.id }) { item ->
                ModerationCard(item, viewModel)
            }
        }
    }
}

@Composable
private fun ModerationCard(item: ModerationItem, viewModel: AdminViewModel) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(item.contentTitle.ifBlank { "Untitled Content" }, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                AssistChip(onClick = {}, label = { Text(item.contentType) })
            }
            Spacer(Modifier.height(4.dp))
            Text("By: ${item.contentCreator}", style = MaterialTheme.typography.bodySmall)
            Text("Reason: ${item.reportReason}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
            Text("Reported by: ${item.reporterName}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (item.aiConfidence > 0) {
                Text("AI Confidence: ${"%.0f".format(item.aiConfidence * 100)}%", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.tertiary)
            }
            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilledTonalButton(onClick = { viewModel.approveContent(item.id) }) {
                    Icon(Icons.Filled.Check, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Approve")
                }
                Button(onClick = { viewModel.removeContent(item.id) }, colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)) {
                    Icon(Icons.Filled.Delete, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Remove")
                }
                OutlinedButton(onClick = { viewModel.escalateContent(item.id) }) {
                    Text("Escalate")
                }
            }
        }
    }
}
