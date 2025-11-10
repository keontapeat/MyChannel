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
    
    // 🔥 YOUTUBE PARITY: Setup Picture-in-Picture controller
    func setupPictureInPicture(for playerLayer: AVPlayerLayer) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("⚠️ [GlobalVideoPlayerManager] PiP not supported on this device")
            return
        }
        
        pipController = AVPictureInPictureController(playerLayer: playerLayer)
        pipController?.delegate = nil // Can add delegate for events if needed
        print("✅ [GlobalVideoPlayerManager] PiP controller configured")
    }
    
    // 🔥 YOUTUBE PARITY: Toggle Picture-in-Picture mode
    func togglePictureInPicture() {
        guard let pipController = pipController else {
            print("⚠️ [GlobalVideoPlayerManager] PiP controller not configured")
            return
        }
        
        if pipController.isPictureInPictureActive {
            pipController.stopPictureInPicture()
            isPiPActive = false
            print("📺 [GlobalVideoPlayerManager] Stopping PiP")
        } else {
            pipController.startPictureInPicture()
            isPiPActive = true
            print("📺 [GlobalVideoPlayerManager] Starting PiP")
        }
        HapticManager.shared.impact(style: .medium)
    }
    
    // 🔥 AUTO PiP: Start Picture-in-Picture when app goes to background
    func startPiPWhenBackgrounding() async {
        guard shouldShowMiniPlayer,
              currentVideo != nil,
              let player = player,
              player.rate > 0 else {
            return
        }
        
        // Check if PiP is already active
        if isPiPActive {
            return
        }
        
        // Try to get the player layer from the PiP container view
        // Note: PiP is handled by PlayerPiPContainerView which has its own controller
        // We just need to trigger it via the binding
        if !isPiPActive {
            // The PiP will be activated by the PlayerPiPContainerView when isPiPActive is set to true
            // But we need the player layer, so we'll rely on the VideoDetailView's PiP container
            print("📺 [GlobalVideoPlayerManager] PiP should be handled by PlayerPiPContainerView")
        }
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

    // Ensure player exists for current video (used by mini player resilience)
    func ensurePlayerAttached() {
        guard !isCleanedUp else { return }
        if playerManager == nil { setupPlayerManager() }
        if let cv = currentVideo, playerManager?.player == nil {
            playerManager?.setupPlayer(with: cv)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.playerManager?.play()
                self?.isPlaying = true
            }
        }
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

        print("🔄 [GlobalPlayer] Adopting external player manager for: \(video.title)")
        print("🔄 [GlobalPlayer] showFullscreen: \(showFullscreen)")

        // Point our manager to the external one and wire observers
        playerManager = externalManager
        setupObservers()

        currentVideo = video
        isPlaying = externalManager.isPlaying

        // 🔥 VIEW TRACKING: Always track views, even for own videos
        Task {
            await startViewTracking(for: video)
        }

        // 🔥 FIX: Set state immediately (not in animation) to prevent race conditions
        showingFullscreen = showFullscreen
        isMiniplayer = !showFullscreen
        shouldShowMiniPlayer = !showFullscreen
        miniplayerOffset = 0
        
        // Ensure player is playing if it was playing before
        if externalManager.isPlaying, let player = player, player.rate == 0 {
            player.play()
        }
        
        print("✅ [GlobalPlayer] Mini player state: shouldShow=\(shouldShowMiniPlayer), isMini=\(isMiniplayer), fullscreen=\(showingFullscreen)")
        
        // 🔥 SAFEGUARD: Multi-check to ensure mini player state persists
        if !showFullscreen {
            for delay in [0.1, 0.3, 0.5, 1.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self = self, !self.isCleanedUp, self.currentVideo != nil else { return }
                    // Aggressively restore mini player state if it gets lost
                    if !self.shouldShowMiniPlayer || !self.isMiniplayer {
                        print("⚠️ [GlobalPlayer] Mini player state LOST at \(delay)s - RESTORING")
                        self.shouldShowMiniPlayer = true
                        self.isMiniplayer = true
                        self.showingFullscreen = false
                    }
                    // Ensure player continues playing
                    if let player = self.player, player.rate == 0, self.isPlaying {
                        print("🔄 [GlobalPlayer] Player paused unexpectedly - resuming")
                        player.play()
                    }
                }
            }
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
        
        // Default behavior – show mini when not fullscreen
        showingFullscreen = showFullscreen
        isMiniplayer = !showFullscreen
        shouldShowMiniPlayer = !showFullscreen
        
        // 🔥 REAL-TIME VIEW TRACKING: Start tracking this view
        Task {
            await startViewTracking(for: video)
        }
        
        // 🔥 AUTO-PLAY: Videos auto-play when opened (like YouTube)
        // View counting happens in VideoPlayerManager.play() - tracks ONCE per video
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.playerManager?.play()  // Auto-play the video
            self.isPlaying = true
            print("▶️ [GlobalVideoPlayerManager] Auto-playing video")
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, !self.isCleanedUp else { return }
            self.playerManager?.play()
        }
        
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, !self.isCleanedUp else { return }
            self.playerManager?.play()
        }
        
        HapticManager.shared.impact(style: .medium)
        print("◀️ [GlobalVideoPlayerManager] Playing previous video: \(previousVideo.title)")
    }
    
    func minimizePlayer() {
        guard currentVideo != nil, !isCleanedUp else { return }
        
        print("🔄 [GlobalVideoPlayerManager] Minimizing to mini player (YouTube style)")
        
        // 🔥 FIX: Set state IMMEDIATELY without animation to prevent race conditions
        showingFullscreen = false
        isMiniplayer = true
        shouldShowMiniPlayer = true
        isTransitioning = true
        
        print("✅ [GlobalVideoPlayerManager] Mini player state SET - shouldShow: \(shouldShowMiniPlayer), isMini: \(isMiniplayer)")
        
        // End transition state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, !self.isCleanedUp else { return }
            self.isTransitioning = false
            
            // 🔥 VERIFY: Ensure state persists after transition
            if !self.shouldShowMiniPlayer || !self.isMiniplayer {
                print("⚠️ [GlobalVideoPlayerManager] Mini player state LOST after minimize - RESTORING")
                self.shouldShowMiniPlayer = true
                self.isMiniplayer = true
                self.showingFullscreen = false
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
        
        isTransitioning = true
        
        // Set state BEFORE presenting to prevent white screen
        showingFullscreen = true
        isMiniplayer = false
        shouldShowMiniPlayer = false
        
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