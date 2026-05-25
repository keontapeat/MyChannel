import SwiftUI
import AVKit
import AVFoundation

struct ProfessionalVideoPlayer: View {
    enum OverlayStyle { case minimal, classic }

    let video: Video
    let isCurrentVideo: Bool
    let isLiked: Bool
    let isFollowing: Bool
    let subscriberCount: Int
    let onLike: () -> Void
    let onFollow: () -> Void
    let onComment: () -> Void
    let onShare: () -> Void
    let onProfileTap: () -> Void
    var overlayStyle: OverlayStyle = .minimal

    @StateObject private var playerManager = VideoPlayerManager()
    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isPlaying = true
    @State private var isMuted = true
    @State private var showPlayIcon = false
    @State private var showHeartPulse = false
    @State private var overlayVisible = true
    @State private var showUnmuteTip = true
    @State private var timeObserverToken: Any?
    
    // 🔥 PREMIUM: Enhanced animation states
    @State private var hasAppeared = false
    @State private var likeParticles: [LikeParticle] = []
    @State private var discRotation: Double = 0
    @State private var profileRingPhase: CGFloat = 0
    @State private var actionButtonsScale: [Int: CGFloat] = [:]
    @State private var glowIntensity: Double = 0.5

    @AppStorage("flicks_playback_speed") private var playbackSpeed: Double = 1.0

    var body: some View {
        ZStack {
            if isCurrentVideo {
                FlicksPlayerLayerView(player: playerManager.player, videoGravity: .resizeAspectFill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        togglePlayPause()
                        showPlayPauseIcon()
                        revealOverlayTemporarily()
                    }
                    .onTapGesture(count: 2) {
                        if !isLiked { onLike() }
                        heartPulse()
                        spawnLikeParticles()
                        revealOverlayTemporarily()
                    }
                    .onAppear {
                        setupPlayer()
                        attachTimeObserver()
                        adoptGlobalManager()
                        scheduleOverlayAutohide()
                        triggerAppearAnimations()
                    }
                    .onDisappear { cleanupPlayback() }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                        playerManager.pause()
                        isPlaying = false
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                        if isCurrentVideo {
                            playerManager.play()
                            applyPlaybackSpeed()
                            isPlaying = true
                            scheduleOverlayAutohide()
                        }
                    }
                    .onChange(of: isCurrentVideo) { newValue in
                        if newValue {
                            playerManager.play()
                            applyPlaybackSpeed()
                            isPlaying = true
                            adoptGlobalManager()
                            scheduleOverlayAutohide()
                            triggerAppearAnimations()
                        } else {
                            playerManager.pause()
                            isPlaying = false
                        }
                    }
                    .onChange(of: playbackSpeed) { _ in
                        if isPlaying { applyPlaybackSpeed() }
                    }
            } else {
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack { Rectangle().fill(.black); ProgressView().tint(.white) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }

            if playerManager.isLoading {
                // 🔥 PREMIUM: Enhanced loading indicator
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 3)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(discRotation))
                }
            }

            if overlayStyle == .minimal { minimalOverlay.opacity(overlayVisible ? 1 : 0) } else { classicOverlay.opacity(overlayVisible ? 1 : 0) }

            // 🔥 PREMIUM: Enhanced play/pause indicator with blur backdrop
            if showPlayIcon {
                ZStack {
                    // Outer glow ring
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.15), Color.clear],
                                center: .center,
                                startRadius: 40,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                    
                    Circle()
                        .fill(.black.opacity(0.35))
                        .frame(width: 100, height: 100)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                        .offset(x: isPlaying ? 0 : 3) // Visual centering for play icon
                }
                .scaleEffect(showPlayIcon ? 1.0 : 0.6)
                .opacity(showPlayIcon ? 1.0 : 0.0)
                .animation(.spring(response: 0.32, dampingFraction: 0.7), value: showPlayIcon)
            }

            // 🔥 PREMIUM: Enhanced heart pulse with particles
            if showHeartPulse {
                ZStack {
                    // Outer glow
                    Image(systemName: "heart.fill")
                        .font(.system(size: 90))
                        .foregroundStyle(Color.red.opacity(0.4))
                        .blur(radius: 20)
                        .scaleEffect(showHeartPulse ? 1.3 : 0.5)
                    
                    // Main heart
                    Image(systemName: "heart.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hexString: "FF6B6B"), Color(hexString: "EE5A5A"), Color(hexString: "DC4444")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.red.opacity(0.5), radius: 12, x: 0, y: 4)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .scaleEffect(showHeartPulse ? 1.0 : 0.5)
                .opacity(showHeartPulse ? 1.0 : 0.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showHeartPulse)
            }
            
            // 🔥 PREMIUM: Like particle burst effect
            ForEach(likeParticles) { particle in
                Image(systemName: particle.symbol)
                    .font(.system(size: particle.size))
                    .foregroundStyle(particle.color)
                    .offset(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
                    .rotationEffect(.degrees(particle.rotation))
                    .scaleEffect(particle.scale)
            }

            if showUnmuteTip && isMuted && isCurrentVideo {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.slash.fill").font(.caption.bold())
                    Text("Tap for sound").font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                        )
                )
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                .padding(.bottom, 180)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .move(edge: .bottom))
                ))
                .onAppear {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showUnmuteTip = false }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: overlayVisible)
        .onAppear {
            startDiscRotation()
            startGlowAnimation()
        }
    }
    
    // MARK: - 🔥 Premium Animation Triggers
    
    private func triggerAppearAnimations() {
        guard !reduceMotion else {
            hasAppeared = true
            return
        }
        
        hasAppeared = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
            hasAppeared = true
        }
    }
    
    private func startDiscRotation() {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            discRotation = 360
        }
    }
    
    private func startGlowAnimation() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            glowIntensity = 0.8
        }
    }
    
    private func spawnLikeParticles() {
        guard !reduceMotion else { return }
        
        let symbols = ["heart.fill", "sparkle", "star.fill", "heart.fill", "heart.fill"]
        let colors: [Color] = [.red, .pink, .orange, .red.opacity(0.8), Color(hexString: "FF6B6B")]
        
        for i in 0..<12 {
            let angle = Double(i) * (360.0 / 12.0) + Double.random(in: -15...15)
            let radians = angle * .pi / 180
            let distance = CGFloat.random(in: 80...160)
            
            let particle = LikeParticle(
                id: UUID(),
                symbol: symbols.randomElement() ?? "heart.fill",
                color: colors.randomElement() ?? .red,
                size: CGFloat.random(in: 14...28),
                x: 0,
                y: 0,
                targetX: cos(radians) * distance,
                targetY: sin(radians) * distance,
                rotation: Double.random(in: -45...45),
                opacity: 1.0,
                scale: 0.3
            )
            
            likeParticles.append(particle)
            
            let index = likeParticles.count - 1
            
            // Animate outward
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(i) * 0.02)) {
                if index < likeParticles.count {
                    likeParticles[index].x = particle.targetX
                    likeParticles[index].y = particle.targetY
                    likeParticles[index].scale = 1.0
                    likeParticles[index].rotation = Double.random(in: -180...180)
                }
            }
            
            // Fade out
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                withAnimation(.easeOut(duration: 0.3)) {
                    if index < likeParticles.count {
                        likeParticles[index].opacity = 0
                        likeParticles[index].scale = 0.5
                        likeParticles[index].y -= 30
                    }
                }
            }
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            likeParticles.removeAll()
        }
    }

    private var minimalOverlay: some View {
        GeometryReader { proxy in
            let safeInsets = proxy.safeAreaInsets
            VStack(spacing: 0) {
                progressIndicator
                    .padding(.top, max(12, safeInsets.top + 8))
                    .padding(.horizontal, 28)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : -20)

                Spacer()

                bottomOverlay(insets: safeInsets)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var progressIndicator: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                // 🔥 PREMIUM: Enhanced progress bar with glow
                Capsule()
                    .fill(.white.opacity(0.12))
                    .frame(height: 3)
                
                // Buffer indicator with subtle gradient
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.25), .white.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, CGFloat(playerManager.bufferedProgress) * proxy.size.width), height: 3)
                
                // Progress with glow effect
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white)
                        .frame(width: max(6, CGFloat(playerManager.currentProgress) * proxy.size.width), height: 3)
                        .shadow(color: .white.opacity(0.5), radius: 4, x: 0, y: 0)
                    
                    // Progress head dot
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                        .shadow(color: .white.opacity(0.6), radius: 4)
                        .offset(x: max(0, CGFloat(playerManager.currentProgress) * proxy.size.width - 4))
                        .opacity(playerManager.currentProgress > 0.01 ? 1 : 0)
                }
            }
        }
        .frame(height: 14)
    }

    private func bottomOverlay(insets: EdgeInsets) -> some View {
        ZStack(alignment: .bottom) {
            // 🔥 PREMIUM: Enhanced gradient with more depth
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.05),
                    .black.opacity(0.2),
                    .black.opacity(0.5),
                    .black.opacity(0.75)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300 + insets.bottom)
            .allowsHitTesting(false)

            HStack(alignment: .bottom, spacing: 16) {
                detailCard
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(x: hasAppeared ? 0 : -30)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: hasAppeared)
                    .padding(.leading, max(16, insets.leading + 14))
                
                actionColumn
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(x: hasAppeared ? 0 : 30)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: hasAppeared)
                    .padding(.trailing, max(16, insets.trailing + 14))
            }
            .padding(.bottom, max(24, insets.bottom + 18))
        }
        .frame(maxWidth: .infinity)
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                // 🔥 PREMIUM: Pulsing ring profile picture
                Button(action: { 
                    onProfileTap()
                    revealOverlayTemporarily()
                    HapticManager.shared.impact(style: .light)
                }) {
                    ZStack {
                        // Animated gradient ring
                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: [
                                        AppTheme.Colors.primary,
                                        AppTheme.Colors.primary.opacity(0.6),
                                        Color.white.opacity(0.8),
                                        AppTheme.Colors.primary.opacity(0.6),
                                        AppTheme.Colors.primary
                                    ],
                                    center: .center,
                                    startAngle: .degrees(profileRingPhase),
                                    endAngle: .degrees(profileRingPhase + 360)
                                ),
                                lineWidth: 2.5
                            )
                            .frame(width: 52, height: 52)
                        
                        AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.white.opacity(0.2))
                        }
                        .frame(width: 46, height: 46)
                        .clipShape(Circle())
                    }
                    .onAppear {
                        if !reduceMotion {
                            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                                profileRingPhase = 360
                            }
                        }
                    }
                }
                .buttonStyle(PremiumScaleButtonStyle())

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text("@\(video.creator.username)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if video.creator.shouldShowVerificationBadge {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.verificationBlue, AppTheme.Colors.verificationBlue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: AppTheme.Colors.verificationBlue.opacity(0.5), radius: 4)
                        }
                    }
                    // 🔥 PREMIUM: Animated subscriber count
                    FlicksAnimatedCount(value: subscriberCount, suffix: " subscribers")
                }

                Spacer()

                // 🔥 PREMIUM: Enhanced follow button
                Button(action: { 
                    onFollow()
                    revealOverlayTemporarily()
                    HapticManager.shared.impact(style: .medium)
                }) {
                    HStack(spacing: 4) {
                        if isFollowing {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                        }
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        Group {
                            if isFollowing {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            } else {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.Colors.primary, AppTheme.Colors.primaryDark],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: AppTheme.Colors.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                        }
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(PremiumScaleButtonStyle())
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isFollowing)
            }

            // 🔥 PREMIUM: Title with better typography
            Text(video.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

            if !topTags.isEmpty {
                // 🔥 PREMIUM: Enhanced hashtags with gradient backgrounds
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(topTags.enumerated()), id: \.element) { index, tag in
                            Text("#\(tag)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.18),
                                                    Color.white.opacity(0.08)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                        )
                                )
                                .opacity(hasAppeared ? 1 : 0)
                                .offset(x: hasAppeared ? 0 : 20)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.3 + Double(index) * 0.05), value: hasAppeared)
                        }
                    }
                }
            }

            // 🔥 PREMIUM: Spinning disc audio indicator
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 22, height: 22)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                }
                .rotationEffect(.degrees(isPlaying && !isMuted ? discRotation : 0))
                
                Text("Original Audio")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("·")
                    .foregroundColor(.white.opacity(0.5))
                
                Text(video.creator.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionColumn: some View {
        VStack(spacing: 20) {
            // 🔥 PREMIUM: Like button with glow when liked
            premiumMetricButton(
                index: 0,
                systemName: isLiked ? "heart.fill" : "heart",
                value: displayedLikeCount,
                iconTint: isLiked ? .red : .white,
                showGlow: isLiked,
                glowColor: .red
            ) {
                onLike()
                spawnLikeParticles()
                HapticManager.shared.notification(type: isLiked ? .warning : .success)
                revealOverlayTemporarily()
            }

            // 🔥 PREMIUM: Comment button
            premiumMetricButton(
                index: 1,
                systemName: "bubble.right.fill",
                value: video.commentCount,
                iconTint: .white
            ) {
                onComment()
                HapticManager.shared.impact(style: .light)
                revealOverlayTemporarily()
            }

            // 🔥 PREMIUM: Share button
            premiumMetricButton(
                index: 2,
                systemName: "arrowshape.turn.up.right.fill",
                label: "Share",
                iconTint: .white
            ) {
                onShare()
                HapticManager.shared.impact(style: .light)
                revealOverlayTemporarily()
            }

            // 🔥 PREMIUM: Sound toggle with animation
            premiumMetricButton(
                index: 3,
                systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                label: isMuted ? "Sound" : "Mute",
                iconTint: isMuted ? .white.opacity(0.7) : .white,
                showGlow: !isMuted,
                glowColor: AppTheme.Colors.accent
            ) {
                toggleMute()
                HapticManager.shared.impact(style: .rigid)
                revealOverlayTemporarily()
            }

            // 🔥 PREMIUM: Spinning album art disc
            ZStack {
                // Vinyl record effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.black, Color.black.opacity(0.8), Color.black],
                            center: .center,
                            startRadius: 0,
                            endRadius: 24
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    )
                
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle().fill(Color.white.opacity(0.2))
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .fill(Color.black)
                        .frame(width: 8, height: 8)
                )
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                .white.opacity(0.6),
                                AppTheme.Colors.primary.opacity(0.8),
                                .white.opacity(0.3),
                                AppTheme.Colors.primary.opacity(0.6),
                                .white.opacity(0.6)
                            ],
                            center: .center
                        ),
                        lineWidth: 2
                    )
            )
            .rotationEffect(.degrees(isPlaying ? discRotation : 0))
            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
            .opacity(hasAppeared ? 1 : 0)
            .scaleEffect(hasAppeared ? 1 : 0.5)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5), value: hasAppeared)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
    }
    
    // 🔥 PREMIUM: Enhanced metric button with glow effects
    @ViewBuilder
    private func premiumMetricButton(
        index: Int,
        systemName: String,
        value: Int? = nil,
        label: String? = nil,
        iconTint: Color = .white,
        showGlow: Bool = false,
        glowColor: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    // Glow effect when active
                    if showGlow {
                        Circle()
                            .fill(glowColor.opacity(0.3))
                            .frame(width: 52, height: 52)
                            .blur(radius: 8)
                    }
                    
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 46, height: 46)
                        .overlay(
                            Circle()
                                .stroke(
                                    showGlow 
                                        ? glowColor.opacity(0.5)
                                        : Color.white.opacity(0.15),
                                    lineWidth: 1
                                )
                        )
                    
                    Image(systemName: systemName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(iconTint)
                        .shadow(color: showGlow ? glowColor.opacity(0.5) : .clear, radius: 4)
                }
                .scaleEffect(actionButtonsScale[index] ?? 1.0)
                
                if let value = value {
                    FlicksAnimatedCount(value: value, font: .system(size: 12, weight: .bold))
                } else if let label = label {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(PremiumActionButtonStyle(index: index, scales: $actionButtonsScale))
        .opacity(hasAppeared ? 1 : 0)
        .offset(x: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.25 + Double(index) * 0.06), value: hasAppeared)
    }

    private var displayedLikeCount: Int {
        max(0, video.likeCount + (isLiked ? 1 : 0))
    }

    private var topTags: [String] {
        Array(video.tags.prefix(3))
    }

    private func formatCount(_ value: Int) -> String {
        switch Double(value) {
        case let x where x >= 1_000_000:
            return "\(String(format: "%.1f", x / 1_000_000))M"
        case let x where x >= 1_000:
            return "\(String(format: "%.1f", x / 1_000))K"
        default:
            return "\(value)"
        }
    }

    private var classicOverlay: some View {
        VStack {
            Spacer()
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(video.title).font(.headline.weight(.semibold)).foregroundStyle(.white).lineLimit(2)
                    Text("@\(video.creator.username)").font(.subheadline).foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }

    private func setupPlayer() {
        playerManager.setupPlayer(with: video)
        playerManager.setLooping(true) // 🔥 YOUTUBE PARITY: Loop videos infinitely
        playerManager.player?.isMuted = isMuted
        if let resume = VideoPlayerManager.resumeTime(videoId: video.id), resume > 1, playerManager.duration > 0 {
            let progress = resume / playerManager.duration
            playerManager.seek(to: progress)
        }
        playerManager.play()
        applyPlaybackSpeed()
        isPlaying = true
    }

    private func adoptGlobalManager() {
        Task {
            await globalPlayer.adoptExternalPlayerManager(playerManager, video: video, showFullscreen: false)
        }
    }

    private func cleanupPlayback() {
        removeTimeObserver()
        playerManager.pause()
        isPlaying = false
    }

    private func togglePlayPause() {
        if isPlaying {
            playerManager.pause()
        } else {
            playerManager.play()
            applyPlaybackSpeed()
        }
        isPlaying.toggle()
        HapticManager.shared.impact(style: .light)
    }

    private func toggleMute() {
        isMuted.toggle()
        playerManager.player?.isMuted = isMuted
        if !isMuted { showUnmuteTip = false }
        HapticManager.shared.impact(style: .light)
    }

    private func attachTimeObserver() {
        guard timeObserverToken == nil, let player = playerManager.player else { return }
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { _ in }
    }

    private func removeTimeObserver() {
        if let token = timeObserverToken, let player = playerManager.player {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    private func showPlayPauseIcon() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { showPlayIcon = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { showPlayIcon = false }
        }
    }

    private func heartPulse() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) { showHeartPulse = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { showHeartPulse = false }
        }
        HapticManager.shared.impact(style: .medium)
    }

    private func scheduleOverlayAutohide() {
        revealOverlayTemporarily()
    }

    private func revealOverlayTemporarily() {
        withAnimation(.easeInOut(duration: 0.2)) { overlayVisible = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            if isPlaying {
                withAnimation(.easeOut(duration: 0.25)) { overlayVisible = false }
            }
        }
    }

    private func applyPlaybackSpeed() {
        guard isPlaying, let player = playerManager.player else { return }
        player.rate = Float(playbackSpeed)
    }
}

// MARK: - 🔥 Premium Supporting Types

/// Particle model for like burst animation
struct LikeParticle: Identifiable {
    let id: UUID
    let symbol: String
    let color: Color
    let size: CGFloat
    var x: CGFloat
    var y: CGFloat
    var targetX: CGFloat
    var targetY: CGFloat
    var rotation: Double
    var opacity: Double
    var scale: CGFloat
}

/// Premium scale button style with spring animation
struct PremiumScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Premium action button style with individual scale tracking
struct PremiumActionButtonStyle: ButtonStyle {
    let index: Int
    @Binding var scales: [Int: CGFloat]
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in
                scales[index] = pressed ? 0.85 : 1.0
            }
    }
}

/// Animated count display for Flicks metrics
struct FlicksAnimatedCount: View {
    let value: Int
    var suffix: String = ""
    var font: Font = .system(size: 12, weight: .medium)
    
    @State private var displayedValue: Int = 0
    @State private var hasAnimated = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Text(formatCount(displayedValue) + suffix)
            .font(font)
            .foregroundColor(.white.opacity(0.9))
            .contentTransition(.numericText())
            .onAppear {
                guard !hasAnimated else { return }
                hasAnimated = true
                if reduceMotion {
                    displayedValue = value
                } else {
                    animateCount()
                }
            }
            .onChange(of: value) { newValue in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    displayedValue = newValue
                }
            }
    }
    
    private func animateCount() {
        let steps = min(value, 15)
        guard steps > 0 else {
            displayedValue = value
            return
        }
        let target = value
        let stepNanos = UInt64(400_000_000 / steps) // 0.4 s total
        Task { @MainActor in
            for step in 0...steps {
                let progress = Double(step) / Double(steps)
                let easedProgress = 1 - pow(1 - progress, 3)
                withAnimation(.spring(response: 0.12, dampingFraction: 0.9)) {
                    displayedValue = Int(Double(target) * easedProgress)
                }
                if step < steps { try? await Task.sleep(nanoseconds: stepNanos) }
            }
        }
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ProfessionalVideoPlayer(
            video: Video.sampleVideos.first!,
            isCurrentVideo: true,
            isLiked: false,
            isFollowing: false,
            subscriberCount: Video.sampleVideos.first!.creator.subscriberCount,
            onLike: {},
            onFollow: {},
            onComment: {},
            onShare: {},
            onProfileTap: {},
            overlayStyle: .minimal
        )
    }
    .preferredColorScheme(.dark)
}