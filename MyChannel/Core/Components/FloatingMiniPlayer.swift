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
    
    var body: some View {
        if globalPlayer.shouldShowMiniPlayer && !globalPlayer.showingFullscreen, 
           let video = globalPlayer.currentVideo {
            VStack {
                Spacer()
                
                miniPlayerView(video: video)
                    .offset(y: globalPlayer.miniplayerOffset + dragOffset)
                    .opacity(opacity)
                    .scaleEffect(scale)
                    .gesture(miniPlayerDragGesture)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: globalPlayer.shouldShowMiniPlayer)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
    
    private var opacity: Double {
        let totalOffset = globalPlayer.miniplayerOffset + dragOffset
        return max(0.3, 1.0 - (totalOffset / 120.0))
    }
    
    private var scale: CGFloat {
        let totalOffset = globalPlayer.miniplayerOffset + dragOffset
        return max(0.85, 1.0 - (totalOffset / 400.0))
    }
    
    private func miniPlayerView(video: Video) -> some View {
        HStack(spacing: 0) {
            // Video thumbnail/player section
            ZStack {
                // Video player or thumbnail
                if let player = globalPlayer.player {
                    VideoPlayer(player: player)
                        .aspectRatio(16/9, contentMode: .fill)
                        .disabled(true)
                        .allowsHitTesting(false)
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
                }
                
                // Progress bar overlay at the bottom
                VStack {
                    Spacer()
                    
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
            }
            .frame(width: 120, height: 68)
            .cornerRadius(8)
            .clipped()
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    globalPlayer.expandPlayer()
                }
                HapticManager.shared.impact(style: .medium)
            }
            
            // Video info and controls section
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
                
                Spacer()
                
                // Control buttons
                HStack(spacing: 16) {
                    // Play/Pause button
                    Button(action: {
                        globalPlayer.togglePlayPause()
                    }) {
                        Image(systemName: globalPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Close button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            globalPlayer.closePlayer()
                        }
                        HapticManager.shared.impact(style: .light)
                    }) {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.cardBackground)
                .shadow(
                    color: AppTheme.Colors.textPrimary.opacity(0.15),
                    radius: 12,
                    x: 0,
                    y: -4
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, safeAreaInsets.bottom + 90) // Account for tab bar and safe area
    }
    
    private var miniPlayerDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    HapticManager.shared.impact(style: .light)
                }
                
                dragOffset = value.translation.height
                
                // Provide haptic feedback when crossing thresholds
                if value.translation.height > 100 && dragOffset < 100 {
                    HapticManager.shared.impact(style: .medium)
                } else if value.translation.height < -50 && dragOffset > -50 {
                    HapticManager.shared.impact(style: .medium)
                }
            }
            .onEnded { value in
                isDragging = false
                dragOffset = 0
                globalPlayer.handleMiniplayerDragEnd(value.translation)
            }
    }
    
    private var safeAreaInsets: UIEdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return .zero
        }
        return window.safeAreaInsets
    }
}

#Preview {
    ZStack {
        AppTheme.Colors.background
            .ignoresSafeArea()
        
        FloatingMiniPlayer()
            .onAppear {
                // Mock data for preview
                GlobalVideoPlayerManager.shared.playVideo(Video.sampleVideos[0], showFullscreen: false)
            }
    }
}