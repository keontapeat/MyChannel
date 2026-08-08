package com.mychannel.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Analytics
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.VideoLibrary
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import android.widget.Toast
import androidx.navigation.NavController
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.mychannel.domain.model.Video
import com.mychannel.ui.components.ReportBlockOptionsSheet
import com.mychannel.ui.components.ReportReasonSheet
import com.mychannel.viewmodel.ProfileViewModel

/**
 * Profile / Channel screen — shows the signed-in user's own channel or a public
 * creator channel depending on whether [channelId] is null or the current user's id.
 *
 * Tabs: Videos | About | Community
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(
    navController: NavController,
    channelId: String? = null,
    viewModel: ProfileViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    var selectedTab by remember { mutableIntStateOf(0) }
    var showOptions by remember { mutableStateOf(false) }
    var showReportReasons by remember { mutableStateOf(false) }
    val tabs = listOf("Videos", "About", "Community")

    // Surface moderation feedback (report/block) as a toast, then clear it.
    LaunchedEffect(uiState.moderationMessage) {
        uiState.moderationMessage?.let { message ->
            Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
            viewModel.clearModerationMessage()
        }
    }

    if (showOptions) {
        ReportBlockOptionsSheet(
            reportLabel = "Report user",
            blockLabel = "Block user",
            onDismiss = { showOptions = false },
            onReport = {
                showOptions = false
                showReportReasons = true
            },
            onBlock = {
                showOptions = false
                viewModel.blockUser()
            }
        )
    }

    if (showReportReasons) {
        ReportReasonSheet(
            title = "Report user",
            onDismiss = { showReportReasons = false },
            onSelectReason = { reason ->
                showReportReasons = false
                viewModel.reportUser(reason)
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Channel") },
                actions = {
                    if (uiState.isOwnProfile) {
                        IconButton(onClick = { navController.navigate(STUDIO_ROUTE) }) {
                            Icon(Icons.Filled.Analytics, contentDescription = "Studio")
                        }
                        IconButton(onClick = { navController.navigate(SETTINGS_ROUTE) }) {
                            Icon(Icons.Filled.Settings, contentDescription = "Settings")
                        }
                    } else if (!uiState.isLoading && uiState.error == null) {
                        // Report/block a creator's channel (UGC safety).
                        IconButton(onClick = { showOptions = true }) {
                            Icon(Icons.Filled.MoreVert, contentDescription = "More options")
                        }
                    }
                }
            )
        }
    ) { innerPadding ->
        when {
            uiState.isLoading -> Box(
                Modifier.fillMaxSize().padding(innerPadding),
                contentAlignment = Alignment.Center
            ) { CircularProgressIndicator() }

            uiState.error != null -> Box(
                Modifier.fillMaxSize().padding(innerPadding),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(uiState.error ?: "Failed to load profile")
                    Button(
                        onClick = { viewModel.loadProfile(channelId) },
                        modifier = Modifier.padding(top = 12.dp)
                    ) { Text("Retry") }
                }
            }

            else -> LazyColumn(
                modifier = Modifier.fillMaxSize().padding(innerPadding),
                contentPadding = PaddingValues(bottom = 24.dp)
            ) {
                // Banner + avatar header
                item(key = "header") {
                    ProfileHeader(
                        uiState = uiState,
                        isOwn = uiState.isOwnProfile,
                        isSubscribed = uiState.isSubscribed,
                        onSubscribe = { viewModel.toggleSubscribe() },
                        onEditProfile = { navController.navigate(EDIT_PROFILE_ROUTE) }
                    )
                }

                // Tabs
                item(key = "tabs") {
                    TabRow(selectedTabIndex = selectedTab) {
                        tabs.forEachIndexed { i, label ->
                            Tab(
                                selected = selectedTab == i,
                                onClick = { selectedTab = i },
                                text = { Text(label) }
                            )
                        }
                    }
                }

                // Tab content
                when (selectedTab) {
                    0 -> {
                        // Videos grid
                        if (uiState.videos.isEmpty()) {
                            item(key = "no_videos") {
                                Box(
                                    Modifier.fillMaxWidth().padding(32.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                        Icon(
                                            Icons.Filled.VideoLibrary,
                                            contentDescription = null,
                                            modifier = Modifier.size(48.dp),
                                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                        Spacer(Modifier.height(8.dp))
                                        Text(
                                            "No videos yet",
                                            style = MaterialTheme.typography.bodyLarge,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }
                            }
                        } else {
                            items(uiState.videos, key = { "v_${it.id}" }) { video ->
                                com.mychannel.ui.components.VideoCard(
                                    video = video,
                                    onClick = { navController.navigate("video/${video.id}") },
                                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                                )
                            }
                        }
                    }

                    1 -> {
                        // About tab
                        item(key = "about") {
                            AboutSection(
                                bio = uiState.bio,
                                joinedDate = uiState.joinedDate,
                                totalViews = uiState.totalViews,
                                location = uiState.location,
                                links = uiState.links
                            )
                        }
                    }

                    2 -> {
                        // Community tab — load real Firestore posts for this channel
                        val communityViewModel: com.mychannel.viewmodel.CommunityViewModel = hiltViewModel(key = "profile_community")
                        val communityState by communityViewModel.uiState.collectAsStateWithLifecycle()
                        val channelOwnerId = channelId ?: viewModel.currentUserId
                        LaunchedEffect(channelOwnerId) {
                            if (channelOwnerId.isNotEmpty()) {
                                communityViewModel.loadPostsForChannel(channelOwnerId)
                            }
                        }
                        if (communityState.isLoading) {
                            item(key = "community_loading") {
                                Box(Modifier.fillMaxWidth().padding(40.dp), contentAlignment = Alignment.Center) {
                                    CircularProgressIndicator()
                                }
                            }
                        } else if (communityState.posts.isEmpty()) {
                            item(key = "community_empty") {
                                Box(Modifier.fillMaxWidth().padding(40.dp), contentAlignment = Alignment.Center) {
                                    Text(
                                        "No community posts yet",
                                        style = MaterialTheme.typography.bodyLarge,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        } else {
                            items(communityState.posts, key = { it.id }) { post ->
                                CommunityPostCard(
                                    post = post,
                                    onLike = { communityViewModel.toggleLike(post.id) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ProfileHeader(
    uiState: com.mychannel.viewmodel.ProfileUiState,
    isOwn: Boolean,
    isSubscribed: Boolean,
    onSubscribe: () -> Unit,
    onEditProfile: () -> Unit
) {
    Column {
        // Banner
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp)
                .background(MaterialTheme.colorScheme.primaryContainer)
        ) {
            if (uiState.bannerUrl.isNotBlank()) {
                AsyncImage(
                    model = ImageRequest.Builder(LocalContext.current)
                        .data(uiState.bannerUrl).crossfade(true).build(),
                    contentDescription = "Banner",
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop
                )
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Avatar
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            ) {
                AsyncImage(
                    model = ImageRequest.Builder(LocalContext.current)
                        .data(uiState.avatarUrl).crossfade(true).build(),
                    contentDescription = uiState.displayName,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop
                )
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = uiState.displayName,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "@${uiState.username}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = "${formatSubscribers(uiState.subscriberCount)} subscribers • ${uiState.videoCount} videos",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 2.dp)
                )
            }
        }

        // Action buttons
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            if (isOwn) {
                OutlinedButton(
                    onClick = onEditProfile,
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(Icons.Filled.Edit, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Edit profile")
                }
                OutlinedButton(
                    onClick = { /* manage content */ },
                    modifier = Modifier.weight(1f)
                ) {
                    Text("Manage")
                }
            } else {
                Button(
                    onClick = onSubscribe,
                    modifier = Modifier.weight(1f)
                ) {
                    Text(if (isSubscribed) "Subscribed" else "Subscribe")
                }
                OutlinedButton(onClick = { /* join / message */ }) {
                    Text("Message")
                }
            }
        }
    }
}

@Composable
private fun AboutSection(
    bio: String,
    joinedDate: String,
    totalViews: Long,
    location: String,
    links: List<String>
) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        if (bio.isNotBlank()) {
            Text(
                text = bio,
                style = MaterialTheme.typography.bodyMedium
            )
        }
        Text(
            text = "${formatLong(totalViews)} total views",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        if (joinedDate.isNotBlank()) {
            Text(
                text = "Joined $joinedDate",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        if (location.isNotBlank()) {
            Text(
                text = "📍 $location",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        links.forEach { link ->
            Text(
                text = link,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}

private fun formatSubscribers(count: Long): String = when {
    count >= 1_000_000L -> "%.1fM".format(count / 1_000_000.0)
    count >= 1_000L -> "%.1fK".format(count / 1_000.0)
    else -> count.toString()
}

private fun formatLong(n: Long): String = when {
    n >= 1_000_000L -> "%.1fM".format(n / 1_000_000.0)
    n >= 1_000L -> "%.1fK".format(n / 1_000.0)
    else -> n.toString()
}

const val SETTINGS_ROUTE = "settings"
const val EDIT_PROFILE_ROUTE = "edit_profile"
const val PROFILE_ROUTE = "profile"
const val PROFILE_CHANNEL_ROUTE = "profile/{channelId}"

// MARK: - Community Post Card
@Composable
private fun CommunityPostCard(
    post: com.mychannel.viewmodel.CommunityPost,
    onLike: () -> Unit
) {
    androidx.compose.material3.Card(
        modifier = androidx.compose.ui.Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp),
        shape = RoundedCornerShape(12.dp),
        colors = androidx.compose.material3.CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(Modifier.padding(16.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                AsyncImage(
                    model = ImageRequest.Builder(LocalContext.current)
                        .data(post.creatorAvatar.ifEmpty { null })
                        .crossfade(true)
                        .build(),
                    contentDescription = "Avatar",
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.size(36.dp).clip(CircleShape)
                )
                Column {
                    Text(
                        text = post.creatorName,
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold
                    )
                    if (post.createdAt > 0) {
                        val ago = android.text.format.DateUtils.getRelativeTimeSpanString(
                            post.createdAt,
                            System.currentTimeMillis(),
                            android.text.format.DateUtils.MINUTE_IN_MILLIS
                        ).toString()
                        Text(
                            text = ago,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
            Spacer(Modifier.height(10.dp))
            if (post.text.isNotEmpty()) {
                Text(
                    text = post.text,
                    style = MaterialTheme.typography.bodyMedium
                )
            }
            if (post.imageUrl.isNotEmpty()) {
                Spacer(Modifier.height(10.dp))
                AsyncImage(
                    model = ImageRequest.Builder(LocalContext.current)
                        .data(post.imageUrl)
                        .crossfade(true)
                        .build(),
                    contentDescription = "Post image",
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxWidth().height(180.dp).clip(RoundedCornerShape(8.dp))
                )
            }
            Spacer(Modifier.height(12.dp))
            Row(
                horizontalArrangement = Arrangement.spacedBy(20.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.clickable { onLike() }
                ) {
                    Icon(
                        imageVector = if (post.isLiked)
                            Icons.Filled.VideoLibrary
                        else
                            Icons.Filled.VideoLibrary,
                        contentDescription = "Like",
                        tint = if (post.isLiked) MaterialTheme.colorScheme.primary
                               else MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(Modifier.width(4.dp))
                    Text(
                        text = formatLong(post.likeCount),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Filled.MoreVert,
                        contentDescription = "Comments",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(Modifier.width(4.dp))
                    Text(
                        text = formatLong(post.commentCount),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}
