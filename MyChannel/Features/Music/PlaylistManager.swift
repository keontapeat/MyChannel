//
//  PlaylistManager.swift
//  MyChannel
//
//  Playlist Creation & Management - Full Featured
//

import SwiftUI
import Combine

// MARK: - Playlist Model

struct UserPlaylist: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var description: String?
    var coverImageURL: String?
    var coverColors: [String]? // Gradient colors if no image
    var tracks: [PlaylistTrack]
    var isPublic: Bool
    var isCollaborative: Bool
    var collaborators: [String]? // User IDs
    var createdAt: Date
    var updatedAt: Date
    var creatorID: String
    var creatorName: String
    var followerCount: Int
    var playCount: Int
    
    var trackCount: Int { tracks.count }
    var totalDuration: TimeInterval {
        tracks.reduce(0) { $0 + $1.duration }
    }
    
    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        }
        return "\(minutes) min"
    }
    
    static func == (lhs: UserPlaylist, rhs: UserPlaylist) -> Bool {
        lhs.id == rhs.id
    }
}

struct PlaylistTrack: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let artworkURL: String?
    let duration: TimeInterval
    let addedAt: Date
    let addedBy: String? // For collaborative playlists
    var isDownloaded: Bool = false
}

// MARK: - Playlist Service

@MainActor
final class PlaylistService: ObservableObject {
    static let shared = PlaylistService()
    
    @Published var playlists: [UserPlaylist] = []
    @Published var likedSongs: [PlaylistTrack] = []
    @Published var recentlyPlayed: [PlaylistTrack] = []
    @Published var isLoading: Bool = false
    
    private let playlistsKey = "user_playlists"
    private let likedSongsKey = "liked_songs"
    
    private init() {
        loadPlaylists()
        loadLikedSongs()
    }
    
    // MARK: - Playlist CRUD
    
    func createPlaylist(name: String, description: String? = nil, isPublic: Bool = false) -> UserPlaylist {
        let playlist = UserPlaylist(
            id: UUID().uuidString,
            name: name,
            description: description,
            coverImageURL: nil,
            coverColors: randomGradientColors(),
            tracks: [],
            isPublic: isPublic,
            isCollaborative: false,
            collaborators: nil,
            createdAt: Date(),
            updatedAt: Date(),
            creatorID: "current-user",
            creatorName: "You",
            followerCount: 0,
            playCount: 0
        )
        
        playlists.insert(playlist, at: 0)
        savePlaylists()
        return playlist
    }
    
    func deletePlaylist(_ playlist: UserPlaylist) {
        playlists.removeAll { $0.id == playlist.id }
        savePlaylists()
    }
    
    func updatePlaylist(_ playlist: UserPlaylist) {
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            var updated = playlist
            updated.updatedAt = Date()
            playlists[index] = updated
            savePlaylists()
        }
    }
    
    func addTrack(_ track: PlaylistTrack, to playlist: UserPlaylist) {
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            // Avoid duplicates
            if !playlists[index].tracks.contains(where: { $0.id == track.id }) {
                playlists[index].tracks.append(track)
                playlists[index].updatedAt = Date()
                savePlaylists()
            }
        }
    }
    
    func removeTrack(_ track: PlaylistTrack, from playlist: UserPlaylist) {
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            playlists[index].tracks.removeAll { $0.id == track.id }
            playlists[index].updatedAt = Date()
            savePlaylists()
        }
    }
    
    func reorderTracks(in playlist: UserPlaylist, from: IndexSet, to: Int) {
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            playlists[index].tracks.move(fromOffsets: from, toOffset: to)
            playlists[index].updatedAt = Date()
            savePlaylists()
        }
    }
    
    // MARK: - Liked Songs
    
    func likeSong(_ track: PlaylistTrack) {
        if !likedSongs.contains(where: { $0.id == track.id }) {
            likedSongs.insert(track, at: 0)
            saveLikedSongs()
        }
    }
    
    func unlikeSong(_ track: PlaylistTrack) {
        likedSongs.removeAll { $0.id == track.id }
        saveLikedSongs()
    }
    
    func isLiked(_ trackId: String) -> Bool {
        likedSongs.contains { $0.id == trackId }
    }
    
    func toggleLike(_ track: PlaylistTrack) {
        if isLiked(track.id) {
            unlikeSong(track)
        } else {
            likeSong(track)
        }
    }
    
    // MARK: - Collaborative
    
    func makeCollaborative(_ playlist: UserPlaylist, collaborators: [String]) {
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            playlists[index].isCollaborative = true
            playlists[index].collaborators = collaborators
            playlists[index].updatedAt = Date()
            savePlaylists()
        }
    }
    
    // MARK: - Persistence
    
    private func savePlaylists() {
        if let encoded = try? JSONEncoder().encode(playlists) {
            UserDefaults.standard.set(encoded, forKey: playlistsKey)
        }
    }
    
    private func loadPlaylists() {
        if let data = UserDefaults.standard.data(forKey: playlistsKey),
           let decoded = try? JSONDecoder().decode([UserPlaylist].self, from: data) {
            playlists = decoded
        }
    }
    
    private func saveLikedSongs() {
        if let encoded = try? JSONEncoder().encode(likedSongs) {
            UserDefaults.standard.set(encoded, forKey: likedSongsKey)
        }
    }
    
    private func loadLikedSongs() {
        if let data = UserDefaults.standard.data(forKey: likedSongsKey),
           let decoded = try? JSONDecoder().decode([PlaylistTrack].self, from: data) {
            likedSongs = decoded
        }
    }
    
    private func randomGradientColors() -> [String] {
        let colorSets = [
            ["#FF6B6B", "#C44569"],
            ["#4ECDC4", "#2C3E50"],
            ["#F093FB", "#F5576C"],
            ["#4776E6", "#8E54E9"],
            ["#11998E", "#38EF7D"],
            ["#FC466B", "#3F5EFB"],
            ["#00C9FF", "#92FE9D"],
            ["#F857A6", "#FF5858"]
        ]
        return colorSets.randomElement() ?? ["#FF6B6B", "#C44569"]
    }
}

// MARK: - Create Playlist Sheet

struct MusicCreatePlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playlistService = PlaylistService.shared
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var isPublic: Bool = false
    @FocusState private var isNameFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Playlist name", text: $name)
                        .focused($isNameFocused)
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                Section {
                    Toggle("Make public", isOn: $isPublic)
                } footer: {
                    Text("Public playlists can be discovered by other users.")
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        _ = playlistService.createPlaylist(
                            name: name.isEmpty ? "My Playlist" : name,
                            description: description.isEmpty ? nil : description,
                            isPublic: isPublic
                        )
                        HapticManager.shared.notification(type: .success)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
    }
}

// MARK: - Playlist Detail View

struct MusicPlaylistDetailView: View {
    @StateObject private var playlistService = PlaylistService.shared
    @ObservedObject private var player = AudioPreviewPlayer.shared
    @State var playlist: UserPlaylist
    @State private var showEditSheet: Bool = false
    @State private var showAddSongs: Bool = false
    @State private var showShareSheet: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                playlistHeader
                
                // Action buttons
                actionButtons
                    .padding(.top, 20)
                
                // Tracks
                if playlist.tracks.isEmpty {
                    emptyState
                        .padding(.top, 60)
                } else {
                    tracksList
                        .padding(.top, 20)
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button {
                        showAddSongs = true
                    } label: {
                        Label("Add Songs", systemImage: "plus")
                    }
                    
                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    if playlist.isCollaborative {
                        Button {
                            // Manage collaborators
                        } label: {
                            Label("Collaborators", systemImage: "person.2")
                        }
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        playlistService.deletePlaylist(playlist)
                        dismiss()
                    } label: {
                        Label("Delete Playlist", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            MusicEditPlaylistSheet(playlist: $playlist)
        }
        .sheet(isPresented: $showAddSongs) {
            AddSongsSheet(playlist: $playlist)
        }
    }
    
    private var playlistHeader: some View {
        VStack(spacing: 16) {
            // Cover
            ZStack {
                if let colors = playlist.coverColors, colors.count >= 2 {
                    LinearGradient(
                        colors: colors.map { Color(hexString: $0) ?? .gray },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else if let imageURL = playlist.coverImageURL {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray
                    }
                } else {
                    Color.gray
                }
                
                if playlist.tracks.isEmpty {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            
            // Info
            VStack(spacing: 8) {
                Text(playlist.name)
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                
                if let description = playlist.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                HStack(spacing: 4) {
                    Text(playlist.creatorName)
                        .fontWeight(.semibold)
                    Text("•")
                    Text("\(playlist.trackCount) songs")
                    Text("•")
                    Text(playlist.formattedDuration)
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                
                if playlist.isCollaborative {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                        Text("Collaborative")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
                }
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, 20)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Play button
            Button {
                // Play all tracks
                HapticManager.shared.impact(style: .medium)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Play")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // Shuffle button
            Button {
                HapticManager.shared.impact(style: .medium)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "shuffle")
                    Text("Shuffle")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.Colors.primary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No songs yet")
                .font(.system(size: 18, weight: .semibold))
            
            Text("Start adding songs to your playlist")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Button {
                showAddSongs = true
            } label: {
                Text("Add Songs")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.Colors.primary)
                    .clipShape(Capsule())
            }
        }
    }
    
    private var tracksList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(playlist.tracks.enumerated()), id: \.element.id) { index, track in
                PlaylistTrackRow(track: track, index: index + 1) {
                    // Play track
                    HapticManager.shared.impact(style: .medium)
                } onRemove: {
                    withAnimation {
                        playlistService.removeTrack(track, from: playlist)
                        if let updated = playlistService.playlists.first(where: { $0.id == playlist.id }) {
                            playlist = updated
                        }
                    }
                    HapticManager.shared.notification(type: .warning)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Playlist Track Row

struct PlaylistTrackRow: View {
    let track: PlaylistTrack
    let index: Int
    let onPlay: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            if let url = track.artworkURL {
                AsyncImage(url: URL(string: url)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 15))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    if track.isDownloaded {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                    Text(track.artist)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Menu {
                Button {
                    onPlay()
                } label: {
                    Label("Play", systemImage: "play")
                }
                Button {
                    // Add to queue
                } label: {
                    Label("Add to Queue", systemImage: "text.badge.plus")
                }
                Divider()
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onPlay()
        }
    }
}

// MARK: - Edit Playlist Sheet

struct MusicEditPlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playlistService = PlaylistService.shared
    @Binding var playlist: UserPlaylist
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var isPublic: Bool = false
    @State private var isCollaborative: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                Section {
                    Toggle("Public", isOn: $isPublic)
                    Toggle("Collaborative", isOn: $isCollaborative)
                }
            }
            .navigationTitle("Edit Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        var updated = playlist
                        updated.name = name
                        updated.description = description.isEmpty ? nil : description
                        updated.isPublic = isPublic
                        updated.isCollaborative = isCollaborative
                        playlistService.updatePlaylist(updated)
                        playlist = updated
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                name = playlist.name
                description = playlist.description ?? ""
                isPublic = playlist.isPublic
                isCollaborative = playlist.isCollaborative
            }
        }
    }
}

// MARK: - Add Songs Sheet

struct AddSongsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playlistService = PlaylistService.shared
    @Binding var playlist: UserPlaylist
    @State private var searchText: String = ""
    @State private var searchResults: [CatalogSong] = []
    @State private var isSearching: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search songs", text: $searchText)
                        .onSubmit {
                            Task { await search() }
                        }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()
                
                if isSearching {
                    ProgressView()
                        .padding(.top, 40)
                    Spacer()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No results found")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)
                    Spacer()
                } else {
                    List {
                        ForEach(searchResults, id: \.id) { song in
                            AddSongRow(song: song) {
                                let track = PlaylistTrack(
                                    id: String(song.id),
                                    title: song.title,
                                    artist: song.artist,
                                    album: song.collectionName,
                                    artworkURL: song.artworkUrl,
                                    duration: 180, // Default
                                    addedAt: Date(),
                                    addedBy: nil
                                )
                                playlistService.addTrack(track, to: playlist)
                                if let updated = playlistService.playlists.first(where: { $0.id == playlist.id }) {
                                    playlist = updated
                                }
                                HapticManager.shared.notification(type: .success)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func search() async {
        guard !searchText.isEmpty else { return }
        isSearching = true
        if let results = try? await MusicCatalogService.shared.searchSongs(term: searchText, limit: 30) {
            searchResults = results
        }
        isSearching = false
    }
}

// MARK: - Add Song Row

struct AddSongRow: View {
    let song: CatalogSong
    let onAdd: () -> Void
    @State private var isAdded: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: song.artworkUrl ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.system(size: 15))
                    .lineLimit(1)
                Text(song.artist)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                isAdded = true
                onAdd()
            } label: {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 24))
                    .foregroundColor(isAdded ? .green : AppTheme.Colors.primary)
            }
            .disabled(isAdded)
        }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

// MARK: - My Library View (Playlists Tab)

struct MyLibraryView: View {
    @StateObject private var playlistService = PlaylistService.shared
    @State private var showCreatePlaylist: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Liked Songs
                    NavigationLink {
                        LikedSongsView()
                    } label: {
                        LikedSongsCard(count: playlistService.likedSongs.count)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Playlists
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Playlists")
                                .font(.system(size: 22, weight: .bold))
                            Spacer()
                            Button {
                                showCreatePlaylist = true
                                HapticManager.shared.impact(style: .light)
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .semibold))
                            }
                        }
                        
                        if playlistService.playlists.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                Text("No playlists yet")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                Button {
                                    showCreatePlaylist = true
                                } label: {
                                    Text("Create Playlist")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(playlistService.playlists) { playlist in
                                    NavigationLink {
                                        MusicPlaylistDetailView(playlist: playlist)
                                    } label: {
                                        PlaylistRowCard(playlist: playlist)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Your Library")
            .sheet(isPresented: $showCreatePlaylist) {
                MusicCreatePlaylistSheet()
            }
        }
    }
}

// MARK: - Liked Songs Card

struct LikedSongsCard: View {
    let count: Int
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "heart.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
            .frame(width: 70, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Liked Songs")
                    .font(.system(size: 18, weight: .semibold))
                Text("\(count) songs")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Playlist Row Card

struct PlaylistRowCard: View {
    let playlist: UserPlaylist
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                if let colors = playlist.coverColors, colors.count >= 2 {
                    LinearGradient(
                        colors: colors.map { Color(hexString: $0) ?? .gray },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color.gray
                }
                
                if playlist.tracks.isEmpty {
                    Image(systemName: "music.note")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.system(size: 16, weight: .semibold))
                HStack(spacing: 4) {
                    if playlist.isCollaborative {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    }
                    Text("\(playlist.trackCount) songs")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Liked Songs View

struct LikedSongsView: View {
    @StateObject private var playlistService = PlaylistService.shared
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(playlistService.likedSongs.enumerated()), id: \.element.id) { index, track in
                    PlaylistTrackRow(track: track, index: index + 1) {
                        HapticManager.shared.impact(style: .medium)
                    } onRemove: {
                        playlistService.unlikeSong(track)
                        HapticManager.shared.notification(type: .warning)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .navigationTitle("Liked Songs")
    }
}

