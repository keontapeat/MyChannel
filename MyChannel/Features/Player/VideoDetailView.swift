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

    var body: some View {
        VStack(spacing: 0) {
            // Enhanced Video Player with Collapse and Close buttons
            ZStack {
                EnhancedVideoPlayerView(video: video)
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.3)
                    .cornerRadius(12)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showVideoControls.toggle()
                        }
                        
                        if showVideoControls {
                            resetControlsHideTimer()
                        }
                    }
                
                // Video Control Overlay
                if showVideoControls {
                    VStack {
                        // Top control bar with collapse and close buttons
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
                                        .fill(.black.opacity(0.6))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .buttonStyle(ScaleButtonStyle())
                            
                            Spacer()
                            
                            // Video title
                            Text(video.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .shadow(color: .black.opacity(0.8), radius: 1)
                            
                            Spacer()
                            
                            // Minimize to mini player button
                            Button(action: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    globalPlayer.minimizePlayer()
                                    dismiss()
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(.black.opacity(0.6))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "pip.enter")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        Spacer()
                        
                        // Bottom gradient for better text visibility
                        VStack {
                            Spacer()
                            
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.4)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 60)
                            .allowsHitTesting(false)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.top, 8)

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
        .sheet(isPresented: $showingCommentComposer) {
            CommentComposerView(video: video) { _ in }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingShareSheet) {
            VideoShareSheet(items: [video.link])
                .presentationDetents([.medium])
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
                globalPlayer.playVideo(video, showFullscreen: true)
                isViewAppeared = true
                resetControlsHideTimer()
            }
        }
        .onDisappear {
            playerControlsTimer?.invalidate()
            controlsHideTimer?.invalidate()
            
            // Only minimize if we're not closing the player entirely
            if globalPlayer.isPlaying && globalPlayer.currentVideo?.id == video.id && globalPlayer.showingFullscreen {
                globalPlayer.minimizePlayer()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                if globalPlayer.isPlaying {
                    globalPlayer.togglePlayPause()
                }
            }
        }
        .onChange(of: showVideoControls) { _, newValue in
            if newValue {
                resetControlsHideTimer()
            } else {
                controlsHideTimer?.invalidate()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func resetControlsHideTimer() {
        controlsHideTimer?.invalidate()
        controlsHideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                showVideoControls = false
            }
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