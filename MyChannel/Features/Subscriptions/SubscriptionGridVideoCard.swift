//
//  SubscriptionGridVideoCard.swift
//  MyChannel
//
//  YouTube-style compact 2-column grid card for the subscriptions feed.
//  Matches YouTube's subscription grid exactly: 16:9 thumbnail, duration badge,
//  title (2 lines), creator name, view count + age, and a ⋮ more-options button.
//

import SwiftUI

struct SubscriptionGridVideoCard: View {
    let video: Video
    var progress: Double = 0
    var isNew: Bool = false
    var onMore: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            thumbnailView

            // Info row
            HStack(alignment: .top, spacing: 0) {
                infoStack
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    onMore()
                }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Thumbnail
    private var thumbnailView: some View {
        // Container must use .fit — .fill inside ScrollView/LazyVGrid gets an
        // unbounded height proposal and expands into a full-screen dark blob.
        ZStack(alignment: .bottom) {
            CachedAsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    )
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()

            // NEW badge top-left
            if isNew && !video.isLiveStream {
                Text("NEW")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppTheme.Colors.primary))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(6)
            }

            // Members-only lock badge
            if video.isMembersOnly == true && AppConfig.Features.enableMembershipPerks {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Circle().fill(Color.black.opacity(0.75)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(6)
            }

            // Duration / LIVE badge bottom-right
            Group {
                if video.isLiveStream {
                    HStack(spacing: 3) {
                        Circle().fill(Color.white).frame(width: 5, height: 5)
                        Text("LIVE")
                            .font(.system(size: 9, weight: .heavy))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red))
                } else if video.duration > 0 {
                    Text(formatDuration(video.duration))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.82)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(6)

            // Continue-watching progress bar
            if progress > 0.01 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.black.opacity(0.3))
                        Rectangle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: geo.size.width * min(1, progress))
                    }
                }
                .frame(height: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))
                .padding(.horizontal, 4)
                .padding(.bottom, 3)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Info Stack
    private var infoStack: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(video.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 3) {
                Text(video.creator.displayName)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                if video.creator.shouldShowVerificationBadge {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }

            HStack(spacing: 3) {
                Text("\(video.formattedViewCount) views")
                Text("·")
                Text(video.timeAgo)
            }
            .font(.system(size: 11, weight: .regular))
            .foregroundColor(AppTheme.Colors.textSecondary)
            .lineLimit(1)
        }
    }

    // MARK: - Helpers
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = Int(seconds) / 60 % 60
        let s = Int(seconds) % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}

#Preview {
    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    LazyVGrid(columns: columns, spacing: 16) {
        SubscriptionGridVideoCard(video: Video.sampleVideos[0], progress: 0.4, isNew: true)
        SubscriptionGridVideoCard(video: Video.sampleVideos[1])
    }
    .padding(16)
    .background(AppTheme.Colors.background)
}
