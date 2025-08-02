//
//  MessageOptionsView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct MessageOptionsView: View {
    let message: ChatMessage
    @ObservedObject var chatService: MockLiveChatService
    @Environment(\.dismiss) private var dismiss
    @State private var showingReportOptions = false
    @State private var showingUserProfile = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Message Preview
                messagePreview
                
                // Options List
                optionsList
            }
            .navigationTitle("Message Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingReportOptions) {
            ReportMessageView(message: message)
        }
        .sheet(isPresented: $showingUserProfile) {
            ChatUserProfileView(
                user: ChatUser(
                    id: message.userId,
                    username: message.username,
                    displayName: message.username,
                    avatarURL: message.userAvatarURL,
                    isSubscriber: message.badges.contains { $0.name == "Subscriber" },
                    isModerator: message.badges.contains { $0.name == "Moderator" },
                    isVIP: message.badges.contains { $0.name == "VIP" },
                    joinedAt: Date().addingTimeInterval(-86400), // 1 day ago
                    messageCount: Int.random(in: 1...100)
                )
            )
        }
    }
    
    private var messagePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                AsyncImage(url: URL(string: message.userAvatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Text(String(message.username.prefix(1)).uppercased())
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        ForEach(message.badges.prefix(3)) { badge in
                            Image(systemName: badge.iconName)
                                .font(.caption2)
                                .foregroundColor(badge.badgeColor)
                        }
                        
                        Text(message.username)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(message.timeString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(message.content)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            
            if let amount = message.superChatAmount {
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(.green)
                    Text("Super Chat: $\(amount, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var optionsList: some View {
        List {
            Section("User Actions") {
                Button(action: { showingUserProfile = true }) {
                    OptionRow(
                        icon: "person.circle",
                        title: "View Profile",
                        subtitle: "See @\(message.username)'s profile",
                        color: .blue
                    )
                }
                
                Button(action: replyToMessage) {
                    OptionRow(
                        icon: "arrowshape.turn.up.left",
                        title: "Reply",
                        subtitle: "Reply to this message",
                        color: .blue
                    )
                }
                
                Button(action: mentionUser) {
                    OptionRow(
                        icon: "at",
                        title: "Mention",
                        subtitle: "Mention @\(message.username)",
                        color: .blue
                    )
                }
            }
            
            Section("Message Actions") {
                Button(action: copyMessage) {
                    OptionRow(
                        icon: "doc.on.doc",
                        title: "Copy Message",
                        subtitle: "Copy message text",
                        color: .gray
                    )
                }
                
                if canPinMessage {
                    Button(action: togglePinMessage) {
                        OptionRow(
                            icon: message.isPinned ? "pin.slash" : "pin",
                            title: message.isPinned ? "Unpin Message" : "Pin Message",
                            subtitle: message.isPinned ? "Remove from pinned" : "Pin to top of chat",
                            color: .orange
                        )
                    }
                }
                
                if canHighlightMessage {
                    Button(action: toggleHighlightMessage) {
                        OptionRow(
                            icon: message.isHighlighted ? "highlighter" : "highlighter",
                            title: message.isHighlighted ? "Remove Highlight" : "Highlight Message",
                            subtitle: message.isHighlighted ? "Remove highlight" : "Highlight this message",
                            color: .yellow
                        )
                    }
                }
            }
            
            Section("Moderation") {
                if canModerateUser {
                    Button(action: timeoutUser) {
                        OptionRow(
                            icon: "clock",
                            title: "Timeout User",
                            subtitle: "Temporarily restrict user",
                            color: .orange
                        )
                    }
                    
                    Button(action: banUser) {
                        OptionRow(
                            icon: "xmark.circle",
                            title: "Ban User",
                            subtitle: "Permanently ban user",
                            color: .red
                        )
                    }
                }
                
                Button(action: deleteMessage) {
                    OptionRow(
                        icon: "trash",
                        title: "Delete Message",
                        subtitle: "Remove this message",
                        color: .red
                    )
                }
                
                Button(action: { showingReportOptions = true }) {
                    OptionRow(
                        icon: "flag",
                        title: "Report Message",
                        subtitle: "Report inappropriate content",
                        color: .red
                    )
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var canPinMessage: Bool {
        // Only moderators/streamers can pin messages
        return true // Simplified for demo
    }
    
    private var canHighlightMessage: Bool {
        // Only moderators/streamers can highlight messages
        return true // Simplified for demo
    }
    
    private var canModerateUser: Bool {
        // Only moderators/streamers can moderate users
        return true // Simplified for demo
    }
    
    // MARK: - Actions
    private func replyToMessage() {
        // TODO: Implement reply functionality
        dismiss()
    }
    
    private func mentionUser() {
        // TODO: Implement mention functionality
        dismiss()
    }
    
    private func copyMessage() {
        UIPasteboard.general.string = message.content
        dismiss()
    }
    
    private func togglePinMessage() {
        Task {
            if message.isPinned {
                try? await chatService.unpinMessage(messageId: message.id)
            } else {
                try? await chatService.pinMessage(messageId: message.id)
            }
            dismiss()
        }
    }
    
    private func toggleHighlightMessage() {
        Task {
            if message.isHighlighted {
                try? await chatService.moderateMessage(messageId: message.id, action: .highlight)
            } else {
                try? await chatService.moderateMessage(messageId: message.id, action: .highlight)
            }
            dismiss()
        }
    }
    
    private func timeoutUser() {
        Task {
            try? await chatService.moderateMessage(messageId: message.id, action: .timeout)
            dismiss()
        }
    }
    
    private func banUser() {
        Task {
            try? await chatService.moderateMessage(messageId: message.id, action: .ban)
            dismiss()
        }
    }
    
    private func deleteMessage() {
        Task {
            try? await chatService.moderateMessage(messageId: message.id, action: .delete)
            dismiss()
        }
    }
}

struct OptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ReportMessageView: View {
    let message: ChatMessage
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason = ReportReason.spam
    @State private var additionalDetails = ""
    
    enum ReportReason: String, CaseIterable {
        case spam = "Spam"
        case harassment = "Harassment"
        case hateSpeech = "Hate Speech"
        case inappropriate = "Inappropriate Content"
        case impersonation = "Impersonation"
        case other = "Other"
        
        var description: String {
            switch self {
            case .spam: return "Repetitive or unwanted messages"
            case .harassment: return "Targeted harassment or bullying"
            case .hateSpeech: return "Hate speech or discrimination"
            case .inappropriate: return "Inappropriate or offensive content"
            case .impersonation: return "Impersonating another user"
            case .other: return "Other violation"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Report Reason")) {
                    ForEach(ReportReason.allCases, id: \.self) { reason in
                        Button(action: { selectedReason = reason }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(reason.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text(reason.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedReason == reason {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Section(header: Text("Additional Details (Optional)")) {
                    TextField("Provide additional context...", text: $additionalDetails, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("Message Preview")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("@\(message.username)")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text(message.content)
                            .font(.subheadline)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .navigationTitle("Report Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Report") {
                        submitReport()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                }
            }
        }
    }
    
    private func submitReport() {
        // TODO: Implement report submission
        dismiss()
    }
}

#Preview {
    MessageOptionsView(
        message: ChatMessage(
            streamId: "stream-1",
            userId: "user-1",
            username: "TestUser",
            content: "This is a test message for the preview!"
        ),
        chatService: MockLiveChatService()
    )
}