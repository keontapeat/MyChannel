//
//  ChatUserListView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct ChatUserListView: View {
    @ObservedObject var chatService: MockLiveChatService
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedFilter: UserFilter = .all
    
    enum UserFilter: String, CaseIterable {
        case all = "All"
        case subscribers = "Subscribers"
        case moderators = "Moderators"
        case vips = "VIPs"
        
        var iconName: String {
            switch self {
            case .all: return "person.2"
            case .subscribers: return "heart"
            case .moderators: return "shield"
            case .vips: return "star"
            }
        }
    }
    
    var filteredUsers: [ChatUser] {
        var users = chatService.chatUsers
        
        // Apply search filter
        if !searchText.isEmpty {
            users = users.filter { user in
                user.username.localizedCaseInsensitiveContains(searchText) ||
                user.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply type filter
        switch selectedFilter {
        case .all:
            break
        case .subscribers:
            users = users.filter { $0.isSubscriber }
        case .moderators:
            users = users.filter { $0.isModerator }
        case .vips:
            users = users.filter { $0.isVIP }
        }
        
        return users.sorted { $0.messageCount > $1.messageCount }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                searchSection
                
                // Filter Tabs
                filterSection
                
                // User List
                userListSection
            }
            .navigationTitle("Chat Users (\(chatService.statistics.activeUsers))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var searchSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search users...", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(UserFilter.allCases, id: \.self) { filter in
                    Button(action: { selectedFilter = filter }) {
                        HStack(spacing: 6) {
                            Image(systemName: filter.iconName)
                                .font(.caption)
                            Text(filter.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedFilter == filter ? Color.blue : Color(.systemGray6))
                        .foregroundColor(selectedFilter == filter ? .white : .primary)
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }
    
    private var userListSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredUsers) { user in
                    ChatUserRow(user: user)
                        .padding(.horizontal)
                    
                    if user.id != filteredUsers.last?.id {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
        }
    }
}

// MARK: - Chat User Row
struct ChatUserRow: View {
    let user: ChatUser
    @State private var showingUserProfile = false
    
    var body: some View {
        Button(action: { showingUserProfile = true }) {
            HStack(spacing: 12) {
                // Avatar
                AsyncImage(url: URL(string: user.avatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Text(String(user.username.prefix(1)).uppercased())
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                        )
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(user.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        // Badges
                        ForEach(user.userBadges.prefix(2)) { badge in
                            Image(systemName: badge.iconName)
                                .font(.caption2)
                                .foregroundColor(badge.badgeColor)
                        }
                        
                        Spacer()
                    }
                    
                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("\(user.messageCount) messages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("Joined \(user.joinedAt.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Message Count Badge
                if user.messageCount > 0 {
                    Text("\(user.messageCount)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingUserProfile) {
            ChatUserProfileView(user: user)
        }
    }
}

// MARK: - Chat User Profile View
struct ChatUserProfileView: View {
    let user: ChatUser
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        AsyncImage(url: URL(string: user.avatarURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color(.systemGray5))
                                .overlay(
                                    Text(String(user.username.prefix(1)).uppercased())
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.secondary)
                                )
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        
                        VStack(spacing: 8) {
                            Text(user.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("@\(user.username)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            // Badges
                            if !user.userBadges.isEmpty {
                                HStack(spacing: 8) {
                                    ForEach(user.userBadges) { badge in
                                        HStack(spacing: 4) {
                                            Image(systemName: badge.iconName)
                                                .font(.caption)
                                            Text(badge.name)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(badge.badgeColor.opacity(0.1))
                                        .foregroundColor(badge.badgeColor)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Stats
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Chat Statistics")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            ChatStatItem(title: "Messages", value: "\(user.messageCount)")
                            ChatStatItem(title: "Joined", value: user.joinedAt.formatted(.relative(presentation: .named)))
                            ChatStatItem(title: "Status", value: user.isSubscriber ? "Subscriber" : "Viewer")
                            ChatStatItem(title: "Type", value: user.isModerator ? "Moderator" : user.isVIP ? "VIP" : "Regular")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button("Send Direct Message") {
                            // TODO: Implement DM functionality
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        
                        Button("View Profile") {
                            // TODO: Navigate to full user profile
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
            }
            .navigationTitle("User Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct ChatStatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ChatUserListView(chatService: MockLiveChatService())
}