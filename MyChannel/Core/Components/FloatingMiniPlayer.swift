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
    
    var body: some View {
        if globalPlayer.isMiniplayer, let video = globalPlayer.currentVideo {
            VStack {
                Spacer()
                
                miniPlayerView(video: video)
                    .offset(y: globalPlayer.miniplayerOffset + dragOffset)
                    .opacity(max(0, 1.0 - (globalPlayer.miniplayerOffset / 100.0)))
                    .scaleEffect(max(0.8, 1.0 - (globalPlayer.miniplayerOffset / 400.0)))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height > 0 {
                                    dragOffset = value.translation.height
                                } else {
                                    // Expand on upward swipe
                                    if abs(value.translation.height) > 50 {
                                        globalPlayer.expandPlayer()
                                    }
                                }
                            }
                            .onEnded { value in
                                dragOffset = 0
                                
                                if value.translation.height > 100 {
                                    globalPlayer.closePlayer()
                                } else if value.translation.height < -50 {
                                    globalPlayer.expandPlayer()
                                }
                            }
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
    
    private func miniPlayerView(video: Video) -> some View {
        HStack(spacing: 0) {
            // Video thumbnail/player
            ZStack {
                if let player = globalPlayer.player {
                    VideoPlayer(player: player)
                        .aspectRatio(16/9, contentMode: .fill)
                        .disabled(true)
                } else {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(AppTheme.Colors.surface)
                    }
                }
                
                // Progress bar overlay
                VStack {
                    Spacer()
                    
                    Rectangle()
                        .fill(AppTheme.Colors.primary)
                        .frame(height: 2)
                        .scaleEffect(x: globalPlayer.currentProgress, anchor: .leading)
                        .animation(.linear(duration: 0.1), value: globalPlayer.currentProgress)
                }
            }
            .frame(width: 120, height: 68)
            .cornerRadius(8)
            .clipped()
            .onTapGesture {
                globalPlayer.expandPlayer()
            }
            
            // Video info and controls
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
                
                // Play/Pause button
                Button(action: {
                    globalPlayer.togglePlayPause()
                }) {
                    Image(systemName: globalPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Close button
                Button(action: {
                    globalPlayer.closePlayer()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.cardBackground)
                .shadow(
                    color: AppTheme.Colors.textPrimary.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: -2
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 100) // Account for tab bar
    }
}

#Preview {
    ZStack {
        AppTheme.Colors.background
            .ignoresSafeArea()
        
        FloatingMiniPlayer()
    }
}