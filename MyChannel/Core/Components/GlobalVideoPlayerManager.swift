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
    @Published private(set) var authorizedPlaybackSession: VideoPlaybackSession?
    private(set) var authorizedPlayableVideo: Video?
    private var authorizationRenewalTask: Task<Void, Never>?
    private var playbackAuthorizationTask: Task<Void, Never>?
    
    // Expose the retained manager and authorized descriptor so detail views can
    // expand an existing mini-player without reconstructing playback from metadata.
    var exposedPlayerManager: VideoPlayerManager? {
        playerManager
    }
    private var cancellables = Set<AnyCancellable>()
    private var lifecycleCancellables = Set<AnyCancellable>()
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

        // Start from an empty playback state.
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
    }
    
    /// Canonical playback session UUID — correlates view analytics across player surfaces.
    var playbackSessionID: String? { viewTracking.playbackSessionID }
    
    deinit {
        cleanupSync()
    }

    private nonisolated func cleanupSync() {}
    
    private func cleanup() {
        guard !isCleanedUp else { return }
        isCleanedUp = true
        pipCoordinator.stopAll()
        
        UIApplication.shared.endReceivingRemoteControlEvents()
        
        kvoObservers.invalidate()
        pipCoordinator.teardownObserver()
        
        // Clear all cancellables to break retain cycles
        cancellables.removeAll()
        lifecycleCancellables.removeAll()
        
        // Clean up player manager and authorization tasks.
        playbackAuthorizationTask?.cancel()
        playbackAuthorizationTask = nil
        clearAuthorization()
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

    // Ensure the retained authorized player exists for mini-player resilience.
    // Raw metadata URLs are never eligible for retry.
    func ensurePlayerAttached() {
        guard !isCleanedUp,
              let session = authorizedPlaybackSession,
              let playableVideo = authorizedPlayableVideo,
              session.videoId == currentVideo?.id,
              session.videoId == playableVideo.id,
              session.expiresAt.map({ $0 > Date() }) ?? true else {
            failClosedPlayback()
            return
        }

        if playerManager == nil {
            setupPlayerManager()
        }

        if playerManager?.player == nil {
            playerManager?.setupPlayer(with: playableVideo)
            playerManager?.requestAutoPlay()
        } else if let item = playerManager?.player?.currentItem,
                  item.status == .failed {
            playerManager?.setupPlayer(with: playableVideo)
            playerManager?.requestAutoPlay()
        }
    }
    
    private func setupObservers() {
        guard let playerManager = playerManager, !isCleanedUp else { return }
        
        // Replace only subscriptions bound to the current player manager.
        // Lifecycle observers (including queue auto-advance) must survive adoption.
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
            .store(in: &lifecycleCancellables)
    }

    // Stop current playback immediately (used when switching videos fast).
    func stopImmediately() {
        playbackAuthorizationTask?.cancel()
        playbackAuthorizationTask = nil
        clearAuthorization()
        pipCoordinator.stopAll()
        assetPreloader.cancel()

        playerManager?.pause()
        playerManager?.player?.replaceCurrentItem(with: nil)
        isPlaying = false
        currentProgress = 0
        currentTime = 0
        duration = 0
        showingFullscreen = false
        currentVideo = nil
        hasActivePlaybackSession = false
    }

    // MARK: - Authorized Player Handoff
    func registerLocalPlayer(
        video: Video,
        playableVideo: Video,
        session: VideoPlaybackSession,
        manager: VideoPlayerManager
    ) {
        guard !isCleanedUp,
              isValidAuthorization(session, playableVideo: playableVideo, metadataVideo: video) else {
            failClosedPlayback()
            return
        }

        playerManager = manager
        setupObservers()
        currentVideo = video
        showingFullscreen = true
        retainAuthorization(session, playableVideo: playableVideo)

        if session.capabilities.supportsPictureInPicture, let player = manager.player {
            pipCoordinator.setup(with: player)
        }
        Task { [weak self] in
            await self?.viewTracking.start(for: video)
        }
    }

    /// Lightweight PiP handoff for callers that already have an active, authorized
    /// player but don't hold a reference to the original `VideoPlaybackSession`.
    /// This arms PiP without re-validating a session — use only from contexts where
    /// playback is already authorized and running.
    func registerLocalPlayer(video: Video, player: AVPlayer?) {
        guard !isCleanedUp else { return }
        currentVideo = video
        if let player {
            pipCoordinator.setup(with: player)
        }
    }

    /// Seamlessly adopts an existing player. MyChannel-hosted playback must pass
    /// the server session and playable manifest copy; sessionless players are not
    /// eligible for retry, queue continuation, or native PiP.
    func adoptExternalPlayerManager(
        _ externalManager: VideoPlayerManager,
        video: Video,
        showFullscreen: Bool,
        session: VideoPlaybackSession? = nil,
        playableVideo: Video? = nil
    ) async {
        guard !isCleanedUp else { return }

        playerManager = externalManager
        setupObservers()
        currentVideo = video
        showingFullscreen = showFullscreen
        isPlaying = externalManager.player?.timeControlStatus == .playing || externalManager.isPlaying

        if let session, let playableVideo,
           isValidAuthorization(session, playableVideo: playableVideo, metadataVideo: video) {
            retainAuthorization(session, playableVideo: playableVideo)
            if session.capabilities.supportsPictureInPicture, let player = externalManager.player {
                pipCoordinator.setup(with: player)
            }
        } else {
            clearAuthorization()
            hasActivePlaybackSession = false
        }

        await viewTracking.start(for: video)
    }

    // MARK: - Video Management
    /// Authorizes every MyChannel video before replacing the active player item.
    /// Existing synchronous callers remain source-compatible while authorization
    /// runs on the main-actor task.
    func playVideo(_ video: Video, showFullscreen: Bool = true, queue: [Video] = []) {
        guard !isCleanedUp else { return }
        playbackAuthorizationTask?.cancel()
        playbackAuthorizationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let session = try await VideoPlaybackSessionService.shared.authorize(videoId: video.id)
                guard !Task.isCancelled else { return }
                var playableVideo = video
                playableVideo.videoURL = session.manifestURL.absoluteString
                self.playAuthorizedVideo(
                    video,
                    playableVideo: playableVideo,
                    session: session,
                    showFullscreen: showFullscreen,
                    queue: queue
                )
            } catch is CancellationError {
                return
            } catch {
                self.failClosedPlayback()
            }
        }
    }

    private func playAuthorizedVideo(
        _ video: Video,
        playableVideo: Video,
        session: VideoPlaybackSession,
        showFullscreen: Bool,
        queue: [Video]
    ) {
        guard isValidAuthorization(session, playableVideo: playableVideo, metadataVideo: video) else {
            failClosedPlayback()
            return
        }

        clearAuthorization()
        pipCoordinator.stopAll()
        assetPreloader.cancel()
        playerManager?.pause()
        playerManager?.player?.replaceCurrentItem(with: nil)
        if playerManager == nil { setupPlayerManager() }

        currentVideo = video
        if !queue.isEmpty {
            videoQueue = queue
            queueIndex = queue.firstIndex(where: { $0.id == video.id }) ?? 0
        } else {
            videoQueue = [video]
            queueIndex = 0
        }
        syncPlaybackQueueFromPublished()

        playerManager?.setupPlayer(with: playableVideo)
        playerManager?.applyFastStartTuning()
        playerManager?.requestAutoPlay()
        retainAuthorization(session, playableVideo: playableVideo)

        if session.capabilities.supportsPictureInPicture, let player {
            pipCoordinator.setup(with: player)
            if !showFullscreen {
                pipCoordinator.scheduleAutoStartIfNotFullscreen()
            }
        }

        showingFullscreen = showFullscreen
        hasActivePlaybackSession = true
        Task { [weak self] in
            await self?.viewTracking.start(for: video)
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
    
    // Navigate to the next queue item through fresh authorization.
    func playNextVideo() {
        viewTracking.flushUniversityWatchBeforeSwitch()
        if skipAdsOnQueueNavigation {
            playerManager?.cancelCurrentAdBreak()
        }
        guard let nextVideo = playbackQueue.upNext else { return }
        playVideo(nextVideo, showFullscreen: showingFullscreen, queue: playbackQueue.videos)
    }

    // Legacy raw-URL preloading is intentionally disabled. Callers may keep
    // invoking this while they migrate to video-ID authorization; no media is
    // fetched until `playVideo` obtains a server session.
    func preloadVideo(url: String) {
        _ = url
    }

    private func syncPlaybackQueueFromPublished() {
        playbackQueue.videos = videoQueue
        playbackQueue.index = queueIndex
    }

    private func preloadNextQueueItems() {
        assetPreloader.cancel()
    }

    private func preloadNextVideo() {
        preloadNextQueueItems()
    }

    // Navigate to the previous queue item through fresh authorization.
    func playPreviousVideo() {
        viewTracking.flushUniversityWatchBeforeSwitch()
        if skipAdsOnQueueNavigation {
            playerManager?.cancelCurrentAdBreak()
        }
        guard playbackQueue.hasPrevious else { return }
        let previousIndex = playbackQueue.index - 1
        guard playbackQueue.videos.indices.contains(previousIndex) else { return }
        let previousVideo = playbackQueue.videos[previousIndex]
        playVideo(previousVideo, showFullscreen: showingFullscreen, queue: playbackQueue.videos)
    }

    // MARK: - Authorization Lifetime
    private func isValidAuthorization(
        _ session: VideoPlaybackSession,
        playableVideo: Video,
        metadataVideo: Video
    ) -> Bool {
        guard session.videoId == metadataVideo.id,
              playableVideo.id == metadataVideo.id,
              playableVideo.videoURL == session.manifestURL.absoluteString,
              SafePlaybackURL.manifest(playableVideo.videoURL) != nil else { return false }
        return session.expiresAt.map { $0 > Date() } ?? true
    }

    private func retainAuthorization(
        _ session: VideoPlaybackSession,
        playableVideo: Video
    ) {
        authorizedPlaybackSession = session
        authorizedPlayableVideo = playableVideo
        hasActivePlaybackSession = true
        scheduleAuthorizationRenewal(session)
    }

    private func scheduleAuthorizationRenewal(_ session: VideoPlaybackSession) {
        authorizationRenewalTask?.cancel()
        guard let expiresAt = session.expiresAt else { return }
        let delay = max(1, expiresAt.timeIntervalSinceNow - 60)
        authorizationRenewalTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard let self, !Task.isCancelled,
                      self.currentVideo?.id == session.videoId else { return }
                let renewed = try await VideoPlaybackSessionService.shared.authorize(
                    videoId: session.videoId
                )
                guard !Task.isCancelled,
                      let metadataVideo = self.currentVideo else { return }
                var playableVideo = metadataVideo
                playableVideo.videoURL = renewed.manifestURL.absoluteString
                guard self.isValidAuthorization(
                    renewed,
                    playableVideo: playableVideo,
                    metadataVideo: metadataVideo
                ) else {
                    self.failClosedPlayback()
                    return
                }

                let previousURL = self.authorizedPlaybackSession?.manifestURL
                let resumeTime = self.player?.currentTime().seconds ?? 0
                let wasPlaying = self.player?.timeControlStatus == .playing
                self.retainAuthorization(renewed, playableVideo: playableVideo)
                if renewed.manifestURL != previousURL {
                    self.playerManager?.setupPlayer(with: playableVideo)
                    if resumeTime.isFinite, resumeTime > 0 {
                        await self.playerManager?.player?.seek(
                            to: CMTime(seconds: resumeTime, preferredTimescale: 600)
                        )
                    }
                    if wasPlaying { self.playerManager?.requestAutoPlay() }
                }
            } catch is CancellationError {
                return
            } catch {
                self?.failClosedPlayback()
            }
        }
    }

    private func clearAuthorization() {
        authorizationRenewalTask?.cancel()
        authorizationRenewalTask = nil
        authorizedPlaybackSession = nil
        authorizedPlayableVideo = nil
    }

    private func failClosedPlayback() {
        clearAuthorization()
        pipCoordinator.stopAll()
        playerManager?.pause()
        playerManager?.player?.replaceCurrentItem(with: nil)
        currentVideo = nil
        isPlaying = false
        isPlayerReady = false
        hasActivePlaybackSession = false
    }

    // Native PiP is a server-granted playback capability.
    func startPiP() {
        guard authorizedPlaybackSession?.capabilities.supportsPictureInPicture == true else {
            return
        }
        pipCoordinator.startPiP()
    }
    
    func expandPlayer() {
        guard let video = currentVideo, !isCleanedUp else { return }
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
        
        if let player = player, player.rate == 0, isPlaying {
            player.play()
        }
        HapticManager.shared.impact(style: .medium)
    }
    
    func closePlayer() {
        guard !isCleanedUp else { return }
        pipCoordinator.stopAll()
        Task { [weak self] in
            await self?.viewTracking.end()
        }
        NowPlayingService.shared.clear()
        playbackAuthorizationTask?.cancel()
        playbackAuthorizationTask = nil
        clearAuthorization()
        
        withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
            playerManager?.pause()
            playerManager?.player?.replaceCurrentItem(with: nil)  // 🔥 FIX: Clear player item
            currentVideo = nil
            showingFullscreen = false
            isPlayerReady = false  // 🔥 FIX: Mark player as not ready
            isPlaying = false
            hasActivePlaybackSession = false
        }
        assetPreloader.cancel()
        HapticManager.shared.impact(style: .light)
    }

    func nuclearReset() {
        // Stop any active tracking
        Task { [weak self] in
            await self?.viewTracking.end()
        }

        kvoObservers.invalidate()
        pipCoordinator.teardownObserver()
        NowPlayingService.shared.clear()
        pipCoordinator.stopAll()
        playbackAuthorizationTask?.cancel()
        playbackAuthorizationTask = nil
        clearAuthorization()
        
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
    
    init() {}

    func playVideo(_ video: Video, showFullscreen: Bool = true) {
        _ = (video, showFullscreen)
    }

    func startPiP() {}

    func expandPlayer() {}

    func closePlayer() {}

    func handleNavigationChange(isVideoDetailVisible: Bool) {
        _ = isVideoDetailVisible
    }

    func togglePlayPause() {}

    func seek(to progress: Double) {
        _ = progress
    }

    func seekForward() {}

    func seekBackward() {}

    func handleMiniplayerDrag(_ translation: CGSize) {
        _ = translation
    }

    func handleMiniplayerDragEnd(_ translation: CGSize) {
        _ = translation
    }

    func performCleanup() {}
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