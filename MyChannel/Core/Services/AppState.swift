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
    
    // MARK: - Singleton
    static let shared = AppState()

    public init() {
        setupObservers()
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
                    self?.loadUserData()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .userDidLogout)
            .sink { [weak self] _ in
                self?.currentUser = nil
                self?.isAuthenticated = false
                self?.resetState()
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
    
    func clearCurrentVideo() {
        currentlyPlayingVideo = nil
        isVideoPlayerVisible = false
        videoPlayerOffset = 0
    }
    
    // MARK: - User Content Actions
    func toggleWatchLater(for videoId: String) {
        if watchLaterVideos.contains(videoId) {
            watchLaterVideos.remove(videoId)
        } else {
            watchLaterVideos.insert(videoId)
        }
    }
    
    func toggleLike(for videoId: String) {
        if likedVideos.contains(videoId) {
            likedVideos.remove(videoId)
        } else {
            likedVideos.insert(videoId)
        }
    }
    
    func toggleSubscription(for creatorId: String) {
        if subscriptions.contains(creatorId) {
            subscriptions.remove(creatorId)
        } else {
            subscriptions.insert(creatorId)
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
    
    // MARK: - Data Persistence
    private func saveUserData() {
        guard let userId = currentUser?.id else { return }
        
        let userData = [
            "watchLaterVideos": Array(watchLaterVideos),
            "likedVideos": Array(likedVideos),
            "savedPlaylists": Array(savedPlaylists),
            "subscriptions": Array(subscriptions),
            "watchHistory": watchHistory
        ]
        
        UserDefaults.standard.set(userData, forKey: "userData_\(userId)")
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
}