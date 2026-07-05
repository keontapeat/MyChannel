package com.mychannel.ui.screens.upload

import android.Manifest
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CloudUpload
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Movie
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import coil.compose.AsyncImage
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.isGranted
import com.google.accompanist.permissions.rememberPermissionState
import com.mychannel.services.UploadWorker
import com.mychannel.viewmodel.UploadStatus
import com.mychannel.viewmodel.UploadViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Upload screen (REQ-8.1, REQ-8.2, REQ-8.3, REQ-8.6).
 *
 * Lets a creator pick a video from the gallery, choose a thumbnail, fill in
 * metadata (title, description, tags, category, privacy), then kick off a
 * background [UploadWorker] with a live progress indicator and cancel control.
 *
 * The media-read permission (READ_MEDIA_VIDEO on Android 13+, otherwise
 * READ_EXTERNAL_STORAGE) is requested via Accompanist before the picker opens.
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalPermissionsApi::class)
@Composable
fun UploadScreen(
    navController: NavController,
    viewModel: UploadViewModel = hiltViewModel()
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // SDK-appropriate media-read permission (REQ-8.1).
    val mediaPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        Manifest.permission.READ_MEDIA_VIDEO
    } else {
        Manifest.permission.READ_EXTERNAL_STORAGE
    }
    val permissionState = rememberPermissionState(mediaPermission)

    val videoPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri: Uri? ->
        if (uri != null) {
            scope.launch {
                val durationSeconds = withContext(Dispatchers.IO) {
                    extractDurationSeconds(context, uri)
                }
                viewModel.selectVideo(uri, durationSeconds)
            }
        }
    }

    val thumbnailPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri: Uri? ->
        uri?.let { viewModel.selectThumbnail(it) }
    }

    fun launchVideoPicker() {
        if (permissionState.status.isGranted || Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // The system photo picker itself is permissionless; we still surface
            // the runtime permission for broader gallery access per spec.
            videoPicker.launch(
                PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.VideoOnly)
            )
        } else {
            permissionState.launchPermissionRequest()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Upload") },
                actions = {
                    TextButton(onClick = { navController.navigate(STUDIO_ROUTE) }) {
                        Text("Studio")
                    }
                }
            )
        }
    ) { padding ->
        when (val status = state.status) {
            is UploadStatus.Complete -> UploadCompleteContent(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                onUploadAnother = { viewModel.reset() },
                onGoToStudio = {
                    viewModel.reset()
                    navController.navigate(STUDIO_ROUTE)
                }
            )

            else -> UploadFormContent(
                modifier = Modifier.fillMaxSize().padding(padding),
                state = state,
                status = status,
                onPickVideo = ::launchVideoPicker,
                onPickThumbnail = {
                    thumbnailPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                },
                onTitleChange = viewModel::updateTitle,
                onDescriptionChange = viewModel::updateDescription,
                onTagsChange = viewModel::updateTags,
                onCategoryChange = viewModel::updateCategory,
                onPrivacyChange = viewModel::updatePrivacy,
                onAgeRestrictedChange = viewModel::updateAgeRestricted,
                onMadeForKidsChange = viewModel::updateMadeForKids,
                onIsPremiereChange = viewModel::updateIsPremiere,
                onScheduledAtChange = viewModel::updateScheduledAt,
                onStartUpload = viewModel::startUpload,
                onCancelUpload = viewModel::cancelUpload
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun UploadFormContent(
    modifier: Modifier,
    state: com.mychannel.viewmodel.UploadUiState,
    status: UploadStatus,
    onPickVideo: () -> Unit,
    onPickThumbnail: () -> Unit,
    onTitleChange: (String) -> Unit,
    onDescriptionChange: (String) -> Unit,
    onTagsChange: (String) -> Unit,
    onCategoryChange: (String) -> Unit,
    onPrivacyChange: (String) -> Unit,
    onAgeRestrictedChange: (Boolean) -> Unit,
    onMadeForKidsChange: (Boolean) -> Unit,
    onIsPremiereChange: (Boolean) -> Unit,
    onScheduledAtChange: (Long) -> Unit,
    onStartUpload: () -> Unit,
    onCancelUpload: () -> Unit
) {
    Column(
        modifier = modifier
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Video picker / preview
        VideoPickerCard(
            videoUri = state.videoUri,
            onClick = onPickVideo
        )

        // Thumbnail selector
        ThumbnailPickerRow(
            thumbnailUri = state.thumbnailUri,
            onClick = onPickThumbnail
        )

        OutlinedTextField(
            value = state.title,
            onValueChange = onTitleChange,
            label = { Text("Title") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )

        OutlinedTextField(
            value = state.description,
            onValueChange = onDescriptionChange,
            label = { Text("Description") },
            minLines = 3,
            modifier = Modifier.fillMaxWidth()
        )

        OutlinedTextField(
            value = state.tags,
            onValueChange = onTagsChange,
            label = { Text("Tags (comma separated)") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )

        CategoryDropdown(
            selected = state.category,
            onSelected = onCategoryChange
        )

        PrivacySelector(
            selected = state.privacy,
            onSelected = onPrivacyChange
        )

        AudienceSection(
            ageRestricted = state.ageRestricted,
            madeForKids = state.madeForKids,
            onAgeRestrictedChange = onAgeRestrictedChange,
            onMadeForKidsChange = onMadeForKidsChange
        )

        PremiereSection(
            isPremiere = state.isPremiere,
            scheduledAtMs = state.scheduledAtMs,
            onIsPremiereChange = onIsPremiereChange,
            onScheduledAtChange = onScheduledAtChange
        )

        // Progress / error / action area
        when (status) {
            is UploadStatus.Uploading -> UploadProgressSection(
                progress = status.progress,
                label = "Uploading… ${status.progress}%",
                onCancel = onCancelUpload
            )

            is UploadStatus.Processing -> ProcessingSection(onCancel = onCancelUpload)

            is UploadStatus.Error -> {
                Text(
                    text = status.message,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodyMedium
                )
                UploadButton(enabled = state.canStartUpload, onClick = onStartUpload)
            }

            else -> UploadButton(enabled = state.canStartUpload, onClick = onStartUpload)
        }

        Spacer(modifier = Modifier.height(8.dp))
    }
}

@Composable
private fun VideoPickerCard(videoUri: String?, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(16f / 9f)
            .clip(RoundedCornerShape(12.dp)),
        contentAlignment = Alignment.Center
    ) {
        if (videoUri != null) {
            AsyncImage(
                model = videoUri,
                contentDescription = "Selected video preview",
                modifier = Modifier.fillMaxSize()
            )
            OutlinedButton(
                onClick = onClick,
                modifier = Modifier.align(Alignment.BottomEnd).padding(8.dp)
            ) {
                Text("Change")
            }
        } else {
            OutlinedButton(onClick = onClick) {
                Icon(
                    imageVector = Icons.Filled.Movie,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.size(8.dp))
                Text("Select video")
            }
        }
    }
}

@Composable
private fun ThumbnailPickerRow(thumbnailUri: String?, onClick: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(width = 96.dp, height = 54.dp)
                .clip(RoundedCornerShape(8.dp)),
            contentAlignment = Alignment.Center
        ) {
            if (thumbnailUri != null) {
                AsyncImage(
                    model = thumbnailUri,
                    contentDescription = "Selected thumbnail",
                    modifier = Modifier.fillMaxSize()
                )
            } else {
                Icon(
                    imageVector = Icons.Filled.Image,
                    contentDescription = null
                )
            }
        }
        OutlinedButton(onClick = onClick) {
            Text(if (thumbnailUri != null) "Change thumbnail" else "Add custom thumbnail")
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CategoryDropdown(selected: String, onSelected: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(
        expanded = expanded,
        onExpandedChange = { expanded = it }
    ) {
        OutlinedTextField(
            value = selected.ifBlank { "Select category" },
            onValueChange = {},
            readOnly = true,
            label = { Text("Category") },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            modifier = Modifier
                .fillMaxWidth()
                .menuAnchor()
        )
        androidx.compose.material3.ExposedDropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false }
        ) {
            CATEGORIES.forEach { category ->
                androidx.compose.material3.DropdownMenuItem(
                    text = { Text(category) },
                    onClick = {
                        onSelected(category)
                        expanded = false
                    }
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PrivacySelector(selected: String, onSelected: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Privacy", style = MaterialTheme.typography.titleSmall)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            PRIVACY_OPTIONS.forEach { (value, label) ->
                FilterChip(
                    selected = selected == value,
                    onClick = { onSelected(value) },
                    label = { Text(label) }
                )
            }
        }
    }
}

@Composable
private fun UploadButton(enabled: Boolean, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth()
    ) {
        Icon(imageVector = Icons.Filled.CloudUpload, contentDescription = null)
        Spacer(modifier = Modifier.size(8.dp))
        Text("Upload")
    }
}

@Composable
private fun UploadProgressSection(progress: Int, label: String, onCancel: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        LinearProgressIndicator(
            progress = progress / 100f,
            modifier = Modifier.fillMaxWidth()
        )
        OutlinedButton(onClick = onCancel, modifier = Modifier.fillMaxWidth()) {
            Text("Cancel upload")
        }
    }
}

@Composable
private fun ProcessingSection(onCancel: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            CircularProgressIndicator(modifier = Modifier.size(20.dp))
            Spacer(modifier = Modifier.size(12.dp))
            Text("Processing on our servers…", style = MaterialTheme.typography.bodyMedium)
        }
        OutlinedButton(onClick = onCancel, modifier = Modifier.fillMaxWidth()) {
            Text("Cancel")
        }
    }
}

@Composable
private fun UploadCompleteContent(
    modifier: Modifier,
    onUploadAnother: () -> Unit,
    onGoToStudio: () -> Unit
) {
    Column(
        modifier = modifier.padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Filled.CheckCircle,
            contentDescription = null,
            tint = Color(0xFF4CAF50),
            modifier = Modifier.size(64.dp)
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "Upload complete",
            style = MaterialTheme.typography.headlineSmall
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "Your video is now processing and will be ready shortly.",
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(24.dp))
        Button(onClick = onGoToStudio, modifier = Modifier.fillMaxWidth()) {
            Text("Go to Creator Studio")
        }
        Spacer(modifier = Modifier.height(8.dp))
        OutlinedButton(onClick = onUploadAnother, modifier = Modifier.fillMaxWidth()) {
            Text("Upload another")
        }
    }
}

/** Best-effort video duration extraction; returns 0 on any failure. */
private fun extractDurationSeconds(context: android.content.Context, uri: Uri): Long {
    val retriever = MediaMetadataRetriever()
    return try {
        retriever.setDataSource(context, uri)
        val millis = retriever
            .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            ?.toLongOrNull() ?: 0L
        millis / 1000
    } catch (e: Exception) {
        0L
    } finally {
        runCatching { retriever.release() }
    }
}

private const val STUDIO_ROUTE = "studio"

private val CATEGORIES = listOf(
    "Gaming", "Music", "Movies", "News", "Sports", "Education", "Comedy", "Tech", "Other"
)

private val PRIVACY_OPTIONS = listOf(
    UploadWorker.PRIVACY_PUBLIC to "Public",
    UploadWorker.PRIVACY_UNLISTED to "Unlisted",
    UploadWorker.PRIVACY_PRIVATE to "Private"
)

@Composable
private fun AudienceSection(
    ageRestricted: Boolean,
    madeForKids: Boolean,
    onAgeRestrictedChange: (Boolean) -> Unit,
    onMadeForKidsChange: (Boolean) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Audience", style = MaterialTheme.typography.titleSmall)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text("Made for kids", style = MaterialTheme.typography.bodyMedium)
                Text("Disables personalization (COPPA)", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            androidx.compose.material3.Switch(
                checked = madeForKids,
                onCheckedChange = onMadeForKidsChange
            )
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text("Age-restrict (18+)", style = MaterialTheme.typography.bodyMedium)
                Text("Only viewers 18+ can watch", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            androidx.compose.material3.Switch(
                checked = ageRestricted,
                onCheckedChange = onAgeRestrictedChange
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PremiereSection(
    isPremiere: Boolean,
    scheduledAtMs: Long,
    onIsPremiereChange: (Boolean) -> Unit,
    onScheduledAtChange: (Long) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text("Schedule as Premiere", style = MaterialTheme.typography.bodyMedium)
                Text("Debut at a scheduled time with live chat", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            androidx.compose.material3.Switch(
                checked = isPremiere,
                onCheckedChange = onIsPremiereChange
            )
        }
        if (isPremiere) {
            // Simple date/time display — a full DateTimePicker would use
            // the Material3 DatePicker composable which requires more scaffolding.
            // Here we show the selected time or a prompt.
            val timeText = if (scheduledAtMs > 0) {
                java.text.SimpleDateFormat("MMM d, yyyy 'at' h:mm a", java.util.Locale.getDefault())
                    .format(java.util.Date(scheduledAtMs))
            } else "Tap to set premiere time"
            OutlinedTextField(
                value = timeText,
                onValueChange = {},
                readOnly = true,
                label = { Text("Premiere date & time") },
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}
