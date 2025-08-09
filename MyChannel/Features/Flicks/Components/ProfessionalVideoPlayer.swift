import SwiftUI
import AVKit
import AVFoundation

struct ProfessionalVideoPlayer: View {
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
    
    @StateObject private var playerManager = VideoPlayerManager()
    @State private var isPlaying = true
    @State private var showPlayIcon = false
    @State private var currentProgress: Double = 0.0
    @State private var timeObserverToken: Any?
    @State private var isMuted = false
    @State private var showSeekForward = false
    @State private var showSeekBackward = false
    @AppStorage("flicks_playback_speed") private var playbackSpeed: Double = 1.0
    
    var body: some View {
        ZStack {
            if isCurrentVideo {
                FlicksPlayerLayerView(
                    player: playerManager.player,
                    videoGravity: .resizeAspectFill
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        togglePlayPause()
                        showPlayPauseIcon()
                    }
                    .overlay(alignment: .center) { seekGestureOverlay }
                    .onAppear {
                        setupPlayer()
                        addTimeObserver()
                    }
                    .onDisappear {
                        cleanupPlayback()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                        playerManager.pause()
                        isPlaying = false
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                        if isCurrentVideo {
                            playerManager.play()
                            applyPlaybackSpeed()
                            isPlaying = true
                        }
                    }
                    .onChange(of: isCurrentVideo) { _, newValue in
                        if newValue {
                            playerManager.play()
                            applyPlaybackSpeed()
                            isPlaying = true
                        } else {
                            playerManager.pause()
                            isPlaying = false
                        }
                    }
                    .onChange(of: playbackSpeed) { _, _ in
                        if isPlaying {
                            applyPlaybackSpeed()
                        }
                    }
            } else {
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        Rectangle()
                            .fill(.black)
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            
            if showPlayIcon {
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .background(.ultraThinMaterial, in: Circle())
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .scaleEffect(showPlayIcon ? 1.0 : 0.8)
                .opacity(showPlayIcon ? 1.0 : 0.0)
                .animation(AppTheme.AnimationPresets.bouncy, value: showPlayIcon)
            }
            
            GeometryReader { geometry in
                ZStack {
                    VStack {
                        Spacer()
                        LinearGradient(
                            colors: [
                                .clear,
                                .black.opacity(0.3),
                                .black.opacity(0.7),
                                .black.opacity(0.9)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 350)
                        .allowsHitTesting(false)
                    }
                    
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer()
                            
                            HStack(spacing: 16) {
                                Button(action: onProfileTap) {
                                    AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle()
                                            .fill(AppTheme.Colors.primary)
                                            .overlay(
                                                Text(String(video.creator.displayName.prefix(1)))
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundStyle(.white)
                                            )
                                    }
                                    .frame(width: 52, height: 52)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.4), lineWidth: 2.5)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                                    .accessibilityLabel("\(video.creator.displayName) profile")
                                }
                                .buttonStyle(.plain)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Text("@\(video.creator.username)")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(.white)
                                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                        
                                        if video.creator.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.system(size: 16))
                                                .foregroundStyle(AppTheme.Colors.primary)
                                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                                .accessibilityLabel("Verified")
                                        }
                                    }
                                    
                                    Text("\(subscriberCount.formatted()) subscribers")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                                }
                                
                                Spacer()
                                
                                if !isFollowing {
                                    Button(action: onFollow) {
                                        Text("Subscribe")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .background(.white, in: Capsule())
                                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                            .accessibilityLabel("Subscribe")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, 16)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text(video.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                
                                if !video.description.isEmpty {
                                    Text(video.description)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                                }
                            }
                            .frame(maxWidth: geometry.size.width * 0.65, alignment: .leading)
                            .padding(.bottom, 120)
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                        
                        VStack(spacing: 28) {
                            Spacer()
                            
                            ProfessionalActionButton(
                                icon: isLiked ? "heart.fill" : "heart",
                                text: formatCount(video.likeCount),
                                isActive: isLiked,
                                activeColor: .red,
                                action: onLike
                            )
                            
                            ProfessionalActionButton(
                                icon: "bubble.right.fill",
                                text: formatCount(video.commentCount),
                                action: onComment
                            )
                            
                            ProfessionalActionButton(
                                icon: "arrowshape.turn.up.right.fill",
                                text: "Share",
                                action: onShare
                            )
                            
                            ProfessionalActionButton(
                                icon: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                text: "",
                                action: toggleMute
                            )
                            
                            Button(action: onProfileTap) {
                                AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(AppTheme.Colors.primary.opacity(0.8))
                                }
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 2.5)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                .accessibilityHidden(true)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 120)
                    }
                }
            }
            
            VStack(spacing: 8) {
                Spacer()
                
                progressBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 44)
            }
        }
    }
    
    private var seekGestureOverlay: some View {
        GeometryReader { _ in
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        seek(by: -10)
                        withAnimation(AppTheme.AnimationPresets.bouncy) { showSeekBackward = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(AppTheme.AnimationPresets.spring) { showSeekBackward = false }
                        }
                        HapticManager.shared.impact(style: .light)
                    }
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        seek(by: 10)
                        withAnimation(AppTheme.AnimationPresets.bouncy) { showSeekForward = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(AppTheme.AnimationPresets.spring) { showSeekForward = false }
                        }
                        HapticManager.shared.impact(style: .light)
                    }
            }
            .overlay(alignment: .leading) {
                if showSeekBackward {
                    seekBadge(symbol: "gobackward.10")
                        .padding(.leading, 24)
                }
            }
            .overlay(alignment: .trailing) {
                if showSeekForward {
                    seekBadge(symbol: "goforward.10")
                        .padding(.trailing, 24)
                }
            }
        }
        .allowsHitTesting(true)
    }
    
    private func seekBadge(symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 38, weight: .bold))
            .foregroundStyle(.white)
            .padding(14)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
            .transition(.scale.combined(with: .opacity))
    }
    
    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.35))
                    .frame(height: 4)
                
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.Colors.primary, .white],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, CGFloat(currentProgress) * proxy.size.width), height: 4)
                    .shadow(color: .white.opacity(0.5), radius: 2, x: 0, y: 0)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = max(0, min(1, value.location.x / proxy.size.width))
                        seek(toFraction: fraction, animateProgress: true)
                    }
            )
        }
        .frame(height: 16)
        .accessibilityLabel("Playback progress")
    }
    
    private func setupPlayer() {
        playerManager.setupPlayer(with: video)
        if let player = playerManager.player {
            player.isMuted = isMuted
        }
        playerManager.play()
        applyPlaybackSpeed()
        isPlaying = true
    }
    
    private func cleanupPlayback() {
        playerManager.pause()
        removeTimeObserver()
        currentProgress = 0
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
        if let player = playerManager.player {
            player.isMuted = isMuted
        }
        HapticManager.shared.impact(style: .light)
    }
    
    private func seek(by seconds: Double) {
        guard let player = playerManager.player,
              let item = player.currentItem else { return }
        let current = item.currentTime().seconds
        let duration = item.duration.seconds
        guard duration.isFinite && duration > 0 else { return }
        let target = max(0, min(duration, current + seconds))
        let time = CMTime(seconds: target, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    private func seek(toFraction fraction: CGFloat, animateProgress: Bool) {
        guard let player = playerManager.player,
              let item = player.currentItem else { return }
        let duration = item.duration
        guard duration.isNumeric && duration.seconds > 0 else { return }
        let targetSeconds = Double(fraction) * duration.seconds
        let time = CMTime(seconds: targetSeconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        if animateProgress {
            withAnimation(.linear(duration: 0.05)) {
                currentProgress = max(0, min(1, Double(fraction)))
            }
        } else {
            currentProgress = max(0, min(1, Double(fraction)))
        }
    }
    
    private func addTimeObserver() {
        guard timeObserverToken == nil else { return }
        guard let player = playerManager.player else { return }
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            updateProgress(currentTime: time)
        }
    }
    
    private func removeTimeObserver() {
        if let token = timeObserverToken, let player = playerManager.player {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    private func updateProgress(currentTime: CMTime) {
        guard let item = playerManager.player?.currentItem else {
            currentProgress = 0
            return
        }
        let duration = item.duration
        if duration.isNumeric, duration.seconds > 0 {
            let progress = currentTime.seconds / duration.seconds
            withAnimation(.linear(duration: 0.05)) {
                currentProgress = max(0, min(1, progress))
            }
        } else {
            currentProgress = 0
        }
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
    
    private func showPlayPauseIcon() {
        withAnimation(AppTheme.AnimationPresets.bouncy) {
            showPlayIcon = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(AppTheme.AnimationPresets.spring) {
                showPlayIcon = false
            }
        }
    }
    
    private func playAtCurrentSpeed() {
        playerManager.play()
        applyPlaybackSpeed()
    }
    
    private func applyPlaybackSpeed() {
        guard isPlaying, let player = playerManager.player else { return }
        player.rate = Float(playbackSpeed)
    }
}

private struct ProfessionalActionButton: View {
    let icon: String
    let text: String
    var isActive: Bool = false
    var activeColor: Color = AppTheme.Colors.primary
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var showPulse = false
    
    var body: some View {
        Button(action: {
            action()
            triggerPulseEffect()
            HapticManager.shared.impact(style: .light)
        }) {
            VStack(spacing: 8) {
                ZStack {
                    if showPulse {
                        Circle()
                            .fill(isActive ? activeColor.opacity(0.3) : .white.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .scaleEffect(showPulse ? 1.3 : 1.0)
                            .opacity(showPulse ? 0.0 : 1.0)
                            .animation(AppTheme.AnimationPresets.easeInOut, value: showPulse)
                    }
                    
                    Circle()
                        .fill(isActive ? activeColor.opacity(0.2) : .black.opacity(0.3))
                        .frame(width: 52, height: 52)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(isActive ? activeColor : .white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                
                if !text.isEmpty {
                    Text(text)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(AppTheme.AnimationPresets.bouncy, value: isPressed)
        .animation(AppTheme.AnimationPresets.spring, value: isActive)
        .onLongPressGesture(minimumDuration: 0.01) { } onPressingChanged: { pressing in
            withAnimation(AppTheme.AnimationPresets.quick) {
                isPressed = pressing
            }
        }
        .accessibilityAddTraits(.isButton)
    }
    
    private func triggerPulseEffect() {
        withAnimation(AppTheme.AnimationPresets.easeInOut) {
            showPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showPulse = false
        }
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
            onProfileTap: {}
        )
    }
    .preferredColorScheme(.dark)
}