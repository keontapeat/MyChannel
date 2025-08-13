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

    @State private var isPlaying = true
    @State private var isMuted = true
    @State private var showPlayIcon = false
    @State private var showHeartPulse = false
    @State private var overlayVisible = true
    @State private var showUnmuteTip = true
    @State private var timeObserverToken: Any?

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
                        revealOverlayTemporarily()
                    }
                    .onAppear {
                        setupPlayer()
                        attachTimeObserver()
                        adoptGlobalManager()
                        scheduleOverlayAutohide()
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
                    .onChange(of: isCurrentVideo) { _, newValue in
                        if newValue {
                            playerManager.play()
                            applyPlaybackSpeed()
                            isPlaying = true
                            adoptGlobalManager()
                            scheduleOverlayAutohide()
                        } else {
                            playerManager.pause()
                            isPlaying = false
                        }
                    }
                    .onChange(of: playbackSpeed) { _, _ in
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
                ProgressView().tint(.white).scaleEffect(1.2)
            }

            if overlayStyle == .minimal { minimalOverlay.opacity(overlayVisible ? 1 : 0) } else { classicOverlay.opacity(overlayVisible ? 1 : 0) }

            if showPlayIcon {
                ZStack {
                    Circle().fill(.black.opacity(0.28)).frame(width: 110, height: 110).background(.ultraThinMaterial, in: Circle())
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 46, weight: .medium))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .scaleEffect(showPlayIcon ? 1.0 : 0.85)
                .opacity(showPlayIcon ? 1.0 : 0.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showPlayIcon)
            }

            if showHeartPulse {
                Image(systemName: "heart.fill")
                    .font(.system(size: 68))
                    .foregroundStyle(.red)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .scaleEffect(showHeartPulse ? 1.0 : 0.8)
                    .opacity(showHeartPulse ? 0.95 : 0.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: showHeartPulse)
            }

            if showUnmuteTip && isMuted && isCurrentVideo {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.slash.fill").font(.caption.bold())
                    Text("Sound off").font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 0.6))
                .foregroundStyle(.white)
                .padding(.bottom, 180)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeOut(duration: 0.25)) { showUnmuteTip = false }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: overlayVisible)
    }

    private var minimalOverlay: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.22)).frame(height: 3)
                    Capsule()
                        .fill(.white.opacity(0.5))
                        .frame(width: max(6, CGFloat(playerManager.bufferedProgress) * proxy.size.width), height: 3)
                    Capsule()
                        .fill(.white)
                        .frame(width: max(6, CGFloat(playerManager.currentProgress) * proxy.size.width), height: 3)
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)
            }
            .frame(height: 14)

            Spacer()

            LinearGradient(colors: [.clear, .black.opacity(0.08), .black.opacity(0.25)], startPoint: .top, endPoint: .bottom)
                .frame(height: 96)
                .allowsHitTesting(false)

            HStack(spacing: 12) {
                Button(action: onProfileTap) {
                    AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(.white.opacity(0.25))
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("@\(video.creator.username)").font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                        if video.creator.isVerified { Image(systemName: "checkmark.seal.fill").font(.caption2).foregroundStyle(AppTheme.Colors.primary) }
                    }
                    Text(video.title).font(.callout.weight(.semibold)).foregroundStyle(.white.opacity(0.95)).lineLimit(2)
                }

                Spacer()

                HStack(spacing: 10) {
                    glassIconButton(system: isLiked ? "heart.fill" : "heart", tint: isLiked ? .red : .white) { onLike(); HapticManager.shared.impact(style: .light); revealOverlayTemporarily() }
                    glassIconButton(system: "bubble.right.fill", tint: .white) { onComment(); revealOverlayTemporarily() }
                    glassIconButton(system: "arrowshape.turn.up.right.fill", tint: .white) { onShare(); revealOverlayTemporarily() }
                    glassIconButton(system: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", tint: .white) { toggleMute(); revealOverlayTemporarily() }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 0.6))
            .padding(.horizontal, 16)
            .padding(.bottom, 106)
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

    private func glassIconButton(system: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 0.6))
        }
        .buttonStyle(.plain)
    }

    private func setupPlayer() {
        playerManager.setupPlayer(with: video)
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
        globalPlayer.adoptExternalPlayerManager(playerManager, video: video, showFullscreen: false)
        globalPlayer.shouldShowMiniPlayer = false
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { showPlayIcon = false }
        }
    }

    private func heartPulse() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) { showHeartPulse = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { showHeartPulse = false }
        }
        HapticManager.shared.impact(style: .medium)
    }

    private func scheduleOverlayAutohide() {
        revealOverlayTemporarily()
    }

    private func revealOverlayTemporarily() {
        withAnimation(.easeInOut(duration: 0.2)) { overlayVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
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