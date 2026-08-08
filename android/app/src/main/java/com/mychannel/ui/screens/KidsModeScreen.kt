package com.mychannel.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.navigation.NavController
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import javax.inject.Inject

// MARK: - Data

data class KidsModeState(
    val isLoading: Boolean = true,
    val isEnabled: Boolean = false,
    val pinHash: String = "",
    val maxAgeRating: String = "G",
    val allowedCategories: List<String> = listOf("Education", "Kids", "Animation"),
    val error: String? = null,
    val saveSuccess: Boolean = false
)

// MARK: - ViewModel

@HiltViewModel
class KidsModeViewModel @Inject constructor(
    private val firestore: FirebaseFirestore
) : ViewModel() {

    private val uid = FirebaseAuth.getInstance().currentUser?.uid
    private val _state = MutableStateFlow(KidsModeState())
    val state: StateFlow<KidsModeState> = _state.asStateFlow()

    private val ALL_CATEGORIES = listOf(
        "Education", "Kids", "Animation", "Science", "Music", "Sports", "Nature"
    )
    val allCategories = ALL_CATEGORIES

    init { load() }

    private fun load() {
        if (uid == null) { _state.update { it.copy(isLoading = false) }; return }
        viewModelScope.launch {
            try {
                val doc = firestore.collection("kids-mode").document(uid).get().await()
                _state.update {
                    it.copy(
                        isLoading = false,
                        isEnabled = doc.getBoolean("enabled") ?: false,
                        pinHash = doc.getString("pinHash") ?: "",
                        maxAgeRating = doc.getString("maxAgeRating") ?: "G",
                        allowedCategories = (doc.get("allowedCategories") as? List<*>)
                            ?.filterIsInstance<String>() ?: listOf("Education", "Kids", "Animation")
                    )
                }
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false) }
            }
        }
    }

    fun save(enabled: Boolean, pin: String, maxRating: String, categories: List<String>) {
        if (uid == null) return
        _state.update { it.copy(isLoading = true, error = null) }
        viewModelScope.launch {
            try {
                val pinHash = if (pin.isNotBlank()) pin.hashCode().toString() else _state.value.pinHash
                firestore.collection("kids-mode").document(uid).set(
                    mapOf(
                        "enabled" to enabled,
                        "pinHash" to pinHash,
                        "maxAgeRating" to maxRating,
                        "allowedCategories" to categories
                    )
                ).await()
                _state.update {
                    it.copy(
                        isLoading = false,
                        isEnabled = enabled,
                        pinHash = pinHash,
                        maxAgeRating = maxRating,
                        allowedCategories = categories,
                        saveSuccess = true
                    )
                }
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun verifyPin(input: String) = input.hashCode().toString() == _state.value.pinHash
    fun clearSuccess() = _state.update { it.copy(saveSuccess = false) }
}

// MARK: - Screen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun KidsModeScreen(
    navController: NavController,
    viewModel: KidsModeViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsState()
    var kidsModeEnabled by remember(state.isEnabled) { mutableStateOf(state.isEnabled) }
    var newPin by remember { mutableStateOf("") }
    var maxRating by remember(state.maxAgeRating) { mutableStateOf(state.maxAgeRating) }
    var selectedCategories by remember(state.allowedCategories) { mutableStateOf(state.allowedCategories.toMutableList()) }
    var showPinField by remember { mutableStateOf(false) }

    val ageRatings = listOf("G", "PG", "PG-13")

    LaunchedEffect(state.saveSuccess) {
        if (state.saveSuccess) {
            viewModel.clearSuccess()
            navController.popBackStack()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Kids Mode") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.Filled.ArrowBack, "Back")
                    }
                },
                actions = {
                    TextButton(onClick = {
                        viewModel.save(kidsModeEnabled, newPin, maxRating, selectedCategories)
                    }) { Text("Save") }
                }
            )
        }
    ) { padding ->
        if (state.isLoading) {
            Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
            return@Scaffold
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        Row(
                            Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text("Enable Kids Mode", fontWeight = FontWeight.SemiBold)
                                Text(
                                    "Filter content to age-appropriate videos",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            Switch(
                                checked = kidsModeEnabled,
                                onCheckedChange = { kidsModeEnabled = it }
                            )
                        }
                    }
                }
            }

            if (kidsModeEnabled) {
                item {
                    Card(Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Text("PIN Protection", fontWeight = FontWeight.SemiBold)

                            if (state.pinHash.isNotBlank() && !showPinField) {
                                Row(
                                    Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text("PIN is set", style = MaterialTheme.typography.bodyMedium)
                                    TextButton(onClick = { showPinField = true }) { Text("Change") }
                                }
                            } else {
                                OutlinedTextField(
                                    value = newPin,
                                    onValueChange = { if (it.length <= 6) newPin = it },
                                    label = { Text(if (state.pinHash.isBlank()) "Set PIN (4–6 digits)" else "New PIN") },
                                    visualTransformation = PasswordVisualTransformation(),
                                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                                    modifier = Modifier.fillMaxWidth(),
                                    singleLine = true
                                )
                            }
                        }
                    }
                }

                item {
                    Card(Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("Max Age Rating", fontWeight = FontWeight.SemiBold)
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                ageRatings.forEach { rating ->
                                    FilterChip(
                                        selected = maxRating == rating,
                                        onClick = { maxRating = rating },
                                        label = { Text(rating) }
                                    )
                                }
                            }
                        }
                    }
                }

                item {
                    Card(Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("Allowed Categories", fontWeight = FontWeight.SemiBold)
                            viewModel.allCategories.forEach { cat ->
                                Row(
                                    Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(cat, style = MaterialTheme.typography.bodyMedium)
                                    Checkbox(
                                        checked = selectedCategories.contains(cat),
                                        onCheckedChange = { checked ->
                                            selectedCategories = selectedCategories.toMutableList().apply {
                                                if (checked) add(cat) else remove(cat)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }

            state.error?.let { err ->
                item {
                    Text(err, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}
