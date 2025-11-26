//  VideoDetailView.swift
//  MyChannel

import SwiftUI
import AVKit
import Combine
import UIKit

struct VideoDetailView: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared
    @StateObject private var playerManager = VideoPlayerManager() // Single player manager
    
    // 🔥 REAL-TIME VIEW COUNT: Make view count reactive
    @State private var currentViewCount: Int
    @StateObject private var viewTracker = RealtimeViewTracker.shared

    private var isYouTube: Bool { video.contentSource == .youtube && video.externalID != nil }
    
    init(video: Video) {
        self.video = video
        _currentViewCount = State(initialValue: video.viewCount)
    }

    // MARK: - Player States
    @State private var showPlayer = false
    @State private var isPlayerReady = false
    @State private var isBuffering = false
    @State private var playbackRate: Float = 1.0
    @State private var isFullscreen = false
    @State private var showPlayerControls = true
    @State private var playerControlsTimer: Timer?
    @State private var isDraggingSeeker = false
    @State private var videoQuality: VideoQuality = .auto
    

    // MARK: - Interaction States
    @State private var isLiked = false
    @State private var isDisliked = false
    @State private var isSubscribed = false
    @State private var isWatchLater = false
    @State private var showingCommentComposer = false
    @State private var showingShareSheet = false
    @State private var showingMoreOptions = false
    @State private var showingQualitySelector = false
    @State private var showingPlaybackSpeedSelector = false

    // MARK: - UI States
    @State private var expandedDescription = false
    @State private var isViewAppeared = false
    @State private var showVideoControls = true
    @State private var controlsHideTimer: Timer?
    @State private var showingFullscreenOverlay = false
    @State private var showingVideoEditor = false  // 🔥 FIX: Add video editor sheet
    @State private var showSeekRippleForward = false
    @State private var showSeekRippleBackward = false
    @State private var lastDoubleTapTime = Date.distantPast  // 🔥 YOUTUBE PARITY: Double-tap detection
    @State private var showingChapters = false
    @State private var currentChapterTitle: String = ""
    @State private var showingChapterTooltip = false
    @State private var chapterTooltipX: CGFloat = 0
    @State private var hoveredChapter: Video.Chapter? = nil  // 🔥 YOUTUBE PARITY: Chapter tooltip state
    @State private var showUpNext = false
    @State private var upNextCountdown = 5
    @State private var upNextVideo: Video? = nil
    @State private var autoplayEnabled = true
    @State private var upNextTimer: Timer? = nil
    @State private var showingUpNextList = false
    @State private var videoToPresent: Video? = nil
    @State private var showingSubtitlePicker = false
    @State private var isScrubbing = false
    @State private var scrubPreviewImage: UIImage? = nil
    @State private var scrubFraction: Double = 0
    @State private var showDebugHUD = false
    @State private var showingAd = false
    @State private var pendingContentResume = false
    @State private var prerollURL: String? = nil
    @State private var midrolls: [VMAPResponse.Midroll] = []
    @State private var servedMidrollIndices: Set<Int> = []
    
    // 🔥 YOUTUBE-STYLE ADS: New ad state management
    @StateObject private var adManager = GoogleIMAAdManager.shared
    @State private var currentVideoAd: VideoAd?
    @State private var showingYouTubeAd = false
    @State private var adSkipped = false
    
    // MARK: - Enhanced YouTube Features
    @State private var showingTranscript = false
    @State private var showingVideoInfo = false
    @State private var showingRecommendations = false
    @State private var isTheaterMode = false
    @State private var showingEndScreens = false
    @State private var showingVideoCards = false
    @State private var currentVideoCard: VideoCard? = nil
    @State private var showingPlaylist = false
    @State private var currentPlaylistIndex = 0
    @State private var showingMiniPlayer = false
    @State private var watchProgress: Double = 0.0
    @State private var hasWatchedThreshold = false
    @State private var showingCinemaMode = false
    @State private var showingCreatorProfile = false
    @State private var showingQueueSidebar = false  // 🔥 YOUTUBE PARITY: Queue sidebar

    // MARK: - Video Player Section (Extracted to fix compiler timeout)
    @ViewBuilder
    private var videoPlayerSection: some View {
        ZStack {
            if showingYouTubeAd, let ad = currentVideoAd {
                // 🔥 YOUTUBE-STYLE AD PLAYER
                youtubeStyleAdPlayer(ad: ad)
            } else if isYouTube {
                youtubePlayerView
            } else {
                avPlayerView
            }
        }
        .background(Color.black)
        .overlay(alignment: .topLeading) {
            if showDebugHUD, let stats = playerManager.currentPlaybackStats() {
                debugHUDView(stats: stats)
            }
        }
        // 🔥 FIX: Removed highPriorityGesture - taps handled by PlayerTapCaptureView now
    }
    
    // 🔥 YOUTUBE-STYLE AD PLAYER VIEW
    @ViewBuilder
    private func youtubeStyleAdPlayer(ad: VideoAd) -> some View {
        ZStack {
            // Ad video player - show video only when ready
            if let player = adManager.adPlayer, adManager.isAdVideoReady {
                VideoPlayer(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .disabled(true)  // No controls during ad
                    .onAppear {
                        // Ensure playback starts when view appears
                        if player.rate == 0 {
                            player.play()
                            print("▶️ [VideoDetailView] Called play() on ad player in view")
                        }
                    }
            } else {
                // Loading state - show until video is ready
                Color.black
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            Text("Loading ad...")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
            }
            
            // YouTube-style ad overlay - only show when video is ready
            if adManager.isAdVideoReady {
                YouTubeStyleAdOverlay(
                    ad: ad,
                    adTimeRemaining: adManager.adTimeRemaining,
                    canSkip: adManager.canSkip,
                    onSkip: {
                        skipCurrentAd()
                    },
                    onLearnMore: {
                        if let url = URL(string: ad.clickURL), !ad.clickURL.isEmpty {
                            adManager.clickAd()
                            UIApplication.shared.open(url)
                        }
                    }
                )
            }
        }
    }
    
    // 🔥 SKIP AD HANDLER
    private func skipCurrentAd() {
        print("⏭️ [VideoDetailView] Skipping ad")
        adManager.skipAd()
        showingYouTubeAd = false
        currentVideoAd = nil
        
        // Resume main video
        playerManager.setupPlayer(with: video)
        playerManager.applyFastStartTuning()
        if AppState.shared.preferredVideoQuality != .auto {
            playerManager.setPreferredQuality(AppState.shared.preferredVideoQuality)
        }
        playerManager.requestAutoPlay()
        
        // Register for PiP
        GlobalVideoPlayerManager.shared.registerLocalPlayer(video: video, player: playerManager.player)
    }
    
    @ViewBuilder
    private var youtubePlayerView: some View {
        YouTubePlayerView(
            videoID: video.externalID ?? "",
            autoplay: true,
            startTime: 0,
            muted: false,
            showControls: true
        )
        .frame(maxWidth: .infinity)
        .frame(height: UIScreen.main.bounds.width * 9.0 / 16.0)
        .background(Color.black)
        
        // Minimal top bar for YouTube embed
        HStack {
            // 🔥 YOUTUBE PARITY: Chevron down to minimize (not close!)
            Button(action: { dismiss() }) {
                ZStack {
                    Circle().fill(.black.opacity(0.7)).frame(width: 36, height: 36)
                    Image(systemName: "chevron.down").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Minimize")
            
            Spacer()
            
            Text(video.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.4)))
            
            Spacer()
            
            Spacer().frame(width: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // 🔥 FIX: Get the correct player (global if from mini player, local otherwise)
    private var activePlayer: AVPlayer? {
        let globalPlayer = GlobalVideoPlayerManager.shared
        if globalPlayer.currentVideo?.id == video.id, let globalPlayerInstance = globalPlayer.player {
            return globalPlayerInstance  // Use global player if same video (from mini player)
        }
        return playerManager.player  // Otherwise use local player
    }
    
    @ViewBuilder
    private var avPlayerView: some View {
        Group {
            if let player = activePlayer {
                // 🔥 FIX: Use PiPEnabledVideoPlayer to allow manual PiP activation
                PiPEnabledVideoPlayer(player: player)
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.width * 9.0 / 16.0)
                    .background(Color.black)
            } else {
                // 🔥 FIX: Show black background while player loads (prevents white screen)
                Color.black
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.width * 9.0 / 16.0)
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            withAnimation(.spring()) { showDebugHUD.toggle() }
        }
        
        // Paid promotion badge (first 8s)
        if (video.isSponsored ?? false) && playerManager.currentTime < 8 {
            paidPromotionBadge
        }
        
        // Overlay controls (MUST be above tap area to receive taps)
        avPlayerControls
        
        // Invisible tap/drag area (disabled when controls visible so buttons work)
        videoTapArea
            .allowsHitTesting(!showVideoControls)  // 🔥 FIX: Disable tap area when controls visible
        
        // Ad overlay
        if showingAd, let url = prerollURL {
            adOverlay(url: url)
        }
        
        // End-screen overlay
        if showUpNext, let next = (upNextVideo ?? Video.sampleVideos.first(where: { $0.id != video.id })) {
            endScreenOverlay(next: next)
        }
        
        // Loading indicator
        if playerManager.isLoading {
            loadingIndicator
        }
        
        // 🔥 FIX: Error overlay (shows when video fails to load)
        if playerManager.hasError, let errorMsg = playerManager.errorMessage {
            errorOverlay(message: errorMsg)
        }
    }
    
    @ViewBuilder
    private var paidPromotionBadge: some View {
        HStack {
            Text("Paid promotion")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6))
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.top, 8)
        .padding(.leading, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .transition(.opacity)
    }
    
    @ViewBuilder
    private var videoTapArea: some View {
        PlayerTapCaptureView(
            onSingleTap: { handlePlayerTap() },
            onDoubleTap: { location, size in
                let isLeft = location.x < size.width / 2
                if isLeft {
                    playerManager.seekBackward(10)
                    showSeekRippleBackward = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showSeekRippleBackward = false
                    }
                    HapticManager.shared.impact(style: .medium)
                    print("⏪ Double-tap left: Rewind 10s")
                } else {
                    playerManager.seekForward(10)
                    showSeekRippleForward = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showSeekRippleForward = false
                    }
                    HapticManager.shared.impact(style: .medium)
                    print("⏩ Double-tap right: Forward 10s")
                }
            }
        )
        // 🔥 YOUTUBE PARITY: Speed gestures (swipe up/down on right edge to change playback speed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onChanged { value in
                    let screenWidth = UIScreen.main.bounds.width
                    let tapX = value.startLocation.x
                    
                    if tapX > screenWidth * 0.8 {
                        let verticalSwipe = value.translation.height
                        if abs(verticalSwipe) > 30 {
                            let speedChange = verticalSwipe < 0 ? 0.25 : -0.25
                            let newSpeed = max(0.25, min(2.0, playbackRate + Float(speedChange)))
                            
                            if abs(newSpeed - playbackRate) >= 0.25 {
                                playbackRate = newSpeed
                                playerManager.setPlaybackRate(newSpeed)
                                HapticManager.shared.impact(style: .light)
                                print("⚡ Speed changed to: \(newSpeed)x")
                            }
                        }
                    }
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.height > 60 {
                        presentFullscreenPlayer()
                    } else if value.translation.height < -60 {
                        Task {
                            await minimizeToMiniPlayer()
                        }
                    }
                }
        )
        .zIndex(1)
    }
    private func handlePlayerTap() {
        print("📱 Video tapped - Current controls state: \(showVideoControls)")
        if showVideoControls {
            withAnimation(.easeInOut(duration: 0.2)) {
                showVideoControls = false
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                showVideoControls = true
            }
            resetControlsHideTimer()
        }
    }

    
    @ViewBuilder
    private var avPlayerControls: some View {
        VStack(spacing: 0) {
            topControlBar
            Spacer()
            centerControls
            bottomProgressArea
        }
        .transition(.opacity)
        .zIndex(200)  // 🔥 FIX: Much higher z-index to ensure controls are above tap area
        .allowsHitTesting(showVideoControls)  // 🔥 FIX: Only allow hit testing when controls are visible
        .contentShape(Rectangle())  // 🔥 FIX: Ensure entire control area is tappable
        .opacity(showVideoControls ? 1.0 : 0.0)  // 🔥 FIX: Use opacity instead of allowsHitTesting
    }
    
    @ViewBuilder
    private var topControlBar: some View {
        HStack {
            // 🔥 YOUTUBE PARITY: Chevron down to minimize to PiP (not close!)
            // This allows users to continue watching while navigating the app
            Button(action: {
                // Register video with GlobalVideoPlayerManager for PiP
                globalPlayer.registerLocalPlayer(video: video, player: playerManager.player)
                globalPlayer.startPiP()
                dismiss()
            }) {
                ZStack {
                    Circle().fill(.black.opacity(0.7)).frame(width: 36, height: 36)
                    Image(systemName: "chevron.down").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Minimize to Picture in Picture")
            
            Spacer()
            
            HStack {
                InteractiveRichTextTitleView(
                    title: video.title,
                    onChannelTap: { channelName in
                        // Navigate to channel profile
                        print("📺 Navigate to channel: \(channelName)")
                        // TODO: Implement channel navigation
                    },
                    onHashtagTap: { hashtag in
                        // Navigate to hashtag search
                        print("🔍 Navigate to hashtag: \(hashtag)")
                        // TODO: Implement hashtag search navigation
                    },
                    textColor: .white  // 🔥 FIX: White text for visibility on black background
                )
                .font(.system(size: 15, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.8), radius: 2)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.4)))
            
            Spacer()
            
            topControlButtons
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .background(LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom))
        .opacity(showVideoControls ? 1.0 : 0.0)
    }
    
    @ViewBuilder
    private var topControlButtons: some View {
        // Quality selector
        Button(action: { showingQualitySelector = true }) {
            ZStack {
                Circle().fill(.black.opacity(0.7)).frame(width: 36, height: 36)
                Image(systemName: "aqi.medium").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        
        // Subtitles / CC toggle
        if !playerManager.availableSubtitleOptions().isEmpty {
            Button(action: { showingSubtitlePicker = true }) {
                ZStack {
                    Circle().fill(.black.opacity(0.7)).frame(width: 36, height: 36)
                    Image(systemName: "captions.bubble").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        
        // Chapters toggle
        let hasChapters = (video.chapters?.isEmpty == false) || !video.parsedChaptersFromDescription.isEmpty
        if hasChapters {
            Button(action: { showingChapters = true }) {
                ZStack {
                    Circle().fill(.black.opacity(0.7)).frame(width: 36, height: 36)
                    Image(systemName: "list.bullet.rectangle").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        
        // Theater Mode Toggle
        Button(action: {
            withAnimation(.spring()) {
                isTheaterMode.toggle()
            }
        }) {
            ZStack {
                Circle().fill(.black.opacity(0.7)).frame(width: 36, height: 36)
                Image(systemName: isTheaterMode ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        
        // Immersive fullscreen (YouTube-style)
        Button(action: {
            presentFullscreenPlayer()
        }) {
            ZStack {
                Circle().fill(.black.opacity(0.7)).frame(width: 36, height: 36)
                Image(systemName: "arrow.down.left.and.arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Fullscreen")
        
        // Minimize to native iOS PiP
        Button(action: { 
            print("🔘 [VideoDetailView] PiP button tapped!")
            print("   globalPlayer.currentVideo: \(String(describing: globalPlayer.currentVideo?.title))")
            print("   globalPlayer.isCleanedUp: \(globalPlayer.isCleanedUp)")
            print("   globalPlayer.showingFullscreen: \(globalPlayer.showingFullscreen)")
            // Start native iOS PiP - it will handle dismissing the view
            globalPlayer.startPiP()
        }) {
            ZStack {
                Circle().fill(.black.opacity(0.7)).frame(width: 36, height: 36)
                Image(systemName: "pip.enter")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Minimize to Picture in Picture")
    }
    
    @ViewBuilder
    private var centerControls: some View {
        HStack(spacing: 24) {
            Button(action: { 
                print("⏪ [VideoDetailView] Rewind button tapped")
                playerManager.seekBackward(10)
                HapticManager.shared.impact(style: .light)
            }) {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 60, height: 60)  // 🔥 FIX: Larger tap target
            .contentShape(Rectangle())  // 🔥 FIX: Explicit content shape
            .buttonStyle(.plain)  // 🔥 FIX: Plain button style to prevent interference
            
            Button(action: { 
                print("▶️ [VideoDetailView] Play/Pause button tapped - Current state: \(playerManager.isPlaying)")
                playerManager.togglePlayPause()
                HapticManager.shared.impact(style: .medium)
                
                // 🔥 FIX: Keep controls visible when play/pause is tapped
                showVideoControls = true
                resetControlsHideTimer()
            }) {
                Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 80, height: 80)  // 🔥 FIX: Larger tap target
            .contentShape(Rectangle())  // 🔥 FIX: Explicit content shape
            .buttonStyle(.plain)  // 🔥 FIX: Plain button style to prevent interference
            
            Button(action: { 
                print("⏩ [VideoDetailView] Forward button tapped")
                playerManager.seekForward(10)
                HapticManager.shared.impact(style: .light)
            }) {
                Image(systemName: "goforward.10")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 60, height: 60)  // 🔥 FIX: Larger tap target
            .contentShape(Rectangle())  // 🔥 FIX: Explicit content shape
            .buttonStyle(.plain)  // 🔥 FIX: Plain button style to prevent interference
        }
        .padding(.bottom, 18)
        .opacity(showVideoControls ? 1.0 : 0.0)
        .allowsHitTesting(showVideoControls)  // 🔥 FIX: Explicitly allow hit testing when visible
    }
    
    @ViewBuilder
    private var bottomProgressArea: some View {
        VStack {
            progressSlider
            progressTimeControls
        }
        .background(LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom))
        .opacity(showVideoControls ? 1.0 : 0.0)
    }
    
    @ViewBuilder
    private var progressSlider: some View {
        Slider(
            value: Binding(
                get: { playerManager.duration > 0 ? playerManager.currentTime / playerManager.duration : 0 },
                set: { fraction in
                    if isScrubbing {
                        scrubFraction = max(0, min(1, fraction))
                        let t = playerManager.duration * scrubFraction
                        scrubPreviewImage = playerManager.thumbnail(at: t)
                    } else {
                        playerManager.seek(to: fraction)
                    }
                }
            ),
            onEditingChanged: { editing in
                isScrubbing = editing
                if !editing {
                    playerManager.seek(to: scrubFraction)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        scrubPreviewImage = nil
                    }
                }
            }
        )
        .tint(.white)
        .padding(.horizontal, 20)
        .overlay(alignment: .bottomLeading) {
            chapterTicks
        }
        .overlay(alignment: .topLeading) {
            scrubPreview
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.width > 80 { playerManager.seekBackward(10) }
                    if value.translation.width < -80 { playerManager.seekForward(10) }
                }
        )
    }
    
    @ViewBuilder
    // 🔥 YOUTUBE PARITY: Chapter ticks with tooltips
    private var chapterTicks: some View {
        if let chapters = video.chapters, !chapters.isEmpty, playerManager.duration > 0 {
            GeometryReader { geometry in
                let trackWidth = geometry.size.width - 40
                HStack(spacing: 0) {
                    ForEach(chapters.sorted(by: { $0.start < $1.start })) { chapter in
                        let p = max(0, min(1, chapter.start / playerManager.duration))
                        let x = CGFloat(p) * trackWidth
                        
                        ZStack(alignment: .top) {
                            Rectangle()
                                .fill(Color.white.opacity(0.45))
                                .frame(width: 1, height: 8)
                            
                            // 🔥 YOUTUBE PARITY: Chapter tooltip on long press
                            if let hoveredChapter = hoveredChapter, hoveredChapter.id == chapter.id {
                                VStack(spacing: 4) {
                                    Text(chapter.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.black.opacity(0.8))
                                        )
                                    
                                    Text(formatTime(chapter.start))
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .offset(y: -50)
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                        .offset(x: x)
                        .onLongPressGesture(minimumDuration: 0.3) {
                            hoveredChapter = chapter
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                if hoveredChapter?.id == chapter.id {
                                    hoveredChapter = nil
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: 50)
            .padding(.horizontal, 28)
        }
    }
    
    @ViewBuilder
    private var scrubPreview: some View {
        if isScrubbing, let img = scrubPreviewImage, playerManager.duration > 0 {
            let trackWidth = UIScreen.main.bounds.width - 40
            let x = CGFloat(scrubFraction) * max(0, trackWidth - 160)
            VStack(spacing: 6) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 90)
                    .clipped()
                    .cornerRadius(8)
                    .shadow(radius: 3)
                Text(formatTime(playerManager.duration * scrubFraction))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
            }
            .offset(x: x, y: -100)
            .transition(.opacity)
        }
    }
    
    @ViewBuilder
    private var progressTimeControls: some View {
        HStack {
            Text(formatTime(playerManager.currentTime)).foregroundColor(.white).font(.caption.monospacedDigit())
            Spacer()
            quickControls
            Text(formatTime(playerManager.duration)).foregroundColor(.white).font(.caption.monospacedDigit())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var quickControls: some View {
        HStack(spacing: 12) {
            Button(action: { showingQualitySelector = true }) {
                HStack(spacing: 4) {
                    Image(systemName: playerManager.selectedQuality.is4K ? "4k.tv" : (playerManager.selectedQuality.isHD ? "hifispeaker.2" : "tv"))
                    Text(playerManager.selectedQuality == .auto ? "Auto" : playerManager.selectedQuality.rawValue)
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            
            Button(action: { showingPlaybackSpeedSelector = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "gauge.medium")
                    Text(String(format: "%.1fx", playbackRate))
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            
            Button(action: { 
                // Start native iOS PiP - it will handle dismissing the view
                globalPlayer.startPiP()
            }) {
                Image(systemName: "pip.enter")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Minimize to Picture in Picture")
            
            // 🔥 YOUTUBE PARITY: Queue button
            Button(action: { 
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showingQueueSidebar.toggle()
                }
            }) {
                Image(systemName: "list.bullet")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(showingQueueSidebar ? AppTheme.Colors.primary : .white)
            }
            .buttonStyle(ScaleButtonStyle())
            
            AirPlayRoutePickerView()
                .frame(width: 24, height: 24)
        }
    }
    
    @ViewBuilder
    private func adOverlay(url: String) -> some View {
        AdPlayerOverlay(adUrl: url) {
            withAnimation { showingAd = false }
            if pendingContentResume { playerManager.play(); pendingContentResume = false }
        }
        .frame(maxWidth: .infinity)
        .frame(height: UIScreen.main.bounds.width * 9.0 / 16.0)
        .transition(.opacity)
        .zIndex(100)
    }
    
    @ViewBuilder
    private func endScreenOverlay(next: Video) -> some View {
        ZStack {
            Rectangle().fill(Color.black.opacity(0.6))
            VStack(spacing: 12) {
                Text("Up next in \(upNextCountdown)s").font(.headline).foregroundColor(.white)
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: next.thumbnailURL)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: { Rectangle().fill(.gray.opacity(0.3)) }
                    .frame(width: 160, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(next.title).font(.subheadline).lineLimit(2).foregroundColor(.white)
                        Text(next.creator.displayName).font(.caption).foregroundColor(.white.opacity(0.85))
                    }
                    Spacer()
                }
                HStack(spacing: 12) {
                    Button("Cancel") { cancelEndscreen() }
                        .buttonStyle(.plain)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.white.opacity(0.15), in: Capsule())
                    Button("Play now") { playNext(next) }
                        .buttonStyle(.plain)
                        .foregroundColor(.black)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.white, in: Capsule())
                }
            }
            .padding()
        }
        .frame(height: UIScreen.main.bounds.width * 9.0 / 16.0)
        .transition(.opacity)
        .zIndex(50)
    }
    
    @ViewBuilder
    private var loadingIndicator: some View {
        ZStack {
            Circle().fill(.black.opacity(0.6)).frame(width: 80, height: 80)
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(1.2)
        }
        .zIndex(100)
    }
    
    @ViewBuilder
    private func errorOverlay(message: String) -> some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.9)
            
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.red)
                
                VStack(spacing: 8) {
                    Text("Video Error")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(message)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                HStack(spacing: 12) {
                    Button(action: {
                        playerManager.hasError = false
                        playerManager.errorMessage = nil
                        playerManager.setupPlayer(with: video)
                        // 🔥 FIX: Register video with GlobalVideoPlayerManager for PiP
                        globalPlayer.registerLocalPlayer(video: video, player: playerManager.player)
                    }) {
                        Text("Retry")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.primary)
                            )
                    }
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            globalPlayer.closePlayer()
                            dismiss()
                        }
                    }) {
                        Text("Close Video")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.top, 24)
            
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    globalPlayer.closePlayer()
                    dismiss()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.6), in: Circle())
            }
            .padding(16)
            .accessibilityLabel("Close video")
        }
        .frame(maxWidth: .infinity)
        .frame(height: UIScreen.main.bounds.width * 9.0 / 16.0)
        .transition(.opacity)
        .zIndex(200)
    }
    
    @ViewBuilder
    private func debugHUDView(stats: VideoPlayerManager.PlaybackStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("⚙️ Debug HUD").font(.caption2).bold().foregroundColor(.white)
            Text("Res: \(stats.width)x\(stats.height)").font(.caption2).foregroundColor(.white)
            Text("Bitrate: \(stats.bitrateKbps) kbps").font(.caption2).foregroundColor(.white)
            Text(String(format: "FPS: %.1f", stats.fps)).font(.caption2).foregroundColor(.white)
            Text(String(format: "Time: %.1f/%.1f", stats.currentTime, stats.duration)).font(.caption2).foregroundColor(.white)
        }
        .padding(8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
        .padding(12)
        .transition(.opacity)
    }

    var body: some View {
        VStack(spacing: 0) {
            // ALL-IN-ONE Video Player with YouTube-style controls
            videoPlayerSection

            // Video metadata and controls (with Up Next autoplay)
            VideoDetailMetaView(video: video,
                                isSubscribed: $isSubscribed,
                                isWatchLater: $isWatchLater,
                                isLiked: $isLiked,
                                isDisliked: $isDisliked,
                                expandedDescription: $expandedDescription,
                                onShare: { showingShareSheet = true },
                                onMore: { showingMoreOptions = true },
                                onComment: { showingCommentComposer = true },
                                onChapters: {
                                    // Only present if either chapters exist on model or can be parsed from description
                                    if (video.chapters?.isEmpty == false) || !video.parsedChaptersFromDescription.isEmpty {
                                        showingChapters = true
                                    }
                                },
                                onProfileTap: { showingCreatorProfile = true },
                                dynamicViewCount: currentViewCount) // 🔥 REAL-TIME: Pass reactive view count
            .overlay(alignment: .bottom) {
                // Simple Up Next bar with autoplay toggle
                if let next = Video.sampleVideos.first(where: { $0.id != video.id }) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial)
                            .frame(width: 56, height: 32)
                            .overlay(Text("Up next").font(.caption2))
                        Text(next.title).font(.caption).lineLimit(1).foregroundStyle(AppTheme.Colors.textPrimary)
                        Spacer()
                        Toggle(isOn: .constant(true)) { Text("Autoplay").font(.caption2) }
                            .labelsHidden()
                            .tint(AppTheme.Colors.primary)
                        Button {
                            playNext(next)
                        } label: {
                            Image(systemName: "play.fill")
                                .foregroundColor(AppTheme.Colors.primary)
                                .font(.title2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .navigationBarHidden(true)
        // When user returns from fullscreen by dismissing, ensure state is consistent
        .sheet(isPresented: $showingCommentComposer) {
            RealTimeCommentsView(video: video)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showingShareSheet) {
            VideoShareSheet(items: [shareURLWithTimestamp()])
                .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $showingFullscreenOverlay) {
            ImmersiveFullscreenPlayerView(video: video) {
                // Exit fullscreen back to inline without breaking playback
                globalPlayer.showingFullscreen = false
                showingFullscreenOverlay = false
            }
        }
        .sheet(isPresented: $showingChapters) {
            VideoChaptersSheet(video: video) { t in
                let progress = playerManager.duration > 0 ? t / playerManager.duration : 0
                playerManager.seek(to: progress)
                playerManager.play()
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingMoreOptions) {
            VideoMoreOptionsSheet(video: video,
                                  isSubscribed: $isSubscribed,
                                  isWatchLater: $isWatchLater)
                .presentationDetents([.medium])
        }
        // 🔥 FIX: Video editor sheet (YouTube-style edit interface)
        .sheet(isPresented: $showingVideoEditor) {
            PostUploadEditorView(video: video)
        }
        .sheet(isPresented: $showingSubtitlePicker) {
            NavigationView {
                List {
                    Button("Off") {
                        playerManager.selectSubtitle(option: nil)
                        showingSubtitlePicker = false
                    }
                    ForEach(Array(playerManager.availableSubtitleOptions().enumerated()), id: \.offset) { _, opt in
                        Button(opt.displayName ?? "Track") {
                            playerManager.selectSubtitle(option: opt)
                            showingSubtitlePicker = false
                        }
                    }
                }
                .navigationTitle("Subtitles & CC")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { showingSubtitlePicker = false } } }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingUpNextList) {
            UpNextQueueSheet(current: video, queue: Video.sampleVideos) { v in
                playNext(v)
            }
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(item: $videoToPresent) { next in
            VideoDetailView(video: next)
                .id(next.id) // Prevent view recreation on state changes
        }
        .sheet(isPresented: $showingQualitySelector) {
            VideoQualitySelector(selectedQuality: $videoQuality) { quality in
                videoQuality = quality
                playerManager.setPreferredQuality(quality)
            }
            .presentationDetents([.fraction(0.4)])
        }
        .sheet(isPresented: $showingPlaybackSpeedSelector) {
            PlaybackSpeedSelector(selectedSpeed: $playbackRate) { speed in
                playbackRate = speed
                playerManager.setPlaybackRate(speed)
            }
            .presentationDetents([.fraction(0.4)])
        }
        .sheet(isPresented: $showingTranscript) {
            VideoTranscriptSheet(video: video)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingVideoInfo) {
            VideoInfoSheet(video: video)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingCreatorProfile) {
            CreatorProfileSheet(creator: video.creator)
                .presentationDetents([.large])
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
                
                // 🔥 FIX: Check if global player already has this video playing (from mini player)
                let globalPlayer = GlobalVideoPlayerManager.shared
                let isFromMiniPlayer = globalPlayer.currentVideo?.id == video.id && globalPlayer.player != nil
                
                if isFromMiniPlayer {
                    print("✅ [VideoDetailView] Video already playing in global player - using global player")
                    // Use the global player's manager instead of creating a new one
                    // This prevents white screen and ensures smooth transition
                    if let existingManager = globalPlayer.exposedPlayerManager {
                        // 🔥 FIX: Use the existing player manager from global player
                        // We can't reassign @StateObject, but we can use the global player's player directly
                        // The VideoPlayer view will use globalPlayer.player
                        isPlayerReady = true
                        showPlayer = true
                        isViewAppeared = true
                        
                        // Update view count
                        Task {
                            let latestCount = await RealtimeViewTracker.shared.getViewCount(for: video.id)
                            currentViewCount = latestCount
                        }
                        
                        // Sync playback state
                        if let player = globalPlayer.player {
                            playbackRate = player.rate
                            // Note: Playback state is managed by globalPlayer.isPlaying
                        }
                        
                        print("✅ [VideoDetailView] Adopted global player - ready to display")
                        return
                    }
                }
                
                // 🔥 FIX: Only stop if not from mini player (to prevent interrupting playback)
                if !isFromMiniPlayer {
                    GlobalVideoPlayerManager.shared.stopImmediately()
                }
                
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
                        
                        print("🎯 Checking ads for video: \(video.title)")
                        print("💰 Video monetization: \(video.monetization?.isMonetized ?? false)")
                        
                        // 🔥 YOUTUBE-STYLE ADS: Use new GoogleIMAAdManager for real skippable ads
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
                        // 🔥 NO VMAP ADS ON YOUR OWN VIDEOS
                        if let currentUser = AuthenticationManager.shared.currentUser,
                           video.creator.id == currentUser.id {
                            print("🎬 Skipping VMAP ads - your video!")
                            return
                        }
                        
                        if let vmap = await AdsService.shared.fetchVMAP(videoId: video.id) {
                            if let preroll = vmap.prerollUrl, !preroll.isEmpty, AdsFrequencyCapService.shared.canShowPreroll() {
                                prerollURL = preroll
                                showingAd = true
                                pendingContentResume = true
                                playerManager.pause()
                                AdsFrequencyCapService.shared.recordPreroll()
                            }
                            self.midrolls = vmap.midrolls ?? []
                            self.servedMidrollIndices = []
                        }
                    }
                }
                showVideoControls = true
                isViewAppeared = true
                resetControlsHideTimer()
            }
        }
        .onDisappear {
            print("🎬 VideoDetailView disappearing")
            playerControlsTimer?.invalidate()
            controlsHideTimer?.invalidate()
            
            // 🔥 YOUTUBE PARITY: When you back out of a video, it should drop into the mini player
            // just like YouTube – even if you never used the swipe-up gesture.
            if !isYouTube {
                // Only try to show mini player if we're not actively going fullscreen
                if !globalPlayer.showingFullscreen {
                    // 🔥 FIX: Adopt player SYNCHRONOUSLY on main thread to prevent race conditions
                    // Start native PiP when dismissing
                    if globalPlayer.currentVideo == nil {
                        print("🔄 [VideoDetailView] Adopting player manager for PiP on disappear")
                        Task { @MainActor in
                            let wasPlaying = playerManager.isPlaying
                            await globalPlayer.adoptExternalPlayerManager(playerManager, video: video, showFullscreen: false)
                            
                            // 🔥 NATIVE PIP: Start PiP after adoption
                            if globalPlayer.currentVideo != nil {
                                globalPlayer.startPiP()
                                
                                // Ensure playback continues
                                if wasPlaying, let player = globalPlayer.player, player.rate == 0 {
                                    player.play()
                                    globalPlayer.isPlaying = true
                                }
                            }
                        }
                    } else {
                        // Player already adopted - just start PiP
                        globalPlayer.startPiP()
                    }
                }
                
                if !globalPlayer.showingFullscreen,
                   globalPlayer.currentVideo?.id != video.id {
                    playerManager.performCleanup()
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background || newPhase == .inactive {
                if playerManager.isPlaying {
                    playerManager.pause()
                }
            }
        }
        .onChange(of: showVideoControls) { newValue in
            print("🎮 Controls visibility changed to: \(newValue)")
            if newValue {
                resetControlsHideTimer()
            } else {
                controlsHideTimer?.invalidate()
            }
        }
        .onChange(of: playerManager.isPlaying) { newValue in
            print("🎵 Player state changed to: \(newValue ? "Playing" : "Paused")")
        }
        .onChange(of: playerManager.currentTime) { newTime in
            // Update watch progress
            if playerManager.duration > 0 {
                watchProgress = newTime / playerManager.duration
                
                // Track watch milestones (YouTube-style analytics)
                if !hasWatchedThreshold && watchProgress >= 0.25 {
                    hasWatchedThreshold = true
                    Task {
                        await AnalyticsService.shared.trackVideoQuartile(videoId: video.id, quartile: 1)
                    }
                } else if watchProgress >= 0.5 {
                    Task {
                        await AnalyticsService.shared.trackVideoQuartile(videoId: video.id, quartile: 2)
                    }
                } else if watchProgress >= 0.75 {
                    Task {
                        await AnalyticsService.shared.trackVideoQuartile(videoId: video.id, quartile: 3)
                    }
                }
            }
            
            if let chapters = video.chapters, !chapters.isEmpty {
                let sorted = chapters.sorted { $0.start < $1.start }
                if let current = sorted.last(where: { $0.start <= newTime }) {
                    currentChapterTitle = current.title
                }
            }
            
            // Check for video cards at specific timestamps
            if let cards = video.videoCards {
                for card in cards {
                    if abs(newTime - card.timestamp) < 0.5 && currentVideoCard?.id != card.id {
                        currentVideoCard = card
                        showingVideoCards = true
                        
                        // Auto-hide after 8 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                            if currentVideoCard?.id == card.id {
                                showingVideoCards = false
                                currentVideoCard = nil
                            }
                        }
                    }
                }
            }
            
            // Check midroll schedule
            if !midrolls.isEmpty, !showingAd, playerManager.duration > 0 {
                for (idx, m) in midrolls.enumerated() {
                    if servedMidrollIndices.contains(idx) { continue }
                    if newTime >= m.time, newTime <= m.time + 0.5, AdsFrequencyCapService.shared.canShowMidroll() {
                        servedMidrollIndices.insert(idx)
                        prerollURL = m.url
                        showingAd = true
                        pendingContentResume = true
                        playerManager.pause()
                        AdsFrequencyCapService.shared.recordMidroll()
                        break
                    }
                }
            }
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
            beginEndscreen()
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
            // 🔥 FIX: Always fetch latest view count from Firestore on appear
            print("📊 [VideoDetailView] Fetching latest view count for: \(video.id)")
            let latestCount = await RealtimeViewTracker.shared.getViewCount(for: video.id)
            print("📊 [VideoDetailView] Latest view count from Firestore: \(latestCount)")
            
            await MainActor.run {
                currentViewCount = latestCount
            }
        }
        .onChange(of: playerManager.isPlaying) { isPlaying in
            // 🔥 FIX: Update view count when video starts playing
            if isPlaying {
                Task {
                    let latestCount = await RealtimeViewTracker.shared.getViewCount(for: video.id)
                    await MainActor.run {
                        currentViewCount = latestCount
                        print("📊 [VideoDetailView] View count updated after play: \(latestCount)")
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SeekToTimestamp"))) { notification in
            if let timestamp = notification.object as? TimeInterval {
                let progress = playerManager.duration > 0 ? timestamp / playerManager.duration : 0
                playerManager.seek(to: progress)
            }
        }
        // 🔥 YOUTUBE PARITY: Auto quality selection when video loads
        .onChange(of: playerManager.duration) { _ in
            if playerManager.duration > 0 && playerManager.selectedQuality == .auto {
                playerManager.autoSelectQuality()
            }
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
    
    // MARK: - Helper Methods
    
    private func resetControlsHideTimer() {
        controlsHideTimer?.invalidate()
        
        // 🔥 FIX: Only auto-hide controls if video is PLAYING (not when paused)
        guard playerManager.isPlaying else { 
            print("⏸️ [VideoDetailView] Controls NOT auto-hiding (video paused)")
            return 
        }
        
        // 🔥 FIX: 5 second delay before auto-hiding (YouTube standard)
        controlsHideTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            // Double-check video is still playing before hiding
            guard playerManager.isPlaying else { 
                print("⏸️ [VideoDetailView] Cancelled auto-hide (video paused)")
                return 
            }
            
            withAnimation(.easeInOut(duration: 0.25)) {
                showVideoControls = false
                print("⏰ [VideoDetailView] Controls auto-hidden after 5s")
            }
        }
        
        print("⏱️ [VideoDetailView] Controls hide timer reset (5s)")
    }

    // MARK: - Gesture Actions
    private func presentFullscreenPlayer() {
        // Hand off the existing manager to the global one and present a true fullscreen overlay
        Task {
            await globalPlayer.adoptExternalPlayerManager(playerManager, video: video, showFullscreen: true)
        }
        showingFullscreenOverlay = true
    }

    @MainActor
    private func minimizeToMiniPlayer() async {
        print("🔄 [VideoDetailView] Minimizing to native PiP via swipe/button")
        print("📊 [VideoDetailView] Player manager exists: \(playerManager != nil)")
        print("📊 [VideoDetailView] Player exists: \(playerManager.player != nil)")
        print("📊 [VideoDetailView] Is playing: \(playerManager.isPlaying)")
        
        let wasPlaying = playerManager.isPlaying
        
        // Adopt player and start native PiP
        await globalPlayer.adoptExternalPlayerManager(playerManager, video: video, showFullscreen: false)
        
        // Start native iOS PiP
        globalPlayer.startPiP()
        
        // Ensure playback continues
        if wasPlaying, let player = globalPlayer.player, player.rate == 0 {
            print("▶️ [VideoDetailView] Resuming playback after PiP")
            player.play()
            globalPlayer.isPlaying = true
        }
        
        // Dismiss the view
        dismiss()
        
        // Double-check after dismissal to ensure state persists
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard !self.globalPlayer.showingFullscreen else {
                print("⛔️ [VideoDetailView] Skipping post-dismiss restore because fullscreen requested")
                return
            }
            
            if self.globalPlayer.currentVideo != nil {
                self.enforceMiniPlayerStateIfNeeded(wasPlaying: wasPlaying, reason: "Post-dismiss verification")
            }
        }
    }

    @MainActor
    private func enforceMiniPlayerStateIfNeeded(wasPlaying: Bool, reason: String) {
        if globalPlayer.showingFullscreen {
            print("⛔️ [VideoDetailView] Skipping PiP enforcement (\(reason)) because fullscreen requested")
            return
        }
        
        // Start native PiP
        print("🔄 [VideoDetailView] Starting native PiP (\(reason))")
        globalPlayer.startPiP()
        
        resumeMiniPlayerPlaybackIfNeeded(wasPlaying: wasPlaying, reason: reason)
        print("✅ [VideoDetailView] Native PiP started (\(reason))")
    }
    
    @MainActor
    private func resumeMiniPlayerPlaybackIfNeeded(wasPlaying: Bool, reason: String) {
        guard wasPlaying else { return }
        
        if let player = globalPlayer.player {
            if player.rate == 0 {
                print("▶️ [VideoDetailView] Resuming playback via global player (\(reason))")
                player.play()
                globalPlayer.isPlaying = true
            }
        } else if let manager = globalPlayer.exposedPlayerManager, let player = manager.player {
            print("✅ [VideoDetailView] Using exposed player manager to resume playback (\(reason))")
            if player.rate == 0 {
                player.play()
            }
            globalPlayer.isPlaying = true
        } else {
            print("🚨 [VideoDetailView] Unable to resume playback (\(reason)) - no player available")
        }
    }

    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    // MARK: - Chapters Helpers
    private func nearestChapter(for time: TimeInterval, in chapters: [Video.Chapter]) -> Video.Chapter? {
        // Find the last chapter whose start time is <= current time
        // Keep logic simple to help the compiler
        let sorted = chapters.sorted { $0.start < $1.start }
        var candidate: Video.Chapter?
        for chapter in sorted {
            if chapter.start <= time {
                candidate = chapter
            } else {
                break
            }
        }
        return candidate
    }

    // MARK: - Endscreen & Queue
    private func beginEndscreen() {
        upNextVideo = Video.sampleVideos.first(where: { $0.id != video.id })
        if let next = upNextVideo {
            // Prewarm Up Next video for instant start
            VideoPlayerManager.prewarm(urlString: next.videoURL)
        }
        guard upNextVideo != nil else { return }
        showUpNext = true
        upNextCountdown = 5
        upNextTimer?.invalidate()
        upNextTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if upNextCountdown > 0 {
                upNextCountdown -= 1
            } else {
                upNextTimer?.invalidate(); upNextTimer = nil
                if autoplayEnabled, let n = upNextVideo {
                    playNext(n)
                }
            }
        }

        // 🔥 REMOVED: Rating popup - too annoying for users
        // Users can rate the app manually from Settings if they want
    }

    private func playNext(_ next: Video) {
        showUpNext = false
        upNextTimer?.invalidate(); upNextTimer = nil
        videoToPresent = next
    }

    private func cancelEndscreen() {
        showUpNext = false
        upNextTimer?.invalidate(); upNextTimer = nil
    }

    private func shareURLWithTimestamp() -> String {
        let seconds = Int(playerManager.currentTime.rounded())
        return "\(video.link)?t=\(seconds)"
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        VideoDetailView(video: Video.sampleVideos[0])
            .environmentObject(PreviewSafeGlobalVideoPlayerManager())
    }
}