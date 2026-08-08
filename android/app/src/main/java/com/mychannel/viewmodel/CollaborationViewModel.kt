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

data class Collaboration(
    val id: String = "",
    val title: String = "",
    val description: String = "",
    val initiatorId: String = "",
    val initiatorName: String = "",
    val initiatorAvatar: String = "",
    val collaboratorIds: List<String> = emptyList(),
    val collaboratorNames: List<String> = emptyList(),
    val status: String = "pending", // pending, accepted, in-progress, completed, declined
    val type: String = "video", // video, live, series
    val revenueSplit: Map<String, Int> = emptyMap(), // userId -> percentage
    val createdAt: Long = 0L
)

data class CollaborationUiState(
    val isLoading: Boolean = true,
    val incomingRequests: List<Collaboration> = emptyList(),
    val activeCollaborations: List<Collaboration> = emptyList(),
    val pastCollaborations: List<Collaboration> = emptyList(),
    val selectedTab: Int = 0, // 0=active, 1=incoming, 2=past
    val error: String? = null
)

/**
 * ViewModel for Collaboration features.
 * YouTube parity: co-creator invitations, revenue splits, joint content.
 */
@HiltViewModel
class CollaborationViewModel @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(CollaborationUiState())
    val uiState: StateFlow<CollaborationUiState> = _uiState.asStateFlow()

    init {
        loadCollaborations()
    }

    private fun loadCollaborations() {
        val userId = authRepository.currentUserId ?: run {
            _uiState.update { it.copy(isLoading = false, error = "Sign in required") }
            return
        }
        viewModelScope.launch {
            runCatching {
                // Collaborations where user is initiator or collaborator
                val snap = firestore.collection("collaborations")
                    .whereArrayContains("participantIds", userId)
                    .orderBy("createdAt", Query.Direction.DESCENDING)
                    .limit(100)
                    .get().await()

                val all = snap.documents.mapNotNull { doc ->
                    val d = doc.data ?: return@mapNotNull null
                    Collaboration(
                        id = doc.id,
                        title = d["title"] as? String ?: "",
                        description = d["description"] as? String ?: "",
                        initiatorId = d["initiatorId"] as? String ?: "",
                        initiatorName = d["initiatorName"] as? String ?: "",
                        initiatorAvatar = d["initiatorAvatar"] as? String ?: "",
                        collaboratorIds = (d["collaboratorIds"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
                        collaboratorNames = (d["collaboratorNames"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
                        status = d["status"] as? String ?: "pending",
                        type = d["type"] as? String ?: "video",
                        createdAt = when (val ts = d["createdAt"]) {
                            is com.google.firebase.Timestamp -> ts.toDate().time
                            is Long -> ts
                            else -> 0L
                        }
                    )
                }

                val incoming = all.filter { it.status == "pending" && it.initiatorId != userId }
                val active = all.filter { it.status in listOf("accepted", "in-progress") }
                val past = all.filter { it.status in listOf("completed", "declined") }
                Triple(incoming, active, past)
            }.onSuccess { (incoming, active, past) ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        incomingRequests = incoming,
                        activeCollaborations = active,
                        pastCollaborations = past
                    )
                }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun acceptCollaboration(collabId: String) {
        updateStatus(collabId, "accepted")
    }

    fun declineCollaboration(collabId: String) {
        updateStatus(collabId, "declined")
    }

    private fun updateStatus(collabId: String, status: String) {
        viewModelScope.launch {
            runCatching {
                firestore.collection("collaborations").document(collabId)
                    .update("status", status).await()
            }.onSuccess { loadCollaborations() }
              .onFailure { e -> _uiState.update { it.copy(error = e.message) } }
        }
    }

    fun selectTab(index: Int) {
        _uiState.update { it.copy(selectedTab = index) }
    }

    fun retry() { loadCollaborations() }
}
