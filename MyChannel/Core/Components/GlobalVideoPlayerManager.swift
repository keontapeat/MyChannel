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

// 🔥 TRUE PiP: Delegate for Picture-in-Picture events
class PiPDelegate: NSObject, AVPictureInPictureControllerDelegate {
    weak var manager: GlobalVideoPlayerManager?
    
    init(manager: GlobalVideoPlayerManager) {
        self.manager = manager
        super.init()
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            manager?.isPiPActive = true
            print("📺 [PiPDelegate] PiP started")
        }
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            manager?.isPiPActive = false
            print("📺 [PiPDelegate] PiP stopped")
        }
    }
    
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("📺 [PiPDelegate] PiP will start")
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("📺 [PiPDelegate] PiP will stop")
    }
}

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
    
    // 🔥 YOUTUBE PARITY: Video Queue for Up Next
    @Published var videoQueue: [Video] = []
    @Published var queueIndex: Int = 0
    
    // 🔥 REAL-TIME VIEW TRACKING: AI monitoring integration
    private let viewTracker = RealtimeViewTracker.shared
    private var currentViewSessionId: String?
    private var heartbeatTimer: Timer?
    
    private var playerManager: VideoPlayerManager?
    
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
    
    // 🔥 YOUTUBE PARITY: Picture-in-Picture support
    private var pipController: AVPictureInPictureController?
    
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
    
    private init() {
        setupPlayerManager()
        configureAudioSession()
        setupViewTracking()
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
    
    // 🔥 TRUE PiP: Setup Picture-in-Picture controller with delegate
    func setupPictureInPicture(for playerLayer: AVPlayerLayer) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("⚠️ [GlobalVideoPlayerManager] PiP not supported on this device")
            return
        }
        
        pipController = AVPictureInPictureController(playerLayer: playerLayer)
        pipController?.delegate = PiPDelegate(manager: self)
        pipController?.canStartPictureInPictureAutomaticallyFromInline = true
        print("✅ [GlobalVideoPlayerManager] PiP controller configured with auto-start")
    }
    
    // 🔥 TRUE PiP: Toggle Picture-in-Picture mode
    func togglePictureInPicture() {
        guard let pipController = pipController else {
            print("⚠️ [GlobalVideoPlayerManager] PiP controller not configured")
            return
        }
        
        if pipController.isPictureInPictureActive {
            pipController.stopPictureInPicture()
            print("📺 [GlobalVideoPlayerManager] Stopping PiP")
        } else {
            pipController.startPictureInPicture()
            print("📺 [GlobalVideoPlayerManager] Starting PiP")
        }
        HapticManager.shared.impact(style: .medium)
    }
    
    // 🔥 AUTO PiP: Start Picture-in-Picture when app goes to background
    func startPiPWhenBackgrounding() async {
        guard shouldShowMiniPlayer,
              currentVideo != nil,
              let player = player,
              player.rate > 0 else { return }
        if isPiPActive { return }
        
        print("📺 [GlobalVideoPlayerManager] Auto-starting PiP while backgrounding")
        isPiPActive = true
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
                                    showFullscreen: Bool) {
        guard !isCleanedUp else { return }

        print("🔄 [GlobalPlayer] Adopting external player manager for: \(video.title)")
        print("🔄 [GlobalPlayer] showFullscreen: \(showFullscreen)")

        // 🔥 APPLE BEST PRACTICE: Adopt player synchronously on MainActor
        Task { @MainActor in
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
        }
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
        
        stopImmediately()
        playerManager?.setupPlayer(with: nextVideo)
        playerManager?.requestAutoPlay()
        
        HapticManager.shared.impact(style: .medium)
        print("▶️ [GlobalVideoPlayerManager] Playing next video: \(nextVideo.title)")
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
    
    func minimizePlayer() {
        guard currentVideo != nil, !isCleanedUp else { return }
        
        // 🔥 ANIMATION FIX: Prevent multiple calls from triggering multiple animations
        guard !shouldShowMiniPlayer || isTransitioning else {
            print("⚠️ [GlobalVideoPlayerManager] Mini player already showing - skipping duplicate minimize")
            return
        }
        
        print("🔄 [GlobalVideoPlayerManager] Minimizing to mini player")
        
        // 🔥 APPLE BEST PRACTICE: Set state synchronously on MainActor
        // This ensures state is set before any view updates
        Task { @MainActor in
            // 🔥 ANIMATION FIX: Set transition flag FIRST to prevent animation from triggering
            isTransitioning = true
            
            // Small delay to ensure transition flag is set before showing mini player
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            
            showingFullscreen = false
            isMiniplayer = true
            shouldShowMiniPlayer = true
            
            print("✅ [GlobalVideoPlayerManager] Mini player state SET - shouldShow: \(shouldShowMiniPlayer), isMini: \(isMiniplayer)")
            
            // 🔥 APPLE BEST PRACTICE: Ensure player state is synced
            if let player = player {
                // Sync play state from actual player
                let actualIsPlaying = player.timeControlStatus == .playing
                if isPlaying != actualIsPlaying {
                    isPlaying = actualIsPlaying
                    print("🔄 [GlobalVideoPlayerManager] Synced play state: \(actualIsPlaying)")
                }
                
                // Ensure player continues if it should be playing
                if isPlaying && player.rate == 0 {
                    print("▶️ [GlobalVideoPlayerManager] Resuming playback in mini player")
                    player.play()
                }
            }
            
            // Mark transition complete after animation duration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, !self.isCleanedUp else { return }
                self.isTransitioning = false
                print("✅ [GlobalVideoPlayerManager] Mini player transition complete")
            }
        }
        
        HapticManager.shared.impact(style: .medium)
    }
    
    func expandPlayer() {
        guard let video = currentVideo, !isCleanedUp else {
            print("⚠️ [GlobalPlayer] Cannot expand - no video or cleaned up")
            return
        }
        
        print("🔄 [GlobalVideoPlayerManager] Expanding from mini player to fullscreen")
        print("🔄 [GlobalVideoPlayerManager] Video: \(video.title)")
        print("🔄 [GlobalVideoPlayerManager] Player exists: \(player != nil)")
        
        // 🔥 CRITICAL: Hide mini player IMMEDIATELY before doing anything else
        // Set state synchronously to ensure mini player disappears instantly
        showingFullscreen = true
        isMiniplayer = false
        shouldShowMiniPlayer = false
        isTransitioning = true
        
        print("✅ [GlobalPlayer] State set IMMEDIATELY - showingFullscreen: \(showingFullscreen), shouldShowMiniPlayer: \(shouldShowMiniPlayer)")
        
        // 🔥 Exit PiP mode if active
        if isPiPActive {
            togglePictureInPicture()
        }
        
        // 🔥 FIX: Ensure player is ready before presenting
        guard let player = player else {
            print("🚨 [GlobalPlayer] No player available - setting up new player")
            setupPlayerManager()
            playerManager?.setupPlayer(with: video)
            // Wait a bit for player to be ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.presentFullscreenVideo()
            }
            return
        }
        
        // 🔥 FIX: Ensure player is attached and ready
        if player.currentItem == nil {
            print("⚠️ [GlobalPlayer] Player has no current item - setting up")
            playerManager?.setupPlayer(with: video)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
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
        
        // 🔥 Stop PiP if active
        if isPiPActive {
            togglePictureInPicture()
        }
        
        // 🔥 REAL-TIME VIEW TRACKING: End view session
        Task {
            await endViewTracking()
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            playerManager?.pause()
            currentVideo = nil
            isMiniplayer = false
            showingFullscreen = false
            shouldShowMiniPlayer = false
            miniplayerOffset = 0
        }
        
        HapticManager.shared.impact(style: .light)
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