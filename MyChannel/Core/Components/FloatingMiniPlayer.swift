//
//  FloatingMiniPlayer.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVKit

struct FloatingMiniPlayer: View {
    // Internal access — shared with MiniPlayerGestures / MiniPlayerControls extensions
    @StateObject var globalPlayer = GlobalVideoPlayerManager.shared
    @GestureState var dragState = CGSize.zero
    @State var position: CGPoint = .zero
    @State var lastPosition: CGPoint = .zero
    @State var isDragging = false
    @State var showingControls = false
    @State var showingVolumeSlider = false
    @State var showingSpeedMenu = false
    @State var showingQualityMenu = false
    @State var playerSize: CGSize = CGSize(width: 140, height: 78)
    @State var isResizing = false
    @State var lastTapTime: Date = Date()
    @State var tapCount = 0
    @State var volume: Float = 1.0
    @State var playbackSpeed: Float = 1.0
    @State var selectedQuality: String = "Auto"
    
    var body: some View {
        // 🔥 FIX: More robust condition checking to prevent mini player from disappearing
        // 🔥 FIX: Ensure player exists and is ready to prevent error states
        if let video = globalPlayer.currentVideo,
           !globalPlayer.showingFullscreen,
           !globalPlayer.isCleanedUp,
           globalPlayer.player != nil {
            
            GeometryReader { geometry in
                // 🔥 YOUTUBE PARITY: Free-floating mini player that can be dragged anywhere
                miniPlayerView(video: video, geometry: geometry)
                    .position(
                        x: position.x == 0 ? geometry.size.width - (playerSize.width / 2) - 20 : position.x,
                        y: position.y == 0 ? geometry.size.height - (playerSize.height / 2) - 100 : position.y
                    )
                    .offset(dragState)  // 🔥 NEW: Use @GestureState for buttery smooth dragging
                    .animation(.interactiveSpring(), value: dragState)  // 🔥 NEW: Smooth animation during drag
                    .gesture(
                        SimultaneousGesture(
                            freeFloatingDragGesture(geometry: geometry),
                            SimultaneousGesture(
                                horizontalSwipeGesture,
                                pinchToResizeGesture
                            )
                        )
                    )
                    .onAppear {
                        // 🔥 YOUTUBE PARITY: Initialize position to bottom-right corner
                        if position == .zero {
                            position = CGPoint(
                                x: geometry.size.width - (playerSize.width / 2) - 20,
                                y: geometry.size.height - (playerSize.height / 2) - 100
                            )
                        }
                    }
                    .drawingGroup(opaque: false, colorMode: .linear)  // 🔥 OPTIMIZED: Better rendering
                    .compositingGroup()
                    .allowsHitTesting(true)
            }
            .zIndex(10000)
            .background(Color.clear)
            .onAppear {
                // 🔥 SYNC INITIAL STATE: Get volume and speed from player
                if let player = globalPlayer.player {
                    volume = player.volume
                    playbackSpeed = player.rate
                }
                print("🎥 [MiniPlayer] Mini player appeared - hasActiveSession: \(globalPlayer.hasActivePlaybackSession)")
            }
            .onDisappear {
                print("⚠️ [MiniPlayer] Mini player disappeared unexpectedly - hasActiveSession: \(globalPlayer.hasActivePlaybackSession)")
            }
        }
    }
    
    @ViewBuilder
    private func miniPlayerView(video: Video, geometry: GeometryProxy) -> some View {
        // 🔥 YOUTUBE-STYLE PIP MINI PLAYER
        VStack(spacing: 0) {
            miniPlayerVideoSection(video: video, geometry: geometry)
        }
        .background(Color.black)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
    }
    
    @ViewBuilder
    private func miniPlayerVideoSection(video: Video, geometry _: GeometryProxy) -> some View {
        let thumbnailView: some View = Group {
            if let u = URL(string: video.thumbnailURL) {
                AppAsyncImage(url: u) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Rectangle().fill(Color.black) }
                    .clipped()
            } else {
                Rectangle().fill(Color.black)
            }
        }
        
        let videoPlayerView: some View = Group {
            if let player = globalPlayer.player {
                RawPlayerLayerView(player: player, videoGravity: .resizeAspect)
                    .aspectRatio(16/9, contentMode: .fit)
                    .allowsHitTesting(false)
                    .clipped()
                    // 🔥 FIX: Prevent video glitching - ensure proper rendering
                    .drawingGroup() // Optimize rendering performance
                    .compositingGroup() // Isolate rendering context
            } else {
                thumbnailView
            }
        }
        
        let playerWidth = playerSize.width
        let playerHeight = playerSize.height
        
        return ZStack {
            // Video Player
            videoPlayerView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)

            if globalPlayer.isBuffering {
                PlayerBufferingIndicator()
            }

            if !globalPlayer.isPlayerReady, globalPlayer.currentVideo != nil {
                PlayerNotReadyChrome(
                    title: video.title,
                    onRetry: { globalPlayer.ensurePlayerAttached() }
                )
            }
            
            // Dark gradient overlay for better contrast
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.clear, Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            
            // Top Controls
            VStack {
                HStack {
                    // Close button
                    Button(action: closePlayer) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // Video title (centered) with @channel and #hashtag support
                    InteractiveRichTextTitleView(
                        title: video.title,
                        onChannelTap: { channelName in
                            // Navigate to channel
                            print("📺 Mini player: Navigate to channel: \(channelName)")
                        },
                        onHashtagTap: { hashtag in
                            // Navigate to hashtag search
                            print("🔍 Mini player: Navigate to hashtag: \(hashtag)")
                        },
                        textColor: .white  // 🔥 FIX: White text for visibility on video background
                    )
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .frame(maxWidth: 180)
                    
                    Spacer()
                    
                    // Settings/PiP button
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        // Expand back to full VideoDetailView
                        globalPlayer.expandPlayer()
                    }) {
                        Image(systemName: "pip.enter")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                
                Spacer()
                
                // Bottom Controls
                VStack(spacing: 12) {
                    // Play controls
                    HStack(spacing: 48) {
                        // Rewind 10s
                        Button(action: {
                            globalPlayer.seekBackward()
                            HapticManager.shared.impact(style: .medium)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(width: 52, height: 52)
                                
                                Image(systemName: "gobackward.10")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        // Play/Pause
                        Button(action: {
                            globalPlayer.togglePlayPause()
                            HapticManager.shared.impact(style: .light)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(width: 62, height: 62)
                                
                                Image(systemName: globalPlayer.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        // Forward 10s
                        Button(action: {
                            globalPlayer.seekForward()
                            HapticManager.shared.impact(style: .medium)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(width: 52, height: 52)
                                
                                Image(systemName: "goforward.10")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Progress bar
                    scrubbableProgressBar
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)
            }
        }
        .frame(width: playerWidth, height: playerHeight)
        .cornerRadius(16)
        .clipped()
    }
}

#Preview {
    ZStack {
        AppTheme.Colors.background
            .ignoresSafeArea()
        
        // Mock home view content
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0..<10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Colors.cardBackground)
                        .frame(height: 200)
                        .overlay(
                            VStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppTheme.Colors.primary)
                                
                                Text("Video Content \(i + 1)")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                            }
                        )
                }
            }
            .padding()
        }
        
        FloatingMiniPlayer()
    }
    .environmentObject(PreviewSafeGlobalVideoPlayerManager())
    .onAppear {
        // Mock setup for preview
        let mockManager = PreviewSafeGlobalVideoPlayerManager()
        mockManager.currentVideo = Video.sampleVideos[0]
    }
}