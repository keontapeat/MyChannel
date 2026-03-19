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
    case liveStream(FirestoreLiveStream)
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
        case .liveStream(let s): return "live-\(s.id)"
        case .custom(let id): return id
        }
    }
}

// MARK: - HomeView
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var featuredStore = FeaturedStore.shared
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
                            onPlayVideo: openVideo,
                            onAddToList: toggleWatchLater
                        )
                        .padding(.bottom, 40)

                        // 🔥 AI-POWERED RECOMMENDATIONS (NEW!)
                        AIRecommendationsSection { video in
                            openVideo(video)
                        }
                        .padding(.bottom, 24)
                        
                        MinimalContentSections(
                            onPlayVideo: { video in openVideo(video) },
                            onSelectMovie: { movie in route = .movie(movie) },
                            onSeeAllFreeMovies: { route = .allMovies },
                            onSeeAllLiveTV: { route = .allLiveTV },
                            onSeeAllTrending: { route = .trending },
                            onSeeAllMusic: { route = .custom("musicHub") },
                            onSeeAllExplore: { route = .custom("exploreHub") },
                            onSeeAllArtists: { route = .custom("topArtists") },
                            onSeeAllFilmmakers: { route = .custom("topFilmmakers") },
                            onSeeAllChannels: { route = .custom("topChannels") },
                            onOpenArtistDetail: { name, avatar, vids, total in
                                route = .artistDetail(name: name, avatar: avatar, videos: vids.isEmpty ? Array(Video.sampleVideos.prefix(8)) : vids, totalViews: total)
                            },
                            onOpenFilmmakerDetail: { name, films in
                                route = .filmmakerDetail(name: name, films: films)
                            },
                            onOpenChannelDetail: { name, avatar, subs, total, vids in
                                route = .channelDetail(name: name, avatar: avatar, subscribers: subs, totalViews: total, videos: vids.isEmpty ? Array(Video.sampleVideos.prefix(12)) : vids)
                            },
                            onSelectLiveStream: { stream in
                                route = .liveStream(stream)
                            }
                        )

                        Color.clear.frame(height: 100)
                    }
                }
                .coordinateSpace(name: "scroll")
                .onScrollOffsetChange { offset in
                    // Clamp and lightly smooth to avoid jitter when snapping back to top
                    let clamped = max(-2000, min(2000, offset))
                    // Simple low-pass filter for smoother header updates
                    let alpha: CGFloat = 0.2
                    scrollOffset = scrollOffset + alpha * (clamped - scrollOffset)
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
        .onChange(of: featuredStore.featured) { _ in
            // 🔥 React to featured video changes (add/remove)
            setupContent()
        }
        .sheet(isPresented: $presentStoryCreator) {
            UltimateStoryCreatorView { story in
                print("🏠 [HomeView] Story created callback received: \(story.id)")
                // Notify stories changed so all views refresh
                NotificationCenter.default.post(name: .storiesDidChange, object: nil)
                // Reload stories immediately
                Task {
                    await MainActor.run {
                        loadUserStories()
                    }
                    // Small delay to ensure database write completes
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    await MainActor.run {
                        presentStoryCreator = false
                        print("✅ [HomeView] Story creator dismissed, stories reloaded")
                    }
                }
            }
            .environmentObject(appState)
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingQuickProfile) {
            if let user = appState.currentUser {
                ProfileQuickMenu(user: user, isPresented: $showingQuickProfile)
                    .environmentObject(appState)
                    .environmentObject(AuthenticationManager.shared)
                    .presentationDetents([.height(680)])
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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenCreatorStudioDashboard"))) { _ in
            // Open full Creator Studio dashboard with current user
            route = .custom("creatorStudioDashboard")
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

            case .liveStream(let stream):
                LiveViewerView(stream: stream)
                    .onDisappear { self.route = nil }
            
            case .custom(let id):
                // Handle Creator Studio navigation
                if id.starts(with: "creatorStudioAnalytics_") {
                    ComprehensiveCreatorStudioView()
                        .environmentObject(appState)
                        .onDisappear { self.route = nil }
                } else if id == "creatorStudioDashboard" {
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
                } else if id == "topArtists" {
                    TopArtistsListView(onDismiss: { self.route = nil })
                        .environmentObject(appState)
                        .background(Color(.systemBackground).ignoresSafeArea())
                        .onDisappear { self.route = nil }
                } else if id == "topFilmmakers" {
                    TopFilmmakersListView(onDismiss: { self.route = nil })
                        .background(Color(.systemBackground).ignoresSafeArea())
                        .onDisappear { self.route = nil }
                } else if id == "topChannels" {
                    TopChannelsListView(onDismiss: { self.route = nil })
                        .background(Color(.systemBackground).ignoresSafeArea())
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

    private func setupContent() {
        // 🔥 FEATURED VIDEOS: Same intro as Featured Edit (1/3) so counts match; current user as creator for profile/subscribe
        let ownerFeatured = FeaturedStore.shared.toVideos()
        let intro = FeaturedStore.ownerIntroVideo() ?? shotByKeontaIntro()
        
        var content: [Video] = [intro]
        content.append(contentsOf: Array(ownerFeatured.filter { $0.id != intro.id }.prefix(2)))
        
        featuredContent = content
        heroVideoIndex = 0
        
        // ⚡ PRE-WARM: Touch the asset cache for every featured video so Firebase Storage
        // starts downloading before the hero card renders — no cold-start lag on autoplay.
        for video in content where !video.videoURL.isEmpty {
            _ = LoopAssetCache.shared.asset(for: video.videoURL)
        }
        
        print("📺 Featured content loaded: \(featuredContent.count) videos")
    }
    
    // 🔥 Shot By Keonta intro video - Streams from Firebase Storage
    private func shotByKeontaIntro() -> Video {
        let currentUser = AppState.shared.currentUser ?? AuthenticationManager.shared.currentUser
        let keontaUser = currentUser ?? User(
            id: "sbkeonta_owner",
            username: "sbkeonta_",
            displayName: "Shot By Keonta",
            email: "keontapeat@mychannel.live",
            profileImageURL: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
            isVerified: true,
            isCreator: true
        )

        let videoURL = "https://firebasestorage.googleapis.com/v0/b/mychannel-ca26d.firebasestorage.app/o/Shot%20By%20Keonta%20Intro%204k.MP4?alt=media&token=88e366e2-efde-4631-9707-d7e9fadc9568"
        let poster = "asset://ShotByKeontaThumbnail"

        return Video(
            id: FeaturedStore.ownerIntroVideoId,
            title: "Shot By Keonta",
            description: "Professional videography & content creation",
            thumbnailURL: poster,
            videoURL: videoURL,
            duration: 11,
            viewCount: 1_500_000,
            likeCount: 85_000,
            creator: keontaUser,
            category: .entertainment,
            tags: ["intro", "keonta", "mychannel"],
            isPublic: true,
            quality: [.quality720p, .quality1080p, .quality2160p],
            aspectRatio: .landscape,
            isLiveStream: false,
            contentSource: .userUploaded,
            externalID: nil,
            isVerified: true
        )
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
        _ = appState.subscriptions
        
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

    private func openVideo(_ video: Video) {
        route = .video(video)
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
    let onSeeAllArtists: () -> Void
    let onSeeAllFilmmakers: () -> Void
    let onSeeAllChannels: () -> Void
    let onOpenArtistDetail: (String, String, [Video], Int) -> Void
    let onOpenFilmmakerDetail: (String, [FreeMovie]) -> Void
    let onOpenChannelDetail: (String, String, Int, Int, [Video]) -> Void
    var onSelectLiveStream: ((FirestoreLiveStream) -> Void)? = nil

    @EnvironmentObject private var appState: AppState
    @State private var blockbusterMovies: [FreeMovie] = []
    @State private var loadingBlockbusters: Bool = false
    @State private var friendChannelVideos: [Video] = []
    @State private var liveChannelsAPI: [LiveTVChannel] = []
    @State private var showLocalArtistsOnly: Bool = false
    @State private var selectedLiveTVChannel: LiveTVChannel?

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

        // 🔥 Use local thumbnail from Assets.xcassets (extracted from video at 2 seconds)
        let poster = "asset://ShotByKeontaThumbnail"

        // Monetization flag so ad preview and pre-roll show
        let adBreaks = Video.AdBreaks(preRoll: true, midRoll: false, postRoll: false)
        let monetization = Video.MonetizationSettings(isMonetized: true, adBreaks: adBreaks, sponsorSegments: [], merchandise: nil, donationEnabled: false, subscriptionTier: nil, totalRevenue: 0)

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
            // LIVE NOW - Active live streams from Firestore
            LiveNowSection { stream in
                onSelectLiveStream?(stream)
            }
            .onAppear {
                LiveStreamManager.shared.startListening()
            }

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

            // 🔥🔥🔥 AI-POWERED LIVE TV SECTION - THE BEST IN THE WORLD 🔥🔥🔥
            AILiveTVSection(
                onSelectChannel: { channel in
                    selectedLiveTVChannel = channel
                },
                onSeeAll: { onSeeAllLiveTV() }
            )
            
            // 🔥 Quick Tune - Smart loading section
            QuickTuneSection(liveChannelsAPI: liveChannelsAPI)

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
                                    EnhancedMoviesService.shared.addToRecentlyWatched(movie)
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
                },
                onSeeAll: onSeeAllArtists
            )
            .padding(.horizontal, 20)
            TopIndieFilmmakersSection(
                onSeeAll: onSeeAllFilmmakers,
                onSelect: { name, films in
                    onOpenFilmmakerDetail(name, films)
                }
            )
            .padding(.horizontal, 20)

            TopMyChannelsSection(
                sourceVideos: detroitFlintArtistsTrending() + gamingCOD() + Video.sampleVideos,
                onSelect: { name, avatar, subs, total, vids in
                    onOpenChannelDetail(name, avatar, subs, total, vids)
                },
                onSeeAll: onSeeAllChannels
            )
            .padding(.horizontal, 20)
        }
        // Native PiP doesn't affect layout, so no need to disable animations
        .task {
            // ⚡ PERFORMANCE FIX: Load all in parallel instead of sequentially
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await loadBlockbusters() }
                group.addTask { await loadFriendChannelVideos() }
                group.addTask { await loadLiveChannelsAPI() }
            }
        }
        .fullScreenCover(item: $selectedLiveTVChannel) { channel in
            LiveTVPlayerView(channel: channel)
                .environmentObject(appState)
                .background(Color.black)
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
        
        // 🔥 FIRE: Preload the first channels for instant thumbnail playback
        await LiveTVService.shared.preloadFireChannels(count: 6)
        
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
            ("Big Mgr Fat Dee", "BigMgrFatDeeAvatar", 285_000, nil),
            ("Bk Dumpp", "BkDumppAvatar", 285_000, nil),
            ("Super Shoddy", "SuperShoddyAvatar", 285_000, nil),
            ("Mbk Keelan", "MbkKeelanAvatar", 285_000, nil),
            ("Cw Timo", "CwTimoAvatar", 285_000, nil),
            ("Fattyrichgang Dell", "FattyrichgangDellAvatar", 285_000, nil),
            ("BagLife Tee", "BagLifeTeeAvatar", 285_000, nil),
            ("Kai Edwards", "KaiEdwardsAvatar", 285_000, nil),
            ("Mia PatMan", "MiaPatManAvatar", 285_000, nil),
            ("Yung Sak Runner", "YungSakRunnerAvatar", 285_000, nil),
            ("Don Perrion", "DonPerrionAvatar", 285_000, nil),
            ("Way P", "WayPAvatar", 285_000, nil),
            ("Ysr Driveway", "YsrDrivewayAvatar", 285_000, nil),
            ("Ysr Gramz", "YsrGramzAvatar", 285_000, nil),
            ("Krispylife Kidd", "KrispylifeKiddAvatar", 285_000, nil),
            ("Babii Moe", "BabiiMoeAvatar", 285_000, nil),
            ("Rich Dior", "RichDiorAvatar", 285_000, nil),
            ("MBK BO Demon", "MBKBODemonAvatar", 285_000, nil),
            ("MBK Uncle Ruckus", "MBKUncleRuckusAvatar", 285_000, nil),
            ("Ktrip", "KtripAvatar", 285_000, nil),
            ("Cliff King Mac", "CliffKingMacAvatar", 285_000, nil),
            ("Mia Rerock", "MiaRerockAvatar", 285_000, nil),
            ("Juscallmeep", "JuscallmeepAvatar", 285_000, nil),
            ("Rlsg Kd", "RlsgKdAvatar", 285_000, nil),
            ("Yn Jay", "YnJayAvatar", 285_000, nil),
            ("YN Quee", "YNQueeAvatar", 285_000, nil),
            ("Detwan Love", "DetwanLoveAvatar", 285_000, nil),
            ("Savagelife Tank", "SavagelifeTankAvatar", 285_000, nil),
            ("Mia Ghost", "MiaGhostAvatar", 285_000, nil),
            ("2800 TBaby", "2800TBabyAvatar", 285_000, nil),
            ("Luh Sportcoat", "LuhSportcoatAvatar", 285_000, nil),
            ("Ftos Twan", "FtosTwanAvatar", 285_000, nil),
            ("Hotboy Curry", "HotboyCurryAvatar", 285_000, nil),
            ("Twyce Marshall", "TwyceMarshallAvatar", 275_000, nil),
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
        // Allow all artists - UI will show fallback if image doesn't exist
        allArtists
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

// MARK: - 🔥 Quick Tune Section (Smart Loading)
private struct QuickTuneSection: View {
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
                        allowPlaybackInPreviews: false
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
                            allowPlaybackInPreviews: false
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
        let source = liveChannelsAPI.isEmpty ? LiveTVChannel.sampleChannels : liveChannelsAPI
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
        if streamReady && !streamFailed {
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
                        }
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
private struct LiveBadge: View {
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
    var onSeeAll: () -> Void = {}

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
    
    var onSeeAll: () -> Void = {}

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
        
        // Pros Kt as #3 filmmaker
        let prosKtAssetName = "ProsKtAvatar"
        let prosKtAvatar: String
        if UIImage(named: prosKtAssetName) != nil {
            prosKtAvatar = "asset://\(prosKtAssetName)"
            print("✅ Found Pros Kt asset: \(prosKtAssetName)")
        } else {
            prosKtAvatar = "https://i.pravatar.cc/200?u=pros_kt"
            print("⚠️ Pros Kt asset '\(prosKtAssetName)' not found - using placeholder")
        }
        
        let prosKt = Filmmaker(
            name: "Pros Kt",
            films: 18,
            score: 98, // Third highest score for #3 position
            avatar: prosKtAvatar
        )
        
        let names = [
            "A. Rivers", "N. Carter", "M. Sloan", "J. Patel", "R. Alvarez",
            "S. Kim", "D. Morgan", "K. O'Neal", "B. Laurent", "T. Ito"
        ]
        let items = names.enumerated().map { idx, n in
            Filmmaker(
                name: n,
                films: Int.random(in: 2...12),
                score: Int.random(in: 60...97), // Max 97 to stay below Pros Kt
                avatar: "https://i.pravatar.cc/200?u=indie_\(idx)"
            )
        }
        
        let all = [teeCee, merchHD, prosKt] + items
        return all.sorted { $0.score > $1.score }
    }

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

// MARK: - Top MyChannels Section (Simple Style - Matches Other Top Sections)
private struct TopMyChannelsSection: View {
    let sourceVideos: [Video]
    var onSelect: (String, String, Int, Int, [Video]) -> Void = { _,_,_,_,_ in }
    var onSeeAll: () -> Void = {}
    
    // Regular MyChannel users with profile pictures (looks like real people who signed up)
    private var featuredCreators: [(id: String, name: String, avatar: String, subscribers: Int, totalViews: Int)] {
        let pinnedCreators: [(id: String, name: String, avatar: String, subscribers: Int, totalViews: Int)] = [
            (
                "ktrip_official",
                "KTrip",
                "https://i.ytimg.com/vi/xfdydb_3Ra0/hqdefault.jpg",
                5_000,
                1_800_000
            ),
            (
                "baby_ju_official",
                "Baby Ju",
                "https://i.ytimg.com/vi/JSXmfgZzHqQ/hqdefault.jpg",
                2_000,
                1_200_000
            ),
            (
                "mbk_cari_official",
                "Mbk Cari",
                "https://i.ytimg.com/vi/JSXmfgZzHqQ/hqdefault.jpg",
                1_500,
                195_000
            )
        ]
        let communityFavorites: [(id: String, name: String, avatar: String, subscribers: Int, totalViews: Int)] = [
            ("alex_m", "Alex M.", "https://i.pravatar.cc/150?img=1", 12_400, 890_000),
            ("jordan_t", "Jordan T.", "https://i.pravatar.cc/150?img=3", 8_200, 420_000),
            ("sam_r", "Sam R.", "https://i.pravatar.cc/150?img=5", 3_100, 156_000),
            ("casey_l", "Casey L.", "https://i.pravatar.cc/150?img=9", 22_800, 1_200_000),
            ("riley_j", "Riley J.", "https://i.pravatar.cc/150?img=10", 1_560, 78_000),
            ("morgan_k", "Morgan K.", "https://i.pravatar.cc/150?img=11", 45_200, 2_100_000),
            ("jamie_w", "Jamie W.", "https://i.pravatar.cc/150?img=12", 6_700, 310_000),
            ("drew_f", "Drew F.", "https://i.pravatar.cc/150?img=13", 19_300, 980_000),
            ("taylor_s", "Taylor S.", "https://i.pravatar.cc/150?img=15", 890, 42_000),
            ("quinn_b", "Quinn B.", "https://i.pravatar.cc/150?img=20", 28_100, 1_450_000)
        ]
        return pinnedCreators + communityFavorites
    }

    private func format(_ n: Int) -> String {
        if n >= 1_000_000_000 { return String(format: "%.1fB", Double(n)/1_000_000_000) }
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n)/1_000) }
        return "\(n)"
    }

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

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(Array(featuredCreators.enumerated()), id: \.element.id) { idx, creator in
                        Button {
                            HapticManager.shared.impact(style: .medium)
                            let vids = sourceVideos.filter { $0.creator.displayName.lowercased().contains(creator.name.lowercased()) }
                            onSelect(creator.name, creator.avatar, creator.subscribers, creator.totalViews, vids)
                        } label: {
                            VStack(alignment: .center, spacing: 8) {
                                ZStack(alignment: .topLeading) {
                                    ZStack {
                                        Circle()
                                            .stroke(AppTheme.Colors.primary, lineWidth: 3)
                                            .frame(width: 64, height: 64)

                                        CachedAsyncImage(url: URL(string: creator.avatar)) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            ZStack {
                                                Circle().fill(AppTheme.Colors.surface)
                                                Image(systemName: "person.circle.fill")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                                    .padding(12)
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
                                    Text(creator.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .frame(width: 110)
                                    Text("\(format(creator.subscribers)) subs")
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

// MARK: - See All List Views (Top Artists / Filmmakers / Channels)

private struct ArtistRowItem: Identifiable {
    let id = UUID()
    let name: String
    let avatar: String
    let videos: [Video]
    let totalViews: Int
}

private struct TopArtistsListView: View {
    let onDismiss: () -> Void
    @EnvironmentObject private var appState: AppState

    private var rankings: [ArtistRowItem] {
        let sourceVideos = FeaturedStore.shared.toVideos() + Video.sampleVideos
        let grouped = Dictionary(grouping: sourceVideos) { $0.creator.displayName }
        var ranks = grouped.map { (name, vids) -> ArtistRowItem in
            let views = vids.reduce(0) { $0 + $1.viewCount }
            return ArtistRowItem(
                name: name,
                avatar: vids.first?.creator.profileImageURL ?? "https://i.pravatar.cc/200?u=\(name)",
                videos: vids,
                totalViews: views
            )
        }
        let dynamicFriends = OwnerFriendsStore.shared.friends
        let pinnedOrder = (OwnerProfile.instagramFriends + dynamicFriends).map { $0.name }
        for f in (OwnerProfile.instagramFriends + dynamicFriends) {
            if let idx = ranks.firstIndex(where: { $0.name == f.name }) {
                let existing = ranks[idx]
                ranks[idx] = ArtistRowItem(name: existing.name, avatar: f.avatar, videos: existing.videos, totalViews: existing.totalViews)
            } else {
                ranks.append(ArtistRowItem(name: f.name, avatar: f.avatar, videos: [], totalViews: 0))
            }
        }
        var sorted = ranks.sorted { $0.totalViews > $1.totalViews }
        if !pinnedOrder.isEmpty {
            let pinnedSet = Set(pinnedOrder)
            let pinnedItems = pinnedOrder.compactMap { name in sorted.first(where: { $0.name == name }) }
            let nonPinned = sorted.filter { !pinnedSet.contains($0.name) }
            sorted = pinnedItems + nonPinned
        }
        return sorted
    }

    private func format(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n)/1_000) }
        return "\(n)"
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(rankings.enumerated()), id: \.element.id) { idx, artist in
                    NavigationLink {
                        ArtistPageView(
                            artist: Artist(
                                id: artist.id.uuidString,
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
                        HStack(spacing: 12) {
                            Text("#\(idx + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Capsule().fill(AppTheme.Colors.primary))
                            AppAsyncImage(url: URL(string: artist.avatar)) { img in
                                img.resizable().scaledToFill()
                            } placeholder: { Color.gray.opacity(0.3) }
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(artist.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.primary)
                                Text("\(format(artist.totalViews)) total views")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
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

private struct FilmmakerRowItem: Identifiable {
    let id = UUID()
    let name: String
    let films: [FreeMovie]
    let avatar: String
}

private struct TopFilmmakersListView: View {
    let onDismiss: () -> Void

    private var filmmakers: [FilmmakerRowItem] {
        let possibleNames = ["TeeCeeAvatar", "TeeCee", "tee_cee", "TeeC eeAvatar", "TeeCee_Avatar"]
        var teeCeeAvatar = "https://i.pravatar.cc/200?u=tee_cee"
        for assetName in possibleNames {
            if UIImage(named: assetName) != nil {
                teeCeeAvatar = "asset://\(assetName)"
                break
            }
        }
        let merchHDAvatar: String = UIImage(named: "MerchHDAvatar") != nil ? "asset://MerchHDAvatar" : "https://i.pravatar.cc/200?u=merch_hd"
        let prosKtAvatar: String = UIImage(named: "ProsKtAvatar") != nil ? "asset://ProsKtAvatar" : "https://i.pravatar.cc/200?u=pros_kt"
        let names = [
            "A. Rivers", "N. Carter", "M. Sloan", "J. Patel", "R. Alvarez",
            "S. Kim", "D. Morgan", "K. O'Neal", "B. Laurent", "T. Ito"
        ]
        let extra = names.enumerated().map { idx, n in
            FilmmakerRowItem(
                name: n,
                films: Array(FreeMovie.sampleMovies.shuffled().prefix(Int.random(in: 6...12))),
                avatar: "https://i.pravatar.cc/200?u=indie_\(idx)"
            )
        }
        let top = [
            FilmmakerRowItem(name: "Tee Cee", films: Array(FreeMovie.sampleMovies.prefix(24)), avatar: teeCeeAvatar),
            FilmmakerRowItem(name: "Merch HD", films: Array(FreeMovie.sampleMovies.prefix(15)), avatar: merchHDAvatar),
            FilmmakerRowItem(name: "Pros Kt", films: Array(FreeMovie.sampleMovies.prefix(18)), avatar: prosKtAvatar)
        ]
        return (top + extra).sorted { $0.films.count > $1.films.count }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(filmmakers.enumerated()), id: \.element.id) { idx, filmmaker in
                    NavigationLink {
                        FilmmakerDetailView(name: filmmaker.name, films: filmmaker.films)
                    } label: {
                        HStack(spacing: 12) {
                            Text("#\(idx + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Capsule().fill(AppTheme.Colors.primary))
                            
                            // Avatar, mirroring Top Artists list style
                            AppAsyncImage(url: URL(string: filmmaker.avatar)) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color.white.opacity(0.3)
                            }
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            
                            Text(filmmaker.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.primary)
                            Spacer()
                            Text("\(filmmaker.films.count) films")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
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

private struct ChannelRowItem: Identifiable {
    let id: String
    let name: String
    let avatar: String
    let subscribers: Int
    let totalViews: Int
    let videos: [Video]
}

private struct TopChannelsListView: View {
    let onDismiss: () -> Void

    private let featuredCreators: [(id: String, name: String, avatar: String, subscribers: Int, totalViews: Int)] = [
        ("alex_m", "Alex M.", "https://i.pravatar.cc/150?img=1", 12_400, 890_000),
        ("jordan_t", "Jordan T.", "https://i.pravatar.cc/150?img=3", 8_200, 420_000),
        ("sam_r", "Sam R.", "https://i.pravatar.cc/150?img=5", 3_100, 156_000),
        ("casey_l", "Casey L.", "https://i.pravatar.cc/150?img=9", 22_800, 1_200_000),
        ("riley_j", "Riley J.", "https://i.pravatar.cc/150?img=10", 1_560, 78_000),
        ("morgan_k", "Morgan K.", "https://i.pravatar.cc/150?img=11", 45_200, 2_100_000),
        ("jamie_w", "Jamie W.", "https://i.pravatar.cc/150?img=12", 6_700, 310_000),
        ("drew_f", "Drew F.", "https://i.pravatar.cc/150?img=13", 19_300, 980_000),
        ("taylor_s", "Taylor S.", "https://i.pravatar.cc/150?img=15", 890, 42_000),
        ("quinn_b", "Quinn B.", "https://i.pravatar.cc/150?img=20", 28_100, 1_450_000)
    ]

    private var channelItems: [ChannelRowItem] {
        let sourceVideos = FeaturedStore.shared.toVideos() + Video.sampleVideos
        return featuredCreators.map { c in
            let vids = sourceVideos.filter { $0.creator.displayName.lowercased().contains(c.name.lowercased()) }
            return ChannelRowItem(
                id: c.id,
                name: c.name,
                avatar: c.avatar,
                subscribers: c.subscribers,
                totalViews: c.totalViews,
                videos: vids.isEmpty ? Array(Video.sampleVideos.prefix(12)) : vids
            )
        }
    }

    private func format(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n)/1_000) }
        return "\(n)"
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(channelItems.enumerated()), id: \.element.id) { idx, channel in
                    NavigationLink {
                        ChannelDetailView(
                            name: channel.name,
                            avatarURL: channel.avatar,
                            subscribers: channel.subscribers,
                            totalViews: channel.totalViews,
                            videos: channel.videos
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Text("#\(idx + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Capsule().fill(AppTheme.Colors.primary))
                            CachedAsyncImage(url: URL(string: channel.avatar)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(AppTheme.Colors.surface)
                                    .overlay(Image(systemName: "person.circle.fill").foregroundColor(.secondary))
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(channel.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.primary)
                                Text("\(format(channel.subscribers)) subs")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
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

// MARK: - Scale Button Style
private struct HomeScaleButtonStyle: ButtonStyle {
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
            // Fetch actual video objects for those IDs (falls through to fair feed if empty)
            let recVideos = (try? await VideoFirestoreService.shared.fetchMultipleVideos(videoIds: Array(videoIds.prefix(20)))) ?? []
            if !recVideos.isEmpty {
                await MainActor.run {
                    forYouVideos = recVideos
                    isLoading = false
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
        
        if !fairFeedVideos.isEmpty {
            forYouVideos = fairFeedVideos
            isLoading = false
            print("✅ [HomeView] Loaded \(fairFeedVideos.count) videos with new creator discovery")
            return
        }
        
        // Final fallback: Use home feed that includes uploaded videos
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
