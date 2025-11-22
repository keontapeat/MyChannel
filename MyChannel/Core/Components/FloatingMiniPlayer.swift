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
                    
                    let miniPlayerWidth = min(geometry.size.width - 32, 420)
                    let miniPlayerHeight = max(miniPlayerWidth * 9 / 16, 140)
                    
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
        let title = video.title
        let creator = video.creator.displayName
        let duration = max(globalPlayer.duration, 0.1)
        let progress = min(max(globalPlayer.currentTime / duration, 0), 1)
        let progressTrackWidth = cardWidth - 36
        let progressFillWidth = max(6, progressTrackWidth * CGFloat(progress))
        let knobOffset = max(0, min(progressTrackWidth - 8, progressTrackWidth * CGFloat(progress) - 4))
        
        ZStack {
            videoSurface(for: video)
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.55),
                            Color.black.opacity(0.1),
                            Color.black.opacity(0.65)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                )
            
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    controlButton(icon: "xmark") {
                        globalPlayer.closePlayer()
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(creator)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 0)
                    
                    controlButton(icon: "arrow.up.left.and.arrow.down.right") {
                        globalPlayer.expandPlayer()
                    }
                }
                .padding(.bottom, 18)
                
                Spacer()
                
                HStack(spacing: 20) {
                    circleTransportButton(systemName: "gobackward.10") {
                        globalPlayer.seekBackward()
                    }
                    
                    circleTransportButton(systemName: globalPlayer.isPlaying ? "pause.fill" : "play.fill", size: 52) {
                        globalPlayer.togglePlayPause()
                    }
                    
                    circleTransportButton(systemName: "goforward.10") {
                        globalPlayer.seekForward()
                    }
                }
                
                Spacer()
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.35))
                        .frame(height: 3)
                    
                    Capsule()
                        .fill(Color.white)
                        .frame(width: progressFillWidth, height: 3)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .offset(x: knobOffset)
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .frame(width: cardWidth, height: cardHeight)
        .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 10)
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
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

// MARK: - Private subviews
private extension FloatingMiniPlayer {
    @ViewBuilder
    func videoSurface(for video: Video) -> some View {
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
                            .scaledToFill()
                    case .failure:
                        Color.black
                    case .empty:
                        ZStack {
                            Color.black
                            ProgressView().tint(.white)
                        }
                    @unknown default:
                        Color.black
                    }
                }
            }
        }
        .background(Color.black)
        .clipped()
    }
    
    func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.2))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
    
    func circleTransportButton(systemName: String, size: CGFloat = 44, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size == 44 ? 18 : 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(Color.black.opacity(0.35))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
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