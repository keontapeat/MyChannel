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
import com.mychannel.viewmodel.ReferralCode
import com.mychannel.viewmodel.ReferralsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReferralsScreen(navController: NavController, viewModel: ReferralsViewModel = hiltViewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    Scaffold(topBar = { TopAppBar(title = { Text("Referrals") }, navigationIcon = { IconButton(onClick = { navController.popBackStack() }) { Icon(Icons.Filled.ArrowBack, "Back") } }) }) { innerPadding ->
        when {
            uiState.isLoading -> Box(Modifier.fillMaxSize().padding(innerPadding), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            else -> LazyColumn(Modifier.fillMaxSize().padding(innerPadding), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                item {
                    Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)) {
                        Column(Modifier.padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("Total Referral Earnings", style = MaterialTheme.typography.labelLarge)
                            Text("$${uiState.totalEarningsCents / 100}.${(uiState.totalEarningsCents % 100).toString().padStart(2, '0')}", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                        }
                    }
                }
                item { Text("My Referral Codes", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold) }
                if (uiState.myCodes.isEmpty()) { item { Text("No referral codes yet. Share your link to start earning!", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) } }
                items(uiState.myCodes, key = { it.id }) { code -> ReferralCodeCard(code, viewModel) }
                item { Spacer(Modifier.height(8.dp)); Text("How It Works", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold) }
                item { HowItWorksCard() }
            }
        }
    }
}

@Composable
private fun ReferralCodeCard(code: ReferralCode, viewModel: ReferralsViewModel) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(code.code, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                FilledTonalButton(onClick = { /* Share intent with viewModel.shareCode(code) */ }) { Icon(Icons.Filled.Share, null, Modifier.size(16.dp)); Spacer(Modifier.width(4.dp)); Text("Share") }
            }
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Column { Text("Uses", style = MaterialTheme.typography.labelSmall); Text("${code.currentUses}", style = MaterialTheme.typography.titleSmall) }
                Column { Text("You earn", style = MaterialTheme.typography.labelSmall); Text("$${code.referrerBonusCents / 100}", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary) }
                Column { Text("Friend gets", style = MaterialTheme.typography.labelSmall); Text("$${code.refereeBonusCents / 100}", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary) }
            }
        }
    }
}

@Composable
private fun HowItWorksCard() {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            HowItWorksStep(1, "Share your code", "Send your unique referral code to friends")
            HowItWorksStep(2, "Friend signs up", "They create an account using your code")
            HowItWorksStep(3, "Both earn rewards", "You both get signup bonuses")
        }
    }
}

@Composable
private fun HowItWorksStep(number: Int, title: String, desc: String) {
    Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Surface(Modifier.size(24.dp), shape = androidx.compose.foundation.shape.CircleShape, color = MaterialTheme.colorScheme.primary) {
            Box(contentAlignment = Alignment.Center) { Text("$number", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onPrimary) }
        }
        Column { Text(title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold); Text(desc, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
    }
}
