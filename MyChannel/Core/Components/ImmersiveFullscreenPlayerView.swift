//
//  ImmersiveFullscreenPlayerView.swift
//  MyChannel
//
//  A YouTube/Netflix-grade fullscreen player with gesture-driven dismiss/expand
//

import SwiftUI
import AVKit

struct ImmersiveFullscreenPlayerView: View {
    let video: Video
    let onExitFullscreen: () -> Void

    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared
    @Environment(\.dismiss) private var dismiss  // 🔥 ADD: For minimizing to mini-player
    @State private var showControls = true
    @State private var dragOffset: CGFloat = 0
    @State private var showRoutePicker = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Reuse the global player's AVPlayer (already adopted from caller)
            if let player = globalPlayer.player {
                ZStack {
                    // Native VideoPlayer hosts the same AVPlayer used for PiP + mini-player
                    VideoPlayer(player: player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // Tap to toggle controls
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { showControls.toggle() } }
                }
                .background(Color.black)
                .offset(y: dragOffset)
                .gesture(dragGesture)
            } else {
                ProgressView().tint(.white)
            }

            if showControls { overlayControls }
        }
        .statusBarHidden(true)
        .onAppear { Orientation.lock(.landscape) }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                globalPlayer.showingFullscreen = true
                globalPlayer.shouldShowMiniPlayer = false
                globalPlayer.isMiniplayer = false
            }
            // Ensure autoplay when presenting fullscreen using explicit play
            if let player = globalPlayer.player {
                player.play()
            }
        }
        .onDisappear {
            // Do not stop playback; caller will keep same player in its inline view
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                globalPlayer.showingFullscreen = false
            }
            Orientation.unlock()
        }
    }

    private var overlayControls: some View {
        ZStack {
            // Top gradient overlay
            VStack {
                LinearGradient(
                    colors: [.black.opacity(0.7), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
                .ignoresSafeArea(edges: .top)
                
                Spacer()
            }
            
            // Bottom gradient overlay
            VStack {
                Spacer()
                
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 220)
                .ignoresSafeArea(edges: .bottom)
            }
            
            VStack(spacing: 0) {
                // Top Controls
                HStack(spacing: 12) {
                    Button {
                        dismissToInline()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .accessibilityLabel("Exit fullscreen")
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(video.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(video.creator.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // AirPlay
                    Button {
                        showRoutePicker.toggle()
                    } label: {
                        Image(systemName: "airplayvideo")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    
                    // Settings Menu
                    Menu {
                        Button("Quality") {}
                        Button("Playback Speed") {}
                        Button("Captions") {}
                        Button("Audio Track") {}
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                
                Spacer()
                
                // Center Play/Pause (YouTube style)
                HStack(spacing: 60) {
                    // Rewind
                    Button {
                        globalPlayer.seekBackward()
                        HapticManager.shared.impact(style: .medium)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: "gobackward.10")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .accessibilityLabel("Rewind 10 seconds")
                    
                    // Play/Pause
                    Button {
                        globalPlayer.togglePlayPause()
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 85, height: 85)
                            
                            Image(systemName: globalPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .accessibilityLabel(globalPlayer.isPlaying ? "Pause" : "Play")
                    
                    // Forward
                    Button {
                        globalPlayer.seekForward()
                        HapticManager.shared.impact(style: .medium)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: "goforward.10")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .accessibilityLabel("Forward 10 seconds")
                }
                
                Spacer()
                
                // Bottom Controls (YouTube style)
                VStack(spacing: 16) {
                    // Progress bar with thumb
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 4)
                            
                            // Buffered progress (optional - can wire to actual buffer if available)
                            Rectangle()
                                .fill(Color.white.opacity(0.5))
                                .frame(width: geometry.size.width * CGFloat(globalPlayer.currentProgress), height: 4)
                            
                            // Current progress
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: geometry.size.width * CGFloat(globalPlayer.currentProgress), height: 4)
                            
                            // Scrubber thumb
                            Circle()
                                .fill(Color.red)
                                .frame(width: 14, height: 14)
                                .offset(x: geometry.size.width * CGFloat(globalPlayer.currentProgress) - 7)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let progress = min(max(Double(value.location.x / geometry.size.width), 0), 1)
                                    globalPlayer.seek(to: progress)
                                }
                        )
                    }
                    .frame(height: 14)
                    .padding(.horizontal, 20)
                    
                    // Time stamps and controls
                    HStack {
                        // Current time / Duration
                        Text("\(formatTime(globalPlayer.currentTime)) / \(formatTime(globalPlayer.duration))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .monospacedDigit()
                        
                        Spacer()
                        
                        Button {
                            if !globalPlayer.togglePictureInPicture() {
                                globalPlayer.minimizePlayer()
                                dismiss()
                            }
                        } label: {
                            Image(systemName: globalPlayer.isPiPActive ? "pip.exit" : "pip.enter")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .transition(.opacity)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        guard !timeInterval.isNaN && !timeInterval.isInfinite else { return "0:00" }
        
        let totalSeconds = Int(timeInterval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                // Only consider upward drag for dismiss-to-inline
                dragOffset = min(0, value.translation.height)
            }
            .onEnded { value in
                let momentum = value.verticalMomentum
                let shouldDismiss = value.translation.height < -80 || momentum < -120
                withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.85)) {
                    dragOffset = 0
                }
                if shouldDismiss { dismissToInline() }
            }
    }

    private func dismissToInline() {
        // Ensure playback stops completely when exiting fullscreen
        globalPlayer.closePlayer()
        onExitFullscreen()
    }
}

#Preview {
    ImmersiveFullscreenPlayerView(video: Video.sampleVideos[0]) {}
        .preferredColorScheme(.dark)
}


