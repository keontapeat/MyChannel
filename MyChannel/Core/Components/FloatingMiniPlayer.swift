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
    
    var body: some View {
        if globalPlayer.shouldShowMiniPlayer && !globalPlayer.showingFullscreen, 
           let video = globalPlayer.currentVideo {
            
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    
                    miniPlayerView(video: video, geometry: geometry)
                        .offset(y: calculateOffset())
                        .opacity(calculateOpacity())
                        .scaleEffect(calculateScale())
                        .gesture(miniPlayerDragGesture)
                        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), 
                                  value: globalPlayer.shouldShowMiniPlayer)
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.9), 
                                  value: dragOffset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .allowsHitTesting(true)
            .zIndex(998) // Below tab bar but above content
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
        HStack(spacing: 0) {
            // Video thumbnail/player section
            ZStack {
                // Video player or thumbnail
                if let player = globalPlayer.player {
                    VideoPlayer(player: player)
                        .aspectRatio(16/9, contentMode: .fill)
                        .disabled(true)
                        .allowsHitTesting(false)
                        .clipped()
                } else {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(AppTheme.Colors.surface)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                                    .scaleEffect(0.6)
                            )
                    }
                    .clipped()
                }
                
                // Progress bar overlay at the bottom
                VStack {
                    Spacer()
                    
                    progressBar
                }
            }
            .frame(width: 120, height: 68)
            .cornerRadius(8)
            .clipped()
            .onTapGesture {
                expandPlayer()
            }
            
            // Video info and controls section
            videoInfoAndControls(video: video)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(miniPlayerBackground)
        .padding(.horizontal, 16)
        .padding(.bottom, calculateBottomPadding(geometry: geometry))
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
            HStack(spacing: 16) {
                // Play/Pause button
                Button(action: {
                    globalPlayer.togglePlayPause()
                    HapticManager.shared.impact(style: .light)
                }) {
                    Image(systemName: globalPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Close button
                Button(action: closePlayer) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
    }
    
    private var miniPlayerBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AppTheme.Colors.cardBackground)
            .shadow(
                color: AppTheme.Colors.textPrimary.opacity(0.08),
                radius: 16,
                x: 0,
                y: -8
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 0.5)
            )
    }
    
    private func calculateBottomPadding(geometry: GeometryProxy) -> CGFloat {
        let safeAreaBottom = geometry.safeAreaInsets.bottom
        let tabBarHeight: CGFloat = 80
        return safeAreaBottom + tabBarHeight + 8
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
                let velocity = value.velocity.height
                
                withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.8)) {
                    dragOffset = 0
                    
                    // Determine action based on gesture
                    if finalOffset > 120 || velocity > 1000 {
                        // Dismiss
                        globalPlayer.closePlayer()
                    } else if finalOffset < -60 || velocity < -800 {
                        // Expand
                        globalPlayer.expandPlayer()
                    } else {
                        // Reset position
                        globalPlayer.miniplayerOffset = 0
                    }
                }
                
                HapticManager.shared.impact(style: .medium)
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
}

#Preview {
    ZStack {
        AppTheme.Colors.background
            .ignoresSafeArea()
        
        // Mock home view content
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0..<10, id: \.self) { i in
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
        
        FloatingMiniPlayer()
            .onAppear {
                // Mock data for preview
                let mockPlayer = GlobalVideoPlayerManager.shared
                mockPlayer.currentVideo = Video.sampleVideos[0]
                mockPlayer.shouldShowMiniPlayer = true
                mockPlayer.isMiniplayer = true
            }
    }
}