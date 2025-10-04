import SwiftUI

struct ArtistDetailView: View {
    let name: String
    let avatarURL: String
    let videos: [Video]
    let totalViews: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @State private var selectedVideo: Video?
    @State private var isFollowing = false
    @State private var tab: ContentTab = .videos
    @State private var query: String = ""
    @State private var sort: Sort = .popular
    @State private var showGrid: Bool = true

    private var isPad: Bool { hSizeClass == .regular }
    private var gridColumns: [GridItem] {
        let count = isPad ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: count)
    }

    private var filteredAndSorted: [Video] {
        let filtered = videos.filter { v in
            guard !query.isEmpty else { return true }
            return v.title.localizedCaseInsensitiveContains(query) ||
                   v.creator.displayName.localizedCaseInsensitiveContains(query)
        }
        switch sort {
        case .popular:
            return filtered.sorted { $0.viewCount > $1.viewCount }
        case .newest:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        case .duration:
            return filtered.sorted { $0.duration > $1.duration }
        }
    }

    private var nameSlug: String {
        name.replacingOccurrences(of: " ", with: "-")
    }

    private var shareURL: URL? {
        URL(string: "https://mychannel.app/artist/\(nameSlug)")
    }

    enum ContentTab: String, CaseIterable, Identifiable {
        case videos = "Videos"
        case about = "About"
        var id: String { rawValue }
    }

    enum Sort: String, CaseIterable, Identifiable {
        case popular = "Popular"
        case newest = "Newest"
        case duration = "Duration"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .popular: return "flame.fill"
            case .newest: return "clock.fill"
            case .duration: return "hourglass"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        GeometryReader { proxy in
                            let minY = proxy.frame(in: .named("scroll")).minY
                            ArtistParallaxHeader(
                                name: name,
                                avatarURL: avatarURL,
                                videoCount: videos.count,
                                totalViews: totalViews,
                                minY: minY,
                                shareURL: shareURL,
                                isFollowing: $isFollowing
                            )
                        }
                        .frame(height: 260)

                        Section {
                            contentBody
                        } header: {
                            StickyControlsBar(
                                tab: $tab,
                                sort: $sort,
                                showGrid: $showGrid
                            )
                            .background(.ultraThinMaterial)
                        }
                    }
                }
                .coordinateSpace(name: "scroll")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let shareURL {
                        ShareLink(item: shareURL) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search videos")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $selectedVideo) { v in
                VideoDetailView(video: v)
            }
        }
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var contentBody: some View {
        switch tab {
        case .videos:
            if showGrid {
                LazyVGrid(columns: gridColumns, spacing: 14) {
                    ForEach(filteredAndSorted) { video in
                        ArtistGridCard(video: video) {
                            selectedVideo = video
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .animation(.spring(response: 0.4, dampingFraction: 0.9), value: filteredAndSorted.count)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(filteredAndSorted) { video in
                        ArtistVideoRow(video: video) {
                            selectedVideo = video
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .animation(.spring(response: 0.4, dampingFraction: 0.9), value: filteredAndSorted.count)
            }
        case .about:
            ArtistAboutSection(name: name, avatarURL: avatarURL, totalViews: totalViews, videos: videos)
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
        }
    }
}

// MARK: - Parallax Header
private struct ArtistParallaxHeader: View {
    let name: String
    let avatarURL: String
    let videoCount: Int
    let totalViews: Int
    let minY: CGFloat
    let shareURL: URL?

    @Binding var isFollowing: Bool

    private var headerHeight: CGFloat {
        let base: CGFloat = 220
        return min(max(base - minY, base), base + 120)
    }

    private func format(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n)/1_000) }
        return "\(n)"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    AppTheme.Colors.primary.opacity(0.22),
                    AppTheme.Colors.secondary.opacity(0.22),
                    AppTheme.Colors.background
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .overlay(
                AppAsyncImage(url: URL(string: avatarURL)) { img in
                    img
                        .resizable()
                        .scaledToFill()
                        .opacity(0.16)
                        .blur(radius: 22)
                        .clipped()
                } placeholder: {
                    Color.clear
                }
            )
            .frame(height: headerHeight)
            .clipped()
            .overlay(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.0)
            )

            HStack(alignment: .center, spacing: 16) {
                ProfileAvatarView(urlString: avatarURL, size: 84, showsRing: true)
                    .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 3))
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                    .scaleEffect(minY < 0 ? max(0.9, 1 + minY/500) : 1.0)

                VStack(alignment: .leading, spacing: 6) {
                    Text(name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("\(videoCount) videos • \(format(totalViews)) total views")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    HStack(spacing: 10) {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isFollowing.toggle()
                            }
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Text(isFollowing ? "Following" : "Follow")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isFollowing ? AppTheme.Colors.textPrimary : .white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(isFollowing ? .white : AppTheme.Colors.primary)
                                .clipShape(Capsule())
                        }

                        if let shareURL {
                            ShareLink(item: shareURL) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                    .padding(10)
                                    .background(AppTheme.Colors.background, in: Circle())
                                    .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 0.5))
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .animation(.easeInOut(duration: 0.2), value: isFollowing)
    }
}

// MARK: - Sticky Controls
private struct StickyControlsBar: View {
    @Binding var tab: ArtistDetailView.ContentTab
    @Binding var sort: ArtistDetailView.Sort
    @Binding var showGrid: Bool

    var body: some View {
        VStack(spacing: 10) {
            Picker("Tab", selection: $tab) {
                ForEach(ArtistDetailView.ContentTab.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 10)

            if tab == .videos {
                HStack(spacing: 12) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(ArtistDetailView.Sort.allCases) { s in
                                Label(s.rawValue, systemImage: s.icon).tag(s)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: sort.icon)
                            Text(sort.rawValue)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.surface, in: Capsule())
                        .overlay(Capsule().stroke(AppTheme.Colors.divider.opacity(0.25), lineWidth: 1))
                    }

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showGrid.toggle()
                        }
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Image(systemName: showGrid ? "square.grid.2x2.fill" : "list.bullet")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .padding(8)
                            .background(AppTheme.Colors.surface, in: Circle())
                            .overlay(Circle().stroke(AppTheme.Colors.divider.opacity(0.25), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            } else {
                Spacer(minLength: 8)
            }
        }
    }
}

// MARK: - Grid Card
private struct ArtistGridCard: View {
    let video: Video
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                MultiSourceAsyncImage(urls: video.posterCandidates) { img in
                    img
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemGray6))
                }
                .frame(height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    Text(video.formattedDuration)
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule().fill(.black.opacity(0.7)))
                        .padding(6),
                    alignment: .bottomTrailing
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    Text("\(video.formattedViewCount) views • \(video.creator.displayName)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - List Row
private struct ArtistVideoRow: View {
    let video: Video
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                MultiSourceAsyncImage(urls: video.posterCandidates) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6))
                }
                .frame(width: 140, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    Text(video.formattedDuration)
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule().fill(.black.opacity(0.7)))
                        .padding(6),
                    alignment: .bottomTrailing
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    Text("\(video.formattedViewCount) views • \(video.creator.displayName)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - About Section
private struct ArtistAboutSection: View {
    let name: String
    let avatarURL: String
    let totalViews: Int
    let videos: [Video]

    private var topTags: [String] {
        let all = videos.flatMap { $0.tags }
        let counts = Dictionary(grouping: all, by: { $0 }).mapValues { $0.count }
        return counts.sorted { $0.value > $1.value }.prefix(10).map { $0.key }
    }

    private func format(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n)/1_000) }
        return "\(n)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ProfileAvatarView(urlString: avatarURL, size: 64, showsRing: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 22, weight: .bold))
                    Text("\(format(totalViews)) lifetime views")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Popular Tags")
                    .font(.headline)

                if topTags.isEmpty {
                    Text("No tags available yet.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    WrapTags(tags: topTags)
                }
            }
            .padding(14)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1))
        }
    }
}

private struct WrapTags: View {
    let tags: [String]
    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geo in
            self.generateContent(in: geo)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geo: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return ZStack(alignment: .topLeading) {
            ForEach(tags, id: \.self) { tag in
                tagChip(tag)
                    .alignmentGuide(.leading) { d in
                        if (abs(width - d.width) > geo.size.width) {
                            width = 0
                            height -= d.height + 8
                        }
                        let result = width
                        if tag == tags.last {
                            width = 0
                        } else {
                            width -= d.width + 8
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if tag == tags.last {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func tagChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.Colors.primary.opacity(0.12))
            .foregroundColor(AppTheme.Colors.primary)
            .clipShape(Capsule())
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { proxy in
            Color.clear.onAppear {
                binding.wrappedValue = proxy.size.height
            }
        }
    }
}

// MARK: - Preview
#Preview("Artist Detail") {
    let friendUser = User(username: "artist", displayName: "Top Artist", email: "artist@mc.com", profileImageURL: "https://i.pravatar.cc/200?u=artist", isVerified: true, isCreator: true)
    let vids = Array(Video.sampleVideos.prefix(12)).map {
        Video(
            id: $0.id,
            title: $0.title,
            description: $0.description,
            thumbnailURL: $0.thumbnailURL,
            videoURL: $0.videoURL,
            duration: $0.duration,
            viewCount: Int.random(in: 30_000...1_500_000),
            likeCount: $0.likeCount,
            commentCount: $0.commentCount,
            creator: friendUser,
            category: .music,
            tags: $0.tags + ["Detroit","Rap","Viral","Official"],
            isPublic: true,
            quality: $0.quality,
            aspectRatio: .landscape,
            isLiveStream: false,
            contentSource: .youtube,
            externalID: $0.externalID,
            isVerified: true
        )
    }
    return ArtistDetailView(
        name: "Top Artist",
        avatarURL: friendUser.profileImageURL ?? "",
        videos: vids,
        totalViews: vids.reduce(0) { $0 + $1.viewCount }
    )
    .preferredColorScheme(.light)
}