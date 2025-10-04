//
//  GlobalVideoPlayerManager.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVFoundation
import Combine

@MainActor
class GlobalVideoPlayerManager: ObservableObject {
    static let shared = GlobalVideoPlayerManager()
    
    @Published var currentVideo: Video?
    @Published var isPlaying = false
    @Published var isMiniplayer = false
    @Published var showingFullscreen = false
    @Published var miniplayerOffset: CGFloat = 0
    @Published var currentProgress: Double = 0.0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var miniPlayerHeight: CGFloat = 80
    @Published var shouldShowMiniPlayer = false
    @Published var isTransitioning = false
    @Published var pausedByFlicks = false
    
    private var playerManager: VideoPlayerManager?
    private var cancellables = Set<AnyCancellable>()
    private var isCleanedUp = false
    private var wasPlayingBeforeFlicks = false

    var player: AVPlayer? {
        playerManager?.player
    }
    
    private init() {
        setupPlayerManager()
    }
    
    deinit {
        print("🗑️ GlobalVideoPlayerManager deinit called")
        // Perform non-MainActor cleanup here
        cleanupSync()
    }
    
    private nonisolated func cleanupSync() {
        // This cleanup runs on whatever thread deinit is called from
        print("🧹 Cleaning up GlobalVideoPlayerManager (sync)")
        
        // We can't access @MainActor properties from here safely
        // So we'll schedule the main cleanup if needed
        Task { @MainActor in
            // This will run on main actor if the object is still alive
            // but since we're in deinit, this may not execute
            print("🧹 Final MainActor cleanup attempted")
        }
    }
    
    private func cleanup() {
        guard !isCleanedUp else { return }
        isCleanedUp = true
        
        print("🧹 Cleaning up GlobalVideoPlayerManager")
        
        // Clear all cancellables to break retain cycles
        cancellables.removeAll()
        
        // Clean up player manager
        playerManager = nil
        
        // Reset all published properties
        currentVideo = nil
        isPlaying = false
        isMiniplayer = false
        showingFullscreen = false
        miniplayerOffset = 0
        currentProgress = 0.0
        currentTime = 0
        duration = 0
        shouldShowMiniPlayer = false
        isTransitioning = false
    }
    
    private func setupPlayerManager() {
        guard !isCleanedUp else { return }
        
        // Create fresh player manager
        playerManager = VideoPlayerManager()
        
        setupObservers()
    }
    
    private func setupObservers() {
        guard let playerManager = playerManager, !isCleanedUp else { return }
        
        // Clear existing cancellables
        cancellables.removeAll()
        
        // Use weak self to prevent retain cycles
        playerManager.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                guard let self = self, !self.isCleanedUp else { return }
                self.isPlaying = isPlaying
            }
            .store(in: &cancellables)
        
        playerManager.$currentProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                guard let self = self, !self.isCleanedUp else { return }
                self.currentProgress = progress
            }
            .store(in: &cancellables)
        
        playerManager.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                guard let self = self, !self.isCleanedUp else { return }
                self.currentTime = time
            }
            .store(in: &cancellables)
        
        playerManager.$duration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                guard let self = self, !self.isCleanedUp else { return }
                self.duration = duration
            }
            .store(in: &cancellables)
    }

    // Stop current playback immediately (used when switching videos fast)
    func stopImmediately() {
        playerManager?.pause()
        playerManager?.player?.replaceCurrentItem(with: nil)
        isPlaying = false
        currentProgress = 0
        currentTime = 0
        // Ensure mini player and fullscreen UI are hidden when stopping abruptly
        shouldShowMiniPlayer = false
        isMiniplayer = false
        showingFullscreen = false
        currentVideo = nil
    }
    
    // MARK: - Adopt External Player
    /// Seamlessly adopt an existing VideoPlayerManager (and its AVPlayer)
    /// so we can hand off playback to the global mini player without
    /// interrupting playback or losing position.
    func adoptExternalPlayerManager(_ externalManager: VideoPlayerManager,
                                    video: Video,
                                    showFullscreen: Bool) {
        guard !isCleanedUp else { return }

        // Point our manager to the external one and wire observers
        playerManager = externalManager
        setupObservers()

        currentVideo = video
        isPlaying = externalManager.isPlaying

        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            showingFullscreen = showFullscreen
            isMiniplayer = !showFullscreen
            shouldShowMiniPlayer = !showFullscreen
            miniplayerOffset = 0
        }
    }

    // MARK: - Video Management
    func playVideo(_ video: Video, showFullscreen: Bool = true) {
        guard !isCleanedUp else { return }
        
        // Stop any current playback immediately to avoid overlap when switching fast
        stopImmediately()
        
        // Ensure we have a player manager
        if playerManager == nil {
            setupPlayerManager()
        }
        
        currentVideo = video
        playerManager?.setupPlayer(with: video)
        
        if showFullscreen {
            showingFullscreen = true
            isMiniplayer = false
            shouldShowMiniPlayer = false
        } else {
            isMiniplayer = true
            showingFullscreen = false
            shouldShowMiniPlayer = true
        }
        
        // Start playing with delay to avoid timing issues
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, !self.isCleanedUp else { return }
            self.playerManager?.play()
        }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    func minimizePlayer() {
        guard currentVideo != nil, !isCleanedUp else { return }
        
        isTransitioning = true
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showingFullscreen = false
            isMiniplayer = true
            shouldShowMiniPlayer = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, !self.isCleanedUp else { return }
            self.isTransitioning = false
        }
    }
    
    func expandPlayer() {
        guard currentVideo != nil, !isCleanedUp else { return }
        
        isTransitioning = true
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showingFullscreen = true
            isMiniplayer = false
            shouldShowMiniPlayer = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, !self.isCleanedUp else { return }
            self.isTransitioning = false
        }
    }
    
    func closePlayer() {
        guard !isCleanedUp else { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            playerManager?.pause()
            currentVideo = nil
            isMiniplayer = false
            showingFullscreen = false
            shouldShowMiniPlayer = false
            miniplayerOffset = 0
        }
    }
    
    // MARK: - Navigation Handling for Mini Player
    func handleNavigationChange(isVideoDetailVisible: Bool) {
        guard let _ = currentVideo, !isCleanedUp else { return }
        
        if !isVideoDetailVisible && !isMiniplayer {
            // User navigated away from video detail, show mini player
            minimizePlayer()
        }
    }
    
    // MARK: - Playback Controls
    func togglePlayPause() {
        guard !isCleanedUp else { return }
        
        playerManager?.togglePlayPause()
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func seek(to progress: Double) {
        guard !isCleanedUp else { return }
        playerManager?.seek(to: progress)
    }
    
    func seekForward() {
        guard !isCleanedUp else { return }
        playerManager?.seekForward(10)
    }
    
    func seekBackward() {
        guard !isCleanedUp else { return }
        playerManager?.seekBackward(10)
    }
    
    // MARK: - Miniplayer Gestures
    func handleMiniplayerDrag(_ translation: CGSize) {
        guard !isCleanedUp else { return }
        miniplayerOffset = max(0, translation.height)
    }
    
    func handleMiniplayerDragEnd(_ translation: CGSize) {
        guard !isCleanedUp else { return }
        
        let dismissThreshold: CGFloat = 100
        let expandThreshold: CGFloat = -50
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if translation.height > dismissThreshold {
                closePlayer()
            } else if translation.height < expandThreshold {
                expandPlayer()
            } else {
                miniplayerOffset = 0
            }
        }
    }
    
    // MARK: - Manual Cleanup (for explicit cleanup)
    func performCleanup() {
        cleanup()
    }

    // MARK: - Flicks Engagement Controls (temporary pause/resume)
    func pauseForFlicksEngagement() {
        guard !isCleanedUp, currentVideo != nil else { return }
        guard !pausedByFlicks else { return }
        wasPlayingBeforeFlicks = isPlaying
        playerManager?.pause()
        isPlaying = false
        pausedByFlicks = true
    }
    
    func resumeAfterLeavingFlicks() {
        guard !isCleanedUp else { return }
        guard pausedByFlicks else { return }
        pausedByFlicks = false
        if wasPlayingBeforeFlicks {
            playerManager?.play()
            isPlaying = true
        }
    }
}

// MARK: - Preview Safe Wrapper
@MainActor
class PreviewSafeGlobalVideoPlayerManager: ObservableObject {
    @Published var currentVideo: Video?
    @Published var isPlaying = false
    @Published var isMiniplayer = false
    @Published var showingFullscreen = false
    @Published var miniplayerOffset: CGFloat = 0
    @Published var currentProgress: Double = 0.0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var miniPlayerHeight: CGFloat = 80
    @Published var shouldShowMiniPlayer = false
    @Published var isTransitioning = false
    
    var player: AVPlayer? { nil }
    
    init() {
        // Safe initialization for previews
        print("🎬 Preview-safe GlobalVideoPlayerManager initialized")
    }
    
    func playVideo(_ video: Video, showFullscreen: Bool = true) {
        print("🎬 Preview: playVideo called for \(video.title)")
    }
    
    func minimizePlayer() {
        print("🎬 Preview: minimizePlayer called")
    }
    
    func expandPlayer() {
        print("🎬 Preview: expandPlayer called")
    }
    
    func closePlayer() {
        print("🎬 Preview: closePlayer called")
    }
    
    func handleNavigationChange(isVideoDetailVisible: Bool) {
        print("🎬 Preview: handleNavigationChange called")
    }
    
    func togglePlayPause() {
        print("🎬 Preview: togglePlayPause called")
    }
    
    func seek(to progress: Double) {
        print("🎬 Preview: seek called")
    }
    
    func seekForward() {
        print("🎬 Preview: seekForward called")
    }
    
    func seekBackward() {
        print("🎬 Preview: seekBackward called")
    }
    
    func handleMiniplayerDrag(_ translation: CGSize) {
        print("🎬 Preview: handleMiniplayerDrag called")
    }
    
    func handleMiniplayerDragEnd(_ translation: CGSize) {
        print("🎬 Preview: handleMiniplayerDragEnd called")
    }
    
    func performCleanup() {
        print("🎬 Preview: performCleanup called")
    }
}

#Preview {
    VStack {
        Text("Global Video Player Manager")
            .font(.largeTitle)
            .padding()
        
        Text("Manages global video playback state")
            .foregroundColor(.secondary)
    }
    .environmentObject(PreviewSafeGlobalVideoPlayerManager())
}