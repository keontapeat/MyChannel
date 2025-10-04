//
//  LiveTVPlayerView.swift
//  MyChannel
//
//  Created by AI Assistant on 8/12/25.
//

import SwiftUI
import AVKit

struct LiveTVPlayerView: View {
    let channel: LiveTVChannel
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = true
    @State private var showControls: Bool = true
    @Environment(\.dismiss) private var dismiss
    @State private var backTapCount: Int = 0
    @State private var showExitHint: Bool = false
    @State private var tapResetWorkItem: DispatchWorkItem? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }

            // Overlay header + controls
            if showControls {
                VStack(alignment: .leading, spacing: 12) {
                    // Gradient for readability
                    LinearGradient(
                        colors: [Color.black.opacity(0.6), Color.black.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                    .allowsHitTesting(false)
                    .overlay(
                        HStack(spacing: 12) {
                            // Close button
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(10)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Circle())
                            }

                            AsyncImage(url: URL(string: channel.logoURL)) { image in
                                image.resizable()
                            } placeholder: {
                                Rectangle().fill(.gray.opacity(0.3))
                            }
                            .frame(width: 48, height: 32)
                            .cornerRadius(6)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(channel.name)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("LIVE • \(channel.category.displayName)")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }

                            Spacer()

                            Button(action: togglePlayPause) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18, weight: .bold))
                                    .padding(10)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                    )

                    Divider().background(Color.white.opacity(0.2))

                    Spacer()
                }
                .transition(.opacity)
            }

            // Double-tap to exit hint
            if showExitHint {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Tap again to exit")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                        Spacer()
                    }
                    .padding(.bottom, 40)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            teardown()
        }
        // Gestures: single tap toggles controls, double-tap exits
        .contentShape(Rectangle())
        .onTapGesture(count: 1) {
            withAnimation(.easeInOut(duration: 0.2)) { showControls.toggle() }
        }
        .onTapGesture(count: 2) {
            dismiss()
        }
        .navigationBarBackButtonHidden(true)
    }

    private func setupPlayer() {
        guard let url = URL(string: channel.streamURL) else { return }
        let player = AVPlayer(url: url)
        player.automaticallyWaitsToMinimizeStalling = false // favor low latency for live
        player.play()
        self.player = player
        isPlaying = true
    }

    private func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    private func teardown() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }

    private func handleBackTap() { /* deprecated with explicit gestures */ }
}

#Preview {
    LiveTVPlayerView(channel: LiveTVChannel.sampleChannels.first!)
}
