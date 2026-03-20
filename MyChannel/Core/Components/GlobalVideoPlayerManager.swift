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
    @Published var showingFullscreen = false
    @Published var currentProgress: Double = 0.0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var pausedByFlicks = false
    @Published var isPlayerReady = false // 🔥 CRITICAL: Track when player is ready to prevent error UI
    @Published private(set) var fullscreenRequestToken = UUID()
    @Published var hasActivePlaybackSession = false  // 🔥 NUCLEAR: Only true when actively playing a video
    
    // 🔥 YOUTUBE PARITY: Video Queue for Up Next
    @Published var videoQueue: [Video] = []
    @Published var queueIndex: Int = 0
    
    // 🔥 REAL-TIME VIEW TRACKING: AI monitoring integration
    private let viewTracker = RealtimeViewTracker.shared
    private let appState = AppState.shared
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
    private(set) var isCleanedUp = false
    private var wasPlayingBeforeFlicks = false
    private var wasPlayingBeforeBackground = false
    private let allowSystemPictureInPicture = true
    
    // 🔥 YOUTUBE PARITY: Native PiP for background playback
    private let pipController = NativePiPController.shared
    
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
        self.showingFullscreen = false
        
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
              currentVideo != nil else { return }
        
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
        print("🎧 [GlobalPlayer] App entered background")
        guard currentVideo != nil else { return }
        
        configureAudioSession()
        wasPlayingBeforeBackground = isPlaying
        
        // 🔥 YOUTUBE PARITY: Native PiP auto-starts via canStartPictureInPictureAutomaticallyFromInline.
        // If player is active, PiP controller will automatically show the floating window.
        // As a fallback, explicitly start PiP if it hasn't auto-started.
        if wasPlayingBeforeBackground && allowSystemPictureInPicture {
            print("▶️ [GlobalPlayer] Background with active playback — PiP will auto-start")
            
            // Ensure PiP controller is set up
            if let player = player {
                pipController.setup(with: player)
            }
            
            // Fallback: explicitly start PiP if auto-start didn't trigger
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                if !self.pipController.isActive {
                    self.pipController.startPiP()
                }
            }
        }
        // Don't pause — let PiP continue playback in the floating window
    }
    
    private func handleAppWillEnterForeground() {
        print("🎧 [GlobalPlayer] App entering foreground")
        guard currentVideo != nil else { return }
        
        // Native PiP will stop automatically when the user taps the restore button
        // on the PiP window. The restoreUserInterface delegate handles expansion.
        // Only resume playback if PiP stopped and player was paused.
        if !pipController.isActive && wasPlayingBeforeBackground {
            if let player = player, player.timeControlStatus != .playing {
                player.play()
            }
        }
        
        wasPlayingBeforeBackground = false
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ [GlobalVideoPlayerManager] Audio session configured")
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
        
        // 🔥 YOUTUBE PARITY: Handle restore from PiP (user taps PiP window)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ExpandFromNativePiP"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                print("🔄 [GlobalPlayer] Expand from native PiP - user tapped PiP window")
                self?.expandPlayer()
            }
        }
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
        
        UIApplication.shared.endReceivingRemoteControlEvents()
        
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
        showingFullscreen = false
        currentProgress = 0.0
        currentTime = 0
        duration = 0
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
        // Ensure fullscreen UI is hidden when stopping abruptly
        showingFullscreen = false
        currentVideo = nil
    }
    
    // MARK: - Register Local Player for PiP
    /// Register a local player with the global manager so PiP button works.
    /// This is a lightweight method that just sets the video and player reference
    /// without fully adopting the player manager.
    func registerLocalPlayer(video: Video, player: AVPlayer?) {
        guard !isCleanedUp else { return }
        
        print("📝 [GlobalPlayer] Registering local player for PiP: \(video.title)")
        
        // Set the current video so PiP button knows about it
        currentVideo = video
        showingFullscreen = true
        
        // Setup PiP controller with the player
        if let player = player {
            pipController.setup(with: player)
            print("✅ [GlobalPlayer] PiP controller setup for local player: \(video.title)")
        } else {
            print("⚠️ [GlobalPlayer] No player available for PiP setup")
        }
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
                
                // 🔥 NATIVE PIP: Setup PiP controller with the player
                pipController.setup(with: player)
                print("✅ [GlobalPlayer] PiP controller setup for adopted player: \(video.title)")
            } else {
                // Fallback to manager state if player not ready
                isPlaying = externalManager.isPlaying
                print("⚠️ [GlobalPlayer] Player not ready yet during adoption")
            }

            // 🔥 VIEW TRACKING: Always track views, even for own videos
            await startViewTracking(for: video)

            // 🔥 APPLE BEST PRACTICE: Set state synchronously to prevent race conditions
            showingFullscreen = showFullscreen
            
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
            
            print("✅ [GlobalPlayer] Adopted player state: fullscreen=\(showingFullscreen), isPlaying=\(isPlaying)")
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
        
        // ⚡ Use pre-buffered asset if it matches this video's URL (instant start)
        if let preloaded = preloadedAsset,
           let videoURL = URL(string: video.videoURL),
           preloaded.url == videoURL {
            let playerItem = AVPlayerItem(asset: preloaded)
            playerItem.preferredForwardBufferDuration = 10.0
            playerManager?.player?.replaceCurrentItem(with: playerItem)
            playerManager?.requestAutoPlay()
            preloadedAsset = nil
            print("⚡ [GlobalPlayer] Playing from pre-buffered asset — INSTANT: \(video.title)")
        } else {
            playerManager?.setupPlayer(with: video)
            playerManager?.requestAutoPlay()
        }

        // 🔥 YOUTUBE PARITY: Setup native PiP for this player
        if let player = player {
            pipController.setup(with: player)
            print("✅ [GlobalPlayer] PiP controller setup for: \(video.title)")
            
            // 🔥 NATIVE PIP: Optionally auto-start PiP if not showing fullscreen
            if !showFullscreen {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.pipController.startPiP()
                }
            }
        }
        
        // Set fullscreen state
        showingFullscreen = showFullscreen
        
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
    
    // MARK: - Public pre-buffer API

    /// Call this as soon as you know a video URL will be played soon (e.g. profile load).
    /// Warms the AVURLAsset and fills PlayerPoolManager's cache so first-frame is instant.
    func preloadVideo(url: String) {
        guard !isCleanedUp, let assetURL = URL(string: url) else { return }

        preloadTask?.cancel()
        preloadTask = Task { [weak self] in
            guard let self = self else { return }

            let options: [String: Any] = [
                AVURLAssetPreferPreciseDurationAndTimingKey: false,  // faster for streaming
                "AVURLAssetHTTPHeaderFieldsKey": ["Range": "bytes=0-524287"]  // prefetch first 512 KB
            ]
            let asset = AVURLAsset(url: assetURL, options: options)
            asset.resourceLoader.preloadsEligibleContentKeys = true

            async let tracks = asset.load(.tracks)
            async let isPlayable = asset.load(.isPlayable)
            _ = try? await (tracks, isPlayable)

            await MainActor.run { [weak self] in
                guard let self = self, !self.isCleanedUp else { return }
                self.preloadedAsset = asset
                print("⚡ [GlobalPlayer] Pre-buffered intro: \(assetURL.lastPathComponent)")
            }
        }

        // Also warm PlayerPoolManager so the player is ready to go
        PlayerPoolManager.shared.preloadAsset(for: url)
    }

    // 🔥🔥🔥 THERMONUCLEAR: Pre-load next video for INSTANT playback (<100ms)
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
            
            let asset = AVURLAsset(url: url, options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: true
            ])
            asset.resourceLoader.preloadsEligibleContentKeys = true
            
            // 🔥 THERMONUCLEAR: Pre-load ALL critical properties
            async let tracks = asset.load(.tracks)
            async let duration = asset.load(.duration)
            async let isPlayable = asset.load(.isPlayable)
            async let preferredMediaSelection = asset.load(.preferredMediaSelection)
            
            // Wait for all to complete in parallel
            _ = try? await (tracks, duration, isPlayable, preferredMediaSelection)
            
            await MainActor.run { [weak self] in
                guard let self = self, !self.isCleanedUp else { return }
                self.preloadedAsset = asset
                
                // 🔥 PERF: Also cache in PlayerPoolManager for instant reuse
                PlayerPoolManager.shared.preloadAsset(for: nextVideo.videoURL)
            }
        }
        
        // 🔥 THERMONUCLEAR: Pre-load 2 more videos ahead
        if queueIndex + 2 < videoQueue.count {
            PlayerPoolManager.shared.preloadAsset(for: videoQueue[queueIndex + 2].videoURL)
        }
        if queueIndex + 3 < videoQueue.count {
            PlayerPoolManager.shared.preloadAsset(for: videoQueue[queueIndex + 3].videoURL)
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
    
    // 🔥 NATIVE PIP: Start Picture-in-Picture
    func startPiP() {
        guard currentVideo != nil, !isCleanedUp else { 
            print("⚠️ [GlobalPlayer] Cannot start PiP - no video or cleaned up")
            return 
        }
        
        // 🔥 FIX: Don't start PiP if already active
        if pipController.isActive {
            print("⚠️ [GlobalPlayer] PiP already active - skipping")
            return
        }
        
        print("🔽 [GlobalPlayer] startPiP() called")
        print("   Current state: fullscreen=\(showingFullscreen)")
        
        // 🔥 When in fullscreen (VideoDetailView), use PiPPlayerManager
        if showingFullscreen {
            print("🎬 [GlobalPlayer] Starting PiP from fullscreen player...")
            PiPPlayerManager.shared.startPiP()
        } else {
            // Use background PiP controller when not in fullscreen
            print("🎬 [GlobalPlayer] Starting background PiP...")
            pipController.startPiP()
        }
        
        showingFullscreen = false
        
        HapticManager.shared.impact(style: .medium)
        print("✅ [GlobalPlayer] Native PiP starting...")
    }
    
    func expandPlayer() {
        guard let video = currentVideo, !isCleanedUp else {
            print("⚠️ [GlobalPlayer] expandPlayer() early return - no video or cleaned up. currentVideo=\(String(describing: currentVideo?.title)), isCleanedUp=\(isCleanedUp)")
            return
        }
        
        print("🔄 [GlobalVideoPlayerManager] expandPlayer() called")
        print("   video=\(video.title)")
        print("   state BEFORE expand → showingFullscreen=\(showingFullscreen)")
        print("   PiP active: \(pipController.isActive)")
        
        // 🔥 FIX: Stop PiP if active
        if pipController.isActive {
            print("⏹️ [GlobalPlayer] Stopping native PiP before expanding")
            pipController.stopPiP()
            
            // Wait briefly for PiP to stop
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                await self.completeExpansion(video: video)
            }
        } else {
            Task { @MainActor in
                await completeExpansion(video: video)
            }
        }
    }
    
    private func completeExpansion(video: Video) async {
        // Go to fullscreen
        showingFullscreen = true
        
        // Trigger fullscreen presentation
        fullscreenRequestToken = UUID()
        
        // Send notification to present VideoDetailView
        NotificationCenter.default.post(
            name: NSNotification.Name("PresentVideoDetail"),
            object: video
        )
        
        // Ensure player continues playing
        if let player = player, player.rate == 0, isPlaying {
            print("▶️ [GlobalPlayer] Resuming playback in fullscreen")
            player.play()
        }
        
        HapticManager.shared.impact(style: .medium)
        
        print("✅ [GlobalPlayer] Expansion complete - showingFullscreen=\(showingFullscreen)")
        print("✅ [GlobalPlayer] Fullscreen presentation triggered")
    }
    
    func closePlayer() {
        guard !isCleanedUp else { return }
        
        print("🔥 [GlobalPlayer] closePlayer() called")
        
        // 🔥 YOUTUBE PARITY: Stop native PiP if active
        if pipController.isActive {
            pipController.stopPiP()
        }
        
        // 🔥 REAL-TIME VIEW TRACKING: End view session
        Task {
            await endViewTracking()
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            playerManager?.pause()
            playerManager?.player?.replaceCurrentItem(with: nil)  // 🔥 FIX: Clear player item
            currentVideo = nil
            showingFullscreen = false
            isPlayerReady = false  // 🔥 FIX: Mark player as not ready
            isPlaying = false
            hasActivePlaybackSession = false
        }
        
        print("✅ [GlobalPlayer] closePlayer() complete - currentVideo: \(currentVideo == nil ? "nil" : "NOT NIL")")
        
        HapticManager.shared.impact(style: .light)
    }
    
    // 🔥🔥🔥 NUCLEAR RESET: Call this to completely reset player state
    func nuclearReset() {
        print("🔥🔥🔥 [GlobalPlayer] NUCLEAR RESET called - obliterating ALL state")
        
        // Stop any active tracking
        Task {
            await endViewTracking()
        }
        
        // 🔥 YOUTUBE PARITY: Stop native PiP if active
        if pipController.isActive {
            pipController.stopPiP()
        }
        
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
        showingFullscreen = false
        hasActivePlaybackSession = false
        isPlayerReady = false
        pausedByFlicks = false
        
        print("✅ [GlobalPlayer] NUCLEAR RESET complete - ALL state obliterated")
    }
    
    // MARK: - Navigation Handling (Legacy - No longer used for native PiP)
    func handleNavigationChange(isVideoDetailVisible: Bool) {
        guard let _ = currentVideo, !isCleanedUp else { return }
        
        if !isVideoDetailVisible {
            // User navigated away from video detail, start native PiP
            startPiP()
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
    
    // MARK: - Miniplayer Gestures (Removed - Native PiP only)
    // Custom mini player gestures removed - using native iOS PiP instead
    
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
    @Published var showingFullscreen = false
    @Published var currentProgress: Double = 0.0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    var player: AVPlayer? { nil }
    
    init() {
        // Safe initialization for previews
        print("🎬 Preview-safe GlobalVideoPlayerManager initialized")
    }
    
    func playVideo(_ video: Video, showFullscreen: Bool = true) {
        print("🎬 Preview: playVideo called for \(video.title)")
    }
    
    func startPiP() {
        print("🎬 Preview: startPiP called")
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