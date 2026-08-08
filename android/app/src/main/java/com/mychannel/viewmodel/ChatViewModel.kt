package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.database.ChildEventListener
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.FirebaseDatabase
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

data class ChatMessage(
    val id: String = "",
    val senderId: String = "",
    val senderName: String = "",
    val senderAvatar: String = "",
    val text: String = "",
    val createdAt: Long = 0L
)

data class Conversation(
    val id: String = "",
    val participantIds: List<String> = emptyList(),
    val participantNames: List<String> = emptyList(),
    val participantAvatars: List<String> = emptyList(),
    val lastMessage: String = "",
    val lastMessageAt: Long = 0L,
    val unreadCount: Int = 0
)

data class ChatUiState(
    val isLoading: Boolean = true,
    val conversations: List<Conversation> = emptyList(),
    val selectedConversation: Conversation? = null,
    val messages: List<ChatMessage> = emptyList(),
    val error: String? = null
)

@HiltViewModel
class ChatViewModel @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val realtimeDb: FirebaseDatabase,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(ChatUiState())
    val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()
    private var messageListener: ChildEventListener? = null

    init { loadConversations() }

    private fun loadConversations() {
        val userId = authRepository.currentUserId ?: run {
            _uiState.update { it.copy(isLoading = false, error = "Sign in required") }
            return
        }
        viewModelScope.launch {
            runCatching {
                val snap = firestore.collection("conversations")
                    .whereArrayContains("participantIds", userId)
                    .orderBy("lastMessageAt", Query.Direction.DESCENDING)
                    .limit(50)
                    .get().await()
                snap.documents.mapNotNull { doc ->
                    val d = doc.data ?: return@mapNotNull null
                    Conversation(
                        id = doc.id,
                        participantIds = (d["participantIds"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
                        participantNames = (d["participantNames"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
                        participantAvatars = (d["participantAvatars"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
                        lastMessage = d["lastMessage"] as? String ?: "",
                        lastMessageAt = when (val ts = d["lastMessageAt"]) {
                            is com.google.firebase.Timestamp -> ts.toDate().time
                            is Long -> ts
                            else -> 0L
                        }
                    )
                }
            }.onSuccess { convos ->
                _uiState.update { it.copy(isLoading = false, conversations = convos) }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun selectConversation(convo: Conversation) {
        _uiState.update { it.copy(selectedConversation = convo, messages = emptyList()) }
        listenToMessages(convo.id)
    }

    fun clearSelection() {
        removeMessageListener()
        _uiState.update { it.copy(selectedConversation = null, messages = emptyList()) }
    }

    private fun listenToMessages(convoId: String) {
        removeMessageListener()
        val ref = realtimeDb.reference.child("conversations").child(convoId).child("messages")
        messageListener = object : ChildEventListener {
            override fun onChildAdded(snapshot: DataSnapshot, previousChildName: String?) {
                val msg = snapshotToMessage(snapshot) ?: return
                _uiState.update { it.copy(messages = it.messages + msg) }
            }
            override fun onChildChanged(snapshot: DataSnapshot, previousChildName: String?) {}
            override fun onChildRemoved(snapshot: DataSnapshot) {}
            override fun onChildMoved(snapshot: DataSnapshot, previousChildName: String?) {}
            override fun onCancelled(error: DatabaseError) {}
        }
        ref.orderByChild("createdAt").limitToLast(100).addChildEventListener(messageListener!!)
    }

    fun sendMessage(text: String) {
        val convo = _uiState.value.selectedConversation ?: return
        val userId = authRepository.currentUserId ?: return
        val userName = authRepository.currentUserName ?: "User"
        val msg = mapOf(
            "senderId" to userId,
            "senderName" to userName,
            "text" to text.trim(),
            "createdAt" to com.google.firebase.database.ServerValue.TIMESTAMP
        )
        realtimeDb.reference.child("conversations").child(convo.id).child("messages").push().setValue(msg)
    }

    fun getOtherParticipantName(convo: Conversation): String {
        val userId = authRepository.currentUserId ?: return "User"
        val idx = convo.participantIds.indexOf(userId)
        val otherIdx = if (idx == 0) 1 else 0
        return convo.participantNames.getOrElse(otherIdx) { "User" }
    }

    fun getOtherParticipantAvatar(convo: Conversation): String {
        val userId = authRepository.currentUserId ?: return ""
        val idx = convo.participantIds.indexOf(userId)
        val otherIdx = if (idx == 0) 1 else 0
        return convo.participantAvatars.getOrElse(otherIdx) { "" }
    }

    private fun snapshotToMessage(snapshot: DataSnapshot): ChatMessage? {
        val value = snapshot.value as? Map<*, *> ?: return null
        return ChatMessage(
            id = snapshot.key ?: "",
            senderId = value["senderId"] as? String ?: "",
            senderName = value["senderName"] as? String ?: "",
            text = value["text"] as? String ?: "",
            createdAt = (value["createdAt"] as? Number)?.toLong() ?: 0L
        )
    }

    private fun removeMessageListener() {
        val convoId = _uiState.value.selectedConversation?.id ?: return
        messageListener?.let {
            realtimeDb.reference.child("conversations").child(convoId).child("messages").removeEventListener(it)
        }
        messageListener = null
    }

    override fun onCleared() {
        super.onCleared()
        removeMessageListener()
    }
}
