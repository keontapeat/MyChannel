//  VideoDetailView.swift
//  MyChannel

import SwiftUI
import AVKit
import Combine

struct VideoDetailView: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared
    @StateObject private var playerManager = VideoPlayerManager() // Single player manager

    private var isYouTube: Bool { video.contentSource == .youtube && video.externalID != nil }

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
    @State private var showSeekRippleForward = false
    @State private var showSeekRippleBackward = false
    @State private var showingChapters = false
    @State private var currentChapterTitle: String = ""
    @State private var showingChapterTooltip = false
    @State private var chapterTooltipX: CGFloat = 0
    @State private var showUpNext = false
    @State private var upNextCountdown = 5
    @State private var upNextVideo: Video? = nil

    var body: some View {
        VStack(spacing: 0) {
            // ALL-IN-ONE Video Player with YouTube-style controls
            ZStack {
                if isYouTube {
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
                        Button(action: { dismiss() }) {
                            ZStack {
                                Circle().fill(.black.opacity(0.7)).frame(width: 36, height: 36)
                                Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())

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
                } else {
                    // EXISTING AVPlayer path
                    Group {
                        if AppConfig.isPreview {
                            Rectangle().fill(Color.black)
                        } else {
                            VideoPlayer(player: playerManager.player)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.width * 9.0 / 16.0)
                    .background(Color.black)
                    
                    // Invisible tap/drag area to show/hide controls and drive fullscreen/miniplayer gestures
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            print("📱 Video tapped - Current controls state: \(showVideoControls)")
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showVideoControls.toggle()
                            }
                            
                            if showVideoControls {
                                resetControlsHideTimer()
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 12, coordinateSpace: .local)
                                .onEnded { value in
                                    if value.translation.height > 60 {
                                        presentFullscreenPlayer()
                                    } else if value.translation.height < -60 {
                                        minimizeToMiniPlayer()
                                    }
                                }
                        )
                        .zIndex(1)
                    
                    // Overlay controls for AVPlayer
                    VStack(spacing: 0) {
                        // Top control bar
                        HStack {
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    globalPlayer.closePlayer()
                                    dismiss()
                                }
                            }) {
                                ZStack {
                                    Circle().fill(.black.opacity(0.7)).frame(width: 36, height: 36)
                                    Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                                }
                            }
                            .buttonStyle(ScaleButtonStyle())
                            
                            Spacer()
                            
                            HStack {
                                Text(video.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .shadow(color: .black.opacity(0.8), radius: 2)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                            }
                            .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.4)))
                            
                            Spacer()
                            
                            if let chapters = video.chapters, !chapters.isEmpty {
                                Button(action: { showingChapters = true }) {
                                    ZStack {
                                        Circle().fill(.black.opacity(0.7)).frame(width: 36, height: 36)
                                        Image(systemName: "list.bullet.rectangle").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                                    }
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }

                            Button(action: { minimizeToMiniPlayer() }) {
                                ZStack {
                                    Circle().fill(.black.opacity(0.7)).frame(width: 36, height: 36)
                                    Image(systemName: "pip.enter").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                                }
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .background(LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom))
                        .opacity(showVideoControls ? 1.0 : 0.0)
                        
                        Spacer()

                        // Center controls, progress, etc. (unchanged)
                        // ... existing code for AVPlayer controls ...
                    }
                    .transition(.opacity)
                    .zIndex(10)
                    .allowsHitTesting(showVideoControls)
                    
                    if playerManager.isLoading {
                        ZStack {
                            Circle().fill(.black.opacity(0.6)).frame(width: 80, height: 80)
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(1.2)
                        }
                        .zIndex(100)
                    }
                }
            }
            .background(Color.black)

            // Video metadata and controls
            VideoDetailMetaView(video: video,
                                isSubscribed: $isSubscribed,
                                isWatchLater: $isWatchLater,
                                isLiked: $isLiked,
                                isDisliked: $isDisliked,
                                expandedDescription: $expandedDescription,
                                onShare: { showingShareSheet = true },
                                onMore: { showingMoreOptions = true },
                                onComment: { showingCommentComposer = true },
                                onChapters: { showingChapters = true })
        }
        .navigationBarHidden(true)
        // When user returns from fullscreen by dismissing, ensure state is consistent
        .sheet(isPresented: $showingCommentComposer) {
            CommentComposerView(video: video) { _ in }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingShareSheet) {
            VideoShareSheet(items: [video.link])
                .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $showingFullscreenOverlay) {
            ImmersiveFullscreenPlayerView(video: video) {
                // Exit fullscreen back to inline without breaking playback
                globalPlayer.showingFullscreen = false
                globalPlayer.shouldShowMiniPlayer = false
                globalPlayer.isMiniplayer = false
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
        .sheet(isPresented: $showingQualitySelector) {
            VideoQualitySelector(selectedQuality: $videoQuality) { quality in
                videoQuality = quality
            }
            .presentationDetents([.fraction(0.4)])
        }
        .sheet(isPresented: $showingPlaybackSpeedSelector) {
            PlaybackSpeedSelector(selectedSpeed: $playbackRate) { speed in
                playbackRate = speed
            }
            .presentationDetents([.fraction(0.4)])
        }
        .onAppear {
            if !isViewAppeared {
                print("🎬 Setting up video player for: \(video.title)")
                GlobalVideoPlayerManager.shared.stopImmediately()
                if !isYouTube {
                    playerManager.setupPlayer(with: video)
                    DispatchQueue.main.async { playerManager.play() }
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
            if !isYouTube {
                if !(globalPlayer.isMiniplayer || globalPlayer.showingFullscreen),
                   globalPlayer.currentVideo?.id != video.id {
                    playerManager.performCleanup()
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                if playerManager.isPlaying {
                    playerManager.pause()
                }
            }
        }
        .onChange(of: showVideoControls) { _, newValue in
            print("🎮 Controls visibility changed to: \(newValue)")
            if newValue {
                resetControlsHideTimer()
            } else {
                controlsHideTimer?.invalidate()
            }
        }
        .onChange(of: playerManager.isPlaying) { _, newValue in
            print("🎵 Player state changed to: \(newValue ? "Playing" : "Paused")")
        }
        .onChange(of: playerManager.currentTime) { _, newTime in
            if let chapters = video.chapters, !chapters.isEmpty {
                let sorted = chapters.sorted { $0.start < $1.start }
                if let current = sorted.last(where: { $0.start <= newTime }) {
                    currentChapterTitle = current.title
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func resetControlsHideTimer() {
        controlsHideTimer?.invalidate()
        controlsHideTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                showVideoControls = false
            }
        }
    }

    // MARK: - Gesture Actions
    private func presentFullscreenPlayer() {
        // Hand off the existing manager to the global one and present a true fullscreen overlay
        globalPlayer.adoptExternalPlayerManager(playerManager, video: video, showFullscreen: true)
        showingFullscreenOverlay = true
    }

    private func minimizeToMiniPlayer() {
        globalPlayer.adoptExternalPlayerManager(playerManager, video: video, showFullscreen: false)
        dismiss()
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
}

// MARK: - Custom Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    NavigationView {
        VideoDetailView(video: Video.sampleVideos[0])
            .environmentObject(PreviewSafeGlobalVideoPlayerManager())
    }
}