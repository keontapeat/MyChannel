//
//  SubscriptionsViewModel.swift
//  MyChannel
//
//  Nuclear-level subscriptions feed — 100% YouTube parity (and then some).
//

import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class SubscriptionsViewModel: ObservableObject {
    
    // MARK: - Published State
    @Published var videos: [Video] = []
    @Published var shorts: [Video] = []
    @Published var posts: [SubscriptionPost] = []
    @Published var subscribedChannels: [User] = []
    @Published var isLoading = false
    @Published var isLoadingPosts = false
    @Published var error: String?
    @Published var hasNewVideosBadge: Bool = false
    @Published var newUploadCount: Int = 0
    
    // Filters & Sorting
    @Published var filterOption: FilterOption = .all
    @Published var sortOption: SortOption = .latest
    @Published var selectedTab: SubscriptionTab = .feed
    
    // Layout (YouTube parity: grid ⇄ list toggle)
    @Published var layout: FeedLayout = .grid
    
    // Channel focus filter — tap a channel chip to see only its uploads (YouTube parity)
    @Published var focusedChannelId: String? = nil
    
    // Notification settings per channel
    @Published var notificationSettings: [String: NotificationLevel] = [:]  // userId -> level
    
    // Watch progress map (videoId -> 0...1) powers Continue / Unwatched + progress bars
    @Published var watchProgress: [String: Double] = [:]
    
    // 🔥 PERFORMANCE: Track tasks for proper cancellation
    private var loadVideosTask: Task<Void, Never>?
    private var loadChannelsTask: Task<Void, Never>?
    
    // Persisted keys
    private let layoutKey = "subscriptions.layout"
    private let lastSeenKey = "subscriptions.lastSeenDate"
    
    init() {
        if let raw = UserDefaults.standard.string(forKey: layoutKey),
           let saved = FeedLayout(rawValue: raw) {
            layout = saved
        }
    }
    
    // 🔥 PERFORMANCE: Proper deinit cleanup
    deinit {
        loadVideosTask?.cancel()
        loadChannelsTask?.cancel()
        print("✅ [SubscriptionsViewModel] Deallocated - no memory leak!")
    }
    
    // MARK: - Feed Layout
    enum FeedLayout: String, CaseIterable {
        case grid = "Grid"
        case list = "List"
        
        var icon: String {
            switch self {
            case .grid: return "rectangle.grid.1x2"
            case .list: return "list.bullet"
            }
        }
        
        var toggleIcon: String {
            // Shows the icon for the *other* layout (what you'll switch to)
            switch self {
            case .grid: return "list.bullet"
            case .list: return "rectangle.grid.1x2"
            }
        }
    }
    
    // MARK: - Filter & Sort Options
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case videos = "Videos"
        case flicks = "Flicks"
        case live = "Live"
        case posts = "Posts"
        case continueWatching = "Continue watching"
        case unwatched = "Unwatched"

        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .today: return "calendar"
            case .videos: return "play.rectangle"
            case .flicks: return "play.square.stack"
            case .live: return "dot.radiowaves.left.and.right"
            case .posts: return "doc.text"
            case .continueWatching: return "play.circle"
            case .unwatched: return "circle.dashed"
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
    
    enum NotificationLevel: String, Codable, CaseIterable {
        case all = "All"
        case personalized = "Personalized"
        case none = "None"
        
        var icon: String {
            switch self {
            case .all: return "bell.fill"
            case .none: return "bell.slash.fill"
            case .personalized: return "bell.badge.fill"
            }
        }
        
        var subtitle: String {
            switch self {
            case .all: return "Notify me about all uploads"
            case .personalized: return "Only the ones I'd love"
            case .none: return "Don't notify me"
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Long-form videos only (Flicks surfaced in their own shelf).
    private var longFormVideos: [Video] {
        videos.filter { !$0.isShort }
    }
    
    var filteredVideos: [Video] {
        var result = longFormVideos
        
        // Channel focus (tap a channel chip)
        if let channelId = focusedChannelId {
            result = result.filter { $0.creator.id == channelId }
        }
        
        // Apply filter
        switch filterOption {
        case .all:
            // Live streams get their own full-width cards above the feed
            // (see `liveNow`) — exclude them here to avoid showing twice.
            result = result.filter { !$0.isLiveStream }
        case .today:
            let today = Calendar.current.startOfDay(for: Date())
            result = result.filter { $0.createdAt >= today }
        case .videos:
            // Long-form only (already the default — just make explicit)
            break
        case .flicks:
            result = []  // Flicks are shown in their own shelf; this filter focuses the Flicks grid
        case .continueWatching:
            result = result.filter {
                let pct = watchProgress[$0.id] ?? 0
                return pct > 0.02 && pct < 0.9
            }
        case .unwatched:
            result = result.filter { (watchProgress[$0.id] ?? 0) < 0.02 }
        case .live:
            // Live streams are rendered via the full-width `liveNow` cards,
            // not the "Most relevant" list — avoid showing them twice.
            result = []
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
    
    /// Flicks from subscribed creators, newest first (respects channel focus).
    var filteredShorts: [Video] {
        var result = shorts
        if let channelId = focusedChannelId {
            result = result.filter { $0.creator.id == channelId }
        }
        return result.sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Live videos currently streaming from subscriptions.
    var liveNow: [Video] {
        videos.filter { $0.isLiveStream }.sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Whether the Posts shelf/tab should show anything.
    var hasPosts: Bool { !posts.isEmpty }
    
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
    
    func progress(for videoId: String) -> Double {
        watchProgress[videoId] ?? 0
    }
    
    // MARK: - Layout
    func toggleLayout() {
        layout = (layout == .grid) ? .list : .grid
        UserDefaults.standard.set(layout.rawValue, forKey: layoutKey)
    }
    
    func focus(on channelId: String?) {
        focusedChannelId = (focusedChannelId == channelId) ? nil : channelId
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
            
            // 3. Split shorts vs long-form for YouTube-style shelves
            videos = allVideos
            shorts = allVideos.filter { $0.isShort }
            
            // 4. Compute "new since last visit" badge
            updateNewUploadBadge(from: allVideos)
            
        } catch {
            self.error = error.localizedDescription
            print("🚨 [Subscriptions] Error loading videos: \(error)")
        }
        
        // 5. Pull watch progress for Continue/Unwatched filters + progress bars
        await loadWatchProgress(userId: userId)
        
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
            
            // Load per-channel notification preferences
            await loadNotificationSettings(userId: userId, channelIds: subscriptions)
            
        } catch {
            print("🚨 [Subscriptions] Error loading channels: \(error)")
        }
    }
    
    /// Loads recent community posts from subscribed creators (YouTube "Posts" parity).
    func loadPosts(userId: String) async {
        guard !subscribedChannels.isEmpty else { return }
        isLoadingPosts = true
        defer { isLoadingPosts = false }
        
        let channels = subscribedChannels
        let collected: [SubscriptionPost] = await withTaskGroup(of: [SubscriptionPost].self) { group in
            for channel in channels.prefix(30) {
                group.addTask {
                    let raw = await Self.fetchPosts(creatorId: channel.id, limit: 5)
                    return raw.map { SubscriptionPost(post: $0, author: channel) }
                }
            }
            var all: [SubscriptionPost] = []
            for await batch in group { all.append(contentsOf: batch) }
            return all
        }
        
        posts = collected.sorted { $0.post.createdAt > $1.post.createdAt }
    }
    
    func refreshFeed(userId: String) async {
        async let videosFetch: Void = loadSubscribedVideos(userId: userId)
        async let channelsFetch: Void = loadSubscribedChannels(userId: userId)
        _ = await (videosFetch, channelsFetch)
        await loadPosts(userId: userId)
        markFeedAsSeen()
    }
    
    // MARK: - New Upload Badge
    private func updateNewUploadBadge(from allVideos: [Video]) {
        let lastSeen = (UserDefaults.standard.object(forKey: lastSeenKey) as? Date) ?? .distantPast
        let fresh = allVideos.filter { $0.createdAt > lastSeen }
        newUploadCount = fresh.count
        hasNewVideosBadge = !fresh.isEmpty
    }
    
    func markFeedAsSeen() {
        UserDefaults.standard.set(Date(), forKey: lastSeenKey)
        newUploadCount = 0
        hasNewVideosBadge = false
    }
    
    func isNewUpload(_ video: Video) -> Bool {
        let lastSeen = (UserDefaults.standard.object(forKey: lastSeenKey) as? Date) ?? .distantPast
        return video.createdAt > lastSeen
    }
    
    // MARK: - Watch Progress
    private func loadWatchProgress(userId: String) async {
        try? await WatchProgressService.shared.fetchAllInProgress(userId: userId)
        var map: [String: Double] = [:]
        for (videoId, wp) in WatchProgressService.shared.progress {
            map[videoId] = wp.completionPct
        }
        watchProgress = map
    }
    
    // MARK: - Subscriptions Management
    func unsubscribe(from channelId: String, userId: String) async {
        await UserCollectionsFirestoreService.shared.toggleSubscription(userId: userId, creatorId: channelId, add: false)
        
        // Remove from local state
        subscribedChannels.removeAll { $0.id == channelId }
        videos.removeAll { $0.creator.id == channelId }
        shorts.removeAll { $0.creator.id == channelId }
        posts.removeAll { $0.author.id == channelId }
        if focusedChannelId == channelId { focusedChannelId = nil }
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
    
    private func loadNotificationSettings(userId: String, channelIds: [String]) async {
        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .collection("notification_settings")
                .getDocuments()
            
            var settings: [String: NotificationLevel] = [:]
            for doc in snapshot.documents {
                if let raw = doc.data()["level"] as? String,
                   let level = NotificationLevel(rawValue: raw) {
                    settings[doc.documentID] = level
                }
            }
            // Default any unset channel to .all
            for id in channelIds where settings[id] == nil {
                settings[id] = .all
            }
            notificationSettings = settings
        } catch {
            print("🚨 [Subscriptions] Error loading notification settings: \(error)")
        }
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
        // Fetch latest videos from each channel in parallel
        await withTaskGroup(of: [Video].self) { group in
            for channelId in channelIds {
                group.addTask {
                    await VideoFirestoreService.shared.fetchVideosByCreator(creatorId: channelId, limit: 8)
                }
            }
            var allVideos: [Video] = []
            for await batch in group { allVideos.append(contentsOf: batch) }
            return allVideos.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    private static func fetchPosts(creatorId: String, limit: Int) async -> [CommunityPost] {
        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await Firestore.firestore()
                .collection("community_posts")
                .whereField("creatorId", isEqualTo: creatorId)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snapshot.documents.compactMap { doc in
                let d = doc.data()
                return CommunityPost(
                    id: doc.documentID,
                    creatorId: d["creatorId"] as? String ?? creatorId,
                    content: d["content"] as? String ?? "",
                    imageURLs: (d["imageURL"] as? String).map { [$0] } ?? [],
                    postType: PostType(rawValue: d["type"] as? String ?? "text") ?? .text,
                    createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    likeCount: d["likeCount"] as? Int ?? 0,
                    commentCount: d["commentCount"] as? Int ?? 0
                )
            }
        } catch {
            return []
        }
        #else
        return []
        #endif
    }
}

// MARK: - Subscription Post (post + resolved author)
struct SubscriptionPost: Identifiable, Equatable {
    let post: CommunityPost
    let author: User
    var id: String { post.id }
    
    static func == (lhs: SubscriptionPost, rhs: SubscriptionPost) -> Bool {
        lhs.post.id == rhs.post.id
    }
}
