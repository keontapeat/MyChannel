import SwiftUI
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif



// MARK: - HomeView
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var featuredStore = FeaturedStore.shared
    private let globalPlayer = GlobalVideoPlayerManager.shared
    @StateObject private var viewModel = HomeViewModel()


    // Route-driven presentation (fixes white screen when dismissing covers)
    
    // Quick profile menu
    
    // 🔥 Thermonuclear Featured Manager

    @Namespace private var storiesNS

    // 🔥 YOUTUBE PARITY: Home filter chips

    private var activeStoriesHeroId: String? {
        if case let .stories(story) = viewModel.route { return story.id }
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
        GeometryReader { geo in
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemBackground)
                    .ignoresSafeArea()

                homeScrollView

                homeHeader
                    .allowsHitTesting(true)
                    .zIndex(1)

                // Featured manager removed - use Profile > Settings > Featured Videos instead
            }
        }
        .onAppear {
            setupContent()
            loadUserStories()
            loadWatchHistoryFromFirestore()
        }
        .refreshable { await refreshContent() }
        .onChange(of: appState.isAuthenticated) { newValue in
            loadUserStories()
        }
        .onChange(of: featuredStore.featured) { _ in
            // 🔥 React to featured video changes (add/remove)
            setupContent()
        }
        .sheet(isPresented: $viewModel.presentStoryCreator) {
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
                        viewModel.presentStoryCreator = false
                        print("✅ [HomeView] Story creator dismissed, stories reloaded")
                    }
                }
            }
            .environmentObject(appState)
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $viewModel.showingQuickProfile, onDismiss: {
            handlePendingQuickProfileAction()
        }) {
            if let user = appState.currentUser {
                ProfileQuickMenu(
                    user: user,
                    isPresented: $viewModel.showingQuickProfile,
                    onSelectAction: { action in
                        // Queue the action and close the sheet. The action runs in
                        // onDismiss above, once this sheet has fully dismissed — no
                        // sleep hacks, no "present while dismissing" glitches.
                        viewModel.pendingQuickProfileAction = action
                        viewModel.showingQuickProfile = false
                    }
                )
                .environmentObject(appState)
                .environmentObject(AuthenticationManager.shared)
                .uiKitSheet(
                    detents: [.large()],
                    showGrabber: true,
                    cornerRadius: 20,
                    scrollingExpandsToLargeDetent: true
                )
            }
        }
        .sheet(isPresented: $viewModel.showingEditProfile) {
            if let user = appState.currentUser {
                NavigationStack {
                    EditProfileView(user: .constant(user))
                }
                .environmentObject(appState)
                .environmentObject(AuthenticationManager.shared)
            }
        }
        .sheet(isPresented: $viewModel.showingSettings) {
            SafeProfileSettingsView()
                .environmentObject(appState)
                .environmentObject(AuthenticationManager.shared)
        }
        .sheet(isPresented: $viewModel.showingSwitchProfile) {
            ProfileSwitcherView()
                .environmentObject(appState)
                .environmentObject(AuthenticationManager.shared)
        }
        .sheet(isPresented: $viewModel.showingFeaturedManager) {
            ThermonuclearFeaturedManager()
                .environmentObject(appState)
                .background(
                    UIKitSheetConfigurator(
                        configuration: UIKitSheetConfiguration(
                            detents: [.large()],
                            largestUndimmedDetentIdentifier: .large,
                            prefersGrabberVisible: true,
                            prefersScrollingExpandsWhenScrolledToEdge: false,
                            preferredCornerRadius: 28
                        )
                    )
                )
        }
        // Auto-scroll removed: hero section only changes on manual swipe
        .onReceive(NotificationCenter.default.publisher(for: .storiesDidChange)) { _ in
            loadUserStories()
        }
        // 🔥🔥🔥 YOUTUBE PARITY: When a video finishes uploading, the upload flow posts
        // "RefreshHomeFeed" with the new Video. Insert it at the top instantly (optimistic)
        // and reconcile with Firestore so the creator sees their post immediately — just
        // like YouTube. Falls back to a full refresh if no object is attached.
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshHomeFeed"))) { _ in
            // Refresh featured + "New from creators" surfaces.
            setupContent()
            NotificationCenter.default.post(name: NSNotification.Name("RefreshHomeContentSections"), object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenFullProfile"))) { notification in
            if let user = notification.object as? User {
                viewModel.route = .publicProfile(user)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenSettings"))) { _ in
            viewModel.showingSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowSwitchProfile"))) { _ in
            viewModel.showingSwitchProfile = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenVideoAnalytics"))) { notification in
            // 🔥 OPEN CREATOR STUDIO: Navigate to analytics for specific video
            if let video = notification.object as? Video {
                // Navigate to Creator Studio with analytics tab selected
                viewModel.route = .custom("creatorStudioAnalytics_\(video.id)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenCreatorStudioDashboard"))) { _ in
            // Open full Creator Studio dashboard with current user
            viewModel.route = .custom("creatorStudioDashboard")
        }
        .fullScreenCover(item: $viewModel.route) { route in
            destinationView(for: route)
        }
        .onChange(of: viewModel.route?.id) { newValue in
            let shouldPause = newValue != nil
            NotificationCenter.default.post(
                name: NSNotification.Name(shouldPause ? "LivePreviewsShouldPause" : "LivePreviewsShouldResume"),
                object: nil
            )
        }
        .environment(\.adaptiveCardWidth, iPadLayout.videoCardWidth(in: geo))
        .environment(\.horizontalSizeClass, .compact)
        }
    }
    
    // MARK: - Scroll content (extracted from body to keep the launch-time stack
    // frame small — see the Route Destination note below.)
    @ViewBuilder
    private var homeScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                Color.clear.frame(height: 100)

                // 🔥 YOUTUBE PARITY: Filter chips bar
                HomeFilterChipsBar(
                    selected: $viewModel.selectedHomeChip,
                    onChipTap: { chip in handleHomeChipTap(chip) }
                )
                .padding(.bottom, 8)

                if viewModel.showingStories && (!viewModel.assetStories.isEmpty || appState.isAuthenticated) {
                    AssetBouncyStoriesRow(
                        stories: viewModel.assetStories,
                        onStoryTap: { story in
                            viewModel.route = .stories(story)
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
                    featuredContent: viewModel.featuredContent,
                    showLiveHeroPreviewInPreviews: true,
                    onPlayVideo: openVideo,
                    onAddToList: toggleWatchLater
                )
                .offset(y: viewModel.scrollOffset < 0 ? -viewModel.scrollOffset * 0.25 : 0)
                .scaleEffect(viewModel.scrollOffset < 0 ? max(0.92, 1.0 + (viewModel.scrollOffset / 2500)) : 1.0)
                .opacity(viewModel.scrollOffset < 0 ? max(0.4, 1.0 + (viewModel.scrollOffset / 800)) : 1.0)
                .padding(.bottom, 40)

                // 🔥 AI-POWERED RECOMMENDATIONS (NEW!)
                AIRecommendationsSection { video in
                    openVideo(video)
                }
                .padding(.bottom, 24)

                homeContentSections

                Color.clear.frame(height: 100)
            }
        }
        .coordinateSpace(name: "scroll")
        .onScrollOffsetChange { offset in
            // Clamp and lightly smooth to avoid jitter when snapping back to top
            let clamped = max(-2000, min(2000, offset))
            // Simple low-pass filter for smoother header updates
            let alpha: CGFloat = 0.2
            viewModel.scrollOffset = viewModel.scrollOffset + alpha * (clamped - viewModel.scrollOffset)
        }
    }

    @ViewBuilder
    private var homeContentSections: some View {
        MinimalContentSections(
            onPlayVideo: { video in openVideo(video) },
            onSelectMovie: { movie in viewModel.route = .movie(movie) },
            onSeeAllFreeMovies: { _ in viewModel.route = .allMovies },
            onSeeAllLiveTV: { viewModel.route = .allLiveTV },
            onSeeAllTrending: { viewModel.route = .trending },
            onSeeAllMusic: { viewModel.route = .custom("musicHub") },
            onSeeAllExplore: { viewModel.route = .custom("exploreHub") },
            onSeeAllArtists: { viewModel.route = .custom("topArtists") },
            onSeeAllFilmmakers: { viewModel.route = .custom("topFilmmakers") },
            onSeeAllChannels: { viewModel.route = .custom("topChannels") },
            onOpenArtistDetail: { name, avatar, vids, total in
                viewModel.route = .artistDetail(name: name, avatar: avatar, videos: vids, totalViews: total)
            },
            onOpenArtistMusicProfile: { artist in
                viewModel.route = .artistMusicProfile(artist)
            },
            onOpenFilmmakerDetail: { name, films in
                viewModel.route = .filmmakerDetail(name: name, films: films)
            },
            onOpenChannelDetail: { name, avatar, subs, total, vids in
                viewModel.route = .channelDetail(name: name, avatar: avatar, subscribers: subs, totalViews: total, videos: vids)
            },
            onSelectLiveStream: { stream in
                viewModel.route = .liveStream(stream)
            }
        )
    }

    @ViewBuilder
    private var homeHeader: some View {
        MinimalNavigationHeader(
            scrollOffset: viewModel.scrollOffset,
            onSearchTap: { viewModel.route = .search },
            onProfileTap: {
                if appState.isAuthenticated {
                    // User is logged in → show quick profile menu
                    viewModel.showingQuickProfile = true
                } else {
                    // User is NOT logged in → show sign-in sheet
                    NotificationCenter.default.post(name: .presentSignInSheet, object: nil)
                }
            }
        )
    }

    // MARK: - Route Destination (extracted from body to keep the launch-time
    // stack frame small — a monolithic switch inside `.fullScreenCover` produced a
    // single arm64 frame > the main-thread stack guard page → EXC_BAD_ACCESS crash
    // on launch, especially on iPad's larger layout pass. See MainTabView for the
    // same split pattern.)
    @ViewBuilder
    private func destinationView(for route: FullScreenRoute) -> some View {
        switch route {
        case .video(let video):
            VideoDetailView(video: video)
                .onDisappear { self.viewModel.route = nil }

        case .movie(let movie):
            MovieDetailView(movie: movie)
                .onDisappear { self.viewModel.route = nil }

        case .search:
            SearchView()
                .onDisappear { self.viewModel.route = nil }

        case .stories(let story):
            storiesDestination(for: story)

        case .allMovies:
            MoviesView()
                .environmentObject(appState)
                .onDisappear { self.viewModel.route = nil }

        case .allLiveTV:
            LiveTVChannelsView()
                .environmentObject(appState)
                .background(Color(.systemBackground).ignoresSafeArea())
                .onDisappear { self.viewModel.route = nil }

        case .trending:
            TrendingView()
                .background(Color(.systemBackground).ignoresSafeArea())
                .onDisappear { self.viewModel.route = nil }

        case .artistDetail(let name, let avatar, let videos, let total):
            ArtistDetailView(name: name, avatarURL: avatar, videos: videos, totalViews: total)
                .onDisappear { self.viewModel.route = nil }

        case .artistMusicProfile(let catalogArtist):
            NavigationStack {
                ArtistProfileView(artist: catalogArtist)
            }
            .onDisappear { self.viewModel.route = nil }

        case .filmmakerDetail(let name, let films):
            FilmmakerDetailView(name: name, films: films)
                .onDisappear { self.viewModel.route = nil }

        case .channelDetail(let name, let avatar, let subs, let total, let videos):
            ChannelDetailView(name: name, avatarURL: avatar, subscribers: subs, totalViews: total, videos: videos)
                .onDisappear { self.viewModel.route = nil }

        case .publicProfile(let user):
            PublicProfileView(user: user)
                .onDisappear { self.viewModel.route = nil }

        case .liveStream(let stream):
            LiveViewerView(stream: stream)
                .onDisappear { self.viewModel.route = nil }

        case .custom(let id):
            customDestination(for: id)
        }
    }

    @ViewBuilder
    private func storiesDestination(for story: AssetStory) -> some View {
        // Instagram-style: group ALL stories by user, open at tapped user, auto-advance to next
        let groups = UserStoryGroup.group(from: viewModel.allAssetStories)
        let sortedGroups = UserStoryGroup.sorted(groups)
        let tappedStoryId = story.stableStoryId
        let startIdx = sortedGroups.firstIndex(where: { group in
            group.stories.contains { $0.stableStoryId == tappedStoryId }
        }) ?? 0
        AssetStoriesPagerView(
            userGroups: sortedGroups,
            initialUserIndex: startIdx
        ) {
            self.viewModel.route = nil
        }
        .onDisappear { self.viewModel.route = nil }
    }

    @ViewBuilder
    private func customDestination(for id: String) -> some View {
        // Handle Creator Studio navigation
        if id.starts(with: "creatorStudioAnalytics_") {
            NavigationStack {
                ComprehensiveCreatorStudioView()
                    .environmentObject(appState)
            }
            .onDisappear { self.viewModel.route = nil }
        } else if id == "creatorStudioDashboard" {
            NavigationStack {
                ComprehensiveCreatorStudioView()
                    .environmentObject(appState)
            }
            .onDisappear { self.viewModel.route = nil }
        } else if id == "musicHub" {
            MusicHubView()
                .environmentObject(appState)
                .onDisappear { self.viewModel.route = nil }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DismissMusicHub"))) { _ in
                    self.viewModel.route = nil
                }
        } else if id == "exploreHub" {
            ExploreHubView()
                .onDisappear { self.viewModel.route = nil }
        } else if id == "topArtists" {
            TopArtistsListView(onDismiss: { self.viewModel.route = nil })
                .environmentObject(appState)
                .background(Color(.systemBackground).ignoresSafeArea())
                .onDisappear { self.viewModel.route = nil }
        } else if id == "topFilmmakers" {
            TopFilmmakersListView(onDismiss: { self.viewModel.route = nil })
                .background(Color(.systemBackground).ignoresSafeArea())
                .onDisappear { self.viewModel.route = nil }
        } else if id == "topChannels" {
            TopChannelsListView(onDismiss: { self.viewModel.route = nil })
                .background(Color(.systemBackground).ignoresSafeArea())
                .onDisappear { self.viewModel.route = nil }
        }
    }

    // MARK: - Setup Methods

    private func handlePendingQuickProfileAction() {
        guard let action = viewModel.pendingQuickProfileAction else { return }
        viewModel.pendingQuickProfileAction = nil

        guard let user = appState.currentUser else { return }

        switch action {
        case .creatorStudio:
            viewModel.route = .custom("creatorStudioDashboard")
        case .viewChannel:
            viewModel.route = .publicProfile(user)
        case .analytics:
            viewModel.route = .custom("creatorStudioAnalytics_\(user.id)")
        case .settings:
            viewModel.showingSettings = true
        case .switchProfile:
            viewModel.showingSwitchProfile = true
        case .editProfile:
            viewModel.showingEditProfile = true
        }
    }

    private func setupContent() {
        // 🎯 FEATURE CARD = 10 ranked slots. FeaturedStore already returns videos
        // sorted by priority (paid Feature Card slots #1–#10 first, then owner pins),
        // so we must NOT reorder here.
        //
        // The Shot By Keonta intro is PERMANENTLY pinned at slot #1 — it is the
        // owner's signature card and always rides at the top of the carousel.
        // The ONLY thing that bumps it is a paid Feature Card booking that owns the
        // #1 slot (the $5K top slot). The moment that paid #1 booking expires and
        // nobody is already booked into #1, the intro automatically reclaims the
        // top spot. Owner pins and lower paid slots (#2–#10) sit BEHIND the intro;
        // they never hide it.
        let totalSlots = FeatureSlotTier.totalSlots // 10
        let intro = FeaturedStore.ownerIntroVideo() ?? shotByKeontaIntro()

        // Rank-ordered featured videos (paid slots first), intro excluded so it
        // isn't double-counted if it happens to also be pinned. Both the current
        // and legacy intro IDs are excluded.
        let introIds: Set<String> = [intro.id, FeaturedStore.ownerIntroVideoId, "shot_by_keonta_intro"]
        let ranked = FeaturedStore.shared.toVideos().filter { !introIds.contains($0.id) }

        // The intro shows at #1 UNLESS a paid booking owns the top slot. When the
        // top slot is paid, that booking leads and the intro is hidden entirely
        // until the slot frees up again.
        let content: [Video]
        if FeaturedStore.shared.isTopSlotPaid {
            content = Array(ranked.prefix(totalSlots))
        } else {
            // Intro is always first; real featured content fills the slots behind it.
            content = Array(([intro] + ranked).prefix(totalSlots))
        }

        viewModel.featuredContent = content
        viewModel.heroVideoIndex = 0
        
        // ⚡ PRE-WARM: Touch the asset cache for every featured video so Firebase Storage
        // starts downloading before the hero card renders — no cold-start lag on autoplay.
        for video in content where !video.videoURL.isEmpty {
            _ = LoopAssetCache.shared.asset(for: video.videoURL)
        }
        
        print("📺 Featured content loaded: \(viewModel.featuredContent.count) videos (max \(totalSlots) slots, top slot paid: \(FeaturedStore.shared.isTopSlotPaid))")
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
        viewModel.isRefreshing = true
        
        // 1. Reload featured content
        setupContent()
        
        // 2. Reload stories
        loadUserStories()
        
        // 3. Reload watch history + collections from Firestore in parallel
        if let userId = appState.currentUser?.id {
            async let historyFetch = HistoryService.shared.fetch(userId: userId, limit: 100)
            async let wlFetch = UserCollectionsFirestoreService.shared.fetchWatchLater(userId: userId)
            async let subsFetch = UserCollectionsFirestoreService.shared.fetchSubscriptions(userId: userId)
            let (history, wl, subs) = await (historyFetch, wlFetch, subsFetch)
            await MainActor.run {
                appState.watchHistory = history
                appState.watchLaterVideos = wl
                appState.subscriptions = subs
            }
        }
        
        // 4. Notify Continue Watching and other sections to refresh
        NotificationCenter.default.post(name: .videoProgressUpdated, object: nil)
        
        viewModel.isRefreshing = false
    }
    
    private func loadUserStories() {
        // Clear existing stories first
        viewModel.assetStories = []
        viewModel.allAssetStories = []
        
        // Don't show stories for unauthenticated users - keep it clean like YouTube
        guard appState.isAuthenticated, let currentUser = appState.currentUser else {
            return
        }
        
        Task { @MainActor in
            print("📖 [HomeView] loadUserStories started for user: \(currentUser.username) (id: \(currentUser.id))")
            try? await StorySeenTracker.shared.fetchSeen(userId: currentUser.id)
            try? await StorySeenTracker.shared.clearExpired(userId: currentUser.id)
            var collected: [AssetStory] = []
            let blockedUserIds = await loadBlockedUserIds(for: currentUser.id)

            // 1. Load current user's own stories
            if let mine = try? await DatabaseService.shared.fetchStoriesByCreator(creatorId: currentUser.id), !mine.isEmpty {
                print("📖 [HomeView] Found \(mine.count) own stories")
                let mapped = mine.map { s -> AssetStory in
                    let media: AssetMedia = (s.mediaType == .video) ? .video(s.mediaURL) : .image(s.mediaURL)
                    return AssetStory(media: media, username: currentUser.username, authorImageName: currentUser.profileImageURL ?? "", creatorId: currentUser.id, originalStoryId: s.id, isCloseFriends: s.isCloseFriends)
                }
                collected.append(contentsOf: mapped)
            } else {
                print("📖 [HomeView] No own stories found")
            }

            // 2. Load stories from followed creators
            if !appState.subscriptions.isEmpty {
                let followed = Array(appState.subscriptions)
                print("📖 [HomeView] Fetching stories from \(followed.count) followed creators")
                if let stories = try? await DatabaseService.shared.fetchActiveStoriesForCreators(followed), !stories.isEmpty {
                    let filtered = stories.filter { shouldIncludeStory($0, currentUserId: currentUser.id, blockedUserIds: blockedUserIds) }
                    let creatorIds = Set(filtered.map { $0.creatorId })
                    let userMap: [String: User] = await withTaskGroup(of: (String, User?).self) { group in
                        for cid in creatorIds {
                            group.addTask { (cid, try? await UserFirestoreService.shared.fetchUser(id: cid)) }
                        }
                        var result: [String: User] = [:]
                        for await (cid, u) in group { result[cid] = u }
                        return result
                    }
                    for s in filtered {
                        let media: AssetMedia = (s.mediaType == .video) ? .video(s.mediaURL) : .image(s.mediaURL)
                        let u = userMap[s.creatorId]
                        collected.append(AssetStory(media: media, username: u?.username ?? s.creatorId, authorImageName: u?.profileImageURL ?? "", creatorId: s.creatorId, originalStoryId: s.id, isCloseFriends: s.isCloseFriends))
                    }
                }
            } else {
                print("📖 [HomeView] No subscriptions — skipping followed stories")
            }

            // 3. If no stories from others, fetch all active stories for discovery
            let hasOtherStories = collected.contains { $0.username.lowercased() != currentUser.username.lowercased() }
            if !hasOtherStories {
                print("📖 [HomeView] No stories from others — fetching all active stories")
                if let allStories = try? await DatabaseService.shared.fetchAllActiveStories(limit: 24), !allStories.isEmpty {
                    print("📖 [HomeView] Got \(allStories.count) stories from fetchAllActiveStories")
                    let filtered = allStories.filter { shouldIncludeStory($0, currentUserId: currentUser.id, blockedUserIds: blockedUserIds) }
                    let creatorIds = Set(filtered.map { $0.creatorId })
                    let userMap: [String: User] = await withTaskGroup(of: (String, User?).self) { group in
                        for cid in creatorIds {
                            group.addTask { (cid, try? await UserFirestoreService.shared.fetchUser(id: cid)) }
                        }
                        var result: [String: User] = [:]
                        for await (cid, u) in group { result[cid] = u }
                        return result
                    }
                    for s in filtered {
                        let media: AssetMedia = (s.mediaType == .video) ? .video(s.mediaURL) : .image(s.mediaURL)
                        let u = userMap[s.creatorId]
                        collected.append(AssetStory(media: media, username: u?.username ?? s.creatorId, authorImageName: u?.profileImageURL ?? "", creatorId: s.creatorId, originalStoryId: s.id, isCloseFriends: s.isCloseFriends))
                    }
                }
            }

            collected = orderedStoriesForTray(collected, currentUserId: currentUser.id)
            // Store ALL stories (multiple per user) for the pager
            self.viewModel.allAssetStories = collected
            // Store one-per-user for the bubble row (most recent first per user)
            self.viewModel.assetStories = uniqueStoriesPerUser(collected)
            print("✅ [HomeView] loadUserStories complete — \(self.viewModel.allAssetStories.count) total stories, \(self.viewModel.assetStories.count) user bubbles")
        }
    }

    /// Returns one representative story per user (first occurrence, which is the most recent)
    private func uniqueStoriesPerUser(_ input: [AssetStory]) -> [AssetStory] {
        var seen = Set<String>()
        var out: [AssetStory] = []
        for s in input {
            let key = s.creatorId.isEmpty ? s.username.lowercased() : s.creatorId
            if seen.insert(key).inserted { out.append(s) }
        }
        return out
    }

    private func orderedStoriesForTray(_ stories: [AssetStory], currentUserId: String) -> [AssetStory] {
        let deduped = dedupeStories(stories)
        let seen = StorySeenTracker.shared.seenStoryIds
        return deduped.sorted { lhs, rhs in
            let lhsOwn = lhs.creatorId == currentUserId
            let rhsOwn = rhs.creatorId == currentUserId
            if lhsOwn != rhsOwn { return lhsOwn }

            let lhsSeen = seen.contains(lhs.stableStoryId)
            let rhsSeen = seen.contains(rhs.stableStoryId)
            if lhsSeen != rhsSeen { return !lhsSeen }

            return lhs.username.localizedCaseInsensitiveCompare(rhs.username) == .orderedAscending
        }
    }

    private func dedupeStories(_ stories: [AssetStory]) -> [AssetStory] {
        var seenIds = Set<String>()
        return stories.filter { story in
            seenIds.insert(story.stableStoryId).inserted
        }
    }

    private func shouldIncludeStory(_ story: Story, currentUserId: String, blockedUserIds: Set<String>) -> Bool {
        guard !story.isExpired else { return false }
        guard !blockedUserIds.contains(story.creatorId) else { return false }

        let audience = (story.audience ?? "public").lowercased()
        if story.creatorId == currentUserId { return true }

        switch audience {
        case "public", "friends":
            return true
        case "close", "closefriends", "close_friends":
            return appState.subscriptions.contains(story.creatorId)
        default:
            return audience.isEmpty || audience == "public"
        }
    }

    private func loadBlockedUserIds(for userId: String) async -> Set<String> {
        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .collection("blockedUsers")
                .getDocuments()
            return Set(snapshot.documents.map { $0.documentID })
        } catch {
            print("⚠️ [HomeView] Failed to load blocked users for stories: \(error.localizedDescription)")
        }
        #endif
        return []
    }
    

    // MARK: - Action Methods
    private func showStoryCreator() {
        viewModel.presentStoryCreator = true
    }

    private func loadWatchHistoryFromFirestore() {
        guard let userId = appState.currentUser?.id else { return }
        guard appState.watchHistory.isEmpty else { return }
        Task {
            let history = await HistoryService.shared.fetch(userId: userId, limit: 100)
            await MainActor.run {
                appState.watchHistory = history
                print("📺 [HomeView] Loaded \(history.count) watch history items from Firestore")
            }
        }
    }

    private func toggleWatchLater(_ video: Video) {
        appState.toggleWatchLater(for: video.id)
        HapticManager.shared.impact(style: .light)
    }

    private func openVideo(_ video: Video) {
        viewModel.route = .video(video)
    }

    // 🔥 YOUTUBE PARITY: Handle Home chip filter taps
    private func handleHomeChipTap(_ chip: HomeFilterChip) {
        switch chip {
        case .all:
            break // Default home view, no navigation
        case .music:
            viewModel.route = .custom("musicHub")
        case .live:
            viewModel.route = .allLiveTV
        case .gaming:
            viewModel.route = .custom("exploreHub")
        case .news, .mixes, .podcasts, .newToYou:
            viewModel.route = .trending // Surface curated content for now
        case .recentlyUploaded:
            viewModel.route = .trending
        case .watched:
            NotificationCenter.default.post(name: .openFullHistory, object: nil)
        }
    }

    // MARK: - ULTRA-THERMONUCLEAR FAB 🔥💥😤
    private var thermonuclearFAB: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button {
                    HapticManager.shared.impact(style: .heavy)
                    viewModel.showingFeaturedManager = true
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






// ⚡ All section/card components extracted to HomeViewComponents.swift
