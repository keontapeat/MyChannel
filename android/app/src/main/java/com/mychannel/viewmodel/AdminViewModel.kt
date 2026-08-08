package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import com.mychannel.domain.repository.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import javax.inject.Inject

data class ModerationItem(
    val id: String = "",
    val contentId: String = "",
    val contentType: String = "", // video, comment, channel, live
    val reportReason: String = "",
    val reporterName: String = "",
    val contentTitle: String = "",
    val contentCreator: String = "",
    val status: String = "pending", // pending, approved, removed, escalated
    val aiConfidence: Double = 0.0,
    val createdAt: Long = 0L
)

data class PlatformStats(
    val totalUsers: Long = 0L,
    val activeUsersToday: Long = 0L,
    val totalVideos: Long = 0L,
    val uploadsToday: Long = 0L,
    val totalReports: Long = 0L,
    val pendingReports: Long = 0L,
    val revenueTodayCents: Long = 0L
)

data class AdminUiState(
    val isLoading: Boolean = true,
    val isAdmin: Boolean = false,
    val stats: PlatformStats = PlatformStats(),
    val moderationQueue: List<ModerationItem> = emptyList(),
    val selectedTab: Int = 0, // 0=dashboard, 1=moderation, 2=users
    val error: String? = null
)

/**
 * ViewModel for Admin/Trust & Safety tools.
 * Platform moderation, user management, content review.
 */
@HiltViewModel
class AdminViewModel @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(AdminUiState())
    val uiState: StateFlow<AdminUiState> = _uiState.asStateFlow()

    init {
        checkAdminAndLoad()
    }

    private fun checkAdminAndLoad() {
        val userId = authRepository.currentUserId ?: run {
            _uiState.update { it.copy(isLoading = false, error = "Sign in required") }
            return
        }
        viewModelScope.launch {
            runCatching {
                val userDoc = firestore.collection("users").document(userId).get().await()
                val role = userDoc.getString("role") ?: ""
                role == "admin" || role == "moderator"
            }.onSuccess { isAdmin ->
                _uiState.update { it.copy(isAdmin = isAdmin) }
                if (isAdmin) {
                    loadStats()
                    loadModerationQueue()
                } else {
                    _uiState.update { it.copy(isLoading = false, error = "Admin access required") }
                }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    private fun loadStats() {
        viewModelScope.launch {
            runCatching {
                val statsDoc = firestore.collection("platform").document("stats").get().await()
                val d = statsDoc.data ?: emptyMap()
                PlatformStats(
                    totalUsers = (d["totalUsers"] as? Number)?.toLong() ?: 0L,
                    activeUsersToday = (d["activeUsersToday"] as? Number)?.toLong() ?: 0L,
                    totalVideos = (d["totalVideos"] as? Number)?.toLong() ?: 0L,
                    uploadsToday = (d["uploadsToday"] as? Number)?.toLong() ?: 0L,
                    totalReports = (d["totalReports"] as? Number)?.toLong() ?: 0L,
                    pendingReports = (d["pendingReports"] as? Number)?.toLong() ?: 0L,
                    revenueTodayCents = (d["revenueTodayCents"] as? Number)?.toLong() ?: 0L
                )
            }.onSuccess { stats ->
                _uiState.update { it.copy(stats = stats, isLoading = false) }
            }
        }
    }

    private fun loadModerationQueue() {
        viewModelScope.launch {
            runCatching {
                val snap = firestore.collection("moderationQueue")
                    .whereEqualTo("status", "pending")
                    .orderBy("createdAt", Query.Direction.ASCENDING)
                    .limit(50)
                    .get().await()
                snap.documents.mapNotNull { doc ->
                    val d = doc.data ?: return@mapNotNull null
                    ModerationItem(
                        id = doc.id,
                        contentId = d["contentId"] as? String ?: "",
                        contentType = d["contentType"] as? String ?: "",
                        reportReason = d["reportReason"] as? String ?: "",
                        reporterName = d["reporterName"] as? String ?: "",
                        contentTitle = d["contentTitle"] as? String ?: "",
                        contentCreator = d["contentCreator"] as? String ?: "",
                        status = d["status"] as? String ?: "pending",
                        aiConfidence = (d["aiConfidence"] as? Number)?.toDouble() ?: 0.0,
                        createdAt = when (val ts = d["createdAt"]) {
                            is com.google.firebase.Timestamp -> ts.toDate().time
                            is Long -> ts
                            else -> 0L
                        }
                    )
                }
            }.onSuccess { items ->
                _uiState.update { it.copy(moderationQueue = items) }
            }
        }
    }

    fun approveContent(itemId: String) { updateModerationStatus(itemId, "approved") }
    fun removeContent(itemId: String) { updateModerationStatus(itemId, "removed") }
    fun escalateContent(itemId: String) { updateModerationStatus(itemId, "escalated") }

    private fun updateModerationStatus(itemId: String, status: String) {
        _uiState.update { state ->
            state.copy(moderationQueue = state.moderationQueue.filter { it.id != itemId })
        }
        viewModelScope.launch {
            runCatching {
                firestore.collection("moderationQueue").document(itemId)
                    .update("status", status).await()
            }
        }
    }

    fun selectTab(index: Int) {
        _uiState.update { it.copy(selectedTab = index) }
    }

    fun retry() { checkAdminAndLoad() }
}
