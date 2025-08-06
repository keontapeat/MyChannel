//
//  EnhancedVideoPlayerView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVKit

struct EnhancedVideoPlayerView: View {
    let video: Video
    @StateObject private var playerManager = VideoPlayerManager()
    @State private var showControls = true
    @State private var isFullScreen = false
    @State private var selectedQuality: VideoQuality = .auto
    @State private var playbackSpeed: PlaybackSpeed = .normal
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Video Player
            VideoPlayer(player: playerManager.player)
                .aspectRatio(16/9, contentMode: .fit)
                .background(Color.black)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showControls.toggle()
                    }
                    
                    if showControls {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showControls = false
                            }
                        }
                    }
                }
            
            // Loading indicator
            if playerManager.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
            
            // Custom Controls Overlay
            if showControls {
                VStack {
                    // Top controls
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                        }
                        
                        Spacer()
                        
                        Text(video.title)
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        Button(action: { isFullScreen.toggle() }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                        }
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.black.opacity(0.7), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    Spacer()
                    
                    // Center play/pause button
                    Button(action: { playerManager.togglePlayPause() }) {
                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(.black.opacity(0.5))
                                    .frame(width: 80, height: 80)
                            )
                    }
                    
                    Spacer()
                    
                    // Bottom controls
                    VStack(spacing: 16) {
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 4)
                                
                                Rectangle()
                                    .fill(Color.white.opacity(0.5))
                                    .frame(width: geometry.size.width * playerManager.bufferedProgress, height: 4)
                                
                                Rectangle()
                                    .fill(Color.red)
                                    .frame(width: geometry.size.width * playerManager.currentProgress, height: 4)
                                
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 16, height: 16)
                                    .offset(x: geometry.size.width * playerManager.currentProgress - 8)
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let progress = min(max(value.location.x / geometry.size.width, 0), 1)
                                        playerManager.seek(to: progress)
                                    }
                            )
                        }
                        .frame(height: 16)
                        
                        // Time labels
                        HStack {
                            Text(playerManager.currentTimeString)
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text(playerManager.durationString)
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        
                        // Control buttons row
                        HStack {
                            Button(action: { playerManager.seekBackward(15) }) {
                                Image(systemName: "gobackward.15")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            Button(action: { playerManager.seekForward(15) }) {
                                Image(systemName: "goforward.15")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .transition(.opacity)
            }
        }
        .background(Color.black)
        .statusBarHidden(isFullScreen)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            playerManager.pause()
        }
    }
    
    private func setupPlayer() {
        playerManager.setupPlayer(with: video)
        playerManager.play()
        
        // Track view
        Task {
            try? await APIService.shared.trackView(
                videoId: video.id,
                duration: video.duration
            )
        }
    }
}

// MARK: - Player-specific enums (avoid conflicts with main enums)

enum PlaybackSpeed: CaseIterable {
    case slow, normal, fast, faster
    
    var displayName: String {
        switch self {
        case .slow: return "0.5x"
        case .normal: return "1x"
        case .fast: return "1.5x"
        case .faster: return "2x"
        }
    }
    
    var value: Float {
        switch self {
        case .slow: return 0.5
        case .normal: return 1.0
        case .fast: return 1.5
        case .faster: return 2.0
        }
    }
}

struct CaptionTrack: Identifiable, Codable {
    let id: String
    let language: String
    let displayName: String
    let url: String
}

#Preview {
    EnhancedVideoPlayerView(video: Video.sampleVideos[0])
}