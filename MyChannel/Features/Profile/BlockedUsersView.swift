//
//  BlockedUsersView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct BlockedUsersView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var blockedUsers: [BlockedUser] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = true
    @State private var showingUnblockAlert: Bool = false
    @State private var userToUnblock: BlockedUser?
    @State private var showingEmptyState: Bool = false
    
    private var filteredUsers: [BlockedUser] {
        if searchText.isEmpty {
            return blockedUsers
        }
        return blockedUsers.filter { user in
            user.displayName.localizedCaseInsensitiveContains(searchText) ||
            user.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else if blockedUsers.isEmpty && !showingEmptyState {
                    emptyStateView
                } else {
                    // Search Bar
                    searchBar
                    
                    // Users List
                    usersList
                }
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Blocked Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadBlockedUsers()
            }
            .alert("Unblock User", isPresented: $showingUnblockAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Unblock", role: .destructive) {
                    if let user = userToUnblock {
                        unblockUser(user)
                    }
                }
            } message: {
                if let user = userToUnblock {
                    Text("Are you sure you want to unblock \(user.displayName)? They'll be able to interact with your content again.")
                }
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppTheme.Colors.primary)
            
            Text("Loading blocked users...")
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Spacer()
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 100)
                
                // Illustration
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.Colors.primary.opacity(0.1),
                                    AppTheme.Colors.primary.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.Colors.primary)
                }
                .shadow(color: AppTheme.Colors.primary.opacity(0.2), radius: 20, x: 0, y: 8)
                
                // Content
                VStack(spacing: 16) {
                    Text("No Blocked Users")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("You haven't blocked anyone yet. When you block users, they won't be able to comment on your videos or send you messages.")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .padding(.horizontal, 20)
                }
                
                // Help Section
                VStack(spacing: 16) {
                    Text("How to Block Users")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    VStack(spacing: 12) {
                        HelpStepRow(
                            number: 1,
                            text: "Go to a user's profile or find their comment"
                        )
                        
                        HelpStepRow(
                            number: 2,
                            text: "Tap the three dots menu"
                        )
                        
                        HelpStepRow(
                            number: 3,
                            text: "Select \"Block User\" from the options"
                        )
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 100)
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                UIKitSearchBar(
                    text: $searchText,
                    placeholder: "Search blocked users..."
                )
                .frame(height: 36)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
                .background(AppTheme.Colors.textTertiary.opacity(0.2))
        }
    }
    
    // MARK: - Users List
    private var usersList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredUsers) { user in
                    BlockedUserRow(
                        user: user,
                        onUnblock: {
                            userToUnblock = user
                            showingUnblockAlert = true
                        }
                    )
                    
                    if user.id != filteredUsers.last?.id {
                        Divider()
                            .padding(.leading, 80)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .overlay(
            Group {
                if !searchText.isEmpty && filteredUsers.isEmpty {
                    searchEmptyState
                }
            }
        )
    }
    
    // MARK: - Search Empty State
    private var searchEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            VStack(spacing: 8) {
                Text("No Results Found")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("No blocked users match \"\(searchText)\"")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
    }
    
    // MARK: - Helper Methods
    private func loadBlockedUsers() {
        #if canImport(FirebaseFirestore)
        guard let currentUserId = authManager.currentUser?.id else {
            isLoading = false
            showingEmptyState = true
            return
        }
        let db = Firestore.firestore()
        Task {
            do {
                let snapshot = try await db.collection("users").document(currentUserId)
                    .collection("blockedUsers")
                    .order(by: "createdAt", descending: true)
                    .getDocuments()
                
                let users = snapshot.documents.compactMap { doc -> BlockedUser? in
                    let data = doc.data()
                    let timestamp = data["createdAt"] as? Timestamp
                    return BlockedUser(
                        id: doc.documentID,
                        username: data["blockedUserUsername"] as? String ?? "unknown",
                        displayName: data["blockedUserDisplayName"] as? String ?? "Unknown User",
                        profileImageURL: data["blockedUserProfileImage"] as? String,
                        blockedDate: timestamp?.dateValue() ?? Date(),
                        reason: data["reason"] as? String ?? "user_initiated_block"
                    )
                }
                await MainActor.run {
                    blockedUsers = users
                    isLoading = false
                    showingEmptyState = users.isEmpty
                }
            } catch {
                print("🚨 [BlockedUsers] Error loading: \(error)")
                await MainActor.run {
                    isLoading = false
                    showingEmptyState = true
                }
            }
        }
        #else
        isLoading = false
        showingEmptyState = true
        #endif
    }
    
    private func unblockUser(_ user: BlockedUser) {
        HapticManager.shared.impact(style: .medium)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            blockedUsers.removeAll { $0.id == user.id }
        }
        
        #if canImport(FirebaseFirestore)
        guard let currentUserId = authManager.currentUser?.id else { return }
        let db = Firestore.firestore()
        Task {
            try? await db.collection("users").document(currentUserId)
                .collection("blockedUsers").document(user.id)
                .delete()
            print("✅ [BlockedUsers] Unblocked \(user.username)")
        }
        #endif
    }
}

// MARK: - Blocked User Row
struct BlockedUserRow: View {
    let user: BlockedUser
    let onUnblock: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Image
            AsyncImage(url: URL(string: user.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.primary.opacity(0.3),
                                AppTheme.Colors.primary.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Text(user.displayName.prefix(1).uppercased())
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primary)
                    )
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Text("@\(user.username)")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("Blocked")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text("•")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text(formatBlockedDate(user.blockedDate))
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            
            Spacer()
            
            // Unblock Button
            Button {
                onUnblock()
                HapticManager.shared.impact(style: .light)
            } label: {
                Text("Unblock")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.Colors.primary.opacity(0.1))
                    .cornerRadius(20)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.clear)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
    
    private func formatBlockedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Help Step Row
struct HelpStepRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Step number circle
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primary)
                    .frame(width: 24, height: 24)
                
                Text("\(number)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Step text
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Blocked User Model
struct BlockedUser: Identifiable, Hashable {
    let id: String
    let username: String
    let displayName: String
    let profileImageURL: String?
    let blockedDate: Date
    let reason: String
}

#Preview {
    BlockedUsersView()
        .environmentObject(AuthenticationManager.shared)
}