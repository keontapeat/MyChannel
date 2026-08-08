package com.mychannel.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.mychannel.viewmodel.Course
import com.mychannel.viewmodel.UniversityViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UniversityScreen(navController: NavController, viewModel: UniversityViewModel = hiltViewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    Scaffold(topBar = {
        TopAppBar(title = { Text("MyChannel University") }, navigationIcon = {
            IconButton(onClick = { navController.popBackStack() }) { Icon(Icons.Filled.ArrowBack, "Back") }
        })
    }) { innerPadding ->
        Column(Modifier.fillMaxSize().padding(innerPadding)) {
            TabRow(selectedTabIndex = uiState.selectedTab) {
                Tab(uiState.selectedTab == 0, { viewModel.selectTab(0) }) { Text("Dashboard", Modifier.padding(16.dp)) }
                Tab(uiState.selectedTab == 1, { viewModel.selectTab(1) }) { Text("Courses", Modifier.padding(16.dp)) }
                Tab(uiState.selectedTab == 2, { viewModel.selectTab(2) }) { Text("Certificates", Modifier.padding(16.dp)) }
            }
            when {
                uiState.isLoading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                uiState.selectedTab == 0 -> LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    item {
                        Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)) {
                            Column(Modifier.padding(20.dp)) {
                                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                                    Column { Text("${uiState.progress.totalHours.toInt()}h", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold); Text("Learning", style = MaterialTheme.typography.labelSmall) }
                                    Column { Text("${uiState.progress.certificates}", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold); Text("Certs", style = MaterialTheme.typography.labelSmall) }
                                    Column { Text("${uiState.progress.currentStreak}d", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold); Text("Streak", style = MaterialTheme.typography.labelSmall) }
                                    Column { Text("#${uiState.progress.globalRank}", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold); Text("Rank", style = MaterialTheme.typography.labelSmall) }
                                }
                            }
                        }
                    }
                    item { Text("Featured Courses", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold) }
                    items(uiState.featuredCourses, key = { it.id }) { course -> CourseCard(course) }
                }
                uiState.selectedTab == 1 -> LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    if (uiState.featuredCourses.isEmpty()) { item { Box(Modifier.fillMaxWidth().padding(48.dp), contentAlignment = Alignment.Center) { Text("No courses available") } } }
                    items(uiState.featuredCourses, key = { it.id }) { course -> CourseCard(course) }
                }
                uiState.selectedTab == 2 -> LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    if (uiState.certificates.isEmpty()) { item { Box(Modifier.fillMaxWidth().padding(48.dp), contentAlignment = Alignment.Center) { Column(horizontalAlignment = Alignment.CenterHorizontally) { Icon(Icons.Filled.EmojiEvents, null, Modifier.size(48.dp), tint = MaterialTheme.colorScheme.primary); Text("No certificates yet", style = MaterialTheme.typography.titleMedium); Text("Complete courses to earn certificates", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) } } } }
                    items(uiState.certificates, key = { it.id }) { cert ->
                        Card(Modifier.fillMaxWidth()) { Column(Modifier.padding(16.dp)) { Text(cert.title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold); Text("Verification: ${cert.verificationId}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) } }
                    }
                }
            }
        }
    }
}

@Composable
private fun CourseCard(course: Course) {
    Card(Modifier.fillMaxWidth()) {
        Column {
            if (course.thumbnailUrl.isNotBlank()) { AsyncImage(model = ImageRequest.Builder(LocalContext.current).data(course.thumbnailUrl).crossfade(true).build(), contentDescription = course.title, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxWidth().height(140.dp).clip(RoundedCornerShape(topStart = 12.dp, topEnd = 12.dp))) }
            Column(Modifier.padding(12.dp)) {
                Text(course.title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                Text(course.creatorName, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Row(Modifier.padding(top = 4.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("${course.videoCount} videos", style = MaterialTheme.typography.labelSmall)
                    Text("${course.totalMinutes}m", style = MaterialTheme.typography.labelSmall)
                    if (course.rating > 0) { Text("★ ${"%.1f".format(course.rating)}", style = MaterialTheme.typography.labelSmall) }
                }
            }
        }
    }
}
