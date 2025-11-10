//
//  ChannelMentionTextField.swift
//  MyChannel
//
//  YouTube Parity: Title field with @channel autocomplete
//  Created for MyChannel by AI Assistant
//

import SwiftUI
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// TextField with @channel autocomplete (YouTube-style)
struct ChannelMentionTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    let isRequired: Bool
    let maxLength: Int
    
    @FocusState private var isFocused: Bool
    @State private var showAutocomplete = false
    @State private var autocompleteResults: [User] = []
    @State private var currentMentionQuery: String = ""
    @State private var mentionStartIndex: Int = 0
    @State private var selectedAutocompleteIndex: Int = 0
    
    private let userService = UserFirestoreService.shared
    
    init(title: String, text: Binding<String>, placeholder: String, icon: String, isRequired: Bool = false, maxLength: Int = 100) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.isRequired = isRequired
        self.maxLength = maxLength
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                if isRequired {
                    Text("*")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)
                }
                Spacer()
                Text("\(text.count)/\(maxLength)")
                    .font(.system(size: 12))
                    .foregroundColor(text.count > maxLength ? .red : AppTheme.Colors.textTertiary)
            }
            
            ZStack(alignment: .topLeading) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                        .frame(width: 20)
                    
                    TextField(placeholder, text: $text)
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .focused($isFocused)
                        .onChange(of: text) { newValue in
                            if newValue.count > maxLength {
                                text = String(newValue.prefix(maxLength))
                            }
                            checkForMention(newValue)
                        }
                        .onSubmit {
                            if showAutocomplete && !autocompleteResults.isEmpty {
                                insertChannel(autocompleteResults[selectedAutocompleteIndex])
                            }
                        }
                }
                .padding(16)
                .background(AppTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.3), lineWidth: isFocused ? 2 : 1)
                )
                .animation(.easeInOut(duration: 0.2), value: isFocused)
                
                // 🔥 YOUTUBE PARITY: Autocomplete dropdown
                if showAutocomplete && !autocompleteResults.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(autocompleteResults.enumerated()), id: \.element.id) { index, user in
                            Button(action: {
                                insertChannel(user)
                            }) {
                                HStack(spacing: 12) {
                                    ProfileAvatarView(urlString: user.profileImageURL, size: 32)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Text(user.displayName)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(AppTheme.Colors.textPrimary)
                                            
                                            if user.shouldShowVerificationBadge {
                                                Image(systemName: "checkmark.seal.fill")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        
                                        Text("@\(user.username)")
                                            .font(.system(size: 13))
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(index == selectedAutocompleteIndex ? AppTheme.Colors.surface.opacity(0.5) : Color.clear)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(AppTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .padding(.top, 60)  // Position below text field
                    .frame(maxHeight: 200)
                }
            }
        }
    }
    
    // MARK: - Autocomplete Logic
    
    private func checkForMention(_ text: String) {
        // Find the last @ symbol
        if let lastAtIndex = text.lastIndex(of: "@") {
            let afterAt = text.index(after: lastAtIndex)
            let query = String(text[afterAt...])
            
            // Check if we're still typing the mention (no space after @)
            if !query.contains(" ") && !query.isEmpty {
                mentionStartIndex = text.distance(from: text.startIndex, to: lastAtIndex)
                currentMentionQuery = query
                showAutocomplete = true
                
                // Search for channels
                Task {
                    await searchChannels(query: query)
                }
            } else {
                showAutocomplete = false
            }
        } else {
            showAutocomplete = false
        }
    }
    
    private func searchChannels(query: String) async {
        guard !query.isEmpty else {
            await MainActor.run {
                autocompleteResults = []
            }
            return
        }
        
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let queryLower = query.lowercased()
            
            // Search by username (starts with)
            let usernameQuery = db.collection("users")
                .whereField("username", isGreaterThanOrEqualTo: queryLower)
                .whereField("username", isLessThan: queryLower + "\u{f8ff}")
                .limit(to: 5)
            
            // Search by displayName (contains)
            let displayNameQuery = db.collection("users")
                .whereField("displayName", isGreaterThanOrEqualTo: queryLower)
                .whereField("displayName", isLessThan: queryLower + "\u{f8ff}")
                .limit(to: 5)
            
            // Execute both queries
            async let usernameResults = usernameQuery.getDocuments()
            async let displayNameResults = displayNameQuery.getDocuments()
            
            let (usernameSnap, displayNameSnap) = try await (usernameResults, displayNameResults)
            
            var users: [User] = []
            var seenIds = Set<String>()
            
            // Process username results
            for doc in usernameSnap.documents {
                if let user = try? parseUser(from: doc) {
                    if !seenIds.contains(user.id) {
                        users.append(user)
                        seenIds.insert(user.id)
                    }
                }
            }
            
            // Process displayName results
            for doc in displayNameSnap.documents {
                if let user = try? parseUser(from: doc) {
                    if !seenIds.contains(user.id) {
                        users.append(user)
                        seenIds.insert(user.id)
                    }
                }
            }
            
            // Sort by relevance (exact matches first, then by subscriber count)
            users.sort { user1, user2 in
                let user1Exact = user1.username.lowercased() == queryLower || user1.displayName.lowercased() == queryLower
                let user2Exact = user2.username.lowercased() == queryLower || user2.displayName.lowercased() == queryLower
                
                if user1Exact != user2Exact {
                    return user1Exact
                }
                
                return user1.subscriberCount > user2.subscriberCount
            }
            
            await MainActor.run {
                autocompleteResults = Array(users.prefix(5))
            }
        } catch {
            print("⚠️ [ChannelMention] Error searching channels: \(error)")
            await MainActor.run {
                autocompleteResults = []
            }
        }
        #else
        // Fallback: No Firebase - show empty results
        await MainActor.run {
            autocompleteResults = []
        }
        #endif
    }
    
    #if canImport(FirebaseFirestore)
    private func parseUser(from doc: DocumentSnapshot) throws -> User {
        let data = doc.data() ?? [:]
        
        return User(
            id: doc.documentID,
            username: data["username"] as? String ?? "",
            displayName: data["displayName"] as? String ?? "",
            email: data["email"] as? String ?? "",
            profileImageURL: (data["profileImageURL"] as? String) ?? (data["avatarUrl"] as? String),
            bannerImageURL: data["bannerImageURL"] as? String,
            bio: data["bio"] as? String,
            subscriberCount: data["subscriberCount"] as? Int ?? 0,
            videoCount: data["videoCount"] as? Int ?? 0,
            isVerified: data["isVerified"] as? Bool ?? false,
            isCreator: data["isCreator"] as? Bool ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            location: data["location"] as? String,
            website: data["website"] as? String,
            socialLinks: [],
            followerCount: data["followerCount"] as? Int,
            followingCount: data["followingCount"] as? Int ?? 0,
            joinDate: (data["joinDate"] as? Timestamp)?.dateValue()
        )
    }
    #endif
    
    private func insertChannel(_ user: User) {
        // Find the @ position
        if let lastAtIndex = text.lastIndex(of: "@") {
            let beforeAt = String(text[..<lastAtIndex])
            let afterMention = text[text.index(after: lastAtIndex)...]
            
            // Find where the mention query ends (space or end of string)
            if let spaceIndex = afterMention.firstIndex(of: " ") {
                let remaining = String(afterMention[afterMention.index(after: spaceIndex)...])
                text = beforeAt + "@\(user.username) " + remaining
            } else {
                text = beforeAt + "@\(user.username) "
            }
        }
        
        showAutocomplete = false
        autocompleteResults = []
    }
}

#Preview {
    ChannelMentionTextField(
        title: "Title",
        text: .constant("WayP - Leave @Shot"),
        placeholder: "Enter video title",
        icon: "text.cursor",
        isRequired: true,
        maxLength: 100
    )
    .padding()
}

