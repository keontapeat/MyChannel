//
//  CollaborativePlaylistService.swift
//  MyChannel
//
//  Created by AI Assistant on 11/28/25.
//

import SwiftUI
import Combine

// MARK: - Collaborative Playlist Service Protocol
protocol CollaborativePlaylistServiceProtocol {
    func getPlaylists(for userId: String) async throws -> [CollaborativePlaylist]
    func getPlaylist(id: String) async throws -> CollaborativePlaylist
    func createPlaylist(_ playlist: CollaborativePlaylist) async throws -> CollaborativePlaylist
    func updatePlaylist(_ playlist: CollaborativePlaylist) async throws -> CollaborativePlaylist
    func deletePlaylist(id: String) async throws
    func joinPlaylist(shareCode: String, userId: String) async throws -> CollaborativePlaylist
    func leavePlaylist(playlistId: String, userId: String) async throws
    func addCollaborator(playlistId: String, collaborator: PlaylistCollaborator) async throws
    func removeCollaborator(playlistId: String, userId: String) async throws
    func updateCollaboratorPermission(playlistId: String, userId: String, permission: CollaboratorPermission) async throws
    func addVideo(playlistId: String, video: PlaylistVideoItem) async throws
    func removeVideo(playlistId: String, videoItemId: String) async throws
    func reorderVideos(playlistId: String, videoIds: [String]) async throws
    func suggestVideo(playlistId: String, suggestion: PlaylistSuggestion) async throws
    func approveSuggestion(playlistId: String, suggestionId: String) async throws
    func rejectSuggestion(playlistId: String, suggestionId: String) async throws
}

// MARK: - Collaborative Playlist Service
@MainActor
class CollaborativePlaylistService: ObservableObject, CollaborativePlaylistServiceProtocol {
    static let shared = CollaborativePlaylistService()
    
    @Published var playlists: [CollaborativePlaylist] = []
    @Published var activityLog: [PlaylistActivityLog] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var currentUserId = "user-1" // Simulated current user
    
    private init() {
        loadSampleData()
    }
    
    private func loadSampleData() {
        playlists = CollaborativePlaylist.samplePlaylists
    }
    
    // MARK: - CRUD Operations
    func getPlaylists(for userId: String) async throws -> [CollaborativePlaylist] {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        return playlists.filter { playlist in
            playlist.ownerId == userId ||
            playlist.collaborators.contains(where: { $0.userId == userId })
        }
    }
    
    func getPlaylist(id: String) async throws -> CollaborativePlaylist {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        guard let playlist = playlists.first(where: { $0.id == id }) else {
            throw CollaborativePlaylistError.playlistNotFound
        }
        
        return playlist
    }
    
    func createPlaylist(_ playlist: CollaborativePlaylist) async throws -> CollaborativePlaylist {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        playlists.append(playlist)
        
        // Log activity
        logActivity(
            playlistId: playlist.id,
            userId: playlist.ownerId,
            username: "You",
            action: .created,
            details: "Created playlist \"\(playlist.title)\""
        )
        
        return playlist
    }
    
    func updatePlaylist(_ playlist: CollaborativePlaylist) async throws -> CollaborativePlaylist {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            throw CollaborativePlaylistError.playlistNotFound
        }
        
        playlists[index] = playlist
        
        logActivity(
            playlistId: playlist.id,
            userId: currentUserId,
            username: "You",
            action: .settingsChanged,
            details: "Updated playlist settings"
        )
        
        return playlist
    }
    
    func deletePlaylist(id: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        guard let index = playlists.firstIndex(where: { $0.id == id }) else {
            throw CollaborativePlaylistError.playlistNotFound
        }
        
        let playlist = playlists[index]
        guard playlist.ownerId == currentUserId else {
            throw CollaborativePlaylistError.notAuthorized
        }
        
        playlists.remove(at: index)
    }
    
    // MARK: - Join/Leave
    func joinPlaylist(shareCode: String, userId: String) async throws -> CollaborativePlaylist {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 400_000_000)
        
        guard let index = playlists.firstIndex(where: { $0.shareCode == shareCode }) else {
            throw CollaborativePlaylistError.invalidShareCode
        }
        
        var playlist = playlists[index]
        
        // Check if already a collaborator
        if playlist.collaborators.contains(where: { $0.userId == userId }) {
            throw CollaborativePlaylistError.alreadyCollaborator
        }
        
        let collaborator = PlaylistCollaborator(
            userId: userId,
            username: "newuser",
            displayName: "New User",
            permission: .contributor,
            addedBy: playlist.ownerId
        )
        
        playlist.collaborators.append(collaborator)
        playlists[index] = playlist
        
        logActivity(
            playlistId: playlist.id,
            userId: userId,
            username: collaborator.displayName,
            action: .collaboratorAdded,
            details: "\(collaborator.displayName) joined the playlist"
        )
        
        return playlist
    }
    
    func leavePlaylist(playlistId: String, userId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw CollaborativePlaylistError.playlistNotFound
        }
        
        var playlist = playlists[index]
        
        guard let collaboratorIndex = playlist.collaborators.firstIndex(where: { $0.userId == userId }) else {
            throw CollaborativePlaylistError.notCollaborator
        }
        
        let collaborator = playlist.collaborators[collaboratorIndex]
        playlist.collaborators.remove(at: collaboratorIndex)
        playlists[index] = playlist
        
        logActivity(
            playlistId: playlist.id,
            userId: userId,
            username: collaborator.displayName,
            action: .collaboratorRemoved,
            details: "\(collaborator.displayName) left the playlist"
        )
    }
    
    // MARK: - Collaborator Management
    func addCollaborator(playlistId: String, collaborator: PlaylistCollaborator) async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw CollaborativePlaylistError.playlistNotFound
        }
        
        var playlist = playlists[index]
        
        guard playlist.canInvite(userId: currentUserId) else {
            throw CollaborativePlaylistError.notAuthorized
        }
        
        playlist.collaborators.append(collaborator)
        playlists[index] = playlist
        
        logActivity(
            playlistId: playlist.id,
            userId: currentUserId,
            username: "You",
            action: .collaboratorAdded,
            details: "Added \(collaborator.displayName) as \(collaborator.permission.displayName)"
        )
    }
    
    func removeCollaborator(playlistId: String, userId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw CollaborativePlaylistError.playlistNotFound
        }
        
        var playlist = playlists[index]
        
        guard playlist.ownerId == currentUserId || playlist.canInvite(userId: currentUserId) else {
            throw CollaborativePlaylistError.notAuthorized
        }
        
        guard let collaboratorIndex = playlist.collaborators.firstIndex(where: { $0.userId == userId }) else {
            throw CollaborativePlaylistError.notCollaborator
        }
        
        let collaborator = playlist.collaborators[collaboratorIndex]
        playlist.collaborators.remove(at: collaboratorIndex)
        playlists[index] = playlist
        
        logActivity(
            playlistId: playlist.id,
            userId: currentUserId,
            username: "You",
            action: .collaboratorRemoved,
            details: "Removed \(collaborator.displayName)"
        )
    }
    
    func updateCollaboratorPermission(playlistId: String, userId: String, permission: CollaboratorPermission) async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        guard let playlistIndex = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw CollaborativePlaylistError.playlistNotFound
        }
        
        var playlist = playlists[playlistIndex]
        
        guard playlist.ownerId == currentUserId else {
            throw CollaborativePlaylistError.notAuthorized
        }
        
        guard let collaboratorIndex = playlist.collaborators.firstIndex(where: { $0.userId == userId }) else {
            throw CollaborativePlaylistError.notCollaborator
        }
        
        let oldPermission = playlist.collaborators[collaboratorIndex].permission
        let collaborator = playlist.collaborators[collaboratorIndex]
        
        let updatedCollaborator = PlaylistCollaborator(
            id: collaborator.id,
            userId: collaborator.userId,
            username: collaborator.username,
            displayName: collaborator.displayName,
            profileImageURL: collaborator.profileImageURL,
            permission: permission,
            joinedAt: collaborator.joinedAt,
            addedBy: collaborator.addedBy,
            videosAdded: collaborator.videosAdded
        )
        
        playlist.collaborators[collaboratorIndex] = updatedCollaborator
        playlists[playlistIndex] = playlist
        
        logActivity(
            playlistId: playlist.id,
            userId: currentUserId,
            username: "You",
            action: .permissionChanged,
            details: "Changed \(collaborator.displayName)'s permission from \(oldPermission.displayName) to \(permission.displayName)"
        )
    }
    
    // MARK: - Video Management
    func addVideo(playlistId: String, video: PlaylistVideoItem) async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw CollaborativePlaylistError.playlistNotFound
        }
        
        var playlist = playlists[index]
        
        guard playlist.canAdd(userId: currentUserId) else {
            throw CollaborativePlaylistError.notAuthorized
        }
        
        var newVideo = video
        newVideo.order = playlist.videoItems.count
        playlist.videoItems.append(newVideo)
        playlists[index] = playlist
        
        // Update collaborator's video count
        if let collabIndex = playlist.collaborators.firstIndex(where: { $0.userId == currentUserId }) {
            var collaborator = playlist.collaborators[collabIndex]
            collaborator.videosAdded += 1
            playlist.collaborators[collabIndex] = collaborator
            playlists[index] = playlist
        }
        
        logActivity(
            playlistId: playlist.id,
            userId: currentUserId,
            username: video.addedByName,
            action: .videoAdded,
            details: "Added \"\(video.title)\""
        )
    }
    
    func removeVideo(playlistId: String, videoItemId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw CollaborativePlaylistError.playlistNotFound
        }
        
        var playlist = playlists[index]
        
        guard playlist.canRemove(userId: currentUserId) else {
            throw CollaborativePlaylistError.notAuthorized
        }
        
        guard let videoIndex = playlist.videoItems.firstIndex(where: { $0.id == videoItemId }) else {
            throw CollaborativePlaylistError.videoNotFound
        }
        
        let video = playlist.videoItems[videoIndex]
        playlist.videoItems.remove(at: videoIndex)
        
        // Reorder remaining videos
        for i in 0..<playlist.videoItems.count {
            playlist.videoItems[i].order = i
        }
        
        playlists[index] = playlist
        
        logActivity(
            playlistId: playlist.id,
            userId: currentUserId,
            username: "You",
            action: .videoRemoved,
            details: "Removed \"\(video.title)\""
        )
    }
    
    func reorderVideos(playlistId: String, videoIds: [String]) async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw CollaborativePlaylistError.playlistNotFound
        }
        
        var playlist = playlists[index]
        
        guard playlist.canEdit(userId: currentUserId) else {
            throw CollaborativePlaylistError.notAuthorized
        }
        
        var reorderedVideos: [PlaylistVideoItem] = []
        for (newOrder, videoId) in videoIds.enumerated() {
            if var video = playlist.videoItems.first(where: { $0.id == videoId }) {
                video.order = newOrder
                reorderedVideos.append(video)
            }
        }
        
        playlist.videoItems = reorderedVideos
        playlists[index] = playlist
        
        logActivity(
            playlistId: playlist.id,
            userId: currentUserId,
            username: "You",
            action: .videoReordered,
            details: "Reordered videos"
        )
    }
    
    // MARK: - Suggestions
    func suggestVideo(playlistId: String, suggestion: PlaylistSuggestion) async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw CollaborativePlaylistError.playlistNotFound
        }
        
        var playlist = playlists[index]
        
        guard playlist.allowSuggestions else {
            throw CollaborativePlaylistError.suggestionsDisabled
        }
        
        playlist.pendingSuggestions.append(suggestion)
        playlists[index] = playlist
    }
    
    func approveSuggestion(playlistId: String, suggestionId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw CollaborativePlaylistError.playlistNotFound
        }
        
        var playlist = playlists[index]
        
        guard playlist.ownerId == currentUserId || playlist.canEdit(userId: currentUserId) else {
            throw CollaborativePlaylistError.notAuthorized
        }
        
        guard let suggestionIndex = playlist.pendingSuggestions.firstIndex(where: { $0.id == suggestionId }) else {
            throw CollaborativePlaylistError.suggestionNotFound
        }
        
        var suggestion = playlist.pendingSuggestions[suggestionIndex]
        suggestion.status = .approved
        suggestion.reviewedBy = currentUserId
        suggestion.reviewedAt = Date()
        
        // Convert suggestion to video item
        let videoItem = PlaylistVideoItem(
            videoId: suggestion.videoId,
            title: suggestion.title,
            thumbnailURL: suggestion.thumbnailURL,
            duration: suggestion.duration,
            creatorName: "Unknown",
            addedBy: suggestion.suggestedBy,
            addedByName: suggestion.suggestedByName,
            note: suggestion.note,
            order: playlist.videoItems.count
        )
        
        playlist.videoItems.append(videoItem)
        playlist.pendingSuggestions.remove(at: suggestionIndex)
        playlists[index] = playlist
        
        logActivity(
            playlistId: playlist.id,
            userId: currentUserId,
            username: "You",
            action: .suggestionApproved,
            details: "Approved suggestion \"\(suggestion.title)\" from \(suggestion.suggestedByName)"
        )
    }
    
    func rejectSuggestion(playlistId: String, suggestionId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else {
            throw CollaborativePlaylistError.playlistNotFound
        }
        
        var playlist = playlists[index]
        
        guard playlist.ownerId == currentUserId || playlist.canEdit(userId: currentUserId) else {
            throw CollaborativePlaylistError.notAuthorized
        }
        
        guard let suggestionIndex = playlist.pendingSuggestions.firstIndex(where: { $0.id == suggestionId }) else {
            throw CollaborativePlaylistError.suggestionNotFound
        }
        
        let suggestion = playlist.pendingSuggestions[suggestionIndex]
        playlist.pendingSuggestions.remove(at: suggestionIndex)
        playlists[index] = playlist
        
        logActivity(
            playlistId: playlist.id,
            userId: currentUserId,
            username: "You",
            action: .suggestionRejected,
            details: "Rejected suggestion \"\(suggestion.title)\" from \(suggestion.suggestedByName)"
        )
    }
    
    // MARK: - Activity Logging
    private func logActivity(playlistId: String, userId: String, username: String, action: PlaylistAction, details: String) {
        let log = PlaylistActivityLog(
            playlistId: playlistId,
            userId: userId,
            username: username,
            action: action,
            details: details
        )
        activityLog.insert(log, at: 0)
        
        // Keep only last 100 entries
        if activityLog.count > 100 {
            activityLog = Array(activityLog.prefix(100))
        }
    }
    
    func getActivityLog(for playlistId: String) -> [PlaylistActivityLog] {
        activityLog.filter { $0.playlistId == playlistId }
    }
}

// MARK: - Collaborative Playlist Error
enum CollaborativePlaylistError: LocalizedError {
    case playlistNotFound
    case invalidShareCode
    case alreadyCollaborator
    case notCollaborator
    case notAuthorized
    case videoNotFound
    case suggestionNotFound
    case suggestionsDisabled
    case maxCollaboratorsReached
    
    var errorDescription: String? {
        switch self {
        case .playlistNotFound: return "Playlist not found"
        case .invalidShareCode: return "Invalid share code"
        case .alreadyCollaborator: return "You are already a collaborator"
        case .notCollaborator: return "You are not a collaborator"
        case .notAuthorized: return "You don't have permission to perform this action"
        case .videoNotFound: return "Video not found in playlist"
        case .suggestionNotFound: return "Suggestion not found"
        case .suggestionsDisabled: return "Suggestions are disabled for this playlist"
        case .maxCollaboratorsReached: return "Maximum number of collaborators reached"
        }
    }
}
