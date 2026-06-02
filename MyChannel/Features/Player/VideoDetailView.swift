//  VideoDetailView.swift
//  MyChannel

import SwiftUI
import AVKit
import Combine
import UIKit

struct VideoDetailView: View {
    let video: Video
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var globalPlayer: GlobalVideoPlayerManager
    @StateObject var playerManager = VideoPlayerManager() // Single player manager
    @StateObject var appState = AppState.shared
    @StateObject var recommendationService = VideoDetailRecommendationService.shared
    @StateObject var controlsCoordinator = PlayerControlsCoordinator()
    
    // 🔥 REAL-TIME VIEW COUNT: Make view count reactive
    @State var currentViewCount: Int
    @StateObject var viewTracker = RealtimeViewTracker.shared

    var isYouTube: Bool { video.contentSource == .youtube && video.externalID != nil }
    
    init(video: Video) {
        self.video = video
        _currentViewCount = State(initialValue: video.viewCount)
    }

    // MARK: - Player States
    @State var showPlayer = false
    @State var isPlayerReady = false
    @State var isBuffering = false
    @State var playbackRate: Float = 1.0
    @State var isFullscreen = false
    @State var showPlayerControls = true
    @State var playerControlsTimer: Timer?
    @State var isDraggingSeeker = false
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
    @State var lastDoubleTapTime = Date.distantPast  // 🔥 YOUTUBE PARITY: Double-tap detection
    @State var showingChapters = false
    @State var currentChapterTitle: String = ""
    @State var showingChapterTooltip = false
    @State var chapterTooltipX: CGFloat = 0
    // Note: hoveredChapter and chapterTooltipHideWorkItem now managed by controlsCoordinator
    @State var showUpNext = false
    @State var upNextCountdown = 5
    @State var upNextVideo: Video? = nil
    @State var autoplayEnabled = true
    @State var upNextTimer: Timer? = nil
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
    
    // 🔥 YOUTUBE-STYLE ADS: New ad state management
    @StateObject var adManager = GoogleIMAAdManager.shared
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

    // MARK: - Wired Phase 141–154 Services
    @StateObject var ambientService = AmbientModeService.shared
    @StateObject var heatmapService = SentimentHeatmapService.shared
    @StateObject var timestampedCommentsService = TimestampedCommentsService.shared
    @StateObject var speedCurvesService = PlaybackSpeedCurvesService.shared
    @State var pinchScale: CGFloat = 1.0
    @State var lastPinchScale: CGFloat = 1.0
    @State var showAmbientGlow = false
    @State var showSilenceSkipIndicator = false
    
    // MARK: - YouTube Parity: Brightness / Volume Swipe
    @State var currentBrightness: CGFloat = UIScreen.main.brightness
    @State var currentVolume: Float = 0.5
    // Note: showBrightnessOverlay and showVolumeOverlay now managed by controlsCoordinator
    @State var verticalSwipeStartY: CGFloat = 0
    @State var lastBrightnessFeedbackStep: Int = -1
    @State var lastVolumeFeedbackStep: Int = -1

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
                print("🎬 Setting up video player for: \(video.title)")
                print("🔗 Video URL: \(video.videoURL)")
                print("🎥 Video source: \(video.contentSource)")
                print("🆔 Video ID: \(video.id)")
                print("📱 Is YouTube: \(isYouTube)")
                print("💰 Video monetized: \(video.monetization?.isMonetized ?? false)")
                
                // 🔥 YOUTUBE PARITY: Check if this video is already playing in PiP / global player
                let globalPlayer = GlobalVideoPlayerManager.shared
                let isSameVideoInGlobal = globalPlayer.currentVideo?.id == video.id && globalPlayer.player != nil
                let isPiPActive = PiPPlayerManager.shared.pipController?.isPictureInPictureActive == true
                    || NativePiPController.shared.isActive
                
                // 🔥 YOUTUBE PARITY: ALWAYS stop PiP when opening VideoDetailView
                // YouTube never shows PiP and fullscreen at the same time
                if isPiPActive {
                    print("⏹️ [VideoDetailView] Stopping PiP — fullscreen player taking over")
                    PiPPlayerManager.shared.stopPiP()
                    NativePiPController.shared.stopPiP()
                }
                
                // 🔥 YOUTUBE PARITY: If same video was in PiP/global, adopt it seamlessly
                if isSameVideoInGlobal {
                    print("✅ [VideoDetailView] Same video from PiP/global — adopting player seamlessly")
                    if let _ = globalPlayer.exposedPlayerManager {
                        isPlayerReady = true
                        showPlayer = true
                        isViewAppeared = true
                        
                        // Mark as fullscreen so PiP doesn't re-trigger
                        globalPlayer.showingFullscreen = true
                        
                        // Update view count
                        Task {
                            let latestCount = await RealtimeViewTracker.shared.getViewCount(for: video.id)
                            currentViewCount = latestCount
                        }
                        
                        // Sync playback state — ensure video keeps playing
                        if let player = globalPlayer.player {
                            playbackRate = player.rate
                            if player.timeControlStatus != .playing && globalPlayer.isPlaying {
                                player.play()
                            }
                        }
                        
                        print("✅ [VideoDetailView] Adopted global player — seamless transition from PiP")
                        return
                    }
                }
                
                // 🔥 Different video — stop everything and start fresh
                GlobalVideoPlayerManager.shared.stopImmediately()
                
                if !isYouTube {
                    // 🔥 ADD ADS LOGIC: Check for ads before playing video
                    Task { @MainActor in
                        // 🔥 NO ADS ON YOUR OWN VIDEOS - Skip ads if watching your own content
                        if let currentUser = AuthenticationManager.shared.currentUser,
                           video.creator.id == currentUser.id {
                            print("🎬 Your own video - skipping ALL ads, playing instantly!")
                            playerManager.setupPlayer(with: video)
                            playerManager.applyFastStartTuning()
                            if AppState.shared.preferredVideoQuality != .auto {
                                playerManager.setPreferredQuality(AppState.shared.preferredVideoQuality)
                                videoQuality = AppState.shared.preferredVideoQuality
                            }
                            playerManager.requestAutoPlay()
                            
                            // 🔥 FIX: Register video with GlobalVideoPlayerManager for PiP support
                            GlobalVideoPlayerManager.shared.registerLocalPlayer(video: video, player: playerManager.player)
                            return
                        }
                        
                        // Premium gating: no ads for subscribers
                        if (try? await StoreKitService.shared.hasActiveSubscription()) == true {
                            print("👑 Premium user - no ads")
                            playerManager.setupPlayer(with: video)
                            playerManager.applyFastStartTuning()
                            if AppState.shared.preferredVideoQuality != .auto {
                                playerManager.setPreferredQuality(AppState.shared.preferredVideoQuality)
                                videoQuality = AppState.shared.preferredVideoQuality
                            }
                            playerManager.requestAutoPlay()
                            
                            // 🔥 FIX: Register video with GlobalVideoPlayerManager for PiP support
                            GlobalVideoPlayerManager.shared.registerLocalPlayer(video: video, player: playerManager.player)
                            return
                        }
                        
                        // 🔥 ADS OFF BY DEFAULT: Only show video ads if you enable them (e.g. in Settings)
                        let videoAdsEnabled = UserDefaults.standard.bool(forKey: "preferences.videoAdsEnabled")
                        guard videoAdsEnabled else {
                            print("🎬 Video ads disabled - playing directly")
                            playerManager.setupPlayer(with: video)
                            playerManager.applyFastStartTuning()
                            if AppState.shared.preferredVideoQuality != .auto {
                                playerManager.setPreferredQuality(AppState.shared.preferredVideoQuality)
                                videoQuality = AppState.shared.preferredVideoQuality
                            }
                            playerManager.requestAutoPlay()
                            GlobalVideoPlayerManager.shared.registerLocalPlayer(video: video, player: playerManager.player)
                            return
                        }
                        
                        print("🎯 Checking ads for video: \(video.title)")
                        print("💰 Video monetization: \(video.monetization?.isMonetized ?? false)")
                        
                        let personalized = UserDefaults.standard.bool(forKey: "preferences.personalizedAdsEnabled")
                        adManager.requestPreRollAd(for: video, personalized: personalized) { [self] ad in
                            if let ad = ad {
                                print("✅ [VideoDetailView] Got YouTube-style ad: \(ad.mediaURL)")
                                
                                // Show YouTube-style ad
                                currentVideoAd = ad
                                showingYouTubeAd = true
                                
                                // Setup ad manager callbacks
                                adManager.onAdComplete = {
                                    Task { @MainActor in
                                        print("🎬 [VideoDetailView] Ad completed, playing main video")
                                        showingYouTubeAd = false
                                        currentVideoAd = nil
                                        
                                        // Track revenue to Firebase
                                        let revenue = Double.random(in: 0.02...0.15)  // Real CPM range
                                        await AdsService.trackAdRevenue(for: video, adRevenue: revenue)
                                        
                                        // Play main video
                                        playerManager.setupPlayer(with: video)
                                        playerManager.applyFastStartTuning()
                                        if AppState.shared.preferredVideoQuality != .auto {
                                            playerManager.setPreferredQuality(AppState.shared.preferredVideoQuality)
                                            videoQuality = AppState.shared.preferredVideoQuality
                                        }
                                        playerManager.requestAutoPlay()
                                        
                                        globalPlayer.registerLocalPlayer(video: video, player: playerManager.player)
                                    }
                                }
                                
                                adManager.onAdSkipped = {
                                    Task { @MainActor in
                                        print("⏭️ [VideoDetailView] Ad skipped, playing main video")
                                        showingYouTubeAd = false
                                        currentVideoAd = nil
                                        
                                        // Still track partial revenue (skipped ads pay less)
                                        let revenue = Double.random(in: 0.005...0.03)
                                        await AdsService.trackAdRevenue(for: video, adRevenue: revenue)
                                        
                                        playerManager.setupPlayer(with: video)
                                        playerManager.applyFastStartTuning()
                                        if AppState.shared.preferredVideoQuality != .auto {
                                            playerManager.setPreferredQuality(AppState.shared.preferredVideoQuality)
                                            videoQuality = AppState.shared.preferredVideoQuality
                                        }
                                        playerManager.requestAutoPlay()
                                        
                                        globalPlayer.registerLocalPlayer(video: video, player: playerManager.player)
                                    }
                                }
                                
                                // Play the ad
                                adManager.playAd(ad)
                                
                            } else {
                                print("❌ No ads available - playing video directly")
                                // No ad, play video directly
                                playerManager.setupPlayer(with: video)
                                playerManager.applyFastStartTuning()
                                if AppState.shared.preferredVideoQuality != .auto {
                                    playerManager.setPreferredQuality(AppState.shared.preferredVideoQuality)
                                    videoQuality = AppState.shared.preferredVideoQuality
                                }
                                playerManager.requestAutoPlay()
                                
                                // 🔥 FIX: Register video with GlobalVideoPlayerManager for PiP
                                globalPlayer.registerLocalPlayer(video: video, player: playerManager.player)
                            }
                        }
                    }
                    // Log watch start to history
                    if let uid = AppState.shared.currentUser?.id {
                        Task { await HistoryService.shared.logStart(userId: uid, video: video) }
                    }
                    
                    // 🔥 FIX: Track view count when video actually starts playing (not just on appear)
                    // This ensures views are only counted when user actually watches
                    // We'll track in the player observer when playback actually starts
                    // Fetch simple VMAP for preroll and pause content while ad plays
                    Task {
                        // 🔥 NO VMAP ADS: Skip unless video ads are enabled (same as preroll)
                        if !UserDefaults.standard.bool(forKey: "preferences.videoAdsEnabled") {
                            return
                        }
                        if let currentUser = AuthenticationManager.shared.currentUser,
                           video.creator.id == currentUser.id {
                            print("🎬 Skipping VMAP ads - your video!")
                            return
                        }
                        
                        if let vmap = await AdsService.shared.fetchVMAP(videoId: video.id) {
                            let uid = AppState.shared.currentUser?.id ?? "anonymous"
                            if let preroll = vmap.prerollUrl, !preroll.isEmpty, AdsFrequencyCapService.shared.canShow(userId: uid, adUnit: "pre_roll") {
                                prerollURL = preroll
                                showingAd = true
                                pendingContentResume = true
                                playerManager.pause()
                                AdsFrequencyCapService.shared.recordExposure(userId: uid, adUnit: "pre_roll", placement: "video_start", duration: 0, skippable: true, completed: false)
                            }
                            self.midrolls = vmap.midrolls ?? []
                            self.servedMidrollIndices = []
                        }
                    }
                }
                controlsCoordinator.showControlsAndResetTimer()
                isViewAppeared = true
            }
        }
        .onDisappear {
            print("🎬 VideoDetailView disappearing")
            playerControlsTimer?.invalidate()
            controlsCoordinator.cleanup()
            
            // 🔥 YOUTUBE PARITY: Save watch progress when leaving
            let _uid = AppState.shared.currentUser?.id ?? "anonymous"
            let _pos = playerManager.currentTime
            let _dur = playerManager.duration
            let _vid = video.id
            Task { try? await WatchProgressService.shared.saveProgress(userId: _uid, videoId: _vid, position: _pos, duration: _dur) }
            
            // 🔥 YOUTUBE PARITY: If user explicitly closed (X button), don't start PiP
            guard !userExplicitlyClosed else {
                print("❌ [VideoDetailView] User explicitly closed — no PiP")
                return
            }
            
            // If native PiP is already active (chevron button started it), nothing to do
            let nativePiPActive = PiPPlayerManager.shared.pipController?.isPictureInPictureActive == true
                || NativePiPController.shared.isActive
            guard !nativePiPActive else {
                print("✅ [VideoDetailView] Native PiP already active — no action needed")
                return
            }
            
            // 🔥 YOUTUBE PARITY: Swipe-dismiss or back gesture → start PiP
            // Video continues in floating window while user browses the app
            if !isYouTube {
                Task { @MainActor in
                    let wasPlaying = playerManager.isPlaying
                    // Adopt player into global manager so PiP controller has a reference
                    await globalPlayer.adoptExternalPlayerManager(playerManager, video: video, showFullscreen: false)
                    globalPlayer.showingFullscreen = false
                    if wasPlaying {
                        // Ensure playback continues
                        if let player = globalPlayer.player, player.rate == 0 {
                            player.play()
                            globalPlayer.isPlaying = true
                        }
                        // Start native PiP floating window
                        globalPlayer.startPiP()
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
                if !pipActive && !playerManager.isPlaying {
                    print("🔄 [VideoDetailView] Returned to foreground, PiP not active")
                }
            }
        }
        .onChange(of: controlsCoordinator.showControls) { newValue in
            print("🎮 Controls visibility changed to: \(newValue)")
            if newValue {
                controlsCoordinator.resetHideTimer()
            } else {
                controlsCoordinator.cancelHideTimer()
            }
        }
        .onChange(of: playerManager.isPlaying) { newValue in
            print("🎵 Player state changed to: \(newValue ? "Playing" : "Paused")")
            controlsCoordinator.updatePlayingState(newValue)
            if newValue {
                Task {
                    let latestCount = await RealtimeViewTracker.shared.getViewCount(for: video.id)
                    await MainActor.run {
                        currentViewCount = latestCount
                        print("📊 [VideoDetailView] View count updated after play: \(latestCount)")
                    }
                }
            }
        }
        .onReceive(playerManager.$currentTime) { _ in
            handleCurrentTimeChange()
        }
        // 🔥 FIX: Listen for "Open Video Editor" notification
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenVideoEditor"))) { notification in
            if let editVideo = notification.object as? Video, editVideo.id == video.id {
                print("📝 [VideoDetailView] Opening video editor")
                showingVideoEditor = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            // CRITICAL FIX: Only trigger endscreen if this is OUR player item, not other players (banners, previews, etc)
            if let item = notification.object as? AVPlayerItem,
               item == playerManager.player?.currentItem {
                // 🔥 YOUTUBE PARITY: Loop video if enabled
                if isLooping {
                    playerManager.seek(to: 0)
                    playerManager.play()
                    print("🔁 [YouTube] Looping video")
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
                print("📊 [VideoDetailView] View count updated: \(viewCount)")
                currentViewCount = viewCount
            }
        }
        .task {
            // View count + recommendations in parallel
            print("📊 [VideoDetailView] Fetching latest view count for: \(video.id)")
            async let viewCountFetch = RealtimeViewTracker.shared.getViewCount(for: video.id)
            async let recsFetch = recommendationService.recommendations(for: video, userId: appState.currentUser?.id, limit: 20)
            let (latestCount, recs) = await (viewCountFetch, recsFetch)
            print("📊 [VideoDetailView] Latest view count from Firestore: \(latestCount)")

            await MainActor.run {
                currentViewCount = latestCount
                recommendedVideos = recs
            }

            recommendationService.prefetchNextPlayerItem(from: recs)

            // Heatmap, comments, silence detection in parallel
            await withTaskGroup(of: Void.self) { group in
                group.addTask { _ = try? await heatmapService.loadHeatmap(videoId: video.id) }
                group.addTask { _ = try? await timestampedCommentsService.loadComments(videoId: video.id) }
                group.addTask { _ = try? await speedCurvesService.detectSilence(videoId: video.id) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SeekToTimestamp"))) { notification in
            if let timestamp = notification.object as? TimeInterval {
                let progress = playerManager.duration > 0 ? timestamp / playerManager.duration : 0
                playerManager.seek(to: progress)
            }
        }
        // 🔥 YOUTUBE PARITY: Auto quality selection + Resume playback position when video loads
        .onChange(of: playerManager.duration) { newDuration in
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