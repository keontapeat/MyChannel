// NowPlayingView.swift
// YouTube watchOS parity: Now Playing screen with full transport controls,
// scrubber, mute, and handoff-to-phone button.

import SwiftUI
import WatchKit

struct NowPlayingView: View {
    @EnvironmentObject var store: WatchStore
    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0

    var body: some View {
        Group {
            if store.nowPlaying.isEmpty {
                EmptyNowPlayingView()
            } else {
                PlayingView(isScrubbing: $isScrubbing, scrubValue: $scrubValue)
            }
        }
        .navigationTitle("Now Playing")
    }
}

// MARK: - Empty state

private struct EmptyNowPlayingView: View {
    @EnvironmentObject var store: WatchStore

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "play.circle")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)

            Text("Nothing playing")
                .font(.headline)

            Text("Start a video on your iPhone")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !store.isPhoneReachable {
                Label("iPhone not reachable", systemImage: "iphone.slash")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.top, 4)
            }
        }
        .padding()
    }
}

// MARK: - Active player view

private struct PlayingView: View {
    @EnvironmentObject var store: WatchStore
    @Binding var isScrubbing: Bool
    @Binding var scrubValue: Double

    private var np: WatchNowPlaying { store.nowPlaying }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                // Thumbnail
                AsyncImage(url: URL(string: np.thumbnailURL)) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 100, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Title + channel
                VStack(spacing: 2) {
                    Text(np.title)
                        .font(.footnote.bold())
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(np.channelName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Progress bar
                ProgressBar(progress: isScrubbing ? scrubValue : np.progress)
                    .frame(height: 4)
                    .padding(.horizontal, 4)

                // Time labels
                HStack {
                    Text(formatSeconds(np.currentSeconds))
                    Spacer()
                    Text(formatSeconds(np.durationSeconds))
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

                // Transport controls
                HStack(spacing: 16) {
                    WatchButton(icon: "backward.fill", size: 20) { store.previous() }
                    WatchButton(
                        icon: np.isPlaying ? "pause.fill" : "play.fill",
                        size: 26,
                        accent: true
                    ) {
                        np.isPlaying ? store.pause() : store.play()
                    }
                    WatchButton(icon: "forward.fill", size: 20) { store.skip() }
                }
                .padding(.vertical, 4)

                // Secondary controls
                HStack(spacing: 12) {
                    // Mute
                    WatchButton(
                        icon: np.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                        size: 16
                    ) { store.toggleMute() }

                    // Open on iPhone
                    WatchButton(icon: "iphone.and.arrow.forward", size: 16) {
                        store.openVideo(np.videoId)
                    }
                    .disabled(!store.isPhoneReachable)

                    // Add to Watch Later
                    WatchButton(icon: "bookmark.fill", size: 16) {
                        store.addToWatchLater(np.videoId)
                        WKInterfaceDevice.current().play(.success)
                    }
                }

                // Digital Crown scrubber hint
                Text("Turn crown to scrub")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 6)
        }
        .focusable()
        .digitalCrownRotation(
            $scrubValue,
            from: 0,
            through: 1,
            by: 0.005,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: scrubValue) { val in
            isScrubbing = true
        }
        .onTapGesture {
            if isScrubbing {
                store.seek(to: scrubValue)
                isScrubbing = false
            }
        }
    }

    private func formatSeconds(_ s: Double) -> String {
        let total = Int(s)
        let m = total / 60
        let sec = total % 60
        return String(format: "%d:%02d", m, sec)
    }
}

// MARK: - Shared sub-components

struct WatchButton: View {
    let icon: String
    let size: CGFloat
    var accent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(accent ? Color.red : Color.primary)
                .frame(width: size + 14, height: size + 14)
                .background(
                    Circle()
                        .fill(accent ? Color.red.opacity(0.15) : Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }
}

struct ProgressBar: View {
    let progress: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.2))
                Capsule()
                    .fill(Color.red)
                    .frame(width: geo.size.width * CGFloat(min(1, max(0, progress))))
            }
        }
    }
}
