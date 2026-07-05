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

data class Premiere(
    val id: String = "",
    val title: String = "",
    val thumbnailUrl: String = "",
    val creatorId: String = "",
    val creatorName: String = "",
    val scheduledAtMs: Long = 0L,
    val isLive: Boolean = false,
    val hasReminder: Boolean = false,
    val viewerCount: Long = 0L
)

data class PremieresUiState(
    val isLoading: Boolean = true,
    val premieres: List<Premiere> = emptyList(),
    val error: String? = null
)

@HiltViewModel
class PremieresViewModel @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(PremieresUiState())
    val uiState: StateFlow<PremieresUiState> = _uiState.asStateFlow()

    init { loadPremieres() }

    private fun loadPremieres() {
        val uid = authRepository.currentUserId
        viewModelScope.launch {
            runCatching {
                // Load videos where isPremiere == true
                val snap = firestore.collection("videos")
                    .whereEqualTo("isPremiere", true)
                    .orderBy("scheduledAt", Query.Direction.ASCENDING)
                    .limit(50)
                    .get().await()

                // Load user's reminders if signed in
                val reminderIds = if (uid != null) {
                    firestore.collection("users").document(uid)
                        .collection("premiereReminders")
                        .get().await()
                        .documents.map { it.id }.toSet()
                } else emptySet()

                snap.documents.mapNotNull { doc ->
                    runCatching {
                        val d = doc.data ?: return@mapNotNull null
                        val scheduledRaw = d["scheduledAt"]
                        val scheduledMs = when (scheduledRaw) {
                            is com.google.firebase.Timestamp -> scheduledRaw.toDate().time
                            is Long -> scheduledRaw
                            else -> 0L
                        }
                        Premiere(
                            id = doc.id,
                            title = d["title"] as? String ?: "",
                            thumbnailUrl = d["thumbnailURL"] as? String ?: "",
                            creatorId = d["creatorId"] as? String ?: "",
                            creatorName = d["channelName"] as? String ?: d["creatorName"] as? String ?: "Creator",
                            scheduledAtMs = scheduledMs,
                            isLive = d["status"] == "live",
                            hasReminder = doc.id in reminderIds,
                            viewerCount = (d["viewerCount"] as? Long) ?: 0L
                        )
                    }.getOrNull()
                }
            }.onSuccess { premieres ->
                _uiState.update { it.copy(isLoading = false, premieres = premieres) }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun toggleReminder(premiereId: String, currentlySet: Boolean) {
        val uid = authRepository.currentUserId ?: return
        _uiState.update { state ->
            state.copy(premieres = state.premieres.map { p ->
                if (p.id == premiereId) p.copy(hasReminder = !currentlySet) else p
            })
        }
        viewModelScope.launch {
            runCatching {
                val ref = firestore.collection("users").document(uid)
                    .collection("premiereReminders").document(premiereId)
                if (currentlySet) ref.delete().await()
                else ref.set(mapOf("premiereId" to premiereId, "setAt" to com.google.firebase.firestore.FieldValue.serverTimestamp())).await()
            }
        }
    }
}
