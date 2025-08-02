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
            playerManager.setupPlayer(with: video)
            playerManager.play()
        }
        .onDisappear {
            playerManager.pause()
        }
    }
}

#Preview {
    VideoPlayerView(video: Video.sampleVideos[0])
}