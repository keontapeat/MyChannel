package com.mychannel.ui.screens.auth

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInHorizontally
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.google.firebase.firestore.FirebaseFirestore
import com.mychannel.domain.repository.AuthRepository
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

data class InterestCategory(
    val id: String,
    val title: String,
    val icon: String,
    val emoji: String
)

val INTEREST_CATEGORIES = listOf(
    InterestCategory("gaming", "Gaming", "sports_esports", "🎮"),
    InterestCategory("music", "Music", "music_note", "🎵"),
    InterestCategory("entertainment", "Entertainment", "movie", "🎬"),
    InterestCategory("education", "Education", "school", "📚"),
    InterestCategory("sports", "Sports", "fitness_center", "⚽"),
    InterestCategory("tech", "Technology", "computer", "💻"),
    InterestCategory("cooking", "Cooking", "restaurant", "🍳"),
    InterestCategory("fitness", "Fitness", "self_improvement", "💪"),
    InterestCategory("comedy", "Comedy", "emoji_emotions", "😂"),
    InterestCategory("science", "Science", "science", "🔬"),
    InterestCategory("travel", "Travel", "flight", "✈️"),
    InterestCategory("art", "Art & Design", "palette", "🎨"),
    InterestCategory("news", "News", "newspaper", "📰"),
    InterestCategory("fashion", "Fashion", "checkroom", "👗"),
    InterestCategory("crypto", "Crypto & Finance", "currency_bitcoin", "💰"),
    InterestCategory("cars", "Cars & Motors", "directions_car", "🚗"),
    InterestCategory("pets", "Pets & Animals", "pets", "🐕"),
    InterestCategory("diy", "DIY & Crafts", "build", "🔨"),
)

/**
 * Onboarding screen — shown after sign-up to capture user interests.
 * Seeds the recommendation engine for personalized home feed from day 1.
 * YouTube-style: "Pick topics you're interested in"
 */
@Composable
fun OnboardingScreen(
    authRepository: AuthRepository,
    firestore: FirebaseFirestore,
    onComplete: () -> Unit
) {
    var step by remember { mutableIntStateOf(0) }
    var selectedInterests by remember { mutableStateOf(setOf<String>()) }
    var saving by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    Scaffold { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(48.dp))

            when (step) {
                0 -> WelcomeStep(onNext = { step = 1 })
                1 -> InterestSelectionStep(
                    selectedInterests = selectedInterests,
                    onToggle = { id ->
                        selectedInterests = if (id in selectedInterests) {
                            selectedInterests - id
                        } else {
                            selectedInterests + id
                        }
                    },
                    onNext = { step = 2 }
                )
                2 -> {
                    // Save and complete
                    LaunchedEffect(Unit) {
                        saving = true
                        val userId = authRepository.currentUserId ?: ""
                        if (userId.isNotBlank()) {
                            runCatching {
                                firestore.collection("users").document(userId)
                                    .update(mapOf(
                                        "interests" to selectedInterests.toList(),
                                        "onboardingCompleted" to true
                                    )).await()
                            }
                        }
                        saving = false
                        onComplete()
                    }

                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            CircularProgressIndicator()
                            Spacer(Modifier.height(16.dp))
                            Text("Personalizing your feed...", style = MaterialTheme.typography.bodyLarge)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun WelcomeStep(onNext: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("🎬", style = MaterialTheme.typography.displayLarge)
        Spacer(Modifier.height(24.dp))
        Text(
            "Welcome to MyChannel",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(12.dp))
        Text(
            "The creator platform where you compete, earn, and grow.\nLet's personalize your experience.",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(Modifier.height(48.dp))
        Button(
            onClick = onNext,
            modifier = Modifier.fillMaxWidth().height(56.dp),
            shape = RoundedCornerShape(28.dp)
        ) {
            Text("Get Started", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun InterestSelectionStep(
    selectedInterests: Set<String>,
    onToggle: (String) -> Unit,
    onNext: () -> Unit
) {
    Column(modifier = Modifier.fillMaxSize()) {
        Text(
            "What are you into?",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold
        )
        Text(
            "Pick at least 3 topics to personalize your feed",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(Modifier.height(16.dp))

        LazyVerticalGrid(
            columns = GridCells.Fixed(3),
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(INTEREST_CATEGORIES, key = { it.id }) { category ->
                val selected = category.id in selectedInterests
                Surface(
                    onClick = { onToggle(category.id) },
                    shape = RoundedCornerShape(16.dp),
                    color = if (selected) MaterialTheme.colorScheme.primaryContainer
                    else MaterialTheme.colorScheme.surfaceVariant,
                    border = if (selected) androidx.compose.foundation.BorderStroke(
                        2.dp, MaterialTheme.colorScheme.primary
                    ) else null,
                    modifier = Modifier.aspectRatio(1f)
                ) {
                    Column(
                        modifier = Modifier.fillMaxSize().padding(8.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Text(category.emoji, style = MaterialTheme.typography.headlineMedium)
                        Spacer(Modifier.height(4.dp))
                        Text(
                            category.title,
                            style = MaterialTheme.typography.labelSmall,
                            textAlign = TextAlign.Center,
                            maxLines = 2
                        )
                        if (selected) {
                            Spacer(Modifier.height(2.dp))
                            Icon(
                                Icons.Filled.Check,
                                contentDescription = null,
                                modifier = Modifier.size(14.dp),
                                tint = MaterialTheme.colorScheme.primary
                            )
                        }
                    }
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        Button(
            onClick = onNext,
            enabled = selectedInterests.size >= 3,
            modifier = Modifier.fillMaxWidth().height(56.dp),
            shape = RoundedCornerShape(28.dp)
        ) {
            Text(
                if (selectedInterests.size < 3) "Pick ${3 - selectedInterests.size} more"
                else "Continue (${selectedInterests.size} selected)",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
        }

        Spacer(Modifier.height(16.dp))

        TextButton(onClick = onNext, modifier = Modifier.fillMaxWidth()) {
            Text("Skip for now", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        Spacer(Modifier.height(24.dp))
    }
}
