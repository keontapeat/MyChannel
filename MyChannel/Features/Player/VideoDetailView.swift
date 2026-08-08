//  VideoDetailView.swift
//  MyChannel

import SwiftUI
import AVKit
import Combine
import UIKit

struct VideoDetailView: View {
    enum PlaybackAuthorizationState: Equatable {
        case checking
        case allowed
        case blocked(String)
    }

    let video: Video
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @EnvironmentObject var globalPlayer: GlobalVideoPlayerManager
    @StateObject var playerManager: VideoPlayerManager
    @StateObject var controlsCoordinator = PlayerControlsCoordinator() // view-owned
    @State var playbackAuthorization: PlaybackAuthorizationState = .checking
    @State var playbackSession: VideoPlaybackSession?
    @State var authorizedVideo: Video?
    @State var hasStartedContentPlayback = false
    @State var lastProgressSaveSecond = -1
    @State var isUsingGlobalPlayer = false
    @State var playbackRenewalTask: Task<Void, Never>?
    @State var pendingAuthorizationResumeTime: TimeInterval?
    // Shared singletons are observed, not owned — @ObservedObject is the correct
    // wrapper (@StateObject would tie their lifecycle to this view).
    @ObservedObject var appState = AppState.shared
    @ObservedObject var recommendationService = VideoDetailRecommendationService.shared
    
    // 🔥 REAL-TIME VIEW COUNT: Make view count reactive
    @State var currentViewCount: Int
    @ObservedObject var viewTracker = RealtimeViewTracker.shared

    var isYouTube: Bool { video.contentSource == .youtube && video.externalID != nil }
    
    init(video: Video) {
        self.video = video
        let globalPlayer = GlobalVideoPlayerManager.shared
        let initialManager: VideoPlayerManager
        if globalPlayer.currentVideo?.id == video.id,
           globalPlayer.authorizedPlaybackSession?.videoId == video.id,
           let retainedManager = globalPlayer.exposedPlayerManager {
            initialManager = retainedManager
        } else {
            initialManager = VideoPlayerManager()
        }
        _playerManager = StateObject(wrappedValue: initialManager)
        _currentViewCount = State(initialValue: video.viewCount)
    }

    // MARK: - Player States
    @State var playbackRate: Float = 1.0
    @State var videoQuality: VideoQuality = .auto
    

    // MARK: - Interaction States
    @State var isLiked = false
    @State var isDisliked = false
    @State var isSubscribed = false
    @State var isWatchLater = false
    @State var showingCommentComposer = false
    @State var showingMoreOptions = false
    @State var showingQualitySelector = false
    @State var showingPlaybackSpeedSelector = false
    @State var showingShareSheet = false
    @State var showingPlayerSettings = false  // 🔥 YOUTUBE PARITY: Settings gear sheet

    // MARK: - UI States
    @State var expandedDescription = false
    @State var isViewAppeared = false
    // Note: showVideoControls and controlsHideTimer now managed by controlsCoordinator
    @State var showingFullscreenOverlay = false
    @State var showingVideoEditor = false  // 🔥 FIX: Add video editor sheet
    @State var showSeekRippleForward = false
    @State var showSeekRippleBackward = false
    @State var showingChapters = false
    @State var currentChapterTitle: String = ""
    @State var showingChapterTooltip = false
    @State var chapterTooltipX: CGFloat = 0
    // Note: hoveredChapter and chapterTooltipHideWorkItem now managed by controlsCoordinator
    @State var showUpNext = false
    @State var upNextCountdown = 5
    @State var upNextVideo: Video? = nil
    @State var autoplayEnabled = true
    @State var upNextCountdownTask: Task<Void, Never>? = nil
    @State var showingUpNextList = false
    @State var videoToPresent: Video? = nil
    @State var showingSubtitlePicker = false
    @State var isScrubbing = false
    @State var scrubPreviewImage: UIImage? = nil
    @State var scrubFraction: Double = 0
    @State var showDebugHUD = false
    @State var showingAd = false
    @State var pendingContentResume = false
    @State var prerollURL: String? = nil
    @State var midrolls: [VMAPResponse.Midroll] = []
    @State var servedMidrollIndices: Set<Int> = []
    
    // 🔥 YOUTUBE-STYLE ADS: New ad state management (shared singleton — observed)
    @ObservedObject var adManager = GoogleIMAAdManager.shared
    @State var currentVideoAd: VideoAd?
    @State var showingYouTubeAd = false
    @State var adSkipped = false
    
    // MARK: - Enhanced YouTube Features
    @State var showingTranscript = false
    @State var showingVideoInfo = false
    @State var showingRecommendations = false
    @State var isTheaterMode = false
    @State var showingEndScreens = false
    @State var showingVideoCards = false
    @State var currentVideoCard: VideoCard? = nil
    @State var showingPlaylist = false
    @State var currentPlaylistIndex = 0
    @State var showingMiniPlayer = false
    @State var userExplicitlyClosed = false  // 🔥 YOUTUBE PARITY: Track explicit close vs swipe dismiss
    @State var watchProgress: Double = 0.0
    @State var hasWatchedThreshold = false
    // 🔥 PERF: Track which playback quartiles (1–4) have already been reported so
    // analytics fires once per milestone instead of every time-observer tick.
    @State var trackedQuartiles: Set<Int> = []
    // 🔥 PERF: Chapters sorted by start time, computed once on appear instead of
    // re-sorting the array on every player time-observer tick.
    @State var sortedChapters: [Video.Chapter] = []
    @State var showingCinemaMode = false
    @State var showingCreatorProfile = false
    @State var selectedCreatorProfile: User? = nil
    @State var selectedHashtag: String? = nil
    @State var showingQueueSidebar = false  // 🔥 YOUTUBE PARITY: Queue sidebar
    @State var recommendedVideos: [Video] = []  // Service-backed recommendations
    
    // 🔥 BEAST MODE: AI Dubbing
    @State var showingAudioTrackSelector = false
    @State var currentAudioTrack = "English (Original)"
    @State var isDubSynthesizing = false
    
    // MARK: - YouTube Parity: Long-Press 2x Speed
    @State var isLongPressSpeedUp = false  // 🔥 YOUTUBE PARITY: Hold-to-2x active
    @State var savedPlaybackRate: Float = 1.0  // 🔥 Rate before long-press
    @State var showSpeedUpIndicator = false
    
    // MARK: - YouTube Parity: Horizontal Swipe-to-Seek
    @State var isHorizontalSeeking = false
    @State var seekStartTime: TimeInterval = 0
    @State var seekDeltaSeconds: TimeInterval = 0
    // Note: showSeekOverlay now managed by controlsCoordinator
    
    // MARK: - YouTube Parity: Loop Toggle
    @State var isLooping = false

    // MARK: - Wired Phase 141–154 Services (shared singletons — observed)
    @ObservedObject var ambientService = AmbientModeService.shared
    @ObservedObject var heatmapService = SentimentHeatmapService.shared
    @ObservedObject var timestampedCommentsService = TimestampedCommentsService.shared
    @ObservedObject var speedCurvesService = PlaybackSpeedCurvesService.shared
    @State var pinchScale: CGFloat = 1.0
    @State var lastPinchScale: CGFloat = 1.0
    @State var showAmbientGlow = false
    @State var showSilenceSkipIndicator = false

    // MARK: - Video Polls / Quizzes
    @ObservedObject var pollService = VideoPollsQuizzesService.shared
    @State var displayedPoll: VideoPoll? = nil

    // MARK: - Shoppable Video
    @ObservedObject var shoppableService = ShoppableVideoService.shared

    // MARK: - Info Cards (YouTube-style interactive overlay)
    @StateObject var infoCardManager = InfoCardPlaybackManager()

    // MARK: - Membership Gating
    @State var membershipGateActive = false
    @State var checkingMembership = false
    @State var showingMembershipSheet = false

    /// Cancels in-flight authorize / ad-timeout work when the user leaves.
    @State var authorizationTask: Task<Void, Never>?
    @State var adLoadTimeoutTask: Task<Void, Never>?
    /// Bumps on each authorize attempt so late completions are ignored.
    @State var authorizationGeneration: UInt64 = 0
    
    // MARK: - YouTube Parity: Brightness / Volume Swipe
    @State var currentBrightness: CGFloat = UIScreen.main.brightness
    @State var currentVolume: Float = 0.5
    // Note: showBrightnessOverlay and showVolumeOverlay now managed by controlsCoordinator
    @State var verticalSwipeStartY: CGFloat = 0
    @State var lastBrightnessFeedbackStep: Int = -1
    @State var lastVolumeFeedbackStep: Int = -1

    // MARK: - YouTube Parity: Fluid Slide-to-Fullscreen Gesture
    /// Live drag translation while the user is pulling the player toward fullscreen (negative = up)
    @State var playerExpandOffset: CGFloat = 0
    /// True while the user's finger is actively driving the expand gesture
    @State var isExpandingPlayer: Bool = false

    var body: some View {
        tertiaryOverlays
            .sheet(isPresented: $showingTranscript) {
            VideoTranscriptSheet(video: video)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingVideoInfo) {
            VideoInfoSheet(video: video)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingCreatorProfile) {
            CreatorProfileSheet(creator: selectedCreatorProfile ?? video.creator)
                .presentationDetents([.large])
                .background(
                    UIKitSheetConfigurator(
                        configuration: UIKitSheetConfiguration(
                            detents: [.large()],
                            largestUndimmedDetentIdentifier: .large,
                            prefersGrabberVisible: true,
                            prefersScrollingExpandsWhenScrolledToEdge: false,
                            preferredCornerRadius: 28
                        )
                    )
                )
        }
        .sheet(isPresented: Binding(get: { selectedHashtag != nil }, set: { if !$0 { selectedHashtag = nil } })) {
            if let hashtag = selectedHashtag {
                HashtagSearchSheet(hashtag: hashtag)
                    .presentationDetents([.large])
                    .background(
                        UIKitSheetConfigurator(
                            configuration: UIKitSheetConfiguration(
                                detents: [.large()],
                                largestUndimmedDetentIdentifier: .large,
                                prefersGrabberVisible: true,
                                prefersScrollingExpandsWhenScrolledToEdge: false,
                                preferredCornerRadius: 28
                            )
                        )
                    )
            }
        }
        .overlay(alignment: .topTrailing) {
            // Video Cards Overlay (YouTube-style)
            if showingVideoCards, let card = currentVideoCard {
                VideoCardOverlay(card: card) {
                    showingVideoCards = false
                    currentVideoCard = nil
                } onTap: {
                    // Handle card tap action
                    showingVideoCards = false
                    currentVideoCard = nil
                }
                .padding(.top, 80)
                .padding(.trailing, 20)
                .transition(.scale.combined(with: .opacity))
                .zIndex(200)
            }
        }
        .onAppear {
            if !isViewAppeared {
                // Arm native PiP registration so the leave-the-app mini player is
                // set up the moment the AVPlayer is created (avoids the nil-player race).
                playerManager.registersForGlobalPiP = true
                #if DEBUG
                print("🎬 [VideoDetailView] Preparing playback for video ID: \(video.id)")
                #endif
                
                // 🔥 YOUTUBE PARITY: Check if this video is already playing in PiP / global player
                // (`globalPlayer` is the injected @EnvironmentObject — same shared instance.)
                let isSameVideoInGlobal = globalPlayer.currentVideo?.id == video.id && globalPlayer.player != nil
                let isPiPActive = PiPPlayerManager.shared.pipController?.isPictureInPictureActive == true
                    || NativePiPController.shared.isActive
                
                // 🔥 YOUTUBE PARITY: ALWAYS stop PiP when opening VideoDetailView
                // YouTube never shows PiP and fullscreen at the same time
                if isPiPActive {
                    PiPPlayerManager.shared.stopPiP()
                    NativePiPController.shared.stopPiP()
                }
                
                // If the same authorized video is already global, reuse its
                // retained manager and server session without rebuilding from metadata.
                if isSameVideoInGlobal,
                   globalPlayer.exposedPlayerManager != nil,
                   let retainedSession = globalPlayer.authorizedPlaybackSession,
                   let retainedVideo = globalPlayer.authorizedPlayableVideo,
                   retainedSession.videoId == video.id,
                   retainedVideo.id == video.id {
                    isViewAppeared = true
                    isUsingGlobalPlayer = true
                    playbackSession = retainedSession
                    authorizedVideo = retainedVideo
                    playbackAuthorization = .allowed
                    hasStartedContentPlayback = true
                    globalPlayer.showingFullscreen = true

                    Task {
                        let latestCount = await RealtimeViewTracker.shared.getViewCount(for: video.id)
                        currentViewCount = latestCount
                    }

                    if let player = globalPlayer.player {
                        playbackRate = player.rate
                        if player.timeControlStatus != .playing && globalPlayer.isPlaying {
                            player.play()
                        }
                    }
                    return
                }
                
                // Different video — stop everything and start from a server-authorized manifest.
                GlobalVideoPlayerManager.shared.stopImmediately()

                if !isYouTube {
                    authorizationTask?.cancel()
                    authorizationTask = Task { await authorizeAndStartPlayback() }
                    if let uid = AppState.shared.currentUser?.id {
                        Task { await HistoryService.shared.logStart(userId: uid, video: video) }
                    }
                } else {
                    // YouTube embeds remain governed by YouTube's own authenticated
                    // player policy and never receive a raw MyChannel media URL.
                    playbackAuthorization = .allowed
                }
                controlsCoordinator.showControlsAndResetTimer()
                isViewAppeared = true
            }
        }
        .onDisappear {
            authorizationTask?.cancel()
            authorizationTask = nil
            adLoadTimeoutTask?.cancel()
            adLoadTimeoutTask = nil
            playbackRenewalTask?.cancel()
            playbackRenewalTask = nil
            #if DEBUG
            print("🎬 [VideoDetailView] Disappearing")
            #endif
            controlsCoordinator.cleanup()
            upNextCountdownTask?.cancel()
            upNextCountdownTask = nil
            
            // Persist remote progress only for authenticated users. Anonymous
            // progress remains local and never collides under a shared user key.
            if let userId = AppState.shared.currentUser?.id {
                let position = activePlaybackTime
                let duration = activePlaybackDuration
                Task {
                    try? await WatchProgressService.shared.saveProgress(
                        userId: userId,
                        videoId: video.id,
                        position: position,
                        duration: duration
                    )
                }
            }
            
            // 🔥 YOUTUBE PARITY: If user explicitly closed (X button), don't start PiP
            guard !userExplicitlyClosed else { return }
            
            // If native PiP is already active (chevron button started it), nothing to do
            let nativePiPActive = PiPPlayerManager.shared.pipController?.isPictureInPictureActive == true
                || NativePiPController.shared.isActive
            guard !nativePiPActive else { return }
            
            // Swipe-dismiss or back gesture keeps the already-authorized player
            // in the in-app mini player. The retained session owns renewal.
            if !isYouTube,
               let session = effectivePlaybackSession,
               let playableVideo = effectivePlayableVideo {
                Task { @MainActor in
                    let manager = activePlayerManager
                    let wasPlaying = manager.isPlaying
                    await globalPlayer.adoptExternalPlayerManager(
                        manager,
                        video: video,
                        showFullscreen: false,
                        session: session,
                        playableVideo: playableVideo
                    )
                    globalPlayer.showingFullscreen = false
                    if wasPlaying, let player = globalPlayer.player, player.rate == 0 {
                        player.play()
                        globalPlayer.isPlaying = true
                    }
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            // Don't pause on background — native PiP needs playback to continue
            // so the system floating window can appear automatically.
            if newPhase == .active {
                // Restore inline playback if PiP was stopped by returning to app
                let pipActive = PiPPlayerManager.shared.pipController?.isPictureInPictureActive ?? false
                if !pipActive && !activePlayerManager.isPlaying {
                    #if DEBUG
                    print("[VideoDetailView] Returned to foreground with playback paused")
                    #endif
                }
            }
        }
        .onChange(of: controlsCoordinator.showControls) { newValue in
            #if DEBUG
            print("🎮 Controls visibility changed to: \(newValue)")
            #endif
            if newValue {
                controlsCoordinator.resetHideTimer()
            } else {
                controlsCoordinator.cancelHideTimer()
            }
        }
        .onChange(of: playerManager.isPlaying) { newValue in
            guard !isUsingGlobalPlayer else { return }
            handlePlaybackStateChanged(newValue)
        }
        .onChange(of: globalPlayer.isPlaying) { newValue in
            guard isUsingGlobalPlayer, globalPlayer.currentVideo?.id == video.id else { return }
            handlePlaybackStateChanged(newValue)
        }
        .onReceive(playerManager.$currentTime) { _ in
            guard !isUsingGlobalPlayer else { return }
            handleCurrentTimeChange()
        }
        .onReceive(globalPlayer.$currentTime) { _ in
            guard isUsingGlobalPlayer, globalPlayer.currentVideo?.id == video.id else { return }
            handleCurrentTimeChange()
        }
        // 🔥 FIX: Listen for "Open Video Editor" notification
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenVideoEditor"))) { notification in
            if let editVideo = notification.object as? Video, editVideo.id == video.id {
                showingVideoEditor = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            if let item = notification.object as? AVPlayerItem,
               item == activePlayerManager.player?.currentItem {
                if isLooping {
                    activePlayerManager.seek(to: 0)
                    activePlayerManager.play()
                } else {
                    beginEndscreen()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowTranscript"))) { _ in
            showingTranscript = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowVideoInfo"))) { _ in
            showingVideoInfo = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("VideoViewCountUpdated"))) { notification in
            // 🔥 REAL-TIME: Update view count when it changes
            if let userInfo = notification.userInfo,
               let videoId = userInfo["videoId"] as? String,
               videoId == video.id,
               let viewCount = userInfo["viewCount"] as? Int {
                currentViewCount = viewCount
            }
        }
        .task {
            // 🔥 PERF: Sort chapters once up front — video is immutable for this view.
            if sortedChapters.isEmpty, let chapters = video.chapters, !chapters.isEmpty {
                sortedChapters = chapters.sorted { $0.start < $1.start }
            }
            // View count + recommendations in parallel
            #if DEBUG
            print("📊 [VideoDetailView] Fetching latest view count for: \(video.id)")
            #endif
            async let viewCountFetch = RealtimeViewTracker.shared.getViewCount(for: video.id)
            async let recsFetch = recommendationService.recommendations(for: video, userId: appState.currentUser?.id, limit: 20)
            let (latestCount, recs) = await (viewCountFetch, recsFetch)
            #if DEBUG
            print("📊 [VideoDetailView] Latest view count: \(latestCount)")
            #endif

            await MainActor.run {
                currentViewCount = latestCount
                recommendedVideos = recs
            }

            recommendationService.prefetchNextPlayerItem(from: recs)

            // Heatmap, comments, silence detection, polls in parallel
            await withTaskGroup(of: Void.self) { group in
                group.addTask { _ = try? await heatmapService.loadHeatmap(videoId: video.id) }
                group.addTask { _ = try? await timestampedCommentsService.loadComments(videoId: video.id) }
                group.addTask { _ = try? await speedCurvesService.detectSilence(videoId: video.id) }
                if AppConfig.Features.enableVideoPollsQuizzes {
                    group.addTask { _ = try? await pollService.loadPolls(videoId: video.id) }
                }
                if AppConfig.Features.enableShoppableVideo {
                    group.addTask { _ = try? await shoppableService.loadTags(videoId: video.id) }
                }
                group.addTask { await infoCardManager.loadCards(for: video.id) }
                // Apply volume normalization: adjust player gain to reach target LUFS
                if AppConfig.Features.enableVolumeNormalization {
                    group.addTask {
                        if let profile = try? await VolumeNormalizationService.shared.analyzeVolume(videoId: video.id) {
                            let gainDB = profile.targetLUFS - profile.integratedLUFS
                            let gainLinear = min(2.0, max(0.1, Float(pow(10.0, gainDB / 20.0))))
                            await MainActor.run { playerManager.setVolume(gainLinear) }
                        }
                    }
                }
                // Membership gate check — also run for signed-out users (gate stays on).
                if AppConfig.Features.enableMembershipPerks, video.isMembersOnly == true {
                    let creatorId = video.creatorId
                    let uid = AppState.shared.currentUser?.id
                    group.addTask {
                        if let uid {
                            await checkMembershipAccess(channelId: creatorId, userId: uid)
                        } else {
                            await MainActor.run {
                                membershipGateActive = true
                                activePlayerManager.pause()
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingMembershipSheet) {
            ChannelMembershipView(
                channelId: video.creatorId,
                channelName: video.creator.displayName,
                channelAvatarURL: video.creator.profileImageURL
            )
            .presentationDetents([.medium, .large])
        }
        .onChange(of: showingMembershipSheet) { isPresented in
            // Re-check membership after the sheet closes in case the user joined.
            guard !isPresented,
                  AppConfig.Features.enableMembershipPerks,
                  video.isMembersOnly == true,
                  let uid = AppState.shared.currentUser?.id else { return }
            Task {
                await checkMembershipAccess(channelId: video.creatorId, userId: uid)
                if !membershipGateActive {
                    authorizationTask?.cancel()
                    authorizationTask = Task { await authorizeAndStartPlayback() }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SeekToTimestamp"))) { notification in
            if let timestamp = notification.object as? TimeInterval {
                let duration = activePlayerManager.duration
                let progress = duration > 0 ? timestamp / duration : 0
                activePlayerManager.seek(to: progress)
            }
        }
        .onChange(of: playerManager.duration) { newDuration in
            guard !isUsingGlobalPlayer else { return }
            handleDurationChange(newDuration)
        }
        .onChange(of: globalPlayer.duration) { newDuration in
            guard isUsingGlobalPlayer, globalPlayer.currentVideo?.id == video.id else { return }
            handleDurationChange(newDuration)
        }
        // 🔥 YOUTUBE PARITY: Queue sidebar
        .overlay(alignment: .trailing) {
            if showingQueueSidebar {
                VideoQueueSidebar(
                    globalPlayer: globalPlayer,
                    isPresented: $showingQueueSidebar
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }
}
    
// MARK: - Preview

#Preview {
    NavigationView {
        VideoDetailView(video: Video.sampleVideos[0])
            .environmentObject(PreviewSafeGlobalVideoPlayerManager())
    }
}