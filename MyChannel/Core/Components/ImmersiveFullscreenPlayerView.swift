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
    @State private var showControls = true
    @State private var dragOffset: CGFloat = 0
    @State private var isPiPActive: Bool = false
    @State private var showRoutePicker = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Reuse the global player's AVPlayer (already adopted from caller)
            if let player = globalPlayer.player {
                ZStack {
                    PlayerPiPContainerView(player: player, isPictureInPictureActive: $isPiPActive)
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
        VStack {
            HStack {
                Button {
                    dismissToInline()
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.35))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Dismiss fullscreen")

                Spacer()

                Text(video.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Capsule())

                Spacer()

                Menu {
                    // Placeholder menus; can be wired to real selectors from VideoPlayerManager
                    Button("Quality") {}
                    Button("Playback Speed") {}
                    Button("Captions…") {}
                    Button("Audio Track…") {}
                    Button("Share") {}
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.35))
                        .clipShape(Circle())
                }

                Button {
                    isPiPActive.toggle()
                } label: {
                    Image(systemName: isPiPActive ? "pip.exit" : "pip.enter")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.35))
                        .clipShape(Circle())
                }
            }
            .padding(.top, 18)
            .padding(.horizontal, 16)

            Spacer()

            // Basic center control
            Button {
                globalPlayer.togglePlayPause()
            } label: {
                Image(systemName: globalPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 8)
            }
            .accessibilityLabel(globalPlayer.isPlaying ? "Pause" : "Play")

            Spacer()

            // Progress + actions bar
            VStack(spacing: 12) {
                // Simple progress representation (binds to global state)
                ProgressView(value: globalPlayer.currentProgress)
                    .progressViewStyle(.linear)
                    .tint(.red)
                    .padding(.horizontal, 16)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let width = UIScreen.main.bounds.width - 32
                                let progress = min(max(Double(value.location.x / width), 0), 1)
                                globalPlayer.seek(to: progress)
                            }
                    )

                HStack(spacing: 20) {
                    Button { globalPlayer.seekBackward() } label: {
                        Image(systemName: "gobackward.10").foregroundColor(.white).font(.title3)
                    }
                    Button { globalPlayer.togglePlayPause() } label: {
                        Image(systemName: globalPlayer.isPlaying ? "pause.fill" : "play.fill").foregroundColor(.white).font(.title2)
                    }
                    Button { globalPlayer.seekForward() } label: {
                        Image(systemName: "goforward.10").foregroundColor(.white).font(.title3)
                    }
                    Button {
                        showRoutePicker.toggle()
                    } label: {
                        Image(systemName: "airplayaudio").foregroundColor(.white).font(.title3)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .background(
                    Group {
                        if showRoutePicker {
                            AirPlayRouteView()
                                .frame(height: 44)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                )
            }
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .transition(.opacity)
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


