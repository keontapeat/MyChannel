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
                val currentUserId = authRepository.currentUserId
                val snap = firestore.collection("communityPosts")
                    .orderBy("createdAt", Query.Direction.DESCENDING)
                    .limit(50)
                    .get().await()

                snap.documents.mapNotNull { document ->
                    runCatching {
                        val data = document.data ?: return@mapNotNull null
                        val createdRaw = data["createdAt"]
                        val createdMs = when (createdRaw) {
                            is com.google.firebase.Timestamp -> createdRaw.toDate().time
                            is Long -> createdRaw
                            else -> 0L
                        }
                        val isLiked = currentUserId?.let { userId ->
                            runCatching {
                                document.reference.collection("likes").document(userId)
                                    .get().await().exists()
                            }.getOrDefault(false)
                        } ?: false

                        CommunityPost(
                            id = document.id,
                            creatorId = data["creatorId"] as? String ?: "",
                            creatorName = data["creatorName"] as? String ?: "Creator",
                            creatorAvatar = data["creatorAvatar"] as? String ?: "",
                            text = data["text"] as? String ?: "",
                            imageUrl = data["imageURL"] as? String ?: "",
                            likeCount = (data["likeCount"] as? Number)?.toLong() ?: 0L,
                            commentCount = (data["commentCount"] as? Number)?.toLong() ?: 0L,
                            isLiked = isLiked,
                            createdAt = createdMs
                        )
                    }.getOrNull()
                }
            }.onSuccess { posts ->
                _uiState.update { it.copy(isLoading = false, posts = posts) }
            }.onFailure { error ->
                _uiState.update { it.copy(isLoading = false, error = error.message) }
            }
        }
    }

    /** Load posts for a specific creator channel — used by ProfileScreen community tab. */
    fun loadPostsForChannel(channelId: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            runCatching {
                val currentUserId = authRepository.currentUserId
                val snap = firestore.collection("community_posts")
                    .whereEqualTo("creatorId", channelId)
                    .orderBy("createdAt", Query.Direction.DESCENDING)
                    .limit(50)
                    .get().await()

                snap.documents.mapNotNull { document ->
                    runCatching {
                        val data = document.data ?: return@mapNotNull null
                        val createdRaw = data["createdAt"]
                        val createdMs = when (createdRaw) {
                            is com.google.firebase.Timestamp -> createdRaw.toDate().time
                            is Long -> createdRaw
                            else -> 0L
                        }
                        val isLiked = currentUserId?.let { userId ->
                            runCatching {
                                document.reference.collection("likes").document(userId)
                                    .get().await().exists()
                            }.getOrDefault(false)
                        } ?: false
                        CommunityPost(
                            id = document.id,
                            creatorId = data["creatorId"] as? String ?: "",
                            creatorName = data["creatorName"] as? String ?: "",
                            creatorAvatar = data["creatorAvatar"] as? String ?: "",
                            text = data["content"] as? String ?: data["text"] as? String ?: "",
                            imageUrl = (data["imageURLs"] as? List<*>)?.firstOrNull() as? String
                                ?: data["imageURL"] as? String ?: "",
                            likeCount = (data["likeCount"] as? Number)?.toLong() ?: 0L,
                            commentCount = (data["commentCount"] as? Number)?.toLong() ?: 0L,
                            isLiked = isLiked,
                            createdAt = createdMs
                        )
                    }.getOrNull()
                }
            }.onSuccess { posts ->
                _uiState.update { it.copy(isLoading = false, posts = posts) }
            }.onFailure { error ->
                _uiState.update { it.copy(isLoading = false, error = error.message) }
            }
        }
    }

    /** Convenience toggle that looks up current liked state from local state. */
    fun toggleLike(postId: String) {
        val post = _uiState.value.posts.find { it.id == postId } ?: return
        toggleLike(postId, post.isLiked)
    }

    fun toggleLike(postId: String, currentlyLiked: Boolean) {
        val userId = authRepository.currentUserId ?: return
        val nextLiked = !currentlyLiked
        val delta = if (nextLiked) 1L else -1L
        _uiState.update { state ->
            state.copy(posts = state.posts.map { post ->
                if (post.id == postId) {
                    post.copy(
                        isLiked = nextLiked,
                        likeCount = (post.likeCount + delta).coerceAtLeast(0L)
                    )
                } else {
                    post
                }
            })
        }

        viewModelScope.launch {
            val likeRef = firestore.collection("communityPosts").document(postId)
                .collection("likes").document(userId)
            runCatching {
                if (nextLiked) {
                    likeRef.set(mapOf(
                        "userId" to userId,
                        "likedAt" to com.google.firebase.firestore.FieldValue.serverTimestamp()
                    )).await()
                } else {
                    likeRef.delete().await()
                }
            }.onFailure { error ->
                _uiState.update { state ->
                    state.copy(
                        posts = state.posts.map { post ->
                            if (post.id == postId && post.isLiked == nextLiked) {
                                post.copy(
                                    isLiked = currentlyLiked,
                                    likeCount = (post.likeCount - delta).coerceAtLeast(0L)
                                )
                            } else {
                                post
                            }
                        },
                        error = error.message
                    )
                }
            }
        }
    }
}
