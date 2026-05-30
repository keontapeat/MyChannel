import SwiftUI
import Combine

// MARK: - Minimal Content Sections
struct MinimalContentSections: View {
    let onPlayVideo: (Video) -> Void
    let onSelectMovie: (FreeMovie) -> Void
    let onSeeAllFreeMovies: ([FreeMovie]) -> Void
    let onSeeAllLiveTV: () -> Void
    let onSeeAllTrending: () -> Void
    let onSeeAllMusic: () -> Void
    let onSeeAllExplore: () -> Void
    let onSeeAllArtists: () -> Void
    let onSeeAllFilmmakers: () -> Void
    let onSeeAllChannels: () -> Void
    let onOpenArtistDetail: (String, String, [Video], Int) -> Void
    let onOpenArtistMusicProfile: (CatalogArtist) -> Void
    let onOpenFilmmakerDetail: (String, [FreeMovie]) -> Void
    let onOpenChannelDetail: (String, String, Int, Int, [Video]) -> Void
    var onSelectLiveStream: ((FirestoreLiveStream) -> Void)? = nil

    @EnvironmentObject private var appState: AppState
    @ObservedObject private var rankService = TopRankMLService.shared
    @State private var blockbusterMovies: [FreeMovie] = []
    @State private var loadingBlockbusters: Bool = false
    @State private var friendChannelVideos: [Video] = []
    @State private var liveChannelsAPI: [LiveTVChannel] = []
    @State private var showLocalArtistsOnly: Bool = false
    @State private var selectedLiveTVChannel: LiveTVChannel?
    @State private var firestoreVideos: [Video] = []

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

    @ViewBuilder private var topSections: some View {
        LiveNowSection { stream in
            onSelectLiveStream?(stream)
        }
        .onAppear {
            LiveStreamManager.shared.startListening()
        }

        ForYouSection(onPlayVideo: onPlayVideo, onSeeAllExplore: onSeeAllExplore)

        if appState.isAuthenticated {
            ContinueWatchingSection(onVideoTap: { video in
                onPlayVideo(video)
            })
        }

        MinimalSection(title: "Trending Now", seeAllAction: { onSeeAllTrending() }) {
            TopTenCarousel(
                videos: trendingVideos(),
                preserveOrder: true,
                onPlay: { v in onPlayVideo(v) }
            )
            .padding(.top, 4)
        }

        MinimalMusicSection(
            onOpenArtistMusicProfile: onOpenArtistMusicProfile,
            appState: _appState,
            onSeeAll: { onSeeAllMusic() }
        )
    }

    @ViewBuilder private var bottomSections: some View {
        MinimalCategoriesSection(
            onPlayVideo: onPlayVideo,
            codVideos: gamingCOD(),
            musicVideos: detroitFlintArtistsTrending(),
            allVideos: categoriesAllVideos()
        )

        AILiveTVSection(
            onSelectChannel: { channel in selectedLiveTVChannel = channel },
            onSeeAll: { onSeeAllLiveTV() }
        )

        QuickTuneSection(liveChannelsAPI: liveChannelsAPI)

        MinimalSection(title: "Movies", seeAllAction: { onSeeAllFreeMovies(homeBlockbusterMovies) }) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(Array(homeBlockbusterMovies.prefix(18))) { movie in
                        MinimalMovieCard(movie: movie, action: { onSelectMovie(movie) })
                    }
                }
                .padding(.horizontal, 20)
            }
        }

        TopArtistsSection(
            rankings: rankService.topArtists.isEmpty ? TopRankMLService.fallbackTopArtists : rankService.topArtists,
            sourceVideos: detroitFlintArtistsTrending() + [makeFriendTrendingVideo()] + firestoreVideos,
            onSelect: { name, avatar, vids, total in onOpenArtistDetail(name, avatar, vids, total) },
            onSeeAll: onSeeAllArtists
        )

        TopIndieFilmmakersSection(
            rankings: rankService.topFilmmakers.isEmpty ? TopRankMLService.fallbackTopFilmmakers : rankService.topFilmmakers,
            onSeeAll: onSeeAllFilmmakers,
            onSelect: { name, films in onOpenFilmmakerDetail(name, films) }
        )

        TopMyChannelsSection(
            rankings: rankService.topChannels.isEmpty ? TopRankMLService.fallbackTopChannels : rankService.topChannels,
            sourceVideos: detroitFlintArtistsTrending() + gamingCOD() + firestoreVideos,
            onSelect: { name, avatar, subs, total, vids in onOpenChannelDetail(name, avatar, subs, total, vids) },
            onSeeAll: onSeeAllChannels
        )
    }

    private func trendingVideos() -> [Video] {
        let base = friendChannelVideos.isEmpty ? [] : friendChannelVideos
        let pinnedIDs = ["JSXmfgZzHqQ", "xfdydb_3Ra0", "96Zeze6gdEI", "l1gQVUGdMyw", "71GJrAY54Ew"]
        let pinnedVideos: [Video] = pinnedIDs.compactMap { id in
            extraTrendingVideos().first(where: { $0.externalID == id }) ??
            detroitFlintArtistsTrending().first(where: { $0.externalID == id })
        }
        let merged = pinnedVideos + [makeFriendTrendingVideo()] + extraTrendingVideos() + flintShowcaseVideos() + base
        var seen = Set<String>()
        return merged.filter { v in
            if seen.contains(v.id) { return false }
            seen.insert(v.id)
            return true
        }
    }

    private func categoriesAllVideos() -> [Video] {
        var vids = flintShowcaseVideos() + detroitFlintArtistsTrending() + gamingCOD() + firestoreVideos + SeedCatalogService.shared.seedVideos
        vids.insert(makeFriendTrendingVideo(), at: 0)
        return vids
    }

    private var homeBlockbusterMovies: [FreeMovie] {
        let merged = blockbusterMovies + FreeMovie.sampleMovies.sorted { lhs, rhs in
            if lhs.year != rhs.year { return lhs.year > rhs.year }
            return lhs.imdbRating > rhs.imdbRating
        }
        var seen = Set<String>()
        return merged.filter { movie in
            let key = "\(movie.id)|\(movie.title.lowercased())"
            guard movie.isAvailable, !movie.streamURL.isEmpty, !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    var body: some View {
        VStack(spacing: 40) {
            topSections
            bottomSections
        }
        // Native PiP doesn't affect layout, so no need to disable animations
        .task {
            // ⚡ PERFORMANCE FIX: Load all in parallel instead of sequentially
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await loadBlockbusters() }
                group.addTask { await loadFriendChannelVideos() }
                group.addTask { await loadLiveChannelsAPI() }
                group.addTask {
                    let vids = await VideoFirestoreService.shared.fetchAllPublicVideos(limit: 50)
                    await MainActor.run { firestoreVideos = vids }
                }
            }
            // Start real-time ML-powered rankings
            rankService.startRealTimeRanking()
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

            async let trailersPage1 = TMDBService.shared.fetchPopularWithTrailersUS(page: 1, limit: 30)
            async let trailersPage2 = TMDBService.shared.fetchPopularWithTrailersUS(page: 2, limit: 30)
            async let freePage1 = TMDBService.shared.fetchFreeWithAdsMoviesUS(page: 1, limit: 30)
            async let freePage2 = TMDBService.shared.fetchFreeWithAdsMoviesUS(page: 2, limit: 30)
            let items = try await trailersPage1 + trailersPage2 + freePage1 + freePage2
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

            var seen = Set<String>()
            let boosted = chosen.filter { movie in
                let key = "\(movie.id)|\(movie.title.lowercased())"
                guard movie.isAvailable, !movie.streamURL.isEmpty, !seen.contains(key) else { return false }
                seen.insert(key)
                return true
            }.sorted { lhs, rhs in
                let boost: (FreeMovie) -> Int = { m in
                    let t = m.title.lowercased()
                    return (t.contains("smile 2") || t.contains("sinners") || t.contains("sonic") || t.contains("venom") || t.contains("deadpool") || t.contains("wick") || t.contains("spider") || t.contains("batman")) ? 1 : 0
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
