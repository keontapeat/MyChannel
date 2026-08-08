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

data class CopyrightClaim(
    val id: String = "",
    val videoId: String = "",
    val videoTitle: String = "",
    val claimantName: String = "",
    val contentType: String = "", // audio, video, visual
    val status: String = "active", // active, disputed, resolved, released
    val action: String = "monetize", // monetize, block, track
    val matchPercentage: Double = 0.0,
    val createdAt: Long = 0L
)

data class DMCANotice(
    val id: String = "",
    val videoId: String = "",
    val videoTitle: String = "",
    val complainantName: String = "",
    val description: String = "",
    val status: String = "pending", // pending, removed, counter-notified, restored
    val createdAt: Long = 0L
)

data class RightsUiState(
    val isLoading: Boolean = true,
    val claims: List<CopyrightClaim> = emptyList(),
    val dmcaNotices: List<DMCANotice> = emptyList(),
    val selectedTab: Int = 0, // 0=claims, 1=dmca
    val error: String? = null
)

/**
 * ViewModel for Rights/DMCA management (YouTube Content ID equivalent).
 * Allows creators to view/dispute copyright claims and DMCA takedown notices.
 */
@HiltViewModel
class RightsViewModel @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(RightsUiState())
    val uiState: StateFlow<RightsUiState> = _uiState.asStateFlow()

    init {
        loadRightsData()
    }

    private fun loadRightsData() {
        val userId = authRepository.currentUserId ?: run {
            _uiState.update { it.copy(isLoading = false, error = "Sign in required") }
            return
        }
        viewModelScope.launch {
            runCatching {
                val claimsSnap = firestore.collection("creators").document(userId)
                    .collection("copyrightClaims")
                    .orderBy("createdAt", Query.Direction.DESCENDING)
                    .limit(50)
                    .get().await()
                val claims = claimsSnap.documents.mapNotNull { doc ->
                    val d = doc.data ?: return@mapNotNull null
                    CopyrightClaim(
                        id = doc.id,
                        videoId = d["videoId"] as? String ?: "",
                        videoTitle = d["videoTitle"] as? String ?: "",
                        claimantName = d["claimantName"] as? String ?: "",
                        contentType = d["contentType"] as? String ?: "",
                        status = d["status"] as? String ?: "active",
                        action = d["action"] as? String ?: "monetize",
                        matchPercentage = (d["matchPercentage"] as? Number)?.toDouble() ?: 0.0,
                        createdAt = when (val ts = d["createdAt"]) {
                            is com.google.firebase.Timestamp -> ts.toDate().time
                            is Long -> ts
                            else -> 0L
                        }
                    )
                }

                val dmcaSnap = firestore.collection("creators").document(userId)
                    .collection("dmcaNotices")
                    .orderBy("createdAt", Query.Direction.DESCENDING)
                    .limit(50)
                    .get().await()
                val notices = dmcaSnap.documents.mapNotNull { doc ->
                    val d = doc.data ?: return@mapNotNull null
                    DMCANotice(
                        id = doc.id,
                        videoId = d["videoId"] as? String ?: "",
                        videoTitle = d["videoTitle"] as? String ?: "",
                        complainantName = d["complainantName"] as? String ?: "",
                        description = d["description"] as? String ?: "",
                        status = d["status"] as? String ?: "pending",
                        createdAt = when (val ts = d["createdAt"]) {
                            is com.google.firebase.Timestamp -> ts.toDate().time
                            is Long -> ts
                            else -> 0L
                        }
                    )
                }
                Pair(claims, notices)
            }.onSuccess { (claims, notices) ->
                _uiState.update { it.copy(isLoading = false, claims = claims, dmcaNotices = notices) }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun selectTab(index: Int) {
        _uiState.update { it.copy(selectedTab = index) }
    }

    fun disputeClaim(claimId: String) {
        val userId = authRepository.currentUserId ?: return
        _uiState.update { state ->
            state.copy(claims = state.claims.map { c ->
                if (c.id == claimId) c.copy(status = "disputed") else c
            })
        }
        viewModelScope.launch {
            runCatching {
                firestore.collection("creators").document(userId)
                    .collection("copyrightClaims").document(claimId)
                    .update("status", "disputed").await()
            }
        }
    }

    fun counterNotifyDMCA(noticeId: String) {
        val userId = authRepository.currentUserId ?: return
        _uiState.update { state ->
            state.copy(dmcaNotices = state.dmcaNotices.map { n ->
                if (n.id == noticeId) n.copy(status = "counter-notified") else n
            })
        }
        viewModelScope.launch {
            runCatching {
                firestore.collection("creators").document(userId)
                    .collection("dmcaNotices").document(noticeId)
                    .update("status", "counter-notified").await()
            }
        }
    }

    fun retry() { loadRightsData() }
}
