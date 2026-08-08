package com.mychannel.ui.screens

import android.content.Context
import android.media.MediaRouter2
import android.media.RouteDiscoveryPreference
import android.media.RoutingSessionInfo
import android.os.Build
import androidx.annotation.RequiresApi
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
import androidx.compose.material.icons.filled.Cast
import androidx.compose.material.icons.filled.CastConnected
import androidx.compose.material.icons.filled.Tv
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
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
import java.util.concurrent.Executor

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
 * Casting bottom sheet using Android MediaRouter2 for real device discovery.
 * Works with Chromecast, Android TV, Fire TV, and any Cast-compatible device.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CastingBottomSheet(
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val context = LocalContext.current
    var isScanning by remember { mutableStateOf(true) }
    var devices by remember { mutableStateOf<List<CastDevice>>(emptyList()) }
    var connectedId by remember { mutableStateOf<String?>(null) }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        DisposableEffect(Unit) {
            val router = MediaRouter2.getInstance(context)
            val preference = RouteDiscoveryPreference.Builder(
                listOf(MediaRouter2.FEATURE_LIVE_VIDEO, MediaRouter2.FEATURE_REMOTE_PLAYBACK),
                true
            ).build()

            val callback = object : MediaRouter2.RouteCallback() {
                override fun onRoutesAdded(routes: List<MediaRouter2.RoutingController>) {}

                override fun onRoutesChanged(routes: List<MediaRouter2.RoutingController>) {}
            }

            val routeCallback = object : MediaRouter2.RouteCallback() {}

            val routesCallbackImpl = object : MediaRouter2.RouteCallback() {
                override fun onRoutesAdded(newRoutes: List<MediaRouter2.RoutingController>) {
                    val discovered = router.getRoutes().map { route ->
                        CastDevice(
                            id = route.id,
                            name = route.name.toString(),
                            type = when {
                                route.name.contains("Chromecast", ignoreCase = true) -> CastDeviceType.CHROMECAST
                                route.name.contains("TV", ignoreCase = true) -> CastDeviceType.ANDROID_TV
                                route.name.contains("Fire", ignoreCase = true) -> CastDeviceType.FIRE_TV
                                else -> CastDeviceType.SMART_TV
                            },
                            isConnected = router.controllers.any { it.id == route.id }
                        )
                    }
                    devices = discovered
                    isScanning = false
                }
            }

            val executor = context.mainExecutor as Executor
            router.registerRouteCallback(executor, routesCallbackImpl, preference)
            // Initial population
            val initial = router.getRoutes().map { route ->
                CastDevice(
                    id = route.id,
                    name = route.name.toString(),
                    type = when {
                        route.name.contains("Chromecast", ignoreCase = true) -> CastDeviceType.CHROMECAST
                        route.name.contains("TV", ignoreCase = true) -> CastDeviceType.ANDROID_TV
                        else -> CastDeviceType.SMART_TV
                    }
                )
            }
            devices = initial
            isScanning = false

            onDispose {
                router.unregisterRouteCallback(routesCallbackImpl)
            }
        }
    } else {
        // Pre-Android 11: show informational state
        isScanning = false
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
                                        // Disconnect: end the current Cast session
                                        connectedId = null
                                        try {
                                            val castContext = com.google.android.gms.cast.framework.CastContext.getSharedInstance(context)
                                            castContext.sessionManager.endCurrentSession(true)
                                        } catch (_: Exception) {
                                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                                val router = MediaRouter2.getInstance(context)
                                                router.controllers.firstOrNull { it.id == device.id }?.release()
                                            }
                                        }
                                    } else {
                                        // Connect: use Cast SDK route selection
                                        connectedId = device.id
                                        try {
                                            // Cast SDK handles device selection via the MediaRouter button;
                                            // MediaRouter2.transferTo is used as a fallback for non-Cast routes
                                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                                val router = MediaRouter2.getInstance(context)
                                                val route = router.getRoutes().firstOrNull { it.id == device.id }
                                                route?.let { router.transferTo(it) }
                                            }
                                        } catch (_: Exception) { /* ignore */ }
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
