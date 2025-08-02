//
//  LiveChat.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import Combine

// MARK: - Chat Message Model
struct ChatMessage: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let streamId: String
    let userId: String
    let username: String
    let userAvatarURL: String?
    let content: String
    let messageType: MessageType
    let timestamp: Date
    let isHighlighted: Bool
    let isPinned: Bool
    let isModerated: Bool
    let badges: [UserBadge]
    let emotes: [ChatEmote]
    let superChatAmount: Double?
    let replyToMessageId: String?
    
    init(
        id: String = UUID().uuidString,
        streamId: String,
        userId: String,
        username: String,
        userAvatarURL: String? = nil,
        content: String,
        messageType: MessageType = .regular,
        timestamp: Date = Date(),
        isHighlighted: Bool = false,
        isPinned: Bool = false,
        isModerated: Bool = false,
        badges: [UserBadge] = [],
        emotes: [ChatEmote] = [],
        superChatAmount: Double? = nil,
        replyToMessageId: String? = nil
    ) {
        self.id = id
        self.streamId = streamId
        self.userId = userId
        self.username = username
        self.userAvatarURL = userAvatarURL
        self.content = content
        self.messageType = messageType
        self.timestamp = timestamp
        self.isHighlighted = isHighlighted
        self.isPinned = isPinned
        self.isModerated = isModerated
        self.badges = badges
        self.emotes = emotes
        self.superChatAmount = superChatAmount
        self.replyToMessageId = replyToMessageId
    }
    
    var isReply: Bool {
        replyToMessageId != nil
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }
    
    // MARK: - Equatable & Hashable
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Message Type Enum
enum MessageType: String, CaseIterable, Codable {
    case regular = "regular"
    case superChat = "super_chat"
    case membership = "membership"
    case system = "system"
    case moderator = "moderator"
    case announcement = "announcement"
    case poll = "poll"
    case celebration = "celebration"
    
    var color: Color {
        switch self {
        case .regular: return .primary
        case .superChat: return .green
        case .membership: return .purple
        case .system: return .secondary
        case .moderator: return .red
        case .announcement: return .blue
        case .poll: return .orange
        case .celebration: return .yellow
        }
    }
}

// MARK: - User Badge Model
struct UserBadge: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let iconName: String
    let color: String
    let description: String
    
    init(
        id: String = UUID().uuidString,
        name: String,
        iconName: String,
        color: String,
        description: String
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.color = color
        self.description = description
    }
    
    var badgeColor: Color {
        Color(hex: color) ?? .blue
    }
    
    // MARK: - Equatable
    static func == (lhs: UserBadge, rhs: UserBadge) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Chat Emote Model
struct ChatEmote: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let imageURL: String
    let isAnimated: Bool
    let isPremium: Bool
    
    init(
        id: String = UUID().uuidString,
        name: String,
        imageURL: String,
        isAnimated: Bool = false,
        isPremium: Bool = false
    ) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
        self.isAnimated = isAnimated
        self.isPremium = isPremium
    }
    
    // MARK: - Equatable
    static func == (lhs: ChatEmote, rhs: ChatEmote) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Chat User Model
struct ChatUser: Identifiable, Codable, Equatable {
    let id: String
    let username: String
    let displayName: String
    let avatarURL: String?
    let isSubscriber: Bool
    let isModerator: Bool
    let isVIP: Bool
    let isStreamer: Bool
    let joinedAt: Date
    let messageCount: Int
    let badges: [UserBadge]
    
    init(
        id: String = UUID().uuidString,
        username: String,
        displayName: String,
        avatarURL: String? = nil,
        isSubscriber: Bool = false,
        isModerator: Bool = false,
        isVIP: Bool = false,
        isStreamer: Bool = false,
        joinedAt: Date = Date(),
        messageCount: Int = 0,
        badges: [UserBadge] = []
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.isSubscriber = isSubscriber
        self.isModerator = isModerator
        self.isVIP = isVIP
        self.isStreamer = isStreamer
        self.joinedAt = joinedAt
        self.messageCount = messageCount
        self.badges = badges
    }
    
    var userBadges: [UserBadge] {
        var badges = self.badges
        
        if isStreamer {
            badges.append(UserBadge(name: "Streamer", iconName: "crown.fill", color: "FFD700", description: "Channel Owner"))
        }
        if isModerator {
            badges.append(UserBadge(name: "Moderator", iconName: "shield.fill", color: "FF4444", description: "Chat Moderator"))
        }
        if isVIP {
            badges.append(UserBadge(name: "VIP", iconName: "star.fill", color: "9146FF", description: "VIP Member"))
        }
        if isSubscriber {
            badges.append(UserBadge(name: "Subscriber", iconName: "heart.fill", color: "00FF7F", description: "Channel Subscriber"))
        }
        
        return badges
    }
    
    // MARK: - Equatable
    static func == (lhs: ChatUser, rhs: ChatUser) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Chat Statistics
struct ChatStatistics: Codable, Equatable {
    let activeUsers: Int
    let totalMessages: Int
    let messagesPerMinute: Double
    let topChatters: [String] // User IDs
    let popularEmotes: [String] // Emote names
    let superChatTotal: Double
    let superChatRevenue: Double
    let peakViewers: Int
    
    init(
        activeUsers: Int = 0,
        totalMessages: Int = 0,
        messagesPerMinute: Double = 0.0,
        topChatters: [String] = [],
        popularEmotes: [String] = [],
        superChatTotal: Double = 0.0,
        superChatRevenue: Double = 0.0,
        peakViewers: Int = 0
    ) {
        self.activeUsers = activeUsers
        self.totalMessages = totalMessages
        self.messagesPerMinute = messagesPerMinute
        self.topChatters = topChatters
        self.popularEmotes = popularEmotes
        self.superChatTotal = superChatTotal
        self.superChatRevenue = superChatRevenue
        self.peakViewers = peakViewers
    }
    
    // MARK: - Equatable
    static func == (lhs: ChatStatistics, rhs: ChatStatistics) -> Bool {
        lhs.activeUsers == rhs.activeUsers &&
        lhs.totalMessages == rhs.totalMessages
    }
}

// MARK: - Chat Settings
struct ChatSettings: Codable, Equatable {
    var isSlowMode: Bool
    var slowModeDelay: Int // seconds
    var isSubscriberOnly: Bool
    var isEmoteOnly: Bool
    var isFollowerOnly: Bool
    var followerOnlyDuration: Int // minutes
    var maxMessageLength: Int
    var isProfanityFilterEnabled: Bool
    var bannedWords: [String]
    var allowedEmotes: [String]
    var superChatEnabled: Bool
    var superChatMinAmount: Double
    var autoModerate: Bool
    var filterSpam: Bool
    var filterLinks: Bool
    var requireVerification: Bool
    
    init(
        isSlowMode: Bool = false,
        slowModeDelay: Int = 30,
        isSubscriberOnly: Bool = false,
        isEmoteOnly: Bool = false,
        isFollowerOnly: Bool = false,
        followerOnlyDuration: Int = 10,
        maxMessageLength: Int = 500,
        isProfanityFilterEnabled: Bool = true,
        bannedWords: [String] = [],
        allowedEmotes: [String] = [],
        superChatEnabled: Bool = true,
        superChatMinAmount: Double = 1.0,
        autoModerate: Bool = false,
        filterSpam: Bool = true,
        filterLinks: Bool = false,
        requireVerification: Bool = false
    ) {
        self.isSlowMode = isSlowMode
        self.slowModeDelay = slowModeDelay
        self.isSubscriberOnly = isSubscriberOnly
        self.isEmoteOnly = isEmoteOnly
        self.isFollowerOnly = isFollowerOnly
        self.followerOnlyDuration = followerOnlyDuration
        self.maxMessageLength = maxMessageLength
        self.isProfanityFilterEnabled = isProfanityFilterEnabled
        self.bannedWords = bannedWords
        self.allowedEmotes = allowedEmotes
        self.superChatEnabled = superChatEnabled
        self.superChatMinAmount = superChatMinAmount
        self.autoModerate = autoModerate
        self.filterSpam = filterSpam
        self.filterLinks = filterLinks
        self.requireVerification = requireVerification
    }
    
    static let defaultSettings = ChatSettings()
    
    // MARK: - Equatable
    static func == (lhs: ChatSettings, rhs: ChatSettings) -> Bool {
        lhs.isSlowMode == rhs.isSlowMode &&
        lhs.isSubscriberOnly == rhs.isSubscriberOnly &&
        lhs.isEmoteOnly == rhs.isEmoteOnly
    }
}

// MARK: - Live Chat Service Protocol
protocol LiveChatServiceProtocol {
    func connectToChat(streamId: String) async throws
    func disconnectFromChat() async throws
    func sendMessage(_ message: ChatMessage) async throws
    func sendSuperChat(streamId: String, message: String, amount: Double) async throws
    func getMessages(for streamId: String, limit: Int) async throws -> [ChatMessage]
    func getChatUsers(for streamId: String) async throws -> [ChatUser]
    func getChatStatistics(for streamId: String) async throws -> ChatStatistics
    func moderateMessage(messageId: String, action: ModerationAction) async throws
    func updateChatSettings(streamId: String, settings: ChatSettings) async throws
    func pinMessage(messageId: String) async throws
    func unpinMessage(messageId: String) async throws
}

// MARK: - Moderation Actions
enum ModerationAction: String, CaseIterable {
    case delete = "delete"
    case timeout = "timeout"
    case ban = "ban"
    case highlight = "highlight"
    case pin = "pin"
    case unpin = "unpin"
    
    var displayName: String {
        switch self {
        case .delete: return "Delete Message"
        case .timeout: return "Timeout User"
        case .ban: return "Ban User"
        case .highlight: return "Highlight Message"
        case .pin: return "Pin Message"
        case .unpin: return "Unpin Message"
        }
    }
    
    var iconName: String {
        switch self {
        case .delete: return "trash"
        case .timeout: return "clock"
        case .ban: return "xmark.circle"
        case .highlight: return "star"
        case .pin: return "pin"
        case .unpin: return "pin.slash"
        }
    }
}

// MARK: - Mock Live Chat Service
class MockLiveChatService: LiveChatServiceProtocol, ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var chatUsers: [ChatUser] = []
    @Published var statistics: ChatStatistics = ChatStatistics()
    @Published var settings: ChatSettings = ChatSettings()
    @Published var isConnected = false
    @Published var isLoading = false
    
    private var messageTimer: Timer?
    private var currentStreamId: String?
    
    init() {
        setupSampleData()
    }
    
    func connectToChat(streamId: String) async throws {
        isLoading = true
        currentStreamId = streamId
        
        // Simulate connection delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        await MainActor.run {
            self.isConnected = true
            self.isLoading = false
            self.messages = ChatMessage.sampleMessages
            self.chatUsers = ChatUser.sampleUsers
            self.statistics = ChatStatistics(
                activeUsers: 1234,
                totalMessages: 5678,
                messagesPerMinute: 45.2,
                topChatters: Array(ChatUser.sampleUsers.prefix(5).map { $0.id }),
                popularEmotes: ["😂", "❤️", "👏", "🔥", "😍"],
                superChatTotal: 256.50,
                superChatRevenue: 256.50,
                peakViewers: 2456
            )
        }
        
        // Start simulating new messages
        startMessageSimulation()
    }
    
    func disconnectFromChat() async throws {
        stopMessageSimulation()
        
        await MainActor.run {
            self.isConnected = false
            self.currentStreamId = nil
            self.messages.removeAll()
            self.chatUsers.removeAll()
        }
    }
    
    func sendMessage(_ message: ChatMessage) async throws {
        guard isConnected else {
            throw NSError(domain: "ChatError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Not connected to chat"])
        }
        
        await MainActor.run {
            self.messages.append(message)
            
            // Keep only last 200 messages for performance
            if self.messages.count > 200 {
                self.messages.removeFirst(self.messages.count - 200)
            }
        }
    }
    
    func sendSuperChat(streamId: String, message: String, amount: Double) async throws {
        let superChatMessage = ChatMessage(
            streamId: streamId,
            userId: "current-user-id",
            username: "CurrentUser",
            content: message,
            messageType: .superChat,
            isHighlighted: true,
            superChatAmount: amount
        )
        
        try await sendMessage(superChatMessage)
    }
    
    func getMessages(for streamId: String, limit: Int) async throws -> [ChatMessage] {
        return Array(messages.suffix(limit))
    }
    
    func getChatUsers(for streamId: String) async throws -> [ChatUser] {
        return chatUsers
    }
    
    func getChatStatistics(for streamId: String) async throws -> ChatStatistics {
        return statistics
    }
    
    func moderateMessage(messageId: String, action: ModerationAction) async throws {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        switch action {
        case .delete:
            await MainActor.run {
                messages.remove(at: index)
            }
        case .highlight:
            let highlightedMessage = ChatMessage(
                id: messages[index].id,
                streamId: messages[index].streamId,
                userId: messages[index].userId,
                username: messages[index].username,
                userAvatarURL: messages[index].userAvatarURL,
                content: messages[index].content,
                messageType: messages[index].messageType,
                timestamp: messages[index].timestamp,
                isHighlighted: true,
                isPinned: messages[index].isPinned,
                isModerated: messages[index].isModerated,
                badges: messages[index].badges,
                emotes: messages[index].emotes,
                superChatAmount: messages[index].superChatAmount,
                replyToMessageId: messages[index].replyToMessageId
            )
            await MainActor.run {
                messages[index] = highlightedMessage
            }
        case .pin:
            try await pinMessage(messageId: messageId)
        case .unpin:
            try await unpinMessage(messageId: messageId)
        default:
            break
        }
    }
    
    func updateChatSettings(streamId: String, settings: ChatSettings) async throws {
        await MainActor.run {
            self.settings = settings
        }
    }
    
    func pinMessage(messageId: String) async throws {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        // Unpin other messages first
        for i in messages.indices {
            if messages[i].isPinned {
                let unpinnedMessage = ChatMessage(
                    id: messages[i].id,
                    streamId: messages[i].streamId,
                    userId: messages[i].userId,
                    username: messages[i].username,
                    userAvatarURL: messages[i].userAvatarURL,
                    content: messages[i].content,
                    messageType: messages[i].messageType,
                    timestamp: messages[i].timestamp,
                    isHighlighted: messages[i].isHighlighted,
                    isPinned: false,
                    isModerated: messages[i].isModerated,
                    badges: messages[i].badges,
                    emotes: messages[i].emotes,
                    superChatAmount: messages[i].superChatAmount,
                    replyToMessageId: messages[i].replyToMessageId
                )
                messages[i] = unpinnedMessage
            }
        }
        
        // Pin the selected message
        let pinnedMessage = ChatMessage(
            id: messages[index].id,
            streamId: messages[index].streamId,
            userId: messages[index].userId,
            username: messages[index].username,
            userAvatarURL: messages[index].userAvatarURL,
            content: messages[index].content,
            messageType: messages[index].messageType,
            timestamp: messages[index].timestamp,
            isHighlighted: messages[index].isHighlighted,
            isPinned: true,
            isModerated: messages[index].isModerated,
            badges: messages[index].badges,
            emotes: messages[index].emotes,
            superChatAmount: messages[index].superChatAmount,
            replyToMessageId: messages[index].replyToMessageId
        )
        
        await MainActor.run {
            messages[index] = pinnedMessage
        }
    }
    
    func unpinMessage(messageId: String) async throws {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        let unpinnedMessage = ChatMessage(
            id: messages[index].id,
            streamId: messages[index].streamId,
            userId: messages[index].userId,
            username: messages[index].username,
            userAvatarURL: messages[index].userAvatarURL,
            content: messages[index].content,
            messageType: messages[index].messageType,
            timestamp: messages[index].timestamp,
            isHighlighted: messages[index].isHighlighted,
            isPinned: false,
            isModerated: messages[index].isModerated,
            badges: messages[index].badges,
            emotes: messages[index].emotes,
            superChatAmount: messages[index].superChatAmount,
            replyToMessageId: messages[index].replyToMessageId
        )
        
        await MainActor.run {
            messages[index] = unpinnedMessage
        }
    }
    
    // MARK: - Additional helper methods for MockLiveChatService
    func updateSettings(_ settings: ChatSettings) {
        Task {
            try? await updateChatSettings(streamId: currentStreamId ?? "", settings: settings)
        }
    }
    
    // MARK: - Private Methods
    private func setupSampleData() {
        messages = ChatMessage.sampleMessages
        chatUsers = ChatUser.sampleUsers
    }
    
    private func startMessageSimulation() {
        messageTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 2...8), repeats: true) { _ in
            Task {
                await self.simulateNewMessage()
            }
        }
    }
    
    private func stopMessageSimulation() {
        messageTimer?.invalidate()
        messageTimer = nil
    }
    
    private func simulateNewMessage() async {
        guard isConnected, let streamId = currentStreamId else { return }
        
        let randomUser = ChatUser.sampleUsers.randomElement() ?? ChatUser.sampleUsers[0]
        let sampleMessages = [
            "This stream is amazing! 🔥",
            "Great content as always!",
            "Can you play my song request?",
            "Love the setup! 😍",
            "First time watching, loving it!",
            "That was incredible! 👏",
            "More of this please!",
            "You're so talented!",
            "This is my favorite stream",
            "Keep up the great work! ❤️"
        ]
        
        let newMessage = ChatMessage(
            streamId: streamId,
            userId: randomUser.id,
            username: randomUser.username,
            userAvatarURL: randomUser.avatarURL,
            content: sampleMessages.randomElement() ?? "Hello chat!",
            badges: randomUser.userBadges
        )
        
        try? await sendMessage(newMessage)
    }
}

// MARK: - Sample Data
extension ChatMessage {
    static let sampleMessages: [ChatMessage] = [
        ChatMessage(
            streamId: "stream-1",
            userId: "user-1",
            username: "TechFan2024",
            content: "This stream is incredible! Love the new setup 🔥",
            badges: [UserBadge(name: "Subscriber", iconName: "heart.fill", color: "00FF7F", description: "Channel Subscriber")]
        ),
        ChatMessage(
            streamId: "stream-1",
            userId: "user-2",
            username: "CodeMaster",
            content: "Can you show that SwiftUI animation again?",
            isHighlighted: true,
            superChatAmount: 5.00
        ),
        ChatMessage(
            streamId: "stream-1",
            userId: "user-3",
            username: "ModeratorMax",
            content: "Welcome everyone to the stream! Remember to be respectful 👋",
            messageType: .moderator,
            badges: [UserBadge(name: "Moderator", iconName: "shield.fill", color: "FF4444", description: "Chat Moderator")]
        ),
        ChatMessage(
            streamId: "stream-1",
            userId: "user-4",
            username: "ArtLover",
            content: "Your art style is so unique! ✨",
            badges: [UserBadge(name: "VIP", iconName: "star.fill", color: "9146FF", description: "VIP Member")]
        ),
        ChatMessage(
            streamId: "stream-1",
            userId: "user-5",
            username: "GameStreamer",
            content: "$25.00 Keep up the amazing work! You inspire me every day! 💖",
            messageType: .superChat,
            isHighlighted: true,
            superChatAmount: 25.00
        )
    ]
}

extension ChatUser {
    static let sampleUsers: [ChatUser] = [
        ChatUser(
            username: "TechFan2024",
            displayName: "Tech Fan",
            avatarURL: "https://picsum.photos/100/100?random=1",
            isSubscriber: true,
            messageCount: 42
        ),
        ChatUser(
            username: "CodeMaster",
            displayName: "Code Master",
            avatarURL: "https://picsum.photos/100/100?random=2",
            isSubscriber: true,
            isVIP: true,
            messageCount: 156
        ),
        ChatUser(
            username: "ModeratorMax",
            displayName: "Moderator Max",
            avatarURL: "https://picsum.photos/100/100?random=3",
            isModerator: true,
            messageCount: 89
        ),
        ChatUser(
            username: "ArtLover",
            displayName: "Art Lover",
            avatarURL: "https://picsum.photos/100/100?random=4",
            isSubscriber: true,
            messageCount: 234
        ),
        ChatUser(
            username: "GameStreamer",
            displayName: "Game Streamer",
            avatarURL: "https://picsum.photos/100/100?random=5",
            isVIP: true,
            messageCount: 67
        )
    ]
}

#Preview {
    VStack {
        Text("Live Chat System")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Chat Features")
                .font(.headline)
            
            ForEach([
                "💬 Real-time messaging with WebSocket support",
                "💰 Super Chat with highlighted messages",
                "🛡️ Advanced moderation tools",
                "🏆 User badges and VIP status",
                "📌 Pin important messages",
                "😀 Custom emotes and reactions",
                "📊 Live chat statistics",
                "🔧 Chat settings and controls"
            ], id: \.self) { feature in
                HStack {
                    Text(feature)
                        .font(.body)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        
        Spacer()
    }
    .padding()
}