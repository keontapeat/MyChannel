//
//  Playlist.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

// MARK: - Playlist Model
struct Playlist: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let thumbnailURL: String?
    let creatorId: String
    let videoIds: [String]
    let isPublic: Bool
    let createdAt: Date
    let updatedAt: Date
    let tags: [String]
    let category: PlaylistCategory
    
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        thumbnailURL: String? = nil,
        creatorId: String,
        videoIds: [String] = [],
        isPublic: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        tags: [String] = [],
        category: PlaylistCategory = .general
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.thumbnailURL = thumbnailURL
        self.creatorId = creatorId
        self.videoIds = videoIds
        self.isPublic = isPublic
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.category = category
    }
    
    // MARK: - Computed Properties
    var videoCount: Int {
        videoIds.count
    }
    
    var isEmpty: Bool {
        videoIds.isEmpty
    }
    
    // MARK: - Equatable
    static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Playlist Category Enum
enum PlaylistCategory: String, CaseIterable, Codable {
    case general = "general"
    case favorites = "favorites"
    case watchLater = "watch_later"
    case educational = "educational"
    case entertainment = "entertainment"
    case music = "music"
    case gaming = "gaming"
    case tutorials = "tutorials"
    case reviews = "reviews"
    case vlogs = "vlogs"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .favorites: return "Favorites"
        case .watchLater: return "Watch Later"
        case .educational: return "Educational"
        case .entertainment: return "Entertainment"
        case .music: return "Music"
        case .gaming: return "Gaming"
        case .tutorials: return "Tutorials"
        case .reviews: return "Reviews"
        case .vlogs: return "Vlogs"
        }
    }
    
    var iconName: String {
        switch self {
        case .general: return "folder"
        case .favorites: return "heart"
        case .watchLater: return "clock"
        case .educational: return "graduationcap"
        case .entertainment: return "tv"
        case .music: return "music.note"
        case .gaming: return "gamecontroller"
        case .tutorials: return "play.rectangle"
        case .reviews: return "star"
        case .vlogs: return "video"
        }
    }
}

// MARK: - Playlist Service Interface
protocol PlaylistServiceProtocol {
    func createPlaylist(_ playlist: Playlist) async throws -> Playlist
    func updatePlaylist(_ playlist: Playlist) async throws -> Playlist
    func deletePlaylist(id: String) async throws
    func getPlaylist(id: String) async throws -> Playlist
    func getPlaylists(for userId: String) async throws -> [Playlist]
    func addVideoToPlaylist(videoId: String, playlistId: String) async throws
    func removeVideoFromPlaylist(videoId: String, playlistId: String) async throws
    func reorderPlaylist(playlistId: String, videoIds: [String]) async throws
}

// MARK: - Mock Playlist Service
class MockPlaylistService: PlaylistServiceProtocol, ObservableObject {
    @Published var playlists: [Playlist] = Playlist.samplePlaylists
    @Published var isLoading = false
    
    func createPlaylist(_ playlist: Playlist) async throws -> Playlist {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            playlists.append(playlist)
        }
        
        return playlist
    }
    
    func updatePlaylist(_ playlist: Playlist) async throws -> Playlist {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw NSError(domain: "PlaylistError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Playlist not found"])
        }
        
        await MainActor.run {
            playlists[index] = playlist
        }
        
        return playlist
    }
    
    func deletePlaylist(id: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        await MainActor.run {
            playlists.removeAll { $0.id == id }
        }
    }
    
    func getPlaylist(id: String) async throws -> Playlist {
        guard let playlist = playlists.first(where: { $0.id == id }) else {
            throw NSError(domain: "PlaylistError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Playlist not found"])
        }
        return playlist
    }
    
    func getPlaylists(for userId: String) async throws -> [Playlist] {
        return playlists.filter { $0.creatorId == userId }
    }
    
    func addVideoToPlaylist(videoId: String, playlistId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw NSError(domain: "PlaylistError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Playlist not found"])
        }
        
        await MainActor.run {
            var updatedVideoIds = playlists[index].videoIds
            if !updatedVideoIds.contains(videoId) {
                updatedVideoIds.append(videoId)
                
                let updatedPlaylist = Playlist(
                    id: playlists[index].id,
                    title: playlists[index].title,
                    description: playlists[index].description,
                    thumbnailURL: playlists[index].thumbnailURL,
                    creatorId: playlists[index].creatorId,
                    videoIds: updatedVideoIds,
                    isPublic: playlists[index].isPublic,
                    createdAt: playlists[index].createdAt,
                    updatedAt: Date(),
                    tags: playlists[index].tags,
                    category: playlists[index].category
                )
                
                playlists[index] = updatedPlaylist
            }
        }
    }
    
    func removeVideoFromPlaylist(videoId: String, playlistId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw NSError(domain: "PlaylistError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Playlist not found"])
        }
        
        await MainActor.run {
            let updatedVideoIds = playlists[index].videoIds.filter { $0 != videoId }
            
            let updatedPlaylist = Playlist(
                id: playlists[index].id,
                title: playlists[index].title,
                description: playlists[index].description,
                thumbnailURL: playlists[index].thumbnailURL,
                creatorId: playlists[index].creatorId,
                videoIds: updatedVideoIds,
                isPublic: playlists[index].isPublic,
                createdAt: playlists[index].createdAt,
                updatedAt: Date(),
                tags: playlists[index].tags,
                category: playlists[index].category
            )
            
            playlists[index] = updatedPlaylist
        }
    }
    
    func reorderPlaylist(playlistId: String, videoIds: [String]) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw NSError(domain: "PlaylistError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Playlist not found"])
        }
        
        await MainActor.run {
            let updatedPlaylist = Playlist(
                id: playlists[index].id,
                title: playlists[index].title,
                description: playlists[index].description,
                thumbnailURL: playlists[index].thumbnailURL,
                creatorId: playlists[index].creatorId,
                videoIds: videoIds,
                isPublic: playlists[index].isPublic,
                createdAt: playlists[index].createdAt,
                updatedAt: Date(),
                tags: playlists[index].tags,
                category: playlists[index].category
            )
            
            playlists[index] = updatedPlaylist
        }
    }
}

// MARK: - Sample Data
extension Playlist {
    static let samplePlaylists: [Playlist] = [
        Playlist(
            title: "My Favorite Tech Videos",
            description: "A collection of the best technology videos I've found",
            thumbnailURL: "https://picsum.photos/400/225?random=playlist1",
            creatorId: "user-1",
            videoIds: Array(Video.sampleVideos.prefix(4).map { $0.id }),
            tags: ["technology", "programming", "tutorials"],
            category: .educational
        ),
        Playlist(
            title: "Chill Gaming Sessions",
            description: "Relaxing gaming content for unwinding",
            thumbnailURL: "https://picsum.photos/400/225?random=playlist2",
            creatorId: "user-1",
            videoIds: Array(Video.sampleVideos.filter { $0.category == .gaming }.map { $0.id }),
            tags: ["gaming", "chill", "relaxing"],
            category: .gaming
        ),
        Playlist(
            title: "Art Inspiration",
            description: "Beautiful digital art tutorials and timelapses",
            thumbnailURL: "https://picsum.photos/400/225?random=playlist3",
            creatorId: "user-1",
            videoIds: Array(Video.sampleVideos.filter { $0.category == .art }.map { $0.id }),
            tags: ["art", "digital", "tutorial", "inspiration"],
            category: .educational
        ),
        Playlist(
            title: "Music Production Masterclass",
            description: "Learn music production from the pros",
            thumbnailURL: "https://picsum.photos/400/225?random=playlist4",
            creatorId: "user-1",
            videoIds: Array(Video.sampleVideos.filter { $0.category == .music }.map { $0.id }),
            tags: ["music", "production", "beats", "tutorial"],
            category: .tutorials
        ),
        Playlist(
            title: "Watch Later",
            description: "Videos to watch when I have time",
            creatorId: "user-1",
            videoIds: Array(Video.sampleVideos.suffix(3).map { $0.id }),
            isPublic: false,
            category: .watchLater
        )
    ]
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            Text("Playlist System")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            ForEach(Playlist.samplePlaylists.prefix(3)) { playlist in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        AsyncImage(url: URL(string: playlist.thumbnailURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .aspectRatio(16/9, contentMode: .fill)
                                .overlay(
                                    Image(systemName: playlist.category.iconName)
                                        .font(.title)
                                        .foregroundColor(.secondary)
                                )
                        }
                        .frame(width: 120, height: 68)
                        .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(playlist.title)
                                .font(.headline)
                                .lineLimit(2)
                            
                            Text(playlist.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            
                            HStack {
                                Image(systemName: playlist.isPublic ? "globe" : "lock")
                                Text("\(playlist.videoCount) videos")
                                Spacer()
                                Text(playlist.category.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}