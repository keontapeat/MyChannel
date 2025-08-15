import SwiftUI
import Combine

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
                            selectedIndex: $heroVideoIndex,
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
        // Base picks
        var base = Video.sampleVideos.filter { $0.viewCount > 500_000 }

        let friend = friendHeroVideos()
        // Deduplicate by id while preserving order
        let combined = (friend + base).reduce(into: [String: Video]()) { acc, v in
            if acc[v.id] == nil { acc[v.id] = v }
        }
        featuredContent = Array(combined.values)

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

    private func friendHeroVideos() -> [Video] {
        let friendUser = User(
            username: "scatz",
            displayName: "Scatz",
            email: "music@artist.com",
            profileImageURL: "https://i.ytimg.com/vi/71GJrAY54Ew/hqdefault.jpg",
            bannerImageURL: nil,
            bio: "Artist",
            subscriberCount: 21_300,
            videoCount: 0,
            isVerified: true,
            isCreator: true
        )

        let v1 = Video(
            id: "friend_yt_71GJrAY54Ew",
            title: "Scatz - Rebound ( Official Music Video ) Shot By @ImmortalVision",
            description: "Official music video. Shot by @ImmortalVision.",
            thumbnailURL: "https://i.ytimg.com/vi/71GJrAY54Ew/maxresdefault.jpg",
            videoURL: "https://www.youtube.com/watch?v=71GJrAY54Ew",
            duration: 94,
            viewCount: 5_000,
            likeCount: 191,
            commentCount: 12,
            createdAt: Calendar.current.date(byAdding: .weekOfYear, value: -4, to: Date()) ?? Date(),
            creator: friendUser,
            category: .music,
            tags: ["music","official","video","scatz","immortalvision"],
            isPublic: true,
            quality: [.quality720p],
            aspectRatio: .landscape,
            isLiveStream: false,
            contentSource: .youtube,
            externalID: "71GJrAY54Ew",
            isVerified: true
        )

        let v2 = Video(
            id: "friend_yt_d17K2Tl_Ljg",
            title: "Scatz - Hibachi ( Official Music Video )",
            description: "Official music video.",
            thumbnailURL: "https://i.ytimg.com/vi/d17K2Tl_Ljg/maxresdefault.jpg",
            videoURL: "https://www.youtube.com/watch?v=d17K2Tl_Ljg",
            duration: 120,
            viewCount: 4_200,
            likeCount: 150,
            commentCount: 8,
            createdAt: Calendar.current.date(byAdding: .weekOfYear, value: -10, to: Date()) ?? Date(),
            creator: friendUser,
            category: .music,
            tags: ["music","official","video","scatz"],
            isPublic: true,
            quality: [.quality720p],
            aspectRatio: .landscape,
            isLiveStream: false,
            contentSource: .youtube,
            externalID: "d17K2Tl_Ljg",
            isVerified: true
        )

        return [v1, v2]
    }
}

// MARK: - Minimal Navigation Header
struct MinimalNavigationHeader: View {
    let scrollOffset: CGFloat
    let onSearchTap: () -> Void
    let onProfileTap: () -> Void

    @EnvironmentObject private var appState: AppState

    private var logoSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone ? 28 : 32
    }

    var body: some View {
        let showBackground = scrollOffset > 50
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
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }

                Spacer()

                HStack(spacing: 14) {
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        onSearchTap()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 34, height: 34)
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: NotificationsView()) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 34, height: 34)
                            Image(systemName: "bell")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)

                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                                .offset(x: 8, y: -8)
                                .opacity(1)
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        onProfileTap()
                    }) {
                        ProfileAvatarView(urlString: appState.currentUser?.profileImageURL, size: 28)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 44)
            .padding(.bottom, 12)
            .background(
                Group {
                    if showBackground {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .transition(.opacity)
                    } else {
                        Color.clear
                    }
                }
            )
            .animation(.easeInOut(duration: 0.25), value: showBackground)
        }
        .allowsHitTesting(true)
    }
}

// MARK: - Minimal Hero Section (now a pager)
struct MinimalHeroSection: View {
    let featuredContent: [Video]
    @Binding var selectedIndex: Int
    let onPlayVideo: (Video) -> Void
    let onAddToList: (Video) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }

    var body: some View {
        if !featuredContent.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.yellow)
                    Text("FEATURED")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                        .tracking(1)
                }
                .padding(.horizontal, 20)

                TabView(selection: $selectedIndex) {
                    ForEach(Array(featuredContent.enumerated()), id: \.offset) { index, vid in
                        FeaturedHeroCard(
                            video: vid,
                            isCompact: isCompact,
                            onPlay: { onPlayVideo(vid) },
                            onAddToList: { onAddToList(vid) }
                        )
                        .padding(.horizontal, 20)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 250)
            }
        }
    }
}

private struct FeaturedHeroCard: View {
    let video: Video
    let isCompact: Bool
    let onPlay: () -> Void
    let onAddToList: () -> Void

    @State private var isPressed = false
    @EnvironmentObject private var appState: AppState

    var body: some View {
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

        ZStack {
            // Media layer (poster + optional live autoplay)
            ZStack {
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

                if !isPreview {
                    VideoLiveThumbnailView(video: video, cornerRadius: 16)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 230)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                LinearGradient(
                    colors: [Color.black.opacity(0.35), .clear, Color.black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            )

            // Overlayed content
            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: video.category.iconName)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.35)))

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                        Text(video.formattedDuration)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.35)))
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)

                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Label(video.creator.displayName, systemImage: "person.crop.circle")
                        Label("\(video.formattedViewCount) views", systemImage: "eye")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))

                    HStack(spacing: 12) {
                        Button(action: {
                            HapticManager.shared.impact(style: .medium)
                            onPlay()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Play")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(height: 48)
                            .frame(maxWidth: .infinity)
                            .background(Color.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(PressableScaleButtonStyle(scale: 0.98))

                        Button(action: {
                            HapticManager.shared.impact(style: .light)
                            onAddToList()
                        }) {
                            let saved = appState.isVideoInWatchLater(video.id)
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white)
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                                Image(systemName: saved ? "checkmark" : "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(saved ? AppTheme.Colors.primary : .black)
                            }
                            .frame(width: 48, height: 48)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(PressableScaleButtonStyle(scale: 0.95))
                        .accessibilityLabel("Watch later")
                        .accessibilityHint("Add or remove from your Watch Later")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .compositingGroup()
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 12)
        .scaleEffect(isPressed ? 0.99 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.01, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(video.creator.displayName) • \(video.formattedViewCount) views")
        .accessibilityHint("Plays the featured video")
        .onAppear {
            NotificationCenter.default.post(name: NSNotification.Name("LivePreviewsShouldResume"), object: nil)
        }
        .onDisappear {
            NotificationCenter.default.post(name: NSNotification.Name("LivePreviewsShouldPause"), object: nil)
        }
    }
}

extension Video {
    var posterCandidates: [URL] {
        var urls: [URL] = []
        var seen = Set<String>()

        func add(_ s: String) {
            if !s.isEmpty, seen.insert(s).inserted, let u = URL(string: s) {
                urls.append(u)
            }
        }

        // 1) Use provided thumbnail if present
        add(thumbnailURL)

        // 2) Prefer YouTube covers when applicable
        if contentSource == .youtube {
            let yid = externalID.flatMap { $0.isEmpty ? nil : $0 } ?? id
            add("https://i.ytimg.com/vi/\(yid)/maxresdefault.jpg")
            add("https://i.ytimg.com/vi/\(yid)/hqdefault.jpg")
        }

        // 3) Seeded fallback to guarantee an image
        add("https://picsum.photos/seed/\(abs(id.hashValue))/400/225")

        return urls
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
    @State private var friendChannelVideos: [Video] = []

    private var friendVideoId: String { "friend_video_yt_71GJrAY54Ew" }
    private var friendChannelID: String { "UCITAM_FKtyKEq40aHVXFTcQ" }

    private func makeFriendTrendingVideo() -> Video {
        let friendUser = User(
            username: "scatz",
            displayName: "Scatz",
            email: "music@artist.com",
            profileImageURL: "https://i.ytimg.com/vi/71GJrAY54Ew/hqdefault.jpg",
            bannerImageURL: nil,
            bio: "Artist",
            subscriberCount: 21_300,
            videoCount: 0,
            isVerified: true,
            isCreator: true
        )
        return Video(
            id: friendVideoId,
            title: "Scatz - Rebound ( Official Music Video ) Shot By @ImmortalVision",
            description: "Official music video. Shot by @ImmortalVision.",
            thumbnailURL: "https://i.ytimg.com/vi/71GJrAY54Ew/hqdefault.jpg",
            videoURL: "https://www.youtube.com/watch?v=71GJrAY54Ew",
            duration: 94,
            viewCount: 5_000,
            likeCount: 191,
            commentCount: 12,
            createdAt: Calendar.current.date(byAdding: .weekOfYear, value: -4, to: Date()) ?? Date(),
            creator: friendUser,
            category: .music,
            tags: ["music","official","video","scatz","immortalvision"],
            isPublic: true,
            quality: [.quality720p],
            aspectRatio: .landscape,
            isLiveStream: false,
            contentSource: .youtube,
            externalID: "71GJrAY54Ew",
            isVerified: true
        )
    }

    private func extraTrendingVideos() -> [Video] {
        let friendUser = User(
            username: "scatz",
            displayName: "Scatz",
            email: "music@artist.com",
            profileImageURL: "https://i.ytimg.com/vi/71GJrAY54Ew/hqdefault.jpg",
            bannerImageURL: nil,
            bio: "Artist",
            subscriberCount: 21_300,
            videoCount: 0,
            isVerified: true,
            isCreator: true
        )
        let entries: [(id: String, title: String)] = [
            ("71GJrAY54Ew", "Scatz - Rebound (Official Music Video)"),
            ("F98vGhQDrB8", "YouTube Video F98vGhQDrB8")
        ]
        return entries.map { e in
            Video(
                id: "yt_\(e.id)",
                title: e.title,
                description: "Official video",
                thumbnailURL: "https://i.ytimg.com/vi/\(e.id)/hqdefault.jpg",
                videoURL: "https://www.youtube.com/watch?v=\(e.id)",
                duration: Double.random(in: 90...300),
                viewCount: Int.random(in: 3_000...2_000_000),
                likeCount: Int.random(in: 100...50_000),
                commentCount: Int.random(in: 10...10_000),
                createdAt: Date(),
                creator: friendUser,
                category: .music,
                tags: ["music","official","video","friend"],
                isPublic: true,
                quality: [.quality720p],
                aspectRatio: .landscape,
                isLiveStream: false,
                contentSource: .youtube,
                externalID: e.id,
                isVerified: true
            )
        }
    }

    private func detroitFlintArtistsTrending() -> [Video] {
        func yt(_ id: String, _ title: String, _ artist: String, views: Int) -> Video {
            Video(
                id: "yt_\(id)",
                title: title,
                description: "\(artist) • Official Video",
                thumbnailURL: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg",
                videoURL: "https://www.youtube.com/watch?v=\(id)",
                duration: Double.random(in: 120.0...240.0),
                viewCount: views,
                likeCount: Int(Double(views) * 0.06),
                commentCount: Int(Double(views) * 0.01),
                creator: User(username: artist.replacingOccurrences(of: " ", with: "_").lowercased(),
                              displayName: artist,
                              email: "artist@music.com",
                              profileImageURL: "https://i.pravatar.cc/200?u=\(artist)",
                              isVerified: true,
                              isCreator: true),
                category: .music,
                tags: ["detroit","flint","music","rap"],
                isPublic: true,
                quality: [.quality720p],
                aspectRatio: .landscape,
                isLiveStream: false,
                contentSource: .youtube,
                externalID: id,
                isVerified: true
            )
        }
        return [
            yt("qGQhX_iQZu4", "Tee Grizzley - First Day Out", "Tee Grizzley", views: 265_000_000),
            yt("3Btk3asR_vc", "Sada Baby - Whole Lotta Choppas", "Sada Baby", views: 96_000_000),
            yt("7bUr0vbJIUK", "Icewear Vezzo - Up The Scoe ft. Lil Durk", "Icewear Vezzo", views: 47_000_000),
            yt("N8WcJ5d0-YI", "Babyface Ray - What The Business Is", "Babyface Ray", views: 20_000_000),
            yt("kQ3JrQxv7CM", "Peezy - 2 Million Up", "Peezy", views: 56_000_000),
            yt("w6B2Kp4eX1M", "Rebirth Island High Kill Gameplay", "Peezy", views: 1_650_000),
            yt("q1Zk3Lm0TyU", "Top 10 Tips to Win More Gunfights", "Peezy", views: 1_050_000),
            yt("m2N9rV3xQeE", "Warzone Movement Guide", "Peezy", views: 880_000)
        ]
    }

    private func gamingCOD() -> [Video] {
        func yt(_ id: String, _ title: String, views: Int) -> Video {
            Video(
                id: "yt_\(id)",
                title: title,
                description: "Call of Duty gameplay",
                thumbnailURL: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg",
                videoURL: "https://www.youtube.com/watch?v=\(id)",
                duration: Double.random(in: 600.0...1800.0),
                viewCount: views,
                likeCount: Int(Double(views) * 0.05),
                commentCount: Int(Double(views) * 0.007),
                creator: User(username: "cod_channel", displayName: "COD Highlights", email: "cod@yt.com", profileImageURL: "https://i.pravatar.cc/200?u=cod", isVerified: true, isCreator: true),
                category: .gaming,
                tags: ["gaming","cod","modern warfare","warzone"],
                isPublic: true,
                quality: [.quality720p],
                aspectRatio: .landscape,
                isLiveStream: false,
                contentSource: .youtube,
                externalID: id,
                isVerified: true
            )
        }
        return [
            yt("x9v2Q8l2dY4", "Warzone 2: 20 Kill Solo Win!", views: 2_400_000),
            yt("b8r0Jk1aZsQ", "MW3 Ranked Play – Tactical Nuke!", views: 1_200_000),
            yt("p7C1LkQ0vPY", "Best Kastov‑74u Class Setup (MWII)", views: 980_000),
            yt("w6B2Kp4eX1M", "Rebirth Island High Kill Gameplay", views: 1_650_000),
            yt("q1Zk3Lm0TyU", "Top 10 Tips to Win More Gunfights", views: 1_050_000),
            yt("m2N9rV3xQeE", "Warzone Movement Guide", views: 880_000)
        ]
    }

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
                        let base = friendChannelVideos.isEmpty ? [] : friendChannelVideos
                        let merged = [makeFriendTrendingVideo()] + base + extraTrendingVideos()
                        var seen = Set<String>()
                        let dedup = merged.filter { v in
                            if seen.contains(v.id) { return false }
                            seen.insert(v.id)
                            return true
                        }
                        ForEach(dedup.prefix(20)) { video in
                            MinimalVideoCard(
                                video: video,
                                action: { onPlayVideo(video) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            MinimalCategoriesSection(
                onPlayVideo: onPlayVideo,
                codVideos: gamingCOD(),
                musicVideos: detroitFlintArtistsTrending(),
                allVideos: {
                    var vids = detroitFlintArtistsTrending() + gamingCOD() + Video.sampleVideos
                    vids.insert(makeFriendTrendingVideo(), at: 0)
                    return vids
                }()
            )

            MinimalSection(
                title: "Live TV",
                seeAllAction: { onSeeAllLiveTV() }
            ) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        let channels = Array(LiveTVChannel.sampleChannels.prefix(8))
                        ForEach(Array(channels.enumerated()), id: \.element.id) { index, channel in
                            NavigationLink(destination: LiveTVPlayerView(channel: channel)) {
                                MinimalChannelCard(channel: channel, autoPreview: index < 3)
                            }
                            .buttonStyle(PlainButtonStyle())
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

            TopArtistsSection(
                sourceVideos: detroitFlintArtistsTrending() + [makeFriendTrendingVideo()] + Video.sampleVideos
            )
            .padding(.horizontal, 20)
            TopIndieFilmmakersSection()
            .padding(.horizontal, 20)

            TopMyChannelsSection(
                sourceVideos: detroitFlintArtistsTrending() + gamingCOD() + Video.sampleVideos
            )
            .padding(.horizontal, 20)
        }
        .task { await loadBlockbusters() }
        .task { await loadFriendChannelVideos() }
    }

    // Loader for TMDB popular trailers powering the Home Free Movies row
    private func loadBlockbusters() async {
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

    private func loadFriendChannelVideos() async {
        guard friendChannelVideos.isEmpty else { return }
        do {
            let items = try await YouTubeAPIService.shared.fetchChannelVideos(channelID: friendChannelID, maxResults: 24)
            await MainActor.run {
                self.friendChannelVideos = items
            }
        } catch {
            print("[YouTube] Error loading friend channel: \(error)")
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
    var useLivePreview: Bool = false

    var body: some View {
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    if useLivePreview && !isPreview {
                        VideoLiveThumbnailView(video: video, cornerRadius: 12)
                            .frame(width: 180, height: 101)
                    } else {
                        MultiSourceAsyncImage(
                            urls: video.posterCandidates,
                            content: { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 180, height: 101)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            },
                            placeholder: {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.systemGray6))
                                    .frame(width: 180, height: 101)
                                    .overlay(
                                        Image(systemName: video.category.iconName)
                                            .font(.system(size: 24))
                                            .foregroundColor(.secondary)
                                    )
                            }
                        )
                    }
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
                                .background(Capsule().fill(.black.opacity(0.7)))
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
    var autoPreview: Bool = false
    @State private var showPreview: Bool = false

    var body: some View {
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
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
                    AppAsyncImage(url: URL(string: channel.logoURL)) { image in
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
            .onAppear {
                showPreview = autoPreview && !isPreview
            }
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

// MARK: - Sleek Categories Section
private struct MinimalCategoriesSection: View {
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
            return Video.sampleVideos.shuffled()
        case .news:
            return Video.sampleVideos.shuffled()
        case .tech:
            return (Video.sampleVideos.filter { $0.category == .technology } + Video.sampleVideos).shuffled()
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
                    ForEach(current.prefix(18)) { video in
                        MinimalVideoCard(video: video, action: {
                            onPlayVideo(video)
                        }, useLivePreview: true)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Top Artists Section
private struct TopArtistsSection: View {
    let sourceVideos: [Video]

    private var rankings: [ArtistRank] {
        let grouped = Dictionary(grouping: sourceVideos) { $0.creator.displayName }
        let ranks = grouped.map { (name, vids) -> ArtistRank in
            let views = vids.reduce(0) { $0 + $1.viewCount }
            return ArtistRank(
                name: name,
                views: views,
                avatar: vids.first?.creator.profileImageURL ?? "https://i.pravatar.cc/200?u=\(name)"
            )
        }
        return ranks.sorted { $0.views > $1.views }.prefix(10).map { $0 }
    }

    struct ArtistRank: Identifiable {
        let id = UUID()
        let name: String
        let views: Int
        let avatar: String
    }

    private func format(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n)/1_000) }
        return "\(n)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Artists")
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 4)

            VStack(spacing: 0) {
                ForEach(Array(rankings.enumerated()), id: \.offset) { idx, a in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(AppTheme.Colors.primary.opacity(0.12))
                            Text("\(idx + 1)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        .frame(width: 32, height: 32)

                        AppAsyncImage(url: URL(string: a.avatar)) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Color(.systemGray5)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.name)
                                .font(.system(size: 15, weight: .semibold))
                            Text("\(format(a.views)) total views")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .background(Color.white)
                    .overlay(alignment: .bottom) {
                        if idx < rankings.count - 1 {
                            Rectangle()
                                .fill(Color.black.opacity(0.06))
                                .frame(height: 0.5)
                                .padding(.leading, 56)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
            )
        }
    }
}

// MARK: - Top Indie Filmmakers Section
private struct TopIndieFilmmakersSection: View {
    struct Filmmaker: Identifiable {
        let id = UUID()
        let name: String
        let films: Int
        let score: Int
        let avatar: String
    }

    private var filmmakers: [Filmmaker] {
        let names = [
            "A. Rivers", "N. Carter", "M. Sloan", "J. Patel", "R. Alvarez",
            "S. Kim", "D. Morgan", "K. O’Neal", "B. Laurent", "T. Ito"
        ]
        let items = names.enumerated().map { idx, n in
            Filmmaker(
                name: n,
                films: Int.random(in: 2...12),
                score: Int.random(in: 60...99),
                avatar: "https://i.pravatar.cc/200?u=indie_\(idx)"
            )
        }
        return items.sorted { $0.score > $1.score }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Indie Filmmakers")
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 4)

            VStack(spacing: 0) {
                ForEach(Array(filmmakers.enumerated()), id: \.offset) { idx, f in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(AppTheme.Colors.primary.opacity(0.12))
                            Text("\(idx + 1)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        .frame(width: 32, height: 32)

                        AppAsyncImage(url: URL(string: f.avatar)) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Color(.systemGray5)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.name)
                                .font(.system(size: 15, weight: .semibold))
                            Text("\(f.films) films • Score \(f.score)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        if idx < filmmakers.count - 1 {
                            Rectangle()
                                .fill(Color.black.opacity(0.06))
                                .frame(height: 0.5)
                                .padding(.leading, 56)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
            )
        }
    }
}

// MARK: - Top MyChannels Section (ranks creators from provided videos)
private struct TopMyChannelsSection: View {
    let sourceVideos: [Video]

    private struct ChannelRank: Identifiable {
        let id = UUID()
        let name: String
        let avatar: String
        let subscribers: Int
        let totalViews: Int
    }

    private var ranks: [ChannelRank] {
        let grouped = Dictionary(grouping: sourceVideos) { $0.creator.id }
        let items = grouped.values.compactMap { vids -> ChannelRank? in
            guard let first = vids.first else { return nil }
            let total = vids.reduce(0) { $0 + $1.viewCount }
            return ChannelRank(
                name: first.creator.displayName,
                avatar: first.creator.profileImageURL ?? "https://i.pravatar.cc/200?u=\(first.creator.id)",
                subscribers: first.creator.subscriberCount,
                totalViews: total
            )
        }
        return items.sorted {
            if $0.subscribers != $1.subscribers { return $0.subscribers > $1.subscribers }
            return $0.totalViews > $1.totalViews
        }.prefix(10).map { $0 }
    }

    private func fmt(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n)/1_000) }
        return "\(n)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top MyChannels")
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 4)

            VStack(spacing: 0) {
                ForEach(Array(ranks.enumerated()), id: \.offset) { idx, c in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(AppTheme.Colors.primary.opacity(0.12))
                            Text("\(idx + 1)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        .frame(width: 32, height: 32)

                        AppAsyncImage(url: URL(string: c.avatar)) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Color(.systemGray5)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.name)
                                .font(.system(size: 15, weight: .semibold))
                            Text("\(fmt(c.subscribers)) subs • \(fmt(c.totalViews)) views")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .background(Color.white)
                    .overlay(alignment: .bottom) {
                        if idx < ranks.count - 1 {
                            Rectangle()
                                .fill(Color.black.opacity(0.06))
                                .frame(height: 0.5)
                                .padding(.leading, 56)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
            )
        }
    }
}

// MARK: - Preview
#Preview("HomeView") {
    HomeView()
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}