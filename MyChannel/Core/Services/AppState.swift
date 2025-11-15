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
    @Published var watchHistory: [String] = []
    
    // MARK: - Network State
    @Published var isConnected = true
    @Published var hasError = false
    @Published var errorMessage: String?
    
    // MARK: - Preferences
    @Published var preferredVideoQuality: VideoQuality = .auto
    @Published var autoPlayEnabled = true
    @Published var notificationsEnabled = true
    
    private var cancellables = Set<AnyCancellable>()
    private var firestoreListeners: Any?
    
    // MARK: - Singleton
    static let shared = AppState()

    public init() {
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
                if let user = notification.object as? User {
                    self?.currentUser = user
                    self?.isAuthenticated = true
                    Task { await self?.hydrateCloudCollectionsIfNeeded() }
                    self?.loadUserData()
                    self?.attachCloudListeners()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .userDidLogout)
            .sink { [weak self] _ in
                self?.currentUser = nil
                self?.isAuthenticated = false
                self?.resetState()
                self?.firestoreListeners = nil
            }
            .store(in: &cancellables)
        
        // Auto-save user data when collections change
        $watchLaterVideos
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveUserData()
            }
            .store(in: &cancellables)
        
        $likedVideos
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveUserData()
            }
            .store(in: &cancellables)
    }

    private func hydrateCloudCollectionsIfNeeded() async {
        guard let uid = currentUser?.id else { return }
        let wl = await UserCollectionsFirestoreService.shared.fetchWatchLater(userId: uid)
        let subs = await UserCollectionsFirestoreService.shared.fetchSubscriptions(userId: uid)
        await MainActor.run {
            self.watchLaterVideos = wl
            self.subscriptions = subs
        }
    }

    private func attachCloudListeners() {
        guard let uid = currentUser?.id else { return }
        firestoreListeners = UserCollectionsFirestoreService.shared.listen(
            userId: uid,
            onWatchLaterChanged: { [weak self] set in
                Task { @MainActor in self?.watchLaterVideos = set }
            },
            onSubscriptionsChanged: { [weak self] set in
                Task { @MainActor in self?.subscriptions = set }
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
        
        // Add to watch history
        if !watchHistory.contains(video.id) {
            watchHistory.insert(video.id, at: 0)
            
            // Keep only last 100 videos in history
            if watchHistory.count > 100 {
                watchHistory = Array(watchHistory.prefix(100))
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
        let watchHistory: [String]
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
                    "watchHistory": watchHistory
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
            
            if let history = userData["watchHistory"] as? [String] {
                watchHistory = history
            }
        }
    }
    
    // MARK: - Error Handling
    func setError(_ message: String) {
        errorMessage = message
        hasError = true
        
        // Auto-clear error after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
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
}