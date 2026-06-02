//
//  PlaylistManagementView.swift
//  MyChannel
//
//  100% COMPLETE PLAYLIST MANAGEMENT! 🎵
//  Create, edit, organize playlists like a PRO!
//

import SwiftUI

struct PlaylistManagementView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var playlistService = PlaylistFirestoreService.shared
    @State private var playlists: [Playlist] = []
    @State private var showingCreatePlaylist = false
    @State private var selectedPlaylist: Playlist?
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Stats
                playlistStatsHeader
                
                // Create Button
                createPlaylistButton
                
                // Playlists List
                if isLoading {
                    ProgressView("Loading playlists...")
                        .padding(40)
                } else if playlists.isEmpty {
                    emptyStateView
                } else {
                    playlistsSection
                }
                
                // Tips
                tipsSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("Playlists")
        .refreshable {
            await loadPlaylists()
        }
        .task {
            await loadPlaylists()
        }
        .sheet(isPresented: $showingCreatePlaylist) {
            StudioCreatePlaylistSheet(creatorId: appState.currentUser?.id ?? "") { _ in
                Task { await loadPlaylists() }
            }
        }
        .sheet(item: $selectedPlaylist) { playlist in
            StudioEditPlaylistSheet(playlist: playlist) {
                Task { await loadPlaylists() }
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadPlaylists() async {
        guard let userId = appState.currentUser?.id, !userId.isEmpty else {
            await MainActor.run {
                playlists = []
                isLoading = false
            }
            return
        }
        do {
            let loaded = try await playlistService.getPlaylists(for: userId)
            // Hydrate video counts from each playlist's membership subcollection.
            var hydrated: [Playlist] = []
            for playlist in loaded {
                let videoIds = (try? await playlistService.getPlaylistVideoIds(playlistId: playlist.id)) ?? []
                hydrated.append(
                    Playlist(
                        id: playlist.id,
                        title: playlist.title,
                        description: playlist.description,
                        thumbnailURL: playlist.thumbnailURL,
                        creatorId: playlist.creatorId,
                        videoIds: videoIds,
                        isPublic: playlist.isPublic,
                        createdAt: playlist.createdAt,
                        updatedAt: playlist.updatedAt,
                        tags: playlist.tags,
                        category: playlist.category
                    )
                )
            }
            await MainActor.run {
                playlists = hydrated
                isLoading = false
            }
        } catch {
            print("⚠️ [PlaylistManagement] Failed to load playlists: \(error.localizedDescription)")
            await MainActor.run { isLoading = false }
        }
    }
    
    private var totalPlaylistVideos: Int {
        playlists.reduce(0) { $0 + $1.videoCount }
    }
    
    private var playlistStatsHeader: some View {
        HStack(spacing: 12) {
            PlaylistStatsCard(title: "Playlists", value: "\(playlists.count)", icon: "list.bullet.rectangle", color: .blue)
            PlaylistStatsCard(title: "Total Videos", value: "\(totalPlaylistVideos)", icon: "play.rectangle", color: .green)
            PlaylistStatsCard(title: "Public", value: "\(playlists.filter { $0.isPublic }.count)", icon: "globe", color: AppTheme.Colors.accent)
        }
    }
    
    private var createPlaylistButton: some View {
        Button(action: { showingCreatePlaylist = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                Text("Create New Playlist")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundColor(.white)
            .padding(20)
            .background(LinearGradient(colors: [AppTheme.Colors.accent, AppTheme.Colors.primary], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Playlists Yet")
                .font(.system(size: 20, weight: .bold))
            Text("Organize your videos into playlists")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Button("Create Playlist") { showingCreatePlaylist = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }
    
    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Playlists")
                .font(.system(size: 20, weight: .semibold))
            ForEach(playlists) { playlist in
                PlaylistRow(playlist: playlist) {
                    selectedPlaylist = playlist
                }
            }
        }
    }
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill").foregroundColor(AppTheme.Colors.textSecondary)
                Text("Playlist Tips")
                    .font(.system(size: 18, weight: .semibold))
            }
            PlaylistTipRow(icon: "list.number", title: "Organize by theme", subtitle: "Group similar content together")
            PlaylistTipRow(icon: "clock", title: "Order matters", subtitle: "Put best videos first")
            PlaylistTipRow(icon: "eye", title: "Use good titles", subtitle: "Make playlists easy to find")
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// Using existing Playlist model from Core/Models/Playlist.swift

struct PlaylistRow: View {
    let playlist: Playlist
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "list.bullet.rectangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .frame(width: 50, height: 50)
                    .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.title)
                        .font(.system(size: 16, weight: .semibold))
                    Text("\(playlist.videoCount) videos")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StudioCreatePlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    let creatorId: String
    let onCreate: (Playlist) -> Void
    
    @StateObject private var playlistService = PlaylistFirestoreService.shared
    @State private var title = ""
    @State private var description = ""
    @State private var isPublic = true
    @State private var category: PlaylistCategory = .general
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Playlist Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    Picker("Category", selection: $category) {
                        ForEach(PlaylistCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                }
                Section("Visibility") {
                    Toggle("Public", isOn: $isPublic)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                }
                Section {
                    Button {
                        Task { await createPlaylist() }
                    } label: {
                        HStack {
                            if isSaving { ProgressView().padding(.trailing, 4) }
                            Text(isSaving ? "Creating…" : "Create Playlist")
                        }
                    }
                    .disabled(title.isEmpty || creatorId.isEmpty || isSaving)
                }
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func createPlaylist() async {
        guard !creatorId.isEmpty else {
            errorMessage = "Sign in required to create a playlist."
            return
        }
        isSaving = true
        errorMessage = nil
        do {
            let newId = try await playlistService.createPlaylist(
                userId: creatorId,
                title: title,
                description: description,
                category: category,
                visibility: isPublic ? "public" : "private"
            )
            let playlist = Playlist(
                id: newId,
                title: title,
                description: description,
                creatorId: creatorId,
                isPublic: isPublic,
                category: category
            )
            HapticManager.shared.notification(type: .success)
            onCreate(playlist)
            dismiss()
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }
}

struct StudioEditPlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    let playlist: Playlist
    var onChange: () -> Void = {}
    
    @StateObject private var playlistService = PlaylistFirestoreService.shared
    @State private var title: String
    @State private var description: String
    @State private var isPublic: Bool
    @State private var category: PlaylistCategory
    @State private var isSaving = false
    @State private var showingDeleteConfirm = false
    @State private var errorMessage: String?
    
    init(playlist: Playlist, onChange: @escaping () -> Void = {}) {
        self.playlist = playlist
        self.onChange = onChange
        _title = State(initialValue: playlist.title)
        _description = State(initialValue: playlist.description)
        _isPublic = State(initialValue: playlist.isPublic)
        _category = State(initialValue: playlist.category)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    Picker("Category", selection: $category) {
                        ForEach(PlaylistCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                }
                Section("Visibility") {
                    Toggle("Public", isOn: $isPublic)
                }
                Section("Stats") {
                    HStack {
                        Text("Videos")
                        Spacer()
                        Text("\(playlist.videoCount)")
                            .foregroundColor(.secondary)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                }
                Section {
                    Button {
                        Task { await saveChanges() }
                    } label: {
                        HStack {
                            if isSaving { ProgressView().padding(.trailing, 4) }
                            Text(isSaving ? "Saving…" : "Save Changes")
                        }
                    }
                    .disabled(title.isEmpty || isSaving)
                    
                    Button("Delete Playlist", role: .destructive) {
                        showingDeleteConfirm = true
                    }
                }
            }
            .navigationTitle("Edit Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Playlist?", isPresented: $showingDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await deletePlaylist() }
                }
            } message: {
                Text("This permanently removes the playlist. Your videos are not deleted.")
            }
        }
    }
    
    private func saveChanges() async {
        isSaving = true
        errorMessage = nil
        do {
            try await playlistService.updatePlaylist(
                id: playlist.id,
                title: title,
                description: description,
                category: category,
                visibility: isPublic ? "public" : "private",
                tags: playlist.tags
            )
            HapticManager.shared.notification(type: .success)
            onChange()
            dismiss()
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }
    
    private func deletePlaylist() async {
        isSaving = true
        errorMessage = nil
        do {
            try await playlistService.deletePlaylist(id: playlist.id)
            HapticManager.shared.notification(type: .success)
            onChange()
            dismiss()
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - PlaylistStatsCard
struct PlaylistStatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Playlist Tip Row
struct PlaylistTipRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
                .background(Color.blue.opacity(0.1), in: Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
