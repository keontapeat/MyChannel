import SwiftUI

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
            LazyHStack(spacing: 16) {
                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, video in
                    TopTenCard(video: video, rank: index + 1) {
                        onPlay(video)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .transaction { tx in tx.disablesAnimations = true }
    }
}

private struct TopTenCard: View {
    let video: Video
    let rank: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    MultiSourceAsyncImage(
                    urls: video.posterCandidates,
                    content: { image in
                        image
                            .resizable()
                            .scaledToFill()
                    },
                    placeholder: {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemGray6))
                    }
                )
                    .frame(width: 220, height: 124)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Rank badge (top-left)
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 28, height: 28)
                        Text("\(rank)")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(.black)
                    }
                    .offset(x: -8, y: -8)
                }

                // Move all text and meta BELOW the thumbnail for uncluttered look
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(video.creator.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineLimit(1)
                        Text("•").foregroundColor(AppTheme.Colors.textTertiary)
                        Text("\(video.formattedViewCount) views")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(width: 220)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
    }
}

#Preview {
    TopTenCarousel(videos: Video.sampleVideos) { _ in }
}



