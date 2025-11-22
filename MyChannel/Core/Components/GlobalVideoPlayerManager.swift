//
//  GlobalVideoPlayerManager.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVFoundation
import AVKit
import Combine
import UIKit

// Native iOS PiP + custom mini-player combo
// - When app is in foreground we show our YouTube-style floating mini-player
// - When user leaves the app we hand playback to the system Picture-in-Picture bubble
//   so it behaves exactly like YouTube on iOS

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
    @Published var isPiPActive = false
    @Published var isPlayerReady = false // 🔥 CRITICAL: Track when player is ready to prevent error UI
    @Published private(set) var fullscreenRequestToken = UUID()
    @Published var hasActivePlaybackSession = false  // 🔥 NUCLEAR: Only true when actively playing a video
    
    // 🔥 YOUTUBE PARITY: Video Queue for Up Next
    @Published var videoQueue: [Video] = []
    @Published var queueIndex: Int = 0
    
    // 🔥 REAL-TIME VIEW TRACKING: AI monitoring integration
    private let viewTracker = RealtimeViewTracker.shared
    private let backgroundPlayService = BackgroundPlayService.shared
    private let appState = AppState.shared
    private weak var pipPlayerLayer: AVPlayerLayer?
    private var pipController: AVPictureInPictureController?
    private var currentViewSessionId: String?
    private var heartbeatTimer: Timer?
    
    private var playerManager: VideoPlayerManager?
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    
    // 🔥 FIX: Expose playerManager for VideoDetailView to use when expanding from mini player
    var exposedPlayerManager: VideoPlayerManager? {
        playerManager
    }
    private var cancellables = Set<AnyCancellable>()
    private var timeControlObserver: NSKeyValueObservation? // 🔥 APPLE BEST PRACTICE: Store KVO observer
    private var playerStatusObserver: NSKeyValueObservation? // 🔥 CRITICAL: Store player status observer
    private var playerItemStatusObserver: NSKeyValueObservation? // 🔥 CRITICAL: Store playerItem status observer
    internal(set) var isCleanedUp = false // 🔥 FIX: Make accessible to FloatingMiniPlayer
    private var wasPlayingBeforeFlicks = false
    private var wasPlayingBeforeBackground = false
    private var usingBackgroundAudioBridge = false
    private var backgroundPlayTask: Task<Void, Never>?
    
    // 🔥 THERMONUCLEAR: Video pre-loading for instant next video
    private var preloadedAsset: AVURLAsset?
    private var preloadTask: Task<Void, Never>?
    
    var upNextVideo: Video? {
        guard queueIndex + 1 < videoQueue.count else { return nil }
        return videoQueue[queueIndex + 1]
    }
    
    var hasPreviousVideo: Bool {
        queueIndex > 0
    }
    
    var hasNextVideo: Bool {
        queueIndex + 1 < videoQueue.count
    }

    var player: AVPlayer? {
        playerManager?.player
    }
    
    var hasActivePlayerItem: Bool {
        playerManager?.player?.currentItem != nil
    }
    
    private init() {
        // 🔥🔥🔥 NUCLEAR INIT: Clear EVERY SINGLE piece of state
        print("🔥🔥🔥 [GlobalPlayer] NUCLEAR INIT starting...")
        
        // Clear video state
        self.currentVideo = nil
        self.videoQueue = []
        self.queueIndex = 0
        
        // Clear playback state
        self.isPlaying = false
        self.currentProgress = 0.0
        self.currentTime = 0
        self.duration = 0
        
        // Clear mini-player state (CRITICAL)
        self.shouldShowMiniPlayer = false  // 🔥 NEVER show on init
        self.isMiniplayer = false
        self.showingFullscreen = false
        self.miniplayerOffset = 0
        self.isTransitioning = false
        
        // Clear PiP state
        self.isPiPActive = false
        
        // Clear session state
        self.hasActivePlaybackSession = false
        self.isPlayerReady = false
        self.pausedByFlicks = false
        
        // Setup managers
        setupPlayerManager()
        configureAudioSession()
        setupViewTracking()
        observeAppLifecycle()
        
        print("✅ [GlobalPlayer] NUCLEAR INIT complete - EVERY state cleared")
        print("   currentVideo: \(currentVideo == nil ? "nil" : "NOT NIL")")
        print("   shouldShowMiniPlayer: \(shouldShowMiniPlayer)")
        print("   isPlayerReady: \(isPlayerReady)")
        print("   hasActivePlaybackSession: \(hasActivePlaybackSession)")
    }
    
    // MARK: - Real-time View Tracking
    
    private func setupViewTracking() {
        // Setup heartbeat timer for view tracking (every 10 seconds)
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.sendViewHeartbeat()
            }
        }
    }
    
    private func startViewTracking(for video: Video) async {
        // End previous session if exists
        if let sessionId = currentViewSessionId {
            await viewTracker.endViewSession(sessionId: sessionId)
        }
        
        // Start new view session
        let userId = AuthenticationManager.shared.currentUser?.id
        await viewTracker.startViewSession(videoId: video.id, userId: userId)
        
        // Store session ID
        currentViewSessionId = UUID().uuidString
        
        print("👁️ [GlobalPlayer] Started view tracking for: \(video.title)")
    }
    
    private func sendViewHeartbeat() async {
        guard let sessionId = currentViewSessionId,
              let video = currentVideo else { return }
        
        await viewTracker.updateViewHeartbeat(
            sessionId: sessionId,
            currentTime: currentTime,
            isPlaying: isPlaying
        )
    }
    
    private func endViewTracking() async {
        guard let sessionId = currentViewSessionId else { return }
        
        await viewTracker.endViewSession(sessionId: sessionId)
        currentViewSessionId = nil
        
        print("👋 [GlobalPlayer] Ended view tracking")
    }
    
    private func handleAppDidEnterBackground() {
        print("🎧 [GlobalPlayer] App entered background - maintaining custom mini player")
        guard let video = currentVideo else { return }
        
        // Ensure audio session stays active for background playback
        configureAudioSession()
        
        wasPlayingBeforeBackground = isPlaying
        
        // Keep mini player state so it reappears instantly on return
        if !showingFullscreen {
            shouldShowMiniPlayer = true
            isMiniplayer = true
        }
        
        guard wasPlayingBeforeBackground else {
            playerManager?.pause()
            return
        }
        
        if startPiPWhenBackgrounding() {
            print("🎬 [GlobalPlayer] Started native PiP while app backgrounded")
            return
        }
        
        handoffToBackgroundAudio(with: video)
    }
    
    private func handleAppWillEnterForeground() {
        print("🎧 [GlobalPlayer] App entering foreground - restoring mini player state")
        guard currentVideo != nil else { return }
        if isPiPActive { return }
        
        if !showingFullscreen {
            shouldShowMiniPlayer = true
            isMiniplayer = true
        }
        
        restoreFromBackgroundAudioIfNeeded()
    }
    
    private func handoffToBackgroundAudio(with video: Video) {
        guard !usingBackgroundAudioBridge else { return }
        backgroundPlayTask?.cancel()
        
        backgroundPlayTask = Task { [weak self] in
            guard let self = self else { return }
            
            guard self.backgroundPlayService.isBackgroundPlayEnabled else {
                if self.wasPlayingBeforeBackground {
                    self.playerManager?.play()
                }
                return
            }
            
            self.playerManager?.pause()
            
            do {
                try await self.backgroundPlayService.startBackgroundPlay(for: video, at: self.currentTime)
                self.usingBackgroundAudioBridge = true
                print("🎧 [GlobalPlayer] Background audio bridge active")
            } catch {
                self.usingBackgroundAudioBridge = false
                print("⚠️ [GlobalPlayer] Background audio handoff failed: \(error.localizedDescription)")
                if self.wasPlayingBeforeBackground {
                    self.playerManager?.play()
                }
            }
        }
    }
    
    private func restoreFromBackgroundAudioIfNeeded() {
        backgroundPlayTask?.cancel()
        
        if isPiPActive {
            return
        }
        
        if usingBackgroundAudioBridge {
            let resumeTime = backgroundPlayService.currentPlaybackTime
            backgroundPlayService.stopBackgroundPlay()
            usingBackgroundAudioBridge = false
            
            if resumeTime.isFinite {
                playerManager?.seekToTime(resumeTime)
            }
            
            if wasPlayingBeforeBackground {
                playerManager?.play()
            } else {
                playerManager?.pause()
            }
        } else if wasPlayingBeforeBackground, let player = player, player.timeControlStatus != .playing {
            player.play()
        }
        
        wasPlayingBeforeBackground = false
    }
    
    // 🔥 YOUTUBE PARITY: Configure audio session for background playback
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [])
            try audioSession.setActive(true)
            print("✅ [GlobalVideoPlayerManager] Audio session configured for background playback")
        } catch {
            print("⚠️ [GlobalVideoPlayerManager] Failed to configure audio session: \(error)")
        }
    }
    
    private func observeAppLifecycle() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppDidEnterBackground()
            }
        }
        
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppWillEnterForeground()
            }
        }
    }
    
    // MARK: - Native Picture-in-Picture
    func setupPictureInPicture(for playerLayer: AVPlayerLayer, controller: AVPictureInPictureController) {
        pipPlayerLayer = playerLayer
        pipController = controller
        print("🎬 [GlobalPlayer] PiP controller registered")
    }
    
    func clearPictureInPicture(controller: AVPictureInPictureController) {
        if pipController === controller {
            pipController = nil
            pipPlayerLayer = nil
            print("🧹 [GlobalPlayer] PiP controller cleared")
        }
    }
    
    func handlePiPStateChange(isActive: Bool) {
        isPiPActive = isActive
        if isActive {
            shouldShowMiniPlayer = false
            isMiniplayer = false
            print("📺 [GlobalPlayer] PiP active - hiding custom mini player")
        } else {
            handlePiPDidStopFromSystem()
        }
    }
    
    func handlePiPDidStopFromSystem() {
        isPiPActive = false
        if currentVideo != nil && !showingFullscreen {
            shouldShowMiniPlayer = true
            isMiniplayer = true
            print("📺 [GlobalPlayer] PiP stopped - restoring custom mini player")
        }
    }
    
    @discardableResult
    func togglePictureInPicture() -> Bool {
        guard let pipController else {
            print("⚠️ [GlobalPlayer] No PiP controller available")
            return false
        }
        
        if pipController.isPictureInPictureActive {
            pipController.stopPictureInPicture()
            return true
        } else if pipController.isPictureInPicturePossible {
            pipController.startPictureInPicture()
            return true
        }
        
        print("⚠️ [GlobalPlayer] PiP controller exists but cannot start")
        return false
    }
    
    @discardableResult
    func startPictureInPictureIfPossible() -> Bool {
        guard let pipController else { return false }
        guard pipController.isPictureInPicturePossible else { return false }
        if !pipController.isPictureInPictureActive {
            pipController.startPictureInPicture()
        }
        return true
    }
    
    @discardableResult
    func startPiPWhenBackgrounding() -> Bool {
        guard appState.autoPiPEnabled else { return false }
        return startPictureInPictureIfPossible()
    }
    
    func stopPictureInPictureIfActive() {
        guard let pipController, pipController.isPictureInPictureActive else { return }
        pipController.stopPictureInPicture()
    }
    
    deinit {
        print("🗑️ GlobalVideoPlayerManager deinit called")
        if let backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
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
        
        stopPictureInPictureIfActive()
        pipController = nil
        pipPlayerLayer = nil
        
        // 🔥 APPLE BEST PRACTICE: Invalidate KVO observers before cleanup
        timeControlObserver?.invalidate()
        timeControlObserver = nil
        playerStatusObserver?.invalidate()
        playerStatusObserver = nil
        playerItemStatusObserver?.invalidate()
        playerItemStatusObserver = nil
        
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

    // Ensure player exists for current video (used by mini player resilience)
    func ensurePlayerAttached() {
        guard !isCleanedUp else { return }
        
        // 🔥 CRITICAL: Always ensure player manager exists
        if playerManager == nil {
            setupPlayerManager()
        }
        
        // 🔥 CRITICAL: Setup player if video exists but player isn't ready
        if let video = currentVideo {
            // Check if player needs setup
            if playerManager?.player == nil {
                print("🔄 [GlobalPlayer] Player not found - setting up for: \(video.title)")
                playerManager?.setupPlayer(with: video)
                playerManager?.requestAutoPlay()
            } else if let player = playerManager?.player,
                      let playerItem = player.currentItem,
                      (player.status != .readyToPlay || playerItem.status != .readyToPlay) {
                // Player exists but not ready - might need to reload
                print("🔄 [GlobalPlayer] Player exists but not ready - status: \(player.status.rawValue), item status: \(playerItem.status.rawValue)")
                
                // If failed, try to reload
                if playerItem.status == .failed {
                    print("🔄 [GlobalPlayer] PlayerItem failed - reloading player")
                    playerManager?.setupPlayer(with: video)
                    playerManager?.requestAutoPlay()
                }
            }
        }
    }
    
    private func setupObservers() {
        guard let playerManager = playerManager, !isCleanedUp else { return }
        
        // Clear existing cancellables
        cancellables.removeAll()
        
        // 🔥 APPLE BEST PRACTICE: Observe AVPlayer.timeControlStatus directly for accurate state
        // This ensures state is always in sync with actual player state
        // Invalidate previous observer if exists
        timeControlObserver?.invalidate()
        
        if let player = playerManager.player {
            // 🔥 CRITICAL: Observe player status to track when ready
            // Invalidate previous observer
            playerStatusObserver?.invalidate()
            playerStatusObserver = player.observe(\.status, options: [.new, .initial]) { [weak self] player, _ in
                Task { @MainActor in
                    guard let self = self, !self.isCleanedUp else { return }
                    let isReady = player.status == .readyToPlay
                    self.isPlayerReady = isReady
                    print("🎬 [GlobalPlayer] Player status: \(player.status.rawValue), ready: \(isReady)")
                }
            }
            
            // Observe playerItem status too
            playerItemStatusObserver?.invalidate()
            if let playerItem = player.currentItem {
                playerItemStatusObserver = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
                    Task { @MainActor in
                        guard let self = self, !self.isCleanedUp else { return }
                        let isReady = item.status == .readyToPlay && player.status == .readyToPlay
                        self.isPlayerReady = isReady
                        
                        if item.status == .failed {
                            print("❌ [GlobalPlayer] PlayerItem failed: \(item.error?.localizedDescription ?? "Unknown")")
                            self.isPlayerReady = false
                        }
                        
                        print("🎬 [GlobalPlayer] PlayerItem status: \(item.status.rawValue), ready: \(isReady)")
                    }
                }
            } else {
                isPlayerReady = false
            }
            
            // Observe timeControlStatus directly from AVPlayer (Apple's recommended approach)
            timeControlObserver = player.observe(\.timeControlStatus, options: [.new, .initial]) { [weak self] player, _ in
                Task { @MainActor in
                    guard let self = self, !self.isCleanedUp else { return }
                    let newIsPlaying = player.timeControlStatus == .playing
                    if self.isPlaying != newIsPlaying {
                        self.isPlaying = newIsPlaying
                        print("🎬 [GlobalPlayer] Play state synced via KVO: \(newIsPlaying ? "PLAYING" : "PAUSED")")
                    }
                }
            }
        } else {
            isPlayerReady = false
        }
        
        // Use weak self to prevent retain cycles
        playerManager.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                guard let self = self, !self.isCleanedUp else { return }
                // Only update if different to prevent unnecessary updates
                if self.isPlaying != isPlaying {
                    self.isPlaying = isPlaying
                }
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
                                    showFullscreen: Bool) async {
        guard !isCleanedUp else { return }

        print("🔄 [GlobalPlayer] Adopting external player manager for: \(video.title)")
        print("🔄 [GlobalPlayer] showFullscreen: \(showFullscreen)")

        // 🔥 APPLE BEST PRACTICE: Adopt player synchronously on MainActor
        // Task { @MainActor in // 🔥 REMOVED: This Task caused a race condition
            // Point our manager to the external one and wire observers
            playerManager = externalManager
            setupObservers()

            currentVideo = video
            
            // 🔥 APPLE BEST PRACTICE: Sync state from actual player, not just manager
            if let player = player {
                // Get actual play state from AVPlayer.timeControlStatus
                let actualIsPlaying = player.timeControlStatus == .playing
                isPlaying = actualIsPlaying
                print("🔄 [GlobalPlayer] Synced play state from player: \(actualIsPlaying)")
            } else {
                // Fallback to manager state if player not ready
                isPlaying = externalManager.isPlaying
            }

            // 🔥 VIEW TRACKING: Always track views, even for own videos
            await startViewTracking(for: video)

            // 🔥 APPLE BEST PRACTICE: Set state synchronously to prevent race conditions
            showingFullscreen = showFullscreen
            isMiniplayer = !showFullscreen
            shouldShowMiniPlayer = !showFullscreen
            miniplayerOffset = 0
            
            // 🔥 APPLE BEST PRACTICE: Ensure player state matches expected state
            if let player = player {
                let shouldBePlaying = isPlaying
                let isActuallyPlaying = player.timeControlStatus == .playing
                
                if shouldBePlaying && !isActuallyPlaying {
                    print("▶️ [GlobalPlayer] Resuming playback after adoption")
                    player.play()
                } else if !shouldBePlaying && isActuallyPlaying {
                    print("⏸️ [GlobalPlayer] Pausing playback after adoption")
                    player.pause()
                }
            }
            
            print("✅ [GlobalPlayer] Mini player state: shouldShow=\(shouldShowMiniPlayer), isMini=\(isMiniplayer), fullscreen=\(showingFullscreen), isPlaying=\(isPlaying)")
        // } // 🔥 REMOVED
    }

    // MARK: - Video Management
    func playVideo(_ video: Video, showFullscreen: Bool = true, queue: [Video] = []) {
        guard !isCleanedUp else { return }
        
        // Stop any current playback immediately to avoid overlap when switching fast
        stopImmediately()
        
        // Ensure we have a player manager
        if playerManager == nil {
            setupPlayerManager()
        }
        
        currentVideo = video
        
        // 🔥 YOUTUBE PARITY: Setup video queue
        if !queue.isEmpty {
            videoQueue = queue
            queueIndex = queue.firstIndex(where: { $0.id == video.id }) ?? 0
        } else {
            videoQueue = [video]
            queueIndex = 0
        }
        
        playerManager?.setupPlayer(with: video)
        playerManager?.requestAutoPlay()
        
        // Default behavior – show mini when not fullscreen
        showingFullscreen = showFullscreen
        isMiniplayer = !showFullscreen
        shouldShowMiniPlayer = !showFullscreen
        
        // 🔥 THERMONUCLEAR: Pre-load next video for instant playback
        preloadNextVideo()
        
        // 🔥 REAL-TIME VIEW TRACKING: Start tracking this view
        Task {
            await startViewTracking(for: video)
        }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    // 🔥 YOUTUBE PARITY: Navigate to next video in queue
    func playNextVideo() {
        guard hasNextVideo else {
            print("⚠️ [GlobalVideoPlayerManager] No next video in queue")
            return
        }
        
        queueIndex += 1
        let nextVideo = videoQueue[queueIndex]
        currentVideo = nextVideo
        
        // 🔥 THERMONUCLEAR: Use pre-loaded asset if available (INSTANT START!)
        if let preloadedAsset = preloadedAsset {
            let playerItem = AVPlayerItem(asset: preloadedAsset)
            playerItem.preferredForwardBufferDuration = 10.0  // 10s buffer
            playerManager?.player?.replaceCurrentItem(with: playerItem)
            playerManager?.play()
            print("⚡ [GlobalVideoPlayerManager] Playing next video from pre-loaded asset (INSTANT!)")
            
            // Clear pre-loaded asset
            self.preloadedAsset = nil
        } else {
            // Fallback to regular setup
            stopImmediately()
            playerManager?.setupPlayer(with: nextVideo)
            playerManager?.requestAutoPlay()
            print("▶️ [GlobalVideoPlayerManager] Playing next video: \(nextVideo.title)")
        }
        
        // Pre-load the NEXT next video
        preloadNextVideo()
        
        HapticManager.shared.impact(style: .medium)
    }
    
    // 🔥 THERMONUCLEAR: Pre-load next video in queue for instant playback
    private func preloadNextVideo() {
        guard hasNextVideo else {
            preloadedAsset = nil
            preloadTask?.cancel()
            return
        }
        
        let nextVideo = videoQueue[queueIndex + 1]
        
        // Cancel previous preload
        preloadTask?.cancel()
        
        preloadTask = Task { [weak self] in
            guard let self = self else { return }
            guard let url = URL(string: nextVideo.videoURL) else { return }
            
            print("🔄 [GlobalVideoPlayerManager] Pre-loading next video: \(nextVideo.title)")
            
            let asset = AVURLAsset(url: url)
            asset.resourceLoader.preloadsEligibleContentKeys = true
            
            // Pre-load tracks and duration (warms up the cache)
            _ = try? await asset.load(.tracks)
            _ = try? await asset.load(.duration)
            _ = try? await asset.load(.isPlayable)
            
            await MainActor.run { [weak self] in
                guard let self = self, !self.isCleanedUp else { return }
                self.preloadedAsset = asset
                print("✅ [GlobalVideoPlayerManager] Pre-loaded next video: \(nextVideo.title) - READY FOR INSTANT START!")
            }
        }
    }
    
    // 🔥 YOUTUBE PARITY: Navigate to previous video in queue
    func playPreviousVideo() {
        guard hasPreviousVideo else {
            print("⚠️ [GlobalVideoPlayerManager] No previous video in queue")
            return
        }
        
        queueIndex -= 1
        let previousVideo = videoQueue[queueIndex]
        currentVideo = previousVideo
        
        stopImmediately()
        playerManager?.setupPlayer(with: previousVideo)
        playerManager?.requestAutoPlay()
        
        HapticManager.shared.impact(style: .medium)
        print("◀️ [GlobalVideoPlayerManager] Playing previous video: \(previousVideo.title)")
    }
    
    // 🔥 YOUTUBE PARITY: Minimize to mini player (when backing out of fullscreen)
    func minimizePlayer() {
        guard currentVideo != nil, !isCleanedUp else { 
            print("⚠️ [GlobalPlayer] Cannot minimize - no video or cleaned up")
            return 
        }
        
        print("🔽 [GlobalPlayer] minimizePlayer() called")
        print("   Current state: shouldShow=\(shouldShowMiniPlayer), isMini=\(isMiniplayer), fullscreen=\(showingFullscreen)")
        
        // 🔥 FIX: Remove the guard that was blocking mini-player from appearing!
        // The old guard prevented the mini-player from showing when it should
        
        print("🔄 [GlobalPlayer] Setting mini-player state synchronously...")
        
        // 🔥 CRITICAL: Set ALL states synchronously to prevent race conditions
        // Don't use Task {} - set state IMMEDIATELY on MainActor
        showingFullscreen = false
        isMiniplayer = true
        shouldShowMiniPlayer = true
        isTransitioning = true  // Block UI interference during animation
        
        print("✅ [GlobalPlayer] Mini-player state set:")
        print("   shouldShowMiniPlayer: \(shouldShowMiniPlayer)")
        print("   isMiniplayer: \(isMiniplayer)")
        print("   showingFullscreen: \(showingFullscreen)")
        
        // 🔥 FIX: Clear transition flag after animation completes
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            isTransitioning = false
            print("✅ [GlobalPlayer] Transition complete - mini-player fully visible")
        }
        
        HapticManager.shared.impact(style: .medium)
    }
    
    func expandPlayer() {
        guard let video = currentVideo, !isCleanedUp else {
            print("⚠️ [GlobalPlayer] expandPlayer() early return - no video or cleaned up. currentVideo=\(String(describing: currentVideo?.title)), isCleanedUp=\(isCleanedUp)")
            return
        }
        
        print("🔄 [GlobalVideoPlayerManager] expandPlayer() called from mini player")
        print("   video=\(video.title)")
        print("   state BEFORE expand → showingFullscreen=\(showingFullscreen), shouldShowMiniPlayer=\(shouldShowMiniPlayer), isMiniplayer=\(isMiniplayer), isTransitioning=\(isTransitioning), isPlayerReady=\(isPlayerReady), playerExists=\(player != nil)")
        
        // 🔥 CRITICAL: Set isTransitioning FIRST to block ALL UI from showing
        // This prevents mini player, PiP, and any other UI from appearing
        isTransitioning = true
        
        // 🔥 CRITICAL: Hide mini player IMMEDIATELY before doing anything else
        // Set ALL state synchronously to ensure mini player disappears instantly
        showingFullscreen = true
        isMiniplayer = false
        shouldShowMiniPlayer = false
        
        print("✅ [GlobalPlayer] State set IMMEDIATELY in expandPlayer()")
        print("   state AFTER expand (pre-player-check) → showingFullscreen=\(showingFullscreen), shouldShowMiniPlayer=\(shouldShowMiniPlayer), isMiniplayer=\(isMiniplayer), isTransitioning=\(isTransitioning)")
        
        // 🚫 NATIVE PiP REMOVED: No need to exit PiP mode (we use custom mini player)
        // Custom FloatingMiniPlayer automatically hides when showingFullscreen = true
        
        // 🔥 FIX: Ensure player is ready before presenting
        guard let player = player else {
            print("🚨 [GlobalPlayer] expandPlayer(): player == nil, setting up new player for \(video.title)")
            setupPlayerManager()
            playerManager?.setupPlayer(with: video)
            // Wait a bit for player to be ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                print("🔁 [GlobalPlayer] Retrying presentFullscreenVideo() after creating player")
                self?.presentFullscreenVideo()
            }
            return
        }
        
        // 🔥 FIX: Ensure player is attached and ready
        if player.currentItem == nil {
            print("⚠️ [GlobalPlayer] expandPlayer(): player.currentItem == nil, setting up for \(video.title)")
            playerManager?.setupPlayer(with: video)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                print("🔁 [GlobalPlayer] Retrying presentFullscreenVideo() after setting up currentItem")
                self?.presentFullscreenVideo()
            }
            return
        }
        
        // Player is ready - present immediately
        presentFullscreenVideo()
    }
    
    // 🔥 FIX: Separate function to present fullscreen video
    private func presentFullscreenVideo() {
        guard let video = currentVideo, !isCleanedUp else { return }
        
        // 🔥 CRITICAL: State already set in expandPlayer() - just ensure it's still correct
        // Double-check state to prevent mini player from showing
        showingFullscreen = true
        isMiniplayer = false
        shouldShowMiniPlayer = false
        
        print("✅ [GlobalPlayer] State verified - showingFullscreen: \(showingFullscreen), shouldShowMiniPlayer: \(shouldShowMiniPlayer)")
        
        fullscreenRequestToken = UUID()
        
        // 🔥 FIX: Send notification to present VideoDetailView
        // This triggers the fullScreenCover in MainTabView
        NotificationCenter.default.post(
            name: NSNotification.Name("PresentVideoDetailFromMiniPlayer"),
            object: nil,
            userInfo: ["video": video]
        )
        
        // Ensure player continues playing
        if let player = player, player.rate == 0, isPlaying {
            print("▶️ [GlobalPlayer] Resuming playback in fullscreen")
            player.play()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, !self.isCleanedUp else { return }
            self.isTransitioning = false
        }
        
        HapticManager.shared.impact(style: .medium)
        print("✅ [GlobalPlayer] Fullscreen presentation triggered")
    }
    
    func closePlayer() {
        guard !isCleanedUp else { return }
        
        print("🔥 [GlobalPlayer] closePlayer() called")
        
        stopPictureInPictureIfActive()
        
        // 🔥 REAL-TIME VIEW TRACKING: End view session
        Task {
            await endViewTracking()
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            playerManager?.pause()
            playerManager?.player?.replaceCurrentItem(with: nil)  // 🔥 FIX: Clear player item
            currentVideo = nil
            isMiniplayer = false
            showingFullscreen = false
            shouldShowMiniPlayer = false
            miniplayerOffset = 0
            isPlayerReady = false  // 🔥 FIX: Mark player as not ready
            isPlaying = false
            hasActivePlaybackSession = false
        }
        
        print("✅ [GlobalPlayer] closePlayer() complete - shouldShowMiniPlayer: \(shouldShowMiniPlayer), currentVideo: \(currentVideo == nil ? "nil" : "NOT NIL")")
        
        HapticManager.shared.impact(style: .light)
    }
    
    // 🔥🔥🔥 NUCLEAR RESET: Call this to completely reset player state
    func nuclearReset() {
        print("🔥🔥🔥 [GlobalPlayer] NUCLEAR RESET called - obliterating ALL state")
        
        // Stop any active tracking
        Task {
            await endViewTracking()
        }
        
        stopPictureInPictureIfActive()
        
        // Destroy player
        playerManager?.pause()
        playerManager?.player?.replaceCurrentItem(with: nil)
        
        // Clear ALL state synchronously
        currentVideo = nil
        videoQueue = []
        queueIndex = 0
        isPlaying = false
        currentProgress = 0.0
        currentTime = 0
        duration = 0
        shouldShowMiniPlayer = false
        isMiniplayer = false
        showingFullscreen = false
        miniplayerOffset = 0
        isTransitioning = false
        isPiPActive = false
        hasActivePlaybackSession = false
        isPlayerReady = false
        pausedByFlicks = false
        
        print("✅ [GlobalPlayer] NUCLEAR RESET complete - ALL state obliterated")
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