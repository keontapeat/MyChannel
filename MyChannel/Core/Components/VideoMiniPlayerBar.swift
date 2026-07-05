//
//  VideoMiniPlayerBar.swift
//  MyChannel
//
//  YouTube-style in-app mini player bar pinned above the tab bar.
//  Shows live video, title, play/pause, and close.
//  Tap → expand to VideoDetailView. Swipe down → dismiss. Swipe right → dismiss.
//

import SwiftUI
import AVKit

struct VideoMiniPlayerBar: View {
    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared

    // Horizontal swipe-to-dismiss
    @State private var dragOffsetX: CGFloat = 0
    // Vertical swipe-to-dismiss
    @State private var dragOffsetY: CGFloat = 0
    @State private var isDismissing = false

    // Mini player bar dimensions
    private let barHeight: CGFloat = 64
    private let thumbWidth: CGFloat = 96
    private let thumbHeight: CGFloat = 54

    var body: some View {
        if let video = globalPlayer.currentVideo,
           !globalPlayer.showingFullscreen,
           !globalPlayer.isCleanedUp {
            content(video: video)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    )
                )
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: globalPlayer.currentVideo?.id)
        }
    }

    @ViewBuilder
    private func content(video: Video) -> some View {
        VStack(spacing: 0) {
            // Thin red progress line across the very top of the bar (YouTube exact)
            GeometryReader { geo in
                Rectangle()
                    .fill(AppTheme.Colors.primary)
                    .frame(width: geo.size.width * CGFloat(globalPlayer.currentProgress), height: 2)
                    .animation(.linear(duration: 0.25), value: globalPlayer.currentProgress)
            }
            .frame(height: 2)

            HStack(spacing: 0) {
                // Live video thumbnail — shows actual frame if player is ready, else poster
                videoThumbView(video: video)
                    .frame(width: thumbWidth, height: thumbHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                // Title + channel
                VStack(alignment: .leading, spacing: 2) {
                    Text(video.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Text(video.creator.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                .padding(.leading, 10)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Play / Pause — 44pt target
                Button {
                    globalPlayer.togglePlayPause()
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Image(systemName: globalPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                // Close
                Button {
                    dismissMiniPlayer()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
            }
            .padding(.leading, 8)
            .frame(height: barHeight)
        }
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: -3)
        .padding(.horizontal, 8)
        // Apply swipe offsets
        .offset(x: dragOffsetX, y: max(0, dragOffsetY))
        .opacity(isDismissing ? 0 : dismissOpacity)
        // Tap anywhere on the bar body (not the buttons) → expand
        .contentShape(Rectangle())
        .onTapGesture {
            expandPlayer()
        }
        // Gestures: horizontal swipe → dismiss, vertical swipe down → dismiss
        .gesture(combinedDismissGesture)
    }

    // MARK: - Live video thumbnail

    @ViewBuilder
    private func videoThumbView(video: Video) -> some View {
        ZStack {
            Color.black
            // Show live player frame when player is ready
            if let player = globalPlayer.player {
                RawPlayerLayerView(player: player, videoGravity: .resizeAspectFill)
                    .allowsHitTesting(false)
            } else {
                // Fallback: poster thumbnail
                AppAsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
            }
        }
    }

    // MARK: - Dismiss opacity during drag

    private var dismissOpacity: Double {
        let hProg = abs(dragOffsetX) / 200
        let vProg = max(0, dragOffsetY) / 120
        let prog = max(hProg, vProg)
        return max(0.3, 1 - prog)
    }

    // MARK: - Gestures

    private var combinedDismissGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dx) > abs(dy) {
                    // Horizontal: only allow rightward swipe-to-dismiss
                    dragOffsetX = max(0, dx)
                    dragOffsetY = 0
                } else {
                    // Vertical: only allow downward swipe-to-dismiss
                    dragOffsetY = max(0, dy)
                    dragOffsetX = 0
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let vx = value.predictedEndTranslation.width - dx
                let vy = value.predictedEndTranslation.height - dy

                let dismissRight = dx > 100 || vx > 300
                let dismissDown  = dy > 80  || vy > 250

                if dismissRight || dismissDown {
                    HapticManager.shared.impact(style: .medium)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        if dismissDown { dragOffsetY = 160 }
                        else           { dragOffsetX = 400 }
                        isDismissing = true
                    }
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 280_000_000)
                        globalPlayer.closePlayer()
                        dragOffsetX = 0
                        dragOffsetY = 0
                        isDismissing = false
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffsetX = 0
                        dragOffsetY = 0
                    }
                }
            }
    }

    // MARK: - Actions

    private func expandPlayer() {
        HapticManager.shared.impact(style: .light)
        globalPlayer.expandPlayer()
    }

    private func dismissMiniPlayer() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            dragOffsetY = 160
            isDismissing = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
            globalPlayer.closePlayer()
            dragOffsetX = 0
            dragOffsetY = 0
            isDismissing = false
        }
        HapticManager.shared.impact(style: .light)
    }
}
