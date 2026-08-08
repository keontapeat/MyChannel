// ⚡ PERFORMANCE: Extracted from HomeView.swift — independent compilation unit.
// All section/card/component structs compile in parallel with the 741-line main HomeView struct.
import SwiftUI

// MARK: - Minimal Section
struct MinimalSection<Content: View>: View {
    let title: String
    let seeAllAction: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                Spacer()

                if let seeAllAction = seeAllAction {
                    Button("See all", action: seeAllAction)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)

            content
        }
    }
}

// MARK: - 🔥 Quick Tune Section (Smart Loading)
struct QuickTuneSection: View {
    let liveChannelsAPI: [LiveTVChannel]
    
    @StateObject private var loadingTracker = LiveChannelLoadingTracker.shared
    
    private var hasReadyChannels: Bool {
        !loadingTracker.readyChannels.isEmpty
    }
    
    private var isLoading: Bool {
        !loadingTracker.isInitialLoadComplete && loadingTracker.readyChannels.isEmpty
    }
    
    var body: some View {
        // Only show section if we have ready channels OR still loading
        if hasReadyChannels || isLoading {
            MinimalSection(title: "Quick Tune", seeAllAction: nil) {
                if isLoading {
                    loadingView
                } else {
                    channelsScrollView
                }
            }
            .animation(.easeOut(duration: 0.3), value: hasReadyChannels)
        }
    }
    
    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading channels...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 30)
    }
    
    private var channelsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                // MyChannel Live
                NavigationLink(destination: LiveTVPlayerView(channel: myChannelLive)) {
                    MinimalChannelCard(
                        channel: myChannelLive,
                        autoPreview: true,
                        previewOverrideStreamURL: nil,
                        previewOverridePosterURL: nil,
                        allowPlaybackInPreviews: true
                    )
                }
                .buttonStyle(PressableScaleStyle(scale: 0.96))
                
                // Other channels
                ForEach(channels) { channel in
                    NavigationLink(destination: LiveTVPlayerView(channel: channel)) {
                        MinimalChannelCard(
                            channel: channel,
                            autoPreview: true,
                            previewOverrideStreamURL: nil,
                            previewOverridePosterURL: nil,
                            allowPlaybackInPreviews: true
                        )
                    }
                    .buttonStyle(PressableScaleStyle(scale: 0.96))
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var myChannelLive: LiveTVChannel {
        LiveTVChannel(
            id: "mychannel-live",
            name: "MyChannel Live",
            logoURL: "https://i.ytimg.com/vi/5qap5aO4i9A/hqdefault.jpg",
            streamURL: "\(AppConfig.API.cloudRunBaseURL)/live/playlist",
            category: .entertainment,
            description: "Go Live playback",
            isLive: true,
            viewerCount: 0,
            quality: "HD",
            language: "English",
            country: "US",
            epgURL: nil,
            previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        )
    }
    
    private var channels: [LiveTVChannel] {
        let source = liveChannelsAPI.isEmpty ? LiveTVChannel.appStoreSafeChannels : liveChannelsAPI
        return Array(source.prefix(8))
    }
}

// MARK: - Minimal Movie Card (stable)
struct MinimalMovieCard: View {
    let movie: FreeMovie
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                MultiSourceAsyncImage(
                    urls: movie.posterCandidates,
                    content: { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    },
                    placeholder: {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemGray6))
                            .frame(width: 120, height: 180)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "film.stack")
                                        .font(.system(size: 24))
                                        .foregroundColor(.secondary)

                                    Text(movie.title)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .padding(.horizontal, 8)
                                }
                            )
                    }
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(movie.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(
                                    index < Int(movie.imdbRating / 2) ? .yellow : Color(.systemGray4)
                                )
                        }

                        Text("\(movie.imdbRating, specifier: "%.1f")")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 120, alignment: .leading)
            }
        }
        .buttonStyle(PressableScaleStyle(scale: 0.96))
    }
}

// MARK: - Minimal Channel Card (stable) 🔥
struct MinimalChannelCard: View {
    let channel: LiveTVChannel
    var autoPreview: Bool = false
    var previewOverrideStreamURL: String? = nil
    var previewOverridePosterURL: String? = nil
    var allowPlaybackInPreviews: Bool = false
    @State private var showPreview: Bool = false
    @State private var streamReady: Bool = false
    @State private var streamFailed: Bool = false

    var body: some View {
        // 🔥 Only show channel when video is actually playing - no placeholder!
        if !streamFailed {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    // 🔥 Live video thumbnail - only shows when playing
                    LiveChannelThumbnailView(
                        streamURL: previewOverrideStreamURL ?? channel.streamURL,
                        posterURL: previewOverridePosterURL ?? channel.logoURL,
                        fallbackStreamURL: channel.previewFallbackURL,
                        allowPlaybackInPreviews: allowPlaybackInPreviews,
                        channelCategory: channel.category,
                        channelName: channel.name,
                        channelId: channel.id,
                        onStreamFailed: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                streamFailed = true
                            }
                        },
                        onStreamReady: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                streamReady = true
                            }
                        },
                        cornerRadius: 12
                    )
                    .frame(width: 160, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(channel.category.color.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: channel.category.color.opacity(0.2), radius: 8, x: 0, y: 4)
                    // 🔥 Ensure touches pass through to NavigationLink
                    .allowsHitTesting(false)

                    // 🔥 LIVE badge with pulse animation
                    if channel.isLive {
                        VStack {
                            HStack {
                                LiveBadge()
                                Spacer()
                            }
                            Spacer()
                        }
                        .padding(8)
                        .allowsHitTesting(false)
                    }
                    
                    // Category badge bottom right
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(channel.category.displayName)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(channel.category.color.opacity(0.9))
                                )
                        }
                    }
                    .padding(6)
                    .allowsHitTesting(false)
                }
                .onAppear {
                    // 🔥 Always show preview immediately - no delay
                    showPreview = true
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("\(formatViewerCount(channel.viewerCount)) watching")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 160, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
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

// 🔥 Animated LIVE badge
struct LiveBadge: View {
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.white)
                .frame(width: 5, height: 5)
                .scaleEffect(isPulsing ? 1.3 : 1.0)
                .animation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true),
                    value: isPulsing
                )
            Text("LIVE")
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.red, Color.red.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .red.opacity(0.5), radius: 4, x: 0, y: 2)
        )
        .onAppear { isPulsing = true }
    }
}

// MARK: - Content Filter
enum ContentFilter: String, CaseIterable {
    case all = "all"
    case trending = "trending"
    case movies = "movies"
    case liveTV = "live_tv"
    case gaming = "gaming"
    case music = "music"
    case education = "education"

    var displayName: String {
        switch self {
        case .all: return "Home"
        case .trending: return "Trending"
        case .movies: return "Movies"
        case .liveTV: return "Live TV"
        case .gaming: return "Gaming"
        case .music: return "Music"
        case .education: return "Education"
        }
    }
}

// MARK: - Sleek Categories Section
struct MinimalCategoriesSection: View {
    let onPlayVideo: (Video) -> Void
    let codVideos: [Video]
    let musicVideos: [Video]
    let allVideos: [Video]

    @State private var selection: Category = .all

    enum Category: String, CaseIterable {
        case all = "All"
        case music = "Music"
        case gaming = "Gaming"
        case sports = "Sports"
        case news = "News"
        case tech = "Tech"
    }

    var current: [Video] {
        switch selection {
        case .all:
            return allVideos.shuffled()
        case .music:
            return musicVideos.shuffled()
        case .gaming:
            return codVideos.shuffled()
        case .sports:
            return allVideos.filter { $0.category == .sports || $0.tags.contains("sports") }.shuffled()
        case .news:
            return allVideos.filter { $0.category == .news || $0.tags.contains("news") }.shuffled()
        case .tech:
            return allVideos.filter { $0.category == .technology || $0.tags.contains("tech") }.shuffled()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Categories")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 20)

            // Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Category.allCases, id: \.self) { cat in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                selection = cat
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(cat.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(selection == cat ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selection == cat ? AppTheme.Colors.primary : Color(.systemGray6))
                            )
                        }
                        .buttonStyle(PressableScaleButtonStyle(scale: 0.97))
                    }
                }
                .padding(.horizontal, 20)
            }

            // Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(Array(current.prefix(18).enumerated()), id: \.offset) { index, video in
                        MinimalVideoCard(
                            video: video,
                            action: { onPlayVideo(video) },
                            useLivePreview: index < 3
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Top Artists Section (ML-Powered Real-Time Rankings)
struct TopArtistsSection: View {
    let rankings: [TopRankedUser]
    let sourceVideos: [Video]
    var onSelect: (String, String, [Video], Int) -> Void = { _,_,_,_  in }
    var onSeeAll: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Artists")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Spacer()
                
                Button {
                    HapticManager.shared.impact(style: .light)
                    onSeeAll()
                } label: {
                    Text("See all")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(rankings, id: \.id) { a in
                        Button {
                            let vids = sourceVideos.filter { matchesCreator($0, name: a.name) }
                            onSelect(a.name, a.avatar, vids, a.totalViews)
                        } label: {
                            RankCardView(user: a)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .background(AppTheme.Colors.background)
            }
        }
    }
}

// MARK: - Top Indie Filmmakers Section (ML-Powered Real-Time Rankings)
struct TopIndieFilmmakersSection: View {
    let rankings: [TopRankedUser]
    var onSeeAll: () -> Void = {}
    var onSelect: (String, [FreeMovie]) -> Void = { _,_ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Indie Filmmakers")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Spacer()
                
                Button {
                    HapticManager.shared.impact(style: .light)
                    onSeeAll()
                } label: {
                    Text("See all")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(rankings, id: \.id) { f in
                        Button {
                            onSelect(f.name, stableFilmSelection(seed: f.id, count: f.videoCount))
                        } label: {
                            RankCardView(user: f, subtitle: "\(f.videoCount) films • Score \(Int(f.overallScore))")
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .background(AppTheme.Colors.background)
            }
        }
    }
}

// MARK: - Top MyChannels Section (ML-Powered Real-Time Rankings)
struct TopMyChannelsSection: View {
    let rankings: [TopRankedUser]
    let sourceVideos: [Video]
    var onSelect: (String, String, Int, Int, [Video]) -> Void = { _,_,_,_,_ in }
    var onSeeAll: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top MyChannels")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Spacer()
                
                Button {
                    HapticManager.shared.impact(style: .light)
                    onSeeAll()
                } label: {
                    Text("See all")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(rankings, id: \.id) { channel in
                        Button {
                            HapticManager.shared.impact(style: .medium)
                            let vids = sourceVideos.filter { matchesCreator($0, name: channel.name) }
                            onSelect(channel.name, channel.avatar, channel.subscribers, channel.totalViews, vids)
                        } label: {
                            RankCardView(user: channel, subtitle: "\(TopRankMLService.formatCount(channel.subscribers)) subs")
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .background(AppTheme.Colors.background)
            }
        }
    }
}

// MARK: - Top-shelf helpers (shared by all three sections)

/// Normalizes a creator/rank name for matching: strips the "_c" channel suffix,
/// lowercases, and collapses separators. Used consistently everywhere a shelf
/// name is compared against a `Video.creator.displayName`.
private func normalizeRankName(_ value: String) -> String {
    value.lowercased()
        .replacingOccurrences(of: "_c", with: "")
        .replacingOccurrences(of: "_", with: " ")
        .replacingOccurrences(of: "-", with: " ")
        .replacingOccurrences(of: "  ", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Consistent creator↔shelf matching (replaces the old exact-`==` vs loose-`contains`
/// mismatch between the Artists and MyChannels shelves).
private func matchesCreator(_ video: Video, name: String) -> Bool {
    normalizeRankName(video.creator.displayName) == normalizeRankName(name)
}

/// Deterministic per-filmmaker film selection so tapping the same filmmaker always
/// opens the same catalog (previously used `.shuffled().prefix(random)` → changed
/// on every tap). Stable across launches via a small FNV-1a hash of the seed+id.
func stableFilmSelection(seed: String, count: Int) -> [FreeMovie] {
    func fnv1a(_ s: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in s.utf8 { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
        return hash
    }
    let clamped = min(max(count, 6), 10)
    return FreeMovie.sampleMovies
        .sorted { fnv1a(seed + $0.id) < fnv1a(seed + $1.id) }
        .prefix(clamped)
        .map { $0 }
}

// MARK: - See All List Views (ML-Powered — Top Artists / Filmmakers / Channels)

struct TopArtistsListView: View {
    let onDismiss: () -> Void
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var rankService = TopRankMLService.shared

    private var orderedRankings: [TopRankedUser] {
        rankService.topArtists.isEmpty ? TopRankMLService.fallbackTopArtists : rankService.topArtists
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(orderedRankings, id: \.id) { artist in
                    NavigationLink {
                        ArtistPageView(
                            artist: Artist(
                                id: artist.id,
                                name: artist.name,
                                slug: artist.name.lowercased().replacingOccurrences(of: " ", with: "-"),
                                avatarURL: URL(string: artist.avatar),
                                monthlyListeners: artist.totalViews
                            ),
                            topSongs: [],
                            albums: [],
                            singles: [],
                            similarArtists: []
                        )
                    } label: {
                        RankListRow(user: artist)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(.plain)
            .navigationTitle("Top Artists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        HapticManager.shared.impact(style: .light)
                        onDismiss()
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
    }
}

struct TopFilmmakersListView: View {
    let onDismiss: () -> Void
    @ObservedObject private var rankService = TopRankMLService.shared

    private var orderedRankings: [TopRankedUser] {
        rankService.topFilmmakers.isEmpty ? TopRankMLService.fallbackTopFilmmakers : rankService.topFilmmakers
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(orderedRankings, id: \.id) { filmmaker in
                    NavigationLink {
                        FilmmakerDetailView(
                            name: filmmaker.name,
                            films: stableFilmSelection(seed: filmmaker.id, count: filmmaker.videoCount)
                        )
                    } label: {
                        RankListRow(
                            user: filmmaker,
                            subtitle: "\(filmmaker.videoCount) films • Score \(Int(filmmaker.overallScore))"
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(.plain)
            .navigationTitle("Top Indie Filmmakers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        HapticManager.shared.impact(style: .light)
                        onDismiss()
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
    }
}

struct TopChannelsListView: View {
    let onDismiss: () -> Void
    @ObservedObject private var rankService = TopRankMLService.shared

    private var orderedRankings: [TopRankedUser] {
        rankService.topChannels.isEmpty ? TopRankMLService.fallbackTopChannels : rankService.topChannels
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(orderedRankings, id: \.id) { channel in
                    NavigationLink {
                        ChannelDetailView(
                            name: channel.name,
                            avatarURL: channel.avatar,
                            subscribers: channel.subscribers,
                            totalViews: channel.totalViews,
                            videos: []
                        )
                    } label: {
                        RankListRow(
                            user: channel,
                            subtitle: "\(TopRankMLService.formatCount(channel.subscribers)) subs"
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(.plain)
            .navigationTitle("Top MyChannels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        HapticManager.shared.impact(style: .light)
                        onDismiss()
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
    }
}

// MARK: - Reusable Row for See All Lists

struct RankListRow: View {
    let user: TopRankedUser
    var subtitle: String? = nil

    // Engine-assigned rank is the single source of truth, so this "#" always
    // agrees with the rank-change arrow below (both derive from `user.rank`).
    private var displayRank: Int { max(user.rank, 1) }

    private var displayName: String {
        user.name
            .replacingOccurrences(of: "_c", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displaySubtitle: String {
        subtitle ?? "\(TopRankMLService.formatCount(user.totalViews)) total views"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            HStack(spacing: 2) {
                Text("#\(displayRank)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                if user.rankChange > 0 {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.green)
                } else if user.rankChange < 0 {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            .frame(width: 36, height: 28)
            .background(Capsule().fill(AppTheme.Colors.primary))

            // Avatar
            if user.avatar.hasPrefix("asset://") {
                let assetName = String(user.avatar.dropFirst(8))
                if let img = UIImage(named: assetName) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    defaultAvatar
                }
            } else {
                AppAsyncImage(url: URL(string: user.avatar)) { img in
                    img.resizable().scaledToFill()
                } placeholder: { Color.gray.opacity(0.3) }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                        .lineLimit(1)
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                }
                Text(displaySubtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()

            // Score indicator
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(user.overallScore))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
                Text("score")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: user.rank)
    }

    private var defaultAvatar: some View {
        ZStack {
            Circle().fill(Color(.systemGray5))
            Image(systemName: "person.circle.fill")
                .resizable().scaledToFit()
                .foregroundColor(.secondary)
                .padding(10)
        }
        .frame(width: 44, height: 44)
    }
}

// MARK: - Scale Button Style
struct HomeScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview
// MARK: - For You Section
struct ForYouSection: View {
    let onPlayVideo: (Video) -> Void
    let onSeeAllExplore: () -> Void
    
    @EnvironmentObject private var appState: AppState
    @StateObject private var personalizedService = PersonalizedFeedService.shared
    @State private var forYouVideos: [Video] = {
        if let data = UserDefaults.standard.data(forKey: "forYouVideosCache"),
           let cached = try? JSONDecoder().decode([Video].self, from: data) {
            return cached
        }
        return []
    }()
    @State private var isLoading = false
    
    /// Last-resort view-level filter — blocks videos from rendering regardless of data source
    private var safeForYouVideos: [Video] {
        forYouVideos.filter { video in
            let t = video.title.lowercased()
            if t.contains("cooking with kya") { return false }
            if t.contains("screen recording 2025") { return false }
            let d = video.creator.displayName.lowercased()
            if d == "shot by keonta" { return false }
            let u = video.creator.username.lowercased()
            if u == "sbkeonta_" || u == "shotbykeonta" || u == "keontapeat" { return false }
            return true
        }
    }
    
    var body: some View {
        if !safeForYouVideos.isEmpty || appState.isAuthenticated {
            MinimalSection(
                title: "For You",
                seeAllAction: onSeeAllExplore
            ) {
                if isLoading {
                    ProgressView("Loading personalized feed...")
                        .frame(height: 101)
                        .padding(.horizontal, 20)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(Array(safeForYouVideos.prefix(8).enumerated()), id: \.element.id) { index, video in
                                MinimalVideoCard(
                                    video: video,
                                    action: { onPlayVideo(video) },
                                    useLivePreview: index < 3
                                )
                                .optimizeUIPerformance()
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .onAppear {
                if let uid = appState.currentUser?.id, !uid.isEmpty {
                    Task { await loadForYou(userId: uid) }
                }
            }
            .onChange(of: safeForYouVideos) { newVideos in
                // 🔥 Pre-buffer top 2 videos for INSTANT playback on tap
                for video in newVideos.prefix(2) {
                    GlobalVideoPlayerManager.shared.preloadVideo(url: video.videoURL)
                }
            }
        }
    }
    
    private func loadForYou(userId: String) async {
        isLoading = true
        print("🔍 [ForYou] Loading feed for userId: '\(userId)'")

        /// Filter out the current user's own uploaded videos from the feed.
        /// Uses multiple signals — creatorId, display name, username, AND specific titles.
        let ownerDisplayNames: Set<String> = ["shot by keonta"]
        let ownerUsernames: Set<String> = ["sbkeonta_", "shotbykeonta", "keontapeat"]
        let blockedTitleSubstrings = ["cooking with kya", "screen recording 2025"]
        func excludeOwn(_ videos: [Video]) -> [Video] {
            videos.filter { video in
                let titleLower = video.title.lowercased()
                let hasBlockedTitle = blockedTitleSubstrings.contains { titleLower.contains($0) }
                
                let shouldExclude = video.creatorId == userId ||
                                  ownerDisplayNames.contains(video.creator.displayName.lowercased()) ||
                                  ownerUsernames.contains(video.creator.username.lowercased()) ||
                                  hasBlockedTitle
                
                if shouldExclude {
                    print("🚫 [ForYou] Filtering out: '\(video.title)' by '\(video.creator.displayName)' (@\(video.creator.username)) [creatorId: \(video.creatorId)]")
                }
                
                return !shouldExclude
            }
        }

        // 🤖 AI RECOMMENDATIONS: Try Cloud Run agent first
        if let recResponse = try? await RealMLAgentsService.shared.getRecommendations(
            userId: userId,
            watchedVideos: [],
            likedVideos: [],
            preferredCategories: [],
            count: 20
        ), !recResponse.recommendations.isEmpty {
            let videoIds = recResponse.recommendations.map { $0.video_id }
            print("🤖 [HomeView] AI recommendations: \(videoIds.count) videos (personalization: \(Int(recResponse.personalization_score * 100))%)")
            let recVideos = (try? await VideoFirestoreService.shared.fetchMultipleVideos(videoIds: Array(videoIds.prefix(20)))) ?? []
            let filtered = excludeOwn(recVideos)
            print("🤖 [ForYou] AI recommendations: \(recVideos.count) → \(filtered.count) after filtering")
            if !filtered.isEmpty {
                await MainActor.run {
                    forYouVideos = filtered
                    isLoading = false
                    if let encoded = try? JSONEncoder().encode(filtered) {
                        UserDefaults.standard.set(encoded, forKey: "forYouVideosCache")
                    }
                }
                return
            }
        }

        // 🚀 Fallback: Use fair discovery engine for new creators
        let fairFeedVideos = await NewUserDiscoveryEngine.shared.generateFairFeed(
            limit: 20,
            userId: userId,
            includeNewCreators: true
        )

        let filteredFair = excludeOwn(fairFeedVideos)
        print("🚀 [ForYou] Fair discovery: \(fairFeedVideos.count) → \(filteredFair.count) after filtering")
        if !filteredFair.isEmpty {
            forYouVideos = filteredFair
            isLoading = false
            if let encoded = try? JSONEncoder().encode(filteredFair) {
                UserDefaults.standard.set(encoded, forKey: "forYouVideosCache")
            }
            print("✅ [HomeView] Loaded \(filteredFair.count) videos with new creator discovery")
            return
        }
        
        // Final fallback: Use home feed that includes uploaded videos
        let rawFeed = await personalizedService.generateHomeFeed(limit: 12)
        var feed = excludeOwn(rawFeed)
        print("📱 [ForYou] Final fallback: \(rawFeed.count) → \(feed.count) after filtering")
        
        // Add featured video "Juicy Booty Banger" at the beginning (fake video - thumbnail only)
        // IMPORTANT: Make sure the image in Assets.xcassets is named exactly "JuicyBootyBangerThumbnail" (case-sensitive)
        let assetName = "JuicyBootyBangerThumbnail"
        let thumbnailURL: String
        if UIImage(named: assetName) != nil {
            thumbnailURL = "asset://\(assetName)"
            print("✅ Found asset: \(assetName)")
        } else {
            // Fallback to placeholder if asset not found
            thumbnailURL = "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"
            print("⚠️ Asset '\(assetName)' not found in Assets.xcassets - using placeholder")
        }
        
        let featuredVideo = Video(
            id: "featured_juicy_booty_banger",
            title: "Juicy Booty Banger",
            description: "Content that gets people's attention",
            thumbnailURL: thumbnailURL,
            videoURL: "", // No actual video - just showing thumbnail
            duration: 180,
            viewCount: 5_000_000, // High view count to ensure it's at the top
            likeCount: 250_000,
            creator: User(
                username: "featured",
                displayName: "Featured",
                email: "noreply@mychannel.com",
                profileImageURL: nil,
                subscriberCount: 1_000_000,
                isVerified: true,
                isCreator: true
            ),
            category: .entertainment,
            tags: ["featured", "viral", "trending"],
            isPublic: true,
            quality: [.quality720p],
            aspectRatio: .landscape,
            isLiveStream: false,
            contentSource: .userUploaded,
            externalID: nil,
            isVerified: true
        )
        
        // Prepend featured video to the feed
        feed.insert(featuredVideo, at: 0)
        
        await MainActor.run {
            forYouVideos = feed
            isLoading = false
            if let encoded = try? JSONEncoder().encode(feed) {
                UserDefaults.standard.set(encoded, forKey: "forYouVideosCache")
            }
        }
    }
}

// MARK: - Ultra-Thermonuclear FAB Content 🔥💥
struct UltraThermonuclearFABContent: View {
    @State private var isPulsing = false
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        HStack(spacing: 8) {
            // 🔥 PULSING STAR ICON
            ZStack {
                // Outer glow pulse
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.yellow.opacity(0.6), .orange.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0.0 : 1.0)
                
                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow, .orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: .yellow.opacity(0.6), radius: 20, x: 0, y: 4)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.8), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                    )
                
                // Rotating highlight particles
                ForEach(0..<4) { index in
                    Image(systemName: "star")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: 20)
                        .rotationEffect(.degrees(Double(index) * 90 + rotationAngle))
                }
                
                // Star icon
                Image(systemName: "star.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .scaleEffect(isPulsing ? 1.1 : 1.0)
            }
            
            // Text
            Text("Manage Featured")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .padding(.trailing, 16)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .padding(.leading, 4)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .yellow.opacity(0.5), radius: 20, x: 0, y: 4)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .onAppear {
            // Continuous pulse animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
            
            // Continuous rotation for highlight particles
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

#Preview("HomeView") {
    HomeView()
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}
import UIKit
