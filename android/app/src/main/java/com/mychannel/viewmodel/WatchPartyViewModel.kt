package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ValueEventListener
import com.google.firebase.firestore.FirebaseFirestore
import com.mychannel.domain.repository.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject

data class ChatMessage(
    val id: String,
    val username: String,
    val avatarUrl: String,
    val text: String,
    val isOwnMessage: Boolean,
    val timestamp: String
)

data class WatchPartyUiState(
    val isLoading: Boolean = true,
    val partyId: String = "",
    val videoUrl: String = "",
    val videoTitle: String = "",
    val isPlaying: Boolean = false,
    val seekPositionMs: Long = 0L,
    val guestCount: Int = 0,
    val isHost: Boolean = false,
    val messages: List<ChatMessage> = emptyList(),
    val error: String? = null
)

@HiltViewModel
class WatchPartyViewModel @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val rtdb: FirebaseDatabase,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(WatchPartyUiState())
    val uiState: StateFlow<WatchPartyUiState> = _uiState.asStateFlow()

    private var chatListener: ValueEventListener? = null
    private var stateListener: ValueEventListener? = null
    private var currentPartyId = ""

    fun joinParty(partyId: String) {
        currentPartyId = partyId
        val uid = authRepository.currentUserId ?: return
        viewModelScope.launch {
            runCatching {
                // Load party metadata from Firestore
                val partyDoc = firestore.collection("watch_parties").document(partyId).get().await()
                val videoId = partyDoc.getString("videoId") ?: ""
                val hostId = partyDoc.getString("hostId") ?: ""

                // Load video URL
                val videoDoc = if (videoId.isNotBlank())
                    firestore.collection("videos").document(videoId).get().await()
                else null

                val videoUrl = videoDoc?.getString("videoURL") ?: videoDoc?.getString("hlsURL") ?: ""
                val isHost = uid == hostId

                _uiState.update {
                    it.copy(
                        isLoading = false,
                        partyId = partyId,
                        videoUrl = videoUrl,
                        videoTitle = videoDoc?.getString("title") ?: "",
                        isHost = isHost
                    )
                }

                // Update presence
                rtdb.getReference("watch_parties/$partyId/guests/$uid").setValue(
                    mapOf("uid" to uid, "joinedAt" to System.currentTimeMillis())
                ).await()

                // Listen to playback state changes from RTDB
                val stateRef = rtdb.getReference("watch_parties/$partyId/state")
                stateListener = stateRef.addValueEventListener(object : ValueEventListener {
                    override fun onDataChange(snapshot: DataSnapshot) {
                        val playing = snapshot.child("isPlaying").getValue(Boolean::class.java) ?: false
                        val seekMs = snapshot.child("seekPositionMs").getValue(Long::class.java) ?: 0L
                        val guestCount = snapshot.child("guestCount").getValue(Int::class.java) ?: 1
                        _uiState.update { it.copy(isPlaying = playing, seekPositionMs = seekMs, guestCount = guestCount) }
                    }
                    override fun onCancelled(error: DatabaseError) {}
                })

                // Listen to chat messages
                val chatRef = rtdb.getReference("watch_parties/$partyId/chat")
                    .orderByChild("timestamp").limitToLast(100)
                chatListener = chatRef.addValueEventListener(object : ValueEventListener {
                    override fun onDataChange(snapshot: DataSnapshot) {
                        val messages = snapshot.children.mapNotNull { msg ->
                            runCatching {
                                ChatMessage(
                                    id = msg.key ?: return@mapNotNull null,
                                    username = msg.child("username").getValue(String::class.java) ?: "User",
                                    avatarUrl = msg.child("avatarUrl").getValue(String::class.java) ?: "",
                                    text = msg.child("text").getValue(String::class.java) ?: "",
                                    isOwnMessage = msg.child("uid").getValue(String::class.java) == uid,
                                    timestamp = formatTime(msg.child("timestamp").getValue(Long::class.java) ?: 0L)
                                )
                            }.getOrNull()
                        }
                        _uiState.update { it.copy(messages = messages) }
                    }
                    override fun onCancelled(error: DatabaseError) {}
                })
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun broadcastPlay(positionMs: Long) {
        if (!_uiState.value.isHost) return
        viewModelScope.launch {
            rtdb.getReference("watch_parties/$currentPartyId/state")
                .updateChildren(mapOf("isPlaying" to true, "seekPositionMs" to positionMs))
        }
        _uiState.update { it.copy(isPlaying = true) }
    }

    fun broadcastPause(positionMs: Long) {
        if (!_uiState.value.isHost) return
        viewModelScope.launch {
            rtdb.getReference("watch_parties/$currentPartyId/state")
                .updateChildren(mapOf("isPlaying" to false, "seekPositionMs" to positionMs))
        }
        _uiState.update { it.copy(isPlaying = false) }
    }

    fun sendMessage(text: String) {
        val uid = authRepository.currentUserId ?: return
        viewModelScope.launch {
            runCatching {
                rtdb.getReference("watch_parties/$currentPartyId/chat").push()
                    .setValue(
                        mapOf(
                            "uid" to uid,
                            "username" to (authRepository.currentUserDisplayName ?: "User"),
                            "avatarUrl" to (authRepository.currentUserAvatarUrl ?: ""),
                            "text" to text,
                            "timestamp" to System.currentTimeMillis()
                        )
                    ).await()
            }
        }
    }

    fun leaveParty() {
        val uid = authRepository.currentUserId ?: return
        viewModelScope.launch {
            runCatching {
                rtdb.getReference("watch_parties/$currentPartyId/guests/$uid").removeValue().await()
            }
        }
        // Remove listeners
        chatListener?.let {
            rtdb.getReference("watch_parties/$currentPartyId/chat").removeEventListener(it)
        }
        stateListener?.let {
            rtdb.getReference("watch_parties/$currentPartyId/state").removeEventListener(it)
        }
    }

    override fun onCleared() {
        super.onCleared()
        leaveParty()
    }

    private fun formatTime(timestamp: Long): String {
        if (timestamp == 0L) return ""
        return SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(timestamp))
    }
}
