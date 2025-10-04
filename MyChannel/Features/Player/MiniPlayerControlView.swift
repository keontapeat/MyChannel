//
//  MiniPlayerControlView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVKit

struct MiniPlayerControlView: View {
    let video: Video
    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        if globalPlayer.shouldShowMiniPlayer, let currentVideo = globalPlayer.currentVideo {
            VStack(spacing: 0) {
                Spacer()
                
                HStack(spacing: 0) {
                    Spacer()
                    
                    // Mini Player Container
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .background(Color.black.opacity(0.1))
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        
                        HStack(spacing: 12) {
                            // Video Thumbnail/Player
                            ZStack {
                                AsyncImage(url: URL(string: currentVideo.thumbnailURL)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 60, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                
                                // Play/Pause overlay
                                if !globalPlayer.isPlaying {
                                    Circle()
                                        .fill(.black.opacity(0.6))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.white)
                                        )
                                }
                            }
                            .onTapGesture {
                                globalPlayer.togglePlayPause()
                            }
                            
                            // Video Info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(currentVideo.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                
                                Text(currentVideo.creator.displayName)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // Control Buttons
                            HStack(spacing: 8) {
                                // Play/Pause Button
                                Button(action: {
                                    globalPlayer.togglePlayPause()
                                }) {
                                    Image(systemName: globalPlayer.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                }
                                .buttonStyle(ScaleButtonStyle())
                                
                                // Close Button
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        globalPlayer.closePlayer()
                                    }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .frame(height: globalPlayer.miniPlayerHeight)
                    .offset(y: globalPlayer.miniplayerOffset + dragOffset.height)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                let finalOffset = dragOffset.height + value.translation.height
                                globalPlayer.handleMiniplayerDragEnd(CGSize(width: 0, height: finalOffset))
                                
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    dragOffset = .zero
                                }
                            }
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            globalPlayer.expandPlayer()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            Text("Main Content Area")
                .font(.title)
                .padding()
            Spacer()
        }
        
        MiniPlayerControlView(video: Video.sampleVideos[0])
            .environmentObject(PreviewSafeGlobalVideoPlayerManager())
    }
}