//
//  FloatingMiniPlayer.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVKit
import AVKit
import AVFoundation

/// Custom YouTube-style mini player that sits above the tab bar.
/// - Shows live video preview (or thumbnail fallback)
/// - Tap anywhere to expand to fullscreen
/// - Play / pause and close controls
/// - Progress bar across the bottom
struct FloatingMiniPlayer: View {
    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared
    @EnvironmentObject private var appState: AppState
    
    @GestureState private var dragTranslation: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero
    
    private let verticalDismissThreshold: CGFloat = 120
    private let verticalExpandThreshold: CGFloat = 90
    private let horizontalDismissThreshold: CGFloat = 180
    private let cardCornerRadius: CGFloat = 22
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let video = globalPlayer.currentVideo,
                   !globalPlayer.showingFullscreen,
                   globalPlayer.shouldShowMiniPlayer,
                   !globalPlayer.isCleanedUp,
                   !globalPlayer.isTransitioning {
                    
                    let miniPlayerWidth = min(geometry.size.width - 32, 360)
                    let miniPlayerHeight: CGFloat = 94
                    
                    ZStack(alignment: .bottomTrailing) {
                        youtubeStyleMiniPlayer(
                            video: video,
                            geometry: geometry,
                            cardWidth: miniPlayerWidth,
                            cardHeight: miniPlayerHeight
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.horizontal, 16)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 18)
                    .offset(totalOffset)
                    .highPriorityGesture(
                        dragGesture(
                            geometry: geometry,
                            cardWidth: miniPlayerWidth,
                            cardHeight: miniPlayerHeight
                        )
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: globalPlayer.shouldShowMiniPlayer)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Now playing: \(video.title) by \(video.creator.displayName)")
                    .accessibilityHint("Double tap to open full player")
                    .onChange(of: video.id) { _ in
                        resetOffsets()
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)
        }
    }
    
    // MARK: - YouTube-style Mini Player
    
    @ViewBuilder
    private func youtubeStyleMiniPlayer(
        video: Video,
        geometry: GeometryProxy,
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        // Layout constants tuned to feel like YouTube's mini player
        let thumbnailCornerRadius: CGFloat = cardCornerRadius
        let title = video.title
        let creator = video.creator.displayName
        
        let duration = max(globalPlayer.duration, 0.1)
        let progress = min(max(globalPlayer.currentTime / duration, 0), 1)
        
        ZStack(alignment: .bottom) {
            // Video preview / thumbnail fallback
            Group {
                if let player = globalPlayer.player {
                    VideoPlayer(player: player)
                        .allowsHitTesting(false)
                } else {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Color.black
                        case .empty:
                            ZStack {
                                Color.black
                                ProgressView()
                                    .tint(.white)
                            }
                        @unknown default:
                            Color.black
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: thumbnailCornerRadius))
            
            // Overlays (top controls, center controls, progress bar)
            VStack(spacing: 0) {
                // Top controls
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.55),
                            Color.black.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    
                    HStack {
                        Button {
                            globalPlayer.closePlayer()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Button {
                            globalPlayer.expandPlayer()
                        } label: {
                            Image(systemName: "rectangle.on.rectangle")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                }
                
                Spacer(minLength: 0)
                
                // Center controls
                HStack(spacing: 24) {
                    Button {
                        globalPlayer.seekBackward()
                    } label: {
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 52, height: 52)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    
                    Button {
                        if globalPlayer.isPlaying {
                            globalPlayer.exposedPlayerManager?.pause()
                        } else {
                            globalPlayer.exposedPlayerManager?.play()
                        }
                    } label: {
                        Image(systemName: globalPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 58, height: 58)
                            .background(Color.black.opacity(0.75))
                            .clipShape(Circle())
                    }
                    
                    Button {
                        globalPlayer.seekForward()
                    } label: {
                        Image(systemName: "goforward.10")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 52, height: 52)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 14)
                
                // Bottom metadata + scrubber
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text(creator)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Button {
                            globalPlayer.expandPlayer()
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.45))
                                .clipShape(Capsule())
                        }
                    }
                    
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.45))
                                .frame(height: 2)
                            
                            Capsule()
                                .fill(Color.red)
                                .frame(width: proxy.size.width * CGFloat(progress), height: 2)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let pct = min(max(Double(value.location.x / proxy.size.width), 0), 1)
                                    globalPlayer.seek(to: pct)
                                }
                        )
                    }
                    .frame(height: 10)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.7), Color.black.opacity(0.0)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: thumbnailCornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 10)
        .onTapGesture {
            globalPlayer.expandPlayer()
        }
    }
}

// MARK: - Private helpers
extension FloatingMiniPlayer {
    private var totalOffset: CGSize {
        CGSize(
            width: accumulatedOffset.width + dragTranslation.width,
            height: accumulatedOffset.height + dragTranslation.height
        )
    }
    
    private func resetOffsets() {
        accumulatedOffset = .zero
    }
    
    private func dragGesture(
        geometry: GeometryProxy,
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation
                globalPlayer.handleMiniplayerDrag(value.translation)
            }
            .onEnded { value in
                globalPlayer.handleMiniplayerDragEnd(value.translation)
                
                // Horizontal flick to dismiss (YouTube parity)
                if abs(value.translation.width) > horizontalDismissThreshold {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        globalPlayer.closePlayer()
                        resetOffsets()
                    }
                    return
                }
                
                // Swipe down to dismiss
                if value.translation.height > verticalDismissThreshold {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        globalPlayer.closePlayer()
                        resetOffsets()
                    }
                    return
                }
                
                // Swipe up to expand
                if value.translation.height < -verticalExpandThreshold {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        resetOffsets()
                    }
                    globalPlayer.expandPlayer()
                    return
                }
                
                // Otherwise, settle to new resting offset within bounds
                let proposed = CGSize(
                    width: accumulatedOffset.width + value.translation.width,
                    height: accumulatedOffset.height + value.translation.height
                )
                
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    accumulatedOffset = clampedOffset(
                        proposed,
                        geometry: geometry,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight
                    )
                }
            }
    }
    
    private func clampedOffset(
        _ proposed: CGSize,
        geometry: GeometryProxy,
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> CGSize {
        let safeInsetBottom = geometry.safeAreaInsets.bottom + 24
        let safeInsetTop: CGFloat = 20
        
        let maxHorizontalLeft = -(geometry.size.width - cardWidth - 32)
        let maxHorizontalRight: CGFloat = 0
        
        let maxVerticalDown: CGFloat = 0
        let maxVerticalUp = -(geometry.size.height - cardHeight - safeInsetBottom - safeInsetTop)
        
        return CGSize(
            width: min(max(proposed.width, maxHorizontalLeft), maxHorizontalRight),
            height: min(max(proposed.height, maxVerticalUp), maxVerticalDown)
        )
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