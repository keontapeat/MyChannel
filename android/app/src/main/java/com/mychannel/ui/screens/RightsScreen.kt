package com.mychannel.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Gavel
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.mychannel.viewmodel.CopyrightClaim
import com.mychannel.viewmodel.DMCANotice
import com.mychannel.viewmodel.RightsViewModel

/**
 * Rights & DMCA management screen.
 * YouTube parity: Content ID claims, DMCA notices, disputes.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RightsScreen(
    navController: NavController,
    viewModel: RightsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Rights Management") },
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
                    Text("Copyright Claims", modifier = Modifier.padding(16.dp))
                }
                Tab(selected = uiState.selectedTab == 1, onClick = { viewModel.selectTab(1) }) {
                    Text("DMCA Notices", modifier = Modifier.padding(16.dp))
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
                uiState.selectedTab == 0 -> ClaimsList(uiState.claims, viewModel)
                uiState.selectedTab == 1 -> DMCAList(uiState.dmcaNotices, viewModel)
            }
        }
    }
}

@Composable
private fun ClaimsList(claims: List<CopyrightClaim>, viewModel: RightsViewModel) {
    if (claims.isEmpty()) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Filled.Shield, contentDescription = null, modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.primary)
                Text("No copyright claims", style = MaterialTheme.typography.titleMedium)
                Text("Your content is clear", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    } else {
        LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            items(claims, key = { it.id }) { claim ->
                ClaimCard(claim, onDispute = { viewModel.disputeClaim(claim.id) })
            }
        }
    }
}

@Composable
private fun ClaimCard(claim: CopyrightClaim, onDispute: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Warning, contentDescription = null, tint = when (claim.status) {
                    "active" -> MaterialTheme.colorScheme.error
                    "disputed" -> MaterialTheme.colorScheme.tertiary
                    else -> MaterialTheme.colorScheme.onSurfaceVariant
                }, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(8.dp))
                Text(claim.videoTitle, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
            }
            Spacer(Modifier.height(8.dp))
            Text("Claimed by: ${claim.claimantName}", style = MaterialTheme.typography.bodySmall)
            Text("Type: ${claim.contentType} • Action: ${claim.action}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("Match: ${claim.matchPercentage.toInt()}% • Status: ${claim.status}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (claim.status == "active") {
                Spacer(Modifier.height(8.dp))
                OutlinedButton(onClick = onDispute) { Text("Dispute") }
            }
        }
    }
}

@Composable
private fun DMCAList(notices: List<DMCANotice>, viewModel: RightsViewModel) {
    if (notices.isEmpty()) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Filled.Gavel, contentDescription = null, modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.primary)
                Text("No DMCA notices", style = MaterialTheme.typography.titleMedium)
                Text("No takedown requests", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    } else {
        LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            items(notices, key = { it.id }) { notice ->
                DMCACard(notice, onCounterNotify = { viewModel.counterNotifyDMCA(notice.id) })
            }
        }
    }
}

@Composable
private fun DMCACard(notice: DMCANotice, onCounterNotify: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(notice.videoTitle, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(4.dp))
            Text("Complainant: ${notice.complainantName}", style = MaterialTheme.typography.bodySmall)
            Text(notice.description, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 2)
            Text("Status: ${notice.status}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (notice.status == "pending" || notice.status == "removed") {
                Spacer(Modifier.height(8.dp))
                OutlinedButton(onClick = onCounterNotify) { Text("Counter-Notify") }
            }
        }
    }
}
