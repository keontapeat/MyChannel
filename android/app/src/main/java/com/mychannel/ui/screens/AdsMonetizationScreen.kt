package com.mychannel.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.AttachMoney
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.mychannel.viewmodel.AdCampaign
import com.mychannel.viewmodel.AdsMonetizationViewModel
import com.mychannel.viewmodel.MonetizationStats

/**
 * Ads & Monetization dashboard.
 * YouTube parity: ad revenue overview, campaign management, monetization settings.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdsMonetizationScreen(
    navController: NavController,
    viewModel: AdsMonetizationViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Monetization") },
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
                    Text("Overview", modifier = Modifier.padding(16.dp))
                }
                Tab(selected = uiState.selectedTab == 1, onClick = { viewModel.selectTab(1) }) {
                    Text("Campaigns", modifier = Modifier.padding(16.dp))
                }
                Tab(selected = uiState.selectedTab == 2, onClick = { viewModel.selectTab(2) }) {
                    Text("Settings", modifier = Modifier.padding(16.dp))
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
                uiState.selectedTab == 0 -> MonetizationOverview(uiState.stats)
                uiState.selectedTab == 1 -> CampaignsList(uiState.campaigns, viewModel)
                uiState.selectedTab == 2 -> MonetizationSettings()
            }
        }
    }
}

@Composable
private fun MonetizationOverview(stats: MonetizationStats) {
    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Card(modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)) {
                Column(modifier = Modifier.padding(20.dp)) {
                    Text("Estimated Revenue", style = MaterialTheme.typography.labelLarge)
                    Spacer(Modifier.height(4.dp))
                    Text("$${stats.totalRevenueCents / 100}.${(stats.totalRevenueCents % 100).toString().padStart(2, '0')}", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
                }
            }
        }
        item {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                StatCard("Ad Revenue", "$${stats.adRevenueCents / 100}", Modifier.weight(1f))
                StatCard("Memberships", "$${stats.membershipRevenueCents / 100}", Modifier.weight(1f))
            }
        }
        item {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                StatCard("Super Thanks", "$${stats.superThanksRevenueCents / 100}", Modifier.weight(1f))
                StatCard("CPM", "${"%.2f".format(stats.cpm)}", Modifier.weight(1f))
            }
        }
        item {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                StatCard("Views (Month)", "${stats.thisMonthViewCount}", Modifier.weight(1f))
                StatCard("Est. Payout", "$${stats.estimatedPayoutCents / 100}", Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun StatCard(label: String, value: String, modifier: Modifier = Modifier) {
    Card(modifier = modifier) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(4.dp))
            Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun CampaignsList(campaigns: List<AdCampaign>, viewModel: AdsMonetizationViewModel) {
    if (campaigns.isEmpty()) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Filled.TrendingUp, contentDescription = null, modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.primary)
                Text("No campaigns yet", style = MaterialTheme.typography.titleMedium)
                Text("Create an ad campaign to promote your content", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    } else {
        LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            items(campaigns, key = { it.id }) { campaign ->
                CampaignCard(campaign, viewModel)
            }
        }
    }
}

@Composable
private fun CampaignCard(campaign: AdCampaign, viewModel: AdsMonetizationViewModel) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(campaign.title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                AssistChip(onClick = {}, label = { Text(campaign.status) })
            }
            Spacer(Modifier.height(8.dp))
            Text("Type: ${campaign.type} • Budget: $${campaign.budgetCents / 100}", style = MaterialTheme.typography.bodySmall)
            Text("Impressions: ${campaign.impressions} • Clicks: ${campaign.clicks} • CTR: ${"%.1f".format(campaign.ctr)}%", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("Spent: $${campaign.spentCents / 100} / $${campaign.budgetCents / 100}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (campaign.status == "active") {
                    OutlinedButton(onClick = { viewModel.pauseCampaign(campaign.id) }) {
                        Icon(Icons.Filled.Pause, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Pause")
                    }
                } else if (campaign.status == "paused") {
                    FilledTonalButton(onClick = { viewModel.resumeCampaign(campaign.id) }) {
                        Icon(Icons.Filled.PlayArrow, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Resume")
                    }
                }
            }
        }
    }
}

@Composable
private fun MonetizationSettings() {
    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("Ad Types", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(12.dp))
                    SettingsToggle("Pre-roll Ads", true)
                    SettingsToggle("Mid-roll Ads", true)
                    SettingsToggle("Post-roll Ads", false)
                    SettingsToggle("Banner Overlay Ads", true)
                }
            }
        }
        item {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("Monetization Features", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(12.dp))
                    SettingsToggle("Channel Memberships", true)
                    SettingsToggle("Super Chat & Super Thanks", true)
                    SettingsToggle("Merchandise Shelf", false)
                }
            }
        }
    }
}

@Composable
private fun SettingsToggle(label: String, defaultEnabled: Boolean) {
    var enabled by remember { mutableStateOf(defaultEnabled) }
    Row(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
        Switch(checked = enabled, onCheckedChange = { enabled = it })
    }
}
