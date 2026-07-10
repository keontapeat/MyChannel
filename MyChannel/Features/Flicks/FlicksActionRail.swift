//
//  FlicksActionRail.swift
//  MyChannel
//
//  Right-side engagement rail extracted from FlicksView.
//

import SwiftUI

struct FlicksActionRail: View {
    let flick: NuclearFlick
    let isLiked: Bool
    let isSaved: Bool
    let likeCountLabel: String
    let commentCountLabel: String
    let shareCountLabel: String
    let playbackSpeedLabel: String
    let qualityLabel: String
    let albumArtRotation: Double
    let trailingPadding: CGFloat
    let bottomPadding: CGFloat
    let reduceMotion: Bool

    let onLike: () -> Void
    let onComment: () -> Void
    let onShare: () -> Void
    let onRemix: () -> Void
    let onSpeed: () -> Void
    let onQuality: () -> Void
    let onSave: () -> Void
    let onMore: () -> Void
    let onSound: (FlickMusicTrack) -> Void

    var body: some View {
        VStack(spacing: 20) {
            railButton(
                icon: isLiked ? "heart.fill" : "heart",
                count: likeCountLabel,
                color: isLiked ? .red : .white,
                scale: isLiked ? 1.1 : 1.0,
                label: "Like"
            ) {
                HapticManager.shared.impact(style: .medium)
                onLike()
            }

            railButton(icon: "bubble.right.fill", count: commentCountLabel, color: .white, label: "Comments") {
                HapticManager.shared.impact(style: .light)
                onComment()
            }

            railButton(icon: "arrowshape.turn.up.right.fill", count: shareCountLabel, color: .white, label: "Share") {
                HapticManager.shared.impact(style: .light)
                onShare()
            }

            railButton(icon: "arrow.triangle.2.circlepath", count: "Remix", color: .white, label: "Remix") {
                HapticManager.shared.impact(style: .light)
                onRemix()
            }

            railButton(
                icon: "gauge.with.dots.needle.67percent",
                count: playbackSpeedLabel,
                color: .white,
                label: "Playback speed"
            ) {
                HapticManager.shared.impact(style: .light)
                onSpeed()
            }

            railButton(icon: "gearshape.fill", count: qualityLabel, color: .white, label: "Video quality") {
                HapticManager.shared.impact(style: .light)
                onQuality()
            }

            railButton(
                icon: isSaved ? "bookmark.fill" : "bookmark",
                count: "Save",
                color: isSaved ? .yellow : .white,
                label: isSaved ? "Saved" : "Save"
            ) {
                HapticManager.shared.impact(style: .medium)
                onSave()
            }

            railButton(icon: "ellipsis", count: "", color: .white, label: "More options") {
                HapticManager.shared.impact(style: .light)
                onMore()
            }

            if let musicTrack = flick.musicTrack {
                Button {
                    HapticManager.shared.impact(style: .light)
                    onSound(musicTrack)
                } label: {
                    AppAsyncImage(
                        url: URL(string: musicTrack.albumArt),
                        content: { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        },
                        placeholder: {
                            Circle().fill(Color.white.opacity(0.3))
                        }
                    )
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .rotationEffect(.degrees(reduceMotion ? 0 : albumArtRotation))
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("Sound: \(musicTrack.title)")
            }
        }
        .padding(.trailing, trailingPadding)
        .padding(.bottom, bottomPadding)
    }

    private func railButton(
        icon: String,
        count: String,
        color: Color,
        scale: CGFloat = 1.0,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.55))
                        .frame(width: 52, height: 52)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                        .scaleEffect(scale)
                }

                if !count.isEmpty {
                    Text(count)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
    }
}

#Preview {
    let previewFlick = NuclearFlick(
        id: "preview",
        videoURL: "https://example.com/v.mp4",
        thumbnailURL: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
        title: "Preview",
        description: "",
        duration: 15,
        viewCount: 1000,
        likeCount: 1200,
        commentCount: 88,
        shareCount: 0,
        createdAt: Date(),
        creator: FlickCreator(
            id: "c1",
            username: "creator",
            displayName: "Creator",
            profileImageURL: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
            isVerified: false
        ),
        tags: [],
        musicTrack: nil,
        contentSource: .userUploaded,
        externalID: nil
    )
    return ZStack {
        Color.black.ignoresSafeArea()
        HStack {
            Spacer()
            FlicksActionRail(
                flick: previewFlick,
                isLiked: true,
                isSaved: false,
                likeCountLabel: "1.2K",
                commentCountLabel: "88",
                shareCountLabel: "Share",
                playbackSpeedLabel: "1.0x",
                qualityLabel: "AUTO",
                albumArtRotation: 0,
                trailingPadding: 0,
                bottomPadding: 0,
                reduceMotion: true,
                onLike: {},
                onComment: {},
                onShare: {},
                onRemix: {},
                onSpeed: {},
                onQuality: {},
                onSave: {},
                onMore: {},
                onSound: { _ in }
            )
        }
    }
}
