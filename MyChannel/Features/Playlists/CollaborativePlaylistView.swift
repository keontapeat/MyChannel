//
//  CollaborativePlaylistView.swift
//  MyChannel
//
//  Created by AI Assistant on 11/28/25.
//

import SwiftUI

// MARK: - Collaborative Playlists List View
struct CollaborativePlaylistsView: View {
    @StateObject private var service = CollaborativePlaylistService.shared
    @State private var showCreatePlaylist = false
    @State private var showJoinPlaylist = false
    @State private var selectedPlaylist: CollaborativePlaylist?
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading playlists...")
                } else if service.playlists.isEmpty {
                    emptyStateView
                } else {
                    playlistsList
                }
            }
            .navigationTitle("Collaborative Playlists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showCreatePlaylist = true
                        } label: {
                            Label("Create Playlist", systemImage: "plus.rectangle.fill")
                        }
                        
                        Button {
                            showJoinPlaylist = true
                        } label: {
                            Label("Join with Code", systemImage: "link.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
            .sheet(isPresented: $showCreatePlaylist) {
                CreateCollaborativePlaylistView()
            }
            .sheet(isPresented: $showJoinPlaylist) {
                JoinPlaylistSheet()
            }
            .sheet(item: $selectedPlaylist) { playlist in
                CollaborativePlaylistDetailView(playlist: playlist)
            }
            .task {
                await loadPlaylists()
            }
        }
    }
    
    // MARK: - Playlists List
    private var playlistsList: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.Spacing.md) {
                // My Playlists Section
                if !myPlaylists.isEmpty {
                    playlistSection(title: "My Playlists", playlists: myPlaylists)
                }
                
                // Collaborating Section
                if !collaboratingPlaylists.isEmpty {
                    playlistSection(title: "Collaborating", playlists: collaboratingPlaylists)
                }
            }
            .padding()
        }
    }
    
    private func playlistSection(title: String, playlists: [CollaborativePlaylist]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text(title)
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            ForEach(playlists) { playlist in
                CollaborativePlaylistCard(playlist: playlist) {
                    selectedPlaylist = playlist
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "person.2.wave.2.fill")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            Text("No Collaborative Playlists")
                .font(AppTheme.Typography.title2)
            
            Text("Create a playlist and invite friends to add videos together, or join an existing playlist with a code.")
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)
            
            HStack(spacing: AppTheme.Spacing.md) {
                Button {
                    showCreatePlaylist = true
                } label: {
                    Label("Create", systemImage: "plus")
                }
                .modernButtonStyle()
                
                Button {
                    showJoinPlaylist = true
                } label: {
                    Label("Join", systemImage: "link")
                }
                .secondaryButtonStyle()
            }
        }
    }
    
    // MARK: - Computed Properties
    private var myPlaylists: [CollaborativePlaylist] {
        service.playlists.filter { $0.ownerId == (AppState.shared.currentUser?.id ?? "") }
    }
    
    private var collaboratingPlaylists: [CollaborativePlaylist] {
        service.playlists.filter { $0.ownerId != (AppState.shared.currentUser?.id ?? "") }
    }
    
    // MARK: - Methods
    private func loadPlaylists() async {
        isLoading = true
        do {
            let _ = try await service.getPlaylists(for: (AppState.shared.currentUser?.id ?? ""))
        } catch {
            print("Failed to load playlists: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Collaborative Playlist Card
struct CollaborativePlaylistCard: View {
    let playlist: CollaborativePlaylist
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Thumbnail
                AsyncImage(url: URL(string: playlist.thumbnailURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            Image(systemName: "music.note.list")
                                .font(.title)
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        )
                }
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .bottomTrailing) {
                    // Video count badge
                    Text("\(playlist.videoCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .padding(4)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.title)
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    // Collaborators avatars
                    HStack(spacing: -6) {
                        ForEach(playlist.collaborators.prefix(3)) { collaborator in
                            AsyncImage(url: URL(string: collaborator.profileImageURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle().fill(AppTheme.Colors.surface)
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        }
                        
                        if playlist.collaborators.count > 3 {
                            Circle()
                                .fill(AppTheme.Colors.primary)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text("+\(playlist.collaborators.count - 3)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        }
                        
                        Spacer()
                    }
                    
                    // Stats
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Label("\(playlist.collaboratorCount)", systemImage: "person.2")
                        Text("•")
                        Text(playlist.formattedDuration)
                        
                        Spacer()
                        
                        // Share code
                        Text(playlist.shareCode)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(AppTheme.Colors.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.Colors.primary.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding()
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(AppTheme.CornerRadius.md)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Create Collaborative Playlist View
struct CreateCollaborativePlaylistView: View {
    @StateObject private var service = CollaborativePlaylistService.shared
    @State private var title = ""
    @State private var description = ""
    @State private var isPublic = true
    @State private var allowSuggestions = true
    @State private var requireApproval = false
    @State private var selectedCategory: PlaylistCategory = .general
    @State private var isCreating = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Playlist Info") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(PlaylistCategory.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.iconName)
                                .tag(category)
                        }
                    }
                }
                
                Section("Privacy") {
                    Toggle("Public Playlist", isOn: $isPublic)
                    
                    if isPublic {
                        Toggle("Allow Suggestions", isOn: $allowSuggestions)
                        
                        if allowSuggestions {
                            Toggle("Require Approval", isOn: $requireApproval)
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("How it works", systemImage: "info.circle")
                            .font(AppTheme.Typography.headline)
                        
                        Text("• Share the playlist code with friends\n• Collaborators can add and remove videos\n• You control who can edit the playlist")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
            .navigationTitle("Create Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createPlaylist()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createPlaylist() {
        isCreating = true
        
        let playlist = CollaborativePlaylist(
            title: title,
            description: description,
            ownerId: (AppState.shared.currentUser?.id ?? ""),
            isPublic: isPublic,
            allowSuggestions: allowSuggestions,
            requireApproval: requireApproval,
            category: selectedCategory
        )
        
        Task {
            do {
                let _ = try await service.createPlaylist(playlist)
                dismiss()
            } catch {
                print("Failed to create playlist: \(error)")
            }
            isCreating = false
        }
    }
}

// MARK: - Join Playlist Sheet
struct JoinPlaylistSheet: View {
    @StateObject private var service = CollaborativePlaylistService.shared
    @State private var shareCode = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.xl) {
                Spacer()
                
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 64))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("Join a Playlist")
                    .font(AppTheme.Typography.title1)
                
                Text("Enter the 6-character code shared by the playlist owner")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Code Input
                TextField("Enter Code", text: $shareCode)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding()
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(AppTheme.CornerRadius.md)
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .onChange(of: shareCode) { newValue in
                        shareCode = String(newValue.uppercased().prefix(6))
                    }
                
                if let error = errorMessage {
                    Text(error)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.error)
                }
                
                Button {
                    joinPlaylist()
                } label: {
                    if isJoining {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Join Playlist")
                    }
                }
                .modernButtonStyle()
                .disabled(shareCode.count != 6 || isJoining)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func joinPlaylist() {
        isJoining = true
        errorMessage = nil
        
        Task {
            do {
                let _ = try await service.joinPlaylist(shareCode: shareCode, userId: (AppState.shared.currentUser?.id ?? ""))
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isJoining = false
        }
    }
}

// MARK: - Collaborative Playlist Detail View
struct CollaborativePlaylistDetailView: View {
    let playlist: CollaborativePlaylist
    
    @StateObject private var service = CollaborativePlaylistService.shared
    @State private var showManageCollaborators = false
    @State private var showAddVideo = false
    @State private var showShareSheet = false
    @State private var showActivityLog = false
    @State private var currentPlaylist: CollaborativePlaylist
    
    @Environment(\.dismiss) private var dismiss
    
    init(playlist: CollaborativePlaylist) {
        self.playlist = playlist
        self._currentPlaylist = State(initialValue: playlist)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Header
                    playlistHeader
                    
                    // Quick Actions
                    quickActionsBar
                    
                    // Pending Suggestions
                    if !currentPlaylist.pendingSuggestions.isEmpty && isOwnerOrAdmin {
                        pendingSuggestionsSection
                    }
                    
                    // Videos List
                    videosSection
                    
                    // Collaborators Preview
                    collaboratorsPreview
                }
                .padding()
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share Code", systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            showManageCollaborators = true
                        } label: {
                            Label("Manage Collaborators", systemImage: "person.2")
                        }
                        
                        Button {
                            showActivityLog = true
                        } label: {
                            Label("Activity Log", systemImage: "clock.arrow.circlepath")
                        }
                        
                        if currentPlaylist.ownerId != (AppState.shared.currentUser?.id ?? "") {
                            Divider()
                            Button(role: .destructive) {
                                leavePlaylist()
                            } label: {
                                Label("Leave Playlist", systemImage: "person.badge.minus")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showManageCollaborators) {
                ManageCollaboratorsView(playlist: currentPlaylist)
            }
            .sheet(isPresented: $showActivityLog) {
                ActivityLogView(playlistId: currentPlaylist.id)
            }
            .sheet(isPresented: $showShareSheet) {
                SharePlaylistSheet(playlist: currentPlaylist)
            }
        }
    }
    
    // MARK: - Header
    private var playlistHeader: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Thumbnail
            AsyncImage(url: URL(string: currentPlaylist.thumbnailURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.Colors.primary.opacity(0.3), AppTheme.Colors.secondary.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.5))
                    )
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg))
            
            // Info
            VStack(spacing: AppTheme.Spacing.sm) {
                Text(currentPlaylist.title)
                    .font(AppTheme.Typography.title2)
                    .multilineTextAlignment(.center)
                
                Text(currentPlaylist.description)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: AppTheme.Spacing.md) {
                    Label("\(currentPlaylist.videoCount) videos", systemImage: "play.rectangle")
                    Label("\(currentPlaylist.collaboratorCount) people", systemImage: "person.2")
                    Label(currentPlaylist.formattedDuration, systemImage: "clock")
                }
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textTertiary)
            }
        }
    }
    
    // MARK: - Quick Actions
    private var quickActionsBar: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Button {
                // Play all
            } label: {
                Label("Play All", systemImage: "play.fill")
                    .font(AppTheme.Typography.bodyMedium)
            }
            .modernButtonStyle()
            
            Button {
                // Shuffle
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .font(AppTheme.Typography.bodyMedium)
            }
            .secondaryButtonStyle()
            
            if currentPlaylist.canAdd(userId: (AppState.shared.currentUser?.id ?? "")) {
                Button {
                    showAddVideo = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                }
                .frame(width: 48, height: 48)
                .background(AppTheme.Colors.surface)
                .clipShape(Circle())
            }
        }
    }
    
    // MARK: - Pending Suggestions
    private var pendingSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                Text("Pending Suggestions")
                    .font(AppTheme.Typography.headline)
                Spacer()
                Text("\(currentPlaylist.pendingSuggestions.count)")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
            
            ForEach(currentPlaylist.pendingSuggestions) { suggestion in
                SuggestionRow(suggestion: suggestion) {
                    // Approve
                    Task {
                        try? await service.approveSuggestion(playlistId: currentPlaylist.id, suggestionId: suggestion.id)
                    }
                } onReject: {
                    Task {
                        try? await service.rejectSuggestion(playlistId: currentPlaylist.id, suggestionId: suggestion.id)
                    }
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(AppTheme.CornerRadius.md)
    }
    
    // MARK: - Videos Section
    private var videosSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Videos")
                .font(AppTheme.Typography.headline)
            
            if currentPlaylist.videoItems.isEmpty {
                VStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "play.rectangle.on.rectangle")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text("No videos yet")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    if currentPlaylist.canAdd(userId: (AppState.shared.currentUser?.id ?? "")) {
                        Button("Add Video") {
                            showAddVideo = true
                        }
                        .font(AppTheme.Typography.bodyMedium)
                        .foregroundColor(AppTheme.Colors.primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.xl)
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.md)
            } else {
                ForEach(currentPlaylist.videoItems) { video in
                    CollaborativePlaylistVideoRow(video: video, canRemove: currentPlaylist.canRemove(userId: (AppState.shared.currentUser?.id ?? ""))) {
                        Task {
                            try? await service.removeVideo(playlistId: currentPlaylist.id, videoItemId: video.id)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Collaborators Preview
    private var collaboratorsPreview: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Text("Collaborators")
                    .font(AppTheme.Typography.headline)
                
                Spacer()
                
                Button("Manage") {
                    showManageCollaborators = true
                }
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.primary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.md) {
                    // Owner
                    CollaboratorAvatar(
                        name: "You (Owner)",
                        imageURL: nil,
                        permission: nil,
                        isOwner: true
                    )
                    
                    ForEach(currentPlaylist.collaborators) { collaborator in
                        CollaboratorAvatar(
                            name: collaborator.displayName,
                            imageURL: collaborator.profileImageURL,
                            permission: collaborator.permission,
                            isOwner: false
                        )
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
    }
    
    // MARK: - Computed
    private var isOwnerOrAdmin: Bool {
        currentPlaylist.ownerId == (AppState.shared.currentUser?.id ?? "") || currentPlaylist.canEdit(userId: (AppState.shared.currentUser?.id ?? ""))
    }
    
    // MARK: - Methods
    private func leavePlaylist() {
        Task {
            try? await service.leavePlaylist(playlistId: currentPlaylist.id, userId: (AppState.shared.currentUser?.id ?? ""))
            dismiss()
        }
    }
}

// MARK: - Supporting Views
struct SuggestionRow: View {
    let suggestion: CollaborativePlaylistSuggestion
    let onApprove: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            AsyncImage(url: URL(string: suggestion.thumbnailURL)) { image in
                image.resizable().aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle().fill(AppTheme.Colors.surface)
            }
            .frame(width: 80, height: 45)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .font(AppTheme.Typography.subheadline)
                    .lineLimit(1)
                
                Text("by \(suggestion.suggestedByName)")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button {
                    onApprove()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.Colors.success)
                }
                
                Button {
                    onReject()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.Colors.error)
                }
            }
            .font(.title2)
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.sm)
    }
}

struct CollaborativePlaylistVideoRow: View {
    let video: PlaylistVideoItem
    let canRemove: Bool
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image.resizable().aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle().fill(AppTheme.Colors.surface)
            }
            .frame(width: 100, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottomTrailing) {
                Text(video.formattedDuration)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
                    .padding(4)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(AppTheme.Typography.subheadline)
                    .lineLimit(2)
                
                Text(video.creatorName)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                HStack {
                    Text("Added by \(video.addedByName)")
                        .font(AppTheme.Typography.caption2)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    if let note = video.note {
                        Text("• \"\(note)\"")
                            .font(AppTheme.Typography.caption2)
                            .foregroundColor(AppTheme.Colors.primary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            if canRemove {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundColor(AppTheme.Colors.error.opacity(0.7))
                }
            }
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
    }
}

struct CollaboratorAvatar: View {
    let name: String
    let imageURL: String?
    let permission: CollaboratorPermission?
    let isOwner: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: imageURL ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(
                            isOwner
                            ? AppTheme.Colors.primary.opacity(0.2)
                            : AppTheme.Colors.surface
                        )
                        .overlay(
                            Text(String(name.prefix(1)))
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(isOwner ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                        )
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                
                if isOwner {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                        .padding(2)
                        .background(Circle().fill(Color.white))
                        .offset(x: 4, y: 4)
                } else if let permission = permission {
                    Image(systemName: permission.iconName)
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Circle().fill(AppTheme.Colors.primary))
                        .offset(x: 4, y: 4)
                }
            }
            
            Text(name.components(separatedBy: " ").first ?? name)
                .font(AppTheme.Typography.caption2)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 60)
    }
}

// MARK: - Manage Collaborators View
struct ManageCollaboratorsView: View {
    let playlist: CollaborativePlaylist
    @StateObject private var service = CollaborativePlaylistService.shared
    @State private var showInvite = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Owner Section
                Section("Owner") {
                    HStack {
                        Circle()
                            .fill(AppTheme.Colors.primary.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.orange)
                            )
                        
                        VStack(alignment: .leading) {
                            Text("You")
                                .font(AppTheme.Typography.headline)
                            Text("Owner • Full control")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                }
                
                // Collaborators Section
                Section("Collaborators (\(playlist.collaborators.count))") {
                    ForEach(playlist.collaborators) { collaborator in
                        HStack {
                            AsyncImage(url: URL(string: collaborator.profileImageURL ?? "")) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle().fill(AppTheme.Colors.surface)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading) {
                                Text(collaborator.displayName)
                                    .font(AppTheme.Typography.headline)
                                Text("\(collaborator.permission.displayName) • \(collaborator.videosAdded) videos added")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            if playlist.ownerId == (AppState.shared.currentUser?.id ?? "") {
                                Menu {
                                    ForEach(CollaboratorPermission.allCases, id: \.self) { permission in
                                        Button {
                                            updatePermission(collaborator.userId, to: permission)
                                        } label: {
                                            if collaborator.permission == permission {
                                                Label(permission.displayName, systemImage: "checkmark")
                                            } else {
                                                Text(permission.displayName)
                                            }
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive) {
                                        removeCollaborator(collaborator.userId)
                                    } label: {
                                        Label("Remove", systemImage: "person.badge.minus")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                            }
                        }
                    }
                }
                
                // Invite Section
                if playlist.ownerId == (AppState.shared.currentUser?.id ?? "") || playlist.canInvite(userId: (AppState.shared.currentUser?.id ?? "")) {
                    Section {
                        Button {
                            showInvite = true
                        } label: {
                            Label("Invite Collaborator", systemImage: "person.badge.plus")
                        }
                    }
                }
            }
            .navigationTitle("Collaborators")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func updatePermission(_ userId: String, to permission: CollaboratorPermission) {
        Task {
            try? await service.updateCollaboratorPermission(playlistId: playlist.id, userId: userId, permission: permission)
        }
    }
    
    private func removeCollaborator(_ userId: String) {
        Task {
            try? await service.removeCollaborator(playlistId: playlist.id, userId: userId)
        }
    }
}

// MARK: - Activity Log View
struct ActivityLogView: View {
    let playlistId: String
    @StateObject private var service = CollaborativePlaylistService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(service.getActivityLog(for: playlistId)) { log in
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: log.action.iconName)
                            .foregroundColor(AppTheme.Colors.primary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.Colors.primary.opacity(0.1))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.details)
                                .font(AppTheme.Typography.subheadline)
                            
                            Text("\(log.username) • \(log.timestamp.formatted(.relative(presentation: .named)))")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Share Playlist Sheet
struct SharePlaylistSheet: View {
    let playlist: CollaborativePlaylist
    @State private var copied = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.xl) {
                Spacer()
                
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 48))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("Share Playlist")
                    .font(AppTheme.Typography.title2)
                
                Text("Share this code with friends so they can join your playlist")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Code Display
                Text(playlist.shareCode)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.primary)
                    .padding()
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(AppTheme.CornerRadius.lg)
                
                Button {
                    UIPasteboard.general.string = playlist.shareCode
                    copied = true
                    
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied!" : "Copy Code", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .modernButtonStyle()
                
                Text("Or share the link:")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
                
                Text(playlist.shareLink)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.primary)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

