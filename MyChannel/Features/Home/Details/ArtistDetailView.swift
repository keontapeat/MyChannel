import SwiftUI
import UIKit

struct ArtistDetailView: View {
    let name: String
    let avatarURL: String
    let videos: [Video]
    let totalViews: Int

    @Environment(\.dismiss) private var dismiss
    @State private var isFollowing = false
    @State private var selection: Segment = .videos
    @State private var selectedVideo: Video?

    enum Segment: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case videos = "Videos"
        var id: String { rawValue }
    }

    private var sortedVideos: [Video] {
        videos.sorted { $0.viewCount > $1.viewCount }
    }

    private var avgViews: Int {
        guard !videos.isEmpty else { return 0 }
        return videos.reduce(0) { $0 + $1.viewCount } / videos.count
    }

    private func format(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n)/1_000) }
        return "\(n)"
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Background
                    AppAsyncImage(url: URL(string: avatarURL)) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color(.systemGray5)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .blur(radius: 20)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.4),
                                Color.black.opacity(0.6),
                                Color(.systemBackground)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()

                    // Content
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header section with artist info
                            VStack(spacing: 20) {
                                artistHeader
                            }
                            .padding(.top, 120)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 30)

                            // Card with segmented control and content
                            VStack(spacing: 20) {
                                segmentedControl
                                contentView
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 24)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
                            )
                            .padding(.horizontal, 0)
                            .padding(.bottom, 50)
                        }
                    }

                    // Navigation bar
                    VStack {
                        navigationBar
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedVideo) { video in
                VideoDetailView(video: video)
            }
        }
    }

    private var navigationBar: some View {
        HStack {
            Button {
                HapticManager.shared.impact(style: .light)
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }

            Spacer()

            Text(name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button {
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
        .padding(.bottom, 10)
    }

    private var artistHeader: some View {
        HStack(spacing: 16) {
            AppAsyncImage(url: URL(string: avatarURL)) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color(.systemGray5))
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 4)
            )
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

            VStack(alignment: .leading, spacing: 8) {
                Text(name)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    Label("\(format(totalViews)) views", systemImage: "eye")
                    Label("\(videos.count) videos", systemImage: "video")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

                HStack(spacing: 12) {
                    Button {
                        isFollowing.toggle()
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(isFollowing ? .white : .black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(isFollowing ? AppTheme.Colors.primary : .white)
                            )
                    }
                    .buttonStyle(PressableScaleButtonStyle(scale: 0.96))

                    Button {
                        if let first = sortedVideos.first {
                            selectedVideo = first
                        }
                        HapticManager.shared.impact(style: .medium)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("Play")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(.black.opacity(0.6))
                        )
                    }
                    .buttonStyle(PressableScaleButtonStyle(scale: 0.96))
                }
            }
            Spacer()
        }
    }

    private var segmentedControl: some View {
        Picker("", selection: $selection) {
            ForEach(Segment.allCases) { segment in
                Text(segment.rawValue).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .animation(.easeInOut(duration: 0.2), value: selection)
    }

    private var contentView: some View {
        Group {
            switch selection {
            case .overview:
                overviewContent
            case .videos:
                videosContent
            }
        }
    }

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Statistics")
                .font(.system(size: 20, weight: .bold))

            HStack(spacing: 12) {
                ArtistStatTile(title: "Total Views", value: format(totalViews), icon: "eye")
                ArtistStatTile(title: "Avg/Video", value: format(avgViews), icon: "chart.bar")
                ArtistStatTile(title: "Videos", value: "\(videos.count)", icon: "video")
            }

            if !sortedVideos.isEmpty {
                Text("Top Videos")
                    .font(.system(size: 20, weight: .bold))
                    .padding(.top, 10)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(sortedVideos.prefix(8)) { video in
                            Button {
                                selectedVideo = video
                            } label: {
                                TopVideoCard(video: video)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    private var videosContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Videos")
                .font(.system(size: 20, weight: .bold))

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(sortedVideos) { video in
                    Button {
                        selectedVideo = video
                    } label: {
                        VideoGridItem(video: video)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Components

private struct ArtistStatTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(AppTheme.Colors.primary)

            Text(value)
                .font(.system(size: 18, weight: .bold))

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }
}

private struct TopVideoCard: View {
    let video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MultiSourceAsyncImage(
                urls: video.posterCandidates,
                content: { image in
                    image.resizable().scaledToFill()
                },
                placeholder: {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.systemGray6))
                }
            )
            .frame(width: 200, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                HStack {
                    Spacer()
                    Text(video.formattedDuration)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.black.opacity(0.7)))
                        .padding(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)

                Text("\(video.formattedViewCount) views")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(width: 200, alignment: .leading)
        }
    }
}

private struct VideoGridItem: View {
    let video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MultiSourceAsyncImage(
                urls: video.posterCandidates,
                content: { image in
                    image.resizable().scaledToFill()
                },
                placeholder: {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.systemGray6))
                }
            )
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                HStack {
                    Spacer()
                    Text(video.formattedDuration)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.black.opacity(0.7)))
                        .padding(6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(video.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)

                Text("\(video.formattedViewCount) views")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview("ArtistDetailView") {
    let sample = Array(Video.sampleVideos.prefix(12))
    ArtistDetailView(
        name: sample.first?.creator.displayName ?? "Artist",
        avatarURL: sample.first?.creator.profileImageURL ?? "https://i.pravatar.cc/200?u=artist",
        videos: sample,
        totalViews: sample.reduce(0) { $0 + $1.viewCount }
    )
    .preferredColorScheme(.light)
}