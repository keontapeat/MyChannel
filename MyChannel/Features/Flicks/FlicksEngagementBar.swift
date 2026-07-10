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
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button(action: onCreatorTap) {
                        AppAsyncImage(
                            url: URL(string: flick.creator.profileImageURL),
                            content: { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            },
                            placeholder: {
                                Circle().fill(Color.white.opacity(0.3))
                            }
                        )
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    }
                    .accessibilityLabel("Creator \(flick.creator.displayName)")

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(flick.creator.displayName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            if flick.creator.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.blue)
                                    .fixedSize()
                            }
                        }

                        Text("@\(flick.creator.username)")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                    }

                    Button(action: onFollow) {
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isFollowing ? Color.white.opacity(0.18) : Color.red)
                            )
                    }
                    .accessibilityLabel(isFollowing ? "Unfollow creator" : "Follow creator")
                }

                Text(flick.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)

                if !flick.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(flick.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)
                        }
                    }
                }
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
            .frame(width: 72, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, bottomInset)
    }
}
