import SwiftUI

// MARK: - Trending Now Section (Polished Header + Carousel)
/// Dedicated, premium "Trending Now" section: sleek header with a flame accent
/// and a pill "See all" affordance, wrapping the ranked Top 10 carousel.
struct TrendingNowSection: View {
    let videos: [Video]
    var onSeeAll: () -> Void
    var onPlay: (Video) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            TopTenCarousel(videos: videos, preserveOrder: true, onPlay: onPlay)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Trending Now")
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .tracking(-0.3)

            Image(systemName: "flame.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(TrendingStyle.flameGradient)
                .shadow(color: AppTheme.Colors.primary.opacity(0.35), radius: 5, x: 0, y: 1)

            Spacer(minLength: 8)

            Button {
                HapticManager.shared.impact(style: .light)
                onSeeAll()
            } label: {
                HStack(spacing: 2) {
                    Text("See all")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(AppTheme.Colors.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(AppTheme.Colors.primary.opacity(0.10))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Top Ten Carousel
struct TopTenCarousel: View {
    let videos: [Video]
    var preserveOrder: Bool = false
    var onPlay: (Video) -> Void

    private var ranked: [Video] {
        let list: [Video]
        if preserveOrder {
            list = videos
        } else {
            list = videos.sorted { lhs, rhs in
                if lhs.viewCount != rhs.viewCount { return lhs.viewCount > rhs.viewCount }
                return lhs.createdAt > rhs.createdAt
            }
        }
        return Array(list.prefix(10))
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, video in
                    TopTenCard(video: video, rank: index + 1) {
                        onPlay(video)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 2)
        }
        .scrollClipDisabledCompat()
        .transaction { tx in tx.disablesAnimations = true }
    }
}

// MARK: - Top Ten Card
private struct TopTenCard: View {
    let video: Video
    let rank: Int
    let action: () -> Void

    private let cardWidth: CGFloat = 248
    private var thumbHeight: CGFloat { cardWidth * 9 / 16 } // 16:9

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                thumbnail
                metadata
            }
            .frame(width: cardWidth)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
    }

    // MARK: Thumbnail
    private var thumbnail: some View {
        ZStack(alignment: .topLeading) {
            MultiSourceAsyncImage(
                urls: video.posterCandidates,
                content: { image in
                    image
                        .resizable()
                        .scaledToFill()
                },
                placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemGray6))
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(AppTheme.Colors.textTertiary.opacity(0.5))
                    }
                }
            )
            .frame(width: cardWidth, height: thumbHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            // Bottom scrim for legibility of badges
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.45)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: thumbHeight * 0.55)
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            // Duration badge (bottom-right)
            .overlay(alignment: .bottomTrailing) {
                Text(video.formattedDuration)
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.black.opacity(0.72))
                    )
                    .padding(8)
            }
            .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 8)

            RankBadge(rank: rank)
                .padding(8)
        }
    }

    // MARK: Metadata
    private var metadata: some View {
        HStack(alignment: .top, spacing: 10) {
            CreatorAvatar(video: video)

            VStack(alignment: .leading, spacing: 3) {
                Text(video.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: 38, alignment: .top)

                HStack(spacing: 4) {
                    Text(video.creator.displayName)
                        .lineLimit(1)
                    if video.creator.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
                .font(.system(size: 12.5))
                .foregroundColor(AppTheme.Colors.textSecondary)

                HStack(spacing: 4) {
                    Text("\(video.formattedViewCount) views")
                    Text("•")
                    Text(video.timeAgo)
                }
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textTertiary)
                .lineLimit(1)
            }
        }
    }
}

// MARK: - Rank Badge
private struct RankBadge: View {
    let rank: Int

    private var isTopThree: Bool { rank <= 3 }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    isTopThree
                        ? AnyShapeStyle(TrendingStyle.flameGradient)
                        : AnyShapeStyle(Color.black.opacity(0.62))
                )
            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: 1)

            Text("\(rank)")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 28, height: 28)
        .shadow(
            color: isTopThree ? AppTheme.Colors.primary.opacity(0.45) : .black.opacity(0.3),
            radius: 6, x: 0, y: 3
        )
    }
}

// MARK: - Creator Avatar
private struct CreatorAvatar: View {
    let video: Video

    private var avatarURLs: [URL] {
        guard let s = video.creator.profileImageURL,
              !s.isEmpty,
              let u = URL(string: s) else { return [] }
        return [u]
    }

    var body: some View {
        Group {
            if avatarURLs.isEmpty {
                fallback
            } else {
                MultiSourceAsyncImage(
                    urls: avatarURLs,
                    content: { image in
                        image
                            .resizable()
                            .scaledToFill()
                    },
                    placeholder: { fallback }
                )
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.primary.opacity(0.06), lineWidth: 1))
    }

    private var fallback: some View {
        ZStack {
            Circle().fill(AppTheme.Colors.primary.opacity(0.15))
            Text(String(video.creator.displayName.prefix(1)).uppercased())
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppTheme.Colors.primary)
        }
    }
}

// MARK: - Pressable Card Style
private struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Shared Style
private enum TrendingStyle {
    static let flameGradient = LinearGradient(
        colors: [AppTheme.Colors.primaryLight, AppTheme.Colors.primary, AppTheme.Colors.primaryDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Compat
private extension View {
    /// Allows carousel card shadows/scale to draw outside the ScrollView bounds on iOS 17+.
    @ViewBuilder
    func scrollClipDisabledCompat() -> some View {
        if #available(iOS 17.0, *) {
            self.scrollClipDisabled()
        } else {
            self
        }
    }
}

#Preview {
    ScrollView {
        TrendingNowSection(
            videos: Video.sampleVideos,
            onSeeAll: {},
            onPlay: { _ in }
        )
        .padding(.vertical, 24)
    }
}
