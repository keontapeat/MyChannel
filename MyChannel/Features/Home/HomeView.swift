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
    case artistDetail(name: String, avatar: String, videos: [Video], totalViews: Int)
    case filmmakerDetail(name: String, films: [FreeMovie])
    case channelDetail(name: String, avatar: String, subscribers: Int, totalViews: Int, videos: [Video])
    case publicProfile(User)
    case custom(String)

    var id: String {
        switch self {
        case .video(let v): return "video-\(v.id)"
        case .movie(let m): return "movie-\(m.id)"
        case .search: return "search"
        case .stories(let s): return "stories-\(s.id)"
        case .allMovies: return "allMovies"
        case .allLiveTV: return "allLiveTV"
        case .trending: return "trending"
        case .artistDetail(let name, _, _, _): return "artist-\(name)"
        case .filmmakerDetail(let name, _): return "filmmaker-\(name)"
        case .channelDetail(let name, _, _, _, _): return "channel-\(name)"
        case .publicProfile(let user): return "profile-\(user.id)"
        case .custom(let id): return id
        }
    }
}

// MARK: - HomeView
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    private let globalPlayer = GlobalVideoPlayerManager.shared
    @State private var miniActive = false

    @State private var scrollOffset: CGFloat = 0
    @State private var isRefreshing: Bool = false

    // Route-driven presentation (fixes white screen when dismissing covers)
    @State private var route: FullScreenRoute? = nil
    
    // Quick profile menu
    @State private var showingQuickProfile = false
    @State private var showingSettings = false
    @State private var showingSwitchProfile = false
    
    // 🔥 Thermonuclear Featured Manager
    @State private var showingFeaturedManager = false

    @State private var featuredContent: [Video] = []
    @State private var heroVideoIndex: Int = 0
    @State private var showingStories: Bool = true
    @State private var assetStories: [AssetStory] = []
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
    
    // Check if current user is admin/owner
    private var isAdmin: Bool {
        guard let email = appState.currentUser?.email else { return false }
        return email.lowercased() == "keontapeat@mychannel.live" || 
               email.lowercased() == "keontapeat@gmail.com"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        Color.clear.frame(height: 100)

                        if showingStories && (!assetStories.isEmpty || appState.isAuthenticated) {
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
                            showLiveHeroPreviewInPreviews: true,
                            onPlayVideo: { video in
                                route = .video(video)
                            },
                            onAddToList: toggleWatchLater
                        )
                        .padding(.bottom, 40)

                        // 🔥 AI-POWERED RECOMMENDATIONS (NEW!)
                        AIRecommendationsSection { video in
                            route = .video(video)
                        }
                        .padding(.bottom, 24)
                        
                        MinimalContentSections(
                            onPlayVideo: { video in route = .video(video) },
                            onSelectMovie: { movie in route = .movie(movie) },
                            onSeeAllFreeMovies: { route = .allMovies },
                            onSeeAllLiveTV: { route = .allLiveTV },
                            onSeeAllTrending: { route = .trending },
                            onSeeAllMusic: { route = .custom("musicHub") },
                            onSeeAllExplore: { route = .custom("exploreHub") },
                            onOpenArtistDetail: { name, avatar, vids, total in
                                route = .artistDetail(name: name, avatar: avatar, videos: vids.isEmpty ? Array(Video.sampleVideos.prefix(8)) : vids, totalViews: total)
                            },
                            onOpenFilmmakerDetail: { name, films in
                                route = .filmmakerDetail(name: name, films: films)
                            },
                            onOpenChannelDetail: { name, avatar, subs, total, vids in
                                route = .channelDetail(name: name, avatar: avatar, subscribers: subs, totalViews: total, videos: vids.isEmpty ? Array(Video.sampleVideos.prefix(12)) : vids)
                            }
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
                        if appState.isAuthenticated {
                            // User is logged in → show quick profile menu
                            showingQuickProfile = true
                        } else {
                            // User is NOT logged in → show sign-in sheet
                            NotificationCenter.default.post(name: .presentSignInSheet, object: nil)
                        }
                    }
                )
                .allowsHitTesting(true)
                .zIndex(1)
                
                // Featured manager removed - use Profile > Settings > Featured Videos instead
            }
        }
        .onAppear {
            setupContent()
            loadUserStories()
        }
        .refreshable { await refreshContent() }
        .onChange(of: appState.isAuthenticated) { newValue in
            loadUserStories()
        }
        .sheet(isPresented: $presentStoryCreator) {
            UltimateStoryCreatorView { story in
                // Dismiss and refresh from authoritative source to avoid duplicates
                presentStoryCreator = false
                Task { await loadUserStories() }
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingQuickProfile) {
            if let user = appState.currentUser {
                ProfileQuickMenu(user: user, isPresented: $showingQuickProfile)
                    .environmentObject(appState)
                    .environmentObject(AuthenticationManager.shared)
                    .presentationDetents([.height(560)])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SafeProfileSettingsView()
                .environmentObject(appState)
                .environmentObject(AuthenticationManager.shared)
        }
        .sheet(isPresented: $showingSwitchProfile) {
            ProfileSwitcherView()
                .environmentObject(appState)
                .environmentObject(AuthenticationManager.shared)
        }
        .sheet(isPresented: $showingFeaturedManager) {
            ThermonuclearFeaturedManager()
                .environmentObject(appState)
        }
        // Auto-scroll removed: hero section only changes on manual swipe
        .onReceive(NotificationCenter.default.publisher(for: .storiesDidChange)) { _ in
            loadUserStories()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenFullProfile"))) { notification in
            if let user = notification.object as? User {
                route = .publicProfile(user)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenSettings"))) { _ in
            showingSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowSwitchProfile"))) { _ in
            showingSwitchProfile = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenVideoAnalytics"))) { notification in
            // 🔥 OPEN CREATOR STUDIO: Navigate to analytics for specific video
            if let video = notification.object as? Video {
                // Navigate to Creator Studio with analytics tab selected
                route = .custom("creatorStudioAnalytics_\(video.id)")
            }
        }
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
                ImprovedMoviesView()
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

            case .artistDetail(let name, let avatar, let videos, let total):
                ArtistDetailView(name: name, avatarURL: avatar, videos: videos, totalViews: total)
                    .onDisappear { self.route = nil }

            case .filmmakerDetail(let name, let films):
                FilmmakerDetailView(name: name, films: films)
                    .onDisappear { self.route = nil }

            case .channelDetail(let name, let avatar, let subs, let total, let videos):
                ChannelDetailView(name: name, avatarURL: avatar, subscribers: subs, totalViews: total, videos: videos)
                    .onDisappear { self.route = nil }
            
            case .publicProfile(let user):
                PublicProfileView(user: user)
                    .onDisappear { self.route = nil }
            
            case .custom(let id):
                // Handle Creator Studio navigation
                if id.starts(with: "creatorStudioAnalytics_") {
                    ComprehensiveCreatorStudioView()
                        .environmentObject(appState)
                        .onDisappear { self.route = nil }
                } else if id == "musicHub" {
                    MusicHubView()
                        .environmentObject(appState)
                        .onDisappear { self.route = nil }
                        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DismissMusicHub"))) { _ in
                            self.route = nil
                        }
                } else if id == "exploreHub" {
                    ExploreHubView()
                        .onDisappear { self.route = nil }
                }
            }
        }
        .onChange(of: route?.id) { newValue in
            let shouldPause = newValue != nil
            NotificationCenter.default.post(
                name: NSNotification.Name(shouldPause ? "LivePreviewsShouldPause" : "LivePreviewsShouldResume"),
                object: nil
            )
        }
    }

    // MARK: - Setup Methods
    @State private var presentStoryCreator: Bool = false

    // Helper to pin specific YouTube link first
    private var pinnedYouTubeURL: String {
        guard AppConfig.Features.enableMockData else { return "" }
        return "https://www.youtube.com/watch?v=71GJrAY54Ew&list=RD71GJrAY54Ew&start_radio=1"
    }
    private func parseYouTubeID(from urlString: String) -> String? {
        guard let comps = URLComponents(string: urlString) else { return nil }
        if let v = comps.queryItems?.first(where: { $0.name == "v" })?.value, !v.isEmpty {
            return v
        }
        if let host = comps.host, host.contains("youtu.be"), let id = comps.path.split(separator: "/").last {
            return String(id)
        }
        return nil
    }
    private func pinnedFeaturedVideo() -> Video {
        guard AppConfig.Features.enableMockData else {
            // When mock data disabled, return a harmless placeholder not shown
            return Video(
                title: "",
                description: "",
                thumbnailURL: "",
                videoURL: "",
                duration: 0,
                viewCount: 0,
                likeCount: 0,
                creator: User(username: "", displayName: "", email: ""),
                category: .other,
                isPublic: false
            )
        }
        let ytID = parseYouTubeID(from: pinnedYouTubeURL) ?? "71GJrAY54Ew"
        let friendUser = User(
            username: "scatz",
            displayName: "Scatz",
            email: "music@artist.com",
            profileImageURL: "https://i.ytimg.com/vi/\(ytID)/hqdefault.jpg",
            bannerImageURL: nil,
            bio: "Artist",
            subscriberCount: 21_300,
            videoCount: 0,
            isVerified: true,
            isCreator: true
        )
        return Video(
            id: "friend_yt_\(ytID)",
            title: "Scatz - Rebound ( Official Music Video ) Shot By @ImmortalVision",
            description: "Official music video. Shot by @ImmortalVision.",
            thumbnailURL: "https://i.ytimg.com/vi/\(ytID)/maxresdefault.jpg",
            videoURL: pinnedYouTubeURL,
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
            externalID: ytID,
            isVerified: true
        )
    }

    // Always-First Featured: Shot By Keonta intro (uses local bundle if present)
    private func introFeaturedVideo() -> Video {
        let keontaUser = User(
            username: "sbkeonta_",
            displayName: "Shot By Keonta",
            email: "keontapeat@mychannel.live",
            profileImageURL: "https://i.pravatar.cc/200?u=sbkeonta_intro",
            isVerified: true,
            isCreator: true
        )

        // Resolve local video in app bundle; fallback to a demo MP4
        let localPath = Bundle.main.path(forResource: "Shot By Keonta Intro 4k", ofType: "MP4")
        let videoURL = localPath.map { URL(fileURLWithPath: $0).absoluteString } ?? "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"

        // Simple poster
        let poster = "https://picsum.photos/seed/sbkeonta/1280/720"

        // Monetization flag so ad preview and pre-roll show
        let preRoll = Video.MonetizationSettings.AdBreak(timeStamp: 0, duration: 15, type: .preRoll)
        let monetization = Video.MonetizationSettings(isMonetized: true, adBreaks: [preRoll], sponsorSegments: [], merchandise: nil, donationEnabled: false, subscriptionTier: nil, totalRevenue: 0)

        return Video(
            title: "MyChannel Intro",
            description: "Shot By Keonta intro (demo)",
            thumbnailURL: poster,
            videoURL: videoURL,
            duration: 35,
            viewCount: 0,
            likeCount: 0,
            creator: keontaUser,
            category: .entertainment,
            tags: ["intro", "keonta", "mychannel"],
            isPublic: true,
            quality: [.quality720p, .quality1080p, .quality2160p],
            aspectRatio: .landscape,
            isLiveStream: false,
            contentSource: .userUploaded,
            externalID: nil,
            isVerified: true,
            monetization: monetization,
            isSponsored: false
        )
    }

    private func setupContent() {
        // Pull owner-managed Featured list (for possible 3rd slot)
        FeaturedStore.shared.ensureOwnerIntroFirstIfAvailable()
        let ownerFeatured = FeaturedStore.shared.toVideos()
        // In production/TestFlight, do not show mock content for authenticated users
        let seeds = SeedCatalogService.shared.seedVideos
        let samples = Video.sampleVideos
        var base: [Video] = []
        if AppConfig.Features.enableMockData {
            base = (samples + seeds).filter { $0.viewCount > 500_000 }
        } else {
            base = []
        }
        let friend: [Video] = AppConfig.Features.enableMockData ? friendHeroVideos() : []

        // Always pin Shot By Keonta intro first, then requested YouTube video
        let keonta = introFeaturedVideo()
        let pinned = pinnedFeaturedVideo()

        var seen = Set<String>()
        var ordered: [Video] = []
        // 1) ALWAYS put Keonta intro first (even in Release builds for App Store screenshots)
        if seen.insert(keonta.id).inserted { ordered.append(keonta) }
        // 2) Then the pinned YouTube request (only in debug/mock mode)
        if AppConfig.Features.enableMockData {
            if seen.insert(pinned.id).inserted { ordered.append(pinned) }
        }
        // 3) Fill remaining slots preferring friend hero, then owner featured, then base
        let candidates: [Video] = (friend + ownerFeatured + base)
        for v in candidates {
            if ordered.count >= 3 { break }
            if seen.insert(v.id).inserted { ordered.append(v) }
        }

        // Ensure we have at least the Keonta intro, even in Release builds
        if ordered.isEmpty {
            ordered = [keonta]
            if AppConfig.Features.enableMockData {
                ordered.append(contentsOf: [pinned] + Array(samples.prefix(2)))
            }
        }

        // Cap to exactly 3 items to show only three page dots in the hero
        featuredContent = Array(ordered.prefix(3))
        heroVideoIndex = 0

        // Ensure we always have at least two items for the Featured carousel.
        if featuredContent.count < 2 {
            var mapped: [Video] = []
            // Prefer sample movie posters as fallback (stable thumbnails)
            for m in FreeMovie.sampleMovies.prefix(4) {
                let v = MoviePlaybackResolver.video(from: m, creator: User.defaultUser)
                mapped.append(v)
            }
            // Merge uniques until we have 2
            var seen = Set(featuredContent.map { $0.id })
            for v in mapped where featuredContent.count < 2 {
                if seen.insert(v.id).inserted { featuredContent.append(v) }
            }
            heroVideoIndex = 0
        }
    }

    private func refreshContent() async {
        isRefreshing = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        setupContent()
        loadUserStories()
        isRefreshing = false
    }
    
    private func loadUserStories() {
        // Clear existing stories first
        assetStories = []
        
        // Don't show stories for unauthenticated users - keep it clean like YouTube
        guard appState.isAuthenticated, let currentUser = appState.currentUser else {
            return
        }
        
        Task { @MainActor in
            // Prefer backend stories if available
            if let backendStories = try? await StoryAPIService.shared.fetchFollowingStories(limit: 24), !backendStories.isEmpty {
                let mapped = backendStories.map { s -> AssetStory in
                    let media: AssetMedia = (s.mediaType == .video) ? .video(s.mediaURL) : .image(s.mediaURL)
                    let name = s.creator?.username ?? s.creatorId
                    return AssetStory(media: media, username: name, authorImageName: s.creator?.profileImageURL ?? "")
                }
                self.assetStories = normalizeStories(mapped, excludingSelfUsername: currentUser.username)
            } else {
                // Fallback to local cache
                if let mine = try? await DatabaseService.shared.fetchStoriesByCreator(creatorId: currentUser.id), !mine.isEmpty {
                    let mapped = mine.map { s -> AssetStory in
                        let media: AssetMedia = (s.mediaType == .video) ? .video(s.mediaURL) : .image(s.mediaURL)
                        return AssetStory(media: media, username: currentUser.username, authorImageName: currentUser.profileImageURL ?? "")
                    }
                    self.assetStories.insert(contentsOf: normalizeStories(mapped, excludingSelfUsername: currentUser.username), at: 0)
                }
                if !appState.subscriptions.isEmpty {
                    let followed = Array(appState.subscriptions)
                    if let stories = try? await DatabaseService.shared.fetchActiveStoriesForCreators(followed), !stories.isEmpty {
                        var mapped: [AssetStory] = []
                        for s in stories {
                            let media: AssetMedia = (s.mediaType == .video) ? .video(s.mediaURL) : .image(s.mediaURL)
                            let user = try? await DatabaseService.shared.fetchUser(id: s.creatorId)
                            let name = user?.username ?? s.creatorId
                            mapped.append(AssetStory(media: media, username: name, authorImageName: user?.profileImageURL ?? ""))
                        }
                        self.assetStories.append(contentsOf: normalizeStories(mapped, excludingSelfUsername: currentUser.username))
                    }
                }
                self.assetStories = normalizeStories(self.assetStories, excludingSelfUsername: currentUser.username)
            }
        }
    }

    private func normalizeStories(_ input: [AssetStory], excludingSelfUsername: String?) -> [AssetStory] {
        var seen = Set<String>()
        var out: [AssetStory] = []
        for s in input {
            let key = s.username.lowercased()
            if let me = excludingSelfUsername, key == me.lowercased() { continue }
            if seen.insert(key).inserted { out.append(s) }
        }
        return out
    }
    
    private func loadStoriesFromFollowedUsers() {
        // This would be replaced with a real API call
        // For now, we'll simulate loading stories only if user has subscriptions
        
        // Example: Only show stories from users the current user actually follows
        let followedUserIds = appState.subscriptions
        
        // In a real implementation, this would query the backend for active stories
        // from the followed users within the last 24 hours
        
        // For demonstration, we'll leave this empty to show the authentic experience
        // where new users who don't follow anyone see no stories
        
        // Real implementation would look like:
        // Task {
        //     let stories = try await APIService.shared.getStoriesFromFollowedUsers(followedUserIds)
        //     await MainActor.run {
        //         self.assetStories = stories.map { story in
        //             AssetStory(
        //                 media: story.mediaType == .video ? .video(story.mediaURL) : .image(story.mediaURL),
        //                 username: story.creator.username,
        //                 authorImageName: story.creator.profileImageURL ?? ""
        //             )
        //         }
        //     }
        // }
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
    
    // MARK: - ULTRA-THERMONUCLEAR FAB 🔥💥😤
    private var thermonuclearFAB: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button {
                    HapticManager.shared.impact(style: .heavy)
                    showingFeaturedManager = true
                } label: {
                    UltraThermonuclearFABContent()
                }
                .padding(.trailing, 20)
                .padding(.bottom, 100) // Above tab bar
            }
        }
        .allowsHitTesting(true)
        .zIndex(999)
    }
}

// MARK: - Minimal Navigation Header (static, slightly larger)
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
            .background(Color.white)
            .animation(.easeInOut(duration: 0.25), value: showBackground)
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
                                    AppAsyncImage(url: URL(string: "https://picsum.photos/200/200?random=\(abs(story.id.hashValue))")) { image in
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

// MARK: - Minimal Hero Section (now a pager)
struct MinimalHeroSection: View {
    let featuredContent: [Video]
    @Binding var selectedIndex: Int
    let showLiveHeroPreviewInPreviews: Bool
    let onPlayVideo: (Video) -> Void
    let onAddToList: (Video) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var appState: AppState
    @State private var showingFeaturedManager = false
    
    private var isCompact: Bool { horizontalSizeClass == .compact }
    
    private var isAdmin: Bool {
        guard let email = appState.currentUser?.email else { return false }
        return email.lowercased() == "keontapeat@mychannel.live" || 
               email.lowercased() == "keontapeat@gmail.com"
    }

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
                    
                    Spacer()
                    
                    // 🔥 QUICK EDIT BUTTON (Admin Only)
                    if isAdmin {
                        Button {
                            HapticManager.shared.impact(style: .light)
                            showingFeaturedManager = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Edit")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(AppTheme.Colors.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.primary.opacity(0.1))
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .sheet(isPresented: $showingFeaturedManager) {
                    ThermonuclearFeaturedManager()
                        .environmentObject(appState)
                }

                TabView(selection: $selectedIndex) {
                    ForEach(Array(featuredContent.enumerated()), id: \.offset) { index, vid in
                        FeaturedHeroCard(
                            video: vid,
                            isCompact: isCompact,
                            showLivePreview: (index == selectedIndex) || (index == 0),
                            allowLiveInPreview: showLiveHeroPreviewInPreviews,
                            onPlay: { onPlayVideo(vid) },
                            onAddToList: { onAddToList(vid) }
                        )
                        .padding(.horizontal, 20)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}

private struct FeaturedHeroCard: View {
    let video: Video
    let isCompact: Bool
    let showLivePreview: Bool
    let allowLiveInPreview: Bool
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

                if showLivePreview && (!isPreview || allowLiveInPreview) {
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
                        Text(video.category.displayName)
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
            // Common JPG candidates
            add("https://i.ytimg.com/vi/\(yid)/maxresdefault.jpg")
            add("https://i.ytimg.com/vi/\(yid)/sddefault.jpg")
            add("https://i.ytimg.com/vi/\(yid)/hqdefault.jpg")
            add("https://img.youtube.com/vi/\(yid)/maxresdefault.jpg")
            add("https://img.youtube.com/vi/\(yid)/sddefault.jpg")
            add("https://img.youtube.com/vi/\(yid)/hqdefault.jpg")
            // Frame indices
            add("https://img.youtube.com/vi/\(yid)/0.jpg")
            add("https://img.youtube.com/vi/\(yid)/1.jpg")
            add("https://img.youtube.com/vi/\(yid)/2.jpg")
            add("https://img.youtube.com/vi/\(yid)/3.jpg")
            // WEBP variants
            add("https://i.ytimg.com/vi_webp/\(yid)/maxresdefault.webp")
            add("https://i.ytimg.com/vi_webp/\(yid)/sddefault.webp")
            add("https://i.ytimg.com/vi_webp/\(yid)/hqdefault.webp")
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
    let onSeeAllMusic: () -> Void
    let onSeeAllExplore: () -> Void
    let onOpenArtistDetail: (String, String, [Video], Int) -> Void
    let onOpenFilmmakerDetail: (String, [FreeMovie]) -> Void
    let onOpenChannelDetail: (String, String, Int, Int, [Video]) -> Void

    @EnvironmentObject private var appState: AppState
    @State private var blockbusterMovies: [FreeMovie] = []
    @State private var loadingBlockbusters: Bool = false
    @State private var friendChannelVideos: [Video] = []
    @State private var liveChannelsAPI: [LiveTVChannel] = []
    @State private var showLocalArtistsOnly: Bool = false

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

    // Custom: Shot By Keonta intro video (local bundle) so you can test full controls
    private func keontaIntroVideo() -> Video {
        let keontaUser = User(
            username: "sbkeonta_",
            displayName: "Shot By Keonta",
            email: "keontapeat@mychannel.live",
            profileImageURL: "https://i.pravatar.cc/200?u=sbkeonta_intro",
            isVerified: true,
            isCreator: true
        )

        // Resolve local video in app bundle; fallback to a demo MP4
        let localPath = Bundle.main.path(forResource: "Shot By Keonta Intro 4k", ofType: "MP4")
        let videoURL = localPath.map { URL(fileURLWithPath: $0).absoluteString } ?? "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"

        // Simple poster
        let poster = "https://picsum.photos/seed/sbkeonta/1280/720"

        // Monetization flag so ad preview and pre-roll show
        let preRoll = Video.MonetizationSettings.AdBreak(timeStamp: 0, duration: 15, type: .preRoll)
        let monetization = Video.MonetizationSettings(isMonetized: true, adBreaks: [preRoll], sponsorSegments: [], merchandise: nil, donationEnabled: false, subscriptionTier: nil, totalRevenue: 0)

        return Video(
            title: "MyChannel Intro",
            description: "Shot By Keonta intro (demo)",
            thumbnailURL: poster,
            videoURL: videoURL,
            duration: 35,
            viewCount: 0,
            likeCount: 0,
            creator: keontaUser,
            category: .entertainment,
            tags: ["intro", "keonta", "mychannel"],
            isPublic: true,
            quality: [.quality720p, .quality1080p, .quality2160p],
            aspectRatio: .landscape,
            isLiveStream: false,
            contentSource: .userUploaded,
            externalID: nil,
            isVerified: true,
            monetization: monetization,
            isSponsored: false
        )
    }

    private func extraTrendingVideos() -> [Video] {
        var videos: [Video] = []
        
        // Baby Ju - Free Ty (Featured as #1 trending)
        let babyJuCreator = User(
            username: "babyju",
            displayName: "Baby Ju",
            email: "noreply@yt.com",
            profileImageURL: "https://i.ytimg.com/vi/JSXmfgZzHqQ/hqdefault.jpg",
            bannerImageURL: nil,
            bio: "Artist",
            subscriberCount: 2040,
            videoCount: 0,
            isVerified: true,
            isCreator: true,
            location: "CALIFORNIA"
        )
        let babyJuVideo = Video(
            id: "yt_JSXmfgZzHqQ",
            title: "Baby Ju - Free Ty (Official Video) #ShotByBigHornet",
            description: "Official Music Video to \"Free Ty\" by Baby Ju off the \"Rock Em Baba\" tape. Shot by @BigHornet. Stream \"Free Ty\" on the \"Rock Em Baba\" EP",
            thumbnailURL: "https://i.ytimg.com/vi/JSXmfgZzHqQ/hqdefault.jpg",
            videoURL: "https://www.youtube.com/watch?v=JSXmfgZzHqQ",
            duration: 184,
            viewCount: 10_000_000,
            likeCount: 572,
            commentCount: 39,
            createdAt: Date(),
            creator: babyJuCreator,
            category: .music,
            tags: ["music", "baby ju", "free ty", "rock em baba", "shotbybighornet"],
            isPublic: true,
            quality: [.quality720p],
            aspectRatio: .landscape,
            isLiveStream: false,
            contentSource: .youtube,
            externalID: "JSXmfgZzHqQ",
            isVerified: true
        )
        videos.append(babyJuVideo)
        
        // KTrip - Whatever (Featured as #2 trending)
        let kTripCreator = User(
            username: "ktrip",
            displayName: "KTrip",
            email: "noreply@yt.com",
            profileImageURL: "https://i.ytimg.com/vi/xfdydb_3Ra0/hqdefault.jpg",
            bannerImageURL: nil,
            bio: "Artist",
            subscriberCount: 5000,
            videoCount: 0,
            isVerified: true,
            isCreator: true
        )
        let kTripVideo = Video(
            id: "yt_xfdydb_3Ra0",
            title: "KTrip - \"Whatever\" (Block Logic Exclusive - Official Music Video)",
            description: "Official Music Video by KTrip",
            thumbnailURL: "https://i.ytimg.com/vi/xfdydb_3Ra0/hqdefault.jpg",
            videoURL: "https://www.youtube.com/watch?v=xfdydb_3Ra0",
            duration: Double.random(in: 90...300),
            viewCount: 8_000_000,
            likeCount: Int.random(in: 100...50_000),
            commentCount: Int.random(in: 10...10_000),
            createdAt: Date(),
            creator: kTripCreator,
            category: .music,
            tags: ["music", "ktrip", "whatever", "block logic"],
            isPublic: true,
            quality: [.quality720p],
            aspectRatio: .landscape,
            isLiveStream: false,
            contentSource: .youtube,
            externalID: "xfdydb_3Ra0",
            isVerified: true
        )
        videos.append(kTripVideo)
        
        // Other videos
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
            ("96Zeze6gdEI", "YouTube Video 96Zeze6gdEI"),
            ("l1gQVUGdMyw", "YouTube Video l1gQVUGdMyw"),
            ("71GJrAY54Ew", "Scatz - Rebound (Official Music Video)")
        ]
        let otherVideos = entries.map { e in
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
        videos.append(contentsOf: otherVideos)
        
        return videos
    }

    // Curated Flint artists showcase to seed All/Trending so the app looks full and professional
    private func flintShowcaseVideos() -> [Video] {
        struct Entry { let artist: String; let slug: String; let title: String }
        let items: [Entry] = [
            .init(artist: "YN Jay", slug: "yn_jay", title: "YN Jay – Official Video"),
            .init(artist: "RMC Mike", slug: "rmc_mike", title: "RMC Mike – Official Video"),
            .init(artist: "Louie Ray", slug: "louie_ray", title: "Louie Ray – Official Video"),
            .init(artist: "Babyface E", slug: "babyface_e", title: "Babyface E – Official Video"),
            .init(artist: "YSR Gramz", slug: "ysr_gramz", title: "YSR Gramz – Official Video"),
            .init(artist: "Scatz", slug: "scatz_flint", title: "Scatz – Official Music Video"),
            .init(artist: "Baby Ghost", slug: "baby_ghost", title: "Baby Ghost – Official Video")
        ]
        return items.map { e in
            let creator = User(
                username: e.artist.replacingOccurrences(of: " ", with: "_").lowercased(),
                displayName: e.artist,
                email: "artist@music.com",
                profileImageURL: "https://i.pravatar.cc/200?u=\(e.slug)",
                isVerified: true,
                isCreator: true
            )
            return Video(
                title: e.title,
                description: "\(e.artist) • Official Video",
                thumbnailURL: "https://picsum.photos/seed/\(e.slug)/1280/720",
                videoURL: "https://example.com/video/\(e.slug)",
                duration: Double.random(in: 120.0...240.0),
                viewCount: Int.random(in: 100_000...5_000_000),
                likeCount: Int.random(in: 2_000...120_000),
                commentCount: Int.random(in: 200...20_000),
                createdAt: Date(),
                creator: creator,
                category: .music,
                tags: ["flint","music","rap"],
                isPublic: true,
                quality: [.quality720p],
                aspectRatio: .landscape,
                isLiveStream: false,
                contentSource: .userUploaded,
                externalID: nil,
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

    @ObservedObject private var globalPlayer = GlobalVideoPlayerManager.shared

    var body: some View {
        VStack(spacing: 40) {
            ForYouSection(onPlayVideo: onPlayVideo, onSeeAllExplore: onSeeAllExplore)

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
                TopTenCarousel(
                    videos: {
                        let base = friendChannelVideos.isEmpty ? [] : friendChannelVideos
                        // Featured videos first: Baby Ju #1, KTrip #2
                        let pinnedIDs = ["JSXmfgZzHqQ", "xfdydb_3Ra0", "96Zeze6gdEI", "l1gQVUGdMyw", "71GJrAY54Ew"]
                        let pinnedVideos: [Video] = pinnedIDs.compactMap { id in
                            extraTrendingVideos().first(where: { $0.externalID == id }) ??
                            detroitFlintArtistsTrending().first(where: { $0.externalID == id })
                        }
                        let merged = pinnedVideos + [makeFriendTrendingVideo()] + extraTrendingVideos() + flintShowcaseVideos() + base
                        var seen = Set<String>()
                        let dedup = merged.filter { v in
                            if seen.contains(v.id) { return false }
                            seen.insert(v.id)
                            return true
                        }
                        return dedup
                    }(),
                    preserveOrder: true,
                    onPlay: { v in onPlayVideo(v) }
                )
                .padding(.top, 4)
            }

            // MUSIC – artist carousel, placed above Categories
                        MinimalMusicSection(
                            onOpenArtistDetail: onOpenArtistDetail,
                            appState: _appState,
                            onSeeAll: { onSeeAllMusic() }
                        )

            MinimalCategoriesSection(
                onPlayVideo: onPlayVideo,
                codVideos: gamingCOD(),
                musicVideos: detroitFlintArtistsTrending(),
                allVideos: {
                    var vids = flintShowcaseVideos() + detroitFlintArtistsTrending() + gamingCOD() + Video.sampleVideos + SeedCatalogService.shared.seedVideos
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
                        // Our Go Live channel via Cloud Run proxy
                        let myChannelLive = LiveTVChannel(
                            id: "mychannel-live",
                            name: "MyChannel Live",
                            logoURL: "https://picsum.photos/seed/mychannel-live/320/180",
                            streamURL: "\(AppConfig.API.cloudRunBaseURL)/live/playlist",
                            category: .entertainment,
                            description: "Go Live playback",
                            isLive: true,
                            viewerCount: 0,
                            quality: "HD",
                            language: "English",
                            country: "US",
                            epgURL: nil,
                            previewFallbackURL: nil
                        )

                        NavigationLink(destination: LiveTVPlayerView(channel: myChannelLive)) {
                            MinimalChannelCard(
                                channel: myChannelLive,
                                autoPreview: true,
                                previewOverrideStreamURL: nil,
                                previewOverridePosterURL: nil,
                                allowPlaybackInPreviews: false
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        let source = liveChannelsAPI.isEmpty ? LiveTVChannel.sampleChannels : liveChannelsAPI
                        let channels = Array(source.prefix(8))
                        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
                        let previewStreams = [
                            "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
                            "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8",
                            "https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8"
                        ]
                        ForEach(Array(channels.enumerated()), id: \.element.id) { index, channel in
                            NavigationLink(destination: LiveTVPlayerView(channel: channel)) {
                                MinimalChannelCard(
                                    channel: channel,
                                    autoPreview: index < 3,
                                    previewOverrideStreamURL: (isPreview && index < 3) ? previewStreams[index] : nil,
                                    previewOverridePosterURL: nil,
                                    allowPlaybackInPreviews: isPreview && index < 3
                                )
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
                            MinimalMovieCard(movie: movie, action: { 
                                onSelectMovie(movie)
                                // Track movie view for enhanced service
                                Task {
                                    await EnhancedMoviesService.shared.addToRecentlyWatched(movie)
                                }
                            })
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            TopArtistsSection(
                sourceVideos: detroitFlintArtistsTrending() + [makeFriendTrendingVideo()] + Video.sampleVideos,
                onSelect: { name, avatar, vids, total in
                    onOpenArtistDetail(name, avatar, vids, total)
                }
            )
            .padding(.horizontal, 20)
            TopIndieFilmmakersSection(
                onSelect: { name, films in
                    onOpenFilmmakerDetail(name, films)
                }
            )
            .padding(.horizontal, 20)

            TopMyChannelsSection(
                sourceVideos: detroitFlintArtistsTrending() + gamingCOD() + Video.sampleVideos,
                onSelect: { name, avatar, subs, total, vids in
                    onOpenChannelDetail(name, avatar, subs, total, vids)
                }
            )
            .padding(.horizontal, 20)
        }
        // When mini player is showing, disable heavy animations in the feed to avoid jank
        .transaction { tx in
            if globalPlayer.shouldShowMiniPlayer { tx.disablesAnimations = true }
        }
        .onReceive(globalPlayer.$shouldShowMiniPlayer.removeDuplicates()) { isMini in
            NotificationCenter.default.post(name: NSNotification.Name(isMini ? "LivePreviewsShouldPause" : "LivePreviewsShouldResume"), object: nil)
        }
        .task {
            // ⚡ PERFORMANCE FIX: Load all in parallel instead of sequentially
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await loadBlockbusters() }
                group.addTask { await loadFriendChannelVideos() }
                group.addTask { await loadLiveChannelsAPI() }
            }
        }
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

    private func loadLiveChannelsAPI() async {
        guard liveChannelsAPI.isEmpty else { return }
        let fetched = await IPTVOrgService.shared.fetchTopChannels(limit: 24, countries: ["US","GB","CA"], languages: ["eng"], categories: nil)
        await MainActor.run {
            self.liveChannelsAPI = fetched
        }
    }
}

// MARK: - Music Section (Artists Carousel)
private struct MinimalMusicSection: View {
    var onOpenArtistDetail: (String, String, [Video], Int) -> Void
    @EnvironmentObject var appState: AppState
    var onSeeAll: (() -> Void)? = nil

    private var allArtists: [(name: String, avatar: String, views: Int, city: String?)] {
        // 🎵 LOCAL ARTISTS WITH ASSETS - Using local images for fast loading!
        let localArtists: [(String,String,Int,String?)] = [
            ("Bae Shanicee", "BaeShaniceeAvatar", 200_000, nil),
            ("Báby Ju", "BabyJuAvatar", 210_000, nil),
            ("HTG Nook", "HTGNookAvatar", 215_600, "Flint, MI"),
            ("Kleanup Man", "KleanupManAvatar", 200_800, "Detroit, MI"),
            ("Scatz Ripky", "ScatzAvatar", 346_300, "Flint, MI"),
            ("Faneto Rich", "FanetoRichAvatar", 250_000, "Buc Town"),
            ("Cashpaid Jay", "CashpaidJayAvatar", 225_000, nil),
            ("Benji Gram", "BenjiGramAvatar", 220_000, nil),
            ("Mbk Cari", "MbkCariAvatar", 195_000, nil),
            ("Luh Monti", "LuhMontiAvatar", 230_000, nil),
            ("Mac Quall", "MacQuallAvatar", 205_000, nil),
            ("Jeff Skigh", "JeffSkighAvatar", 200_000, nil),
            ("Six Ward Von", "SixWardVonAvatar", 210_000, nil),
            ("Barth Baby", "BarthBabyAvatar", 215_000, nil),
            ("Baby Ghost", "BabyGhostAvatar", 220_000, nil)
        ]
        
        let curated: [(String,String,Int,String?)] = OwnerProfile.instagramFriends.map { ($0.name, $0.avatar, Int.random(in: 50_000...350_000), nil) }
        
        // Improved deduplication: normalize names (remove @, spaces, punctuation) and check avatar assets
        var seen = Set<String>()
        var seenAvatars = Set<String>()
        var ordered: [(String,String,Int,String?)] = []
        
        // Helper to normalize artist name for comparison
        func normalize(_ name: String) -> String {
            return name.lowercased()
                .replacingOccurrences(of: "@", with: "")
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: " ", with: "")
        }
        
        // Helper to extract asset name from avatar string
        func extractAssetName(_ avatar: String) -> String? {
            if avatar.hasPrefix("asset://") {
                let components = avatar.components(separatedBy: "?")
                if components.count > 0 {
                    return components[0].replacingOccurrences(of: "asset://", with: "")
                }
            } else if !avatar.hasPrefix("http") {
                // Local asset name (not a URL)
                return avatar
            }
            return nil
        }
        
        // Process local artists first (priority)
        for item in localArtists {
            let normalizedName = normalize(item.0)
            let assetName = extractAssetName(item.1)
            
            // Skip if we've already seen this normalized name or the same asset
            let shouldSkip = seen.contains(normalizedName) || (assetName != nil && seenAvatars.contains(assetName!))
            if !shouldSkip {
                seen.insert(normalizedName)
                if let asset = assetName {
                    seenAvatars.insert(asset)
                }
                ordered.append(item)
            }
        }
        
        // Then add curated artists (skip if duplicate)
        for item in curated {
            let normalizedName = normalize(item.0)
            let assetName = extractAssetName(item.1)
            
            // Skip if duplicate name or asset
            let shouldSkip = seen.contains(normalizedName) || (assetName != nil && seenAvatars.contains(assetName!))
            if !shouldSkip {
                seen.insert(normalizedName)
                if let asset = assetName {
                    seenAvatars.insert(asset)
                }
                ordered.append(item)
            }
        }
        
        return ordered
    }

    private var artists: [(name: String, avatar: String, views: Int, city: String?)] {
        // Filter out artists whose avatar assets don't exist (no empty cards)
        allArtists.filter { artist in
            // If it's a URL, keep it
            if artist.avatar.hasPrefix("http") { return true }
            // If it's a local asset, check if it exists
            return UIImage(named: artist.avatar) != nil
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Music")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
                Spacer()
                if let onSeeAll {
                    Button("See all", action: onSeeAll)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(Array(artists.enumerated()), id: \.offset) { _, a in
                        Button {
                            onOpenArtistDetail(a.name, a.avatar, [], a.views)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                // Check if it's a local asset or URL
                                if a.avatar.hasPrefix("http") {
                                    AppAsyncImage(url: URL(string: a.avatar)) { img in
                                        img
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 180)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color(.systemGray6))
                                            .frame(width: 120, height: 180)
                                    }
                                } else {
                                    // Local asset image with fallback
                                    Group {
                                        if let uiImage = UIImage(named: a.avatar) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 120, height: 180)
                                                .offset(y: a.avatar == "MbkCariAvatar" ? 15 : 0) // Shift Mbk Cari image down to show face
                                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        } else {
                                            // Fallback placeholder if asset not found
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color(.systemGray5), Color(.systemGray6)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 120, height: 180)
                                                .overlay(
                                                    Image(systemName: "person.circle.fill")
                                                        .font(.system(size: 40))
                                                        .foregroundColor(.secondary)
                                                )
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(a.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .frame(width: 120, alignment: .leading)
                                    Text("\(format(a.views)) total views")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .frame(width: 120, alignment: .leading)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func format(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n)/1_000) }
        return "\(n)"
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
                .onAppear {
                    // ⚡ PERFORMANCE: Prefetch thumbnail
                    if let url = video.posterCandidates.first {
                        ImagePrefetcher.shared.prefetch(url: url)
                    }
                }

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
        .drawingGroup() // ⚡ PERFORMANCE: Flatten view hierarchy for smoother scrolling
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
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Minimal Channel Card (stable)
struct MinimalChannelCard: View {
    let channel: LiveTVChannel
    var autoPreview: Bool = false
    var previewOverrideStreamURL: String? = nil
    var previewOverridePosterURL: String? = nil
    var allowPlaybackInPreviews: Bool = false
    @State private var showPreview: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if showPreview {
                    LiveChannelThumbnailView(
                        streamURL: previewOverrideStreamURL ?? channel.streamURL,
                        posterURL: previewOverridePosterURL ?? channel.logoURL,
                        fallbackStreamURL: channel.previewFallbackURL,
                        allowPlaybackInPreviews: allowPlaybackInPreviews
                    )
                        .frame(width: 160, height: 90)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    AppAsyncImage(url: URL(string: previewOverridePosterURL ?? channel.logoURL)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: { Color(.systemGray6) }
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
                showPreview = autoPreview
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
                        MinimalVideoCard(
                            video: video,
                            action: { onPlayVideo(video) }
                        )
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
    var onSelect: (String, String, [Video], Int) -> Void = { _,_,_,_  in }

    private var rankings: [ArtistRank] {
        let grouped = Dictionary(grouping: sourceVideos) { $0.creator.displayName }
        var ranks = grouped.map { (name, vids) -> ArtistRank in
            let views = vids.reduce(0) { $0 + $1.viewCount }
            return ArtistRank(
                name: name,
                views: views,
                avatar: vids.first?.creator.profileImageURL ?? "https://i.pravatar.cc/200?u=\(name)"
            )
        }
        // Promote IG friends if provided (dedup by name) and pin their order at the front
        let dynamicFriends = OwnerFriendsStore.shared.friends
        let pinnedOrder = (OwnerProfile.instagramFriends + dynamicFriends).map { $0.name }
        for f in (OwnerProfile.instagramFriends + dynamicFriends) {
            if let idx = ranks.firstIndex(where: { $0.name == f.name }) {
                // Update avatar if we already have this artist from videos
                let existing = ranks[idx]
                ranks[idx] = ArtistRank(name: existing.name, views: existing.views, avatar: f.avatar)
            } else {
                ranks.append(ArtistRank(name: f.name, views: 0, avatar: f.avatar))
            }
        }

        var sorted = ranks.sorted { $0.views > $1.views }

        // Pin in the specified order so the first friend becomes #1
        if !pinnedOrder.isEmpty {
            let pinnedSet = Set(pinnedOrder)
            let pinnedItems = pinnedOrder.compactMap { name in
                sorted.first(where: { $0.name == name })
            }
            let nonPinned = sorted.filter { !pinnedSet.contains($0.name) }
            sorted = pinnedItems + nonPinned
        }

        return Array(sorted.prefix(10))
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
                .foregroundColor(AppTheme.Colors.primary)
                .padding(.top, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(Array(rankings.enumerated()), id: \.offset) { idx, a in
                        Button {
                            let vids = sourceVideos.filter { $0.creator.displayName == a.name }
                            onSelect(a.name, a.avatar, vids, a.views)
                        } label: {
                            VStack(alignment: .center, spacing: 8) {
                                ZStack(alignment: .topLeading) {
                                    ZStack {
                                        Circle()
                                            .stroke(AppTheme.Colors.primary, lineWidth: 3)
                                            .frame(width: 64, height: 64)

                                        AppAsyncImage(url: URL(string: a.avatar)) { img in
                                            img.resizable().scaledToFill()
                                        } placeholder: { Color.white }
                                        .frame(width: 58, height: 58)
                                        .clipShape(Circle())
                                    }

                                    Text("#\(idx + 1)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(AppTheme.Colors.primary))
                                        .padding(.top, 2)
                                        .padding(.leading, 2)
                                }

                                VStack(alignment: .center, spacing: 2) {
                                    Text(a.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .frame(width: 110)
                                    Text("\(format(a.views)) total views")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .frame(width: 110)
                                }
                            }
                            .frame(width: 120)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .background(AppTheme.Colors.background)
            }
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
        // Tee Cee as #1 top filmmaker
        // Check multiple possible asset names (case-sensitive)
        let possibleNames = ["TeeCeeAvatar", "TeeCee", "tee_cee", "TeeC eeAvatar", "TeeCee_Avatar"]
        var teeCeeAvatar = "https://i.pravatar.cc/200?u=tee_cee" // Default
        var foundAssetName: String? = nil
        
        for assetName in possibleNames {
            if UIImage(named: assetName) != nil {
                foundAssetName = assetName
                teeCeeAvatar = "asset://\(assetName)" // 🔥 FIX: Use asset:// prefix like Merch HD
                print("✅ Found Tee Cee asset: \(assetName)")
                break
            }
        }
        
        if foundAssetName == nil {
            print("⚠️ Tee Cee assets not found. Checked: \(possibleNames.joined(separator: ", "))")
            print("💡 Make sure the image is added to Assets.xcassets with exact name 'TeeCeeAvatar'")
            print("💡 Asset names are case-sensitive - check spelling exactly")
        }
        
        let teeCee = Filmmaker(
            name: "Tee Cee",
            films: 24,
            score: 100, // Highest score for #1 position
            avatar: teeCeeAvatar
        )
        
        // Merch HD as #2 filmmaker
        let merchHDAssetName = "MerchHDAvatar"
        let merchHDAvatar: String
        if UIImage(named: merchHDAssetName) != nil {
            merchHDAvatar = "asset://\(merchHDAssetName)"
            print("✅ Found Merch HD asset: \(merchHDAssetName)")
        } else {
            merchHDAvatar = "https://i.pravatar.cc/200?u=merch_hd"
            print("⚠️ Merch HD asset '\(merchHDAssetName)' not found - using placeholder")
        }
        
        let merchHD = Filmmaker(
            name: "Merch HD",
            films: 15,
            score: 99, // Second highest score for #2 position
            avatar: merchHDAvatar
        )
        
        let names = [
            "A. Rivers", "N. Carter", "M. Sloan", "J. Patel", "R. Alvarez",
            "S. Kim", "D. Morgan", "K. O'Neal", "B. Laurent", "T. Ito"
        ]
        let items = names.enumerated().map { idx, n in
            Filmmaker(
                name: n,
                films: Int.random(in: 2...12),
                score: Int.random(in: 60...98), // Max 98 to stay below MerchHD
                avatar: "https://i.pravatar.cc/200?u=indie_\(idx)"
            )
        }
        
        var all = [teeCee, merchHD] + items
        return all.sorted { $0.score > $1.score }
    }

    var onSelect: (String, [FreeMovie]) -> Void = { _,_ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Indie Filmmakers")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppTheme.Colors.primary)
                .padding(.top, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(Array(filmmakers.enumerated()), id: \.offset) { idx, f in
                        Button {
                            onSelect(f.name, Array(FreeMovie.sampleMovies.shuffled().prefix(Int.random(in: 6...10))))
                        } label: {
                            VStack(alignment: .center, spacing: 8) {
                                ZStack(alignment: .topLeading) {
                                    ZStack {
                                        Circle()
                                            .stroke(AppTheme.Colors.primary, lineWidth: 3)
                                            .frame(width: 64, height: 64)

                                        // 🔥 FIX: Check for asset images first (for Tee Cee and Merch HD)
                                        if f.avatar.hasPrefix("asset://") {
                                            let assetName = String(f.avatar.dropFirst(8)) // Remove "asset://" prefix
                                            if let assetImage = UIImage(named: assetName) {
                                                Image(uiImage: assetImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 58, height: 58)
                                                    .clipShape(Circle())
                                            } else {
                                                // Fallback if asset not found - try AppAsyncImage
                                                if let url = URL(string: f.avatar) {
                                                    AppAsyncImage(url: url) { img in
                                                        img.resizable().scaledToFill()
                                                    } placeholder: { 
                                                        Color.white
                                                    }
                                                    .frame(width: 58, height: 58)
                                                    .clipShape(Circle())
                                                } else {
                                                    Color.white
                                                        .frame(width: 58, height: 58)
                                                        .clipShape(Circle())
                                                }
                                            }
                                        } else if let url = URL(string: f.avatar) {
                                            AppAsyncImage(url: url) { img in
                                                img.resizable().scaledToFill()
                                            } placeholder: { Color.white }
                                            .frame(width: 58, height: 58)
                                            .clipShape(Circle())
                                        } else {
                                            Color.white
                                                .frame(width: 58, height: 58)
                                                .clipShape(Circle())
                                        }
                                    }

                                    Text("#\(idx + 1)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(AppTheme.Colors.primary))
                                        .padding(.top, 2)
                                        .padding(.leading, 2)
                                }

                                VStack(alignment: .center, spacing: 2) {
                                    Text(f.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .frame(width: 110)
                                    Text("\(f.films) films • Score \(f.score)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .frame(width: 110)
                                }
                            }
                            .frame(width: 120)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .background(AppTheme.Colors.background)
            }
        }
    }
}

// MARK: - Top MyChannels Section (ranks creators from provided videos)
private struct TopMyChannelsSection: View {
    let sourceVideos: [Video]
    var onSelect: (String, String, Int, Int, [Video]) -> Void = { _,_,_,_,_ in }

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
                .foregroundColor(AppTheme.Colors.primary)
                .padding(.top, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(Array(ranks.enumerated()), id: \.offset) { idx, c in
                        Button {
                            let vids = sourceVideos.filter { $0.creator.displayName == c.name }
                            onSelect(c.name, c.avatar, c.subscribers, c.totalViews, vids)
                        } label: {
                            VStack(alignment: .center, spacing: 8) {
                                ZStack(alignment: .topLeading) {
                                    ZStack {
                                        Circle()
                                            .stroke(AppTheme.Colors.primary, lineWidth: 3)
                                            .frame(width: 64, height: 64)

                                        // 🔥 FIX: Better image loading with visible placeholder
                                        CachedAsyncImage(url: URL(string: c.avatar)) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            ZStack {
                                                Circle()
                                                    .fill(AppTheme.Colors.surface)
                                                Image(systemName: "person.circle.fill")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                                    .padding(8)
                                            }
                                        }
                                        .frame(width: 58, height: 58)
                                        .clipShape(Circle())
                                    }

                                    Text("#\(idx + 1)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(AppTheme.Colors.primary))
                                        .padding(.top, 2)
                                        .padding(.leading, 2)
                                }

                                VStack(alignment: .center, spacing: 2) {
                                    Text(c.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .frame(width: 110)
                                    Text("\(fmt(c.subscribers)) subs • \(fmt(c.totalViews)) views")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .frame(width: 110)
                                }
                            }
                            .frame(width: 120)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .background(AppTheme.Colors.background)
            }
        }
    }
}

// MARK: - Preview
// MARK: - For You Section
struct ForYouSection: View {
    let onPlayVideo: (Video) -> Void
    let onSeeAllExplore: () -> Void
    
    @EnvironmentObject private var appState: AppState
    @StateObject private var personalizedService = PersonalizedFeedService.shared
    @State private var forYouVideos: [Video] = []
    @State private var isLoading = false
    
    var body: some View {
        if !forYouVideos.isEmpty || appState.isAuthenticated {
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
                            ForEach(forYouVideos.prefix(8)) { video in
                                MinimalVideoCard(video: video, action: { onPlayVideo(video) })
                                    .optimizeUIPerformance()
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .onAppear {
                if let uid = appState.currentUser?.id {
                    Task { await loadForYou(userId: uid) }
                }
            }
        }
    }
    
    private func loadForYou(userId: String) async {
        isLoading = true
        
        // 🚀 NEW: Use fair discovery engine for new creators
        let fairFeedVideos = await NewUserDiscoveryEngine.shared.generateFairFeed(
            limit: 20,
            userId: userId,
            includeNewCreators: true
        )
        
        if !fairFeedVideos.isEmpty {
            forYouVideos = fairFeedVideos
            isLoading = false
            print("✅ [HomeView] Loaded \(fairFeedVideos.count) videos with new creator discovery")
            return
        }
        
        // Fallback: Use home feed that includes uploaded videos
        var feed = await personalizedService.generateHomeFeed(limit: 12)
        
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
                
                // Rotating sparkles
                ForEach(0..<4) { index in
                    Image(systemName: "sparkle")
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
            
            // Continuous rotation for sparkles
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
