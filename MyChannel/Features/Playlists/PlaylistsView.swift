//
//  PlaylistsView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct PlaylistsView: View {
    @StateObject private var fsService = PlaylistFirestoreService.shared
    @State private var showingCreatePlaylist = false
    @State private var editingPlaylist: Playlist? = nil
    @State private var searchText = ""
    @State private var selectedCategory: PlaylistCategory?
    @State private var playlists: [Playlist] = []
    
    var filteredPlaylists: [Playlist] {
        var result = playlists
        
        if !searchText.isEmpty {
            result = result.filter { playlist in
                playlist.title.localizedCaseInsensitiveContains(searchText) ||
                playlist.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if let selectedCategory = selectedCategory {
            result = result.filter { $0.category == selectedCategory }
        }
        
        return result.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and Filter
                searchAndFilterSection
                
                // Category Filter
                categoryFilterSection
                
                // Playlists List
                playlistsListSection
            }
            .navigationTitle("Playlists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCreatePlaylist = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $showingCreatePlaylist) {
                CreatePlaylistViewFirestore()
            }
            .sheet(item: $editingPlaylist) { playlist in
                EditPlaylistSheet(playlist: playlist) { updated in
                    if let idx = playlists.firstIndex(where: { $0.id == updated.id }) {
                        playlists[idx] = updated
                    }
                }
            }
            .task {
                await loadPlaylists()
            }
            .refreshable {
                await loadPlaylists()
            }
        }
    }
    
    private func loadPlaylists() async {
        guard let userId = AppState.shared.currentUser?.id else { return }
        do {
            playlists = try await fsService.getPlaylists(for: userId)
        } catch {
            print("⚠️ [PlaylistsView] Failed to load playlists: \(error.localizedDescription)")
        }
    }
    
    private var searchAndFilterSection: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search playlists...", text: $searchText)
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
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All Categories
                CategoryFilterChip(
                    title: "All",
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )
                
                // Individual Categories
                ForEach(PlaylistCategory.allCases, id: \.self) { category in
                    CategoryFilterChip(
                        title: category.displayName,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
    }
    
    private var playlistsListSection: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if filteredPlaylists.isEmpty {
                    emptyPlaylistsView
                } else {
                    ForEach(filteredPlaylists) { playlist in
                        NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                            PlaylistCard(
                                playlist: playlist,
                                onDelete: { deletePlaylist(playlist) },
                                onEdit: { editPlaylist(playlist) }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }
    
    private var emptyPlaylistsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Playlists Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create your first playlist to organize your favorite videos")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Create Playlist") {
                showingCreatePlaylist = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 60)
    }
    
    // MARK: - Actions
    private func deletePlaylist(_ playlist: Playlist) {
        Task {
            do {
                try await fsService.deletePlaylist(id: playlist.id)
                await loadPlaylists()
            } catch {
                print("Error deleting playlist: \(error)")
            }
        }
    }
    
    private func editPlaylist(_ playlist: Playlist) {
        editingPlaylist = playlist
    }
}

// MARK: - Category Filter Chip
struct CategoryFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Playlist Card
struct PlaylistCard: View {
    let playlist: Playlist
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    @State private var showingActionSheet = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            AsyncImage(url: URL(string: playlist.thumbnailURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        VStack {
                            Image(systemName: playlist.category.iconName)
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("\(playlist.videoCount)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                    )
            }
            .frame(width: 120, height: 68)
            .cornerRadius(8)
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(playlist.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if !playlist.isPublic {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(playlist.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Spacer()
                
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: playlist.category.iconName)
                        Text(playlist.category.displayName)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(playlist.videoCount) videos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: { showingActionSheet = true }) {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .confirmationDialog("Playlist Options", isPresented: $showingActionSheet) {
            Button("Edit") { onEdit() }
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Create Playlist View
struct CreatePlaylistView: View {
    @ObservedObject var playlistService: MockPlaylistService
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedCategory: PlaylistCategory = .general
    @State private var isPublic = true
    @State private var tags = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Playlist Details") {
                    TextField("Playlist Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                Section("Settings") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(PlaylistCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.iconName)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                    
                    Toggle("Public Playlist", isOn: $isPublic)
                }
                
                Section("Tags") {
                    TextField("Add tags (comma separated)", text: $tags)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section {
                    Button("Create Playlist") {
                        createPlaylist()
                    }
                    .disabled(title.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createPlaylist() {
        let tagArray = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        
        let newPlaylist = Playlist(
            title: title,
            description: description,
            creatorId: AppState.shared.currentUser?.id ?? "",
            isPublic: isPublic,
            tags: tagArray,
            category: selectedCategory
        )
        
        Task {
            do {
                _ = try await playlistService.createPlaylist(newPlaylist)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error creating playlist: \(error)")
            }
        }
    }
}

// MARK: - Create Playlist View (Firestore)
struct CreatePlaylistViewFirestore: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var selectedCategory: PlaylistCategory = .general
    @State private var isPublic = true
    @State private var tags = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Playlist Details") {
                    TextField("Playlist Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical).lineLimit(3...6)
                }
                Section("Settings") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(PlaylistCategory.allCases, id: \.self) { c in HStack { Image(systemName: c.iconName); Text(c.displayName) }.tag(c) }
                    }
                    Toggle("Public Playlist", isOn: $isPublic)
                }
                Section("Tags") { TextField("Add tags (comma separated)", text: $tags) }
                Section { Button("Create", action: create).disabled(title.isEmpty).buttonStyle(.borderedProminent).frame(maxWidth: .infinity) }
            }
            .navigationTitle("New Playlist")
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
        }
    }
    private func create() {
        guard let uid = AppState.shared.currentUser?.id else { return }
        Task {
            let _ = try? await PlaylistFirestoreService.shared.createPlaylist(userId: uid, title: title, description: description, category: selectedCategory, visibility: isPublic ? "public" : "private")
            await MainActor.run { dismiss() }
        }
    }
}

#Preview {
    PlaylistsView()
}

// MARK: - Edit Playlist Sheet

struct EditPlaylistSheet: View {
    let playlist: Playlist
    let onSave: (Playlist) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var description: String
    @State private var isPublic: Bool
    @State private var saving = false

    init(playlist: Playlist, onSave: @escaping (Playlist) -> Void) {
        self.playlist = playlist
        self.onSave = onSave
        _title = State(initialValue: playlist.title)
        _description = State(initialValue: playlist.description)
        _isPublic = State(initialValue: playlist.isPublic)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Privacy") {
                    Toggle("Public playlist", isOn: $isPublic)
                }
            }
            .navigationTitle("Edit Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveChanges() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveChanges() {
        saving = true
        Task {
            do {
                let updated = Playlist(
                    id: playlist.id,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    thumbnailURL: playlist.thumbnailURL,
                    creatorId: playlist.creatorId,
                    videoIds: playlist.videoIds,
                    songIds: playlist.songIds,
                    isPublic: isPublic,
                    createdAt: playlist.createdAt,
                    updatedAt: Date(),
                    tags: playlist.tags,
                    category: playlist.category
                )
                try await PlaylistFirestoreService.shared.updatePlaylist(
                    id: updated.id,
                    title: updated.title,
                    description: updated.description,
                    category: updated.category,
                    visibility: updated.isPublic ? "public" : "private",
                    tags: updated.tags
                )
                await MainActor.run {
                    onSave(updated)
                    dismiss()
                }
            } catch {
                print("❌ EditPlaylistSheet save error: \(error)")
            }
            saving = false
        }
    }
}
