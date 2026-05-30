import SwiftUI
import AVKit
import Combine

extension VideoDetailView {
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
            // 🔥 BEAST MODE: True Cinematic Ambient Mode (Blurred Video Mirror)
            Group {
                if ambientService.isEnabled {
                    ZStack {
                        if isYouTube {
                            youtubePlayerView
                        } else {
                            if let player = activePlayer {
                                PiPEnabledVideoPlayer(player: player)
                            }
                        }
                    }
                    .aspectRatio(16.0/9.0, contentMode: .fill)
                    .blur(radius: 80, opaque: true)
                    .scaleEffect(1.2)
                    .opacity(0.65)
                    .animation(.easeInOut(duration: 1.0), value: ambientService.isEnabled)
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
    func youtubeStyleAdPlayer(ad: VideoAd) -> some View {
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
    func skipCurrentAd() {
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
    var youtubePlayerView: some View {
        YouTubePlayerView(
            videoID: video.externalID ?? "",
            autoplay: true,
            startTime: 0,
            muted: false,
            showControls: true
        )
        .frame(maxWidth: .infinity)
        .aspectRatio(16.0/9.0, contentMode: .fit)
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
    var activePlayer: AVPlayer? {
        let globalPlayer = GlobalVideoPlayerManager.shared
        if globalPlayer.currentVideo?.id == video.id, let globalPlayerInstance = globalPlayer.player {
            return globalPlayerInstance  // Use global player if same video (from mini player)
        }
        return playerManager.player  // Otherwise use local player
    }
    
    @ViewBuilder
    var avPlayerView: some View {
        Group {
            if let player = activePlayer {
                // 🔥 FIX: Use PiPEnabledVideoPlayer to allow manual PiP activation
                PiPEnabledVideoPlayer(player: player)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16.0/9.0, contentMode: .fit)
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
                    .aspectRatio(16.0/9.0, contentMode: .fit)
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
            .allowsHitTesting(!controlsCoordinator.showControls)  // 🔥 FIX: Disable tap area when controls visible
        
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
        
        // 🔥 YOUTUBE PARITY: Double-tap seek visual feedback
        if showSeekRippleBackward {
            seekRippleVisual(isForward: false)
        }
        if showSeekRippleForward {
            seekRippleVisual(isForward: true)
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
        if controlsCoordinator.showSeekOverlay {
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
        
        // 🔥 BEAST MODE: AI Synthesized Dubbing Banner
        if currentAudioTrack != "English (Original)" && !isDubSynthesizing {
            HStack(spacing: 6) {
                Image(systemName: "waveform.circle.fill")
                    .foregroundColor(.green)
                Text("\(currentAudioTrack) • AI Dubbed")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.black.opacity(0.7)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 60)
            .padding(.trailing, 20)
            .zIndex(340)
            .allowsHitTesting(false)
            .transition(.scale.combined(with: .opacity))
        }
        
        if isDubSynthesizing {
            HStack(spacing: 8) {
                ProgressView().tint(.green).scaleEffect(0.8)
                Text("Synthesizing \(currentAudioTrack)...")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.black.opacity(0.7)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 60)
            .padding(.trailing, 20)
            .zIndex(340)
            .allowsHitTesting(false)
            .transition(.scale.combined(with: .opacity))
        }
        
        // 🔥 YOUTUBE PARITY: Brightness overlay (left side vertical swipe)
        if controlsCoordinator.showBrightnessOverlay {
            HStack(spacing: 12) {
                Image(systemName: UIScreen.main.brightness > 0.5 ? "sun.max.fill" : "sun.min.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: Double(UIScreen.main.brightness), total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        .frame(width: 120)
                    Text("\(Int(UIScreen.main.brightness * 100))%")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Capsule().fill(Color.black.opacity(0.75)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.leading, 24)
            .padding(.vertical, 100)
            .zIndex(350)
            .allowsHitTesting(false)
            .transition(.scale.combined(with: .opacity))
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
        if controlsCoordinator.showVolumeOverlay {
            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 4) {
                    ProgressView(value: Double(playerManager.player?.volume ?? 0), total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        .frame(width: 120)
                    Text("\(Int((playerManager.player?.volume ?? 0) * 100))%")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Image(systemName: (playerManager.player?.volume ?? 0) > 0.5 ? "speaker.wave.3.fill" : "speaker.wave.1.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 24)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Capsule().fill(Color.black.opacity(0.75)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(.trailing, 24)
            .padding(.vertical, 100)
            .zIndex(350)
            .allowsHitTesting(false)
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    // 🔥 YOUTUBE PARITY: Ripple visual effect for double tap to seek
    @ViewBuilder
    func seekRippleVisual(isForward: Bool) -> some View {
        HStack {
            if isForward { Spacer() }
            
            ZStack {
                // Semi-circle background
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 300, height: 300)
                    .offset(x: isForward ? 150 : -150)
                
                // Text and arrows
                VStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: isForward ? "play.fill" : "backward.fill")
                        Image(systemName: isForward ? "play.fill" : "backward.fill")
                        Image(systemName: isForward ? "play.fill" : "backward.fill")
                    }
                    .font(.system(size: 14))
                    Text(isForward ? "10 seconds" : "10 seconds")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .offset(x: isForward ? 40 : -40)
            }
            .frame(width: UIScreen.main.bounds.width / 2)
            .clipped() // Clip to bounds so it's a semi-circle
            
            if !isForward { Spacer() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .transition(.opacity)
        .zIndex(340)
    }
    
    @ViewBuilder
    var paidPromotionBadge: some View {
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
    var videoTapArea: some View {
        PlayerTapCaptureView(
            onSingleTap: { handlePlayerTap() },
            onDoubleTap: { location, size in
                let isLeft = location.x < size.width / 2
                if isLeft {
                    playerManager.seekBackward(10)
                    showSeekRippleBackward = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        showSeekRippleBackward = false
                    }
                    HapticManager.shared.impact(style: .medium)
                    print("⏪ Double-tap left: Rewind 10s")
                } else {
                    playerManager.seekForward(10)
                    showSeekRippleForward = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        showSeekRippleForward = false
                    }
                    HapticManager.shared.impact(style: .medium)
                    print("⏩ Double-tap right: Forward 10s")
                }
            },
            onLongPressStateChanged: { isActive in
                if isActive {
                    if !isLongPressSpeedUp {
                        savedPlaybackRate = playbackRate
                        playbackRate = 2.0
                        playerManager.setPlaybackRate(2.0)
                        isLongPressSpeedUp = true
                        withAnimation(.spring(response: 0.2)) { showSpeedUpIndicator = true }
                        HapticManager.shared.impact(style: .medium)
                        print("⚡ [YouTube] Long-press 2x speed activated")
                    }
                } else {
                    if isLongPressSpeedUp {
                        playbackRate = savedPlaybackRate
                        playerManager.setPlaybackRate(savedPlaybackRate)
                        isLongPressSpeedUp = false
                        withAnimation(.spring(response: 0.2)) { showSpeedUpIndicator = false }
                        HapticManager.shared.impact(style: .light)
                        print("⚡ [YouTube] Long-press released — back to \(savedPlaybackRate)x")
                    }
                }
            },
            onPanChanged: { startLocation, translation, location, size in
                let screenWidth = size.width
                let playerHeight = max(size.height, 1)
                let startX = startLocation.x
                let dx = translation.x
                let dy = translation.y

                if !isHorizontalSeeking && !controlsCoordinator.showBrightnessOverlay && !controlsCoordinator.showVolumeOverlay {
                    if abs(dx) > abs(dy) && abs(dx) > 20 {
                        isHorizontalSeeking = true
                        seekStartTime = playerManager.currentTime
                        seekDeltaSeconds = 0
                    } else if abs(dy) > abs(dx) && abs(dy) > 20 {
                        let isLeftSide = startX < screenWidth * 0.5
                        if isLeftSide {
                            controlsCoordinator.beginBrightnessOverlay()
                            currentBrightness = UIScreen.main.brightness
                        } else {
                            controlsCoordinator.beginVolumeOverlay()
                            currentVolume = playerManager.player?.volume ?? currentVolume
                        }
                        verticalSwipeStartY = startLocation.y
                    }
                }

                if isHorizontalSeeking {
                    let seekScale = min(playerManager.duration, 60.0) / max(screenWidth, 1)
                    seekDeltaSeconds = Double(dx) * seekScale
                    controlsCoordinator.beginSeekOverlay()
                }

                if controlsCoordinator.showBrightnessOverlay {
                    let deltaY = verticalSwipeStartY - location.y
                    let brightnessChange = deltaY / playerHeight * 0.7
                    let newBrightness = max(0, min(1, currentBrightness + brightnessChange))
                    UIScreen.main.brightness = newBrightness
                    emitSteppedFeedbackIfNeeded(for: newBrightness, lastStep: &lastBrightnessFeedbackStep)
                    pauseControlsAutoHideForTransientOverlay()
                }

                if controlsCoordinator.showVolumeOverlay {
                    let deltaY = verticalSwipeStartY - location.y
                    let volumeChange = Float(deltaY / playerHeight) * 0.7
                    let newVolume = max(0, min(1, currentVolume + volumeChange))
                    playerManager.player?.volume = newVolume
                    emitSteppedFeedbackIfNeeded(for: CGFloat(newVolume), lastStep: &lastVolumeFeedbackStep)
                    pauseControlsAutoHideForTransientOverlay()
                }
            },
            onPanEnded: { _, translation, _, _ in
                if isHorizontalSeeking {
                    let targetTime = max(0, min(playerManager.duration, seekStartTime + seekDeltaSeconds))
                    let progress = playerManager.duration > 0 ? targetTime / playerManager.duration : 0
                    playerManager.seek(to: progress)
                    HapticManager.shared.impact(style: .light)
                    print("⏩ [YouTube] Swipe-seek to \(Int(targetTime))s (delta: \(Int(seekDeltaSeconds))s)")
                }

                if controlsCoordinator.showBrightnessOverlay {
                    currentBrightness = UIScreen.main.brightness
                    lastBrightnessFeedbackStep = -1
                    controlsCoordinator.endBrightnessOverlay()
                }

                if controlsCoordinator.showVolumeOverlay {
                    currentVolume = playerManager.player?.volume ?? 0.5
                    lastVolumeFeedbackStep = -1
                    controlsCoordinator.endVolumeOverlay()
                }

                if !isHorizontalSeeking && !controlsCoordinator.showBrightnessOverlay && !controlsCoordinator.showVolumeOverlay {
                    if translation.y > 60 {
                        Task { await minimizeToMiniPlayer() }
                    } else if translation.y < -60 {
                        presentFullscreenPlayer()
                    }
                }

                isHorizontalSeeking = false
                seekDeltaSeconds = 0
                controlsCoordinator.endSeekOverlay()
            }
        )
        .zIndex(1)
    }
    func handlePlayerTap() {
        print("📱 Video tapped - Current controls state: \(controlsCoordinator.showControls)")
        controlsCoordinator.toggleControls()
    }

    
    @ViewBuilder
    var avPlayerControls: some View {
        VStack(spacing: 0) {
            topControlBar
            Spacer()
            centerControls
            bottomProgressArea
        }
        .transition(.opacity)
        .zIndex(200)  // 🔥 FIX: Much higher z-index to ensure controls are above tap area
        .allowsHitTesting(controlsCoordinator.showControls && !showUpNext)  // 🔥 FIX: Disable hit testing when end screen is showing
        .contentShape(Rectangle())  // 🔥 FIX: Ensure entire control area is tappable
        .opacity(controlsCoordinator.showControls && !showUpNext ? 1.0 : 0.0)  // 🔥 FIX: Hide controls when end screen is active
    }
    
    @ViewBuilder
    var topControlBar: some View {
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
        .opacity(controlsCoordinator.showControls ? 1.0 : 0.0)
    }
    
    @ViewBuilder
    var topControlButtons: some View {
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
        
        // 🔥 BEAST MODE: AI Multi-Language Dubbing
        Button(action: { showingAudioTrackSelector = true }) {
            ZStack {
                Circle().fill(.black.opacity(0.7)).frame(width: 36, height: 36)
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(currentAudioTrack != "English (Original)" ? .green : .white)
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
    var centerControls: some View {
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
                controlsCoordinator.showControlsAndResetTimer()
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
        .opacity(controlsCoordinator.showControls ? 1.0 : 0.0)
        .allowsHitTesting(controlsCoordinator.showControls)  // 🔥 FIX: Explicitly allow hit testing when visible
    }
    
    @ViewBuilder
    var bottomProgressArea: some View {
        VStack {
            progressSlider
            progressTimeControls
        }
        .background(LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom))
        .opacity(controlsCoordinator.showControls ? 1.0 : 0.0)
    }
    
    @ViewBuilder
    var progressSlider: some View {
        UIKitVideoScrubber(
            value: Binding(
                get: { isScrubbing ? scrubFraction : (playerManager.duration > 0 ? playerManager.currentTime / playerManager.duration : 0) },
                set: { fraction in
                    scrubFraction = max(0, min(1, fraction))
                }
            ),
            tintColor: .white,
            minimumTrackColor: .white,
            maximumTrackColor: UIColor.white.withAlphaComponent(0.35),
            onEditingChanged: { editing in
                isScrubbing = editing
                if editing {
                    scrubFraction = playerManager.duration > 0 ? playerManager.currentTime / playerManager.duration : 0
                } else {
                    playerManager.seek(to: scrubFraction)
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        scrubPreviewImage = nil
                    }
                }
            },
            onScrubChanged: { fraction in
                scrubFraction = max(0, min(1, fraction))
                let t = playerManager.duration * scrubFraction
                scrubPreviewImage = playerManager.thumbnail(at: t)
            }
        )
        .frame(height: 32)
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
    var chapterTicks: some View {
        if let chapters = video.chapters, !chapters.isEmpty, playerManager.duration > 0 {
            GeometryReader { geometry in
                let trackWidth = geometry.size.width - 40
                let sortedChapters = chapters.sorted(by: { $0.start < $1.start })
                ZStack(alignment: .topLeading) {
                    ForEach(sortedChapters) { chapter in
                        let p = max(0, min(1, chapter.start / playerManager.duration))
                        let x = CGFloat(p) * trackWidth

                        Rectangle()
                            .fill(Color.white.opacity(0.45))
                            .frame(width: 1, height: 8)
                            .offset(x: x)
                    }

                    if let hoveredChapter = controlsCoordinator.hoveredChapter {
                        VStack(spacing: 4) {
                            Text(hoveredChapter.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)

                            Text(formatTime(hoveredChapter.start))
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .offset(x: max(0, min(trackWidth - 120, chapterTooltipX - 60)), y: -50)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateHoveredChapterViaCoordinator(at: value.location.x, trackWidth: trackWidth, chapters: sortedChapters)
                        }
                        .onEnded { _ in
                            controlsCoordinator.clearHoveredChapter()
                        }
                )
            }
            .frame(height: 50)
            .padding(.horizontal, 28)
        }
    }
    
    @ViewBuilder
    var scrubPreview: some View {
        if isScrubbing, let img = scrubPreviewImage, playerManager.duration > 0 {
            GeometryReader { geo in
                // geo.size.width already reflects the padded track width
                let x = CGFloat(scrubFraction) * max(0, geo.size.width - 160)
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
    }
    
    @ViewBuilder
    var progressTimeControls: some View {
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
    var quickControls: some View {
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
            
            // 🔥 PHASE 124: Social Clips (Duets)
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                print("🎬 Trigger Duet Flow")
            }) {
                Image(systemName: "rectangle.split.2x1")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
            }
            .buttonStyle(ScaleButtonStyle())
            
            // 🔥 PHASE 125: Group Watch Parties
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                print("🍿 Trigger Watch Party Flow")
            }) {
                Image(systemName: "tv.badge.wifi")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
            }
            .buttonStyle(ScaleButtonStyle())
            
            AirPlayRoutePickerView()
                .frame(width: 24, height: 24)
        }
    }
    
    @ViewBuilder
    func adOverlay(url: String) -> some View {
        AdPlayerOverlay(adUrl: url) {
            withAnimation { showingAd = false }
            if pendingContentResume { playerManager.play(); pendingContentResume = false }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16.0/9.0, contentMode: .fit)
        .transition(.opacity)
        .zIndex(100)
    }
    
    // MARK: - YouTube-Style End Screen Overlay
    @ViewBuilder
    func endScreenOverlay(next: Video) -> some View {
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
        .aspectRatio(16.0/9.0, contentMode: .fit)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95)),
            removal: .opacity
        ))
        .zIndex(300) // Increased z-index to be above controls (200)
    }
    
    @ViewBuilder
    var loadingIndicator: some View {
        ZStack {
            Circle().fill(.black.opacity(0.6)).frame(width: 80, height: 80)
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(1.2)
        }
        .zIndex(100)
    }
    
    @ViewBuilder
    func errorOverlay(message: String) -> some View {
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
        .aspectRatio(16.0/9.0, contentMode: .fit)
        .transition(.opacity)
        .zIndex(200)
    }
    
    @ViewBuilder
    func debugHUDView(stats: VideoPlayerManager.PlaybackStats) -> some View {
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

    var mainContent: some View {
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
                                        showingShareSheet = true
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
                                    dynamicViewCount: currentViewCount, // 🔥 REAL-TIME: Pass reactive view count
                                    relatedVideos: recommendedVideos, // 🔥 YOUTUBE PARITY: Related videos rail
                                    onSelectRelated: { next in
                                        trackRecommendationClick(next)
                                        playNext(next)
                                    },
                                    onShowTranscript: { showingTranscript = true }) // 🔥 YOUTUBE PARITY: Open transcript sheet
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
    }
    
    var primaryOverlays: some View {
        mainContent
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
    }
    
    var secondaryOverlays: some View {
        primaryOverlays
            .sheet(isPresented: $showingShareSheet) {
            VideoShareSheet(items: [shareURLWithTimestamp()])
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
            NavigationStack {
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
    }
    
    var tertiaryOverlays: some View {
        secondaryOverlays
            .fullScreenCover(item: $videoToPresent) { next in
            VideoDetailView(video: next)
                .id(next.id) // Prevent view recreation on state changes
        }
        .confirmationDialog("Audio Track", isPresented: $showingAudioTrackSelector, titleVisibility: .visible) {
            ForEach(["English (Original)", "Spanish (AI Dub)", "French (AI Dub)", "German (AI Dub)"] as [String], id: \.self) { track in
                Button {
                    if track != currentAudioTrack {
                        isDubSynthesizing = true
                        currentAudioTrack = track
                        Task {
                            // Mocking Vertex AI synthesis delay
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            isDubSynthesizing = false
                            HapticManager.shared.successPattern()
                        }
                    }
                } label: {
                    Text(track)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Powered by Vertex AI Voice Cloning")
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
    }
    
}
