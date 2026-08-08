//
//  FlicksEngagementBar.swift
//  MyChannel
//
//  Bottom engagement chrome extracted from FlicksView (creator info + action rail).
//

import SwiftUI

struct FlicksEngagementBar: View {
    let flick: NuclearFlick
    let isLiked: Bool
    let isSaved: Bool
    let isFollowing: Bool
    let likeCountLabel: String
    let commentCountLabel: String
    let shareCountLabel: String
    let playbackSpeedLabel: String
    let qualityLabel: String
    let albumArtRotation: Double
    let bottomInset: CGFloat
    let infoRightPadding: CGFloat
    let reduceMotion: Bool

    let onCreatorTap: () -> Void
    let onFollow: () -> Void
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
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                creatorRow

                Text(flick.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                if !flick.description.isEmpty {
                    Text(flick.description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.88))
                        .lineLimit(2)
                }

                if !flick.tags.isEmpty {
                    Text(flick.tags.prefix(3).map { "#\($0)" }.joined(separator: "  "))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }

                Button(action: onComment) {
                    HStack {
                        Text("Add a comment…")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.72))
                        Spacer()
                        Image(systemName: "face.smiling")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white.opacity(0.72))
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 46)
                    .background(Color.black.opacity(0.46), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("Add a comment")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, infoRightPadding)

            FlicksActionRail(
                flick: flick,
                isLiked: isLiked,
                isSaved: isSaved,
                likeCountLabel: likeCountLabel,
                commentCountLabel: commentCountLabel,
                shareCountLabel: shareCountLabel,
                playbackSpeedLabel: playbackSpeedLabel,
                qualityLabel: qualityLabel,
                albumArtRotation: albumArtRotation,
                trailingPadding: 0,
                bottomPadding: 0,
                reduceMotion: reduceMotion,
                onLike: onLike,
                onComment: onComment,
                onShare: onShare,
                onRemix: onRemix,
                onSpeed: onSpeed,
                onQuality: onQuality,
                onSave: onSave,
                onMore: onMore,
                onSound: onSound
            )
            .frame(width: 64, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, bottomInset)
    }

    private var creatorRow: some View {
        HStack(spacing: 10) {
            Button(action: onCreatorTap) {
                AppAsyncImage(
                    url: URL(string: flick.creator.profileImageURL),
                    content: { $0.resizable().aspectRatio(contentMode: .fill) },
                    placeholder: { Circle().fill(Color.white.opacity(0.3)) }
                )
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }
            .accessibilityLabel("Creator \(flick.creator.displayName)")

            HStack(spacing: 4) {
                Text(flick.creator.username)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if flick.creator.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                }
            }

            Button(action: onFollow) {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(Color.black.opacity(isFollowing ? 0.32 : 0.48), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.75), lineWidth: 1))
            }
            .accessibilityLabel(isFollowing ? "Unfollow creator" : "Follow creator")
        }
    }
}
