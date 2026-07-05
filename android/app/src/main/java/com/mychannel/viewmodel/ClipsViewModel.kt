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

data class Clip(
    val id: String = "",
    val title: String = "",
    val thumbnailUrl: String = "",
    val sourceVideoId: String = "",
    val durationSeconds: Int = 30,
    val viewCount: Long = 0L,
    val creatorId: String = "",
    val createdAt: Long = 0L
)

data class ClipsUiState(
    val isLoading: Boolean = true,
    val clips: List<Clip> = emptyList(),
    val error: String? = null
)

@HiltViewModel
class ClipsViewModel @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val authRepository: AuthRepository
) : ViewModel() {
    private val _uiState = MutableStateFlow(ClipsUiState())
    val uiState: StateFlow<ClipsUiState> = _uiState.asStateFlow()

    init {
        loadClips(videoId = null)
    }

    fun loadClips(videoId: String?) {
        _uiState.update { it.copy(isLoading = true, error = null) }
        viewModelScope.launch {
            runCatching {
                var query: Query = firestore.collection("clips")
                    .orderBy("createdAt", Query.Direction.DESCENDING)
                    .limit(50)
                if (videoId != null) {
                    query = query.whereEqualTo("sourceVideoId", videoId)
                }
                query.get().await()
            }.onSuccess { snap ->
                val clips = snap.documents.mapNotNull { doc ->
                    runCatching {
                        Clip(
                            id = doc.id,
                            title = doc.getString("title") ?: "",
                            thumbnailUrl = doc.getString("thumbnailUrl") ?: "",
                            sourceVideoId = doc.getString("sourceVideoId") ?: "",
                            durationSeconds = (doc.getLong("durationSeconds") ?: 30L).toInt(),
                            viewCount = doc.getLong("viewCount") ?: 0L,
                            creatorId = doc.getString("creatorId") ?: "",
                            createdAt = doc.getLong("createdAt") ?: 0L
                        )
                    }.getOrNull()
                }
                _uiState.update { it.copy(isLoading = false, clips = clips) }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    /**
     * Creates a clip by writing a Firestore document in the `clips` collection.
     * A Cloud Function picks this up and extracts the actual video segment
     * server-side using FFmpeg. The Firestore doc is the source of truth;
     * the actual byte extraction happens asynchronously.
     */
    fun createClip(sourceVideoId: String, title: String, startSeconds: Int, endSeconds: Int) {
        val uid = authRepository.currentUserId ?: return
        viewModelScope.launch {
            runCatching {
                val durationSeconds = (endSeconds - startSeconds).coerceIn(1, 60)
                firestore.collection("clips").add(
                    hashMapOf(
                        "sourceVideoId" to sourceVideoId,
                        "title" to title.trim(),
                        "startSeconds" to startSeconds,
                        "endSeconds" to endSeconds,
                        "durationSeconds" to durationSeconds,
                        "creatorId" to uid,
                        "viewCount" to 0L,
                        "thumbnailUrl" to "",
                        "clipUrl" to "",
                        "status" to "processing",  // Cloud Function sets to "ready"
                        "createdAt" to com.google.firebase.firestore.FieldValue.serverTimestamp()
                    )
                ).await()
                // Reload the list after creating
                loadClips(sourceVideoId.ifBlank { null })
            }
        }
    }
}
