//
//  VideoMiniPlayerBar.swift
//  MyChannel
//
//  YouTube-style in-app floating mini player that sits above the tab bar.
//  Appears whenever a video is playing but the VideoDetailView is dismissed.
//  Tap → re-open VideoDetailView. Swipe right → dismiss (stop).
//

import SwiftUI
import AVKit

struct VideoMiniPlayerBar: View {
    @EnvironmentObject private var globalPlayer: GlobalVideoPlayerManager
    @State private var dragOffset: CGFloat = 0
    @State private var isDismissing = false

    // Opens the full VideoDetailView for the current video
    var onTap: (Video) -> Void

    var body: some View {
        if let video = globalPlayer.currentVideo, !globalPlayer.showingFullscreen {
            content(video: video)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func content(video: Video) -> some View {
        HStack(spacing: 0) {
            // Thumbnail
            thumbnailView(video: video)

            // Title + channel
            VStack(alignment: .leading, spacing: 2) {
                Text(video.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                Text(video.creator.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            .padding(.leading, 10)

            Spacer()

            // Play / Pause
            Button {
                if globalPlayer.isPlaying {
                    globalPlayer.player?.pause()
                    globalPlayer.isPlaying = false
                } else {
                    globalPlayer.player?.play()
                    globalPlayer.isPlaying = true
                }
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: globalPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(width: 44, height: 44)
            }

            // Close
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isDismissing = true
                }
                globalPlayer.stopImmediately()
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.leading, 8)
        .frame(height: 56)
        .background(
            AppTheme.Colors.surface
                .overlay(
                    // Thin progress line at bottom
                    GeometryReader { geo in
                        Rectangle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: geo.size.width * globalPlayer.currentProgress, height: 2)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom),
                    alignment: .bottom
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: -2)
        .padding(.horizontal, 8)
        .offset(x: dragOffset)
        .opacity(isDismissing ? 0 : 1)
        .onTapGesture {
            onTap(video)
            HapticManager.shared.impact(style: .light)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow horizontal swipe
                    if abs(value.translation.width) > abs(value.translation.height) {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width > 100 {
                        // Swipe right → dismiss
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 400
                        }
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            globalPlayer.stopImmediately()
                        }
                        HapticManager.shared.impact(style: .medium)
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }

    @ViewBuilder
    private func thumbnailView(video: Video) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .frame(width: 80, height: 45)

            if let url = URL(string: video.thumbnailURL) {
                AppAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 80, height: 45)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
