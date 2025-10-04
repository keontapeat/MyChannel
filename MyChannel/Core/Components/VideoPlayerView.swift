//
//  VideoPlayerView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVKit

// Simple video player view for basic playback
struct VideoPlayerView: View {
    let video: Video
    @StateObject private var playerManager = VideoPlayerManager()
    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VideoPlayer(player: playerManager.player)
                .aspectRatio(16/9, contentMode: .fit)
            
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                    }
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
        .onAppear {
            // Setup local manager and hand off to global manager; start playback explicitly (no toggle)
            playerManager.setupPlayer(with: video)
            playerManager.play()
            globalPlayer.adoptExternalPlayerManager(playerManager, video: video, showFullscreen: true)
        }
        .onDisappear {
            // Do not pause here if global is in use; closing is handled by global player lifecycle
        }
    }
}

#Preview {
    VideoPlayerView(video: Video.sampleVideos[0])
}