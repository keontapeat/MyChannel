//
//  TopRankMLService.swift
//  MyChannel
//
//  Real-time Vertex AI top-rank-ml powered ranking engine.
//  Pulls live metrics from Firestore, sends to Cloud Run ML agent,
//  returns ranked lists that update in real time with position swaps.
//

import Foundation
import Combine
import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

// MARK: - Ranked User Model (shared across all three Top sections)

struct TopRankedUser: Identifiable, Equatable {
    let id: String
    let name: String
    let username: String
    let avatar: String
    let isVerified: Bool

    // Live metrics from Firestore
    var totalViews: Int
    var subscribers: Int
    var videoCount: Int
    var likeCount: Int
    var commentCount: Int
    var shareCount: Int
    var watchTimeMinutes: Double
    var avgViewDuration: Double          // seconds

    // ML-computed scores (0–100)
    var engagementScore: Double          // likes+comments+shares weighted
    var viralityScore: Double            // velocity of growth
    var contentQualityScore: Double      // ML content quality
    var consistencyScore: Double         // upload regularity
    var overallScore: Double             // final composite

    // Rank metadata
    var rank: Int
    var previousRank: Int
    var rankChange: Int                  // positive = moved up
    var category: RankCategory
    var lastUpdated: Date

    static func == (lhs: TopRankedUser, rhs: TopRankedUser) -> Bool {
        lhs.id == rhs.id && lhs.rank == rhs.rank && lhs.overallScore == rhs.overallScore
    }
}

enum RankCategory: String, Codable, CaseIterable {
    case artist = "artist"
    case filmmaker = "filmmaker"
    case channel = "channel"
}

// MARK: - Canonical Pin Order (single source of truth)
//
// These are the only pinned-name lists for the three Top shelves. The ranking
// engine applies them once in `applyRankings`, so `TopRankedUser.rank` is
// authoritative everywhere — the shelf cards and the "See All" lists both read
// the already-ordered lists and display `user.rank`. Do NOT re-define pin lists
// in the views; that previously caused the shelf and its "See All" to disagree.
enum RankPins {
    static let artists = ["Ysr Gramz", "Juscallmeep", "Mac Quall"]
    static let filmmakers = ["Tee Cee", "Merch Hd", "Pros KT"]
    static let channels = ["Ktrip", "Baby Juu", "Mbk Cari"]
}

// MARK: - TopRankMLService

@MainActor
final class TopRankMLService: ObservableObject {

    static let shared = TopRankMLService()

    // MARK: Published rankings (drive the UI)
    @Published var topArtists: [TopRankedUser] = []
    @Published var topFilmmakers: [TopRankedUser] = []
    @Published var topChannels: [TopRankedUser] = []
    @Published var isLoading: Bool = false
    @Published var lastRefresh: Date = .distantPast
    @Published var isLive: Bool = false

    // MARK: Private
    private var refreshTimer: Timer?
    private var firestoreListeners: [Any] = []
    private var previousArtistRanks: [String: Int] = [:]
    private var previousFilmmakerRanks: [String: Int] = [:]
    private var previousChannelRanks: [String: Int] = [:]
    private let refreshInterval: TimeInterval = 300  // re-rank every 5 minutes
    private var cachedUsers: [TopRankedUser] = []    // cache to prevent random reshuffling
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    private static func fallbackRankedUser(_ friend: FriendArtist, category: RankCategory, rank: Int) -> TopRankedUser {
        let displayName = friend.name.hasSuffix("_c") ? String(friend.name.dropLast(2)) : friend.name
        // Deterministic, stable stats so the very first paint (before the ML list
        // loads) already looks full and believable instead of showing "0 total views".
        let fid = "fallback_\(category.rawValue)_\(displayName.lowercased().replacingOccurrences(of: " ", with: "_"))"
        var rng = StableRNG(string: fid)
        let baseViews = Int.random(in: 120_000...900_000, using: &rng)
        // Higher ranks read as bigger to feel like a real leaderboard.
        let rankBoost = max(0, (4 - rank)) * 60_000
        return TopRankedUser(
            id: fid,
            name: displayName,
            username: displayName.lowercased().replacingOccurrences(of: " ", with: ""),
            avatar: friend.avatar,
            isVerified: true,
            totalViews: baseViews + rankBoost,
            subscribers: category == .channel ? max(5000 - ((rank - 1) * 1500), 1500) : Int.random(in: 8_000...60_000, using: &rng),
            videoCount: category == .filmmaker ? max(24 - ((rank - 1) * 3), 15) : Int.random(in: 12...40, using: &rng),
            likeCount: Int.random(in: 2_000...25_000, using: &rng),
            commentCount: Int.random(in: 200...4_000, using: &rng),
            shareCount: Int.random(in: 50...1_500, using: &rng),
            watchTimeMinutes: 0,
            avgViewDuration: 0,
            engagementScore: Double(1000 - rank),
            viralityScore: 0,
            contentQualityScore: 0,
            consistencyScore: 0,
            overallScore: Double(1000 - rank),
            rank: rank,
            previousRank: rank,
            rankChange: 0,
            category: category,
            lastUpdated: Date()
        )
    }

    static var fallbackTopArtists: [TopRankedUser] {
        RankPins.artists.enumerated().compactMap { index, name in
            OwnerProfile.instagramFriends.first { $0.name == name }.map {
                fallbackRankedUser($0, category: .artist, rank: index + 1)
            }
        }
    }

    static var fallbackTopFilmmakers: [TopRankedUser] {
        ["Tee Cee", "Merch Hd", "Pros KT"].enumerated().compactMap { index, name in
            OwnerProfile.instagramFriends.first { $0.name == name }.map {
                fallbackRankedUser($0, category: .filmmaker, rank: index + 1)
            }
        }
    }

    static var fallbackTopChannels: [TopRankedUser] {
        ["Ktrip", "Baby Juu", "Mbk Cari"].enumerated().compactMap { index, name in
            OwnerProfile.instagramFriends.first { $0.name == name }.map {
                fallbackRankedUser($0, category: .channel, rank: index + 1)
            }
        }
    }

    // MARK: - Lifecycle

    func startRealTimeRanking() {
        guard refreshTimer == nil else { return }
        print("[TopRankML] Starting real-time ranking engine...")

        // Initial fetch
        Task { await refreshAllRankings() }

        // Periodic ML re-rank
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAllRankings()
            }
        }

        // Firestore real-time listeners for instant metric changes
        attachFirestoreListeners()
        isLive = true
    }

    func stopRealTimeRanking() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        detachFirestoreListeners()
        isLive = false
        print("[TopRankML] Stopped real-time ranking engine")
    }

    // MARK: - Master refresh

    func refreshAllRankings() async {
        isLoading = true
        defer { isLoading = false }

        // 1. Gather raw user metrics from Firestore
        let allUsers = await fetchAllUserMetrics()

        // Skip re-ranking if user list hasn't meaningfully changed
        let newIDs = Set(allUsers.map(\.id))
        let cachedIDs = Set(cachedUsers.map(\.id))
        let metricsChanged = allUsers.contains { newUser in
            guard let cached = cachedUsers.first(where: { $0.id == newUser.id }) else { return true }
            return cached.totalViews != newUser.totalViews
                || cached.subscribers != newUser.subscribers
                || cached.videoCount != newUser.videoCount
                || cached.likeCount != newUser.likeCount
                || cached.category != newUser.category   // AI re-classified → must re-shelf
        }
        if !cachedUsers.isEmpty && newIDs == cachedIDs && !metricsChanged {
            print("[TopRankML] No metric changes detected, skipping re-rank")
            return
        }

        // 2. Send to Vertex AI top-rank-ml for scoring
        let scored = await scoreUsersWithML(allUsers)

        // 3. Partition into categories, sort, assign ranks, compute deltas
        applyRankings(scored)
        cachedUsers = scored

        lastRefresh = Date()
        print("[TopRankML] Rankings refreshed – \(topArtists.count) artists, \(topFilmmakers.count) filmmakers, \(topChannels.count) channels")
    }

    // MARK: - 1. Fetch user metrics from Firestore

    private func fetchAllUserMetrics() async -> [TopRankedUser] {
        var users: [TopRankedUser] = []

        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        do {
            // Fetch users collection ordered by totalViews descending
            let snapshot = try await db.collection("users")
                .order(by: "totalViews", descending: true)
                .limit(to: 200)
                .getDocuments()

            for doc in snapshot.documents {
                let data = doc.data()
                let uid = doc.documentID

                let subs = data["subscriberCount"] as? Int ?? data["subscribers"] as? Int ?? 0
                let videos = data["videoCount"] as? Int ?? 0
                // Skip accounts with no subscribers AND no videos — empty/new accounts
                guard subs > 0 || videos > 0 else { continue }

                // 🧠 AI CATEGORY: prefer an explicit/stored category; otherwise let the
                // AI classifier decide which Top shelf this real creator belongs in
                // (artist / filmmaker / channel) from their bio + uploads. The classifier
                // caches + persists, so this is cheap after the first resolve.
                var category = resolveCategory(from: data)
                if data["creatorCategory"] == nil {
                    category = CreatorCategoryClassifier.shared.category(
                        forUserId: uid,
                        displayName: data["displayName"] as? String ?? data["username"] as? String ?? "Creator",
                        bio: data["bio"] as? String
                    )
                }

                let user = TopRankedUser(
                    id: uid,
                    name: data["displayName"] as? String ?? data["username"] as? String ?? "Unknown",
                    username: data["username"] as? String ?? "",
                    avatar: data["profileImageURL"] as? String ?? data["photoURL"] as? String ?? "https://i.pravatar.cc/200?u=\(uid)",
                    isVerified: data["isVerified"] as? Bool ?? false,
                    totalViews: data["totalViews"] as? Int ?? 0,
                    subscribers: subs,
                    videoCount: videos,
                    likeCount: data["likeCount"] as? Int ?? data["totalLikes"] as? Int ?? 0,
                    commentCount: data["commentCount"] as? Int ?? 0,
                    shareCount: data["shareCount"] as? Int ?? 0,
                    watchTimeMinutes: data["watchTimeMinutes"] as? Double ?? 0,
                    avgViewDuration: data["avgViewDuration"] as? Double ?? 0,
                    engagementScore: 0,
                    viralityScore: 0,
                    contentQualityScore: 0,
                    consistencyScore: 0,
                    overallScore: 0,
                    rank: 0,
                    previousRank: 0,
                    rankChange: 0,
                    category: category,
                    lastUpdated: Date()
                )
                users.append(user)
            }
        } catch {
            print("[TopRankML] Firestore fetch error: \(error.localizedDescription)")
        }
        #endif

        // Score tiers:
        // Pinned friends: 1000–996  |  Real Firestore users: 500 + engagement bonus (→ up to ~880)
        // IG friends (non-pinned): 490  |  Seeded: ≤ 100
        // Real users sit just above the friend filler (490) and climb above each
        // other as they actually earn views / subs / likes / videos. They can never
        // cross into pinned territory (≥ 996), so your top-3 friends stay locked in.
        for i in 0..<users.count {
            users[i].overallScore = 500 + Self.realUserEngagementBonus(users[i])
        }

        // Merge with SmartUserSeederService — only .real and .imported users, never .aiGenerated fakes
        let seederService = SmartUserSeederService.shared
        let seeded = seederService.seededUsers
            .filter { $0.userType != .aiGenerated }
            .map { $0.toUser() }
        let existingIds = Set(users.map(\.id))
        for u in seeded where !existingIds.contains(u.id) {
            let category: RankCategory
            if u.videoCount > 0 && (u.bio?.lowercased().contains("film") == true || u.bio?.lowercased().contains("movie") == true || u.bio?.lowercased().contains("director") == true) {
                category = .filmmaker
            } else if u.bio?.lowercased().contains("music") == true || u.bio?.lowercased().contains("artist") == true || u.bio?.lowercased().contains("rapper") == true || u.bio?.lowercased().contains("singer") == true {
                category = .artist
            } else {
                category = .channel
            }

            users.append(TopRankedUser(
                id: u.id,
                name: u.displayName,
                username: u.username,
                avatar: u.profileImageURL ?? "https://i.pravatar.cc/200?u=\(u.id)",
                isVerified: u.isVerified,
                totalViews: u.totalViews ?? 0,
                subscribers: u.subscriberCount,
                videoCount: u.videoCount,
                likeCount: 0,
                commentCount: 0,
                shareCount: 0,
                watchTimeMinutes: 0,
                avgViewDuration: 0,
                engagementScore: 0,
                viralityScore: 0,
                contentQualityScore: 0,
                consistencyScore: 0,
                overallScore: 0,
                rank: 0,
                previousRank: 0,
                rankChange: 0,
                category: category,
                lastUpdated: Date()
            ))
        }

        // Also merge IG friends as artists — use deterministic stats based on name hash
        let dynamicFriends = OwnerFriendsStore.shared.friends
        let allFriends = OwnerProfile.instagramFriends + dynamicFriends
        let existingIds2 = Set(users.map(\.id))
        for f in allFriends {
            let fid = "ig_\(f.name.lowercased().replacingOccurrences(of: " ", with: "_"))"
            guard !existingIds2.contains(fid) else { continue }

            // Pinned rank → force exact position using an artificially high overallScore.
            // Pinned #1 = 999, #2 = 998, #3 = 997, etc. Non-pinned friends get 490 baseline.
            let forcedScore: Double
            if let pin = f.pinnedRank {
                forcedScore = Double(1000 - pin)
            } else {
                forcedScore = 490  // stays visible until a real user earns > 490 via actual engagement
            }

            // Reuse cached metrics if available so rankings don't shuffle, EXCEPT for pinned scores
            if let cached = cachedUsers.first(where: { $0.id == fid }) {
                // If it's a pinned user, we must ensure their score matches the current config (in case config changed)
                if f.pinnedRank != nil {
                    var updatedCache = cached
                    updatedCache.overallScore = forcedScore
                    updatedCache.engagementScore = forcedScore
                    users.append(updatedCache)
                } else {
                    users.append(cached)
                }
                continue
            }

            // Resolve category from FriendArtist.category field
            let friendCategory: RankCategory
            switch f.category.lowercased() {
            case "filmmaker", "film", "director": friendCategory = .filmmaker
            case "channel": friendCategory = .channel
            default: friendCategory = .artist
            }

            // Deterministic seed from user id so values are stable across refreshes
            var rng = StableRNG(string: fid)

            let displayName = f.name.hasSuffix("_c") ? String(f.name.dropLast(2)) : f.name
            users.append(TopRankedUser(
                id: fid,
                name: displayName,
                username: displayName.lowercased().replacingOccurrences(of: " ", with: ""),
                avatar: f.avatar,
                isVerified: true,
                totalViews: Int.random(in: 50_000...500_000, using: &rng),
                subscribers: Int.random(in: 5_000...80_000, using: &rng),
                videoCount: Int.random(in: 10...40, using: &rng),
                likeCount: Int.random(in: 1_000...20_000, using: &rng),
                commentCount: Int.random(in: 200...5_000, using: &rng),
                shareCount: Int.random(in: 50...2_000, using: &rng),
                watchTimeMinutes: Double(Int.random(in: 500...5_000, using: &rng)),
                avgViewDuration: Double(Int.random(in: 30...180, using: &rng)),
                engagementScore: forcedScore,
                viralityScore: 0,
                contentQualityScore: 0,
                consistencyScore: 0,
                overallScore: forcedScore,
                rank: 0,
                previousRank: 0,
                rankChange: 0,
                category: friendCategory,
                lastUpdated: Date()
            ))
        }

        return users
    }

    private func resolveCategory(from data: [String: Any]) -> RankCategory {
        if let cat = data["creatorCategory"] as? String {
            switch cat.lowercased() {
            case "artist", "music", "rapper", "singer": return .artist
            case "filmmaker", "film", "director", "animation": return .filmmaker
            default: return .channel
            }
        }
        if let isArtist = data["isArtist"] as? Bool, isArtist { return .artist }
        if let isFilmmaker = data["isFilmmaker"] as? Bool, isFilmmaker { return .filmmaker }
        return .channel
    }

    // MARK: - 2. Score users via Vertex AI top-rank-ml Cloud Run agent

    private func scoreUsersWithML(_ users: [TopRankedUser]) async -> [TopRankedUser] {
        // Build request payload
        struct RankRequest: Encodable {
            let users: [[String: Any]]

            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                let data = try JSONSerialization.data(withJSONObject: ["users": users])
                let obj = try JSONSerialization.jsonObject(with: data)
                try container.encode(TopRankAnyCodable(obj))
            }
        }

        // Build lightweight metric dicts for the ML agent
        let userDicts: [[String: Any]] = users.map { u in
            [
                "id": u.id,
                "totalViews": u.totalViews,
                "subscribers": u.subscribers,
                "videoCount": u.videoCount,
                "likeCount": u.likeCount,
                "commentCount": u.commentCount,
                "shareCount": u.shareCount,
                "watchTimeMinutes": u.watchTimeMinutes,
                "avgViewDuration": u.avgViewDuration,
                "category": u.category.rawValue
            ] as [String: Any]
        }

        // Call the live Cloud Run endpoint via proxy
        do {
            let payload = TopRankPayload(users: userDicts)
            let response: TopRankResponse = try await CloudRunAgentRouter.post(
                .topRankML,
                path: "/rank",
                body: payload,
                timeout: 15
            )

            // Merge ML scores back into users
            // Skip users with pinned scores (overallScore > 100) so rank pins are never overwritten
            var scoredUsers = users
            let scoreMap = Dictionary(response.rankings.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
            for i in 0..<scoredUsers.count {
                guard scoredUsers[i].overallScore < 490 else { continue } // pinned or friend baseline — don't overwrite
                if let mlScore = scoreMap[scoredUsers[i].id] {
                    scoredUsers[i].engagementScore = mlScore.engagementScore
                    scoredUsers[i].viralityScore = mlScore.viralityScore
                    scoredUsers[i].contentQualityScore = mlScore.contentQualityScore
                    scoredUsers[i].consistencyScore = mlScore.consistencyScore
                    scoredUsers[i].overallScore = mlScore.overallScore
                }
            }

            print("[TopRankML] ML scoring complete for \(response.rankings.count) users")
            return scoredUsers

        } catch {
            print("[TopRankML] ML agent unavailable, using local scoring: \(error.localizedDescription)")
            // Fallback: compute scores locally
            return computeLocalScores(users)
        }
    }

    // MARK: - Local fallback scoring (when ML agent is cold-starting or unavailable)

    private func computeLocalScores(_ users: [TopRankedUser]) -> [TopRankedUser] {
        var scored = users
        for i in 0..<scored.count {
            var u = scored[i]

            // Engagement: weighted combination of likes, comments, shares per view
            let totalEngagement = Double(u.likeCount) + Double(u.commentCount) * 2.0 + Double(u.shareCount) * 3.0
            let viewBase = max(Double(u.totalViews), 1.0)
            u.engagementScore = min((totalEngagement / viewBase) * 1000.0, 100.0)

            // Virality: subscriber-to-view ratio + growth velocity proxy
            let subViewRatio = Double(u.subscribers) / viewBase
            let volumeBonus = min(Double(u.totalViews) / 1_000_000.0, 30.0)
            u.viralityScore = min(subViewRatio * 200.0 + volumeBonus, 100.0)

            // Content Quality: watch time per video, avg duration
            let watchPerVideo = u.videoCount > 0 ? u.watchTimeMinutes / Double(u.videoCount) : 0
            u.contentQualityScore = min(watchPerVideo * 2.0 + u.avgViewDuration * 0.5, 100.0)

            // Consistency: videos per month proxy (assume 6 month window)
            let videosPerMonth = Double(u.videoCount) / 6.0
            u.consistencyScore = min(videosPerMonth * 10.0, 100.0)

            // Overall: weighted composite
            //   35% engagement, 25% virality, 25% content quality, 15% consistency
            // Skip pinned or friend-baseline users (score >= 490) — must not be overwritten
            guard u.overallScore < 490 else {
                scored[i] = u
                continue
            }

            u.overallScore = u.engagementScore * 0.35
                           + u.viralityScore * 0.25
                           + u.contentQualityScore * 0.25
                           + u.consistencyScore * 0.15

            // Boost verified users slightly (they've earned trust)
            if u.isVerified { u.overallScore += 2.0 }

            // Boost based on raw subscriber + view volume (scale matters)
            let scaleBonus = min(log10(max(Double(u.subscribers), 1)) * 3.0, 15.0)
            u.overallScore += scaleBonus

            u.overallScore = min(u.overallScore, 100.0)
            scored[i] = u
        }
        return scored
    }

    // MARK: - 3. Apply rankings with position swap detection

    private func applyRankings(_ scored: [TopRankedUser]) {
        // Partition by category
        var artists = scored.filter { $0.category == .artist }
        var filmmakers = scored.filter { $0.category == .filmmaker }
        var channels = scored.filter { $0.category == .channel }

        // Sort each by overallScore descending
        artists.sort { $0.overallScore > $1.overallScore }
        filmmakers.sort { $0.overallScore > $1.overallScore }
        channels.sort { $0.overallScore > $1.overallScore }

        // Prevent duplicate people from appearing across sections.
        // Priority order:
        // 1. Top Artists
        // 2. Top Indie Filmmakers
        // 3. Top MyChannels
        let artistIds = Set(artists.map(\.id))
        filmmakers.removeAll { artistIds.contains($0.id) }

        let filmmakerIds = Set(filmmakers.map(\.id))
        channels.removeAll { artistIds.contains($0.id) || filmmakerIds.contains($0.id) }

        // Guarantee the pinned Top MyChannels always appear, even if deduplication removed them
        let channelIds = Set(channels.map(\.id))
        for (pinIdx, pinName) in RankPins.channels.enumerated() {
            let pinId = "ig_\(pinName.lowercased().replacingOccurrences(of: " ", with: "_"))"
            if !channelIds.contains(pinId) {
                if let friend = OwnerProfile.instagramFriends.first(where: { $0.name == pinName }) {
                    channels.insert(TopRankMLService.fallbackRankedUser(friend, category: .channel, rank: pinIdx + 1), at: 0)
                }
            }
        }

        // Apply the canonical pin order ONCE per category (single source of truth).
        // After this, array position == displayed rank, so `assignRanks` makes
        // `user.rank` authoritative for both the shelf cards and the See All lists.
        artists = prioritizedRankings(artists, pinnedNames: RankPins.artists)
        filmmakers = prioritizedRankings(filmmakers, pinnedNames: RankPins.filmmakers)
        channels = prioritizedRankings(channels, pinnedNames: RankPins.channels)

        // Assign ranks + compute rank changes
        topArtists = assignRanks(artists.prefix(200).map { $0 }, previousRanks: &previousArtistRanks)
        topFilmmakers = assignRanks(filmmakers.prefix(200).map { $0 }, previousRanks: &previousFilmmakerRanks)
        topChannels = assignRanks(channels.prefix(200).map { $0 }, previousRanks: &previousChannelRanks)

        // Write rankings back to Firestore for cross-device sync
        Task { await persistRankingsToFirestore() }
    }

    private func assignRanks(_ users: [TopRankedUser], previousRanks: inout [String: Int]) -> [TopRankedUser] {
        var ranked = users
        for i in 0..<ranked.count {
            let newRank = i + 1
            let prevRank = previousRanks[ranked[i].id] ?? newRank
            ranked[i].rank = newRank
            ranked[i].previousRank = prevRank
            ranked[i].rankChange = prevRank - newRank  // positive = moved up
        }
        // Update cache for next cycle
        previousRanks = Dictionary(ranked.map { ($0.id, $0.rank) }, uniquingKeysWith: { _, last in last })
        return ranked
    }

    // MARK: - Firestore persistence (so web/other clients see the same rankings)

    private func persistRankingsToFirestore() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let batch = db.batch()

        func writeCategory(_ users: [TopRankedUser], collection: String) {
            for user in users.prefix(20) {
                let ref = db.collection("rankings").document(collection).collection("ranked").document(user.id)
                batch.setData([
                    "rank": user.rank,
                    "previousRank": user.previousRank,
                    "rankChange": user.rankChange,
                    "overallScore": user.overallScore,
                    "engagementScore": user.engagementScore,
                    "viralityScore": user.viralityScore,
                    "contentQualityScore": user.contentQualityScore,
                    "consistencyScore": user.consistencyScore,
                    "totalViews": user.totalViews,
                    "subscribers": user.subscribers,
                    "videoCount": user.videoCount,
                    "name": user.name,
                    "avatar": user.avatar,
                    "category": user.category.rawValue,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: ref, merge: true)
            }
        }

        writeCategory(topArtists, collection: "topArtists")
        writeCategory(topFilmmakers, collection: "topFilmmakers")
        writeCategory(topChannels, collection: "topChannels")

        do {
            try await batch.commit()
            print("[TopRankML] Rankings persisted to Firestore")
        } catch {
            print("[TopRankML] Failed to persist rankings: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Firestore real-time listeners (instant metric changes → re-rank)

    private func attachFirestoreListeners() {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()

        // Listen for any user metric update (likes, views, subs change)
        let listener = db.collection("users")
            .order(by: "totalViews", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot, error == nil else { return }

                // If there are actual changes (not just initial load), trigger re-rank
                let hasChanges = snapshot.documentChanges.contains { $0.type == .modified }
                if hasChanges {
                    print("[TopRankML] Firestore metric change detected → re-ranking...")
                    Task { @MainActor in
                        await self.refreshAllRankings()
                    }
                }
            }
        firestoreListeners.append(listener)

        // Listen for ranking collection changes (from other devices / Cloud Functions)
        for category in ["topArtists", "topFilmmakers", "topChannels"] {
            let rankListener = db.collection("rankings").document(category).collection("ranked")
                .order(by: "rank")
                .limit(to: 20)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self, let snapshot, error == nil else { return }
                    let hasRemoteChanges = snapshot.documentChanges.contains {
                        $0.type == .modified && !snapshot.metadata.hasPendingWrites
                    }
                    if hasRemoteChanges {
                        print("[TopRankML] Remote ranking update for \(category)")
                        Task { @MainActor in
                            await self.refreshAllRankings()
                        }
                    }
                }
            firestoreListeners.append(rankListener)
        }
        #endif
    }

    private func detachFirestoreListeners() {
        #if canImport(FirebaseFirestore)
        for listener in firestoreListeners {
            if let l = listener as? ListenerRegistration {
                l.remove()
            }
        }
        #endif
        firestoreListeners.removeAll()
    }

    // MARK: - Helpers

    /// Engagement bonus (0...380) layered on top of the real-user baseline (500).
    /// Keeps real creators ordered against each other by their ACTUAL metrics while
    /// staying safely below the pinned-friend band (≥ 996). As a real user earns more
    /// views / subs / likes / uploads, this bonus grows and they climb the shelf.
    static func realUserEngagementBonus(_ u: TopRankedUser) -> Double {
        let viewsPts = min(log10(Double(max(u.totalViews, 1))) * 22.0, 150.0)        // up to 150
        let subsPts  = min(log10(Double(max(u.subscribers, 1))) * 20.0, 120.0)        // up to 120
        let likesPts = min(log10(Double(max(u.likeCount, 1))) * 10.0, 60.0)           // up to 60
        let videoPts = min(Double(u.videoCount) * 1.5, 40.0)                          // up to 40
        let verified = u.isVerified ? 10.0 : 0.0                                      // up to 10
        return min(viewsPts + subsPts + likesPts + videoPts + verified, 380.0)
    }

    static func formatCount(_ n: Int) -> String {
        if n >= 1_000_000_000 { return String(format: "%.1fB", Double(n)/1_000_000_000) }
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n)/1_000) }
        return "\(n)"
    }
}

 private func prioritizedRankings(_ rankings: [TopRankedUser], pinnedNames: [String]) -> [TopRankedUser] {
     func normalize(_ value: String) -> String {
         value.lowercased()
             .replacingOccurrences(of: "_c", with: "")
             .replacingOccurrences(of: "_", with: " ")
             .replacingOccurrences(of: "-", with: " ")
             .replacingOccurrences(of: "  ", with: " ")
             .trimmingCharacters(in: .whitespacesAndNewlines)
     }

     var remaining = rankings
     var ordered: [TopRankedUser] = []

     for pinnedName in pinnedNames {
         let normalizedPinned = normalize(pinnedName)
         if let index = remaining.firstIndex(where: { normalize($0.name) == normalizedPinned }) {
             ordered.append(remaining.remove(at: index))
         }
     }

     ordered.append(contentsOf: remaining)
     return ordered
 }

// MARK: - Cloud Run request / response models

private struct TopRankPayload: Encodable {
    let users: [[String: Any]]

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let data = try JSONSerialization.data(withJSONObject: ["users": users])
        let obj = try JSONSerialization.jsonObject(with: data)
        try container.encode(TopRankAnyCodable(obj))
    }
}

private struct TopRankResponse: Decodable {
    let rankings: [MLScore]

    struct MLScore: Decodable {
        let id: String
        let engagementScore: Double
        let viralityScore: Double
        let contentQualityScore: Double
        let consistencyScore: Double
        let overallScore: Double

        enum CodingKeys: String, CodingKey {
            case id
            case engagementScore = "engagement_score"
            case viralityScore = "virality_score"
            case contentQualityScore = "content_quality_score"
            case consistencyScore = "consistency_score"
            case overallScore = "overall_score"
        }
    }
}

// MARK: - AnyCodable helper for encoding [String: Any]

private struct TopRankAnyCodable: Encodable {
    let value: Any

    init(_ value: Any) { self.value = value }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let dict = value as? [String: Any] {
            let data = try JSONSerialization.data(withJSONObject: dict)
            let json = try JSONDecoder().decode(JSON.self, from: data)
            try container.encode(json)
        } else if let array = value as? [Any] {
            let data = try JSONSerialization.data(withJSONObject: array)
            let json = try JSONDecoder().decode(JSON.self, from: data)
            try container.encode(json)
        } else {
            try container.encodeNil()
        }
    }
}

private enum JSON: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSON])
    case object([String: JSON])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { self = .string(s); return }
        if let n = try? container.decode(Double.self) { self = .number(n); return }
        if let b = try? container.decode(Bool.self) { self = .bool(b); return }
        if let a = try? container.decode([JSON].self) { self = .array(a); return }
        if let o = try? container.decode([String: JSON].self) { self = .object(o); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .array(let a): try container.encode(a)
        case .object(let o): try container.encode(o)
        case .null: try container.encodeNil()
        }
    }
}
