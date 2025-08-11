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

    var body: some View {
        VStack(spacing: 0) {
            // ALL-IN-ONE Video Player with YouTube-style controls
            ZStack {
                // MAIN VIDEO PLAYER - Edge-to-edge like YouTube
                VideoPlayer(player: playerManager.player)
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
                                // Swipe down -> enter fullscreen immersive player
                                if value.translation.height > 60 {
                                    presentFullscreenPlayer()
                                }
                                // Swipe up -> minimize to mini player
                                else if value.translation.height < -60 {
                                    minimizeToMiniPlayer()
                                }
                            }
                    )
                    .zIndex(1) // Lower zIndex so buttons can be tapped
                
                // YouTube-style overlay controls - HIGHER LAYER
                VStack(spacing: 0) {
                    // Seek with double-tap
                    HStack(spacing: 0) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                playerManager.seekBackward(10)
                                HapticManager.shared.impact(style: .light)
                                resetControlsHideTimer()
                            }
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                playerManager.seekForward(10)
                                HapticManager.shared.impact(style: .light)
                                resetControlsHideTimer()
                            }
                    }
                    .allowsHitTesting(true)
                    .frame(height: 1)
                    .opacity(0.01)
                    
                    // Top control bar
                    HStack {
                        // Close button (X out)
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                globalPlayer.closePlayer()
                                dismiss()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(.black.opacity(0.7))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        Spacer()
                        
                        // Video title
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
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.black.opacity(0.4))
                        )
                        
                        Spacer()
                        
                        // Minimize to mini player button
                        Button(action: {
                            minimizeToMiniPlayer()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(.black.opacity(0.7))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "pip.enter")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .background(
                        LinearGradient(
                            colors: [.black.opacity(0.8), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(showVideoControls ? 1.0 : 0.0)
                    
                    Spacer()
                    
                    // Center playback controls
                    HStack(spacing: 40) {
                        // Skip back 10 seconds
                        Button(action: {
                            print("⏪ Skip back button tapped")
                            playerManager.seekBackward(10)
                            HapticManager.shared.impact(style: .light)
                            resetControlsHideTimer()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(.black.opacity(0.7))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "gobackward.10")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Play/Pause button (main control)
                        Button(action: {
                            print("🎯 Play/Pause button tapped - Current state: \(playerManager.isPlaying)")
                            print("🎮 Player exists: \(playerManager.player != nil)")
                            playerManager.togglePlayPause()
                            HapticManager.shared.impact(style: .medium)
                            resetControlsHideTimer()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(.black.opacity(0.8))
                                    .frame(width: 70, height: 70)
                                
                                Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                    .offset(x: playerManager.isPlaying ? 0 : 2)
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Skip forward 10 seconds
                        Button(action: {
                            print("⏩ Skip forward button tapped")
                            playerManager.seekForward(10)
                            HapticManager.shared.impact(style: .light)
                            resetControlsHideTimer()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(.black.opacity(0.7))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "goforward.10")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .opacity(showVideoControls ? 1.0 : 0.0)
                    
                    Spacer()
                    
                    // Bottom progress bar and time
                    VStack(spacing: 12) {
                        // YouTube-style progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: isDraggingSeeker ? 6 : 4)
                                    .animation(.easeInOut(duration: 0.2), value: isDraggingSeeker)
                                
                                // Buffered progress
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.5))
                                    .frame(
                                        width: geometry.size.width * CGFloat(playerManager.bufferedProgress),
                                        height: isDraggingSeeker ? 6 : 4
                                    )
                                
                                // Current progress (YouTube red)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.red)
                                    .frame(
                                        width: geometry.size.width * CGFloat(playerManager.currentProgress),
                                        height: isDraggingSeeker ? 6 : 4
                                    )
                                    .animation(.linear(duration: 0.1), value: playerManager.currentProgress)
                                
                                // Scrubber dot
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: isDraggingSeeker ? 16 : 12, height: isDraggingSeeker ? 16 : 12)
                                    .offset(x: geometry.size.width * CGFloat(playerManager.currentProgress) - (isDraggingSeeker ? 8 : 6))
                                    .opacity(isDraggingSeeker ? 1.0 : 0.8)
                                    .animation(.easeInOut(duration: 0.2), value: isDraggingSeeker)
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        isDraggingSeeker = true
                                        let progress = min(max(value.location.x / geometry.size.width, 0), 1)
                                        playerManager.seek(to: progress)
                                        HapticManager.shared.impact(style: .light)
                                    }
                                    .onEnded { _ in
                                        isDraggingSeeker = false
                                        resetControlsHideTimer()
                                    }
                            )
                            .overlay(alignment: .topLeading) {
                                if isDraggingSeeker, playerManager.duration > 0 {
                                    let previewTime = playerManager.duration * playerManager.currentProgress
                                    if let img = playerManager.thumbnail(at: previewTime) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 120, height: 68)
                                            .clipped()
                                            .background(Color.black)
                                            .cornerRadius(8)
                                            .offset(x: max(0, min(geometry.size.width - 120, geometry.size.width * CGFloat(playerManager.currentProgress) - 60)), y: -76)
                                            .shadow(radius: 4)
                                    }
                                }
                            }
                        }
                        .frame(height: 20)
                        
                        // Time labels
                        HStack {
                            Text(formatTime(playerManager.currentTime))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.8), radius: 1)
                            
                            Spacer()
                            
                            Text(formatTime(playerManager.duration))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.8), radius: 1)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(showVideoControls ? 1.0 : 0.0)
                }
                .transition(.opacity)
                .zIndex(10) // Put all controls ABOVE the tap area
                .allowsHitTesting(showVideoControls) // Only allow button taps when controls are visible
                
                // Loading indicator
                if playerManager.isLoading {
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.6))
                            .frame(width: 80, height: 80)
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    }
                    .zIndex(100)
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
                                onComment: { showingCommentComposer = true })
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
                
                // Set up the player manager properly
                playerManager.setupPlayer(with: video)
                playerManager.play()
                
                showVideoControls = true
                isViewAppeared = true
                resetControlsHideTimer()
            }
        }
        .onDisappear {
            print("🎬 VideoDetailView disappearing")
            playerControlsTimer?.invalidate()
            controlsHideTimer?.invalidate()
            
            // Only cleanup if playback isn't being handed off to global mini player/fullscreen
            if !(globalPlayer.isMiniplayer || globalPlayer.showingFullscreen),
               globalPlayer.currentVideo?.id != video.id {
                playerManager.performCleanup()
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