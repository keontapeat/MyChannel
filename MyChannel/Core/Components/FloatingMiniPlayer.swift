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
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                // 🔥 YOUTUBE PARITY: Show mini player whenever video is playing and not in fullscreen
                // Just like YouTube - simple, reliable, always works
                if let video = globalPlayer.currentVideo,
                   !globalPlayer.showingFullscreen,
                   globalPlayer.shouldShowMiniPlayer,
                   !globalPlayer.isTransitioning,
                   !globalPlayer.isCleanedUp {
                    
                    youtubeStyleMiniPlayer(video: video, geometry: geometry)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: globalPlayer.shouldShowMiniPlayer)
                }
            }
        }
        .zIndex(9999)
        .ignoresSafeArea(.keyboard)
    }
    
    @ViewBuilder
    private func youtubeStyleMiniPlayer(video: Video, geometry: GeometryProxy) -> some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                // Thumbnail
                if let player = globalPlayer.player {
                    VideoPlayer(player: player)
                        .frame(width: 120, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .allowsHitTesting(false)
                } else {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Rectangle()
                                .fill(AppTheme.Colors.surface)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(AppTheme.Colors.textTertiary)
                                )
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Video info
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    Text(video.creator.displayName)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Play/Pause
                Button(action: {
                    if globalPlayer.isPlaying {
                        globalPlayer.exposedPlayerManager?.pause()
                    } else {
                        globalPlayer.exposedPlayerManager?.play()
                    }
                }) {
                    Image(systemName: globalPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(globalPlayer.isPlaying ? "Pause" : "Play")
                .accessibilityHint("Double tap to \(globalPlayer.isPlaying ? "pause" : "play") the video")
                
                // Close
                Button(action: {
                    globalPlayer.stopImmediately()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close mini player")
                .accessibilityHint("Double tap to stop the video")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.surface)
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: -2)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 60) // Above tab bar
            .onTapGesture {
                globalPlayer.expandPlayer()
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Now playing: \(video.title) by \(video.creator.displayName)")
            .accessibilityHint("Double tap to open full player")
        }
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