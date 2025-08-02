//
//  PlaylistsView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct PlaylistsView: View {
    @StateObject private var playlistService = MockPlaylistService()
    @State private var showingCreatePlaylist = false
    @State private var searchText = ""
    @State private var selectedCategory: PlaylistCategory?
    
    var filteredPlaylists: [Playlist] {
        var playlists = playlistService.playlists
        
        if !searchText.isEmpty {
            playlists = playlists.filter { playlist in
                playlist.title.localizedCaseInsensitiveContains(searchText) ||
                playlist.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if let selectedCategory = selectedCategory {
            playlists = playlists.filter { $0.category == selectedCategory }
        }
        
        return playlists.sorted { $0.updatedAt > $1.updatedAt }
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
                CreatePlaylistView(playlistService: playlistService)
            }
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
                        NavigationLink(destination: PlaylistDetailView(playlist: playlist, playlistService: playlistService)) {
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
                try await playlistService.deletePlaylist(id: playlist.id)
            } catch {
                print("Error deleting playlist: \(error)")
            }
        }
    }
    
    private func editPlaylist(_ playlist: Playlist) {
        // TODO: Show edit playlist sheet
        print("Edit playlist: \(playlist.title)")
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
            creatorId: "current-user-id",
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

#Preview {
    PlaylistsView()
}