//
//  LiveChatView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct LiveChatView: View {
    let streamId: String
    let isStreamer: Bool
    @StateObject private var chatService = MockLiveChatService()
    @State private var messageText = ""
    @State private var showingUserList = false
    @State private var showingChatSettings = false
    @State private var showingSuperChatSheet = false
    @State private var autoScroll = true
    @State private var selectedMessage: ChatMessage?
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat Header
            chatHeader
            
            // Messages List
            chatMessagesList
            
            // Input Area
            chatInputArea
        }
        .background(Color(.systemBackground))
        .task {
            await connectToChat()
        }
        .onDisappear {
            Task {
                try? await chatService.disconnectFromChat()
            }
        }
        .sheet(isPresented: $showingUserList) {
            ChatUserListView(chatService: chatService)
        }
        .sheet(isPresented: $showingChatSettings) {
            ChatSettingsView(chatService: chatService, streamId: streamId)
        }
        .sheet(isPresented: $showingSuperChatSheet) {
            SuperChatView(streamId: streamId, chatService: chatService)
        }
        .sheet(item: $selectedMessage) { message in
            MessageOptionsView(message: message, chatService: chatService)
        }
    }
    
    private var chatHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Live Chat")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if chatService.isConnected {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("\(chatService.statistics.activeUsers) viewers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Connecting...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { showingUserList = true }) {
                    Image(systemName: "person.2")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                if isStreamer {
                    Button(action: { showingChatSettings = true }) {
                        Image(systemName: "gear")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
                
                Button(action: { autoScroll.toggle() }) {
                    Image(systemName: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                        .font(.title3)
                        .foregroundColor(autoScroll ? .blue : .secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4)),
            alignment: .bottom
        )
    }
    
    private var chatMessagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Pinned Message
                    if let pinnedMessage = chatService.messages.first(where: { $0.isPinned }) {
                        PinnedMessageView(message: pinnedMessage)
                            .padding(.horizontal)
                    }
                    
                    // Regular Messages
                    ForEach(chatService.messages.filter { !$0.isPinned }) { message in
                        ChatMessageView(
                            message: message,
                            isStreamer: isStreamer,
                            onTap: { selectedMessage = message },
                            onReply: { replyToMessage(message) }
                        )
                        .padding(.horizontal)
                        .id(message.id)
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: chatService.messages.count) { _, _ in
                if autoScroll, let lastMessage = chatService.messages.last {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var chatInputArea: some View {
        VStack(spacing: 0) {
            // Chat Settings Info
            if chatService.settings.isSlowMode || chatService.settings.isSubscriberOnly {
                chatSettingsInfo
            }
            
            // Input Field
            HStack(spacing: 12) {
                TextField("Say something...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(1...3)
                    .disabled(!chatService.isConnected)
                
                // Super Chat Button
                Button(action: { showingSuperChatSheet = true }) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                .disabled(!chatService.isConnected)
                
                // Send Button
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.title2)
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .blue)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !chatService.isConnected)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4)),
            alignment: .top
        )
    }
    
    private var chatSettingsInfo: some View {
        HStack {
            if chatService.settings.isSlowMode {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Slow mode: \(chatService.settings.slowModeDelay)s")
                        .font(.caption)
                }
                .foregroundColor(.orange)
            }
            
            if chatService.settings.isSubscriberOnly {
                HStack(spacing: 4) {
                    Image(systemName: "heart")
                        .font(.caption)
                    Text("Subscribers only")
                        .font(.caption)
                }
                .foregroundColor(.purple)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Actions
    private func connectToChat() async {
        do {
            try await chatService.connectToChat(streamId: streamId)
        } catch {
            print("Error connecting to chat: \(error)")
        }
    }
    
    private func sendMessage() {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        let message = ChatMessage(
            streamId: streamId,
            userId: "current-user-id",
            username: "CurrentUser",
            content: content
        )
        
        Task {
            do {
                try await chatService.sendMessage(message)
                await MainActor.run {
                    messageText = ""
                }
            } catch {
                print("Error sending message: \(error)")
            }
        }
    }
    
    private func replyToMessage(_ message: ChatMessage) {
        messageText = "@\(message.username) "
    }
}

// MARK: - Chat Message View
struct ChatMessageView: View {
    let message: ChatMessage
    let isStreamer: Bool
    let onTap: () -> Void
    let onReply: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 8) {
                // Avatar
                AsyncImage(url: URL(string: message.userAvatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Text(String(message.username.prefix(1)).uppercased())
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        )
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                
                // Message Content
                VStack(alignment: .leading, spacing: 4) {
                    // Header with badges and username
                    HStack(spacing: 4) {
                        // User badges
                        ForEach(message.badges.prefix(3)) { badge in
                            Image(systemName: badge.iconName)
                                .font(.caption2)
                                .foregroundColor(badge.badgeColor)
                        }
                        
                        Text(message.username)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(message.messageType.color)
                        
                        Text(message.timeString)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if message.superChatAmount != nil {
                            HStack(spacing: 2) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.caption2)
                                Text("Super Chat")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.green)
                        }
                        
                        Spacer()
                    }
                    
                    // Message text
                    Text(message.content)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Super Chat amount
                    if let amount = message.superChatAmount {
                        Text("$\(amount, specifier: "%.2f")")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                Group {
                    if message.isHighlighted {
                        Color.yellow.opacity(0.2)
                    } else if message.messageType == .superChat {
                        Color.green.opacity(0.1)
                    } else {
                        Color.clear
                    }
                }
            )
            .cornerRadius(8)
            .overlay(
                Group {
                    if message.isHighlighted {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.yellow, lineWidth: 2)
                    } else if message.messageType == .superChat {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green, lineWidth: 1)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pinned Message View
struct PinnedMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "pin.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                
                Text("Pinned by moderator")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                
                Spacer()
            }
            
            HStack(spacing: 8) {
                AsyncImage(url: URL(string: message.userAvatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color(.systemGray5))
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(message.username)
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Text(message.content)
                        .font(.subheadline)
                        .lineLimit(2)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    LiveChatView(streamId: "stream-1", isStreamer: false)
        .frame(height: 600)
}