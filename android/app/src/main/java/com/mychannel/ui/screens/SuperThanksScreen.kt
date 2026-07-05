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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import com.google.firebase.functions.FirebaseFunctions
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

/**
 * Super Thanks — one-time paid appreciation from viewers to creators.
 *
 * MONEY NOTE: actual payment flows through the Cloud Function `sendSuperThanks`
 * which creates an escrow transaction server-side. This screen only collects
 * the intent (amount + message) and calls the callable. Integer cents throughout.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SuperThanksScreen(
    videoId: String,
    creatorId: String,
    creatorName: String,
    navController: NavController
) {
    val amounts = listOf(2, 5, 10, 20, 50, 100)
    val amountColors = mapOf(
        2   to Color(0xFF1976D2),
        5   to Color(0xFF00838F),
        10  to Color(0xFF388E3C),
        20  to Color(0xFFF9A825),
        50  to Color(0xFFE65100),
        100 to Color(0xFFC62828)
    )

    var selectedAmount by remember { mutableIntStateOf(5) }
    var message by remember { mutableStateOf("") }
    var sending by remember { mutableStateOf(false) }
    var sent by remember { mutableStateOf(false) }
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Super Thanks") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            Spacer(Modifier.height(8.dp))

            if (sent) {
                // ── Success ──────────────────────────────────────────────────
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.padding(top = 48.dp)
                ) {
                    Text("🎉", style = MaterialTheme.typography.displayMedium)
                    Text(
                        "Super Thanks sent!",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        "You sent $$selectedAmount to $creatorName",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    if (message.isNotBlank()) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(
                                    amountColors[selectedAmount] ?: MaterialTheme.colorScheme.primary,
                                    RoundedCornerShape(16.dp)
                                )
                                .padding(16.dp)
                        ) {
                            Text(
                                text = message,
                                style = MaterialTheme.typography.bodyMedium,
                                color = Color.White
                            )
                        }
                    }
                    Button(onClick = { navController.popBackStack() }, modifier = Modifier.padding(top = 16.dp)) {
                        Text("Done")
                    }
                }
            } else {
                // ── Picker ───────────────────────────────────────────────────
                Text(
                    "Show appreciation for $creatorName",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                // Amount chips
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    contentPadding = PaddingValues(vertical = 4.dp)
                ) {
                    items(amounts) { amt ->
                        val isSelected = amt == selectedAmount
                        val color = amountColors[amt] ?: MaterialTheme.colorScheme.primary
                        Button(
                            onClick = { selectedAmount = amt },
                            colors = ButtonDefaults.buttonColors(
                                containerColor = if (isSelected) color else MaterialTheme.colorScheme.surfaceVariant,
                                contentColor = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface
                            ),
                            shape = RoundedCornerShape(50)
                        ) {
                            Text("$$amt", fontWeight = FontWeight.Bold)
                        }
                    }
                }

                // Message
                OutlinedTextField(
                    value = message,
                    onValueChange = { if (it.length <= 150) message = it },
                    label = { Text("Add a message (optional)") },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 3,
                    maxLines = 5,
                    shape = RoundedCornerShape(16.dp),
                    supportingText = { Text("${message.length}/150") }
                )

                // Live preview of Super Thanks bubble
                if (message.isNotBlank()) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(
                                amountColors[selectedAmount] ?: MaterialTheme.colorScheme.primary,
                                RoundedCornerShape(16.dp)
                            )
                            .padding(16.dp)
                    ) {
                        Column {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Icon(Icons.Filled.Favorite, contentDescription = null, tint = Color.White, modifier = Modifier.size(16.dp))
                                Text("$$selectedAmount Super Thanks", color = Color.White, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelLarge)
                            }
                            Spacer(Modifier.height(4.dp))
                            Text(message, color = Color.White, style = MaterialTheme.typography.bodyMedium)
                        }
                    }
                }

                Spacer(Modifier.weight(1f))

                // Send button
                Button(
                    onClick = {
                        sending = true
                        scope.launch {
                            runCatching {
                                // MONEY NOTE: integer cents, server-side compliance checks
                                val data = hashMapOf(
                                    "videoId" to videoId,
                                    "creatorId" to creatorId,
                                    "amountCents" to (selectedAmount * 100),
                                    "message" to message.trim()
                                )
                                FirebaseFunctions.getInstance()
                                    .getHttpsCallable("sendSuperThanks")
                                    .call(data)
                                    .await()
                            }.onSuccess {
                                sent = true
                            }.onFailure { e ->
                                snackbarHostState.showSnackbar(e.message ?: "Payment failed")
                            }
                            sending = false
                        }
                    },
                    modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp),
                    shape = RoundedCornerShape(50),
                    enabled = !sending
                ) {
                    if (sending) {
                        CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp, color = Color.White)
                    } else {
                        Text("Send $$selectedAmount Super Thanks", fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}
