package com.mychannel.ui.screens

import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.mychannel.domain.model.ChampionshipDivision
import com.mychannel.domain.model.VSMatch
import com.mychannel.viewmodel.VSMatchViewModel

/**
 * VS Match / Gaming hub screen.
 *
 * Shows open challenges to accept and the current user's match history,
 * plus a "Create Challenge" flow. All money operations are routed through
 * Cloud Function callables via [VSMatchViewModel].
 *
 * MONEY NOTE: wager amounts are integer cents throughout. The compliance checks
 * (age 18+, KYC, terms, region, daily limits) are enforced server-side.
 * This screen only presents the UI; it never bypasses or replaces server checks.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VSMatchScreen(
    navController: NavController,
    viewModel: VSMatchViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    var showCreateDialog by remember { mutableStateOf(false) }
    var selectedTab by remember { mutableIntStateOf(0) }

    // Show snackbar on success or error
    LaunchedEffect(uiState.successMessage, uiState.error) {
        val msg = uiState.successMessage ?: uiState.error
        if (msg != null) {
            snackbarHostState.showSnackbar(msg)
            viewModel.consumeMessages()
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = { Text("VS Matches") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        },
        floatingActionButton = {
            Button(onClick = { showCreateDialog = true }) {
                Icon(Icons.Filled.EmojiEvents, contentDescription = null)
                Text("Challenge", modifier = Modifier.padding(start = 8.dp))
            }
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            TabRow(selectedTabIndex = selectedTab) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    text = { Text("Open (${uiState.openMatches.size})") }
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    text = { Text("My Matches") }
                )
            }

            when {
                uiState.isLoading -> Box(
                    Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) { CircularProgressIndicator() }

                selectedTab == 0 -> MatchList(
                    matches = uiState.openMatches,
                    emptyMessage = "No open challenges right now.",
                    actionLabel = "Accept",
                    onAction = { match -> viewModel.acceptMatch(match.id) }
                )

                else -> MatchList(
                    matches = uiState.myMatches,
                    emptyMessage = "You haven't created any matches yet.",
                    actionLabel = null,
                    onAction = null
                )
            }
        }
    }

    if (showCreateDialog) {
        CreateChallengeDialog(
            isCreating = uiState.isCreating,
            onDismiss = { showCreateDialog = false },
            onCreate = { wagerCents ->
                showCreateDialog = false
                viewModel.createMatch(wagerCents)
            }
        )
    }
}

@Composable
private fun MatchList(
    matches: List<VSMatch>,
    emptyMessage: String,
    actionLabel: String?,
    onAction: ((VSMatch) -> Unit)?
) {
    if (matches.isEmpty()) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(emptyMessage, style = MaterialTheme.typography.bodyLarge)
        }
        return
    }
    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items(matches, key = { it.id }) { match ->
            VSMatchCard(match = match, actionLabel = actionLabel, onAction = onAction)
        }
    }
}

@Composable
private fun VSMatchCard(
    match: VSMatch,
    actionLabel: String?,
    onAction: ((VSMatch) -> Unit)?
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    DivisionBadge(division = match.championshipDivision)
                    Text(
                        text = match.challengerName,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold
                    )
                }
                Spacer(Modifier.height(4.dp))
                Text(
                    text = "Wager: ${formatCents(match.wagerAmount)}",
                    style = MaterialTheme.typography.bodyMedium
                )
                Text(
                    text = "Status: ${match.status.replaceFirstChar { it.uppercase() }}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            if (actionLabel != null && onAction != null && match.status == "open") {
                OutlinedButton(
                    onClick = { onAction(match) },
                    modifier = Modifier.padding(start = 8.dp)
                ) {
                    Text(actionLabel)
                }
            }
        }
    }
}

@Composable
private fun DivisionBadge(division: ChampionshipDivision) {
    val (label, color) = when (division) {
        ChampionshipDivision.LIGHTWEIGHT -> "LW" to Color(0xFF4CAF50)
        ChampionshipDivision.WELTERWEIGHT -> "WW" to Color(0xFF2196F3)
        ChampionshipDivision.MIDDLEWEIGHT -> "MW" to Color(0xFFFF9800)
        ChampionshipDivision.HEAVYWEIGHT -> "HW" to Color(0xFFF44336)
        ChampionshipDivision.SUPER_HEAVYWEIGHT -> "SHW" to Color(0xFF9C27B0)
        ChampionshipDivision.ULTRA_HEAVYWEIGHT -> "UHW" to Color(0xFFFFD700)
        ChampionshipDivision.UNKNOWN -> "?" to Color.Gray
    }
    Box(
        modifier = Modifier
            .background(color, RoundedCornerShape(4.dp))
            .padding(horizontal = 6.dp, vertical = 2.dp)
    ) {
        Text(text = label, style = MaterialTheme.typography.labelSmall, color = Color.White)
    }
}

@Composable
private fun CreateChallengeDialog(
    isCreating: Boolean,
    onDismiss: () -> Unit,
    onCreate: (wagerCents: Long) -> Unit
) {
    var dollarInput by remember { mutableStateOf("") }
    val wagerCents = dollarInput.toDoubleOrNull()?.let { (it * 100).toLong() } ?: 0L
    val division = ChampionshipDivision.fromWagerCents(wagerCents)
    val isValid = wagerCents >= 100L

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Create VS Challenge") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    text = "Set your wager amount. Minimum is \$1. All compliance checks run server-side.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                OutlinedTextField(
                    value = dollarInput,
                    onValueChange = { dollarInput = it.filter { c -> c.isDigit() || c == '.' } },
                    label = { Text("Wager (\$)") },
                    prefix = { Text("$") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                if (isValid) {
                    Text(
                        text = "Division: ${division.raw.replace('_', ' ').replaceFirstChar { it.uppercase() }}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }
        },
        confirmButton = {
            if (isCreating) {
                CircularProgressIndicator(modifier = Modifier.size(24.dp))
            } else {
                Button(
                    onClick = { if (isValid) onCreate(wagerCents) },
                    enabled = isValid
                ) { Text("Post Challenge") }
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}

/** Formats integer cents as a USD currency string for display only. */
private fun formatCents(cents: Long): String = "$%,.2f".format(cents / 100.0)
