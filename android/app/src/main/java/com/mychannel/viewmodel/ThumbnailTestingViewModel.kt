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

data class ThumbnailTest(
    val id: String = "",
    val videoId: String = "",
    val videoTitle: String = "",
    val status: String = "running", // running, completed, paused
    val variants: List<ThumbnailVariant> = emptyList(),
    val winnerId: String? = null,
    val startedAt: Long = 0L,
    val completedAt: Long? = null
)

data class ThumbnailVariant(
    val id: String = "",
    val imageUrl: String = "",
    val label: String = "", // A, B, C
    val impressions: Long = 0L,
    val clicks: Long = 0L,
    val ctr: Double = 0.0,
    val watchTime: Long = 0L // seconds
)

data class ThumbnailTestingUiState(
    val isLoading: Boolean = true,
    val tests: List<ThumbnailTest> = emptyList(),
    val error: String? = null
)

/**
 * ViewModel for Thumbnail A/B Testing.
 * YouTube parity: allows creators to test multiple thumbnails and pick winners.
 */
@HiltViewModel
class ThumbnailTestingViewModel @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(ThumbnailTestingUiState())
    val uiState: StateFlow<ThumbnailTestingUiState> = _uiState.asStateFlow()

    init {
        loadTests()
    }

    private fun loadTests() {
        val userId = authRepository.currentUserId ?: run {
            _uiState.update { it.copy(isLoading = false, error = "Sign in required") }
            return
        }
        viewModelScope.launch {
            runCatching {
                val snap = firestore.collection("creators").document(userId)
                    .collection("thumbnailTests")
                    .orderBy("startedAt", Query.Direction.DESCENDING)
                    .limit(20)
                    .get().await()
                snap.documents.mapNotNull { doc ->
                    val d = doc.data ?: return@mapNotNull null
                    val variantsRaw = (d["variants"] as? List<*>)?.filterIsInstance<Map<*, *>>() ?: emptyList()
                    val variants = variantsRaw.mapIndexed { idx, v ->
                        ThumbnailVariant(
                            id = v["id"] as? String ?: "variant_$idx",
                            imageUrl = v["imageUrl"] as? String ?: "",
                            label = v["label"] as? String ?: ('A' + idx).toString(),
                            impressions = (v["impressions"] as? Number)?.toLong() ?: 0L,
                            clicks = (v["clicks"] as? Number)?.toLong() ?: 0L,
                            ctr = (v["ctr"] as? Number)?.toDouble() ?: 0.0,
                            watchTime = (v["watchTime"] as? Number)?.toLong() ?: 0L
                        )
                    }
                    ThumbnailTest(
                        id = doc.id,
                        videoId = d["videoId"] as? String ?: "",
                        videoTitle = d["videoTitle"] as? String ?: "",
                        status = d["status"] as? String ?: "running",
                        variants = variants,
                        winnerId = d["winnerId"] as? String,
                        startedAt = when (val ts = d["startedAt"]) {
                            is com.google.firebase.Timestamp -> ts.toDate().time
                            is Long -> ts
                            else -> 0L
                        }
                    )
                }
            }.onSuccess { tests ->
                _uiState.update { it.copy(isLoading = false, tests = tests) }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun endTest(testId: String, winnerId: String) {
        val userId = authRepository.currentUserId ?: return
        _uiState.update { state ->
            state.copy(tests = state.tests.map { t ->
                if (t.id == testId) t.copy(status = "completed", winnerId = winnerId) else t
            })
        }
        viewModelScope.launch {
            runCatching {
                firestore.collection("creators").document(userId)
                    .collection("thumbnailTests").document(testId)
                    .update(mapOf("status" to "completed", "winnerId" to winnerId))
                    .await()
            }
        }
    }

    fun retry() { loadTests() }
}
