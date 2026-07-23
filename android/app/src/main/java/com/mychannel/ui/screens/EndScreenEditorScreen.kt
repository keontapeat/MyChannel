package com.mychannel.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Link
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.PlaylistPlay
import androidx.compose.material.icons.filled.Save
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.mychannel.domain.model.EndScreenElement
import com.mychannel.viewmodel.EndScreenViewModel
import kotlin.math.roundToInt

/**
 * End Screen & Cards Editor — YouTube Studio parity.
 * Drag-and-drop elements onto a canvas overlay over the video thumbnail.
 * Elements: video, playlist, subscribe, channel, link (max 4).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EndScreenEditorScreen(
    videoId: String,
    navController: NavController,
    viewModel: EndScreenViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("End Screen & Cards", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    TextButton(
                        onClick = { viewModel.save(); navController.popBackStack() },
                        enabled = !uiState.isSaving
                    ) {
                        if (uiState.isSaving) {
                            CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                        } else {
                            Icon(Icons.Filled.Save, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(4.dp))
                            Text("Save", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            )
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(innerPadding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Canvas preview
            item(key = "canvas") {
                EndScreenCanvas(
                    thumbnailUrl = uiState.thumbnailUrl,
                    elements = uiState.elements,
                    selectedId = uiState.selectedElementId,
                    onSelect = { viewModel.selectElement(it) },
                    onMove = { id, xPct, yPct -> viewModel.moveElement(id, xPct, yPct) }
                )
            }

            // Elements list
            item(key = "elements_header") {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        "Elements (${uiState.elements.size}/4)",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold
                    )
                    if (uiState.elements.isEmpty()) {
                        Text(
                            "Add up to 4 elements",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            items(uiState.elements, key = { it.id }) { element ->
                EndScreenElementCard(
                    element = element,
                    isSelected = uiState.selectedElementId == element.id,
                    onSelect = { viewModel.selectElement(element.id) },
                    onRemove = { viewModel.removeElement(element.id) },
                    onTitleChange = { viewModel.updateElementTitle(element.id, it) },
                    onTargetChange = { viewModel.updateElementTarget(element.id, it) }
                )
            }

            // Add element palette
            if (uiState.elements.size < 4) {
                item(key = "add_palette") {
                    Text(
                        "Add element",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(Modifier.height(8.dp))
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(EndScreenElementTypeUi.values()) { type ->
                            AddElementChip(type = type, onClick = { viewModel.addElement(type.id) })
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Canvas

@Composable
private fun EndScreenCanvas(
    thumbnailUrl: String,
    elements: List<com.mychannel.domain.model.EndScreenElement>,
    selectedId: String?,
    onSelect: (String) -> Unit,
    onMove: (String, Float, Float) -> Unit
) {
    var canvasSize by remember { mutableStateOf(IntSize.Zero) }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(16f / 9f)
            .clip(RoundedCornerShape(12.dp))
            .onSizeChanged { canvasSize = it }
    ) {
        AsyncImage(
            model = ImageRequest.Builder(LocalContext.current)
                .data(thumbnailUrl)
                .crossfade(true)
                .build(),
            contentDescription = "Video thumbnail",
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop
        )

        // Dark overlay for last 20s indicator
        Box(
            modifier = Modifier
                .fillMaxWidth(0.25f)
                .fillMaxSize()
                .align(Alignment.TopEnd)
                .background(Color.Black.copy(alpha = 0.35f))
        )

        // Element overlays
        elements.forEach { element ->
            val xPx = (element.xPct * canvasSize.width).roundToInt()
            val yPx = (element.yPct * canvasSize.height).roundToInt()
            val isSelected = element.id == selectedId

            Box(
                modifier = Modifier
                    .offset { IntOffset(xPx - 36, yPx - 22) }
                    .size(width = 72.dp, height = 44.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(Color.Black.copy(alpha = 0.72f))
                    .border(
                        width = if (isSelected) 2.dp else 1.dp,
                        color = if (isSelected) Color(0xFF3EA6FF) else Color.White.copy(alpha = 0.5f),
                        shape = RoundedCornerShape(8.dp)
                    )
                    .clickable { onSelect(element.id) }
                    .pointerInput(element.id, canvasSize) {
                        detectDragGestures { change, _ ->
                            if (canvasSize.width > 0 && canvasSize.height > 0) {
                                val newXPct = (change.position.x / canvasSize.width)
                                    .coerceIn(0f, 1f)
                                val newYPct = (change.position.y / canvasSize.height)
                                    .coerceIn(0f, 1f)
                                onMove(element.id, newXPct, newYPct)
                            }
                        }
                    },
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(2.dp)
                ) {
                    Icon(
                        imageVector = EndScreenElementTypeUi.forId(element.type).icon,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = EndScreenElementTypeUi.forId(element.type).label,
                        color = Color.White.copy(alpha = 0.9f),
                        fontSize = 8.sp,
                        maxLines = 1
                    )
                }
            }
        }
    }
}

// MARK: - Element card

@Composable
private fun EndScreenElementCard(
    element: com.mychannel.domain.model.EndScreenElement,
    isSelected: Boolean,
    onSelect: () -> Unit,
    onRemove: () -> Unit,
    onTitleChange: (String) -> Unit,
    onTargetChange: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    val typeUi = EndScreenElementTypeUi.forId(element.type)

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onSelect(); expanded = !expanded },
        shape = RoundedCornerShape(12.dp)
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Icon(typeUi.icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(20.dp))
                Text(
                    element.title.ifBlank { typeUi.label },
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier.weight(1f)
                )
                IconButton(onClick = onRemove, modifier = Modifier.size(32.dp)) {
                    Icon(Icons.Filled.Delete, contentDescription = "Remove", tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(18.dp))
                }
            }

            if (expanded) {
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = element.title,
                    onValueChange = onTitleChange,
                    label = { Text("Label (optional)") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                if (element.type != "subscribe") {
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(
                        value = element.targetId,
                        onValueChange = onTargetChange,
                        label = { Text(if (element.type == "link") "URL (https://…)" else "Video / Channel ID") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }
    }
}

// MARK: - Add element chip

@Composable
private fun AddElementChip(type: EndScreenElementTypeUi, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp)
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Add, contentDescription = null, modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.primary)
            Icon(type.icon, contentDescription = null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(type.label, style = MaterialTheme.typography.labelMedium)
        }
    }
}

// MARK: - Type enum (UI only)

enum class EndScreenElementTypeUi(val id: String, val label: String, val icon: ImageVector) {
    VIDEO("video", "Video", Icons.Filled.PlayArrow),
    PLAYLIST("playlist", "Playlist", Icons.Filled.PlaylistPlay),
    SUBSCRIBE("subscribe", "Subscribe", Icons.Filled.PersonAdd),
    CHANNEL("channel", "Channel", Icons.Filled.PersonAdd),
    LINK("link", "Link", Icons.Filled.Link);

    companion object {
        fun forId(id: String): EndScreenElementTypeUi =
            values().firstOrNull { it.id == id } ?: VIDEO
    }
}
