import SwiftUI

struct LiveTVChannelsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: LiveTVChannel.ChannelCategory? = nil
    @State private var searchText: String = ""
    @State private var viewMode: ViewMode = .grid
    @State private var healthyChannels: [LiveTVChannel] = []
    @State private var isCheckingHealth = true

    enum ViewMode: String, CaseIterable {
        case grid = "grid"
        case list = "list"

        var icon: String {
            switch self {
            case .grid: return "square.grid.2x2"
            case .list: return "list.bullet"
            }
        }
    }

    private var allChannels: [LiveTVChannel] {
        LiveTVChannel.sampleChannels + [
            LiveTVChannel(
                id: "pluto-espn",
                name: "ESPN Classic",
                logoURL: "https://images.pluto.tv/channels/espn-classic/colorLogoPNG.png",
                streamURL: "https://service-stitcher.clusters.pluto.tv/stitch/hls/channel/espn-classic/master.m3u8",
                category: .sports,
                description: "Classic sports moments and games",
                isLive: true,
                viewerCount: 25430,
                quality: "HD",
                language: "English",
                country: "US",
                epgURL: nil,
                previewFallbackURL: nil
            ),
            LiveTVChannel(
                id: "plex-bloomberg",
                name: "Bloomberg TV",
                logoURL: "https://provider-static.plex.tv/epg/images/ott_channels/logos/bloomberg-tv.png",
                streamURL: "https://bloomberg.com/media-manifest/streams/qt.m3u8",
                category: .business,
                description: "Financial news and market analysis",
                isLive: true,
                viewerCount: 12890,
                quality: "HD",
                language: "English",
                country: "US",
                epgURL: nil,
                previewFallbackURL: nil
            ),
            LiveTVChannel(
                id: "roku-kids-tv",
                name: "Kids TV",
                logoURL: "https://image.roku.com/developer_channels/prod/kids-tv-logo.png",
                streamURL: "https://service-stitcher.clusters.pluto.tv/stitch/hls/channel/kids-tv/master.m3u8",
                category: .kids,
                description: "Educational and entertaining content for children",
                isLive: true,
                viewerCount: 18750,
                quality: "HD",
                language: "English",
                country: "US",
                epgURL: nil,
                previewFallbackURL: nil
            )
        ]
    }

    private var filteredChannels: [LiveTVChannel] {
        // Prefer health-checked set; otherwise fall back to all
        var channels = healthyChannels.isEmpty ? allChannels : healthyChannels

        if let category = selectedCategory {
            channels = channels.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            channels = channels.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.category.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return channels.sorted { $0.viewerCount > $1.viewerCount }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                searchBar
                categoryChips

                ScrollView {
                    if isCheckingHealth {
                        ProgressView("Checking channels…")
                            .padding(.top, 40)
                    }
                    if viewMode == .grid {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16),
                                            GridItem(.flexible(), spacing: 16)],
                                  spacing: 16) {
                            ForEach(filteredChannels) { channel in
                                MinimalGridChannelCard(channel: channel) { play(channel) }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredChannels) { channel in
                                MinimalListChannelCard(channel: channel) { play(channel) }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    Color.clear.frame(height: 16)
                }
            }
            .background(AppTheme.Colors.background)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            // Health-rank in the background
            let ranked = await LiveStreamHealthChecker.rankHealthyChannels(allChannels, timeout: 1.5)
            await MainActor.run {
                healthyChannels = ranked
                isCheckingHealth = false
            }
        }
    }

    // MARK: - Header / Search / Filters

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.Colors.surface, in: Circle())
            }
            .buttonStyle(PressableScaleStyle())

            Spacer()

            VStack(spacing: 2) {
                Text("Live TV")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: true)
                    Text("\(filteredChannels.count) channels live")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Button { viewMode = mode } label: {
                        Image(systemName: mode.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(viewMode == mode ? .white : AppTheme.Colors.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(viewMode == mode ? Color.black : AppTheme.Colors.surface, in: Circle())
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.Colors.textSecondary)

            TextField("Search channels…", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16))

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.Colors.surface))
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(title: "All Channels (\(allChannels.count))", selected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(LiveTVChannel.ChannelCategory.allCases, id: \.self) { category in
                    let count = allChannels.filter { $0.category == category }.count
                    if count > 0 {
                        chip(title: "\(category.displayName) (\(count))", selected: selectedCategory == category) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 12)
    }

    private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(selected ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Color.black : AppTheme.Colors.surface, in: Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Actions

    private func play(_ channel: LiveTVChannel) {
        let video = Video(
            title: channel.name,
            description: channel.description,
            thumbnailURL: channel.logoURL,
            videoURL: channel.streamURL,
            duration: 0,
            viewCount: channel.viewerCount,
            likeCount: 0,
            creator: User.defaultUser,
            category: mapCategory(channel.category),
            tags: [channel.category.rawValue],
            isPublic: true,
            quality: [.quality720p, .quality1080p],
            aspectRatio: .landscape,
            isLiveStream: true,
            contentSource: nil,
            contentRating: nil,
            language: channel.language,
            isVerified: true
        )
        GlobalVideoPlayerManager.shared.playVideo(video, showFullscreen: true)
        NotificationCenter.default.post(name: NSNotification.Name("PresentVideoDetailFromMiniPlayer"), object: nil)
    }

    private func mapCategory(_ c: LiveTVChannel.ChannelCategory) -> VideoCategory {
        switch c {
        case .news: return .news
        case .sports: return .sports
        case .entertainment: return .entertainment
        case .movies: return .movies
        case .music: return .music
        case .kids: return .kids
        case .documentary: return .documentaries
        case .lifestyle: return .lifestyle
        case .business: return .news
        case .international: return .news
        }
    }
}

// MARK: - Minimal Grid Card (matches Home style)
private struct MinimalGridChannelCard: View {
    let channel: LiveTVChannel
    let action: () -> Void

    @State private var showPreview = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    if showPreview {
                        LiveChannelThumbnailView(streamURL: channel.streamURL, posterURL: channel.logoURL, fallbackStreamURL: channel.previewFallbackURL)
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        AsyncImage(url: URL(string: channel.logoURL)) { image in
                            image.resizable().scaledToFit()
                        } placeholder: { Color(.systemGray6) }
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if channel.isLive {
                        HStack(spacing: 4) {
                            Circle().fill(.white).frame(width: 4, height: 4)
                            Text("LIVE").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(Color.red.opacity(0.9)))
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .onAppear { showPreview = true }
                .onDisappear { showPreview = false }

                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text("\(formatViewerCount(channel.viewerCount)) viewers")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatViewerCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Minimal List Card
private struct MinimalListChannelCard: View {
    let channel: LiveTVChannel
    let action: () -> Void

    @State private var showPreview = false
    private let thumbSize = CGSize(width: 160, height: 90)
    private let rowHeight: CGFloat = 114

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    LiveChannelThumbnailView(streamURL: channel.streamURL, posterURL: channel.logoURL, fallbackStreamURL: channel.previewFallbackURL)
                        .opacity(showPreview ? 1 : 0)

                    AsyncImage(url: URL(string: channel.logoURL)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: { Color(.systemGray6) }
                    .opacity(showPreview ? 0 : 1)
                }
                .frame(width: thumbSize.width, height: thumbSize.height)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Text area pinned to top, consistent height
                VStack(alignment: .leading, spacing: 4) {
                    Text(channel.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(channel.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("\(formatViewerCount(channel.viewerCount)) watching • \(channel.quality)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: rowHeight, alignment: .center)
            .contentShape(Rectangle())
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.Colors.surface)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear { showPreview = true }
        .onDisappear { showPreview = false }
    }

    private func formatViewerCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
}

#Preview("Live TV - Minimal") {
    LiveTVChannelsView()
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}