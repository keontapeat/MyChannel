//
//  AppState.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import Combine

// MARK: - App State Manager
@MainActor
class AppState: ObservableObject {
    // MARK: - User State
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    
    // MARK: - UI State
    @Published var selectedTab: Int = 0
    @Published var showingUpload = false
    @Published var showingProfile = false
    @Published var showingSettings = false
    
    // MARK: - Video State
    @Published var currentlyPlayingVideo: Video?
    @Published var isVideoPlayerVisible = false
    @Published var videoPlayerOffset: CGFloat = 0
    
    // MARK: - User Content Collections
    @Published var watchLaterVideos: Set<String> = []
    @Published var likedVideos: Set<String> = []
    @Published var savedPlaylists: Set<String> = []
    @Published var subscriptions: Set<String> = []
    @Published var watchHistory: [WatchHistoryItem] = []
    
    // MARK: - Network State
    @Published var isConnected = true
    @Published var hasError = false
    @Published var errorMessage: String?
    
    // MARK: - Appearance
    /// nil = follow system (YouTube default). Set to .dark / .light to override.
    @Published var overrideColorScheme: ColorScheme? = nil
    
    // MARK: - Preferences
    @Published var preferredVideoQuality: VideoQuality = .auto
    @Published var autoPlayEnabled = true
    @Published var notificationsEnabled = true
    
    // 🔥 NUCLEAR FIX #2: User opt-in for auto-PiP
    @Published var autoPiPEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoPiPEnabled, forKey: "autoPiPEnabled")
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var firestoreListeners: Any?
    private var isSavingFromListener = false
    
    // MARK: - Singleton
    static let shared = AppState()

    public init() {
        // 🔥 DISABLED: Native iOS PiP (use custom YouTube-style mini-player instead)
        // Default to false to prevent native PiP from ever auto-starting
        self.autoPiPEnabled = UserDefaults.standard.object(forKey: "autoPiPEnabled") as? Bool ?? false
        
        setupObservers()
        // Seed from AuthenticationManager at launch so UI reflects signed-in user immediately
        if let authUser = AuthenticationManager.shared.currentUser {
            currentUser = authUser
            isAuthenticated = AuthenticationManager.shared.isAuthenticated
            Task { await hydrateCloudCollectionsIfNeeded() }
        }
        loadUserData()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Monitor authentication changes
        NotificationCenter.default.publisher(for: .userDidLogin)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let user = notification.object as? User {
                    self.currentUser = user
                    self.isAuthenticated = true
                    // 🔥 FIX 2.1(a): Wrap post-login operations in defensive error handling
                    // to prevent crashes during hydration / listener setup
                    Task { [weak self] in
                        do {
                            await self?.hydrateCloudCollectionsIfNeeded()
                            if let userId = self?.currentUser?.id {
                                await HistoryService.shared.loadPauseState(userId: userId)
                            }
                        } catch {
                            print("⚠️ [AppState] Non-fatal: hydration failed: \(error.localizedDescription)")
                        }
                    }
                    do { self.loadUserData() } catch { print("⚠️ [AppState] Non-fatal: loadUserData failed") }
                    do { self.attachCloudListeners() } catch { print("⚠️ [AppState] Non-fatal: attachCloudListeners failed") }
                    // Start search history cross-device sync
                    do { SearchHistoryService.shared.startListening(userId: user.id) } catch { print("⚠️ [AppState] Non-fatal: SearchHistoryService listen failed") }
                    // Start ML agent notification bridge for this user
                    do { MLAgentNotificationBridge.shared.start(userId: user.id) } catch { print("⚠️ [AppState] Non-fatal: MLAgentNotificationBridge start failed") }
                    // Index subscribed content into iOS Spotlight Search
                    Task {
                        let videos = await VideoFirestoreService.shared.fetchAllPublicVideos(limit: 50)
                        let spotlightVideos = videos.map { v in
                            SpotlightVideo(id: v.id, title: v.title,
                                           description: v.description ?? "",
                                           thumbnailURL: URL(string: v.thumbnailURL ?? ""),
                                           creatorName: v.creator.displayName,
                                           tags: v.tags ?? [],
                                           durationSeconds: Double(v.duration ?? 0))
                        }
                        SpotlightIndexingService.shared.indexVideos(spotlightVideos)
                    }
                    // Observability: identify user in Sentry + PostHog
                    SentryObservabilityService.shared.identifyUser(uid: user.id, email: user.email)
                    Task { await PostHogAnalyticsService.shared.identify(uid: user.id, properties: ["display_name": user.displayName, "is_creator": user.isCreator]) }
                    // Monetization: refresh RevenueCat entitlements after login
                    Task { await RevenueCatService.shared.refreshEntitlements() }
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .userDidLogout)
            .sink { [weak self] _ in
                self?.currentUser = nil
                self?.isAuthenticated = false
                self?.resetState()
                self?.firestoreListeners = nil
                // Stop search history cross-device sync on logout
                SearchHistoryService.shared.stopListening()
                // Stop ML agent notification bridge on logout
                MLAgentNotificationBridge.shared.stop()
                // Clear observability identities on logout
                SentryObservabilityService.shared.clearUser()
                PostHogAnalyticsService.shared.reset()
                RevenueCatService.shared.logOut()
            }
            .store(in: &cancellables)
        
        // Auto-save user data when collections change
        // 🔥 FIX: Skip save when the change came from a Firestore listener to prevent save loops
        $watchLaterVideos
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isSavingFromListener else { return }
                self.saveUserData()
            }
            .store(in: &cancellables)
        
        $likedVideos
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isSavingFromListener else { return }
                self.saveUserData()
            }
            .store(in: &cancellables)
    }

    private func hydrateCloudCollectionsIfNeeded() async {
        guard let uid = currentUser?.id else { return }
        async let wlFetch = UserCollectionsFirestoreService.shared.fetchWatchLater(userId: uid)
        async let subsFetch = UserCollectionsFirestoreService.shared.fetchSubscriptions(userId: uid)
        let (wl, subs) = await (wlFetch, subsFetch)
        isSavingFromListener = true
        self.watchLaterVideos = wl
        self.subscriptions = subs
        isSavingFromListener = false
    }

    private func attachCloudListeners() {
        guard let uid = currentUser?.id else { return }
        firestoreListeners = UserCollectionsFirestoreService.shared.listen(
            userId: uid,
            onWatchLaterChanged: { [weak self] set in
                Task { @MainActor in
                    // 🔥 FIX: Mark as listener update to prevent save loop
                    self?.isSavingFromListener = true
                    self?.watchLaterVideos = set
                    self?.isSavingFromListener = false
                }
            },
            onSubscriptionsChanged: { [weak self] set in
                Task { @MainActor in
                    self?.isSavingFromListener = true
                    self?.subscriptions = set
                    self?.isSavingFromListener = false
                }
            }
        )
    }
    
    // MARK: - State Management
    func updateUser(_ user: User) {
        currentUser = user
        isAuthenticated = true
        loadUserData()
    }
    
    func clearUser() {
        currentUser = nil
        isAuthenticated = false
        resetState()
    }
    
    // MARK: - Auth Gate Helper (YouTube-style prompt)
    func requireAuthentication(hint: String? = nil) -> Bool {
        if isAuthenticated { return true }
        HapticManager.shared.impact(style: .light)
        NotificationCenter.default.post(name: .presentSignInSheet, object: nil)
        if let hint { setError(hint) }
        return false
    }
    
    func resetState() {
        currentlyPlayingVideo = nil
        isVideoPlayerVisible = false
        videoPlayerOffset = 0
        showingUpload = false
        showingProfile = false
        showingSettings = false
        hasError = false
        errorMessage = nil
        
        // Clear user content collections
        watchLaterVideos.removeAll()
        likedVideos.removeAll()
        savedPlaylists.removeAll()
        subscriptions.removeAll()
        watchHistory.removeAll()
    }
    
    // MARK: - Video Management
    func setCurrentVideo(_ video: Video) {
        currentlyPlayingVideo = video
        isVideoPlayerVisible = true
        addToHistory(video: video)
    }
    
    func addToHistory(video: Video, progress: Double = 0.0, position: TimeInterval = 0.0) {
        guard !HistoryService.shared.isWatchHistoryPaused else { return }
        let item = WatchHistoryItem.fromVideo(video, progress: progress, position: position)
        
        if let existingIndex = watchHistory.firstIndex(where: { $0.contentId == video.id }) {
            watchHistory[existingIndex] = item
        } else {
            watchHistory.insert(item, at: 0)
        }
        
        if watchHistory.count > 100 {
            watchHistory = Array(watchHistory.prefix(100))
        }
        
        if let userId = currentUser?.id {
            Task {
                await HistoryService.shared.addOrUpdateHistoryItem(item, userId: userId)
            }
        }
    }
    
    func addStoryToHistory(story: Story, creator: User) {
        guard !HistoryService.shared.isWatchHistoryPaused else { return }
        let item = WatchHistoryItem.fromStory(story, creator: creator)
        
        if let existingIndex = watchHistory.firstIndex(where: { $0.contentId == story.id }) {
            watchHistory[existingIndex] = item
        } else {
            watchHistory.insert(item, at: 0)
        }
        
        if watchHistory.count > 100 {
            watchHistory = Array(watchHistory.prefix(100))
        }
        
        if let userId = currentUser?.id {
            Task {
                await HistoryService.shared.addOrUpdateHistoryItem(item, userId: userId)
            }
        }
    }
    
    func addLiveTVToHistory(channel: LiveTVChannel, duration: TimeInterval = 0.0) {
        guard !HistoryService.shared.isWatchHistoryPaused else { return }
        let item = WatchHistoryItem.fromLiveTV(channel, duration: duration)
        
        if let existingIndex = watchHistory.firstIndex(where: { $0.contentId == channel.id }) {
            watchHistory[existingIndex] = item
        } else {
            watchHistory.insert(item, at: 0)
        }
        
        if watchHistory.count > 100 {
            watchHistory = Array(watchHistory.prefix(100))
        }
        
        if let userId = currentUser?.id {
            Task {
                await HistoryService.shared.addOrUpdateHistoryItem(item, userId: userId)
            }
        }
    }
    
    func updateHistoryProgress(contentId: String, progress: Double, position: TimeInterval) {
        guard !HistoryService.shared.isWatchHistoryPaused else { return }
        if let index = watchHistory.firstIndex(where: { $0.contentId == contentId }) {
            var item = watchHistory[index]
            item.watchProgress = progress
            item.lastPosition = position
            watchHistory[index] = item
            
            if let userId = currentUser?.id {
                Task {
                    await HistoryService.shared.updateProgress(itemId: item.id, userId: userId, progress: progress, position: position)
                }
            }
        }
    }
    
    // 🔥 NEW: Track video watch for University
    func trackUniversityWatch(video: Video, watchTime: TimeInterval, completionPercentage: Double, aiVerificationScore: Int? = nil) {
        guard let userId = currentUser?.id else { return }
        
        Task {
            do {
                try await UniversityWatchTrackingService.shared.trackVideoWatch(
                    userId: userId,
                    videoId: video.id,
                    title: video.title,
                    duration: video.duration,
                    watchTime: watchTime,
                    completionPercentage: completionPercentage,
                    aiVerificationScore: aiVerificationScore
                )
                
                print("✅ [AppState] Tracked University watch: \(video.title)")
            } catch {
                print("⚠️ [AppState] Failed to track University watch: \(error)")
            }
        }
    }
    
    func clearCurrentVideo() {
        currentlyPlayingVideo = nil
        isVideoPlayerVisible = false
        videoPlayerOffset = 0
    }
    
    // MARK: - User Content Actions
    func toggleWatchLater(for videoId: String) {
        guard requireAuthentication(hint: "Sign in to save videos to Watch Later.") else { return }
        let willAdd = !watchLaterVideos.contains(videoId)
        if willAdd { watchLaterVideos.insert(videoId) } else { watchLaterVideos.remove(videoId) }
        if let uid = currentUser?.id {
            Task { await UserCollectionsFirestoreService.shared.toggleWatchLater(userId: uid, videoId: videoId, add: willAdd) }
        }
    }
    
    func toggleLike(for videoId: String) {
        guard requireAuthentication(hint: "Sign in to like videos and see them across devices.") else { return }
        let willAdd = !likedVideos.contains(videoId)
        if willAdd { likedVideos.insert(videoId) } else { likedVideos.remove(videoId) }
        if let uid = currentUser?.id {
            Task { await VideoFirestoreService.shared.toggleLike(videoId: videoId, userId: uid, add: willAdd) }
        }
    }
    
    func toggleSubscription(for creatorId: String) {
        guard requireAuthentication(hint: "Sign in to subscribe and see new uploads in your feed.") else { return }
        let willAdd = !subscriptions.contains(creatorId)
        if willAdd { subscriptions.insert(creatorId) } else { subscriptions.remove(creatorId) }
        if let uid = currentUser?.id {
            Task { await UserCollectionsFirestoreService.shared.toggleSubscription(userId: uid, creatorId: creatorId, add: willAdd) }
        }
    }
    
    func isVideoLiked(_ videoId: String) -> Bool {
        return likedVideos.contains(videoId)
    }
    
    func isVideoInWatchLater(_ videoId: String) -> Bool {
        return watchLaterVideos.contains(videoId)
    }
    
    func isSubscribedTo(_ creatorId: String) -> Bool {
        return subscriptions.contains(creatorId)
    }
    
    // MARK: - Data Persistence (BULLETPROOF with DataPersistenceService)
    
    // Codable struct for user collections
    private struct UserCollectionsData: Codable {
        let watchLaterVideos: [String]
        let likedVideos: [String]
        let savedPlaylists: [String]
        let subscriptions: [String]
        let watchHistory: [WatchHistoryItem]
    }
    
    private func saveUserData() {
        guard let userId = currentUser?.id else { return }
        
        // Create Codable struct
        let userData = UserCollectionsData(
            watchLaterVideos: Array(watchLaterVideos),
            likedVideos: Array(likedVideos),
            savedPlaylists: Array(savedPlaylists),
            subscriptions: Array(subscriptions),
            watchHistory: watchHistory
        )
        
        // 🛡️ BULLETPROOF: Use DataPersistenceService with auto-retry and cloud backup
        Task {
            do {
                try await DataPersistenceService.shared.saveDualLayer(
                    userData,
                    key: "userData_\(userId)",
                    collectionPath: "userCollections",
                    docId: userId
                )
                print("✅ User data saved (bulletproof): watchLater=\(userData.watchLaterVideos.count), liked=\(userData.likedVideos.count), subs=\(userData.subscriptions.count)")
            } catch {
                print("🚨 Failed to save user data: \(error)")
                // Fallback: save to UserDefaults directly
                let fallbackData = [
                    "watchLaterVideos": Array(watchLaterVideos),
                    "likedVideos": Array(likedVideos),
                    "savedPlaylists": Array(savedPlaylists),
                    "subscriptions": Array(subscriptions),
                    "watchHistory": try? JSONEncoder().encode(watchHistory)
                ] as [String : Any]
                UserDefaults.standard.set(fallbackData, forKey: "userData_\(userId)")
            }
        }
    }
    
    private func loadUserData() {
        guard let userId = currentUser?.id else { return }
        
        if let userData = UserDefaults.standard.dictionary(forKey: "userData_\(userId)") {
            if let watchLater = userData["watchLaterVideos"] as? [String] {
                watchLaterVideos = Set(watchLater)
            }
            if let liked = userData["likedVideos"] as? [String] {
                likedVideos = Set(liked)
            }
            if let playlists = userData["savedPlaylists"] as? [String] {
                savedPlaylists = Set(playlists)
            }
            if let subs = userData["subscriptions"] as? [String] {
                subscriptions = Set(subs)
            }
            if let historyData = userData["watchHistory"] as? Data,
               let history = try? JSONDecoder().decode([WatchHistoryItem].self, from: historyData) {
                watchHistory = history
            } else if let legacyHistory = userData["watchHistory"] as? [String] {
                // Migrate legacy string array to WatchHistoryItem array
                watchHistory = []
            }
        }
        // Load from Firestore too so data persists across devices and after reinstall
        Task { await loadUserDataFromCloud() }
    }
    
    /// Load user collections (likes, watch history, etc.) from Firestore so they persist across devices and sign-out/sign-in.
    private func loadUserDataFromCloud() async {
        guard let userId = currentUser?.id else { return }
        do {
            if let data = try await DataPersistenceService.shared.loadDualLayer(
                UserCollectionsData.self,
                key: "userData_\(userId)",
                collectionPath: "userCollections",
                docId: userId
            ) {
                // 🔥 FIX: Mark as listener update to prevent save loop when hydrating from cloud
                isSavingFromListener = true
                likedVideos = Set(data.likedVideos)
                savedPlaylists = Set(data.savedPlaylists)
                watchHistory = data.watchHistory
                // Watch later & subscriptions come from UserCollectionsFirestoreService subcollections (hydrateCloudCollectionsIfNeeded / listeners)
                if !data.watchLaterVideos.isEmpty { watchLaterVideos = Set(data.watchLaterVideos) }
                if !data.subscriptions.isEmpty { subscriptions = Set(data.subscriptions) }
                isSavingFromListener = false
                print("✅ User collections loaded from cloud: likes=\(data.likedVideos.count), watchHistory=\(data.watchHistory.count)")
            }
        } catch {
            print("⚠️ loadUserDataFromCloud: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Error Handling
    func setError(_ message: String) {
        errorMessage = message
        hasError = true
        
        // Auto-clear error after 5 seconds
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            self?.clearError()
        }
    }
    
    func clearError() {
        errorMessage = nil
        hasError = false
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let userDidLogin = Notification.Name("userDidLogin")
    static let userDidLogout = Notification.Name("userDidLogout")
    static let videoDidStart = Notification.Name("videoDidStart")
    static let videoDidEnd = Notification.Name("videoDidEnd")
    static let storiesDidChange = Notification.Name("storiesDidChange")
    static let openVideoFromHistory = Notification.Name("openVideoFromHistory")
    static let openStoryFromHistory = Notification.Name("openStoryFromHistory")
    static let openLiveTVFromHistory = Notification.Name("openLiveTVFromHistory")
    static let presentSignInSheet = Notification.Name("presentSignInSheet")
}