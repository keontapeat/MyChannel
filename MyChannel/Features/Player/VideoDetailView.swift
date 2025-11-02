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
    @State private var autoplayEnabled = true
    @State private var upNextTimer: Timer? = nil
    @State private var showingUpNextList = false
    @State private var videoToPresent: Video? = nil
    @State private var isPiPActive = false
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
                    VideoPlayer(player: playerManager.player)
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.width * 9.0 / 16.0)
                    .background(Color.black)
                    .onLongPressGesture(minimumDuration: 0.5) {
                        withAnimation(.spring()) { showDebugHUD.toggle() }
                    }
                    
                    // Paid promotion badge (first 8s)
                    if (video.isSponsored ?? false) && playerManager.currentTime < 8 {
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
                            // Quick gear opens Quality selector
                            Button(action: { showingQualitySelector = true }) {
                                ZStack {
                                    Circle().fill(.black.opacity(0.7)).frame(width: 36, height: 36)
                                    Image(systemName: "aqi.medium").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                                }
                            }
                            .buttonStyle(ScaleButtonStyle())

                            

                            // Subtitles / CC toggle if tracks are available
                            if !playerManager.availableSubtitleOptions().isEmpty {
                                Button(action: { showingSubtitlePicker = true }) {
                                    ZStack {
                                        Circle().fill(.black.opacity(0.7)).frame(width: 36, height: 36)
                                        Image(systemName: "captions.bubble").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                                    }
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }

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

                        // Center controls
                        HStack(spacing: 24) {
                            Button(action: { playerManager.seekBackward(10); HapticManager.shared.impact(style: .light) }) {
                                Image(systemName: "gobackward.10").font(.system(size: 28, weight: .semibold)).foregroundColor(.white)
                            }
                            Button(action: { playerManager.togglePlayPause(); HapticManager.shared.impact(style: .medium) }) {
                                Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 56, weight: .semibold)).foregroundColor(.white)
                            }
                            Button(action: { playerManager.seekForward(10); HapticManager.shared.impact(style: .light) }) {
                                Image(systemName: "goforward.10").font(.system(size: 28, weight: .semibold)).foregroundColor(.white)
                            }
                        }
                        .padding(.bottom, 18)
                        .opacity(showVideoControls ? 1.0 : 0.0)

                        // Bottom progress area with chapter ticks
                        VStack {
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
                                // Chapter tick marks (lightweight)
                                if let chapters = video.chapters, !chapters.isEmpty, playerManager.duration > 0 {
                                    HStack(spacing: 0) {
                                        ForEach(chapters.sorted(by: { $0.start < $1.start })) { c in
                                            let p = max(0, min(1, c.start / playerManager.duration))
                                            Rectangle()
                                                .fill(Color.white.opacity(0.45))
                                                .frame(width: 1, height: 8)
                                                .offset(x: CGFloat(p) * (UIScreen.main.bounds.width - 40 - 16))
                                        }
                                    }
                                    .padding(.horizontal, 28)
                                }
                            }
                            .overlay(alignment: .topLeading) {
                                if isScrubbing, let img = scrubPreviewImage, playerManager.duration > 0 {
                                    let trackWidth = UIScreen.main.bounds.width - 40 // 20pt horizontal padding each side
                                    let x = CGFloat(scrubFraction) * max(0, trackWidth - 160) // keep preview inside
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
                            .gesture(
                                DragGesture(minimumDistance: 20)
                                    .onEnded { value in
                                        // Double-tap seek style: detect quick horizontal flicks
                                        if value.translation.width > 80 { playerManager.seekBackward(10) }
                                        if value.translation.width < -80 { playerManager.seekForward(10) }
                                    }
                            )
                            HStack {
                                Text(formatTime(playerManager.currentTime)).foregroundColor(.white).font(.caption.monospacedDigit())
                                Spacer()
                                // Quick controls: Quality and Speed
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

                                    // System PiP toggle
                                    Button(action: { isPiPActive.toggle() }) {
                                        Image(systemName: isPiPActive ? "pip.exit" : "pip.enter")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .buttonStyle(ScaleButtonStyle())

                                    AirPlayRoutePickerView()
                                        .frame(width: 24, height: 24)
                                }
                                Text(formatTime(playerManager.duration)).foregroundColor(.white).font(.caption.monospacedDigit())
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)
                        }
                        .background(LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                        .opacity(showVideoControls ? 1.0 : 0.0)
                    }
                    .transition(.opacity)
                    .zIndex(10)
                    .allowsHitTesting(showVideoControls)

                // Simple preroll ad overlay when available
                if showingAd, let url = prerollURL {
                    AdPlayerOverlay(adUrl: url) {
                        withAnimation { showingAd = false }
                        if pendingContentResume { playerManager.play(); pendingContentResume = false }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.width * 9.0 / 16.0)
                    .transition(.opacity)
                    .zIndex(100)
                }

                    // End-screen overlay (visual) when video ends
                    if showUpNext, let next = (upNextVideo ?? Video.sampleVideos.first(where: { $0.id != video.id })) {
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
            .overlay(alignment: .topLeading) {
                if showDebugHUD, let stats = playerManager.currentPlaybackStats() {
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
            }

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
                                onProfileTap: { showingCreatorProfile = true })
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
        // Hidden PiP host view to drive system PiP
        .overlay(
            Group {
                if let p = playerManager.player {
                    PlayerPiPContainerView(player: p, isPictureInPictureActive: $isPiPActive)
                        .frame(width: 0, height: 0)
                        .hidden()
                }
            }
        )
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
                            playerManager.play()
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
                            playerManager.play()
                            return
                        }
                        
                        print("🎯 Checking ads for video: \(video.title)")
                        let personalized = UserDefaults.standard.bool(forKey: "preferences.personalizedAdsEnabled")
                        if let ad = await AdsService.requestPreRoll(for: video, personalized: personalized), !ad.creativeUri.isEmpty {
                            print("✅ Got ad: \(ad.creativeUri)")
                            // Create ad video and play it first
                            let adVideo = Video(
                                title: "Ad",
                                description: "Sponsored",
                                thumbnailURL: "",
                                videoURL: ad.creativeUri,
                                duration: TimeInterval(ad.duration),
                                viewCount: 0,
                                likeCount: 0,
                                creator: video.creator,
                                category: .other,
                                isPublic: false
                            )
                            
                            // Play ad first
                            playerManager.setupPlayer(with: adVideo)
                            playerManager.play()
                            
                            // After ad duration, switch to main video
                            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(ad.duration)) {
                                print("🎬 Ad finished, playing main video")
                                playerManager.setupPlayer(with: video)
                                playerManager.applyFastStartTuning()
                                if AppState.shared.preferredVideoQuality != .auto {
                                    playerManager.setPreferredQuality(AppState.shared.preferredVideoQuality)
                                    videoQuality = AppState.shared.preferredVideoQuality
                                }
                                playerManager.play()
                            }
                        } else {
                            print("❌ No ads available - playing video directly")
                            // No ad, play video directly
                            playerManager.setupPlayer(with: video)
                            playerManager.applyFastStartTuning()
                            if AppState.shared.preferredVideoQuality != .auto {
                                playerManager.setPreferredQuality(AppState.shared.preferredVideoQuality)
                                videoQuality = AppState.shared.preferredVideoQuality
                            }
                            playerManager.play()
                        }
                    }
                    // Log watch start to history
                    if let uid = AppState.shared.currentUser?.id {
                        Task { await HistoryService.shared.logStart(userId: uid, video: video) }
                    }
                    
                    // 🔥 TRACK VIEW COUNT: Increment view count in Firestore for real-time stats
                    Task {
                        await VideoFirestoreService.shared.incrementViewCount(videoId: video.id)
                    }
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
            if !isYouTube {
                if !(globalPlayer.isMiniplayer || globalPlayer.showingFullscreen),
                   globalPlayer.currentVideo?.id != video.id {
                    playerManager.performCleanup()
                }
                // Always show mini player when leaving detail if video still active
                if globalPlayer.currentVideo != nil {
                    globalPlayer.minimizePlayer()
                    globalPlayer.ensurePlayerAttached()
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SeekToTimestamp"))) { notification in
            if let timestamp = notification.object as? TimeInterval {
                let progress = playerManager.duration > 0 ? timestamp / playerManager.duration : 0
                playerManager.seek(to: progress)
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

        // Consider prompting for review after successful completion
        if let uid = AppState.shared.currentUser?.id {
            Task { await ReviewGateService.shared.checkEligibilityAndPrompt(userId: uid) }
        }
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