import SwiftUI
import AVKit
import AVFoundation
import FirebaseFirestore

@MainActor
class NuclearFlicksViewModel: ObservableObject {
    
    @Injected private var agentService: AgentAPIService
    @Injected private var firestoreService: VideoFirestoreService
    @Injected private var seedCatalog: SeedCatalogService
    
    // 🔥 STRONGER: App-wide warmup on launch
    static func warmupOnLaunch() {
        Task { @MainActor in
            print("🔥 [NuclearFlicks] App-wide warmup started")
            let viewModel = NuclearFlicksViewModel()
            await viewModel.loadInitialFlicks()
            // Pre-warm player pool
            _ = PlayerPoolManager.shared.getPoolStats()
            print("✅ [NuclearFlicks] App-wide warmup complete")
        }
    }
    @Published var flicks: [NuclearFlick] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?
    
    @Published var likedFlickIds: Set<String> = []
    @Published var followedCreatorIds: Set<String> = []
    @Published var savedFlickIds: Set<String> = []
    
    @Published var commentsFlick: NuclearFlick?
    @Published var shareFlick: NuclearFlick?
    @Published var selectedCreatorProfile: User?
    
    @Published var albumArtRotation: Double = 0
    
    private var lastDocument: DocumentSnapshot?
    private var preloadedIndices: Set<Int> = []
    private var rotationTimer: Timer?
    private var recommendationsEnabled = false
    private var servedRecommendationIDs: Set<String> = []
    private var validatedURLs: Set<String> = []
    private var invalidURLs: Set<String> = []
    private let blacklistKey = "NuclearFlicks_DeadURLBlacklist"
    private var persistentBlacklist: Set<String> {
        get { UserDefaults.standard.stringArray(forKey: blacklistKey).map { Set($0) } ?? [] }
        set { UserDefaults.standard.set(Array(newValue), forKey: blacklistKey) }
    }
    
    init() {
        startAlbumArtRotation()
        // Load persistent blacklist on init
        invalidURLs = persistentBlacklist
        // Seed per-user state from the app's persisted collections so likes,
        // follows, and saves survive relaunch and sync across devices instead of
        // resetting to empty every time Flicks opens.
        likedFlickIds = AppState.shared.likedVideos
        followedCreatorIds = AppState.shared.subscriptions
        savedFlickIds = AppState.shared.watchLaterVideos
    }
    
    deinit {
        rotationTimer?.invalidate()
    }
    
    // MARK: - Data Loading
    
    func loadInitialFlicks() async {
        isLoading = true
        error = nil
        recommendationsEnabled = false
        servedRecommendationIDs.removeAll()
        defer { isLoading = false }
        
        if await loadRecommendedFeedIfAvailable(limit: 20) {
            print("✅ [NuclearFlicks] Loaded Vertex AI recommendations")
            preloadVideos(around: 0, count: 1)  // visible+1 — docs/launch-perf-flicks.md
            return
        }
        
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            
            // Try flicks collection first
            let query = db.collection("flicks")
                .order(by: "createdAt", descending: true)
                .limit(to: 20)
            
            let snapshot = try await query.getDocuments()
            
            var mainVideoBackfill = await loadPublicVideoFlicks(limit: 60)

            // 🔄 MIGRATION FALLBACK: pull any flicks still living in the legacy
            // "shorts" collection so pre-rename content isn't stranded.
            if snapshot.documents.isEmpty {
                let legacy = await loadLegacyShortsFlicks(limit: 20)
                if !legacy.isEmpty {
                    mainVideoBackfill = mergePlayableFlicks(primary: legacy, fallback: mainVideoBackfill, minimumCount: legacy.count + mainVideoBackfill.count)
                }
            }
            
            if !snapshot.documents.isEmpty {
                lastDocument = snapshot.documents.last
                var parsed = snapshot.documents.compactMap { doc in
                    parseFlickFromDocument(doc)
                }
                parsed = await validateFlicks(parsed)
                parsed = mergePlayableFlicks(primary: parsed, fallback: mainVideoBackfill, minimumCount: 20)
                if parsed.count < 10 {
                    let demoBackfill = makeDemoFlicks()
                    parsed = mergePlayableFlicks(primary: parsed, fallback: demoBackfill, minimumCount: 20)
                    print("📺 [NuclearFlicks] Supplemented Flicks with playable catalog content")
                }
                flicks = parsed
                print("✅ [NuclearFlicks] Loaded \(flicks.count) playable Flicks")
                preloadVideos(around: 0, count: 1)  // visible+1 — docs/launch-perf-flicks.md
            } else if !mainVideoBackfill.isEmpty {
                flicks = mergePlayableFlicks(primary: mainVideoBackfill, fallback: makeDemoFlicks(), minimumCount: 20)
                print("✅ [NuclearFlicks] Loaded \(flicks.count) playable videos from public videos")
                preloadVideos(around: 0, count: 1)  // visible+1 — docs/launch-perf-flicks.md
            } else {
                // Silently fallback to demo data (no error - this is expected when starting)
                flicks = makeDemoFlicks()
                print("📺 [NuclearFlicks] No Flicks in Firestore yet. Showing \(flicks.count) demo Flicks.")
                preloadVideos(around: 0, count: 1)  // visible+1 — docs/launch-perf-flicks.md
            }
        } catch {
            // Only show error for actual failures (network issues, permissions, etc.)
            print("🚨 [NuclearFlicks] Error loading from Firestore: \(error.localizedDescription)")
            
            // Don't show error to user - just fallback gracefully to demo content
            flicks = makeDemoFlicks()
            print("📺 [NuclearFlicks] Fallback to \(flicks.count) demo Flicks due to error")
        }
        #else
        flicks = makeDemoFlicks()
        print("📺 [NuclearFlicks] Firebase not available. Showing \(flicks.count) demo Flicks.")
        #endif
    }
    
    private func loadRecommendedFeedIfAvailable(limit: Int) async -> Bool {
        guard let userId = AppState.shared.currentUser?.id else { return false }
        do {
            let sessionHistory = Array(AppState.shared.watchHistory.prefix(25).map { $0.contentId })
            let ids = try await agentService.getRecommendations(
                userId: userId,
                sessionHistory: sessionHistory,
                limit: limit
            )
            let freshIds = ids.filter { !servedRecommendationIDs.contains($0) }
            let flickResults = await fetchFlicks(for: freshIds)
            guard !flickResults.isEmpty else { return false }
            flicks = flickResults
            servedRecommendationIDs.formUnion(flickResults.map { $0.id })
            recommendationsEnabled = true
            lastDocument = nil
            return true
        } catch {
            print("⚠️ [NuclearFlicks] Recommendation load failed: \(error)")
            return false
        }
    }

    func loadMoreFlicks() async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        if recommendationsEnabled {
            let appended = await appendAdditionalRecommendations(limit: 10)
            if appended { return }
        }
        
        #if canImport(FirebaseFirestore)
        guard let lastDoc = lastDocument else { return }
        
        do {
            let db = Firestore.firestore()
            let query = db.collection("flicks")
                .order(by: "createdAt", descending: true)
                .start(afterDocument: lastDoc)
                .limit(to: 10)
            
            let snapshot = try await query.getDocuments()
            
            if !snapshot.documents.isEmpty {
                let newCursor = snapshot.documents.last
                if newCursor?.documentID == lastDocument?.documentID {
                    print("⚠️ [NuclearFlicks] Pagination cursor unchanged — skipping duplicate page")
                    return
                }
                lastDocument = newCursor
                var newFlicks = snapshot.documents.compactMap { doc in
                    parseFlickFromDocument(doc)
                }
                newFlicks = await validateFlicks(newFlicks)
                flicks = mergePlayableFlicks(primary: flicks, fallback: newFlicks, minimumCount: flicks.count + newFlicks.count)
            } else {
                let publicVideos = await loadPublicVideoFlicks(limit: 20)
                flicks = mergePlayableFlicks(primary: flicks, fallback: publicVideos, minimumCount: flicks.count + min(publicVideos.count, 10))
            }
        } catch {
            print("🚨 [NuclearFlicks] Error loading more: \(error)")
        }
        #endif
    }
    
    // MARK: - Actions
    
    func toggleLike(flick: NuclearFlick) {
        let baseId = flick.id.components(separatedBy: "_loop_").first ?? flick.id
        let wasLiked = likedFlickIds.contains(baseId)
        if wasLiked {
            likedFlickIds.remove(baseId)
            AppState.shared.likedVideos.remove(baseId)
        } else {
            likedFlickIds.insert(baseId)
            AppState.shared.likedVideos.insert(baseId)
        }
        Task { [weak self] in
            let ok = await self?.recordFlickEvent(flickId: baseId, type: wasLiked ? "unlike" : "like") ?? false
            guard let self, !ok else { return }
            // Roll back optimistic UI on network failure
            if wasLiked {
                self.likedFlickIds.insert(baseId)
                AppState.shared.likedVideos.insert(baseId)
            } else {
                self.likedFlickIds.remove(baseId)
                AppState.shared.likedVideos.remove(baseId)
            }
        }
    }
    
    func isLiked(flickId: String) -> Bool {
        let baseId = flickId.components(separatedBy: "_loop_").first ?? flickId
        return likedFlickIds.contains(baseId)
    }
    
    func toggleFollow(creator: FlickCreator) {
        // Route through AppState so the follow persists to
        // users/{uid}/subscriptions and drives the rest of the app's feeds.
        AppState.shared.toggleSubscription(for: creator.id)
        followedCreatorIds = AppState.shared.subscriptions
    }
    
    func isFollowing(creatorId: String) -> Bool {
        followedCreatorIds.contains(creatorId)
    }

    func toggleSave(flick: NuclearFlick) {
        let baseId = flick.id.components(separatedBy: "_loop_").first ?? flick.id
        let wasSaved = savedFlickIds.contains(baseId)
        AppState.shared.toggleWatchLater(for: baseId)
        savedFlickIds = AppState.shared.watchLaterVideos
        Task { [weak self] in
            let ok = await self?.recordFlickEvent(flickId: baseId, type: wasSaved ? "unsave" : "save") ?? false
            guard let self, !ok else { return }
            // Roll back optimistic save on failure
            AppState.shared.toggleWatchLater(for: baseId)
            self.savedFlickIds = AppState.shared.watchLaterVideos
        }
    }

    func isSaved(flickId: String) -> Bool {
        let baseId = flickId.components(separatedBy: "_loop_").first ?? flickId
        return savedFlickIds.contains(baseId)
    }
    
    func openComments(flick: NuclearFlick) {
        commentsFlick = flick
    }
    
    func openShare(flick: NuclearFlick) {
        shareFlick = flick
    }
    
    func removeUnavailableFlick(id: String) {
        let baseId = id.components(separatedBy: "_loop_").first ?? id
        flicks.removeAll { flick in
            flick.id == id || flick.id == baseId || flick.id.hasPrefix("\(baseId)_loop_")
        }
        if flicks.count < 8 {
            let backfill = mergePlayableFlicks(primary: flicks, fallback: makeDemoFlicks(), minimumCount: 20)
            flicks = backfill
        }
    }
    
    func navigateToCreator(_ creator: FlickCreator) {
        // Convert FlickCreator to User and navigate to profile
        let user = User(
            id: creator.id,
            username: creator.username,
            displayName: creator.displayName,
            email: "",
            profileImageURL: creator.profileImageURL,
            isVerified: creator.isVerified
        )
        selectedCreatorProfile = user
    }
    
    // MARK: - Preloading
    
    /// Preload video assets for the focused item and up to `count` items ahead.
    /// Default `count: 1` = visible+1 (current + next only). See docs/launch-perf-flicks.md.
    func preloadVideos(around index: Int, count: Int = 1) {
        guard let range = FeedMath.preloadRange(
            around: index,
            before: 0,
            after: max(0, count),
            total: flicks.count
        ) else { return }
        
        for i in range {
            if !preloadedIndices.contains(i) {
                preloadedIndices.insert(i)
                Task {
                    await preloadVideo(at: i)
                }
            }
        }
    }
    
    private func preloadVideo(at index: Int) async {
        guard index < flicks.count else { return }
        let flick = flicks[index]
        guard isPlayableFlick(flick) else { return }
        
        if flick.contentSource != Video.ContentSource.youtube {
            VideoPlayerManager.prewarm(urlString: flick.videoURL)
            PlayerPoolManager.shared.preloadAsset(for: flick.videoURL)
            
            // 🔥 Phase 3: Intelligent Actor-based Video Prefetching
            Task {
                await AVPlayerItemPrefetcher.shared.prefetch(urls: [flick.videoURL])
            }
            
            if let thumbURL = URL(string: flick.thumbnailURL) {
                ImagePrefetcher.shared.prefetch(url: thumbURL)
            }
            let alive = await isURLAlive(flick.videoURL)
            if !alive {
                removeUnavailableFlick(id: flick.id)
            }
        }
    }
    
    // MARK: - Analytics
    
    func trackView(flick: NuclearFlick) async {
        // 🔒 Engagement is recorded as a userId-stamped event; the
        // onFlickEngagementEvent Cloud Function aggregates it into the
        // server-authoritative viewCount. Clients no longer increment counters
        // directly, which closes the spoofing/inflation hole.
        await recordFlickEvent(flickId: flick.id, type: "view")

        // Track with RealtimeViewTracker
        if let userId = AppState.shared.currentUser?.id {
            await RealtimeViewTracker.shared.startViewSession(videoId: flick.id, userId: userId)
        }
    }
    
    func trackWatchTime(flickId: String, duration: TimeInterval) async {
        guard duration > 0 else { return }
        // Watch time flows through the same event pipeline (no more writes to a
        // shared, world-writable analytics/watch_time doc).
        await recordFlickEvent(flickId: flickId, type: "watch_time", extra: [
            "watchTime": Int(duration.rounded())
        ])
    }

    /// 🔒 Records a userId-stamped engagement event in the flick's /events
    /// subcollection. The onFlickEngagementEvent Cloud Function aggregates these
    /// into server-authoritative counters, so clients never write counts directly.
    @discardableResult
    private func recordFlickEvent(flickId: String, type: String, extra: [String: Any] = [:]) async -> Bool {
        #if canImport(FirebaseFirestore)
        guard let userId = AppState.shared.currentUser?.id else { return true }
        // Duplicate/looped feed entries share one backing doc — strip the suffix.
        let baseId = flickId.components(separatedBy: "_loop_").first ?? flickId
        var payload: [String: Any] = [
            "userId": userId,
            "type": type,
            "createdAt": FieldValue.serverTimestamp()
        ]
        payload.merge(extra) { _, new in new }
        do {
            _ = try await Firestore.firestore()
                .collection("flicks").document(baseId)
                .collection("events").addDocument(data: payload)
            return true
        } catch {
            print("🚨 [NuclearFlicks] Failed to record \(type) event: \(error.localizedDescription)")
            return false
        }
        #else
        return true
        #endif
    }
    
    // MARK: - Album Art Rotation
    
    func startAlbumArtRotation() {
        guard rotationTimer == nil else { return }
        // 30fps is visually smooth for a small spinning disc and halves wakeups.
        rotationTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.albumArtRotation += 2
                if self.albumArtRotation >= 360 {
                    self.albumArtRotation -= 360
                }
            }
        }
    }

    func stopAlbumArtRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
    }
    
    // MARK: - Helpers
    
    private func parseFlickFromDocument(_ doc: DocumentSnapshot) -> NuclearFlick? {
        let data = doc.data() ?? [:]
        
        guard let title = data["title"] as? String,
              let videoURL = data["videoUrl"] as? String ?? data["videoURL"] as? String ?? data["downloadURL"] as? String ?? data["downloadUrl"] as? String else {
            return nil
        }
        
        let creator = FlickCreator(
            id: data["creatorId"] as? String ?? "unknown",
            username: data["creatorUsername"] as? String ?? "creator",
            displayName: data["creatorDisplayName"] as? String ?? "Creator",
            profileImageURL: data["creatorProfileImage"] as? String ?? "",
            isVerified: data["creatorIsVerified"] as? Bool ?? false
        )
        
        var musicTrack: FlickMusicTrack?
        if let musicData = data["musicTrack"] as? [String: Any],
           let musicTitle = musicData["title"] as? String,
           let musicArtist = musicData["artist"] as? String,
           let albumArt = musicData["albumArt"] as? String {
            musicTrack = FlickMusicTrack(title: musicTitle, artist: musicArtist, albumArt: albumArt)
        }
        
        let flick = NuclearFlick(
            id: doc.documentID,
            videoURL: videoURL,
            thumbnailURL: data["thumbnailUrl"] as? String ?? data["thumbnailURL"] as? String ?? "",
            title: title,
            description: data["description"] as? String ?? "",
            duration: data["duration"] as? TimeInterval ?? 30,
            viewCount: data["viewCount"] as? Int ?? 0,
            likeCount: data["likeCount"] as? Int ?? 0,
            commentCount: data["commentCount"] as? Int ?? 0,
            shareCount: data["shareCount"] as? Int ?? 0,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            creator: creator,
            tags: data["tags"] as? [String] ?? [],
            musicTrack: musicTrack,
            contentSource: (data["contentSource"] as? String).flatMap { Video.ContentSource(rawValue: $0) } ?? Video.ContentSource.userUploaded,
            externalID: data["externalID"] as? String
        )
        
        guard isPlayableFlick(flick) else { return nil }
        return flick
    }
    
    private func makeDemoFlicks() -> [NuclearFlick] {
        let freeVideos = seedCatalog.freeCatalogVideos
        let seedVideos = seedCatalog.seedVideos
        let combined = (freeVideos + seedVideos)
            .filter { isPlayableVideo($0) && isKnownReliableURLString($0.videoURL) }
            .shuffled()
        if !combined.isEmpty {
            return combined.prefix(60).map { video in
                videoToFlick(video)
            }
        }
        let demoCreator = FlickCreator(
            id: "demo1",
            username: "demo_creator",
            displayName: "Demo Creator",
            profileImageURL: "https://i.pravatar.cc/200?u=demo_creator",
            isVerified: true
        )
        return (1...10).map { i in
            NuclearFlick(
                id: "demo_\(i)",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
                thumbnailURL: "https://picsum.photos/seed/flick\(i)/1080/1920",
                title: "Amazing Flick #\(i) 🔥",
                description: "This is an amazing short video! Check it out!",
                duration: 30,
                viewCount: Int.random(in: 10_000...1_000_000),
                likeCount: Int.random(in: 1_000...100_000),
                commentCount: Int.random(in: 100...10_000),
                shareCount: Int.random(in: 50...5_000),
                createdAt: Date(),
                creator: demoCreator,
                tags: ["trending", "viral", "fyp"],
                musicTrack: FlickMusicTrack(
                    title: "Original Audio",
                    artist: "Demo Creator",
                    albumArt: "https://picsum.photos/seed/music\(i)/300/300"
                ),
                contentSource: Video.ContentSource.userUploaded,
                externalID: nil as String?
            )
        }
    }

    private func fetchFlicks(for videoIds: [String]) async -> [NuclearFlick] {
        guard !videoIds.isEmpty else { return [] }
        do {
            let videos = try await firestoreService.fetchMultipleVideos(videoIds: videoIds)
            guard !videos.isEmpty else { return [] }
            // Filter out videos with empty/invalid URLs (e.g. deleted videos)
            let validVideos = videos.filter { isPlayableVideo($0) }
            let flickMap = Dictionary(validVideos.map { ($0.id, videoToFlick($0)) }, uniquingKeysWith: { _, last in last })
            return videoIds.compactMap { flickMap[$0] }
        } catch {
            print("⚠️ [NuclearFlicks] Failed to hydrate recommended IDs: \(error)")
            return []
        }
    }
    
    private func appendAdditionalRecommendations(limit: Int) async -> Bool {
        guard let userId = AppState.shared.currentUser?.id else { return false }
        do {
            let sessionHistory = Array(AppState.shared.watchHistory.prefix(30).map { $0.contentId })
            let ids = try await AgentAPIService.shared.getRecommendations(
                userId: userId,
                sessionHistory: sessionHistory,
                limit: limit
            )
            let newIds = ids.filter { !servedRecommendationIDs.contains($0) }
            let flickResults = await fetchFlicks(for: newIds)
            guard !flickResults.isEmpty else { return false }
            flicks.append(contentsOf: flickResults)
            servedRecommendationIDs.formUnion(flickResults.map { $0.id })
            return true
        } catch {
            print("⚠️ [NuclearFlicks] Failed to append recommendations: \(error)")
            return false
        }
    }
    
    private func loadPublicVideoFlicks(limit: Int) async -> [NuclearFlick] {
        let videos = await VideoFirestoreService.shared.fetchAllPublicVideos(limit: limit)
        return videos
            .filter { isPlayableVideo($0) }
            .map { videoToFlick($0) }
    }

    /// 🔄 MIGRATION FALLBACK: reads the legacy "shorts" collection (pre-rename)
    /// so existing content keeps showing until it's migrated into "flicks".
    /// Safe to remove once a server-side migration copies shorts/* → flicks/*.
    private func loadLegacyShortsFlicks(limit: Int) async -> [NuclearFlick] {
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("shorts")
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            let parsed = snapshot.documents.compactMap { parseFlickFromDocument($0) }
            guard !parsed.isEmpty else { return [] }
            let validated = await validateFlicks(parsed)
            if !validated.isEmpty {
                print("🔄 [NuclearFlicks] Loaded \(validated.count) flicks from legacy 'shorts' collection")
            }
            return validated
        } catch {
            print("⚠️ [NuclearFlicks] Legacy shorts fallback failed: \(error.localizedDescription)")
            return []
        }
        #else
        return []
        #endif
    }
    
    private func mergePlayableFlicks(primary: [NuclearFlick], fallback: [NuclearFlick], minimumCount: Int) -> [NuclearFlick] {
        var seen = Set<String>()
        var merged: [NuclearFlick] = []
        
        for flick in primary + fallback {
            guard isPlayableFlick(flick), !seen.contains(flick.id) else { continue }
            seen.insert(flick.id)
            merged.append(flick)
        }
        
        if merged.count < minimumCount {
            let reusableFallback = fallback.filter { isPlayableFlick($0) }
            while merged.count < minimumCount, !reusableFallback.isEmpty {
                for original in reusableFallback {
                    guard merged.count < minimumCount else { break }
                    let copy = NuclearFlick(
                        id: "\(original.id)_loop_\(merged.count)",
                        videoURL: original.videoURL,
                        thumbnailURL: original.thumbnailURL,
                        title: original.title,
                        description: original.description,
                        duration: original.duration,
                        viewCount: original.viewCount,
                        likeCount: original.likeCount,
                        commentCount: original.commentCount,
                        shareCount: original.shareCount,
                        createdAt: original.createdAt,
                        creator: original.creator,
                        tags: original.tags,
                        musicTrack: original.musicTrack,
                        contentSource: original.contentSource,
                        externalID: original.externalID
                    )
                    merged.append(copy)
                }
            }
        }
        
        return merged
    }
    
    // MARK: - URL Reachability Validation

    /// Checks if a video URL actually resolves (live file, not 404/deleted).
    /// Skips known-reliable hosts and uses a session-level cache so each URL is checked at most once.
    private func isURLAlive(_ urlString: String) async -> Bool {
        if isKnownReliableURLString(urlString) { return true }
        if validatedURLs.contains(urlString) { return true }
        if invalidURLs.contains(urlString) { return false }
        guard let url = URL(string: urlString) else {
            invalidURLs.insert(urlString)
            persistentBlacklist = invalidURLs
            return false
        }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 2.0  // 🔥 FASTER FAIL: 2s instead of 3s
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let alive = (response as? HTTPURLResponse).map { $0.statusCode < 400 } ?? true
            if alive { validatedURLs.insert(urlString) } else { 
                invalidURLs.insert(urlString)
                persistentBlacklist = invalidURLs
            }
            return alive
        } catch {
            invalidURLs.insert(urlString)
            persistentBlacklist = invalidURLs
            return false
        }
    }

    /// Validates a batch of flicks concurrently via HEAD requests.
    /// Filters out any with dead/unreachable URLs before they reach the feed.
    /// Known-reliable URLs and YouTube flicks are passed through without a network round-trip.
    private func validateFlicks(_ flicks: [NuclearFlick]) async -> [NuclearFlick] {
        guard !flicks.isEmpty else { return [] }
        let currentValidated = validatedURLs
        let currentInvalid = invalidURLs
        let results: [(index: Int, alive: Bool)] = await withTaskGroup(of: (index: Int, alive: Bool).self) { group in
            for (i, flick) in flicks.enumerated() {
                let urlString = flick.videoURL
                let thumbURL = flick.thumbnailURL
                let isYT = flick.contentSource == .youtube
                let isReliable = isKnownReliableURLString(urlString)
                let inValid = currentValidated.contains(urlString)
                let inInvalid = currentInvalid.contains(urlString)
                group.addTask {
                    if isYT || isReliable || inValid { return (index: i, alive: true) }
                    if inInvalid { return (index: i, alive: false) }
                    guard let url = URL(string: urlString) else { return (index: i, alive: false) }
                    var request = URLRequest(url: url)
                    request.httpMethod = "HEAD"
                    request.timeoutInterval = 2.0  // 🔥 FASTER FAIL
                    request.cachePolicy = .reloadIgnoringLocalCacheData
                    do {
                        let (_, response) = try await URLSession.shared.data(for: request)
                        let videoAlive = (response as? HTTPURLResponse).map { $0.statusCode < 400 } ?? true
                        // 🔥 ALSO VALIDATE THUMBNAIL
                        var thumbAlive = true
                        if let thumb = URL(string: thumbURL), !thumbURL.isEmpty {
                            var thumbReq = URLRequest(url: thumb)
                            thumbReq.httpMethod = "HEAD"
                            thumbReq.timeoutInterval = 2.0
                            thumbReq.cachePolicy = .reloadIgnoringLocalCacheData
                            let (_, thumbResp) = try await URLSession.shared.data(for: thumbReq)
                            thumbAlive = (thumbResp as? HTTPURLResponse).map { $0.statusCode < 400 } ?? true
                        }
                        return (index: i, alive: videoAlive && thumbAlive)
                    } catch {
                        return (index: i, alive: false)
                    }
                }
            }
            var collected: [(index: Int, alive: Bool)] = []
            for await result in group { collected.append(result) }
            return collected
        }
        var valid: [NuclearFlick] = []
        for result in results.sorted(by: { $0.index < $1.index }) {
            if result.alive {
                validatedURLs.insert(flicks[result.index].videoURL)
                valid.append(flicks[result.index])
            } else {
                invalidURLs.insert(flicks[result.index].videoURL)
                persistentBlacklist = invalidURLs
                print("🚫 [NuclearFlicks] Filtered dead URL: \(flicks[result.index].videoURL.prefix(80))")
            }
        }
        return valid
    }

    private func isPlayableVideo(_ video: Video) -> Bool {
        if video.contentSource == .youtube {
            return !(video.externalID ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if video.isLiveStream { return false }
        if video.duration <= 0 { return false }
        return isPlayableURLString(video.videoURL)
    }
    
    private func isPlayableFlick(_ flick: NuclearFlick) -> Bool {
        if flick.contentSource == .youtube {
            return !(flick.externalID ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if flick.duration <= 0 { return false }
        if flick.thumbnailURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        return isPlayableURLString(flick.videoURL)
    }
    
    private func isPlayableURLString(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "https" || scheme == "http" || scheme == "file"
    }
    
    private func isKnownReliableURLString(_ value: String) -> Bool {
        let lowercased = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isPlayableURLString(lowercased) else { return false }
        return lowercased.contains("firebasestorage.googleapis.com")
            || lowercased.contains("storage.googleapis.com")
            || lowercased.contains("commondatastorage.googleapis.com")
            || lowercased.hasSuffix(".mp4")
            || lowercased.hasSuffix(".m3u8")
            || lowercased.hasPrefix("file://")
    }

    private func videoToFlick(_ video: Video) -> NuclearFlick {
        let creator = FlickCreator(
            id: video.creator.id,
            username: video.creator.username,
            displayName: video.creator.displayName,
            profileImageURL: video.creator.profileImageURL ?? "https://i.pravatar.cc/200?u=\(video.id)",
            isVerified: video.creator.isVerified
        )
        return NuclearFlick(
            id: video.id,
            videoURL: video.videoURL,
            thumbnailURL: video.thumbnailURL,
            title: video.title,
            description: video.description,
            duration: video.duration,
            viewCount: video.viewCount,
            likeCount: video.likeCount,
            commentCount: video.commentCount,
            shareCount: max(1, video.viewCount / 1000),
            createdAt: video.createdAt,
            creator: creator,
            tags: video.tags.isEmpty ? ["free", "watch"] : video.tags,
            musicTrack: FlickMusicTrack(
                title: "Original Audio",
                artist: video.creator.displayName,
                albumArt: video.creator.profileImageURL ?? "https://picsum.photos/seed/\(video.id)/300/300"
            ),
            contentSource: video.contentSource ?? .userUploaded,
            externalID: video.externalID
        )
    }
}


