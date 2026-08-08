package com.mychannel.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.mychannel.viewmodel.ChatMessage
import com.mychannel.viewmodel.ChatViewModel
import com.mychannel.viewmodel.Conversation
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(navController: NavController, viewModel: ChatViewModel = hiltViewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    if (uiState.selectedConversation != null) {
        ConversationView(viewModel, onBack = { viewModel.clearSelection() })
    } else {
        Scaffold(topBar = { TopAppBar(title = { Text("Messages") }, navigationIcon = { IconButton(onClick = { navController.popBackStack() }) { Icon(Icons.Filled.ArrowBack, "Back") } }) }) { innerPadding ->
            when {
                uiState.isLoading -> Box(Modifier.fillMaxSize().padding(innerPadding), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                uiState.conversations.isEmpty() -> Box(Modifier.fillMaxSize().padding(innerPadding), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(Icons.Filled.Forum, null, Modifier.size(48.dp), tint = MaterialTheme.colorScheme.primary)
                        Text("No messages yet", style = MaterialTheme.typography.titleMedium)
                    }
                }
                else -> LazyColumn(Modifier.fillMaxSize().padding(innerPadding)) {
                    items(uiState.conversations, key = { it.id }) { convo ->
                        ConversationRow(convo, viewModel) { viewModel.selectConversation(convo) }
                    }
                }
            }
        }
    }
}

@Composable
private fun ConversationRow(convo: Conversation, viewModel: ChatViewModel, onClick: () -> Unit) {
    Surface(onClick = onClick) {
        Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            val avatar = viewModel.getOtherParticipantAvatar(convo)
            if (avatar.isNotBlank()) {
                AsyncImage(model = ImageRequest.Builder(LocalContext.current).data(avatar).crossfade(true).build(), contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.size(48.dp).clip(CircleShape))
            } else {
                Surface(Modifier.size(48.dp), shape = CircleShape, color = MaterialTheme.colorScheme.primaryContainer) { Box(contentAlignment = Alignment.Center) { Icon(Icons.Filled.Person, null) } }
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(viewModel.getOtherParticipantName(convo), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                Text(convo.lastMessage, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
            }
            if (convo.unreadCount > 0) { Badge { Text("${convo.unreadCount}") } }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ConversationView(viewModel: ChatViewModel, onBack: () -> Unit) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val convo = uiState.selectedConversation ?: return
    var messageText by remember { mutableStateOf("") }
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    LaunchedEffect(uiState.messages.size) {
        if (uiState.messages.isNotEmpty()) listState.animateScrollToItem(uiState.messages.lastIndex)
    }

    Scaffold(topBar = { TopAppBar(title = { Text(viewModel.getOtherParticipantName(convo)) }, navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Filled.ArrowBack, "Back") } }) },
        bottomBar = {
            Surface(tonalElevation = 4.dp) {
                Row(Modifier.fillMaxWidth().padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    OutlinedTextField(value = messageText, onValueChange = { messageText = it }, placeholder = { Text("Message…") }, modifier = Modifier.weight(1f), shape = RoundedCornerShape(24.dp), singleLine = true)
                    Spacer(Modifier.width(8.dp))
                    IconButton(onClick = { if (messageText.isNotBlank()) { viewModel.sendMessage(messageText); messageText = "" } }, enabled = messageText.isNotBlank()) { Icon(Icons.Filled.Send, "Send", tint = MaterialTheme.colorScheme.primary) }
                }
            }
        }
    ) { innerPadding ->
        LazyColumn(Modifier.fillMaxSize().padding(innerPadding).padding(horizontal = 16.dp), state = listState, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            items(uiState.messages, key = { it.id }) { msg ->
                val isMe = msg.senderId == (viewModel.uiState.value.selectedConversation?.participantIds?.firstOrNull() ?: "")
                MessageBubble(msg, isMe = !isMe) // flip logic: first participant is current user
            }
        }
    }
}

@Composable
private fun MessageBubble(msg: ChatMessage, isMe: Boolean) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = if (isMe) Arrangement.End else Arrangement.Start) {
        Surface(shape = RoundedCornerShape(16.dp, 16.dp, if (isMe) 4.dp else 16.dp, if (isMe) 16.dp else 4.dp), color = if (isMe) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant) {
            Text(msg.text, Modifier.padding(12.dp, 8.dp), color = if (isMe) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodyMedium)
        }
    }
}
