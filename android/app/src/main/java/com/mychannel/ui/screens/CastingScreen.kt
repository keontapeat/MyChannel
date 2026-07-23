package com.mychannel.ui.screens

import android.content.Context
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Cast
import androidx.compose.material.icons.filled.CastConnected
import androidx.compose.material.icons.filled.Tv
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

data class CastDevice(
    val id: String,
    val name: String,
    val type: CastDeviceType,
    val isConnected: Boolean = false
)

enum class CastDeviceType(val label: String) {
    CHROMECAST("Chromecast"),
    ANDROID_TV("Android TV"),
    FIRE_TV("Fire TV"),
    SMART_TV("Smart TV")
}

/**
 * Casting bottom sheet — Chromecast / Android TV parity.
 * Uses MediaRouter2 API for device discovery.
 * The Google Cast SDK integration point is marked clearly for when the
 * cast-framework dependency is added to build.gradle.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CastingBottomSheet(
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var isScanning by remember { mutableStateOf(true) }
    var devices by remember { mutableStateOf<List<CastDevice>>(emptyList()) }
    var connectedId by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    // Simulate discovery — replace with CastContext.getSharedInstance().sessionManager
    // or MediaRouter2 callbacks when cast-framework is linked.
    LaunchedEffect(Unit) {
        delay(1500)
        isScanning = false
        // In production: populate from MediaRouter2.Callback.onRoutesAdded()
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 32.dp)
        ) {
            Text(
                "Play on",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)
            )

            when {
                isScanning -> {
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .padding(vertical = 32.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            CircularProgressIndicator()
                            Text(
                                "Looking for devices…",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }

                devices.isEmpty() -> {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(32.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Icon(
                            Icons.Filled.Wifi,
                            contentDescription = null,
                            modifier = Modifier.size(48.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            "No devices found",
                            style = MaterialTheme.typography.titleMedium
                        )
                        Text(
                            "Make sure your Chromecast or Smart TV is on the same Wi-Fi network.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                else -> {
                    LazyColumn(contentPadding = PaddingValues(horizontal = 16.dp)) {
                        items(devices, key = { it.id }) { device ->
                            CastDeviceRow(
                                device = device,
                                isConnected = connectedId == device.id,
                                onClick = {
                                    if (connectedId == device.id) {
                                        connectedId = null
                                        // CastContext.getSharedInstance().sessionManager.endCurrentSession(true)
                                    } else {
                                        connectedId = device.id
                                        // CastContext.getSharedInstance().sessionManager.startSession(routeInfo)
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CastDeviceRow(
    device: CastDevice,
    isConnected: Boolean,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = if (isConnected) Icons.Filled.CastConnected else Icons.Filled.Tv,
            contentDescription = null,
            modifier = Modifier.size(28.dp),
            tint = if (isConnected) MaterialTheme.colorScheme.primary
                   else MaterialTheme.colorScheme.onSurfaceVariant
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                device.name,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium
            )
            Text(
                if (isConnected) "Connected" else device.type.label,
                style = MaterialTheme.typography.bodySmall,
                color = if (isConnected) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        if (isConnected) {
            Icon(
                Icons.Filled.Cast,
                contentDescription = "Connected",
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(20.dp)
            )
        }
    }
}
