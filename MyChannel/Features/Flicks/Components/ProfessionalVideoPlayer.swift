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

            FlicksPlayerOverlay(
                style: overlayStyle,
                video: video,
                isLiked: isLiked,
                isFollowing: isFollowing,
                isMuted: isMuted,
                isPlaying: isPlaying,
                subscriberCount: subscriberCount,
                currentProgress: playerManager.currentProgress,
                bufferedProgress: playerManager.bufferedProgress,
                hasAppeared: hasAppeared,
                discRotation: discRotation,
                profileRingPhase: $profileRingPhase,
                actionButtonsScale: $actionButtonsScale,
                reduceMotion: reduceMotion,
                onLike: onLike,
                onFollow: onFollow,
                onComment: onComment,
                onShare: onShare,
                onProfileTap: onProfileTap,
                onToggleMute: toggleMute,
                onRevealOverlay: revealOverlayTemporarily,
                onSpawnLikeParticles: spawnLikeParticles
            )
            .opacity(overlayVisible ? 1 : 0)

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