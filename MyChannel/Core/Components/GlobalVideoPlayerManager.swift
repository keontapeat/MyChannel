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
    @Published private(set) var isBuffering = false

    /// User preference — when true, auto-advance queue on item end (YouTube Up Next parity).
    @Published var upNextAutoplayEnabled: Bool = UserDefaults.standard.object(forKey: "player.upNextAutoplay") as? Bool ?? true {
        didSet { UserDefaults.standard.set(upNextAutoplayEnabled, forKey: "player.upNextAutoplay") }
    }

    /// When true, previous/next queue navigation skips mid-roll ad breaks.
    var skipAdsOnQueueNavigation: Bool = true
    
    // 🔥 YOUTUBE PARITY: Video Queue for Up Next (backed by VideoPlaybackQueue)
    @Published var videoQueue: [Video] = [] {
        didSet { playbackQueue.videos = videoQueue }
    }
    @Published var queueIndex: Int = 0 {
        didSet { playbackQueue.index = queueIndex }
    }
    
    private let viewTracking: GlobalPlayerViewTracking
    private let pipCoordinator = GlobalPlayerPiPCoordinator()
    private let kvoObservers = GlobalPlayerKVOObservers()
    private let audioLifecycle = GlobalPlayerAudioLifecycle()
    
    private var playerManager: VideoPlayerManager?
    
    // 🔥 FIX: Expose playerManager for VideoDetailView to use when expanding from mini player
    var exposedPlayerManager: VideoPlayerManager? {
        playerManager
    }
    private var cancellables = Set<AnyCancellable>()
    private(set) var isCleanedUp = false
    private var wasPlayingBeforeFlicks = false
    
    // Extracted queue + preload helpers (see VideoPlaybackQueue.swift)
    private var playbackQueue = VideoPlaybackQueue()
    private let assetPreloader = VideoAssetPreloader()
    
    var upNextVideo: Video? { playbackQueue.upNext }
    var hasPreviousVideo: Bool { playbackQueue.hasPrevious }
    var hasNextVideo: Bool { playbackQueue.hasNext }

    var player: AVPlayer? {
        playerManager?.player
    }
    
    var hasActivePlayerItem: Bool {
        playerManager?.player?.currentItem != nil
    }
    
    private init() {
        viewTracking = GlobalPlayerViewTracking { video, watchTime, completion, viewToken in
            AppState.shared.trackUniversityWatch(
                video: video,
                watchTime: watchTime,
                completionPercentage: completion,
                viewToken: viewToken
            )
        }

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
        
        viewTracking.currentTime = { [weak self] in self?.currentTime ?? 0 }
        viewTracking.duration = { [weak self] in self?.duration ?? 0 }
        viewTracking.isPlaying = { [weak self] in self?.isPlaying ?? false }
        viewTracking.hasCurrentVideo = { [weak self] in self?.currentVideo != nil }

        pipCoordinator.hasCurrentVideo = { [weak self] in self?.currentVideo != nil }
        pipCoordinator.isPlaying = { [weak self] in self?.isPlaying ?? false }
        pipCoordinator.isCleanedUp = { [weak self] in self?.isCleanedUp ?? true }
        pipCoordinator.showingFullscreen = { [weak self] in self?.showingFullscreen ?? false }
        pipCoordinator.setShowingFullscreen = { [weak self] value in self?.showingFullscreen = value }
        pipCoordinator.player = { [weak self] in self?.player }
        pipCoordinator.onExpandFromPiPTap = { [weak self] in self?.expandPlayer() }

        kvoObservers.isCleanedUp = { [weak self] in self?.isCleanedUp ?? true }
        kvoObservers.onPlayerReadyChanged = { [weak self] ready in self?.isPlayerReady = ready }
        kvoObservers.onPlayingChanged = { [weak self] playing in
            guard let self, self.isPlaying != playing else { return }
            self.isPlaying = playing
        }

        audioLifecycle.onDidEnterBackground = { [weak self] in
            self?.audioLifecycle.configureAudioSessionOnce()
            self?.pipCoordinator.handleDidEnterBackground()
        }
        audioLifecycle.onWillEnterForeground = { [weak self] in
            self?.pipCoordinator.handleWillEnterForeground()
        }
        audioLifecycle.onRouteChange = { [weak self] in
            self?.ensurePlayerAttached()
        }

        registerNowPlayingCallbacks()
        observePlaybackEndForUpNext()
        setupPlayerManager()
        audioLifecycle.configureAudioSessionOnce()
        viewTracking.startHeartbeat()
        audioLifecycle.startObserving()
        pipCoordinator.startObserving()
        
        print("✅ [GlobalPlayer] NUCLEAR INIT complete - EVERY state cleared")
        print("   currentVideo: \(currentVideo == nil ? "nil" : "NOT NIL")")
        print("   isPlayerReady: \(isPlayerReady)")
        print("   hasActivePlaybackSession: \(hasActivePlaybackSession)")
    }
    
    /// Canonical playback session UUID — correlates view analytics across player surfaces.
    var playbackSessionID: String? { viewTracking.playbackSessionID }
    
    deinit {
        print("🗑️ GlobalVideoPlayerManager deinit called")
        audioLifecycle.stopObserving()
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
        
        pipCoordinator.stopAll()
        
        UIApplication.shared.endReceivingRemoteControlEvents()
        
        kvoObservers.invalidate()
        pipCoordinator.teardownObserver()
        
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
        
        kvoObservers.attach(to: playerManager.player)
        
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

        playerManager.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                guard let self, !self.isCleanedUp else { return }
                self.isBuffering = loading
            }
            .store(in: &cancellables)

        playerManager.$hasError
            .combineLatest(playerManager.$isLoading)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasError, isLoading in
                guard let self, !self.isCleanedUp else { return }
                if hasError && !isLoading {
                    self.isPlayerReady = false
                }
            }
            .store(in: &cancellables)

        // Sync lock-screen / Control Center metadata while global player is active.
        Publishers.CombineLatest4(
            playerManager.$currentTime,
            playerManager.$duration,
            playerManager.$isPlaying,
            $currentVideo
        )
        .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
        .sink { [weak self] time, duration, playing, video in
            guard let self, !self.isCleanedUp, let video else { return }
            NowPlayingService.shared.update(
                title: video.title,
                creator: video.creator.displayName,
                thumbnailURL: video.thumbnailURL,
                duration: duration > 0 ? duration : video.duration,
                currentTime: time,
                isPlaying: playing
            )
        }
        .store(in: &cancellables)
    }

    private func registerNowPlayingCallbacks() {
        NowPlayingService.shared.registerCallbacks(
            onPlay: { [weak self] in self?.togglePlayPause() },
            onPause: { [weak self] in self?.togglePlayPause() },
            onSeek: { [weak self] time in
                guard let self, self.duration > 0 else { return }
                self.seek(to: time / self.duration)
            },
            onSkipForward: { [weak self] in self?.seekForward() },
            onSkipBackward: { [weak self] in self?.seekBackward() }
        )
    }

    private func observePlaybackEndForUpNext() {
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self, !self.isCleanedUp, self.upNextAutoplayEnabled else { return }
                guard let item = notification.object as? AVPlayerItem,
                      item === self.player?.currentItem else { return }
                if self.playbackQueue.hasNext {
                    self.playNextVideo()
                }
            }
            .store(in: &cancellables)
    }

    // Stop current playback immediately (used when switching videos fast)
    func stopImmediately() {
        pipCoordinator.stopAll()
        assetPreloader.cancel()
        
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
            pipCoordinator.setup(with: player)
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
                pipCoordinator.setup(with: player)
                print("✅ [GlobalPlayer] PiP controller setup for adopted player: \(video.title)")
            } else {
                // Fallback to manager state if player not ready
                isPlaying = externalManager.isPlaying
                print("⚠️ [GlobalPlayer] Player not ready yet during adoption")
            }

            // 🔥 VIEW TRACKING: Always track views, even for own videos
            await viewTracking.start(for: video)

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
        syncPlaybackQueueFromPublished()
        
        // ⚡ Use pre-buffered asset if it matches this video's URL (instant start)
        if let preloaded = assetPreloader.takePreloadedAsset(for: video.videoURL) {
            let playerItem = AVPlayerItem(asset: preloaded)
            playerItem.preferredForwardBufferDuration = 10.0
            playerManager?.player?.replaceCurrentItem(with: playerItem)
            playerManager?.requestAutoPlay()
            print("⚡ [GlobalPlayer] Playing from pre-buffered asset — INSTANT: \(video.title)")
        } else if let preloaded = assetPreloader.takePreloadedAsset(),
                  let videoURL = URL(string: video.videoURL),
                  preloaded.url == videoURL {
            let playerItem = AVPlayerItem(asset: preloaded)
            playerItem.preferredForwardBufferDuration = 10.0
            playerManager?.player?.replaceCurrentItem(with: playerItem)
            playerManager?.requestAutoPlay()
            print("⚡ [GlobalPlayer] Playing from pre-buffered asset — INSTANT: \(video.title)")
        } else {
            playerManager?.setupPlayer(with: video)
            playerManager?.requestAutoPlay()
        }

        // 🔥 YOUTUBE PARITY: Setup native PiP for this player
        if let player = player {
            pipCoordinator.setup(with: player)
            print("✅ [GlobalPlayer] PiP controller setup for: \(video.title)")
            
            // 🔥 NATIVE PIP: Optionally auto-start PiP if not showing fullscreen
            if !showFullscreen {
                pipCoordinator.scheduleAutoStartIfNotFullscreen()
            }
        }
        
        // Set fullscreen state
        showingFullscreen = showFullscreen
        hasActivePlaybackSession = true

        // 🔥 THERMONUCLEAR: Pre-load next video for instant playback
        preloadNextQueueItems()
        
        // 🔥 REAL-TIME VIEW TRACKING: Start tracking this view
        Task { [weak self] in
            guard let self else { return }
            await self.viewTracking.start(for: video)
        }
        
        HapticManager.shared.impact(style: .medium)
    }
    
    func addToQueue(_ video: Video) {
        if videoQueue.contains(where: { $0.id == video.id }) {
            return
        }
        if videoQueue.isEmpty, let currentVideo {
            videoQueue = [currentVideo, video]
            queueIndex = 0
        } else {
            videoQueue.append(video)
        }
        syncPlaybackQueueFromPublished()
        preloadNextQueueItems()
    }
    
    // 🔥 YOUTUBE PARITY: Navigate to next video in queue
    func playNextVideo() {
        viewTracking.flushUniversityWatchBeforeSwitch()
        if skipAdsOnQueueNavigation {
            playerManager?.cancelCurrentAdBreak()
        }

        guard let nextVideo = playbackQueue.advance() else {
            print("⚠️ [GlobalVideoPlayerManager] No next video in queue")
            return
        }
        
        queueIndex = playbackQueue.index
        videoQueue = playbackQueue.videos
        currentVideo = nextVideo
        
        if let preloaded = assetPreloader.takePreloadedAsset(for: nextVideo.videoURL) {
            let playerItem = AVPlayerItem(asset: preloaded)
            playerItem.preferredForwardBufferDuration = 10.0
            playerManager?.player?.replaceCurrentItem(with: playerItem)
            playerManager?.play()
            print("⚡ [GlobalVideoPlayerManager] Playing next video from pre-loaded asset (INSTANT!)")
        } else if let preloaded = assetPreloader.takePreloadedAsset() {
            let playerItem = AVPlayerItem(asset: preloaded)
            playerItem.preferredForwardBufferDuration = 10.0
            playerManager?.player?.replaceCurrentItem(with: playerItem)
            playerManager?.play()
            print("⚡ [GlobalVideoPlayerManager] Playing next video from pre-loaded asset (INSTANT!)")
        } else {
            playerManager?.pause()
            playerManager?.setupPlayer(with: nextVideo)
            playerManager?.requestAutoPlay()
            print("▶️ [GlobalVideoPlayerManager] Playing next video: \(nextVideo.title)")
        }
        
        preloadNextQueueItems()
        HapticManager.shared.impact(style: .medium)
    }
    
    // MARK: - Public pre-buffer API

    /// Call this as soon as you know a video URL will be played soon (e.g. profile load).
    /// **Canonical preload path for GlobalVideoPlayerManager** — routes exclusively through
    /// `VideoAssetPreloader`. Do not call `PlayerPoolManager.preloadAsset` from here;
    /// pool warming is owned by feature-specific players (Flicks, detail view).
    func preloadVideo(url: String) {
        guard !isCleanedUp else { return }
        assetPreloader.preload(urlString: url)
    }

    private func syncPlaybackQueueFromPublished() {
        playbackQueue.videos = videoQueue
        playbackQueue.index = queueIndex
    }

    /// Pre-load the next two queue items only (batch-7 cap).
    private func preloadNextQueueItems() {
        var urls: [String] = []
        var idx = playbackQueue.index
        while urls.count < VideoAssetPreloader.maxPreloadCount {
            idx += 1
            guard idx < playbackQueue.videos.count else { break }
            urls.append(playbackQueue.videos[idx].videoURL)
        }
        if urls.isEmpty {
            assetPreloader.cancel()
        } else {
            assetPreloader.preload(urlStrings: urls)
        }
    }

    private func preloadNextVideo() {
        preloadNextQueueItems()
    }
    
    // 🔥 YOUTUBE PARITY: Navigate to previous video in queue
    func playPreviousVideo() {
        viewTracking.flushUniversityWatchBeforeSwitch()
        if skipAdsOnQueueNavigation {
            playerManager?.cancelCurrentAdBreak()
        }

        guard let previousVideo = playbackQueue.retreat() else {
            print("⚠️ [GlobalVideoPlayerManager] No previous video in queue")
            return
        }
        
        queueIndex = playbackQueue.index
        videoQueue = playbackQueue.videos
        currentVideo = previousVideo
        
        stopImmediately()
        playerManager?.setupPlayer(with: previousVideo)
        playerManager?.requestAutoPlay()
        
        HapticManager.shared.impact(style: .medium)
        print("◀️ [GlobalVideoPlayerManager] Playing previous video: \(previousVideo.title)")
    }
    
    // 🔥 NATIVE PIP: Start Picture-in-Picture
    func startPiP() {
        pipCoordinator.startPiP()
    }
    
    func expandPlayer() {
        guard let video = currentVideo, !isCleanedUp else {
            print("⚠️ [GlobalPlayer] expandPlayer() early return - no video or cleaned up. currentVideo=\(String(describing: currentVideo?.title)), isCleanedUp=\(isCleanedUp)")
            return
        }
        
        print("🔄 [GlobalVideoPlayerManager] expandPlayer() called")
        print("   video=\(video.title)")
        print("   state BEFORE expand → showingFullscreen=\(showingFullscreen)")
        print("   PiP active: \(pipCoordinator.isActive)")
        
        pipCoordinator.prepareExpansion { [weak self] in
            await self?.completeExpansion(video: video)
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
        
        pipCoordinator.stopAll()
        Task { [weak self] in
            await self?.viewTracking.end()
        }
        NowPlayingService.shared.clear()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            playerManager?.pause()
            playerManager?.player?.replaceCurrentItem(with: nil)  // 🔥 FIX: Clear player item
            currentVideo = nil
            showingFullscreen = false
            isPlayerReady = false  // 🔥 FIX: Mark player as not ready
            isPlaying = false
            hasActivePlaybackSession = false
        }
        assetPreloader.cancel()
        
        print("✅ [GlobalPlayer] closePlayer() complete - currentVideo: \(currentVideo == nil ? "nil" : "NOT NIL")")
        
        HapticManager.shared.impact(style: .light)
    }
    
    // 🔥🔥🔥 NUCLEAR RESET: Call this to completely reset player state
    func nuclearReset() {
        print("🔥🔥🔥 [GlobalPlayer] NUCLEAR RESET called - obliterating ALL state")
        
        // Stop any active tracking
        Task { [weak self] in
            await self?.viewTracking.end()
        }

        kvoObservers.invalidate()
        pipCoordinator.teardownObserver()
        NowPlayingService.shared.clear()
        pipCoordinator.stopAll()
        
        // Destroy player
        playerManager?.pause()
        playerManager?.player?.replaceCurrentItem(with: nil)
        
        // Clear ALL state synchronously
        currentVideo = nil
        videoQueue = []
        queueIndex = 0
        playbackQueue.reset()
        assetPreloader.cancel()
        isPlaying = false
        currentProgress = 0.0
        currentTime = 0
        duration = 0
        showingFullscreen = false
        hasActivePlaybackSession = false
        isPlayerReady = false
        pausedByFlicks = false
        isBuffering = false

        // Re-wire observers after obliterating player state
        setupPlayerManager()
        pipCoordinator.startObserving()
        
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
        HapticManager.shared.impact(style: .light)
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

    /// Switch playback quality from a UI label (e.g. "Auto", "4K", "1080p").
    /// Routes to the underlying `VideoPlayerManager.setPreferredQuality`.
    func setQuality(_ quality: String) {
        guard !isCleanedUp else { return }
        let mapped: VideoQuality
        switch quality.lowercased() {
        case "auto": mapped = .auto
        case "4k", "2160p": mapped = .quality2160p
        case "1440p", "2k": mapped = .quality1440p
        case "1080p": mapped = .quality1080p
        case "720p": mapped = .quality720p
        case "480p": mapped = .quality480p
        case "360p": mapped = .quality360p
        case "240p": mapped = .quality240p
        case "144p": mapped = .quality144p
        default: mapped = VideoQuality(rawValue: quality.lowercased()) ?? .auto
        }
        playerManager?.setPreferredQuality(mapped)
    }
    
    // MARK: - Miniplayer Gestures (Removed - Native PiP only)
    // Custom mini player gestures removed - using native iOS PiP instead
    
    // MARK: - Manual Cleanup (for explicit cleanup)
    func performCleanup() {
        cleanup()
    }

    // MARK: - Flicks Engagement Controls (temporary pause/resume)
    //
    // Flicks uses inline AVPlayers (NuclearVideoPlayerView). When the Flicks tab is visible,
    // pause long-form global playback so only one surface owns audio. FlicksView wires
    // .onAppear → pauseForFlicksEngagement() and .onDisappear → resumeAfterLeavingFlicks().
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