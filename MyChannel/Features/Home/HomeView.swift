import SwiftUI
import Combine
import UIKit

// MARK: - Preview-safe onReceive helper
struct ConditionalOnReceiveModifier<P: Publisher>: ViewModifier where P.Failure == Never {
    let publisher: P?
    let action: (P.Output) -> Void

    func body(content: Content) -> some View {
        if let publisher {
            content.onReceive(publisher, perform: action)
        } else {
            content
        }
    }
}

enum FeaturedItem: Identifiable, Equatable {
    case video(Video)
    case friend(AssetStory)

    var id: String {
        switch self {
        case .video(let v): return "video-\(v.id)"
        case .friend(let s): return "friend-\(s.id.uuidString)"
        }
    }

    static func == (lhs: FeaturedItem, rhs: FeaturedItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Centralized Full Screen Routing
enum FullScreenRoute: Identifiable {
    case video(Video)
    case movie(FreeMovie)
    case search
    case stories(AssetStory)
    case allMovies
    case allLiveTV
    case trending

    var id: String {
        switch self {
        case .video(let v): return "video-\(v.id)"
        case .movie(let m): return "movie-\(m.id)"
        case .search: return "search"
        case .stories(let s): return "stories-\(s.id)"
        case .allMovies: return "allMovies"
        case .allLiveTV: return "allLiveTV"
        case .trending: return "trending"
        }
    }
}

// MARK: - HomeView
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var globalPlayer = GlobalVideoPlayerManager.shared

    @State private var scrollOffset: CGFloat = 0
    @State private var isRefreshing: Bool = false

    // Route-driven presentation (fixes white screen when dismissing covers)
    @State private var route: FullScreenRoute? = nil

    @State private var featuredContent: [Video] = []
    @State private var heroVideoIndex: Int = 0
    @State private var showingStories: Bool = true
    @State private var assetStories: [AssetStory] = AssetStory.sampleStories
    @Namespace private var storiesNS

    private var activeStoriesHeroId: UUID? {
        if case let .stories(story) = route { return story.id }
        return nil
    }

    private var isRunningInPreview: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        #else
        return false
        #endif
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        Color.clear.frame(height: 100)

                        if showingStories {
                            AssetBouncyStoriesRow(
                                stories: assetStories,
                                onStoryTap: { story in
                                    route = .stories(story)
                                },
                                onAddStory: {
                                    HapticManager.shared.impact(style: .medium)
                                    showStoryCreator()
                                },
                                ns: storiesNS,
                                activeHeroId: activeStoriesHeroId
                            )
                            .zIndex(2)
                            .padding(.bottom, 32)
                        }

                        MinimalHeroSection(
                            featuredContent: featuredContent,
                            heroVideoIndex: heroVideoIndex,
                            onPlayVideo: { video in
                                route = .video(video)
                            },
                            onAddToList: toggleWatchLater
                        )
                        .padding(.bottom, 40)

                        MinimalContentSections(
                            onPlayVideo: { video in route = .video(video) },
                            onSelectMovie: { movie in route = .movie(movie) },
                            onSeeAllFreeMovies: { route = .allMovies },
                            onSeeAllLiveTV: { route = .allLiveTV },
                            onSeeAllTrending: { route = .trending }
                        )

                        Color.clear.frame(height: 100)
                    }
                }
                .coordinateSpace(name: "scroll")
                .onScrollOffsetChange { offset in
                    scrollOffset = offset
                }

                MinimalNavigationHeader(
                    scrollOffset: scrollOffset,
                    onSearchTap: { route = .search },
                    onProfileTap: {
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToProfileTab"), object: nil)
                    }
                )
                .allowsHitTesting(true)
                .zIndex(1)
            }
        }
        .onAppear(perform: setupContent)
        .refreshable { await refreshContent() }
        .sheet(isPresented: $presentStoryCreator) {
            CreateStoryView { newStory in
                let media: AssetMedia = (newStory.mediaType == .video) ? .video(newStory.mediaURL) : .image(newStory.mediaURL)
                let placeholder = AssetStory(media: media, username: appState.currentUser?.username ?? "you", authorImageName: "")
                assetStories.insert(placeholder, at: 0)
                presentStoryCreator = false
            }
            .preferredColorScheme(.dark)
        }
        .modifier(
            ConditionalOnReceiveModifier(
                publisher: isRunningInPreview ? nil : Timer.publish(every: 10.0, on: .main, in: .common).autoconnect(),
                action: { _ in
                    withAnimation(.easeInOut(duration: 1.0)) {
                        heroVideoIndex = (heroVideoIndex + 1) % max(1, featuredContent.count)
                    }
                }
            )
        )
        .fullScreenCover(item: $route) { route in
            switch route {
            case .video(let video):
                VideoDetailView(video: video)
                    .onDisappear { self.route = nil }

            case .movie(let movie):
                MovieDetailView(movie: movie)
                    .onDisappear { self.route = nil }

            case .search:
                SearchView()
                    .onDisappear { self.route = nil }

            case .stories(let story):
                AssetStoriesPagerView(
                    stories: assetStories,
                    initialIndex: assetStories.firstIndex(where: { $0.id == story.id }) ?? 0
                ) {
                    self.route = nil
                }
                .onDisappear { self.route = nil }

            case .allMovies:
                MoviesView()
                    .environmentObject(appState)
                    .background(Color(.systemBackground).ignoresSafeArea())
                    .onDisappear { self.route = nil }

            case .allLiveTV:
                LiveTVChannelsView()
                    .environmentObject(appState)
                    .background(Color(.systemBackground).ignoresSafeArea())
                    .onDisappear { self.route = nil }

            case .trending:
                TrendingView()
                    .background(Color(.systemBackground).ignoresSafeArea())
                    .onDisappear { self.route = nil }
            }
        }
        .onChange(of: route?.id) { _, newValue in
            let shouldPause = newValue != nil
            NotificationCenter.default.post(
                name: NSNotification.Name(shouldPause ? "LivePreviewsShouldPause" : "LivePreviewsShouldResume"),
                object: nil
            )
        }
    }

    // MARK: - Setup Methods
    @State private var presentStoryCreator: Bool = false
    private func setupContent() {
        featuredContent = Video.sampleVideos.filter { $0.viewCount > 500_000 }.shuffled()
        if featuredContent.isEmpty {
            featuredContent = Array(Video.sampleVideos.prefix(3))
        }
    }

    private func refreshContent() async {
        isRefreshing = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        setupContent()
        isRefreshing = false
    }

    // MARK: - Action Methods
    private func showStoryCreator() {
        presentStoryCreator = true
    }

    private func toggleWatchLater(_ video: Video) {
        appState.toggleWatchLater(for: video.id)
        HapticManager.shared.impact(style: .light)
    }
}

// MARK: - Minimal Navigation Header
struct MinimalNavigationHeader: View {
    let scrollOffset: CGFloat
    let onSearchTap: () -> Void
    let onProfileTap: () -> Void

    @EnvironmentObject private var appState: AppState

    private var logoSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone ? 24 : 28
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 12) {
                    Image("MyChannel")
                        .resizable()
                        .renderingMode(.original)
                        .interpolation(.high)
                        .antialiased(true)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: logoSize, height: logoSize)

                    Text("MyChannel")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }

                Spacer()

                HStack(spacing: 24) {
                    Button(action: onSearchTap) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                    }

                    NavigationLink(destination: NotificationsView()) {
                        ZStack {
                            Image(systemName: "bell")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)

                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                                .offset(x: 6, y: -6)
                                .opacity(1)
                        }
                    }

                    Button(action: onProfileTap) {
                        AsyncImage(url: URL(string: appState.currentUser?.profileImageURL ?? "")) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(white: 0.97), Color(white: 0.92)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)
                                )
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 50)
            .padding(.bottom, 16)
            .background(
                Group {
                    if scrollOffset > 50 {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .transition(.opacity)
                    } else {
                        Color.clear
                    }
                }
            )
            .animation(.easeInOut(duration: 0.25), value: scrollOffset > 50)
        }
        .allowsHitTesting(true)
    }
}

// MARK: - Minimal Stories Section
struct MinimalStoriesSection: View {
    let stories: [AssetStory]
    let onStoryTap: (AssetStory) -> Void
    let onAddStory: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                Button(action: onAddStory) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 60, height: 60)

                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.primary)
                        }

                        Text("Your Story")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                ForEach(stories) { story in
                    Button(action: { onStoryTap(story) }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.pink, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                                    .frame(width: 64, height: 64)

                                if UIImage(named: story.authorImageName) != nil {
                                    Image(story.authorImageName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 58, height: 58)
                                        .clipShape(Circle())
                                } else {
                                    AsyncImage(url: URL(string: "https://picsum.photos/200/200?random=\(abs(story.id.hashValue))")) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 58, height: 58)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        Circle()
                                            .fill(Color(.systemGray5))
                                            .frame(width: 58, height: 58)
                                    }
                                }
                            }

                            Text(story.username)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }

}

// (Moved loadBlockbusters() into MinimalContentSections below)

// MARK: - Minimal Hero Section
struct MinimalHeroSection: View {
    let featuredContent: [Video]
    let heroVideoIndex: Int
    let onPlayVideo: (Video) -> Void
    let onAddToList: (Video) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }

    var body: some View {
        if !featuredContent.isEmpty {
            let currentVideo = featuredContent[heroVideoIndex % featuredContent.count]

            VStack(spacing: 20) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.yellow)

                        Text("FEATURED")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                            .tracking(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(.systemGray6)))

                    Spacer()
                }
                .padding(.horizontal, 20)

                AsyncImage(url: URL(string: currentVideo.thumbnailURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemGray6))
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: currentVideo.category.iconName)
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)

                                Text(currentVideo.title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .padding(.horizontal, 40)
                            }
                        )
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    Text(currentVideo.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(isCompact ? .leading : .center)
                        .frame(maxWidth: .infinity, alignment: isCompact ? .leading : .center)
                        .lineLimit(2)
                        .padding(.horizontal, 20)

                    Text("\(currentVideo.category.displayName) • \(currentVideo.formattedDuration) • \(currentVideo.formattedViewCount) views")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: isCompact ? .leading : .center)
                        .padding(.horizontal, 20)

                    HStack(spacing: 12) {
                        Button(action: { onPlayVideo(currentVideo) }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Play")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .padding(.horizontal, 12)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        Button(action: { onAddToList(currentVideo) }) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 48, height: 48)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

}

// MARK: - Minimal Content Sections
struct MinimalContentSections: View {
    let onPlayVideo: (Video) -> Void
    let onSelectMovie: (FreeMovie) -> Void
    let onSeeAllFreeMovies: () -> Void
    let onSeeAllLiveTV: () -> Void
    let onSeeAllTrending: () -> Void

    @EnvironmentObject private var appState: AppState
    @State private var blockbusterMovies: [FreeMovie] = []
    @State private var loadingBlockbusters: Bool = false

    var body: some View {
        VStack(spacing: 40) {
            if !appState.watchHistory.isEmpty {
                MinimalSection(
                    title: "Continue Watching",
                    seeAllAction: nil
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(Video.sampleVideos.prefix(5)) { video in
                                MinimalVideoCard(video: video, action: { onPlayVideo(video) })
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }

            MinimalSection(
                title: "Trending Now",
                seeAllAction: { onSeeAllTrending() }
            ) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(Video.sampleVideos.filter { $0.viewCount > 100_000 }.prefix(8)) { video in
                            MinimalVideoCard(video: video, action: { onPlayVideo(video) })
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            MinimalSection(
                title: "Movies",
                seeAllAction: { onSeeAllFreeMovies() }
            ) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 16) {
                        let movies = blockbusterMovies.isEmpty ? Array(FreeMovie.sampleMovies.prefix(6)) : Array(blockbusterMovies.prefix(12))
                        ForEach(movies) { movie in
                            MinimalMovieCard(movie: movie, action: { onSelectMovie(movie) })
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            MinimalSection(
                title: "Live TV",
                seeAllAction: { onSeeAllLiveTV() }
            ) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(LiveTVChannel.sampleChannels.prefix(8)) { channel in
                            NavigationLink(destination: LiveTVPlayerView(channel: channel)) {
                                MinimalChannelCard(channel: channel)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .task { await loadBlockbusters() }
    }

    // Loader for TMDB popular trailers powering the Home Free Movies row
    fileprivate func loadBlockbusters() async {
        guard blockbusterMovies.isEmpty else { return }
        loadingBlockbusters = true
        defer { loadingBlockbusters = false }
        do {
            guard !AppSecrets.tmdbAPIKey.isEmpty else {
                print("[TMDB] API key missing. Showing sample movies.")
                return
            }

            let items = try await TMDBService.shared.fetchPopularWithTrailersUS(page: 1, limit: 30)
            var chosen: [FreeMovie] = items.filter { $0.trailerURL != nil }

            if chosen.isEmpty {
                print("[TMDB] No trailer-attached items returned. Falling back to popular items without trailer filter.")
                chosen = items
            }

            if chosen.isEmpty {
                print("[TMDB] Popular items still empty. Falling back to free-with-ads providers list.")
                let freeList = try await TMDBService.shared.fetchFreeWithAdsMoviesUS(page: 1, limit: 20)
                chosen = freeList
            }

            let boosted = chosen.sorted { lhs, rhs in
                let boost: (FreeMovie) -> Int = { m in
                    let t = m.title.lowercased()
                    return (t.contains("smile 2") || t.contains("sinners")) ? 1 : 0
                }
                if boost(lhs) != boost(rhs) { return boost(lhs) > boost(rhs) }
                if lhs.year != rhs.year { return lhs.year > rhs.year }
                return lhs.imdbRating > rhs.imdbRating
            }

            await MainActor.run {
                self.blockbusterMovies = boosted
            }
        } catch {
            print("[TMDB] Error loading blockbusters: \(error)")
        }
    }
}

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
                    .foregroundColor(.primary)

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

// MARK: - Minimal Video Card
struct MinimalVideoCard: View {
    let video: Video
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 180, height: 101)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemGray6))
                        .frame(width: 180, height: 101)
                        .overlay(
                            Image(systemName: video.category.iconName)
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                        )
                }
                .overlay(
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(video.formattedDuration)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(.black.opacity(0.7))
                                )
                                .padding(8)
                        }
                    }
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .frame(height: 36, alignment: .top)

                    Text(video.creator.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Text("\(video.formattedViewCount) views")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(width: 180, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Minimal Movie Card
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
        .buttonStyle(PlainButtonStyle())
    }
}

struct MinimalChannelCard: View {
    let channel: LiveTVChannel
    @State private var showPreview: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if showPreview {
                    LiveChannelThumbnailView(
                        streamURL: channel.streamURL,
                        posterURL: channel.logoURL,
                        fallbackStreamURL: channel.previewFallbackURL
                    )
                        .frame(width: 160, height: 90)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    AsyncImage(url: URL(string: channel.logoURL)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color(.systemGray6)
                    }
                    .frame(width: 160, height: 90)
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
            .frame(width: 160, alignment: .leading)
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

// MARK: - Preview
#Preview("HomeView") {
    HomeView()
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}