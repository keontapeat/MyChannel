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

data class CommunityPost(
    val id: String = "",
    val creatorId: String = "",
    val creatorName: String = "",
    val creatorAvatar: String = "",
    val text: String = "",
    val imageUrl: String = "",
    val likeCount: Long = 0L,
    val commentCount: Long = 0L,
    val isLiked: Boolean = false,
    val createdAt: Long = 0L
)

data class CommunityUiState(
    val isLoading: Boolean = true,
    val posts: List<CommunityPost> = emptyList(),
    val error: String? = null
)

@HiltViewModel
class CommunityViewModel @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(CommunityUiState())
    val uiState: StateFlow<CommunityUiState> = _uiState.asStateFlow()

    init {
        loadPosts()
    }

    private fun loadPosts() {
        viewModelScope.launch {
            runCatching {
                // Try camelCase collection first (written by web), fall back to snake_case
                val snap = firestore.collection("communityPosts")
                    .orderBy("createdAt", Query.Direction.DESCENDING)
                    .limit(50)
                    .get().await()

                snap.documents.mapNotNull { doc ->
                    runCatching {
                        val d = doc.data ?: return@mapNotNull null
                        val createdRaw = d["createdAt"]
                        val createdMs = when (createdRaw) {
                            is com.google.firebase.Timestamp -> createdRaw.toDate().time
                            is Long -> createdRaw
                            else -> 0L
                        }
                        CommunityPost(
                            id = doc.id,
                            creatorId = d["creatorId"] as? String ?: "",
                            creatorName = d["creatorName"] as? String ?: "Creator",
                            creatorAvatar = d["creatorAvatar"] as? String ?: "",
                            text = d["text"] as? String ?: "",
                            imageUrl = d["imageURL"] as? String ?: "",
                            likeCount = (d["likeCount"] as? Long) ?: 0L,
                            commentCount = (d["commentCount"] as? Long) ?: 0L,
                            isLiked = false,
                            createdAt = createdMs
                        )
                    }.getOrNull()
                }
            }.onSuccess { posts ->
                _uiState.update { it.copy(isLoading = false, posts = posts) }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun toggleLike(postId: String, currentlyLiked: Boolean) {
        val uid = authRepository.currentUserId ?: return
        val delta = if (currentlyLiked) -1L else 1L
        _uiState.update { state ->
            state.copy(posts = state.posts.map { post ->
                if (post.id == postId) post.copy(isLiked = !currentlyLiked, likeCount = post.likeCount + delta)
                else post
            })
        }
        viewModelScope.launch {
            runCatching {
                firestore.collection("communityPosts").document(postId)
                    .update("likeCount", com.google.firebase.firestore.FieldValue.increment(delta))
                    .await()
            }
        }
    }
}
