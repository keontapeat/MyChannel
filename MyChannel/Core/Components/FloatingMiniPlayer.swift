//
//  FloatingMiniPlayer.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVKit

struct FloatingMiniPlayer: View {
    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var lastDragTranslation: CGFloat = 0
    
    // 🔥 YOUTUBE PARITY: Advanced mini player controls
    @State private var showingControls = false
    @State private var showingVolumeSlider = false
    @State private var showingSpeedMenu = false
    @State private var showingQualityMenu = false
    @State private var playerSize: CGSize = CGSize(width: 140, height: 78)
    @State private var isResizing = false
    @State private var lastTapTime: Date = Date()
    @State private var tapCount = 0
    @State private var volume: Float = 1.0
    @State private var playbackSpeed: Float = 1.0
    @State private var selectedQuality: String = "Auto"
    
    var body: some View {
        if globalPlayer.shouldShowMiniPlayer && !globalPlayer.showingFullscreen,
           let video = globalPlayer.currentVideo {
            
            GeometryReader { geometry in
                VStack { // isolate from parent layout to reduce layout thrash
                    Spacer()
                    
                    miniPlayerView(video: video, geometry: geometry)
                        .offset(y: calculateOffset())
                        .opacity(calculateOpacity())
                        .scaleEffect(calculateScale())
                        .gesture(
                            SimultaneousGesture(
                                miniPlayerDragGesture,
                                SimultaneousGesture(
                                    horizontalSwipeGesture,
                                    pinchToResizeGesture
                                )
                            )
                        )
                        .transaction { tx in tx.disablesAnimations = true }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .allowsHitTesting(true)
            .zIndex(998) // Below tab bar but above content
            .onAppear {
                // 🔥 SYNC INITIAL STATE: Get volume and speed from player
                if let player = globalPlayer.player {
                    volume = player.volume
                    playbackSpeed = player.rate
                }
            }
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
    
    // MARK: - Calculation Methods
    private func calculateOffset() -> CGFloat {
        let baseOffset = isDragging ? dragOffset : globalPlayer.miniplayerOffset
        return max(-50, baseOffset) // Prevent dragging too far up
    }
    
    private func calculateOpacity() -> Double {
        let totalOffset = calculateOffset()
        if totalOffset > 0 {
            return max(0.1, 1.0 - (totalOffset / 150.0))
        } else {
            return 1.0
        }
    }
    
    private func calculateScale() -> CGFloat {
        let totalOffset = calculateOffset()
        if totalOffset > 0 {
            return max(0.85, 1.0 - (totalOffset / 400.0))
        } else {
            return min(1.05, 1.0 + (abs(totalOffset) / 200.0))
        }
    }
    
    private func miniPlayerView(video: Video, geometry: GeometryProxy) -> some View {
        HStack(spacing: 10) {
            miniPlayerVideoSection(video: video)
            miniPlayerInfoSection(video: video)
        }
        .padding(10)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
    
    private func miniPlayerVideoSection(video: Video) -> some View {
        let thumbnailView: some View = Group {
            if let u = URL(string: video.thumbnailURL) {
                AppAsyncImage(url: u) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Rectangle().fill(AppTheme.Colors.surface) }
                    .clipped()
            } else {
                Rectangle().fill(AppTheme.Colors.surface)
            }
        }
        
        let videoPlayerView: some View = Group {
            if let player = globalPlayer.player {
                VideoPlayer(player: player)
                    .aspectRatio(16/9, contentMode: .fill)
                    .allowsHitTesting(false)
                    .clipped()
            } else {
                thumbnailView
            }
        }
        
        return ZStack(alignment: .center) {
            videoPlayerView
            // 🔥 YOUTUBE PARITY: Enhanced video player with gestures
            ZStack(alignment: .center) {
                videoPlayerView
                
                // 🔥 BUFFERING INDICATOR
                if !globalPlayer.isPlaying && globalPlayer.player?.rate == 0 && globalPlayer.player?.currentItem != nil {
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.6))
                            .frame(width: 40, height: 40)
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                }
                
                // 🔥 DOUBLE TAP ZONES: Left (rewind) and Right (forward)
                HStack(spacing: 0) {
                    // Left side - Rewind 10s
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            globalPlayer.seekBackward()
                            showSeekFeedback(isForward: false)
                            HapticManager.shared.impact(style: .medium)
                        }
                        .onTapGesture(count: 1) {
                            handleSingleTap()
                        }
                    
                    // Center - Play/Pause (smaller area)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 40)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            globalPlayer.togglePlayPause()
                            HapticManager.shared.impact(style: .light)
                        }
                    
                    // Right side - Forward 10s
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            globalPlayer.seekForward()
                            showSeekFeedback(isForward: true)
                            HapticManager.shared.impact(style: .medium)
                        }
                        .onTapGesture(count: 1) {
                            handleSingleTap()
                        }
                }
                
                // 🔥 SEEK FEEDBACK ANIMATION
                if showingControls {
                    seekFeedbackOverlay
                }
                
                // Play/Pause button (only when not playing or controls visible)
                if !globalPlayer.isPlaying || showingControls {
                    Button(action: { globalPlayer.togglePlayPause(); HapticManager.shared.impact(style: .light) }) {
                        Image(systemName: globalPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .opacity(showingControls ? 1.0 : 0.8)
                }

                // 🔥 ADVANCED CONTROLS OVERLAY
                if showingControls {
                    advancedControlsOverlay
                }
                
                // Close button (always visible)
                VStack { 
                    HStack { 
                        Spacer()
                        Button(action: closePlayer) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(6)
                    Spacer() 
                }
            }
            .frame(width: playerSize.width, height: playerSize.height)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
        }
    }
    
    private func miniPlayerInfoSection(video: Video) -> some View {
        HStack(spacing: 10) {
            videoMetadataSection(video: video)
            miniPlayerControlsCluster
        }
    }
    
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
    
    private func liveViewerCount(viewCount: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "eye.fill")
                .font(.system(size: 8))
            Text("\(formatViewCount(viewCount))")
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundColor(AppTheme.Colors.textSecondary)
    }
    
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
    
    private var volumeControlButton: some View {
        Button(action: { globalPlayer.player?.volume = globalPlayer.player?.volume == 0 ? 1 : 0 }) {
            Image(systemName: (globalPlayer.player?.volume ?? 0) > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(6)
                .background(AppTheme.Colors.textSecondary.opacity(0.08))
                .clipShape(Circle())
        }
    }
    
    private var speedControlButton: some View {
        Button(action: {}) {
            Image(systemName: "gauge")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(6)
                .background(AppTheme.Colors.textSecondary.opacity(0.08))
                .clipShape(Circle())
        }
    }
    
    private var qualityControlButton: some View {
        Button(action: {}) {
            Image(systemName: "gearshape")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(6)
                .background(AppTheme.Colors.textSecondary.opacity(0.08))
                .clipShape(Circle())
        }
    }
    
    private var pipButton: some View {
        Button(action: { globalPlayer.togglePictureInPicture() }) {
            Image(systemName: "pip")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(6)
                .background(AppTheme.Colors.textSecondary.opacity(0.08))
                .clipShape(Circle())
        }
    }
    
    private var miniPlayerControlsCluster: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                // Volume control with popup
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
                    
                    // Speed control with menu
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
                            Text(String(format: "%.2gx", playbackSpeed))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(showingSpeedMenu ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                                .padding(6)
                                .background(showingSpeedMenu ? AppTheme.Colors.primary.opacity(0.15) : AppTheme.Colors.textSecondary.opacity(0.08))
                                .clipShape(Circle())
                        }
                        
                        // Speed menu popup
                        if showingSpeedMenu {
                            VStack(spacing: 4) {
                                ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { speed in
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
                                                .font(.system(size: 12, weight: playbackSpeed == speed ? .bold : .regular))
                                                .foregroundColor(playbackSpeed == speed ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                                            
                                            Spacer()
                                            
                                            if playbackSpeed == speed {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(AppTheme.Colors.primary)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(playbackSpeed == speed ? AppTheme.Colors.primary.opacity(0.1) : Color.clear)
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
                            .offset(x: -75, y: -140)
                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                        }
                    }
                }
                
                HStack(spacing: 6) {
                    // Quality selector
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
                    
                    // Expand to fullscreen
                    Button(action: { expandPlayer(); HapticManager.shared.impact(style: .light) }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .padding(6)
                            .background(AppTheme.Colors.textSecondary.opacity(0.08))
                            .clipShape(Circle())
                    }
                    
                    // Close player
                    Button(action: closePlayer) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .padding(6)
                            .background(AppTheme.Colors.textSecondary.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
            }
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
    
    private func videoInfoAndControls(video: Video) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(video.creator.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            // Control buttons
            VStack(alignment: .trailing, spacing: 8) {
                // Title + channel
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(video.title).font(.system(size: 14, weight: .medium)).foregroundColor(AppTheme.Colors.textPrimary).lineLimit(1)
                        Text(video.creator.displayName).font(.system(size: 12)).foregroundColor(AppTheme.Colors.textSecondary).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    // Play/Pause control
                    Button(action: { globalPlayer.togglePlayPause(); HapticManager.shared.impact(style: .light) }) {
                        Image(systemName: globalPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(AppTheme.Colors.primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())

                    // Close control
                    Button(action: closePlayer) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .padding(8)
                            .background(AppTheme.Colors.textSecondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                // Scrubbable slider + time
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { Double(globalPlayer.currentProgress) },
                            set: { globalPlayer.seek(to: max(0, min(1, $0))) }
                        )
                    )
                    .tint(AppTheme.Colors.primary)
                    HStack {
                        Text(formatTime(globalPlayer.currentTime)).font(.caption2.monospacedDigit()).foregroundColor(AppTheme.Colors.textSecondary)
                        Spacer()
                        Text(formatTime(globalPlayer.duration)).font(.caption2.monospacedDigit()).foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
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
    
    // MARK: - Gesture Handling
    private var miniPlayerDragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    lastDragTranslation = 0
                    HapticManager.shared.impact(style: .light)
                }
                
                let translation = value.translation.height
                let velocity = translation - lastDragTranslation
                
                // Add some resistance when dragging up
                if translation < 0 {
                    dragOffset = translation * 0.3
                } else {
                    dragOffset = translation
                }
                
                lastDragTranslation = translation
                
                // Provide haptic feedback at thresholds
                if translation > 100 && dragOffset < 90 {
                    HapticManager.shared.impact(style: .medium)
                } else if translation < -30 && dragOffset > -25 {
                    HapticManager.shared.impact(style: .medium)
                }
            }
            .onEnded { value in
                isDragging = false
                lastDragTranslation = 0
                
                let finalOffset = value.translation.height
                let momentum = value.verticalMomentum
                
                withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.8)) {
                    dragOffset = 0
                    
                    // Determine action based on gesture
                    if finalOffset > 120 || momentum > 160 {
                        // Dismiss
                        globalPlayer.closePlayer()
                        HapticManager.shared.impact(style: .heavy)
                    } else if finalOffset < -60 || momentum < -140 {
                        // Expand to fullscreen and present VideoDetail
                        globalPlayer.expandPlayer()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            NotificationCenter.default.post(name: NSNotification.Name("PresentVideoDetailFromMiniPlayer"), object: nil)
                        }
                        HapticManager.shared.impact(style: .medium)
                    } else {
                        // Reset position
                        globalPlayer.miniplayerOffset = 0
                        HapticManager.shared.impact(style: .light)
                    }
                }
            }
    }
    
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
    
    // MARK: - 🔥 YOUTUBE PARITY: Additional Gestures
    
    private var horizontalSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = abs(value.translation.height)
                
                // Only process horizontal swipes (not vertical drags)
                if abs(horizontalDistance) > verticalDistance {
                    if horizontalDistance > 50 {
                        // Swipe right - Previous video
                        navigateToPreviousVideo()
                    } else if horizontalDistance < -50 {
                        // Swipe left - Next video
                        navigateToNextVideo()
                    }
                }
            }
    }
    
    private var pinchToResizeGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if !isResizing {
                    isResizing = true
                    HapticManager.shared.impact(style: .light)
                }
                
                let baseWidth: CGFloat = 140
                let baseHeight: CGFloat = 78
                let scale = min(max(0.7, value), 1.5) // Limit scaling between 70% and 150%
                
                playerSize = CGSize(
                    width: baseWidth * scale,
                    height: baseHeight * scale
                )
            }
            .onEnded { _ in
                isResizing = false
                // Snap to nearest size
                let baseWidth: CGFloat = 140
                let baseHeight: CGFloat = 78
                let currentScale = playerSize.width / baseWidth
                
                let targetScale: CGFloat
                if currentScale < 0.85 {
                    targetScale = 0.7 // Small
                } else if currentScale > 1.15 {
                    targetScale = 1.5 // Large
                } else {
                    targetScale = 1.0 // Normal
                }
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    playerSize = CGSize(
                        width: baseWidth * targetScale,
                        height: baseHeight * targetScale
                    )
                }
                HapticManager.shared.impact(style: .medium)
            }
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
            // Single tap - toggle controls
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if self.tapCount == 1 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.showingControls.toggle()
                    }
                    // Auto-hide controls after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.showingControls = false
                        }
                    }
                }
            }
        }
    }
    
    private func showSeekFeedback(isForward: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            showingControls = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingControls = false
            }
        }
    }
    
    // MARK: - 🔥 YOUTUBE PARITY: Navigation Functions
    
    private func navigateToPreviousVideo() {
        globalPlayer.playPreviousVideo()
    }
    
    private func navigateToNextVideo() {
        globalPlayer.playNextVideo()
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
        mockManager.shouldShowMiniPlayer = true
        mockManager.isMiniplayer = true
    }
}