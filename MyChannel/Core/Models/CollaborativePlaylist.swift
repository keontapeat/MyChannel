//
//  CollaborativePlaylist.swift
//  MyChannel
//
//  Created by AI Assistant on 11/28/25.
//

import SwiftUI

// MARK: - Collaborative Playlist Model
struct CollaborativePlaylist: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let thumbnailURL: String?
    let ownerId: String
    var collaborators: [PlaylistCollaborator]
    var videoItems: [PlaylistVideoItem]
    let isPublic: Bool
    let allowSuggestions: Bool // Non-collaborators can suggest videos
    let requireApproval: Bool // Owner must approve additions
    var pendingSuggestions: [PlaylistSuggestion]
    let shareCode: String // For easy sharing/joining
    let createdAt: Date
    let updatedAt: Date
    let category: PlaylistCategory
    
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        thumbnailURL: String? = nil,
        ownerId: String,
        collaborators: [PlaylistCollaborator] = [],
        videoItems: [PlaylistVideoItem] = [],
        isPublic: Bool = true,
        allowSuggestions: Bool = true,
        requireApproval: Bool = false,
        pendingSuggestions: [PlaylistSuggestion] = [],
        shareCode: String = String((0..<6).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! }),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        category: PlaylistCategory = .general
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.thumbnailURL = thumbnailURL
        self.ownerId = ownerId
        self.collaborators = collaborators
        self.videoItems = videoItems
        self.isPublic = isPublic
        self.allowSuggestions = allowSuggestions
        self.requireApproval = requireApproval
        self.pendingSuggestions = pendingSuggestions
        self.shareCode = shareCode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.category = category
    }
    
    // MARK: - Computed Properties
    var videoCount: Int {
        videoItems.count
    }
    
    var collaboratorCount: Int {
        collaborators.count + 1 // +1 for owner
    }
    
    var totalDuration: TimeInterval {
        videoItems.reduce(0) { $0 + $1.duration }
    }
    
    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
    
    var shareLink: String {
        "https://mychannel.app/playlist/join/\(shareCode)"
    }
    
    // MARK: - Permission Checks
    func canEdit(userId: String) -> Bool {
        if userId == ownerId { return true }
        return collaborators.first(where: { $0.userId == userId })?.permission.canEdit ?? false
    }
    
    func canAdd(userId: String) -> Bool {
        if userId == ownerId { return true }
        return collaborators.first(where: { $0.userId == userId })?.permission.canAdd ?? false
    }
    
    func canRemove(userId: String) -> Bool {
        if userId == ownerId { return true }
        return collaborators.first(where: { $0.userId == userId })?.permission.canRemove ?? false
    }
    
    func canInvite(userId: String) -> Bool {
        if userId == ownerId { return true }
        return collaborators.first(where: { $0.userId == userId })?.permission.canInvite ?? false
    }
}

// MARK: - Playlist Collaborator
struct PlaylistCollaborator: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let username: String
    let displayName: String
    let profileImageURL: String?
    let permission: CollaboratorPermission
    let joinedAt: Date
    let addedBy: String // userId who added this collaborator
    var videosAdded: Int
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        username: String,
        displayName: String,
        profileImageURL: String? = nil,
        permission: CollaboratorPermission = .contributor,
        joinedAt: Date = Date(),
        addedBy: String,
        videosAdded: Int = 0
    ) {
        self.id = id
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.profileImageURL = profileImageURL
        self.permission = permission
        self.joinedAt = joinedAt
        self.addedBy = addedBy
        self.videosAdded = videosAdded
    }
}

// MARK: - Collaborator Permission
enum CollaboratorPermission: String, Codable, CaseIterable {
    case viewer = "viewer"
    case contributor = "contributor"
    case editor = "editor"
    case admin = "admin"
    
    var displayName: String {
        switch self {
        case .viewer: return "Viewer"
        case .contributor: return "Contributor"
        case .editor: return "Editor"
        case .admin: return "Admin"
        }
    }
    
    var description: String {
        switch self {
        case .viewer: return "Can view the playlist"
        case .contributor: return "Can add videos"
        case .editor: return "Can add, remove, and reorder videos"
        case .admin: return "Full control including inviting others"
        }
    }
    
    var iconName: String {
        switch self {
        case .viewer: return "eye"
        case .contributor: return "plus.circle"
        case .editor: return "pencil"
        case .admin: return "crown"
        }
    }
    
    var canAdd: Bool {
        self != .viewer
    }
    
    var canRemove: Bool {
        self == .editor || self == .admin
    }
    
    var canEdit: Bool {
        self == .editor || self == .admin
    }
    
    var canInvite: Bool {
        self == .admin
    }
}

// MARK: - Playlist Video Item
struct PlaylistVideoItem: Identifiable, Codable, Equatable {
    let id: String
    let videoId: String
    let title: String
    let thumbnailURL: String
    let duration: TimeInterval
    let creatorName: String
    let addedBy: String // userId who added this video
    let addedByName: String
    let addedAt: Date
    var note: String? // Optional note from the person who added it
    var order: Int
    
    init(
        id: String = UUID().uuidString,
        videoId: String,
        title: String,
        thumbnailURL: String,
        duration: TimeInterval,
        creatorName: String,
        addedBy: String,
        addedByName: String,
        addedAt: Date = Date(),
        note: String? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.videoId = videoId
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.creatorName = creatorName
        self.addedBy = addedBy
        self.addedByName = addedByName
        self.addedAt = addedAt
        self.note = note
        self.order = order
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Playlist Suggestion
struct PlaylistSuggestion: Identifiable, Codable, Equatable {
    let id: String
    let videoId: String
    let title: String
    let thumbnailURL: String
    let duration: TimeInterval
    let suggestedBy: String
    let suggestedByName: String
    let suggestedAt: Date
    var note: String?
    var status: SuggestionStatus
    var reviewedBy: String?
    var reviewedAt: Date?
    
    init(
        id: String = UUID().uuidString,
        videoId: String,
        title: String,
        thumbnailURL: String,
        duration: TimeInterval,
        suggestedBy: String,
        suggestedByName: String,
        suggestedAt: Date = Date(),
        note: String? = nil,
        status: SuggestionStatus = .pending,
        reviewedBy: String? = nil,
        reviewedAt: Date? = nil
    ) {
        self.id = id
        self.videoId = videoId
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.suggestedBy = suggestedBy
        self.suggestedByName = suggestedByName
        self.suggestedAt = suggestedAt
        self.note = note
        self.status = status
        self.reviewedBy = reviewedBy
        self.reviewedAt = reviewedAt
    }
}

// MARK: - Suggestion Status
enum SuggestionStatus: String, Codable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .approved: return AppTheme.Colors.success
        case .rejected: return AppTheme.Colors.error
        }
    }
}

// MARK: - Activity Log Entry
struct PlaylistActivityLog: Identifiable, Codable {
    let id: String
    let playlistId: String
    let userId: String
    let username: String
    let action: PlaylistAction
    let details: String
    let timestamp: Date
    
    init(
        id: String = UUID().uuidString,
        playlistId: String,
        userId: String,
        username: String,
        action: PlaylistAction,
        details: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.playlistId = playlistId
        self.userId = userId
        self.username = username
        self.action = action
        self.details = details
        self.timestamp = timestamp
    }
}

// MARK: - Playlist Action
enum PlaylistAction: String, Codable {
    case created = "created"
    case videoAdded = "video_added"
    case videoRemoved = "video_removed"
    case videoReordered = "video_reordered"
    case collaboratorAdded = "collaborator_added"
    case collaboratorRemoved = "collaborator_removed"
    case permissionChanged = "permission_changed"
    case settingsChanged = "settings_changed"
    case suggestionApproved = "suggestion_approved"
    case suggestionRejected = "suggestion_rejected"
    
    var displayName: String {
        switch self {
        case .created: return "Created playlist"
        case .videoAdded: return "Added video"
        case .videoRemoved: return "Removed video"
        case .videoReordered: return "Reordered videos"
        case .collaboratorAdded: return "Added collaborator"
        case .collaboratorRemoved: return "Removed collaborator"
        case .permissionChanged: return "Changed permissions"
        case .settingsChanged: return "Updated settings"
        case .suggestionApproved: return "Approved suggestion"
        case .suggestionRejected: return "Rejected suggestion"
        }
    }
    
    var iconName: String {
        switch self {
        case .created: return "plus.circle.fill"
        case .videoAdded: return "plus.rectangle.fill"
        case .videoRemoved: return "minus.rectangle.fill"
        case .videoReordered: return "arrow.up.arrow.down"
        case .collaboratorAdded: return "person.badge.plus"
        case .collaboratorRemoved: return "person.badge.minus"
        case .permissionChanged: return "key.fill"
        case .settingsChanged: return "gearshape.fill"
        case .suggestionApproved: return "checkmark.circle.fill"
        case .suggestionRejected: return "xmark.circle.fill"
        }
    }
}

// MARK: - Sample Data
extension CollaborativePlaylist {
    static let samplePlaylists: [CollaborativePlaylist] = [
        CollaborativePlaylist(
            title: "🔥 Best Tech Videos 2025",
            description: "A collaborative collection of the best tech content this year. Add your favorites!",
            thumbnailURL: "https://picsum.photos/400/225?random=collab1",
            ownerId: "user-1",
            collaborators: [
                PlaylistCollaborator(
                    userId: "user-2",
                    username: "techguru",
                    displayName: "Tech Guru",
                    profileImageURL: "https://i.pravatar.cc/100?u=techguru",
                    permission: .editor,
                    addedBy: "user-1",
                    videosAdded: 12
                ),
                PlaylistCollaborator(
                    userId: "user-3",
                    username: "codemaster",
                    displayName: "Code Master",
                    profileImageURL: "https://i.pravatar.cc/100?u=codemaster",
                    permission: .contributor,
                    addedBy: "user-1",
                    videosAdded: 8
                ),
                PlaylistCollaborator(
                    userId: "user-4",
                    username: "devdesign",
                    displayName: "Dev & Design",
                    profileImageURL: "https://i.pravatar.cc/100?u=devdesign",
                    permission: .admin,
                    addedBy: "user-1",
                    videosAdded: 15
                )
            ],
            videoItems: [
                PlaylistVideoItem(
                    videoId: "vid-1",
                    title: "SwiftUI 5.0 - Everything New",
                    thumbnailURL: "https://picsum.photos/320/180?random=v1",
                    duration: 1245,
                    creatorName: "Apple Dev",
                    addedBy: "user-1",
                    addedByName: "You",
                    note: "Must watch for iOS devs!"
                ),
                PlaylistVideoItem(
                    videoId: "vid-2",
                    title: "AI Revolution in 2025",
                    thumbnailURL: "https://picsum.photos/320/180?random=v2",
                    duration: 890,
                    creatorName: "Tech Vision",
                    addedBy: "user-2",
                    addedByName: "Tech Guru"
                ),
                PlaylistVideoItem(
                    videoId: "vid-3",
                    title: "Building Apps with Vision Pro",
                    thumbnailURL: "https://picsum.photos/320/180?random=v3",
                    duration: 2100,
                    creatorName: "VR Masters",
                    addedBy: "user-3",
                    addedByName: "Code Master",
                    note: "Great spatial computing intro"
                )
            ],
            pendingSuggestions: [
                PlaylistSuggestion(
                    videoId: "vid-suggest-1",
                    title: "Rust for Swift Developers",
                    thumbnailURL: "https://picsum.photos/320/180?random=suggest1",
                    duration: 1560,
                    suggestedBy: "user-5",
                    suggestedByName: "RustFan",
                    note: "This explains Rust concepts using Swift analogies"
                )
            ],
            shareCode: "TECH25",
            category: .tutorials
        ),
        CollaborativePlaylist(
            title: "🎮 Gaming Squad Favorites",
            description: "Our group's favorite gaming moments and tutorials",
            thumbnailURL: "https://picsum.photos/400/225?random=collab2",
            ownerId: "user-1",
            collaborators: [
                PlaylistCollaborator(
                    userId: "user-5",
                    username: "progamer",
                    displayName: "Pro Gamer",
                    profileImageURL: "https://i.pravatar.cc/100?u=progamer",
                    permission: .contributor,
                    addedBy: "user-1",
                    videosAdded: 5
                )
            ],
            videoItems: [
                PlaylistVideoItem(
                    videoId: "vid-g1",
                    title: "Elden Ring Boss Guide",
                    thumbnailURL: "https://picsum.photos/320/180?random=g1",
                    duration: 3600,
                    creatorName: "Souls Master",
                    addedBy: "user-1",
                    addedByName: "You"
                )
            ],
            allowSuggestions: true,
            requireApproval: true,
            shareCode: "GAME99",
            category: .gaming
        )
    ]
}

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            Text("Collaborative Playlists")
                .font(AppTheme.Typography.largeTitle)
                .padding(.top)
            
            ForEach(CollaborativePlaylist.samplePlaylists) { playlist in
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: playlist.thumbnailURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(AppTheme.Colors.surface)
                        }
                        .frame(width: 100, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(playlist.title)
                                .font(AppTheme.Typography.headline)
                                .lineLimit(2)
                            
                            HStack(spacing: 8) {
                                Label("\(playlist.videoCount)", systemImage: "play.rectangle")
                                Label("\(playlist.collaboratorCount)", systemImage: "person.2")
                            }
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Collaborators
                    HStack(spacing: -8) {
                        ForEach(playlist.collaborators.prefix(4)) { collaborator in
                            AsyncImage(url: URL(string: collaborator.profileImageURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(AppTheme.Colors.surface)
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        }
                        
                        if playlist.collaborators.count > 4 {
                            Circle()
                                .fill(AppTheme.Colors.primary)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text("+\(playlist.collaborators.count - 4)")
                                        .font(AppTheme.Typography.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        }
                        
                        Spacer()
                        
                        // Share code
                        Text("Code: \(playlist.shareCode)")
                            .font(AppTheme.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.Colors.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.Colors.primary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    
                    // Pending suggestions badge
                    if !playlist.pendingSuggestions.isEmpty {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.orange)
                            Text("\(playlist.pendingSuggestions.count) pending suggestion(s)")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                .padding()
                .background(AppTheme.Colors.cardBackground)
                .cornerRadius(AppTheme.CornerRadius.lg)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
        }
        .padding()
    }
    .background(AppTheme.Colors.background)
}
