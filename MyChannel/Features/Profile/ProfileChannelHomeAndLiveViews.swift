//
//  ProfileChannelHomeAndLiveViews.swift
//  MyChannel
//
//  🔥 YOUTUBE PARITY: Channel Home + Live tab views for ProfileTab parity.
//  - ProfileChannelHomeView: Featured/trailer + recent uploads grid (YouTube channel "Home" tab)
//  - ProfileLiveView: Filters userVideos for live streams (YouTube channel "Live" tab)
//

import SwiftUI

// MARK: - Channel Home View
struct ProfileChannelHomeView: View {
    let videos: [Video]
    let user: User

    private var featuredVideo: Video? {
        videos.first { $0.isLiveStream } ?? videos.max(by: { $0.viewCount < $1.viewCount }) ?? videos.first
    }

    private var recentVideos: [Video] {
        Array(videos.sorted(by: { $0.createdAt > $1.createdAt }).prefix(8))
    }

    private var popularVideos: [Video] {
        Array(videos.sorted(by: { $0.viewCount > $1.viewCount }).prefix(8))
    }

    var body: some View {
        if videos.isEmpty {
            ChannelHomeEmptyState(user: user)
                .padding(.top, 60)
        } else {
            VStack(alignment: .leading, spacing: 28) {
                if let featured = featuredVideo {
                    featuredSection(featured)
                }

                if !recentVideos.isEmpty {
                    horizontalRow(title: "Recent uploads", videos: recentVideos)
                }

                if !popularVideos.isEmpty {
                    horizontalRow(title: "Popular videos", videos: popularVideos)
                }

                Color.clear.frame(height: 24)
            }
            .padding(.top, 16)
            .iPadReadableWidth()
        }
    }

    @ViewBuilder
    private func featuredSection(_ video: Video) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(video.isLiveStream ? "Live now" : "Featured")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 16)

            Button {
                NotificationCenter.default.post(name: .openVideoFromProfile, object: video)
                HapticManager.shared.impact(style: .light)
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack(alignment: .topLeading) {
                        AppAsyncImage(url: URL(string: video.thumbnailURL)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(AppTheme.Colors.surface)
                        }
                        .aspectRatio(16.0/9.0, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        if video.isLiveStream {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                Text("LIVE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .padding(8)
                        }
                    }

                    Text(video.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(metaLine(for: video))
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func horizontalRow(title: String, videos: [Video]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(videos) { v in
                        Button {
                            NotificationCenter.default.post(name: .openVideoFromProfile, object: v)
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            channelHomeCard(v)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private func channelHomeCard(_ video: Video) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                AppAsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(AppTheme.Colors.surface)
                }
                .frame(width: 240, height: 135)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(formatDuration(video.duration))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .padding(6)
            }

            Text(video.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 240, alignment: .leading)

            Text(metaLine(for: video))
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .lineLimit(1)
                .frame(width: 240, alignment: .leading)
        }
    }

    private func metaLine(for video: Video) -> String {
        "\(formatCount(video.viewCount)) views \u{2022} \(video.timeAgo)"
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Channel Home Empty State
private struct ChannelHomeEmptyState: View {
    let user: User

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "house")
                .font(.system(size: 56))
                .foregroundColor(AppTheme.Colors.textSecondary)
            Text("Welcome to \(user.displayName)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text("There's no content here yet. Check back soon!")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Live Tab View
struct ProfileLiveView: View {
    let videos: [Video]
    let user: User

    private var liveVideos: [Video] {
        videos.filter { $0.isLiveStream }
    }

    private var upcomingVideos: [Video] {
        videos.filter { v in
            v.scheduledAt != nil && !v.isLiveStream && (v.scheduledAt ?? .distantPast) > Date()
        }
    }

    var body: some View {
        if liveVideos.isEmpty && upcomingVideos.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 56))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Text("No live streams yet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Text("When \(user.displayName) goes live, you'll see it here.")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else {
            LazyVStack(alignment: .leading, spacing: 16) {
                if !liveVideos.isEmpty {
                    sectionHeader("Live now", count: liveVideos.count)
                    ForEach(liveVideos) { v in
                        liveRow(v, isLive: true)
                    }
                }

                if !upcomingVideos.isEmpty {
                    sectionHeader("Upcoming", count: upcomingVideos.count)
                    ForEach(upcomingVideos) { v in
                        liveRow(v, isLive: false)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .iPadReadableWidth()
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text("(\(count))")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.Colors.textSecondary)
            Spacer()
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func liveRow(_ video: Video, isLive: Bool) -> some View {
        Button {
            NotificationCenter.default.post(name: .openVideoFromProfile, object: video)
            HapticManager.shared.impact(style: .light)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    AppAsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(AppTheme.Colors.surface)
                    }
                    .aspectRatio(16.0/9.0, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    HStack(spacing: 6) {
                        if isLive {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                        }
                        Text(isLive ? "LIVE" : "UPCOMING")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isLive ? Color.red.opacity(0.95) : Color.black.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .padding(8)
                }

                Text(video.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if isLive {
                    Text("\(formatCount(video.viewCount)) watching")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                } else if let scheduled = video.scheduledAt {
                    Text("Starts \(scheduled.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .padding(.bottom, 8)
        }
        .buttonStyle(.plain)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Notification for opening videos from profile tabs
extension Notification.Name {
    static let openVideoFromProfile = Notification.Name("openVideoFromProfile")
}
