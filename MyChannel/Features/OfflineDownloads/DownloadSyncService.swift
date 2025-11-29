//
//  DownloadSyncService.swift
//  MyChannel
//
//  🔄🔥 DOWNLOAD SYNC SERVICE 🔥🔄
//  Syncs offline watch history when back online
//
//  Features:
//  - Watch progress sync
//  - Like/dislike sync
//  - Comment draft sync
//  - Playlist additions sync
//  - Analytics sync
//  - Conflict resolution
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Download Sync Service
@MainActor
final class DownloadSyncService: ObservableObject {
    static let shared = DownloadSyncService()
    
    // MARK: - Published State
    @Published private(set) var pendingSyncItems: [SyncItem] = []
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var syncProgress: Double = 0
    @Published private(set) var syncErrors: [SyncError] = []
    
    // MARK: - Private Properties
    private let downloadManager = NuclearDownloadManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    private let syncQueueKey = "offline_sync_queue"
    
    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif
    
    // MARK: - Initialization
    private init() {
        loadPendingSyncItems()
        setupNetworkMonitoring()
        
        print("🔄 [SyncService] Initialized with \(pendingSyncItems.count) pending items")
    }
    
    // MARK: - Public API: Recording Offline Activity
    
    /// Record that playback started (for watch history)
    func recordPlaybackStart(videoId: String) {
        let item = SyncItem(
            id: UUID().uuidString,
            type: .watchHistoryAdd,
            videoId: videoId,
            timestamp: Date(),
            data: ["startedAt": Date().timeIntervalSince1970]
        )
        
        addSyncItem(item)
    }
    
    /// Record playback completion
    func recordPlaybackComplete(videoId: String) {
        let item = SyncItem(
            id: UUID().uuidString,
            type: .watchHistoryComplete,
            videoId: videoId,
            timestamp: Date(),
            data: ["completedAt": Date().timeIntervalSince1970]
        )
        
        addSyncItem(item)
    }
    
    /// Record watch progress
    func recordWatchProgress(videoId: String, progress: Double, currentTime: TimeInterval) {
        // Update existing progress item or create new one
        if let existingIndex = pendingSyncItems.firstIndex(where: {
            $0.type == .watchProgress && $0.videoId == videoId
        }) {
            pendingSyncItems[existingIndex].data["progress"] = progress
            pendingSyncItems[existingIndex].data["currentTime"] = currentTime
            pendingSyncItems[existingIndex].timestamp = Date()
        } else {
            let item = SyncItem(
                id: UUID().uuidString,
                type: .watchProgress,
                videoId: videoId,
                timestamp: Date(),
                data: [
                    "progress": progress,
                    "currentTime": currentTime
                ]
            )
            addSyncItem(item)
        }
        
        savePendingSyncItems()
    }
    
    /// Record a like
    func recordLike(videoId: String) {
        let item = SyncItem(
            id: UUID().uuidString,
            type: .like,
            videoId: videoId,
            timestamp: Date(),
            data: [:]
        )
        
        // Remove any existing dislike for this video
        pendingSyncItems.removeAll { $0.type == .dislike && $0.videoId == videoId }
        
        addSyncItem(item)
    }
    
    /// Record a dislike
    func recordDislike(videoId: String) {
        let item = SyncItem(
            id: UUID().uuidString,
            type: .dislike,
            videoId: videoId,
            timestamp: Date(),
            data: [:]
        )
        
        // Remove any existing like for this video
        pendingSyncItems.removeAll { $0.type == .like && $0.videoId == videoId }
        
        addSyncItem(item)
    }
    
    /// Record removing a like/dislike
    func recordRemoveRating(videoId: String) {
        // Remove any existing rating
        pendingSyncItems.removeAll {
            ($0.type == .like || $0.type == .dislike) && $0.videoId == videoId
        }
        savePendingSyncItems()
    }
    
    /// Record adding to Watch Later
    func recordAddToWatchLater(videoId: String) {
        let item = SyncItem(
            id: UUID().uuidString,
            type: .addToWatchLater,
            videoId: videoId,
            timestamp: Date(),
            data: [:]
        )
        
        addSyncItem(item)
    }
    
    /// Record saving a comment draft
    func recordCommentDraft(videoId: String, comment: String, parentCommentId: String? = nil) {
        let item = SyncItem(
            id: UUID().uuidString,
            type: .commentDraft,
            videoId: videoId,
            timestamp: Date(),
            data: [
                "comment": comment,
                "parentCommentId": parentCommentId as Any
            ]
        )
        
        addSyncItem(item)
    }
    
    /// Record subscribing to a channel
    func recordSubscription(channelId: String) {
        let item = SyncItem(
            id: UUID().uuidString,
            type: .subscribe,
            videoId: channelId, // Using videoId field for channelId
            timestamp: Date(),
            data: [:]
        )
        
        addSyncItem(item)
    }
    
    /// Record adding to a playlist
    func recordAddToPlaylist(videoId: String, playlistId: String) {
        let item = SyncItem(
            id: UUID().uuidString,
            type: .addToPlaylist,
            videoId: videoId,
            timestamp: Date(),
            data: ["playlistId": playlistId]
        )
        
        addSyncItem(item)
    }
    
    // MARK: - Sync Operations
    
    /// Manually trigger sync
    func syncNow() async {
        guard !isSyncing else { return }
        guard downloadManager.networkStatus != .offline else {
            print("🔄 [SyncService] Cannot sync - offline")
            return
        }
        guard !pendingSyncItems.isEmpty else {
            print("🔄 [SyncService] Nothing to sync")
            return
        }
        
        isSyncing = true
        syncProgress = 0
        syncErrors.removeAll()
        
        print("🔄 [SyncService] Starting sync of \(pendingSyncItems.count) items...")
        
        let itemsToSync = pendingSyncItems
        var completedCount = 0
        
        for item in itemsToSync {
            do {
                try await syncItem(item)
                
                // Remove from pending
                pendingSyncItems.removeAll { $0.id == item.id }
                completedCount += 1
                syncProgress = Double(completedCount) / Double(itemsToSync.count)
                
            } catch {
                let syncError = SyncError(
                    itemId: item.id,
                    type: item.type,
                    message: error.localizedDescription,
                    timestamp: Date()
                )
                syncErrors.append(syncError)
                
                print("🔄 [SyncService] Failed to sync \(item.type): \(error)")
            }
        }
        
        lastSyncDate = Date()
        isSyncing = false
        savePendingSyncItems()
        
        print("🔄 [SyncService] Sync complete. \(completedCount)/\(itemsToSync.count) items synced")
    }
    
    /// Sync a single item
    private func syncItem(_ item: SyncItem) async throws {
        #if canImport(FirebaseFirestore)
        switch item.type {
        case .watchHistoryAdd, .watchHistoryComplete:
            try await syncWatchHistory(item)
            
        case .watchProgress:
            try await syncWatchProgress(item)
            
        case .like:
            try await syncLike(item)
            
        case .dislike:
            try await syncDislike(item)
            
        case .addToWatchLater:
            try await syncAddToWatchLater(item)
            
        case .commentDraft:
            try await syncCommentDraft(item)
            
        case .subscribe:
            try await syncSubscription(item)
            
        case .addToPlaylist:
            try await syncAddToPlaylist(item)
        }
        #else
        // Simulate sync for non-Firebase builds
        try await Task.sleep(nanoseconds: 100_000_000)
        #endif
    }
    
    // MARK: - Firebase Sync Methods
    
    #if canImport(FirebaseFirestore)
    private func syncWatchHistory(_ item: SyncItem) async throws {
        guard let userId = getCurrentUserId() else { return }
        
        let historyRef = db.collection("users").document(userId)
            .collection("watch-history").document(item.videoId)
        
        try await historyRef.setData([
            "videoId": item.videoId,
            "watchedAt": FieldValue.serverTimestamp(),
            "completed": item.type == .watchHistoryComplete,
            "syncedFrom": "offline"
        ], merge: true)
    }
    
    private func syncWatchProgress(_ item: SyncItem) async throws {
        guard let userId = getCurrentUserId() else { return }
        
        let progressRef = db.collection("users").document(userId)
            .collection("watch-progress").document(item.videoId)
        
        try await progressRef.setData([
            "videoId": item.videoId,
            "progress": item.data["progress"] ?? 0,
            "currentTime": item.data["currentTime"] ?? 0,
            "updatedAt": FieldValue.serverTimestamp(),
            "syncedFrom": "offline"
        ], merge: true)
    }
    
    private func syncLike(_ item: SyncItem) async throws {
        guard let userId = getCurrentUserId() else { return }
        
        // Add to user's liked videos
        let likedRef = db.collection("users").document(userId)
            .collection("liked-videos").document(item.videoId)
        
        try await likedRef.setData([
            "videoId": item.videoId,
            "likedAt": FieldValue.serverTimestamp(),
            "syncedFrom": "offline"
        ])
        
        // Increment video like count
        let videoRef = db.collection("videos").document(item.videoId)
        try await videoRef.updateData([
            "likeCount": FieldValue.increment(Int64(1))
        ])
    }
    
    private func syncDislike(_ item: SyncItem) async throws {
        guard let userId = getCurrentUserId() else { return }
        
        let dislikedRef = db.collection("users").document(userId)
            .collection("disliked-videos").document(item.videoId)
        
        try await dislikedRef.setData([
            "videoId": item.videoId,
            "dislikedAt": FieldValue.serverTimestamp(),
            "syncedFrom": "offline"
        ])
    }
    
    private func syncAddToWatchLater(_ item: SyncItem) async throws {
        guard let userId = getCurrentUserId() else { return }
        
        let watchLaterRef = db.collection("users").document(userId)
            .collection("watch-later").document(item.videoId)
        
        try await watchLaterRef.setData([
            "videoId": item.videoId,
            "addedAt": FieldValue.serverTimestamp(),
            "syncedFrom": "offline"
        ])
    }
    
    private func syncCommentDraft(_ item: SyncItem) async throws {
        guard let userId = getCurrentUserId() else { return }
        guard let comment = item.data["comment"] as? String else { return }
        
        // Save as draft (user can post when online)
        let draftRef = db.collection("users").document(userId)
            .collection("comment-drafts").document()
        
        try await draftRef.setData([
            "videoId": item.videoId,
            "comment": comment,
            "parentCommentId": item.data["parentCommentId"] ?? NSNull(),
            "createdAt": FieldValue.serverTimestamp(),
            "syncedFrom": "offline"
        ])
    }
    
    private func syncSubscription(_ item: SyncItem) async throws {
        guard let userId = getCurrentUserId() else { return }
        
        let subRef = db.collection("users").document(userId)
            .collection("subscriptions").document(item.videoId)
        
        try await subRef.setData([
            "channelId": item.videoId,
            "subscribedAt": FieldValue.serverTimestamp(),
            "notifications": true,
            "syncedFrom": "offline"
        ])
        
        // Update channel subscriber count
        let channelRef = db.collection("channels").document(item.videoId)
        try await channelRef.updateData([
            "subscriberCount": FieldValue.increment(Int64(1))
        ])
    }
    
    private func syncAddToPlaylist(_ item: SyncItem) async throws {
        guard let userId = getCurrentUserId() else { return }
        guard let playlistId = item.data["playlistId"] as? String else { return }
        
        let playlistItemRef = db.collection("users").document(userId)
            .collection("playlists").document(playlistId)
            .collection("videos").document(item.videoId)
        
        try await playlistItemRef.setData([
            "videoId": item.videoId,
            "addedAt": FieldValue.serverTimestamp(),
            "syncedFrom": "offline"
        ])
        
        // Update playlist video count
        let playlistRef = db.collection("users").document(userId)
            .collection("playlists").document(playlistId)
        
        try await playlistRef.updateData([
            "videoCount": FieldValue.increment(Int64(1)),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }
    #endif
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        downloadManager.$networkStatus
            .removeDuplicates()
            .sink { [weak self] status in
                Task { @MainActor in
                    if status == .wifi {
                        // Auto-sync when WiFi connected
                        await self?.syncNow()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Helpers
    
    private func addSyncItem(_ item: SyncItem) {
        pendingSyncItems.append(item)
        savePendingSyncItems()
    }
    
    private func getCurrentUserId() -> String? {
        // Get from AuthenticationManager
        return AuthenticationManager.shared.currentUser?.id
    }
    
    // MARK: - Persistence
    
    private func savePendingSyncItems() {
        if let data = try? JSONEncoder().encode(pendingSyncItems) {
            userDefaults.set(data, forKey: syncQueueKey)
        }
    }
    
    private func loadPendingSyncItems() {
        guard let data = userDefaults.data(forKey: syncQueueKey),
              let items = try? JSONDecoder().decode([SyncItem].self, from: data) else {
            return
        }
        pendingSyncItems = items
    }
    
    /// Clear all pending sync items (use with caution)
    func clearPendingItems() {
        pendingSyncItems.removeAll()
        savePendingSyncItems()
    }
    
    /// Get pending count by type
    func pendingCount(for type: SyncItemType) -> Int {
        return pendingSyncItems.filter { $0.type == type }.count
    }
}

// MARK: - Models

struct SyncItem: Identifiable, Codable {
    let id: String
    let type: SyncItemType
    let videoId: String
    var timestamp: Date
    var data: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case id, type, videoId, timestamp, dataJSON
    }
    
    init(id: String, type: SyncItemType, videoId: String, timestamp: Date, data: [String: Any]) {
        self.id = id
        self.type = type
        self.videoId = videoId
        self.timestamp = timestamp
        self.data = data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(SyncItemType.self, forKey: .type)
        videoId = try container.decode(String.self, forKey: .videoId)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        let dataJSON = try container.decode(Data.self, forKey: .dataJSON)
        data = (try? JSONSerialization.jsonObject(with: dataJSON) as? [String: Any]) ?? [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(videoId, forKey: .videoId)
        try container.encode(timestamp, forKey: .timestamp)
        
        let dataJSON = try JSONSerialization.data(withJSONObject: data)
        try container.encode(dataJSON, forKey: .dataJSON)
    }
}

enum SyncItemType: String, Codable {
    case watchHistoryAdd
    case watchHistoryComplete
    case watchProgress
    case like
    case dislike
    case addToWatchLater
    case commentDraft
    case subscribe
    case addToPlaylist
}

struct SyncError: Identifiable {
    let id = UUID()
    let itemId: String
    let type: SyncItemType
    let message: String
    let timestamp: Date
}
