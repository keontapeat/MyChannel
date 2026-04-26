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
    @StateObject private var appState = AppState.shared
    @StateObject private var recommendationService = VideoDetailRecommendationService.shared
    
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
    // showingShareSheet removed — share is now presented directly via UIApplication.shared.presentShareSheet()
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
    @State private var userExplicitlyClosed = false  // 🔥 YOUTUBE PARITY: Track explicit close vs swipe dismiss
    @State private var watchProgress: Double = 0.0
    @State private var hasWatchedThreshold = false
    @State private var showingCinemaMode = false
    @State private var showingCreatorProfile = false
    @State private var selectedCreatorProfile: User? = nil
    @State private var selectedHashtag: String? = nil
    @State private var showingQueueSidebar = false  // 🔥 YOUTUBE PARITY: Queue sidebar
    @State private var recommendedVideos: [Video] = []  // Service-backed recommendations
    
    // MARK: - YouTube Parity: Long-Press 2x Speed
    @State private var isLongPressSpeedUp = false  // 🔥 YOUTUBE PARITY: Hold-to-2x active
    @State private var savedPlaybackRate: Float = 1.0  // 🔥 Rate before long-press
    @State private var showSpeedUpIndicator = false
    
    // MARK: - YouTube Parity: Horizontal Swipe-to-Seek
    @State private var isHorizontalSeeking = false
    @State private var seekStartTime: TimeInterval = 0
    @State private var seekDeltaSeconds: TimeInterval = 0
    @State private var showSeekOverlay = false
    
    // MARK: - YouTube Parity: Loop Toggle
    @State private var isLooping = false

    // MARK: - Wired Phase 141–154 Services
    @StateObject private var ambientService = AmbientModeService.shared
    @StateObject private var heatmapService = SentimentHeatmapService.shared
    @StateObject private var timestampedCommentsService = TimestampedCommentsService.shared
    @StateObject private var speedCurvesService = PlaybackSpeedCurvesService.shared
    @State private var pinchScale: CGFloat = 1.0
    @State private var lastPinchScale: CGFloat = 1.0
    @State private var showAmbientGlow = false
    @State private var showSilenceSkipIndicator = false
    
    // MARK: - YouTube Parity: Brightness / Volume Swipe
    @State private var currentBrightness: CGFloat = UIScreen.main.brightness
    @State private var currentVolume: Float = 0.5
    @State private var showBrightnessOverlay = false
    @State private var showVolumeOverlay = false
    @State private var verticalSwipeStartY: CGFloat = 0

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
        .background(
            // 🔥 PHASE 142: Ambient Mode glow behind player
            Group {
                if showAmbientGlow, ambientService.isEnabled {
                    let palette = ambientService.currentPalette
                    RadialGradient(
                        colors: [
                            Color(palette.dominant).opacity(ambientService.glowIntensity),
                            Color(palette.secondary).opacity(ambientService.glowIntensity * 0.5),
                            Color.black
                        ],
                        center: .center, startRadius: 50, endRadius: 300
                    )
                    .animation(.easeInOut(duration: ambientService.transitionDuration), value: palette)
                } else {
                    Color.black
                }
            }
        )
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
                RawPlayerLayerView(player: player, videoGravity: .resizeAspect)
                    .aspectRatio(16/9, contentMode: .fit)
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
                    // 🔥 PHASE 141: Pinch-to-zoom on video player
                    .scaleEffect(pinchScale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                pinchScale = max(1.0, min(3.0, lastPinchScale * value))
                            }
                            .onEnded { value in
                                lastPinchScale = pinchScale
                                if pinchScale < 1.1 {
                                    withAnimation(.spring()) { pinchScale = 1.0; lastPinchScale = 1.0 }
                                }
                            }
                    )
                    .clipped()
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
        if showUpNext, let next = (upNextVideo ?? recommendedVideos.first(where: { $0.id != video.id })) {
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
        
        // 🔥 YOUTUBE PARITY: Long-press 2x speed indicator
        if showSpeedUpIndicator {
            HStack(spacing: 6) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("2x")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.black.opacity(0.7)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 60)
            .zIndex(350)
            .transition(.scale.combined(with: .opacity))
            .allowsHitTesting(false)
        }
        
        // 🔥 YOUTUBE PARITY: Horizontal swipe-to-seek overlay
        if showSeekOverlay {
            let targetTime = max(0, min(playerManager.duration, seekStartTime + seekDeltaSeconds))
            VStack(spacing: 4) {
                Text(formatTime(targetTime))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                HStack(spacing: 4) {
                    Image(systemName: seekDeltaSeconds >= 0 ? "forward.fill" : "backward.fill")
                        .font(.system(size: 11))
                    Text("\(seekDeltaSeconds >= 0 ? "+" : "")\(Int(seekDeltaSeconds))s")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.7)))
            .zIndex(350)
            .allowsHitTesting(false)
        }
        
        // 🔥 YOUTUBE PARITY: Brightness overlay (left side vertical swipe)
        if showBrightnessOverlay {
            HStack(spacing: 8) {
                Image(systemName: UIScreen.main.brightness > 0.5 ? "sun.max.fill" : "sun.min.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                ProgressView(value: Double(UIScreen.main.brightness), total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(width: 100)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.black.opacity(0.7)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .zIndex(350)
            .allowsHitTesting(false)
        }
        
        // 🔥 PHASE 154: Sentiment heatmap "Most replayed" indicator
        if !heatmapService.mostReplayed.isEmpty, let top = heatmapService.mostReplayed.first {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
                Text("Most replayed")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.7)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 20)
            .padding(.bottom, 60)
            .zIndex(340)
            .allowsHitTesting(false)
            .opacity({
                let t = playerManager.currentTime
                return (t >= top.startSec && t <= top.endSec) ? 1 : 0
            }())
            .animation(.easeInOut, value: playerManager.currentTime)
        }

        // 🔥 PHASE 145: Auto-skip silence indicator
        if showSilenceSkipIndicator {
            HStack(spacing: 6) {
                Image(systemName: "waveform.slash")
                    .font(.system(size: 12, weight: .bold))
                Text("Skipping silence")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.7)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 60)
            .zIndex(340)
            .allowsHitTesting(false)
            .transition(.opacity)
        }

        // 🔥 PHASE 146: Timestamped comment bubble
        if let bubble = timestampedCommentsService.commentsAt(timestampSec: playerManager.currentTime, toleranceSec: 1.5).first {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                Text(bubble.body)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.75)))
            .frame(maxWidth: 280, alignment: .leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 16)
            .padding(.bottom, 80)
            .zIndex(345)
            .allowsHitTesting(false)
            .transition(.scale.combined(with: .opacity))
        }

        // 🔥 YOUTUBE PARITY: Volume overlay (right side vertical swipe)
        if showVolumeOverlay {
            HStack(spacing: 8) {
                Image(systemName: (playerManager.player?.volume ?? 0) > 0.5 ? "speaker.wave.3.fill" : "speaker.wave.1.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                ProgressView(value: Double(playerManager.player?.volume ?? 0), total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(width: 100)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.black.opacity(0.7)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(.trailing, 20)
            .zIndex(350)
            .allowsHitTesting(false)
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
        // 🔥 YOUTUBE PARITY: Long-press to 2x speed (hold → 2x, release → restore)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onChanged { value in
                    switch value {
                    case .second(true, _):
                        // Long press recognized — activate 2x speed
                        if !isLongPressSpeedUp {
                            savedPlaybackRate = playbackRate
                            playbackRate = 2.0
                            playerManager.setPlaybackRate(2.0)
                            isLongPressSpeedUp = true
                            withAnimation(.spring(response: 0.2)) { showSpeedUpIndicator = true }
                            HapticManager.shared.impact(style: .medium)
                            print("⚡ [YouTube] Long-press 2x speed activated")
                        }
                    default:
                        break
                    }
                }
                .onEnded { _ in
                    // Finger lifted — restore original speed
                    if isLongPressSpeedUp {
                        playbackRate = savedPlaybackRate
                        playerManager.setPlaybackRate(savedPlaybackRate)
                        isLongPressSpeedUp = false
                        withAnimation(.spring(response: 0.2)) { showSpeedUpIndicator = false }
                        HapticManager.shared.impact(style: .light)
                        print("⚡ [YouTube] Long-press released — back to \(savedPlaybackRate)x")
                    }
                }
        )
        // 🔥 YOUTUBE PARITY: Horizontal swipe-to-seek + Brightness/Volume vertical swipe + Swipe up/down for fullscreen/PiP
        .simultaneousGesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .local)
                .onChanged { value in
                    let screenWidth = UIScreen.main.bounds.width
                    let playerHeight = UIScreen.main.bounds.width * 9.0 / 16.0
                    let startX = value.startLocation.x
                    let dx = value.translation.width
                    let dy = value.translation.height
                    
                    // Determine gesture direction on first significant movement
                    if !isHorizontalSeeking && !showBrightnessOverlay && !showVolumeOverlay {
                        if abs(dx) > abs(dy) && abs(dx) > 20 {
                            // Horizontal → seek
                            isHorizontalSeeking = true
                            seekStartTime = playerManager.currentTime
                            seekDeltaSeconds = 0
                        } else if abs(dy) > abs(dx) && abs(dy) > 20 {
                            // Vertical → brightness (left) or volume (right)
                            let isLeftSide = startX < screenWidth * 0.5
                            if isLeftSide {
                                showBrightnessOverlay = true
                                currentBrightness = UIScreen.main.brightness
                            } else {
                                showVolumeOverlay = true
                            }
                            verticalSwipeStartY = value.startLocation.y
                        }
                    }
                    
                    // 🔥 Horizontal seek: 1pt = ~0.15s (whole screen swipe ≈ 60s)
                    if isHorizontalSeeking {
                        let seekScale = min(playerManager.duration, 60.0) / screenWidth
                        seekDeltaSeconds = Double(dx) * seekScale
                        withAnimation(.easeOut(duration: 0.1)) { showSeekOverlay = true }
                    }
                    
                    // 🔥 Brightness (left side vertical swipe)
                    if showBrightnessOverlay {
                        let deltaY = verticalSwipeStartY - value.location.y
                        let brightnessChange = deltaY / playerHeight
                        let newBrightness = max(0, min(1, currentBrightness + brightnessChange))
                        UIScreen.main.brightness = newBrightness
                    }
                    
                    // 🔥 Volume (right side vertical swipe)
                    if showVolumeOverlay {
                        let deltaY = verticalSwipeStartY - value.location.y
                        let volumeChange = Float(deltaY / playerHeight)
                        let newVolume = max(0, min(1, currentVolume + volumeChange))
                        playerManager.player?.volume = newVolume
                    }
                }
                .onEnded { value in
                    // 🔥 Finalize horizontal seek
                    if isHorizontalSeeking {
                        let targetTime = max(0, min(playerManager.duration, seekStartTime + seekDeltaSeconds))
                        let progress = playerManager.duration > 0 ? targetTime / playerManager.duration : 0
                        playerManager.seek(to: progress)
                        HapticManager.shared.impact(style: .light)
                        print("⏩ [YouTube] Swipe-seek to \(Int(targetTime))s (delta: \(Int(seekDeltaSeconds))s)")
                    }
                    
                    // 🔥 Finalize brightness
                    if showBrightnessOverlay {
                        currentBrightness = UIScreen.main.brightness
                    }
                    
                    // 🔥 Finalize volume
                    if showVolumeOverlay {
                        currentVolume = playerManager.player?.volume ?? 0.5
                    }
                    
                    // 🔥 Swipe down → PiP, Swipe up → fullscreen (only if not seeking/adjusting)
                    if !isHorizontalSeeking && !showBrightnessOverlay && !showVolumeOverlay {
                        if value.translation.height > 60 {
                            Task { await minimizeToMiniPlayer() }
                        } else if value.translation.height < -60 {
                            presentFullscreenPlayer()
                        }
                    }
                    
                    // Reset all gesture states
                    isHorizontalSeeking = false
                    seekDeltaSeconds = 0
                    withAnimation { showSeekOverlay = false }
                    showBrightnessOverlay = false
                    showVolumeOverlay = false
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
        .allowsHitTesting(showVideoControls && !showUpNext)  // 🔥 FIX: Disable hit testing when end screen is showing
        .contentShape(Rectangle())  // 🔥 FIX: Ensure entire control area is tappable
        .opacity(showVideoControls && !showUpNext ? 1.0 : 0.0)  // 🔥 FIX: Hide controls when end screen is active
    }
    
    @ViewBuilder
    private var topControlBar: some View {
        HStack {
            // 🔥 YOUTUBE PARITY: Chevron down to minimize to PiP (not close!)
            // This allows users to continue watching while navigating the app
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                // Start native iOS PiP — dismiss ONLY after PiP bubble appears.
                // If PiP fails (simulator / PiP disabled), just dismiss normally.
                PiPPlayerManager.shared.startPiP(
                    onStarted: { dismiss() },
                    onFailed:  { dismiss() }
                )
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
                    onChannelTap: { channelName in handleChannelTap(channelName) },
                    onHashtagTap: { hashtag in handleHashtagTap(hashtag) },
                    textColor: .white,  // 🔥 FIX: White text for visibility on black background
                    channelMapper: ChannelMentionMapper(creator: video.creator)  // 🔥 YOUTUBE PARITY: @sbkeonta_ → @ShotByKeonta
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
        
        // 🔥 PHASE 142: Ambient Mode Toggle
        Button(action: {
            ambientService.toggle()
            showAmbientGlow = ambientService.isEnabled
            HapticManager.shared.impact(style: .light)
        }) {
            ZStack {
                Circle().fill(.black.opacity(0.7)).frame(width: 36, height: 36)
                Image(systemName: ambientService.isEnabled ? "lightbulb.fill" : "lightbulb")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ambientService.isEnabled ? .yellow : .white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        
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
        
        // Close video completely
        Button(action: { 
            print("❌ [VideoDetailView] Close button tapped - exiting video")
            userExplicitlyClosed = true
            // Stop playback and cleanup
            playerManager.pause()
            globalPlayer.closePlayer()
            // Dismiss the view completely
            dismiss()
        }) {
            ZStack {
                Circle().fill(.black.opacity(0.7)).frame(width: 36, height: 36)
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Close video")
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
        // 🔥 PHASE 154: Sentiment heatmap overlay on scrubber
        .overlay(alignment: .bottom) {
            if heatmapService.showHeatmap, !heatmapService.segments.isEmpty, playerManager.duration > 0 {
                GeometryReader { geo in
                    let w = geo.size.width - 40
                    HStack(spacing: 0) {
                        ForEach(heatmapService.segments) { seg in
                            let start = CGFloat(seg.startSec / playerManager.duration) * w
                            let end = CGFloat(seg.endSec / playerManager.duration) * w
                            let segW = max(2, end - start)
                            Rectangle()
                                .fill(Color.orange.opacity(seg.replayIntensity * 0.6))
                                .frame(width: segW, height: 4)
                                .offset(x: start)
                        }
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 20)
                .allowsHitTesting(false)
            }
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
            Button(action: { showingPlaybackSpeedSelector = true }) {
                Text(playbackRate == 1.0 ? "1x" : String(format: "%.2gx", playbackRate))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(playbackRate != 1.0 ? AppTheme.Colors.primary : .white)
            }
            .buttonStyle(ScaleButtonStyle())
            
            // 🔥 YOUTUBE PARITY: Loop toggle
            Button(action: {
                isLooping.toggle()
                HapticManager.shared.impact(style: .light)
                print("🔁 [YouTube] Loop \(isLooping ? "ON" : "OFF")")
            }) {
                Image(systemName: "repeat")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(isLooping ? AppTheme.Colors.primary : .white)
            }
            .buttonStyle(ScaleButtonStyle())
            
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
    
    // MARK: - YouTube-Style End Screen Overlay
    @ViewBuilder
    private func endScreenOverlay(next: Video) -> some View {
        ZStack {
            // Dark overlay background
            Rectangle()
                .fill(Color.black.opacity(0.85))
            
            VStack(spacing: 0) {
                // Countdown text at top
                Text("Up next in \(upNextCountdown)s")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                
                // Video preview card
                HStack(spacing: 12) {
                    // Thumbnail with duration badge
                    ZStack(alignment: .bottomTrailing) {
                        AsyncImage(url: URL(string: next.thumbnailURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(16/9, contentMode: .fill)
                            case .failure:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.white.opacity(0.5))
                                    )
                            case .empty:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(ProgressView().tint(.white))
                            @unknown default:
                                Rectangle().fill(Color.gray.opacity(0.3))
                            }
                        }
                        .frame(width: 160, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        // Duration badge
                        if next.duration > 0 {
                            Text(formatTime(TimeInterval(next.duration)))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .padding(4)
                        }
                    }
                    
                    // Video info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(next.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Text(next.creator.displayName)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Action buttons - YouTube style
                HStack(spacing: 16) {
                    // Cancel button
                    Button {
                        HapticManager.shared.impact(style: .light)
                        cancelEndscreen()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)
                    
                    // Play now button with countdown ring
                    Button {
                        HapticManager.shared.impact(style: .medium)
                        playNext(next)
                    } label: {
                        HStack(spacing: 8) {
                            // Circular countdown indicator
                            ZStack {
                                Circle()
                                    .stroke(Color.black.opacity(0.2), lineWidth: 2)
                                    .frame(width: 20, height: 20)
                                
                                Circle()
                                    .trim(from: 0, to: CGFloat(upNextCountdown) / 5.0)
                                    .stroke(Color.black, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                    .frame(width: 20, height: 20)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.linear(duration: 1), value: upNextCountdown)
                                
                                Image(systemName: "play.fill")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            
                            Text("Play now")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 40) // Increased bottom padding to avoid controls overlap
            }
        }
        .frame(height: UIScreen.main.bounds.width * 9.0 / 16.0)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95)),
            removal: .opacity
        ))
        .zIndex(300) // Increased z-index to be above controls (200)
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
                            userExplicitlyClosed = true
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
                    userExplicitlyClosed = true
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
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 🔥 iOS STATUS BAR: Reserve space for status bar with black background
                Color.black
                    .frame(height: geometry.safeAreaInsets.top)
                
                // ALL-IN-ONE Video Player with YouTube-style controls
                videoPlayerSection

                // Video metadata and controls (with Up Next autoplay)
                VideoDetailMetaView(video: video,
                                    isSubscribed: $isSubscribed,
                                    isWatchLater: $isWatchLater,
                                    isLiked: $isLiked,
                                    isDisliked: $isDisliked,
                                    expandedDescription: $expandedDescription,
                                    onShare: {
                                        let av = UIActivityViewController(activityItems: [shareURLWithTimestamp()], applicationActivities: nil)
                                        UIApplication.shared.presentShareSheet(av)
                                    },
                                    onMore: { showingMoreOptions = true },
                                    onComment: { showingCommentComposer = true },
                                    onChapters: {
                                        // Only present if either chapters exist on model or can be parsed from description
                                        if (video.chapters?.isEmpty == false) || !video.parsedChaptersFromDescription.isEmpty {
                                            showingChapters = true
                                        }
                                    },
                                    onProfileTap: {
                                        selectedCreatorProfile = video.creator
                                        showingCreatorProfile = true
                                    },
                                    onChannelTap: { channelName in handleChannelTap(channelName) },
                                    onHashtagTap: { hashtag in handleHashtagTap(hashtag) },
                                    dynamicViewCount: currentViewCount) // 🔥 REAL-TIME: Pass reactive view count
                .overlay(alignment: .bottom) {
                    // Simple Up Next bar with autoplay toggle
                    if let next = recommendedVideos.first(where: { $0.id != video.id }) {
                        VideoDetailUpNextBar(
                            sourceVideo: video,
                            next: next,
                            autoplayEnabled: $autoplayEnabled,
                            onTap: { playNext(next) },
                            onImpression: { trackRecommendationImpression(next) }
                        )
                    }
                }
            }
            .background(Color.black)
            .ignoresSafeArea(edges: .top) // 🔥 Extend black background under status bar
        }
        .statusBarHidden(false) // 🔥 Ensure status bar is always visible
        // When user returns from fullscreen by dismissing, ensure state is consistent
        .sheet(isPresented: $showingCommentComposer) {
            RealTimeCommentsView(video: video)
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
                .background(
                    UIKitSheetConfigurator(
                        configuration: UIKitSheetConfiguration(
                            detents: [.medium()],
                            largestUndimmedDetentIdentifier: .medium,
                            prefersGrabberVisible: true,
                            prefersScrollingExpandsWhenScrolledToEdge: false,
                            preferredCornerRadius: 28
                        )
                    )
                )
        }
        // 🔥 FIX: Video editor sheet (YouTube-style edit interface)
        .sheet(isPresented: $showingVideoEditor) {
            PostUploadEditorView(video: video)
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
            .background(
                UIKitSheetConfigurator(
                    configuration: UIKitSheetConfiguration(
                        detents: [.medium()],
                        largestUndimmedDetentIdentifier: .medium,
                        prefersGrabberVisible: true,
                        prefersScrollingExpandsWhenScrolledToEdge: false,
                        preferredCornerRadius: 28
                    )
                )
            )
        }
        .sheet(isPresented: $showingUpNextList) {
            UpNextQueueSheet(current: video, queue: recommendedVideos) { v in
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
            .background(
                UIKitSheetConfigurator(
                    configuration: UIKitSheetConfiguration(
                        detents: [.medium()],
                        largestUndimmedDetentIdentifier: .medium,
                        prefersGrabberVisible: true,
                        prefersScrollingExpandsWhenScrolledToEdge: false,
                        preferredCornerRadius: 28
                    )
                )
            )
        }
        .sheet(isPresented: $showingPlaybackSpeedSelector) {
            PlaybackSpeedSelector(selectedSpeed: $playbackRate) { speed in
                playbackRate = speed
                playerManager.setPlaybackRate(speed)
            }
            .presentationDetents([.fraction(0.4)])
            .background(
                UIKitSheetConfigurator(
                    configuration: UIKitSheetConfiguration(
                        detents: [.medium()],
                        largestUndimmedDetentIdentifier: .medium,
                        prefersGrabberVisible: true,
                        prefersScrollingExpandsWhenScrolledToEdge: false,
                        preferredCornerRadius: 28
                    )
                )
            )
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
                showVideoControls = true
                isViewAppeared = true
                resetControlsHideTimer()
            }
        }
        .onDisappear {
            print("🎬 VideoDetailView disappearing")
            playerControlsTimer?.invalidate()
            controlsHideTimer?.invalidate()
            
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
            // 🔥 FIX: Always fetch latest view count from Firestore on appear
            print("📊 [VideoDetailView] Fetching latest view count for: \(video.id)")
            let latestCount = await RealtimeViewTracker.shared.getViewCount(for: video.id)
            print("📊 [VideoDetailView] Latest view count from Firestore: \(latestCount)")
            
            // 🔥 Load Up Next recommendations from VideoDetailRecommendationService
            let recs = await recommendationService.recommendations(
                for: video,
                userId: appState.currentUser?.id,
                limit: 20
            )

            await MainActor.run {
                currentViewCount = latestCount
                recommendedVideos = recs
            }

            recommendationService.prefetchNextPlayerItem(from: recs)

            // 🔥 PHASE 154: Load sentiment heatmap for scrubber
            try? await heatmapService.loadHeatmap(videoId: video.id)

            // 🔥 PHASE 146: Load timestamped comments
            try? await timestampedCommentsService.loadComments(videoId: video.id)

            // 🔥 PHASE 145: Detect silence regions for auto-skip
            try? await speedCurvesService.detectSilence(videoId: video.id)
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
    
    // MARK: - Helper Methods

    private func handleDurationChange(_ newDuration: Double) {
        guard newDuration > 0 else { return }
        if playerManager.selectedQuality == .auto {
            playerManager.autoSelectQuality()
        }
        let savedPosition = WatchProgressService.shared.resumePosition(videoId: video.id)
        guard savedPosition > 0 else { return }
        let fraction = savedPosition / newDuration
        if fraction > 0.02 && fraction < 0.95 {
            print("▶️ [YouTube] Resuming from \(Int(savedPosition))s / \(Int(newDuration))s")
            playerManager.seek(to: fraction)
        }
    }

    private func handleCurrentTimeChange() {
        let newTime = playerManager.currentTime
        if playerManager.duration > 0 {
            let roundedTime = Int(newTime)
            if roundedTime % 5 == 0 && roundedTime > 0 {
                let uid = AppState.shared.currentUser?.id ?? "anonymous"
                let vid = video.id
                let dur = playerManager.duration
                Task { try? await WatchProgressService.shared.saveProgress(userId: uid, videoId: vid, position: newTime, duration: dur) }
            }
            watchProgress = newTime / playerManager.duration
            if !hasWatchedThreshold && watchProgress >= 0.25 {
                hasWatchedThreshold = true
                Task { await AnalyticsService.shared.trackVideoQuartile(videoId: video.id, quartile: 1) }
            } else if watchProgress >= 0.5 {
                Task { await AnalyticsService.shared.trackVideoQuartile(videoId: video.id, quartile: 2) }
            } else if watchProgress >= 0.75 {
                Task { await AnalyticsService.shared.trackVideoQuartile(videoId: video.id, quartile: 3) }
            }
        }
        if speedCurvesService.autoSkipSilence {
            if let seg = speedCurvesService.silenceSegments.first(where: { newTime >= $0.startSec && newTime <= $0.endSec }) {
                let skipTo = seg.endSec / playerManager.duration
                playerManager.seek(to: min(1.0, skipTo))
                withAnimation { showSilenceSkipIndicator = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showSilenceSkipIndicator = false }
                }
            }
        }
        if let chapters = video.chapters, !chapters.isEmpty {
            let sorted = chapters.sorted { $0.start < $1.start }
            if let current = sorted.last(where: { $0.start <= newTime }) {
                currentChapterTitle = current.title
            }
        }
        if let cards = video.videoCards {
            for card in cards {
                if abs(newTime - card.timestamp) < 0.5 && currentVideoCard?.id != card.id {
                    currentVideoCard = card
                    showingVideoCards = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                        if currentVideoCard?.id == card.id {
                            showingVideoCards = false
                            currentVideoCard = nil
                        }
                    }
                }
            }
        }
        if !midrolls.isEmpty, !showingAd, playerManager.duration > 0 {
            let uid = AppState.shared.currentUser?.id ?? "anonymous"
            for (idx, m) in midrolls.enumerated() {
                if servedMidrollIndices.contains(idx) { continue }
                if newTime >= m.time, newTime <= m.time + 0.5, AdsFrequencyCapService.shared.canShow(userId: uid, adUnit: "mid_roll") {
                    servedMidrollIndices.insert(idx)
                    prerollURL = m.url
                    showingAd = true
                    pendingContentResume = true
                    playerManager.pause()
                    AdsFrequencyCapService.shared.recordExposure(userId: uid, adUnit: "mid_roll", placement: "video_midroll", duration: 0, skippable: true, completed: false)
                    break
                }
            }
        }
    }

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
        print("🔄 [VideoDetailView] Minimizing to native PiP")
        let wasPlaying = playerManager.isPlaying
        
        // Hand the player off to GlobalVideoPlayerManager so PiP controller has a reference
        await globalPlayer.adoptExternalPlayerManager(playerManager, video: video, showFullscreen: false)
        globalPlayer.showingFullscreen = false
        
        // Keep playback going and start native PiP
        if wasPlaying, let player = globalPlayer.player, player.rate == 0 {
            player.play()
            globalPlayer.isPlaying = true
        }
        
        // Start native iOS PiP floating window, then dismiss
        PiPPlayerManager.shared.startPiP(
            onStarted: { [weak globalPlayer] in
                globalPlayer?.showingFullscreen = false
            },
            onFailed: nil
        )
        
        // Dismiss the VideoDetailView
        dismiss()
    }

    @MainActor
    private func enforceMiniPlayerStateIfNeeded(wasPlaying: Bool, reason: String) {
        guard !globalPlayer.showingFullscreen else { return }
        resumeMiniPlayerPlaybackIfNeeded(wasPlaying: wasPlaying, reason: reason)
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
        upNextVideo = recommendedVideos.first(where: { $0.id != video.id })
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
        trackRecommendationClick(next)
        videoToPresent = next
    }

    private func handleChannelTap(_ channelName: String) {
        Task {
            let resolved = await UserLookupService.shared.resolveUser(usernameOrDisplayName: channelName, fallback: video.creator)
            await MainActor.run {
                selectedCreatorProfile = resolved ?? video.creator
                showingCreatorProfile = true
            }
        }
    }

    private func handleHashtagTap(_ hashtag: String) {
        selectedHashtag = hashtag
    }

    private func trackRecommendationImpression(_ next: Video) {
        Task {
            let index = recommendedVideos.firstIndex(of: next) ?? 0
            await recommendationService.trackImpression(
                videoId: next.id,
                sourceVideoId: video.id,
                position: index,
                userId: appState.currentUser?.id
            )
        }
    }

    private func trackRecommendationClick(_ next: Video) {
        Task {
            let index = recommendedVideos.firstIndex(of: next) ?? 0
            await recommendationService.trackClick(
                videoId: next.id,
                sourceVideoId: video.id,
                position: index,
                userId: appState.currentUser?.id
            )
        }
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