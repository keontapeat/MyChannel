package com.mychannel.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.navigation.NavController
import coil.compose.AsyncImage
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseUser
import com.google.firebase.firestore.FirebaseFirestore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import javax.inject.Inject

// MARK: - Data model

data class AccountProfile(
    val uid: String,
    val displayName: String,
    val email: String,
    val avatarUrl: String?,
    val isCurrentAccount: Boolean
)

// MARK: - ViewModel

@HiltViewModel
class AccountSwitcherViewModel @Inject constructor(
    private val firestore: FirebaseFirestore
) : ViewModel() {

    private val auth = FirebaseAuth.getInstance()

    private val _accounts = MutableStateFlow<List<AccountProfile>>(emptyList())
    val accounts: StateFlow<List<AccountProfile>> = _accounts.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    init { loadAccounts() }

    private fun loadAccounts() {
        // Firebase on Android only surfaces the currently signed-in user.
        // We store a local list of previously signed-in UIDs in Firestore
        // under the user's own doc so we can surface them in the switcher.
        val currentUser = auth.currentUser ?: return
        _isLoading.value = true
        viewModelScope.launch {
            try {
                val doc = firestore.collection("users").document(currentUser.uid)
                    .get().await()
                val linkedUids = (doc.get("linkedAccountUids") as? List<*>)
                    ?.filterIsInstance<String>() ?: emptyList()

                val profiles = mutableListOf<AccountProfile>()

                // Current account always first
                profiles.add(
                    AccountProfile(
                        uid = currentUser.uid,
                        displayName = currentUser.displayName ?: "Unknown",
                        email = currentUser.email ?: "",
                        avatarUrl = currentUser.photoUrl?.toString(),
                        isCurrentAccount = true
                    )
                )

                // Linked accounts
                for (uid in linkedUids.filter { it != currentUser.uid }) {
                    val profileDoc = runCatching {
                        firestore.collection("users").document(uid).get().await()
                    }.getOrNull() ?: continue
                    profiles.add(
                        AccountProfile(
                            uid = uid,
                            displayName = profileDoc.getString("displayName") ?: uid,
                            email = profileDoc.getString("email") ?: "",
                            avatarUrl = profileDoc.getString("avatarURL"),
                            isCurrentAccount = false
                        )
                    )
                }

                _accounts.value = profiles
            } catch (e: Exception) {
                // Fall back to just the current account
                _accounts.value = listOf(
                    AccountProfile(
                        uid = currentUser.uid,
                        displayName = currentUser.displayName ?: "Unknown",
                        email = currentUser.email ?: "",
                        avatarUrl = currentUser.photoUrl?.toString(),
                        isCurrentAccount = true
                    )
                )
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun removeAccount(uid: String) {
        val currentUser = auth.currentUser ?: return
        if (uid == currentUser.uid) return // Can't remove active account
        viewModelScope.launch {
            runCatching {
                val ref = firestore.collection("users").document(currentUser.uid)
                val doc = ref.get().await()
                val linked = (doc.get("linkedAccountUids") as? List<*>)
                    ?.filterIsInstance<String>()?.toMutableList() ?: mutableListOf()
                linked.remove(uid)
                ref.update("linkedAccountUids", linked).await()
            }
            _accounts.update { it.filter { acc -> acc.uid != uid } }
        }
    }
}

// MARK: - Screen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountSwitcherScreen(
    navController: NavController,
    viewModel: AccountSwitcherViewModel = hiltViewModel()
) {
    val accounts by viewModel.accounts.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Switch Account") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.Filled.ArrowBack, "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { /* Sign in with Google to add account */ }) {
                        Icon(Icons.Filled.PersonAdd, "Add account")
                    }
                }
            )
        }
    ) { padding ->
        if (isLoading) {
            Box(
                Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center
            ) { CircularProgressIndicator() }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(accounts, key = { it.uid }) { account ->
                    AccountRow(
                        account = account,
                        onRemove = { viewModel.removeAccount(account.uid) }
                    )
                }

                item {
                    Spacer(Modifier.height(8.dp))
                    OutlinedButton(
                        onClick = { /* Navigate to Google sign-in */ },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Icon(Icons.Filled.Add, contentDescription = null)
                        Spacer(Modifier.width(8.dp))
                        Text("Add account")
                    }
                }
            }
        }
    }
}

@Composable
private fun AccountRow(account: AccountProfile, onRemove: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = if (account.isCurrentAccount)
                MaterialTheme.colorScheme.primaryContainer
            else
                MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            if (account.avatarUrl != null) {
                AsyncImage(
                    model = account.avatarUrl,
                    contentDescription = null,
                    modifier = Modifier.size(48.dp).clip(CircleShape),
                    contentScale = ContentScale.Crop
                )
            } else {
                Surface(
                    modifier = Modifier.size(48.dp),
                    shape = CircleShape,
                    color = MaterialTheme.colorScheme.primary
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Text(
                            account.displayName.take(1).uppercase(),
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onPrimary,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }

            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        account.displayName,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    if (account.isCurrentAccount) {
                        Spacer(Modifier.width(6.dp))
                        Badge { Text("Active") }
                    }
                }
                Text(
                    account.email,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            if (!account.isCurrentAccount) {
                IconButton(onClick = onRemove) {
                    Icon(
                        Icons.Filled.Close,
                        contentDescription = "Remove account",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}
