package com.mychannel.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavController
import com.mychannel.viewmodel.AuthViewModel

/**
 * Settings screen — playback, notifications, privacy, parental controls,
 * geographic restrictions, account management.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    navController: NavController,
    authViewModel: AuthViewModel = hiltViewModel()
) {
    // Persistent toggles — in production these would be backed by DataStore
    var autoplay by remember { mutableStateOf(true) }
    var hd by remember { mutableStateOf(false) }
    var notifyUploads by remember { mutableStateOf(true) }
    var notifyReplies by remember { mutableStateOf(true) }
    var privateHistory by remember { mutableStateOf(false) }
    var privateLikes by remember { mutableStateOf(true) }
    var parentalControls by remember { mutableStateOf(false) }
    var restrictedMode by remember { mutableStateOf(false) }
    var locationRestrictions by remember { mutableStateOf(false) }
    var backgroundPlay by remember { mutableStateOf(true) }

    // Account deletion — two-step confirmation (App Store / Google Play requirement).
    var showDeleteConfirm by remember { mutableStateOf(false) }
    var showDeleteFinal by remember { mutableStateOf(false) }
    var deleteConfirmText by remember { mutableStateOf("") }

    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text("Delete account?") },
            text = {
                Text(
                    "This permanently removes your account and all associated data — " +
                        "your videos, comments, profile, subscriptions, and playlists. " +
                        "This cannot be undone."
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteConfirm = false
                    deleteConfirmText = ""
                    showDeleteFinal = true
                }) {
                    Text("Continue", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) { Text("Cancel") }
            }
        )
    }

    if (showDeleteFinal) {
        AlertDialog(
            onDismissRequest = { showDeleteFinal = false },
            title = { Text("Final confirmation") },
            text = {
                Column {
                    Text("Type DELETE to permanently delete your account.")
                    OutlinedTextField(
                        value = deleteConfirmText,
                        onValueChange = { deleteConfirmText = it },
                        singleLine = true,
                        modifier = Modifier.padding(top = 12.dp)
                    )
                }
            },
            confirmButton = {
                TextButton(
                    enabled = deleteConfirmText.trim().equals("DELETE", ignoreCase = false),
                    onClick = {
                        showDeleteFinal = false
                        deleteConfirmText = ""
                        authViewModel.deleteAccount {
                            navController.navigate("home") {
                                popUpTo(0) { inclusive = true }
                            }
                        }
                    }
                ) {
                    Text("Delete account", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = {
                    showDeleteFinal = false
                    deleteConfirmText = ""
                }) { Text("Cancel") }
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(innerPadding),
            contentPadding = PaddingValues(bottom = 32.dp)
        ) {
            // Playback
            item { SectionHeader("Playback") }
            item { ToggleRow("Autoplay next video", autoplay) { autoplay = it } }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }
            item { ToggleRow("Always prefer HD quality", hd) { hd = it } }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }
            item { ToggleRow("Background play", backgroundPlay) { backgroundPlay = it } }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }

            // Notifications
            item { SectionHeader("Notifications") }
            item { ToggleRow("New uploads from subscriptions", notifyUploads) { notifyUploads = it } }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }
            item { ToggleRow("Replies to my comments", notifyReplies) { notifyReplies = it } }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }

            // Privacy
            item { SectionHeader("Privacy") }
            item { ToggleRow("Keep watch history private", privateHistory) { privateHistory = it } }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }
            item { ToggleRow("Keep liked videos private", privateLikes) { privateLikes = it } }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }

            // Parental Controls / Safety
            item { SectionHeader("Family & Safety") }
            item {
                ToggleRow(
                    label = "Parental controls",
                    sublabel = "Require a PIN to view age-restricted content",
                    checked = parentalControls
                ) { parentalControls = it }
            }
            item {
                NavigationRow("Kids Mode") {
                    navController.navigate("kids_mode")
                }
            }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }
            item {
                ToggleRow(
                    label = "Restricted Mode",
                    sublabel = "Hide potentially mature content",
                    checked = restrictedMode
                ) { restrictedMode = it }
            }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }

            // Geographic restrictions
            item { SectionHeader("Content & Region") }
            item {
                ToggleRow(
                    label = "Respect geographic restrictions",
                    sublabel = "Hide content unavailable in your region",
                    checked = locationRestrictions
                ) { locationRestrictions = it }
            }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }
            item {
                NavigationRow(
                    label = "Blocked content regions",
                    sublabel = "Manage per-creator regional blocks",
                    onClick = { navController.navigate("settings/geo_blocks") }
                )
            }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }

            // Account
            item { SectionHeader("Account") }
            item {
                NavigationRow("Edit profile", onClick = { navController.navigate(EDIT_PROFILE_ROUTE) })
            }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }
            item {
                NavigationRow("Downloads & storage", onClick = { navController.navigate(DOWNLOADS_ROUTE) })
            }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }
            item {
                NavigationRow("Switch Account", onClick = {
                    navController.navigate("account_switcher")
                })
            }
            item {
                NavigationRow("Sign out", onClick = {
                    authViewModel.signOut {
                        navController.navigate("home") {
                            popUpTo(0) { inclusive = true }
                        }
                    }
                })
            }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }
            item {
                NavigationRow(
                    label = "Delete account",
                    sublabel = "Permanently delete your account and data",
                    onClick = { showDeleteConfirm = true }
                )
            }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleSmall,
        fontWeight = FontWeight.Bold,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(start = 16.dp, top = 20.dp, bottom = 4.dp, end = 16.dp)
    )
}

@Composable
private fun ToggleRow(
    label: String,
    checked: Boolean,
    sublabel: String = "",
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Column(modifier = Modifier.weight(1f).padding(end = 16.dp)) {
            Text(label, style = MaterialTheme.typography.bodyMedium)
            if (sublabel.isNotBlank()) {
                Text(
                    sublabel,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
private fun NavigationRow(
    label: String,
    sublabel: String = "",
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(label, style = MaterialTheme.typography.bodyMedium)
            if (sublabel.isNotBlank()) {
                Text(
                    sublabel,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        Icon(
            Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}
