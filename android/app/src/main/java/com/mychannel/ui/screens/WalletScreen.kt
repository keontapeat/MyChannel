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
import com.mychannel.viewmodel.WalletTransaction
import com.mychannel.viewmodel.WalletViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WalletScreen(navController: NavController, viewModel: WalletViewModel = hiltViewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    Scaffold(topBar = { TopAppBar(title = { Text("Wallet") }, navigationIcon = { IconButton(onClick = { navController.popBackStack() }) { Icon(Icons.Filled.ArrowBack, "Back") } }) }) { innerPadding ->
        when {
            uiState.isLoading -> Box(Modifier.fillMaxSize().padding(innerPadding), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            uiState.error != null -> Box(Modifier.fillMaxSize().padding(innerPadding), contentAlignment = Alignment.Center) { Column(horizontalAlignment = Alignment.CenterHorizontally) { Text(uiState.error ?: "Error", color = MaterialTheme.colorScheme.error); Button(onClick = { viewModel.retry() }) { Text("Retry") } } }
            else -> LazyColumn(Modifier.fillMaxSize().padding(innerPadding), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                item {
                    Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)) {
                        Column(Modifier.padding(20.dp)) {
                            Text("Balance", style = MaterialTheme.typography.labelLarge)
                            Text("$${uiState.balanceCents / 100}.${(uiState.balanceCents % 100).toString().padStart(2, '0')}", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
                            Spacer(Modifier.height(12.dp))
                            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                                Column { Text("Pending", style = MaterialTheme.typography.labelSmall); Text("$${uiState.pendingPayoutCents / 100}", style = MaterialTheme.typography.titleMedium) }
                                Column { Text("Lifetime", style = MaterialTheme.typography.labelSmall); Text("$${uiState.lifetimeEarningsCents / 100}", style = MaterialTheme.typography.titleMedium) }
                            }
                        }
                    }
                }
                item { Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Button(onClick = { /* Deposit — routed through Cloud Function */ }, Modifier.weight(1f)) { Icon(Icons.Filled.Add, null, Modifier.size(16.dp)); Spacer(Modifier.width(4.dp)); Text("Deposit") }
                    OutlinedButton(onClick = { /* Withdraw — routed through Cloud Function */ }, Modifier.weight(1f)) { Icon(Icons.Filled.ArrowUpward, null, Modifier.size(16.dp)); Spacer(Modifier.width(4.dp)); Text("Withdraw") }
                } }
                item { Text("Transactions", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold) }
                if (uiState.transactions.isEmpty()) { item { Text("No transactions yet", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) } }
                items(uiState.transactions, key = { it.id }) { tx -> TransactionRow(tx) }
            }
        }
    }
}

@Composable
private fun TransactionRow(tx: WalletTransaction) {
    val isPositive = tx.type in listOf("deposit", "payout", "ad_revenue", "tip_received")
    Card(Modifier.fillMaxWidth()) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(if (isPositive) Icons.Filled.ArrowDownward else Icons.Filled.ArrowUpward, null, tint = if (isPositive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error, modifier = Modifier.size(24.dp))
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(tx.description.ifBlank { tx.type.replace("_", " ").replaceFirstChar { it.uppercase() } }, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold)
                Text(tx.status, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Text("${if (isPositive) "+" else "-"}$${tx.amountCents / 100}.${(tx.amountCents % 100).toString().padStart(2, '0')}", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = if (isPositive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error)
        }
    }
}
