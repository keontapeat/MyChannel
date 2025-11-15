//
//  FloatingMiniPlayer.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVKit
import AVFoundation

struct FloatingMiniPlayer: View {
    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared
    @GestureState private var dragState = CGSize.zero  // For YouTube-style swipe down gesture
    @State private var dragOffset: CGFloat = 0  // YouTube-style swipe down offset
    
    // 🔥 ANIMATION FIX: Track if animation has been shown to prevent multiple animations
    @State private var hasShownAnimation = false
    @State private var lastVideoId: String? = nil
    
    // 🔥 YOUTUBE PARITY: Mini player controls (only what's needed)
    @State private var volume: Float = 1.0
    @State private var playbackSpeed: Float = 1.0
    
    // State for old controls (keeping for compatibility, but YouTube-style doesn't use them)
    @State private var showingVolumeSlider = false
    @State private var showingSpeedMenu = false
    @State private var showingQualityMenu = false
    @State private var selectedQuality: String = "Auto"
    @State private var showingControls = false
    @State private var lastTapTime: Date = Date()
    @State private var tapCount = 0
    
    var body: some View {
        // 🔥 TRUE PICTURE-IN-PICTURE: System PiP that works outside app and is resizable
        Group {
            // 🔥 CRITICAL: Only show mini player if ALL conditions are met
            // Must check showingFullscreen FIRST to prevent showing when going fullscreen
            if let video = globalPlayer.currentVideo,
               !globalPlayer.showingFullscreen,  // Check fullscreen FIRST
               globalPlayer.shouldShowMiniPlayer,
               !globalPlayer.isTransitioning {  // Don't show during transitions
                
                ZStack {
                    // 🔥 CRITICAL: Use system PiP for true Picture-in-Picture
                    if let player = globalPlayer.player {
                        // Hidden view that drives system PiP
                        PlayerPiPContainerView(
                            player: player,
                            isPictureInPictureActive: Binding(
                                get: { globalPlayer.isPiPActive },
                                set: { globalPlayer.isPiPActive = $0 }
                            )
                        )
                        .frame(width: 1, height: 1)
                        .opacity(0)
                        .allowsHitTesting(false)
                        .onAppear {
                            // 🔥 AUTO-START PiP when mini player appears
                            if AVPictureInPictureController.isPictureInPictureSupported() {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    if !globalPlayer.isPiPActive {
                                        globalPlayer.isPiPActive = true
                                        print("📺 [FloatingMiniPlayer] Auto-starting system PiP")
                                    }
                                }
                            }
                        }
                    }
                    
                    // 🔥 FALLBACK: In-app mini player (only shows if PiP not supported or fails)
                    if !AVPictureInPictureController.isPictureInPictureSupported() || !globalPlayer.isPiPActive {
                        GeometryReader { geometry in
                            VStack {
                                Spacer()
                                
                                // In-app mini player (fallback)
                                youtubeStyleMiniPlayer(video: video, geometry: geometry)
                                    .offset(y: dragState.height + dragOffset)
                                    .gesture(
                                        DragGesture(minimumDistance: 10)
                                            .updating($dragState) { value, state, _ in
                                                if value.translation.height > 0 {
                                                    state = CGSize(width: 0, height: value.translation.height)
                                                }
                                            }
                                            .onEnded { value in
                                                if value.translation.height > 100 {
                                                    globalPlayer.closePlayer()
                                                    HapticManager.shared.impact(style: .medium)
                                                } else {
                                                    dragOffset = 0
                                                }
                                            }
                                    )
                                    .frame(height: 80)
                                    .padding(.bottom, geometry.safeAreaInsets.bottom + 80)
                            }
                        }
                        .zIndex(10000)
                        // 🔥 FIX: Single, clean animation - only animate on first appearance
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: globalPlayer.shouldShowMiniPlayer)
                    }
                }
                .onAppear {
                    // 🔥 ANIMATION FIX: Only show animation once per video
                    let currentVideoId = globalPlayer.currentVideo?.id
                    if currentVideoId != lastVideoId {
                        // New video - reset animation flag
                        hasShownAnimation = false
                        lastVideoId = currentVideoId
                    }
                    
                    // 🔥 APPLE BEST PRACTICE: Ensure player is attached and sync state when view appears
                    Task { @MainActor in
                        // 🔥 CRITICAL: Always ensure player is attached first
                        globalPlayer.ensurePlayerAttached()
                        
                        // Wait a moment for player to be ready
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        
                        if let player = globalPlayer.player {
                            // Sync volume and speed from actual player
                            volume = player.volume
                            playbackSpeed = player.rate
                            
                            // 🔥 APPLE BEST PRACTICE: Use timeControlStatus for accurate play state
                            let actualIsPlaying = player.timeControlStatus == .playing
                            let expectedIsPlaying = globalPlayer.isPlaying
                            
                            print("✅ [MiniPlayer] Player found - rate: \(player.rate), timeControlStatus: \(player.timeControlStatus.rawValue)")
                            print("📊 [MiniPlayer] Expected playing: \(expectedIsPlaying), Actual playing: \(actualIsPlaying)")
                            
                            // Sync state if mismatch
                            if expectedIsPlaying != actualIsPlaying {
                                if expectedIsPlaying {
                                    print("▶️ [MiniPlayer] Resuming playback - state mismatch")
                                    player.play()
                                } else {
                                    print("⏸️ [MiniPlayer] Pausing playback - state mismatch")
                                    player.pause()
                                }
                            }
                        } else {
                            print("⚠️ [MiniPlayer] Player still not ready - showing thumbnail")
                            // Try one more time to ensure attachment
                            globalPlayer.ensurePlayerAttached()
                        }
                        
                        print("🎥 [MiniPlayer] Mini player appeared - shouldShow: \(globalPlayer.shouldShowMiniPlayer), video: \(globalPlayer.currentVideo?.title ?? "none"), player exists: \(globalPlayer.player != nil)")
                    }
                }
                .onDisappear {
                    print("⚠️ [MiniPlayer] Mini player disappeared unexpectedly - shouldShow: \(globalPlayer.shouldShowMiniPlayer)")
                }
                .task {
                    // 🔥 APPLE BEST PRACTICE: Monitor player state and sync when needed
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // Check every 1 second
                        
                        await MainActor.run {
                            guard let player = globalPlayer.player else {
                                // Player not available - ensure it's set up
                                if globalPlayer.shouldShowMiniPlayer && globalPlayer.currentVideo != nil {
                                    print("⚠️ [MiniPlayer] Task: Player not available - ensuring attachment")
                                    globalPlayer.ensurePlayerAttached()
                                }
                                return
                            }
                            
                            // 🔥 APPLE BEST PRACTICE: Use timeControlStatus for accurate state checking
                            let actualIsPlaying = player.timeControlStatus == .playing
                            let expectedIsPlaying = globalPlayer.isPlaying
                            
                            // Sync if mismatch
                            if expectedIsPlaying != actualIsPlaying {
                                if expectedIsPlaying {
                                    print("▶️ [MiniPlayer] Task: Resuming playback - state sync")
                                    player.play()
                                } else {
                                    print("⏸️ [MiniPlayer] Task: Pausing playback - state sync")
                                    player.pause()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - AVPlayerLayer View (No Error UI)
    /// Custom player layer that doesn't show VideoPlayer's ugly error UI
    private struct MiniPlayerLayerView: UIViewRepresentable {
        let player: AVPlayer?
        
        func makeUIView(context: Context) -> PlayerContainerView {
            let view = PlayerContainerView()
            view.backgroundColor = .black
            view.playerLayer.videoGravity = .resizeAspectFill
            // Only set player if it's valid
            if let player = player,
               let item = player.currentItem,
               item.status != .failed {
                view.playerLayer.player = player
            } else {
                view.playerLayer.player = nil // Don't show failed player
            }
            return view
        }
        
        func updateUIView(_ uiView: PlayerContainerView, context: Context) {
            // Only update if player is valid
            if let player = player,
               let item = player.currentItem,
               item.status != .failed {
                uiView.playerLayer.player = player
            } else {
                uiView.playerLayer.player = nil // Clear failed player
            }
        }
        
        final class PlayerContainerView: UIView {
            override class var layerClass: AnyClass { AVPlayerLayer.self }
            var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        }
    }
    
    // MARK: - Utils
    private func formatTime(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }
    
    private func formatViewCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
    
    // MARK: - Calculation Methods (Removed - using free-floating position instead)
    
    // 🔥 YOUTUBE 100% PARITY: Bottom-anchored mini player
    @ViewBuilder
    private func youtubeStyleMiniPlayer(video: Video, geometry: GeometryProxy) -> some View {
        HStack(spacing: 12) {
            // Left: Video thumbnail/player (YouTube style)
            ZStack {
                // 🔥 CRITICAL: Always show thumbnail (prevents error UI)
                thumbnailView
                    .frame(width: 140, height: 78)
                    .cornerRadius(8)
                    .clipped()
                
                // Show video layer ONLY when player is 100% ready
                if let player = globalPlayer.player,
                   let playerItem = player.currentItem,
                   playerItem.status == .readyToPlay,
                   player.status == .readyToPlay,
                   playerItem.error == nil {
                    MiniPlayerLayerView(player: player)
                        .frame(width: 140, height: 78)
                        .cornerRadius(8)
                        .clipped()
                }
                
                // Play button overlay when paused
                if !globalPlayer.isPlaying {
                    Image(systemName: "play.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }
            .onTapGesture {
                globalPlayer.togglePlayPause()
            }
            
            // Right: Title and controls (YouTube style)
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(video.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                // Creator name
                Text(video.creator.displayName)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                
                Spacer()
            }
            
            Spacer()
            
            // Controls: Play/Pause
            Button(action: {
                globalPlayer.togglePlayPause()
                HapticManager.shared.impact(style: .light)
            }) {
                Image(systemName: globalPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(width: 44, height: 44)
            }
            
            // Close button
            Button(action: {
                globalPlayer.closePlayer()
                HapticManager.shared.impact(style: .light)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(AppTheme.Colors.surface)
                .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
        )
        .overlay(
            // Progress bar at top (YouTube style)
            VStack {
                Rectangle()
                    .fill(AppTheme.Colors.primary)
                    .frame(height: 2)
                    .frame(width: geometry.size.width * CGFloat(globalPlayer.currentProgress))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
        )
    }
    
    @ViewBuilder
    private func miniPlayerView(video: Video, geometry: GeometryProxy) -> some View {
        // 🔥 YOUTUBE-STYLE PIP MINI PLAYER (legacy - keeping for reference)
        VStack(spacing: 0) {
            miniPlayerVideoSection(video: video, geometry: geometry)
        }
        .background(Color.black)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
    }
    
    // Thumbnail view helper (used by YouTube-style mini player)
    @ViewBuilder
    private var thumbnailView: some View {
        if let video = globalPlayer.currentVideo,
           let u = URL(string: video.thumbnailURL) {
            AppAsyncImage(url: u) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.black)
            }
            .clipped()
        } else {
            Rectangle()
                .fill(Color.black)
        }
    }
    
    @ViewBuilder
    private func miniPlayerVideoSection(video: Video, geometry: GeometryProxy) -> some View {
        let thumbnailView: some View = Group {
            if let u = URL(string: video.thumbnailURL) {
                AppAsyncImage(url: u) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Rectangle().fill(Color.black) }
                    .clipped()
            } else {
                Rectangle().fill(Color.black)
            }
        }
        
        let videoPlayerView: some View = Group {
            // 🔥 TEMPORARY FIX: ALWAYS show thumbnail to eliminate error UI completely
            // Once we confirm error UI is gone, we'll add back video playback
            thumbnailView
            
            // TODO: Re-enable video playback once error UI is confirmed fixed
            // if let player = globalPlayer.player,
            //    let playerItem = player.currentItem,
            //    playerItem.status == .readyToPlay,
            //    player.status == .readyToPlay,
            //    playerItem.error == nil {
            //     MiniPlayerLayerView(player: player)
            //         .aspectRatio(16/9, contentMode: .fit)
            //         .allowsHitTesting(false)
            //         .clipped()
            //         .background(Color.black)
            // }
        }
        
        let playerWidth = geometry.size.width - 40
        let playerHeight = playerWidth * 9 / 16
        
        ZStack {
            // Video Player
            videoPlayerView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            
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
                        // Toggle PiP or expand
                        NotificationCenter.default.post(name: NSNotification.Name("PresentVideoDetailFromMiniPlayer"), object: nil)
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
    
    @ViewBuilder
    private func miniPlayerInfoSection(video: Video) -> some View {
        HStack(spacing: 10) {
            videoMetadataSection(video: video)
            miniPlayerControlsCluster
        }
    }
    
    @ViewBuilder
    private func videoMetadataSection(video: Video) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            videoTitleRow(video: video)
            creatorInfoRow(video: video)
            
            if let upNext = globalPlayer.upNextVideo {
                upNextPreview(upNext: upNext)
            }
            
            progressBarWithTime
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private func videoTitleRow(video: Video) -> some View {
        HStack(spacing: 6) {
            Text(video.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            if video.isLiveStream {
                liveBadge
            }
        }
    }
    
    private var liveBadge: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
            
            Text("LIVE")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.red)
        .cornerRadius(4)
    }
    
    @ViewBuilder
    private func creatorInfoRow(video: Video) -> some View {
        HStack(spacing: 6) {
            Text(video.creator.displayName)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .lineLimit(1)
            
            if video.isLiveStream {
                liveViewerCount(viewCount: video.viewCount)
            }
        }
    }
    
    @ViewBuilder
    private func liveViewerCount(viewCount: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "eye.fill")
                .font(.system(size: 8))
            Text("\(formatViewCount(viewCount))")
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundColor(AppTheme.Colors.textSecondary)
    }
    
    @ViewBuilder
    private func upNextPreview(upNext: Video) -> some View {
        HStack(spacing: 6) {
            Text("Up Next:")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text(upNext.title)
                .font(.system(size: 9, weight: .regular))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
    
    private var progressBarWithTime: some View {
        VStack(spacing: 2) {
            scrubbableProgressBar
            
            HStack {
                Text(formatTime(globalPlayer.currentTime))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Spacer()
                Text(formatTime(globalPlayer.duration))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
    }
    
    private var miniPlayerControlsCluster: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                volumeControl
                speedControl
                qualityControl
                expandButton
                closeButton
            }
        }
    }
    
    private var volumeControl: some View {
        ZStack {
                        Button(action: { 
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingVolumeSlider.toggle()
                                if showingVolumeSlider {
                                    showingSpeedMenu = false
                                    showingQualityMenu = false
                                }
                            }
                            HapticManager.shared.impact(style: .light) 
                        }) {
                            Image(systemName: volume > 0.5 ? "speaker.wave.2.fill" : volume > 0 ? "speaker.wave.1.fill" : "speaker.slash.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(showingVolumeSlider ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                                .padding(6)
                                .background(showingVolumeSlider ? AppTheme.Colors.primary.opacity(0.15) : AppTheme.Colors.textSecondary.opacity(0.08))
                                .clipShape(Circle())
                        }
                        
                        // Volume slider popup
                        if showingVolumeSlider {
                            VStack(spacing: 8) {
                                Slider(value: $volume, in: 0...1)
                                    .tint(AppTheme.Colors.primary)
                                    .frame(width: 120)
                                    .onChange(of: volume) { newValue in
                                        globalPlayer.player?.volume = newValue
                                    }
                                
                                Text("\(Int(volume * 100))%")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.Colors.cardBackground.opacity(0.98)))
                                    .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
                            )
                            .offset(x: -70, y: -80)
                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                        }
        }
    }
    
    private var speedControl: some View {
        ZStack {
            Button(action: { 
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showingSpeedMenu.toggle()
                    if showingSpeedMenu {
                        showingVolumeSlider = false
                        showingQualityMenu = false
                    }
                }
                HapticManager.shared.impact(style: .light) 
            }) {
                speedButtonLabel
            }
            
            if showingSpeedMenu {
                speedMenuPopup
            }
        }
    }
    
    private var speedButtonLabel: some View {
        Text(String(format: "%.2gx", playbackSpeed))
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(showingSpeedMenu ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
            .padding(6)
            .background(showingSpeedMenu ? AppTheme.Colors.primary.opacity(0.15) : AppTheme.Colors.textSecondary.opacity(0.08))
            .clipShape(Circle())
    }
    
    private var speedMenuPopup: some View {
        VStack(spacing: 4) {
            ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { speed in
                speedMenuItem(speed: speed)
            }
        }
        .padding(8)
        .frame(width: 140)
        .background(speedMenuBackground)
        .offset(x: -75, y: -140)
        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
    }
    
    private func speedMenuItem(speed: Double) -> some View {
        Button(action: {
            playbackSpeed = Float(speed)
            globalPlayer.player?.rate = Float(speed)
            withAnimation {
                showingSpeedMenu = false
            }
            HapticManager.shared.impact(style: .light)
        }) {
            HStack {
                Text(speed == 1.0 ? "Normal" : String(format: "%.2gx", speed))
                    .font(.system(size: 12, weight: Float(speed) == playbackSpeed ? .bold : .regular))
                    .foregroundColor(Float(speed) == playbackSpeed ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                
                Spacer()
                
                if Float(speed) == playbackSpeed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Float(speed) == playbackSpeed ? AppTheme.Colors.primary.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
    }
    
    private var speedMenuBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.Colors.cardBackground.opacity(0.98)))
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
    }
    
    private var qualityControl: some View {
        ZStack {
                        Button(action: { 
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingQualityMenu.toggle()
                                if showingQualityMenu {
                                    showingVolumeSlider = false
                                    showingSpeedMenu = false
                                }
                            }
                            HapticManager.shared.impact(style: .light) 
                        }) {
                            Text(selectedQuality == "Auto" ? "HD" : selectedQuality)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(showingQualityMenu ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                                .padding(6)
                                .background(showingQualityMenu ? AppTheme.Colors.primary.opacity(0.15) : AppTheme.Colors.textSecondary.opacity(0.08))
                                .clipShape(Circle())
                        }
                        
                        // Quality menu popup
                        if showingQualityMenu {
                            VStack(spacing: 4) {
                                ForEach(["Auto", "4K", "1080p", "720p", "480p", "360p"], id: \.self) { quality in
                                    Button(action: {
                                        selectedQuality = quality
                                        // TODO: Implement actual quality switching via HLS stream selection
                                        withAnimation {
                                            showingQualityMenu = false
                                        }
                                        HapticManager.shared.impact(style: .light)
                                    }) {
                                        HStack {
                                            Text(quality)
                                                .font(.system(size: 12, weight: selectedQuality == quality ? .bold : .regular))
                                                .foregroundColor(selectedQuality == quality ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                                            
                                            Spacer()
                                            
                                            if selectedQuality == quality {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(AppTheme.Colors.primary)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedQuality == quality ? AppTheme.Colors.primary.opacity(0.1) : Color.clear)
                                        .cornerRadius(6)
                                    }
                                }
                            }
                            .padding(8)
                            .frame(width: 140)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.Colors.cardBackground.opacity(0.98)))
                                    .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
                            )
                            .offset(x: -75, y: -120)
                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                        }
        }
    }
    
    private var expandButton: some View {
        Button(action: { 
            // 🔥 FIX: Call globalPlayer.expandPlayer() to go fullscreen
            globalPlayer.expandPlayer()
            HapticManager.shared.impact(style: .light) 
        }) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(6)
                .background(AppTheme.Colors.textSecondary.opacity(0.08))
                .clipShape(Circle())
        }
    }
    
    private var closeButton: some View {
        Button(action: { 
            // 🔥 FIX: Call globalPlayer.closePlayer() to close mini player
            globalPlayer.closePlayer()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(6)
                .background(AppTheme.Colors.textSecondary.opacity(0.08))
                .clipShape(Circle())
        }
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(height: 3)
                
                // Progress track
                Rectangle()
                    .fill(AppTheme.Colors.primary)
                    .frame(
                        width: geometry.size.width * CGFloat(globalPlayer.currentProgress),
                        height: 3
                    )
                    .animation(.linear(duration: 0.1), value: globalPlayer.currentProgress)
            }
        }
        .frame(height: 3)
    }
    
    
    
    private var miniPlayerBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.Colors.cardBackground.opacity(0.95))
            )
            .shadow(
                color: AppTheme.Colors.textPrimary.opacity(0.12),
                radius: 20,
                x: 0,
                y: -8
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 0.5)
            )
    }
    
    private func calculateBottomPadding(geometry: GeometryProxy) -> CGFloat {
        let safeAreaBottom = geometry.safeAreaInsets.bottom
        let tabBarHeight: CGFloat = 80
        // Additional fixed reserve to avoid feed reflow
        return safeAreaBottom + tabBarHeight + 24
    }
    
    // MARK: - Gesture Handling (YouTube-style swipe down only)
    // Old free-floating gestures removed - now using YouTube-style bottom-anchored player
    
    // MARK: - Actions
    private func expandPlayer() {
        withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.8)) {
            globalPlayer.expandPlayer()
        }
        HapticManager.shared.impact(style: .medium)
    }
    
    private func closePlayer() {
        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
            globalPlayer.closePlayer()
        }
        HapticManager.shared.impact(style: .light)
    }
    
    // MARK: - Navigation Helpers (for future swipe gestures)
    private func navigateToPreviousVideo() {
        globalPlayer.playPreviousVideo()
    }
    
    private func navigateToNextVideo() {
        globalPlayer.playNextVideo()
    }
    
    // MARK: - 🔥 YOUTUBE PARITY: Enhanced Components
    
    private var scrubbableProgressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(height: 3)
                
                // 🔥 YOUTUBE PARITY: Chapter markers
                if let video = globalPlayer.currentVideo,
                   let chapters = video.chapters,
                   !chapters.isEmpty,
                   globalPlayer.duration > 0 {
                    ForEach(chapters, id: \.id) { chapter in
                        let chapterProgress = chapter.start / globalPlayer.duration
                        Rectangle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 1, height: 6)
                            .offset(x: geometry.size.width * CGFloat(chapterProgress))
                    }
                }
                
                // Progress track
                Rectangle()
                    .fill(AppTheme.Colors.primary)
                    .frame(
                        width: geometry.size.width * CGFloat(globalPlayer.currentProgress),
                        height: 3
                    )
                    .animation(.linear(duration: 0.1), value: globalPlayer.currentProgress)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let progress = min(max(0, value.location.x / geometry.size.width), 1)
                        globalPlayer.seek(to: progress)
                    }
                    .onEnded { value in
                        let progress = min(max(0, value.location.x / geometry.size.width), 1)
                        globalPlayer.seek(to: progress)
                        HapticManager.shared.impact(style: .light)
                    }
            )
        }
        .frame(height: 3)
    }
    
    private var seekFeedbackOverlay: some View {
        HStack {
            // Left side rewind feedback
            VStack {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("-10s")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(8)
            .background(.black.opacity(0.6))
            .cornerRadius(8)
            .opacity(0.8)
            
            Spacer()
            
            // Right side forward feedback
            VStack {
                Image(systemName: "goforward.10")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("+10s")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(8)
            .background(.black.opacity(0.6))
            .cornerRadius(8)
            .opacity(0.8)
        }
        .padding(.horizontal, 8)
    }
    
    private var advancedControlsOverlay: some View {
        VStack {
            HStack {
                Spacer()
                
                // Settings menu
                Menu {
                    Button("Quality") { showingQualityMenu = true }
                    Button("Speed") { showingSpeedMenu = true }
                    Button("Captions") { /* Toggle captions */ }
                    Button(globalPlayer.isPiPActive ? "Exit Picture in Picture" : "Picture in Picture") { 
                        globalPlayer.togglePictureInPicture()
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }
            .padding(8)
            
            Spacer()
            
            // Bottom controls
            HStack {
                // Previous video
                Button(action: {
                    globalPlayer.playPreviousVideo()
                }) {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(globalPlayer.hasPreviousVideo ? .white : .white.opacity(0.3))
                        .padding(8)
                        .background(.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .disabled(!globalPlayer.hasPreviousVideo)
                
                Spacer()
                
                // Next video
                Button(action: {
                    globalPlayer.playNextVideo()
                }) {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(globalPlayer.hasNextVideo ? .white : .white.opacity(0.3))
                        .padding(8)
                        .background(.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .disabled(!globalPlayer.hasNextVideo)
            }
            .padding(8)
        }
    }
    
    // MARK: - 🔥 YOUTUBE PARITY: Gesture Handlers
    
    private func handleSingleTap() {
        let now = Date()
        if now.timeIntervalSince(lastTapTime) < 0.3 {
            tapCount += 1
        } else {
            tapCount = 1
        }
        lastTapTime = now
        
        if tapCount == 1 {
            // Single tap - KEEP MINI PLAYER VISIBLE, just toggle controls
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if self.tapCount == 1 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.showingControls.toggle()
                    }
                    // Auto-hide controls after 3 seconds (but keep mini player visible)
                    if self.showingControls {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                self.showingControls = false
                            }
                        }
                    }
                }
            }
        } else if tapCount == 2 {
            // Double tap - expand to fullscreen
            globalPlayer.expandPlayer()
        }
    }
    
    private func showSeekFeedback(isForward: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            showingControls = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.showingControls = false
            }
        }
    }
    
    // MARK: - Navigation functions already declared above (removed duplicate)
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
        mockManager.shouldShowMiniPlayer = true
        mockManager.isMiniplayer = true
    }
}