//
//  SubscriptionsViewModel.swift
//  MyChannel
//
//  Created by AI Assistant
//

import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class SubscriptionsViewModel: ObservableObject {
    
    // MARK: - Published State
    @Published var videos: [Video] = []
    @Published var subscribedChannels: [User] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var hasNewVideosBadge: Bool = false
    
    // Filters & Sorting
    @Published var filterOption: FilterOption = .all
    @Published var sortOption: SortOption = .latest
    @Published var selectedTab: SubscriptionTab = .feed
    
    // Notification settings per channel
    @Published var notificationSettings: [String: NotificationLevel] = [:]  // userId -> level
    
    // 🔥 PERFORMANCE: Track tasks for proper cancellation
    private var loadVideosTask: Task<Void, Never>?
    private var loadChannelsTask: Task<Void, Never>?
    
    // 🔥 PERFORMANCE: Proper deinit cleanup
    deinit {
        loadVideosTask?.cancel()
        loadChannelsTask?.cancel()
        print("✅ [SubscriptionsViewModel] Deallocated - no memory leak!")
    }
    
    // MARK: - Filter & Sort Options
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case continueWatching = "Continue"
        case unwatched = "Unwatched"
        case live = "Live"
        case posts = "Posts"

        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .today: return "calendar"
            case .continueWatching: return "play.circle"
            case .unwatched: return "circle.fill"
            case .live: return "dot.radiowaves.left.and.right"
            case .posts: return "doc.text"
            }
        }
    }
    
    enum SortOption: String, CaseIterable {
        case latest = "Latest"
        case oldest = "Oldest"
        case mostViewed = "Most Viewed"
        case channelName = "Channel Name"
        
        var icon: String {
            switch self {
            case .latest: return "arrow.down"
            case .oldest: return "arrow.up"
            case .mostViewed: return "eye.fill"
            case .channelName: return "textformat"
            }
        }
    }
    
    enum SubscriptionTab: String, CaseIterable {
        case feed = "Feed"
        case channels = "Channels"
        
        var icon: String {
            switch self {
            case .feed: return "play.square.stack"
            case .channels: return "person.2.fill"
            }
        }
    }
    
    enum NotificationLevel: String, Codable {
        case all = "All"
        case none = "None"
        case personalized = "Personalized"
        
        var icon: String {
            switch self {
            case .all: return "bell.fill"
            case .none: return "bell.slash.fill"
            case .personalized: return "bell.badge.fill"
            }
        }
    }
    
    // MARK: - Computed Properties
    var filteredVideos: [Video] {
        var result = videos
        
        // Apply filter
        switch filterOption {
        case .all:
            break
        case .today:
            let today = Calendar.current.startOfDay(for: Date())
            result = result.filter { $0.createdAt >= today }
        case .continueWatching:
            let watchedIds = (UserDefaults.standard.array(forKey: "partialWatchIds") as? [String]) ?? []
            result = result.filter { watchedIds.contains($0.id) }
        case .unwatched:
            let watchedIds = Set((UserDefaults.standard.array(forKey: "partialWatchIds") as? [String]) ?? [])
            let fullyWatchedIds = Set((UserDefaults.standard.array(forKey: "completedWatchIds") as? [String]) ?? [])
            result = result.filter { !watchedIds.contains($0.id) && !fullyWatchedIds.contains($0.id) }
        case .live:
            result = result.filter { $0.isLiveStream }
        case .posts:
            result = []
        }
        
        // Apply sort
        switch sortOption {
        case .latest:
            result.sort { $0.createdAt > $1.createdAt }
        case .oldest:
            result.sort { $0.createdAt < $1.createdAt }
        case .mostViewed:
            result.sort { $0.viewCount > $1.viewCount }
        case .channelName:
            result.sort { $0.creator.displayName < $1.creator.displayName }
        }
        
        return result
    }
    
    var channelsByNotificationLevel: [NotificationLevel: [User]] {
        var grouped: [NotificationLevel: [User]] = [
            .all: [],
            .personalized: [],
            .none: []
        ]
        
        for channel in subscribedChannels {
            let level = notificationSettings[channel.id] ?? .all
            grouped[level]?.append(channel)
        }
        
        return grouped
    }
    
    // MARK: - Lifecycle
    func loadSubscribedVideos(userId: String) async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            // 1. Get user's subscriptions
            let subscriptions = try await fetchSubscriptions(userId: userId)
            
            // 2. Fetch latest videos from subscribed channels
            let allVideos = try await fetchVideosFromChannels(channelIds: subscriptions)
            
            // 3. Update state
            videos = allVideos
            
        } catch {
            self.error = error.localizedDescription
            print("🚨 [Subscriptions] Error loading videos: \(error)")
        }
        
        isLoading = false
    }
    
    func loadSubscribedChannels(userId: String) async {
        do {
            let subscriptions = try await fetchSubscriptions(userId: userId)
            
            // Fetch all channel user objects in parallel
            let channels: [User] = await withTaskGroup(of: User?.self) { group in
                for channelId in subscriptions {
                    group.addTask { try? await UserFirestoreService.shared.fetchUser(id: channelId) }
                }
                var result: [User] = []
                for await user in group { if let u = user { result.append(u) } }
                return result
            }
            
            subscribedChannels = channels.sorted { $0.displayName < $1.displayName }
            
        } catch {
            print("🚨 [Subscriptions] Error loading channels: \(error)")
        }
    }
    
    func refreshFeed(userId: String) async {
        async let videosFetch: Void = loadSubscribedVideos(userId: userId)
        async let channelsFetch: Void = loadSubscribedChannels(userId: userId)
        _ = await (videosFetch, channelsFetch)
    }
    
    // MARK: - Subscriptions Management
    func unsubscribe(from channelId: String, userId: String) async {
        do {
            await UserCollectionsFirestoreService.shared.toggleSubscription(userId: userId, creatorId: channelId, add: false)
            
            // Remove from local state
            subscribedChannels.removeAll { $0.id == channelId }
            videos.removeAll { $0.creator.id == channelId }
            
        } catch {
            print("🚨 [Subscriptions] Error unsubscribing: \(error)")
        }
    }
    
    func updateNotificationLevel(channelId: String, level: NotificationLevel) async {
        notificationSettings[channelId] = level
        
        // Save to Firestore
        #if canImport(FirebaseFirestore)
        guard let userId = AuthenticationManager.shared.currentUser?.id else { return }
        
        try? await Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("notification_settings")
            .document(channelId)
            .setData([
                "level": level.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        #endif
    }
    
    // MARK: - Data Fetching
    private func fetchSubscriptions(userId: String) async throws -> [String] {
        #if canImport(FirebaseFirestore)
        let snapshot = try await Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("subscriptions")
            .getDocuments()
        
        return snapshot.documents.map { $0.documentID }
        #else
        return []
        #endif
    }
    
    private func fetchVideosFromChannels(channelIds: [String]) async throws -> [Video] {
        // Fetch latest 5 videos from each channel in parallel
        await withTaskGroup(of: [Video].self) { group in
            for channelId in channelIds {
                group.addTask {
                    await VideoFirestoreService.shared.fetchVideosByCreator(creatorId: channelId, limit: 5)
                }
            }
            var allVideos: [Video] = []
            for await batch in group { allVideos.append(contentsOf: batch) }
            return allVideos.sorted { $0.createdAt > $1.createdAt }
        }
    }
}

