import SwiftUI
import AVKit
import Combine

extension VideoDetailView {
    // MARK: - Video Player Section (Extracted to fix compiler timeout)
    @ViewBuilder
    private var videoPlayerSection: some View {
        ZStack {
            if showingYouTubeAd, let ad = currentVideoAd {
                youtubeStyleAdPlayer(ad: ad)
            } else if isYouTube {
                youtubePlayerView
            } else if case .allowed = playbackAuthorization {
                avPlayerView
            } else {
                playbackAuthorizationOverlay
            }

            if membershipGateActive {
                membershipGateOverlay
            }
        }
        .background(
            Group {
                if ambientService.isEnabled {
                    let palette = ambientService.currentPalette
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(palette.dominant),
                                Color(palette.secondary),
                                Color(palette.accent)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .blur(radius: 60)
                        .scaleEffect(1.2)
                        .opacity(0.75 * ambientService.glowIntensity)
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: ambientService.transitionDuration),
                            value: palette.dominant
                        )
                    }
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

    @ViewBuilder
    private var playbackAuthorizationOverlay: some View {
        ZStack(alignment: .top) {
            Color.black
                .aspectRatio(16.0 / 9.0, contentMode: .fit)

            switch playbackAuthorization {
            case .checking:
                VStack(spacing: AppTheme.Spacing.md) {
                    ProgressView()
                        .tint(.white)
                    Text("Authorizing playback…")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(.white)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Authorizing playback")
            case .blocked(let message):
                VStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                    Text(message)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        Button("Retry") {
                            authorizationTask?.cancel()
                            authorizationTask = Task { await authorizeAndStartPlayback() }
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)

                        Button("Close") {
                            closeVideoDetail()
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .frame(minHeight: 44)
                    }
                }
                .padding(AppTheme.Spacing.lg)
                .accessibilityElement(children: .contain)
            case .allowed:
                EmptyView()
            }

            // Always allow exit while authorizing / blocked — player chrome isn't mounted yet.
            HStack {
                Button(action: { closeVideoDetail() }) {
                    playerCircleButtonLabel(systemName: "xmark")
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("Close video")
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }
    
    // 🔥 YOUTUBE-STYLE AD PLAYER VIEW
    @ViewBuilder
    func youtubeStyleAdPlayer(ad: VideoAd) -> some View {
        ZStack(alignment: .topLeading) {
            // Ad video player - show video only when ready
            if let player = adManager.adPlayer, adManager.isAdVideoReady {
                RawPlayerLayerView(player: player, videoGravity: .resizeAspect)
                    .aspectRatio(16/9, contentMode: .fit)
                    .onAppear {
                        // Ensure playback starts when view appears
                        if player.rate == 0 {
                            player.play()
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

            // Always allow exit during ads / ad loading.
            HStack {
                Button(action: { closeVideoDetail() }) {
                    playerCircleButtonLabel(systemName: "xmark")
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("Close video")
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .zIndex(50)

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
                        guard let url = SafePlaybackURL.external(ad.clickURL) else { return }
                        adManager.clickAd()
                        UIApplication.shared.open(url)
                    }
                )
            }
        }
    }
    
    // 🔥 SKIP AD HANDLER
    func skipCurrentAd() {
        #if DEBUG
        print("⏭️ [VideoDetailView] Requesting ad skip")
        #endif
        // GoogleIMAAdManager owns the transition callback. Starting content here
        // as well races onAdSkipped and can create two AVPlayer items.
        adManager.skipAd()
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
            Button(action: {
                userExplicitlyClosed = true
                dismiss()
            }) {
                playerCircleButtonLabel(systemName: "chevron.down", iconSize: 16)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Minimize")

            Spacer()

            Text(video.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(PlayerChrome.onSurface)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm).fill(PlayerChrome.scrimSoft))

            Spacer()

            Button(action: { closeVideoDetail() }) {
                playerCircleButtonLabel(systemName: "xmark")
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Close video")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    var activePlayer: AVPlayer? {
        activePlayerManager.player
    }
    
    @ViewBuilder
    var avPlayerView: some View {
        // 🔥 FIX: Split into sub-views to prevent stack overflow crash.
        // The original single-body getter required ~42KB of stack frame —
        // exceeding iOS's 512KB main-thread limit — causing EXC_BAD_ACCESS (code=2).
        avPlayerVideoLayer
        
        // Paid promotion badge (first 8s)
        if (video.isSponsored ?? false) && playerManager.currentTime < 8 {
            paidPromotionBadge
        }
        
        // Overlay controls (MUST be above tap area to receive taps)
        avPlayerControls
        
        // Invisible tap/drag area (disabled when controls visible so buttons work)
        videoTapArea
            .allowsHitTesting(!controlsCoordinator.showControls)

        // Ad overlay
        if showingAd, let url = prerollURL {
            adOverlay(url: url)
        }
        
        // End-screen overlay
        if showUpNext, let next = (upNextVideo ?? recommendedVideos.first(where: { $0.id != video.id })) {
            endScreenOverlay(next: next)
        }

        // Poll / Quiz overlay
        if AppConfig.Features.enableVideoPollsQuizzes, var poll = displayedPoll {
            VideoPollOverlayView(
                poll: Binding(
                    get: { displayedPoll ?? poll },
                    set: { displayedPoll = $0 }
                ),
                onVote: { optionId in
                    guard let uid = AppState.shared.currentUser?.id else { return }
                    Task { [weak pollService] in
                        try? await pollService?.vote(pollId: poll.id, optionId: optionId, uid: uid)
                    }
                },
                onDismiss: {
                    withAnimation(.easeOut(duration: 0.25)) { displayedPoll = nil }
                }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .zIndex(200)
        }

        // Shoppable product-tag chips
        if AppConfig.Features.enableShoppableVideo {
            let currentTags = (shoppableService.tagsByVideo[video.id] ?? []).filter {
                playerManager.currentTime >= $0.startSeconds && playerManager.currentTime <= $0.endSeconds
            }
            if !currentTags.isEmpty {
                VStack {
                    Spacer()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(currentTags) { tag in
                                Button {
                                    UIApplication.shared.open(tag.merchantURL)
                                    HapticManager.shared.impact(style: .light)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "bag.fill")
                                            .font(.system(size: 11))
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text(tag.title)
                                                .font(.system(size: 12, weight: .semibold))
                                                .lineLimit(1)
                                            if let price = tag.price, let currency = tag.currency {
                                                Text("\(currency) \(price)")
                                                    .font(.system(size: 10))
                                                    .opacity(0.85)
                                            }
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(Color.black.opacity(0.75)))
                                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 80)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(190)
                .allowsHitTesting(true)
            }
        }

        // Info Cards overlay (YouTube-style interactive cards)
        InfoCardsContainerView(
            manager: infoCardManager,
            onCardTap: { card in
                if let urlString = card.destination.urlString {
                    if urlString.hasPrefix("mychannel://"), let url = URL(string: urlString) {
                        UIApplication.shared.open(url)
                    } else if let url = SafePlaybackURL.external(urlString) {
                        UIApplication.shared.open(url)
                    } else if let url = URL(string: urlString),
                              url.scheme?.lowercased() == "https",
                              url.host != nil {
                        UIApplication.shared.open(url)
                    }
                }
                HapticManager.shared.impact(style: .light)
            }
        )
        .zIndex(180)

        // Loading / error overlays + seek/dubbing/status indicators
        avPlayerStatusOverlays
    }

    @ViewBuilder
    private var membershipGateOverlay: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.85)
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
                Text("Members Only")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Join this channel to watch this video.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                Button {
                    HapticManager.shared.impact(style: .medium)
                    showingMembershipSheet = true
                } label: {
                    Text("Join channel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 28)
                        .background(Capsule().fill(AppTheme.Colors.primary))
                }
                .accessibilityLabel("Join channel membership")

                Button {
                    closeVideoDetail()
                } label: {
                    Text("Close")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(minHeight: 44)
                }
                .accessibilityLabel("Close video")
            }
            .padding(24)

            Button(action: { closeVideoDetail() }) {
                playerCircleButtonLabel(systemName: "xmark")
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .accessibilityLabel("Close video")
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .transition(.opacity)
        .zIndex(400)
    }
    
    // MARK: - avPlayerView split: video layer
    /// The actual video frame + pinch-to-zoom + long-press debug HUD toggle.
    @ViewBuilder
    private var avPlayerVideoLayer: some View {
        Group {
            if let player = activePlayer {
                PiPEnabledVideoPlayer(player: player)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16.0/9.0, contentMode: .fit)
                    .background(Color.black)
                    .scaleEffect(pinchScale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                pinchScale = max(1.0, min(3.0, lastPinchScale * value))
                            }
                            .onEnded { value in
                                lastPinchScale = pinchScale
                                if pinchScale < 1.1 {
                                    withAnimation(reduceMotion ? nil : .spring()) {
                                        pinchScale = 1.0
                                        lastPinchScale = 1.0
                                    }
                                }
                            }
                    )
                    .clipped()
                    .transition(.opacity)
            } else {
                Color.black
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16.0/9.0, contentMode: .fit)
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: activePlayer == nil)
        .onLongPressGesture(minimumDuration: 0.5) {
            withAnimation(reduceMotion ? nil : .spring()) { showDebugHUD.toggle() }
        }
    }
    
    // MARK: - avPlayerView split: status overlays
    /// Loading indicator, error overlay, seek ripples, speed indicator, seek scrub
    /// overlay, dubbing banners, brightness/volume overlays, heatmap badge,
    /// silence skip, and timestamped comment bubble.
    @ViewBuilder
    private var avPlayerStatusOverlays: some View {
        avPlayerLoadingAndErrorOverlays
        avPlayerGestureIndicators
        avPlayerBrightnessVolumeOverlays
        avPlayerSmartOverlays
    }
    
    @ViewBuilder
    private var avPlayerLoadingAndErrorOverlays: some View {
        if playerManager.isLoading {
            loadingIndicator
        }
        if playerManager.hasError, let errorMsg = playerManager.errorMessage {
            errorOverlay(message: errorMsg)
        }
    }
    
    @ViewBuilder
    private var avPlayerGestureIndicators: some View {
        if showSeekRippleBackward {
            seekRippleVisual(isForward: false)
        }
        if showSeekRippleForward {
            seekRippleVisual(isForward: true)
        }
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
    }
    
    @ViewBuilder
    private var avPlayerBrightnessVolumeOverlays: some View {
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
    
    @ViewBuilder
    private var avPlayerSmartOverlays: some View {
        // AI Dubbing banner
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
        // Heatmap "Most replayed" badge
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
            .animation(reduceMotion ? nil : .easeInOut, value: playerManager.currentTime)
        }
        // Auto-skip silence indicator
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
        // Timestamped comment bubble
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
                    Text("10 seconds")
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
                    #if DEBUG
                    print("⏪ Double-tap left: Rewind 10s")
                    #endif
                } else {
                    playerManager.seekForward(10)
                    showSeekRippleForward = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        showSeekRippleForward = false
                    }
                    HapticManager.shared.impact(style: .medium)
                    #if DEBUG
                    print("⏩ Double-tap right: Forward 10s")
                    #endif
                }
            },
            onLongPressStateChanged: { isActive in
                if isActive {
                    if !isLongPressSpeedUp {
                        savedPlaybackRate = playbackRate
                        playbackRate = 2.0
                        playerManager.setPlaybackRate(2.0)
                        isLongPressSpeedUp = true
                        withAnimation(reduceMotion ? nil : .spring(response: 0.2)) {
                            showSpeedUpIndicator = true
                        }
                        HapticManager.shared.impact(style: .medium)
                        #if DEBUG
                        print("⚡ [YouTube] Long-press 2x speed activated")
                        #endif
                    }
                } else {
                    if isLongPressSpeedUp {
                        playbackRate = savedPlaybackRate
                        playerManager.setPlaybackRate(savedPlaybackRate)
                        isLongPressSpeedUp = false
                        withAnimation(reduceMotion ? nil : .spring(response: 0.2)) {
                            showSpeedUpIndicator = false
                        }
                        HapticManager.shared.impact(style: .light)
                        #if DEBUG
                        print("⚡ [YouTube] Long-press released — back to \(savedPlaybackRate)x")
                        #endif
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
                    #if DEBUG
                    print("⏩ [YouTube] Swipe-seek to \(Int(targetTime))s (delta: \(Int(seekDeltaSeconds))s)")
                    #endif
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
                    // 🔥 NOTE: Swipe-up (fullscreen) and swipe-down (minimize) are now
                    // handled by the fluid playerExpandGesture on the outer videoPlayerSection.
                    // No duplicate action needed here.
                }

                isHorizontalSeeking = false
                seekDeltaSeconds = 0
                controlsCoordinator.endSeekOverlay()
            }
        )
        .zIndex(1)
    }
    func handlePlayerTap() {
        #if DEBUG
        print("📱 Video tapped - Current controls state: \(controlsCoordinator.showControls)")
        #endif
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
    
    /// Shared label for the small circular chrome buttons (chevron, gear, close).
    /// Centralizes the fixed white-on-black player look via PlayerChrome tokens.
    @ViewBuilder
    func playerCircleButtonLabel(systemName: String, iconSize: CGFloat = 14, weight: Font.Weight = .semibold) -> some View {
        ZStack {
            Circle()
                .fill(PlayerChrome.controlBackground)
                .frame(width: PlayerChrome.controlButtonSize, height: PlayerChrome.controlButtonSize)
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: weight))
                .foregroundColor(PlayerChrome.onSurface)
        }
    }

    @ViewBuilder
    var topControlBar: some View {
        HStack {
            // 🔥 YOUTUBE PARITY: Chevron down to minimize to PiP (not close!)
            // This allows users to continue watching while navigating the app
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                guard effectivePlaybackSession?.capabilities.supportsPictureInPicture == true else {
                    Task { await minimizeToMiniPlayer() }
                    return
                }
                PiPPlayerManager.shared.startPiP(
                    onStarted: { dismiss() },
                    onFailed: { Task { await minimizeToMiniPlayer() } }
                )
            }) {
                playerCircleButtonLabel(systemName: "chevron.down", iconSize: 16)
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
            .background(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm).fill(PlayerChrome.scrimSoft))
            
            Spacer()
            
            topControlButtons
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .background(PlayerChrome.topGradient)
        .opacity(controlsCoordinator.showControls ? 1.0 : 0.0)
    }
    
    // 🔥 YOUTUBE PARITY: Slim top bar — AirPlay, a single settings gear (consolidates
    // quality / captions / chapters / speed / loop / ambient / audio / theater / stats),
    // and a close button. Fullscreen now lives at the bottom-right like YouTube.
    @ViewBuilder
    var topControlButtons: some View {
        HStack(spacing: 10) {
            if effectivePlaybackSession?.capabilities.supportsCasting == true {
                AirPlayRoutePickerView()
                    .frame(width: PlayerChrome.controlButtonSize, height: PlayerChrome.controlButtonSize)
                    .background(Circle().fill(PlayerChrome.controlBackground))
                    .accessibilityLabel("Cast or AirPlay")
            }

            // Consolidated settings menu (YouTube's gear)
            playerSettingsMenu

            // Close video completely
            Button(action: {
                #if DEBUG
                print("❌ [VideoDetailView] Close button tapped - exiting video")
                #endif
                closeVideoDetail()
            }) {
                playerCircleButtonLabel(systemName: "xmark")
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Close video")
        }
    }

    // 🔥 YOUTUBE PARITY: Single gear that opens a real settings sheet (PlayerSettingsSheet),
    // housing every secondary control — quality, speed, captions, chapters, audio, loop,
    // ambient, theater and stats — exactly like YouTube's settings panel.
    @ViewBuilder
    var playerSettingsMenu: some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            showingPlayerSettings = true
        }) {
            playerCircleButtonLabel(systemName: "gearshape.fill")
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Player settings")
    }
    
    @ViewBuilder
    var centerControls: some View {
        HStack(spacing: 24) {
            Button(action: { 
                #if DEBUG
                print("⏪ [VideoDetailView] Rewind button tapped")
                #endif
                playerManager.seekBackward(10)
                HapticManager.shared.impact(style: .light)
            }) {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(PlayerChrome.onSurface)
            }
            .frame(width: 60, height: 60)  // 🔥 FIX: Larger tap target
            .contentShape(Rectangle())  // 🔥 FIX: Explicit content shape
            .buttonStyle(.plain)  // 🔥 FIX: Plain button style to prevent interference
            .accessibilityLabel("Seek backward 10 seconds")
            .accessibilityAddTraits(.isButton)
            
            Button(action: { 
                #if DEBUG
                print("▶️ [VideoDetailView] Play/Pause button tapped - Current state: \(playerManager.isPlaying)")
                #endif
                playerManager.togglePlayPause()
                HapticManager.shared.impact(style: .medium)
                
                // 🔥 FIX: Keep controls visible when play/pause is tapped
                controlsCoordinator.showControlsAndResetTimer()
            }) {
                Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundColor(PlayerChrome.onSurface)
            }
            .frame(width: 80, height: 80)  // 🔥 FIX: Larger tap target
            .contentShape(Rectangle())  // 🔥 FIX: Explicit content shape
            .buttonStyle(.plain)  // 🔥 FIX: Plain button style to prevent interference
            .accessibilityLabel(playerManager.isPlaying ? "Pause" : "Play")
            .accessibilityAddTraits(.isButton)
            
            Button(action: { 
                #if DEBUG
                print("⏩ [VideoDetailView] Forward button tapped")
                #endif
                playerManager.seekForward(10)
                HapticManager.shared.impact(style: .light)
            }) {
                Image(systemName: "goforward.10")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(PlayerChrome.onSurface)
            }
            .frame(width: 60, height: 60)  // 🔥 FIX: Larger tap target
            .contentShape(Rectangle())  // 🔥 FIX: Explicit content shape
            .buttonStyle(.plain)  // 🔥 FIX: Plain button style to prevent interference
            .accessibilityLabel("Seek forward 10 seconds")
            .accessibilityAddTraits(.isButton)
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
        .background(PlayerChrome.bottomGradient)
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
            },
            accessibilityValueText: "\(formatTime(isScrubbing ? playerManager.duration * scrubFraction : playerManager.currentTime)) of \(formatTime(playerManager.duration))"
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
            Text(formatTime(playerManager.currentTime)).foregroundColor(PlayerChrome.onSurface).font(.caption.monospacedDigit())
            Spacer()
            quickControls
            Text(formatTime(playerManager.duration)).foregroundColor(PlayerChrome.onSurface).font(.caption.monospacedDigit())

            // 🔥 YOUTUBE PARITY: Fullscreen toggle lives at the bottom-right, next to duration
            Button(action: { presentFullscreenPlayer() }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(PlayerChrome.onSurface)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Fullscreen")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    var quickControls: some View {
        HStack(spacing: 14) {
            // Quick speed toggle (full picker still available in settings gear)
            Button(action: { showingPlaybackSpeedSelector = true }) {
                Text(playbackRate == 1.0 ? "1x" : String(format: "%.2gx", playbackRate))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(playbackRate != 1.0 ? PlayerChrome.accent : PlayerChrome.onSurface)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Playback speed, \(playbackRate == 1.0 ? "1" : String(format: "%.2g", playbackRate)) times")
            .accessibilityHint("Opens playback speed options")

            // 🔥 YOUTUBE PARITY: Queue button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showingQueueSidebar.toggle()
                }
            }) {
                Image(systemName: "list.bullet")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(showingQueueSidebar ? PlayerChrome.accent : PlayerChrome.onSurface)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Up next queue")
            .accessibilityAddTraits(showingQueueSidebar ? [.isButton, .isSelected] : .isButton)
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
        ZStack(alignment: .topTrailing) {
            // Dark overlay background
            Rectangle()
                .fill(Color.black.opacity(0.85))

            VStack(spacing: 0) {
                // Countdown text at top
                Text("Up next in \(upNextCountdown)s")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Video preview card - compact
                HStack(spacing: 10) {
                    // Thumbnail with duration badge - smaller
                    ZStack(alignment: .bottomTrailing) {
                        CachedAsyncImage(url: URL(string: next.thumbnailURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.white.opacity(0.5))
                                        .font(.system(size: 20))
                                )
                        }
                        .frame(width: 120, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        // Duration badge - minimal
                        if next.duration > 0 {
                            Text(formatTime(TimeInterval(next.duration)))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(2)
                                .padding(3)
                        }
                    }

                    // Video info - compact
                    VStack(alignment: .leading, spacing: 3) {
                        Text(next.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(next.creator.displayName)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)

                Spacer()

                // Action buttons - compact YouTube style
                HStack(spacing: 12) {
                    // Cancel endscreen (stay on this video)
                    Button {
                        HapticManager.shared.impact(style: .light)
                        cancelEndscreen()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)

                    // Close the detail player entirely
                    Button {
                        HapticManager.shared.impact(style: .medium)
                        closeVideoDetail()
                    } label: {
                        Text("Close")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close video")

                    // Play now button with countdown ring
                    Button {
                        HapticManager.shared.impact(style: .medium)
                        playNext(next)
                    } label: {
                        HStack(spacing: 6) {
                            // Circular countdown indicator
                            ZStack {
                                Circle()
                                    .stroke(Color.black.opacity(0.2), lineWidth: 2)
                                    .frame(width: 18, height: 18)

                                Circle()
                                    .trim(from: 0, to: CGFloat(upNextCountdown) / 5.0)
                                    .stroke(Color.black, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                    .frame(width: 18, height: 18)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.linear(duration: 1), value: upNextCountdown)

                                Image(systemName: "play.fill")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.black)
                            }

                            Text("Play now")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 32)
            }

            Button(action: { closeVideoDetail() }) {
                playerCircleButtonLabel(systemName: "xmark")
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .accessibilityLabel("Close video")
        }
        .aspectRatio(16.0/9.0, contentMode: .fit)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95)),
            removal: .opacity
        ))
        .zIndex(300)
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
                        authorizationTask?.cancel()
                        authorizationTask = Task { await authorizeAndStartPlayback() }
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
                            closeVideoDetail()
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
                    closeVideoDetail()
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

    // MARK: - Fluid Slide-to-Fullscreen Gesture (YouTube parity)
    // Drag UP on the player → it expands toward fullscreen with a live elastic feel.
    // Drag DOWN → elastic resistance, release → snaps back (or past threshold → mini/PiP).
    private func playerExpandGesture(playerHeight: CGFloat, screenHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                // Only activate on primarily-vertical movement; horizontal is handled by seek gesture
                let isVertical = abs(value.translation.height) > abs(value.translation.width)
                guard isVertical else { return }

                // Don't compete with the horizontal seek overlay or brightness/volume overlays
                guard !isHorizontalSeeking,
                      !controlsCoordinator.showBrightnessOverlay,
                      !controlsCoordinator.showVolumeOverlay else { return }

                isExpandingPlayer = true
                let raw = value.translation.height  // negative = dragging up

                if raw < 0 {
                    // Dragging UP toward fullscreen — elastic resistance so it feels springy
                    let resistance: CGFloat = 0.55
                    playerExpandOffset = raw * resistance
                } else {
                    // Dragging DOWN — slight elastic resist (minimize territory)
                    let resistance: CGFloat = 0.3
                    playerExpandOffset = raw * resistance
                }
            }
            .onEnded { value in
                guard isExpandingPlayer else { return }
                isExpandingPlayer = false
                let velocity = value.predictedEndTranslation.height - value.translation.height

                // Threshold: 80pt upward OR fast upward flick velocity
                let shouldExpand = value.translation.height < -80 || velocity < -200

                // Threshold: 60pt downward → minimize (existing behavior kept)
                let shouldMinimize = value.translation.height > 60

                if shouldExpand {
                    // Snap to fullscreen with a snappy spring before presenting
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                        playerExpandOffset = -(screenHeight - playerHeight) / 2
                    }
                    HapticManager.shared.impact(style: .medium)
                    // Small delay so the spring has time to register before the cover appears
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 80_000_000)
                        playerExpandOffset = 0
                        isExpandingPlayer = false
                        presentFullscreenPlayer()
                    }
                } else if shouldMinimize {
                    // Animate the player sliding DOWN off screen, then hand off to mini player.
                    // The whole VStack also needs to slide — drive via the view offset below.
                    HapticManager.shared.impact(style: .medium)
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        // Push the player down toward bottom of screen
                        playerExpandOffset = screenHeight * 0.6
                    }
                    Task { @MainActor in
                        // Brief pause so the animation is visible (≈ 200ms)
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        // Reset offset before we dismiss (the view is going away anyway)
                        playerExpandOffset = 0
                        isExpandingPlayer = false
                        await minimizeToMiniPlayer()
                    }
                } else {
                    // Snap back to inline
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                        playerExpandOffset = 0
                    }
                }
            }
    }

    // How far (0…1) the player is into its expansion toward fullscreen
    private func expandProgress(playerHeight: CGFloat, screenHeight: CGFloat) -> CGFloat {
        guard playerHeight > 0, screenHeight > playerHeight else { return 0 }
        let maxTravel = (screenHeight - playerHeight) / 2
        return min(1, max(0, -playerExpandOffset / maxTravel))
    }

    var mainContent: some View {
        GeometryReader { geometry in
            let screenH = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
            // Estimated player height based on 16:9 ratio of the screen width
            let playerH = geometry.size.width / (16.0 / 9.0)
            let progress = expandProgress(playerHeight: playerH, screenHeight: screenH)

            VStack(spacing: 0) {
                // 🔥 iOS STATUS BAR: Reserve space for status bar with black background
                Color.black
                    .frame(height: geometry.safeAreaInsets.top)

                // ALL-IN-ONE Video Player with YouTube-style controls
                // 🔥 YOUTUBE PARITY: Fluid slide-to-fullscreen gesture lives here.
                // As the user drags up the player scales/translates toward filling the screen.
                videoPlayerSection
                    .offset(y: playerExpandOffset)
                    // Corner radius collapses from 12→0 as it nears fullscreen
                    .clipShape(RoundedRectangle(cornerRadius: 12 * (1 - progress), style: .continuous))
                    // Subtle scale-up so the video visually "grows" toward fullscreen
                    .scaleEffect(1.0 + progress * 0.05)
                    // Darken the rest of the screen as player expands
                    .shadow(color: .black.opacity(progress * 0.4), radius: 20)
                    .gesture(playerExpandGesture(playerHeight: playerH, screenHeight: screenH))
                    .zIndex(isExpandingPlayer ? 10 : 0)

                // Video metadata and controls
                VideoDetailMetaView(video: video,
                                    supportsOfflineDownload: effectivePlaybackSession?.capabilities.supportsOfflineDownload == true,
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
                                    dynamicViewCount: currentViewCount,
                                    relatedVideos: recommendedVideos,
                                    onSelectRelated: { next in
                                        trackRecommendationClick(next)
                                        playNext(next)
                                    },
                                    onShowTranscript: { showingTranscript = true })

                // 🔥 UP NEXT BAR — pinned at bottom of screen (outside scroll), YouTube parity
                if let next = recommendedVideos.first(where: { $0.id != video.id }) {
                    VideoDetailUpNextBar(
                        sourceVideo: video,
                        next: next,
                        autoplayEnabled: $autoplayEnabled,
                        onTap: {
                            HapticManager.shared.impact(style: .medium)
                            playNext(next)
                        },
                        onDismiss: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                // Remove the first recommendation so the bar hides.
                                // The bar re-appears if recommendations reload.
                                if let idx = recommendedVideos.firstIndex(where: { $0.id == next.id }) {
                                    recommendedVideos.remove(at: idx)
                                }
                            }
                        },
                        onImpression: { trackRecommendationImpression(next) }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.38, dampingFraction: 0.88), value: recommendedVideos.count)
                }
            }
            // 🔥 YOUTUBE PARITY: Scrim darkens behind the player as it expands toward fullscreen
            .overlay {
                if isExpandingPlayer && progress > 0 {
                    Color.black
                        .opacity(progress * 0.55)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .animation(.linear(duration: 0.05), value: progress)
                }
            }
            // 🔥 YOUTUBE PARITY: When sliding DOWN to mini player, the whole view
            // translates and fades together — not just the player strip.
            // playerExpandOffset > 0 means downward drag (minimize direction).
            .offset(y: playerExpandOffset > 0 ? playerExpandOffset * 0.45 : 0)
            .opacity(playerExpandOffset > 0 ? max(0.5, 1 - playerExpandOffset / (screenH * 0.5)) : 1)
            .background(Color.black)
            .ignoresSafeArea(edges: .top) // 🔥 Extend black background under status bar
        }
    }
    
    var primaryOverlays: some View {
        mainContent
            .statusBarHidden(false) // 🔥 Ensure status bar is always visible
            // 🔥 YOUTUBE PARITY: Whole-screen drag-down-to-minimize gesture.
            // YouTube lets you start the dismiss swipe from anywhere on the screen,
            // not just the player strip.  We use simultaneousGesture so the ScrollView
            // inside VideoDetailMetaView can still scroll — this only triggers on
            // clear downward drags that begin near the top half of the screen.
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        // Only fire on dominant downward movement and no other gesture active
                        let isDownward = value.translation.height > 0
                        let isDominantlyVertical = abs(value.translation.height) > abs(value.translation.width) * 1.5
                        guard isDownward, isDominantlyVertical,
                              !isHorizontalSeeking,
                              !controlsCoordinator.showBrightnessOverlay,
                              !controlsCoordinator.showVolumeOverlay,
                              // Don't re-drive if the player gesture already took it
                              playerExpandOffset <= 0 else { return }

                        isExpandingPlayer = true
                        // Gentle resistance — the view should feel tethered, not 1:1
                        playerExpandOffset = value.translation.height * 0.38
                    }
                    .onEnded { value in
                        guard isExpandingPlayer, playerExpandOffset > 0 else { return }
                        let dy = value.translation.height
                        let vy = value.predictedEndTranslation.height - dy
                        let shouldMinimize = dy > 80 || vy > 280

                        if shouldMinimize {
                            HapticManager.shared.impact(style: .medium)
                            // Animate the whole view down before dismissing
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                                playerExpandOffset = UIScreen.main.bounds.height * 0.55
                            }
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 200_000_000)
                                playerExpandOffset = 0
                                isExpandingPlayer = false
                                await minimizeToMiniPlayer()
                            }
                        } else {
                            isExpandingPlayer = false
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                playerExpandOffset = 0
                            }
                        }
                    }
            )
        .sheet(isPresented: $showingCommentComposer) {
            RealTimeCommentsView(video: video, currentPlaybackTime: playerManager.currentTime)
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
            // 🔥 YOUTUBE PARITY: Settings gear → full settings sheet
            .sheet(isPresented: $showingPlayerSettings) {
                PlayerSettingsSheet(
                    qualityLabel: videoQuality.displayName,
                    speedLabel: playbackRate == 1.0 ? "Normal" : String(format: "%.2gx", playbackRate),
                    audioLabel: currentAudioTrack,
                    captionsAvailable: effectivePlaybackSession?.capabilities.supportsCaptions == true &&
                        !activePlayerManager.availableSubtitleOptions().isEmpty,
                    chaptersAvailable: (video.chapters?.isEmpty == false) || !video.parsedChaptersFromDescription.isEmpty,
                    isLooping: $isLooping,
                    isAmbient: Binding(
                        get: { ambientService.isEnabled },
                        set: { newValue in
                            if newValue != ambientService.isEnabled {
                                ambientService.toggle()
                                showAmbientGlow = ambientService.isEnabled
                                if ambientService.isEnabled, let player = activePlayerManager.player {
                                    ambientService.startLiveExtraction(for: player)
                                }
                            }
                        }
                    ),
                    isTheater: $isTheaterMode,
                    showStats: $showDebugHUD,
                    onQuality: { showingQualitySelector = true },
                    onSpeed: { showingPlaybackSpeedSelector = true },
                    onCaptions: {
                        guard effectivePlaybackSession?.capabilities.supportsCaptions == true else { return }
                        showingSubtitlePicker = true
                    },
                    onChapters: {
                        if (video.chapters?.isEmpty == false) || !video.parsedChaptersFromDescription.isEmpty {
                            showingChapters = true
                        }
                    },
                    onAudio: { showingAudioTrackSelector = true }
                )
            }
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
