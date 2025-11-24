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
                    .onChange(of: isCurrentVideo) { newValue in
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
        GeometryReader { proxy in
            let safeInsets = proxy.safeAreaInsets
            VStack(spacing: 0) {
                progressIndicator
                    .padding(.top, max(12, safeInsets.top + 8))
                    .padding(.horizontal, 28)

                Spacer()

                bottomOverlay(insets: safeInsets)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var progressIndicator: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.12))
                    .frame(height: 3)
                Capsule()
                    .fill(.white.opacity(0.35))
                    .frame(width: max(6, CGFloat(playerManager.bufferedProgress) * proxy.size.width), height: 3)
                Capsule()
                    .fill(.white)
                    .frame(width: max(6, CGFloat(playerManager.currentProgress) * proxy.size.width), height: 3)
            }
        }
        .frame(height: 14)
    }

    private func bottomOverlay(insets: EdgeInsets) -> some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.2), .black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 260 + insets.bottom)
            .allowsHitTesting(false)

            HStack(alignment: .bottom, spacing: 20) {
                detailCard
                actionColumn
            }
            .padding(.horizontal, max(20, insets.leading + 18))
            .padding(.bottom, max(24, insets.bottom + 18))
        }
        .frame(maxWidth: .infinity)
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Button(action: { onProfileTap(); revealOverlayTemporarily() }) {
                    AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(.white.opacity(0.2))
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("@\(video.creator.username)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if video.creator.shouldShowVerificationBadge {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                    Text(formatCount(subscriberCount) + " subscribers")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }

                Spacer()

                Button(action: { onFollow(); revealOverlayTemporarily() }) {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isFollowing ? Color.white.opacity(0.15) : AppTheme.Colors.primary)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
            }

            Text(video.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !topTags.isEmpty {
                HStack(spacing: 8) {
                    ForEach(topTags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.95))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.12), in: Capsule())
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "music.note")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text("Original Audio · \(video.creator.displayName)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionColumn: some View {
        VStack(spacing: 18) {
            metricButton(
                systemName: isLiked ? "heart.fill" : "heart",
                label: formatCount(displayedLikeCount),
                iconTint: isLiked ? .red : .white
            ) {
                onLike()
                HapticManager.shared.impact(style: .light)
                revealOverlayTemporarily()
            }

            metricButton(
                systemName: "bubble.right.fill",
                label: formatCount(video.commentCount)
            ) {
                onComment()
                revealOverlayTemporarily()
            }

            metricButton(
                systemName: "arrowshape.turn.up.right.fill",
                label: "Share"
            ) {
                onShare()
                revealOverlayTemporarily()
            }

            metricButton(
                systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                label: isMuted ? "Sound" : "Mute"
            ) {
                toggleMute()
                revealOverlayTemporarily()
            }

            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Circle().fill(Color.white.opacity(0.2))
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.8), AppTheme.Colors.primary.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .rotationEffect(.degrees(-6))
            .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.9)
        )
    }

    private func metricButton(systemName: String, label: String, iconTint: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconTint)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                    )
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
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